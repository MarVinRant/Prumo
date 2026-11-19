-- Liberação explícita de material aceito em quarentena após conferência.
create or replace function public.release_quarantined_stock(
  p_position_id uuid,
  p_quantity numeric,
  p_reason text,
  p_idempotency_key text default null
) returns jsonb
language plpgsql security definer set search_path=public,private,pgcrypto,pg_temp as $$
declare
  v_uid uuid:=auth.uid(); v_tenant uuid; v_position record; v_usable uuid; v_usable_q numeric;
  v_doc uuid; v_line_out uuid; v_line_in uuid; v_no text; v_key text; v_existing jsonb;
begin
  perform private.require_aal2();
  if nullif(trim(coalesce(p_reason,'')),'') is null then raise exception 'reason_required'; end if;
  if p_quantity is null or p_quantity<=0 then raise exception 'quantity_must_be_positive'; end if;
  select sp.tenant_id,sp.id,sp.item_id,sp.location_id,sp.lot_id,sp.on_hand_q,sp.condition,l.expires_on,i.base_uom
    into v_position from stock_positions sp join lots l on l.tenant_id=sp.tenant_id and l.id=sp.lot_id
    join items i on i.tenant_id=sp.tenant_id and i.id=sp.item_id
    where sp.id=p_position_id for update;
  if v_position.id is null then raise exception 'position_not_found'; end if;
  v_tenant:=v_position.tenant_id;
  if not exists(select 1 from memberships where tenant_id=v_tenant and user_id=v_uid and status='active' and role in('owner','manager') and (expires_at is null or expires_at>now())) then raise exception 'quarantine_release_required'; end if;
  if v_position.condition<>'quarantine' then raise exception 'position_not_quarantine'; end if;
  if v_position.expires_on is not null and v_position.expires_on<current_date then raise exception 'expired_lot_blocked'; end if;
  if p_quantity>v_position.on_hand_q then raise exception 'insufficient_quarantine_stock'; end if;
  v_key:=coalesce(p_idempotency_key,'quarantine-release:'||p_position_id::text||':'||p_quantity::text||':'||md5(trim(p_reason)));
  select jsonb_build_object('document_id',id,'document_no',document_no) into v_existing from stock_documents where tenant_id=v_tenant and idempotency_key=v_key;
  if v_existing is not null then return v_existing; end if;
  select id,on_hand_q into v_usable,v_usable_q from stock_positions where tenant_id=v_tenant and item_id=v_position.item_id and location_id=v_position.location_id and lot_id=v_position.lot_id and condition='usable' for update;
  v_no:='QRL-'||to_char(clock_timestamp(),'YYYYMMDDHH24MISSMS')||'-'||substr(replace(gen_random_uuid()::text,'-',''),1,6);
  insert into stock_documents(tenant_id,document_no,type,reason,idempotency_key,actor_id) values(v_tenant,v_no,'adjustment',trim(p_reason),v_key,v_uid) returning id into v_doc;
  insert into stock_document_lines(tenant_id,document_id,item_id,location_id,lot_id,quantity,input_uom,signed_quantity) values(v_tenant,v_doc,v_position.item_id,v_position.location_id,v_position.lot_id,p_quantity,v_position.base_uom,-p_quantity) returning id into v_line_out;
  insert into stock_document_lines(tenant_id,document_id,item_id,location_id,lot_id,quantity,input_uom,signed_quantity) values(v_tenant,v_doc,v_position.item_id,v_position.location_id,v_position.lot_id,p_quantity,v_position.base_uom,p_quantity) returning id into v_line_in;
  update stock_positions set on_hand_q=on_hand_q-p_quantity,updated_at=now() where tenant_id=v_tenant and id=p_position_id;
  insert into stock_entries(tenant_id,document_id,document_line_id,item_id,location_id,lot_id,quantity,direction) values(v_tenant,v_doc,v_line_out,v_position.item_id,v_position.location_id,v_position.lot_id,p_quantity,'out');
  insert into stock_positions(tenant_id,item_id,location_id,lot_id,condition,on_hand_q) values(v_tenant,v_position.item_id,v_position.location_id,v_position.lot_id,'usable',p_quantity)
    on conflict(tenant_id,item_id,location_id,lot_id,condition) do update set on_hand_q=stock_positions.on_hand_q+excluded.on_hand_q,updated_at=now() returning id into v_usable;
  insert into stock_entries(tenant_id,document_id,document_line_id,item_id,location_id,lot_id,quantity,direction) values(v_tenant,v_doc,v_line_in,v_position.item_id,v_position.location_id,v_position.lot_id,p_quantity,'in');
  insert into audit_events(tenant_id,actor_id,action,entity,entity_id,payload) values(v_tenant,v_uid,'stock.quarantine_release','stock_position',p_position_id,jsonb_build_object('document_id',v_doc,'quantity',p_quantity,'reason',trim(p_reason)));
  return jsonb_build_object('document_id',v_doc,'document_no',v_no,'quantity',p_quantity);
end; $$;

revoke all on function public.release_quarantined_stock(uuid,numeric,text,text) from public,anon;
grant execute on function public.release_quarantined_stock(uuid,numeric,text,text) to authenticated;
