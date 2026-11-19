-- Repetição com a mesma chave e payload diferente é conflito explícito.
alter table public.stock_documents add column if not exists idempotency_fingerprint text;
create index if not exists stock_documents_tenant_idempotency on public.stock_documents(tenant_id,idempotency_key);

create or replace function public.post_stock_movement(p_type text,p_item_id uuid,p_location_id uuid,p_to_location_id uuid default null,p_lot_id uuid default null,p_quantity numeric default 0,p_input_uom text default null,p_reason text default null,p_idempotency_key text default null) returns jsonb
language plpgsql security definer set search_path=public,finance,pgcrypto,pg_temp as $$
declare v_uid uuid:=auth.uid(); v_tenant uuid; v_lot uuid; v_doc uuid; v_line uuid; v_no text; v_uom text; v_qty numeric:=p_quantity; v_factor numeric:=1; v_pos uuid; v_on numeric; v_reserved numeric; v_existing jsonb; v_existing_hash text; v_fingerprint text; v_expires_on date; v_lot_condition text;
begin
 if v_uid is null then raise exception 'not_authenticated'; end if;
 if p_quantity is null or p_quantity<=0 then raise exception 'quantity_must_be_positive'; end if;
 v_fingerprint:=md5(jsonb_build_object('type',p_type,'item_id',p_item_id,'location_id',p_location_id,'to_location_id',p_to_location_id,'lot_id',p_lot_id,'quantity',p_quantity,'input_uom',p_input_uom,'reason',p_reason)::text);
 select tenant_id into v_tenant from memberships where user_id=v_uid and status='active' and (expires_at is null or expires_at>now()) limit 1;
 if v_tenant is null then raise exception 'membership_required'; end if;
 if p_idempotency_key is not null then
   select jsonb_build_object('document_id',id,'document_no',document_no),idempotency_fingerprint into v_existing,v_existing_hash from stock_documents where tenant_id=v_tenant and idempotency_key=p_idempotency_key;
   if v_existing is not null then if v_existing_hash is not null and v_existing_hash<>v_fingerprint then raise exception 'idempotency_payload_conflict'; end if; return v_existing; end if;
 end if;
 select base_uom into v_uom from items where tenant_id=v_tenant and id=p_item_id and status='active'; if v_uom is null then raise exception 'item_not_found'; end if;
 if p_input_uom is not null and p_input_uom<>v_uom then
   if lower(p_input_uom)='kg' and v_uom='g' then v_factor:=1000;
   elsif lower(p_input_uom)='l' and v_uom='ml' then v_factor:=1000;
   else select factor into v_factor from item_packages where tenant_id=v_tenant and item_id=p_item_id and name=p_input_uom limit 1; if v_factor is null then raise exception 'conversion_not_configured'; end if; end if;
 end if;
 v_qty:=p_quantity*v_factor;
 if p_lot_id is null then insert into lots(tenant_id,item_id,lot_code) values(v_tenant,p_item_id,'MOV-'||to_char(clock_timestamp(),'YYYYMMDDHH24MISSMS')) returning id into v_lot; else select id,expires_on,condition into v_lot,v_expires_on,v_lot_condition from lots where tenant_id=v_tenant and id=p_lot_id and item_id=p_item_id for update; end if; if v_lot is null then raise exception 'lot_not_found'; end if;
 if p_type in('consumption','transfer','return') and (v_expires_on < current_date or v_lot_condition='expired') then raise exception 'expired_lot_blocked'; end if;
 if p_type='transfer' and (p_to_location_id is null or p_to_location_id=p_location_id) then raise exception 'destination_required'; end if;
 v_no:='MOV-'||to_char(clock_timestamp(),'YYYYMMDDHH24MISSMS')||'-'||substr(replace(gen_random_uuid()::text,'-',''),1,6);
 insert into stock_documents(tenant_id,document_no,type,reason,idempotency_key,idempotency_fingerprint,actor_id) values(v_tenant,v_no,p_type,p_reason,coalesce(p_idempotency_key,gen_random_uuid()::text),v_fingerprint,v_uid) returning id into v_doc;
 insert into stock_document_lines(tenant_id,document_id,item_id,location_id,to_location_id,lot_id,quantity,input_uom,signed_quantity) values(v_tenant,v_doc,p_item_id,p_location_id,p_to_location_id,v_lot,v_qty,coalesce(p_input_uom,v_uom),case when p_type in('consumption','loss','transfer') then -v_qty else v_qty end) returning id into v_line;
 select id,on_hand_q,reserved_q into v_pos,v_on,v_reserved from stock_positions where tenant_id=v_tenant and item_id=p_item_id and location_id=p_location_id and lot_id=v_lot and condition='usable' for update;
 if p_type in('consumption','loss','transfer') then if v_pos is null or v_on-v_reserved<v_qty then raise exception 'insufficient_available_stock'; end if; update stock_positions set on_hand_q=on_hand_q-v_qty,updated_at=now() where id=v_pos; insert into stock_entries(tenant_id,document_id,document_line_id,item_id,location_id,lot_id,quantity,direction) values(v_tenant,v_doc,v_line,p_item_id,p_location_id,v_lot,v_qty,'out'); end if;
 if p_type in('opening','receipt','adjustment','transfer','return') then if p_type='transfer' then insert into stock_positions(tenant_id,item_id,location_id,lot_id,on_hand_q) values(v_tenant,p_item_id,p_to_location_id,v_lot,v_qty) on conflict(tenant_id,item_id,location_id,lot_id,condition) do update set on_hand_q=stock_positions.on_hand_q+excluded.on_hand_q,updated_at=now(); insert into stock_entries(tenant_id,document_id,document_line_id,item_id,location_id,lot_id,quantity,direction) values(v_tenant,v_doc,v_line,p_item_id,p_to_location_id,v_lot,v_qty,'in'); else insert into stock_positions(tenant_id,item_id,location_id,lot_id,on_hand_q) values(v_tenant,p_item_id,p_location_id,v_lot,v_qty) on conflict(tenant_id,item_id,location_id,lot_id,condition) do update set on_hand_q=stock_positions.on_hand_q+excluded.on_hand_q,updated_at=now(); insert into stock_entries(tenant_id,document_id,document_line_id,item_id,location_id,lot_id,quantity,direction) values(v_tenant,v_doc,v_line,p_item_id,p_location_id,v_lot,v_qty,'in'); end if; end if;
 insert into audit_events(tenant_id,actor_id,action,entity,entity_id,payload) values(v_tenant,v_uid,'stock.movement','stock_document',v_doc,jsonb_build_object('type',p_type,'quantity',v_qty,'input_quantity',p_quantity,'input_uom',p_input_uom,'conversion_factor',v_factor,'item_id',p_item_id));
 return jsonb_build_object('document_id',v_doc,'document_no',v_no,'quantity',v_qty,'conversion_factor',v_factor);
end; $$;

revoke all on function public.post_stock_movement(text,uuid,uuid,uuid,uuid,numeric,text,text,text) from public,anon;
grant execute on function public.post_stock_movement(text,uuid,uuid,uuid,uuid,numeric,text,text,text) to authenticated;
