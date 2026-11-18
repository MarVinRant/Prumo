alter table public.receipts add column if not exists idempotency_key text;
create unique index if not exists receipts_tenant_idempotency_key on public.receipts(tenant_id,idempotency_key) where idempotency_key is not null;

create or replace function public.approve_purchase_request(p_request_id uuid) returns boolean language plpgsql security definer set search_path=public,pg_temp as $$
declare v_uid uuid:=auth.uid(); v_tenant uuid; v_changed integer;
begin
 select tenant_id into v_tenant from memberships where user_id=v_uid and status='active' and role in('owner','manager','purchasing') limit 1;
 if v_tenant is null then raise exception 'purchase_approval_required'; end if;
 update purchase_requests set status='approved' where tenant_id=v_tenant and id=p_request_id and status='requested';
 get diagnostics v_changed=row_count;
 if v_changed=0 then raise exception 'request_not_approvable'; end if;
 insert into audit_events(tenant_id,actor_id,action,entity,entity_id) values(v_tenant,v_uid,'purchase.approve','purchase_request',p_request_id);
 return true;
end; $$;

create or replace function public.create_purchase_order_from_request(p_request_id uuid) returns uuid language plpgsql security definer set search_path=public,pg_temp as $$
declare v_uid uuid:=auth.uid(); v_tenant uuid; v_item uuid; v_quantity numeric; v_supplier uuid; v_order uuid; v_no text;
begin
 select tenant_id into v_tenant from memberships where user_id=v_uid and status='active' and role in('owner','manager','purchasing') limit 1;
 if v_tenant is null then raise exception 'purchasing_required'; end if;
 select prl.item_id,prl.quantity into v_item,v_quantity from purchase_requests pr join purchase_request_lines prl on prl.tenant_id=pr.tenant_id and prl.request_id=pr.id where pr.tenant_id=v_tenant and pr.id=p_request_id and pr.status='approved' limit 1;
 if v_item is null then raise exception 'request_not_approved'; end if;
 select si.supplier_id into v_supplier from supplier_items si join suppliers s on s.tenant_id=si.tenant_id and s.id=si.supplier_id where si.tenant_id=v_tenant and si.item_id=v_item and s.status='active' order by si.created_at limit 1;
 if v_supplier is null then raise exception 'supplier_required'; end if;
 v_no:='PO-'||to_char(clock_timestamp(),'YYYYMMDDHH24MISSMS')||'-'||substr(replace(gen_random_uuid()::text,'-',''),1,6);
 insert into purchase_orders(tenant_id,supplier_id,request_id,order_no,status) values(v_tenant,v_supplier,p_request_id,v_no,'sent') returning id into v_order;
 insert into purchase_order_lines(tenant_id,order_id,item_id,ordered_q) values(v_tenant,v_order,v_item,v_quantity);
 update purchase_requests set status='ordered' where tenant_id=v_tenant and id=p_request_id;
 insert into audit_events(tenant_id,actor_id,action,entity,entity_id,payload) values(v_tenant,v_uid,'purchase.order','purchase_order',v_order,jsonb_build_object('request_id',p_request_id));
 return v_order;
end; $$;

create or replace function public.receive_purchase_order(p_order_id uuid,p_location_id uuid,p_quantity numeric,p_lot_code text,p_expires_on date,p_unit_cost numeric default null,p_idempotency_key text default null) returns jsonb language plpgsql security definer set search_path=public,pg_temp as $$
declare v_uid uuid:=auth.uid(); v_tenant uuid; v_line record; v_lot uuid; v_receipt uuid; v_doc jsonb; v_received numeric;
begin
 select tenant_id into v_tenant from memberships where user_id=v_uid and status='active' and role in('owner','manager','purchasing') limit 1;
 if v_tenant is null then raise exception 'receiving_required'; end if;
 if p_quantity is null or p_quantity<=0 then raise exception 'quantity_must_be_positive'; end if;
 if p_expires_on is not null and p_expires_on<current_date then raise exception 'expired_lot_blocked'; end if;
 if p_idempotency_key is not null then select jsonb_build_object('receipt_id',id,'status',status) into v_doc from receipts where tenant_id=v_tenant and idempotency_key=p_idempotency_key; if v_doc is not null then return v_doc; end if; end if;
 select pol.id,pol.item_id,pol.ordered_q,pol.received_q,i.base_uom into v_line from purchase_order_lines pol join items i on i.tenant_id=pol.tenant_id and i.id=pol.item_id where pol.tenant_id=v_tenant and pol.order_id=p_order_id for update;
 if v_line.id is null then raise exception 'order_not_found'; end if;
 if p_quantity>v_line.ordered_q-v_line.received_q then raise exception 'received_quantity_exceeds_order'; end if;
 if not exists(select 1 from locations where tenant_id=v_tenant and id=p_location_id and status='active' and is_stockable) then raise exception 'location_not_found'; end if;
 insert into lots(tenant_id,item_id,lot_code,expires_on,condition) values(v_tenant,v_line.item_id,coalesce(nullif(trim(p_lot_code),''),'REC-'||to_char(clock_timestamp(),'YYYYMMDDHH24MISSMS')),p_expires_on,'usable') on conflict(tenant_id,item_id,lot_code) do update set expires_on=excluded.expires_on returning id into v_lot;
 v_doc:=public.post_stock_movement('receipt',v_line.item_id,p_location_id,null,v_lot,p_quantity,v_line.base_uom,'Recebimento de pedido '||p_order_id,coalesce(p_idempotency_key,gen_random_uuid()::text));
 insert into receipts(tenant_id,order_id,location_id,status,received_by,idempotency_key) values(v_tenant,p_order_id,p_location_id,'posted',v_uid,p_idempotency_key) returning id into v_receipt;
 insert into receipt_lines(tenant_id,receipt_id,order_line_id,lot_id,accepted_q,rejected_q) values(v_tenant,v_receipt,v_line.id,v_lot,p_quantity,0);
 v_received:=v_line.received_q+p_quantity;
 update purchase_order_lines set received_q=v_received,unit_cost=coalesce(p_unit_cost,unit_cost) where tenant_id=v_tenant and id=v_line.id;
 update purchase_orders set status=case when v_received=v_line.ordered_q then 'received' else 'partial' end where tenant_id=v_tenant and id=p_order_id;
 update purchase_requests set status='received' where tenant_id=v_tenant and id=(select request_id from purchase_orders where tenant_id=v_tenant and id=p_order_id) and v_received=v_line.ordered_q;
 return v_doc||jsonb_build_object('receipt_id',v_receipt);
end; $$;

revoke all on function public.approve_purchase_request(uuid) from public,anon; grant execute on function public.approve_purchase_request(uuid) to authenticated;
revoke all on function public.create_purchase_order_from_request(uuid) from public,anon; grant execute on function public.create_purchase_order_from_request(uuid) to authenticated;
revoke all on function public.receive_purchase_order(uuid,uuid,numeric,text,date,numeric,text) from public,anon; grant execute on function public.receive_purchase_order(uuid,uuid,numeric,text,date,numeric,text) to authenticated;
