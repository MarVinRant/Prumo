-- Recebimento por conferência: entregue = utilizável + quarentena + rejeitada.
-- A quantidade rejeitada não atende o pedido e não entra no estoque.
alter table public.purchase_order_lines
  add column if not exists delivered_q numeric(20,6) not null default 0;

update public.purchase_order_lines
set delivered_q=greatest(delivered_q,received_q)
where delivered_q<received_q;

alter table public.purchase_order_lines drop constraint if exists purchase_order_lines_delivered_q_check;
alter table public.purchase_order_lines add constraint purchase_order_lines_delivered_q_check
  check(delivered_q>=received_q and delivered_q>=0 and delivered_q<=ordered_q);

alter table public.receipt_lines
  add column if not exists blocked_q numeric(20,6) not null default 0;

alter table public.receipt_lines drop constraint if exists receipt_lines_quantities_check;
alter table public.receipt_lines add constraint receipt_lines_quantities_check
  check(accepted_q>=0 and blocked_q>=0 and rejected_q>=0 and accepted_q+blocked_q+rejected_q>0);

create or replace function public.receive_purchase_order_split(
  p_order_id uuid,
  p_location_id uuid,
  p_accepted_q numeric,
  p_blocked_q numeric,
  p_rejected_q numeric,
  p_lot_code text,
  p_expires_on date,
  p_unit_cost numeric default null,
  p_idempotency_key text default null
) returns jsonb
language plpgsql security definer set search_path=public,finance,private,pgcrypto,pg_temp as $$
declare
  v_uid uuid:=auth.uid(); v_tenant uuid; v_line record; v_lot uuid; v_receipt uuid;
  v_existing jsonb; v_delivered numeric; v_accepted numeric; v_blocked numeric; v_rejected numeric;
  v_usable_doc uuid; v_usable_line uuid; v_blocked_doc uuid; v_blocked_line uuid;
  v_no text; v_uom text; v_old_value numeric:=0; v_old_avg numeric:=0; v_total_q numeric:=0;
  v_cost numeric:=0; v_new_value numeric:=0; v_new_avg numeric:=0; v_doc_key text;
begin
  perform private.require_aal2();
  if v_uid is null then raise exception 'not_authenticated'; end if;
  select tenant_id into v_tenant from memberships
    where user_id=v_uid and status='active' and role in('owner','manager','purchasing')
      and (expires_at is null or expires_at>now()) order by created_at limit 1;
  if v_tenant is null then raise exception 'receiving_required'; end if;
  v_accepted:=coalesce(p_accepted_q,0); v_blocked:=coalesce(p_blocked_q,0); v_rejected:=coalesce(p_rejected_q,0);
  if v_accepted<0 or v_blocked<0 or v_rejected<0 or v_accepted+v_blocked+v_rejected<=0 then raise exception 'receipt_quantities_required'; end if;
  if p_expires_on is not null and p_expires_on<current_date then raise exception 'expired_lot_blocked'; end if;
  if p_idempotency_key is not null then
    select jsonb_build_object('receipt_id',id,'status',status) into v_existing
      from receipts where tenant_id=v_tenant and idempotency_key=p_idempotency_key;
    if v_existing is not null then return v_existing; end if;
  end if;
  select pol.id,pol.item_id,pol.ordered_q,pol.received_q,pol.delivered_q,i.base_uom
    into v_line from purchase_order_lines pol join items i on i.tenant_id=pol.tenant_id and i.id=pol.item_id
    where pol.tenant_id=v_tenant and pol.order_id=p_order_id for update;
  if v_line.id is null then raise exception 'order_not_found'; end if;
  v_delivered:=v_accepted+v_blocked+v_rejected;
  if v_delivered>v_line.ordered_q-v_line.delivered_q then raise exception 'delivered_quantity_exceeds_order'; end if;
  if not exists(select 1 from locations where tenant_id=v_tenant and id=p_location_id and status='active' and is_stockable) then raise exception 'location_not_found'; end if;
  insert into lots(tenant_id,item_id,lot_code,expires_on,condition)
    values(v_tenant,v_line.item_id,coalesce(nullif(trim(p_lot_code),''),'REC-'||to_char(clock_timestamp(),'YYYYMMDDHH24MISSMS')),p_expires_on,'usable')
    on conflict(tenant_id,item_id,lot_code) do update set expires_on=excluded.expires_on returning id into v_lot;
  insert into receipts(tenant_id,order_id,location_id,status,received_by,idempotency_key)
    values(v_tenant,p_order_id,p_location_id,'posted',v_uid,p_idempotency_key) returning id into v_receipt;
  insert into receipt_lines(tenant_id,receipt_id,order_line_id,lot_id,accepted_q,blocked_q,rejected_q)
    values(v_tenant,v_receipt,v_line.id,v_lot,v_accepted,v_blocked,v_rejected);

  -- Each condition gets its own immutable stock document. Rejected units never enter stock.
  if v_accepted>0 then
    v_doc_key:=coalesce(p_idempotency_key,'receipt:'||v_receipt::text)||':usable';
    v_no:='RCV-'||to_char(clock_timestamp(),'YYYYMMDDHH24MISSMS')||'-'||substr(replace(gen_random_uuid()::text,'-',''),1,6);
    insert into stock_documents(tenant_id,document_no,type,reason,idempotency_key,actor_id)
      values(v_tenant,v_no,'receipt','Recebimento utilizável '||p_order_id,v_doc_key,v_uid) returning id into v_usable_doc;
    insert into stock_document_lines(tenant_id,document_id,item_id,location_id,lot_id,quantity,input_uom,signed_quantity)
      values(v_tenant,v_usable_doc,v_line.item_id,p_location_id,v_lot,v_accepted,v_line.base_uom,v_accepted) returning id into v_usable_line;
    insert into stock_positions(tenant_id,item_id,location_id,lot_id,condition,on_hand_q)
      values(v_tenant,v_line.item_id,p_location_id,v_lot,'usable',v_accepted)
      on conflict(tenant_id,item_id,location_id,lot_id,condition) do update set on_hand_q=stock_positions.on_hand_q+excluded.on_hand_q,updated_at=now();
    insert into stock_entries(tenant_id,document_id,document_line_id,item_id,location_id,lot_id,quantity,direction)
      values(v_tenant,v_usable_doc,v_usable_line,v_line.item_id,p_location_id,v_lot,v_accepted,'in');
  end if;
  if v_blocked>0 then
    v_doc_key:=coalesce(p_idempotency_key,'receipt:'||v_receipt::text)||':quarantine';
    v_no:='RCQ-'||to_char(clock_timestamp(),'YYYYMMDDHH24MISSMS')||'-'||substr(replace(gen_random_uuid()::text,'-',''),1,6);
    insert into stock_documents(tenant_id,document_no,type,reason,idempotency_key,actor_id)
      values(v_tenant,v_no,'receipt','Recebimento em quarentena '||p_order_id,v_doc_key,v_uid) returning id into v_blocked_doc;
    insert into stock_document_lines(tenant_id,document_id,item_id,location_id,lot_id,quantity,input_uom,signed_quantity)
      values(v_tenant,v_blocked_doc,v_line.item_id,p_location_id,v_lot,v_blocked,v_line.base_uom,v_blocked) returning id into v_blocked_line;
    insert into stock_positions(tenant_id,item_id,location_id,lot_id,condition,on_hand_q)
      values(v_tenant,v_line.item_id,p_location_id,v_lot,'quarantine',v_blocked)
      on conflict(tenant_id,item_id,location_id,lot_id,condition) do update set on_hand_q=stock_positions.on_hand_q+excluded.on_hand_q,updated_at=now();
    insert into stock_entries(tenant_id,document_id,document_line_id,item_id,location_id,lot_id,quantity,direction)
      values(v_tenant,v_blocked_doc,v_blocked_line,v_line.item_id,p_location_id,v_lot,v_blocked,'in');
  end if;

  update purchase_order_lines set delivered_q=delivered_q+v_delivered, received_q=received_q+v_accepted+v_blocked,
    unit_cost=coalesce(p_unit_cost,unit_cost) where tenant_id=v_tenant and id=v_line.id;
  update purchase_orders set status=case when v_line.delivered_q+v_delivered=v_line.ordered_q then 'received' else 'partial' end
    where tenant_id=v_tenant and id=p_order_id;
  update purchase_requests set status='received' where tenant_id=v_tenant
    and id=(select request_id from purchase_orders where tenant_id=v_tenant and id=p_order_id)
    and v_line.received_q+v_accepted+v_blocked=v_line.ordered_q;

  -- Cost is captured only for accepted physical stock; quarantine remains unavailable until released.
  select coalesce(stock_value,0),coalesce(avg_unit_cost,0) into v_old_value,v_old_avg
    from finance.stock_values where tenant_id=v_tenant and item_id=v_line.item_id and location_id=p_location_id for update;
  v_cost:=coalesce(p_unit_cost,v_old_avg,0);
  select coalesce(sum(on_hand_q),0) into v_total_q from stock_positions
    where tenant_id=v_tenant and item_id=v_line.item_id and location_id=p_location_id and condition='usable';
  v_new_value:=v_old_value+(v_accepted*v_cost); v_new_avg:=case when v_total_q>0 then v_new_value/v_total_q else 0 end;
  insert into finance.stock_values(tenant_id,item_id,location_id,avg_unit_cost,stock_value,updated_at)
    values(v_tenant,v_line.item_id,p_location_id,v_new_avg,v_new_value,now())
    on conflict(tenant_id,item_id,location_id) do update set avg_unit_cost=excluded.avg_unit_cost,stock_value=excluded.stock_value,updated_at=now();
  insert into audit_events(tenant_id,actor_id,action,entity,entity_id,payload)
    values(v_tenant,v_uid,'purchase.receipt.conferred','receipt',v_receipt,jsonb_build_object('item_id',v_line.item_id,'accepted_q',v_accepted,'blocked_q',v_blocked,'rejected_q',v_rejected,'location_id',p_location_id));
  return jsonb_build_object('receipt_id',v_receipt,'status','posted','accepted_q',v_accepted,'blocked_q',v_blocked,'rejected_q',v_rejected,'delivered_q',v_delivered);
end; $$;

revoke all on function public.receive_purchase_order_split(uuid,uuid,numeric,numeric,numeric,text,date,numeric,text) from public,anon;
grant execute on function public.receive_purchase_order_split(uuid,uuid,numeric,numeric,numeric,text,date,numeric,text) to authenticated;
