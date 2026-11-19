create table if not exists finance.value_adjustments(
  id uuid primary key default gen_random_uuid(),
  tenant_id uuid not null references public.organizations(id) on delete cascade,
  item_id uuid not null,
  location_id uuid not null,
  amount numeric(20,6) not null check(amount<>0),
  reason text not null,
  status text not null default 'requested' check(status in('requested','approved','rejected')),
  idempotency_key text not null,
  requested_by uuid not null references auth.users(id),
  approved_by uuid references auth.users(id),
  requested_at timestamptz not null default now(),
  approved_at timestamptz,
  unique(tenant_id,id),
  unique(tenant_id,idempotency_key),
  foreign key(tenant_id,item_id) references public.items(tenant_id,id),
  foreign key(tenant_id,location_id) references public.locations(tenant_id,id)
);
alter table finance.value_adjustments enable row level security;
revoke all on table finance.value_adjustments from anon,authenticated;

create or replace function public.request_value_adjustment(p_item_id uuid,p_location_id uuid,p_amount numeric,p_reason text,p_idempotency_key text default null) returns jsonb
language plpgsql security definer set search_path=public,finance,private,pgcrypto,pg_temp as $$
declare v_uid uuid:=auth.uid(); v_tenant uuid; v_id uuid; v_key text:=coalesce(p_idempotency_key,gen_random_uuid()::text); v_existing jsonb;
begin
  perform private.require_aal2();
  if p_amount is null or p_amount=0 then raise exception 'amount_required'; end if;
  if nullif(trim(coalesce(p_reason,'')),'') is null then raise exception 'reason_required'; end if;
  select tenant_id into v_tenant from memberships where tenant_id is not null and user_id=v_uid and status='active' and role in('owner','manager','finance') and (expires_at is null or expires_at>now()) order by created_at limit 1;
  if v_tenant is null then raise exception 'finance_adjustment_required'; end if;
  select jsonb_build_object('adjustment_id',id,'status',status) into v_existing from finance.value_adjustments where tenant_id=v_tenant and idempotency_key=v_key;
  if v_existing is not null then return v_existing; end if;
  if not exists(select 1 from public.items where tenant_id=v_tenant and id=p_item_id and status='active') then raise exception 'item_not_found'; end if;
  if not exists(select 1 from public.locations where tenant_id=v_tenant and id=p_location_id and status='active') then raise exception 'location_not_found'; end if;
  insert into finance.value_adjustments(tenant_id,item_id,location_id,amount,reason,idempotency_key,requested_by) values(v_tenant,p_item_id,p_location_id,p_amount,trim(p_reason),v_key,v_uid) returning id into v_id;
  insert into public.audit_events(tenant_id,actor_id,action,entity,entity_id,payload) values(v_tenant,v_uid,'finance.adjustment.request','value_adjustment',v_id,jsonb_build_object('item_id',p_item_id,'location_id',p_location_id));
  return jsonb_build_object('adjustment_id',v_id,'status','requested');
end; $$;

create or replace function public.approve_value_adjustment(p_adjustment_id uuid) returns jsonb
language plpgsql security definer set search_path=public,finance,private,pg_temp as $$
declare v_uid uuid:=auth.uid(); v_tenant uuid; v_adjustment record; v_old_value numeric:=0; v_total_q numeric:=0; v_new_value numeric; v_new_avg numeric; v_role text;
begin
  perform private.require_aal2();
  select tenant_id,role into v_tenant,v_role from memberships where user_id=v_uid and status='active' and role in('owner','finance') and (expires_at is null or expires_at>now()) order by created_at limit 1;
  if v_tenant is null then raise exception 'finance_approval_required'; end if;
  select * into v_adjustment from finance.value_adjustments where tenant_id=v_tenant and id=p_adjustment_id for update;
  if v_adjustment.id is null then raise exception 'adjustment_not_found'; end if;
  if v_adjustment.status='approved' then return jsonb_build_object('adjustment_id',v_adjustment.id,'status','approved'); end if;
  if v_adjustment.requested_by=v_uid then raise exception 'independent_approval_required'; end if;
  select coalesce(stock_value,0) into v_old_value from finance.stock_values where tenant_id=v_tenant and item_id=v_adjustment.item_id and location_id=v_adjustment.location_id for update;
  select coalesce(sum(on_hand_q),0) into v_total_q from public.stock_positions where tenant_id=v_tenant and item_id=v_adjustment.item_id and location_id=v_adjustment.location_id and condition='usable';
  v_new_value:=v_old_value+v_adjustment.amount;
  if v_new_value<0 then raise exception 'stock_value_cannot_be_negative'; end if;
  if v_total_q<=0 and v_new_value<>0 then raise exception 'quantity_required_for_value'; end if;
  v_new_avg:=case when v_total_q>0 then v_new_value/v_total_q else 0 end;
  insert into finance.stock_values(tenant_id,item_id,location_id,avg_unit_cost,stock_value,updated_at) values(v_tenant,v_adjustment.item_id,v_adjustment.location_id,v_new_avg,v_new_value,now()) on conflict(tenant_id,item_id,location_id) do update set avg_unit_cost=excluded.avg_unit_cost,stock_value=excluded.stock_value,updated_at=now();
  update finance.value_adjustments set status='approved',approved_by=v_uid,approved_at=now() where tenant_id=v_tenant and id=p_adjustment_id;
  insert into public.audit_events(tenant_id,actor_id,action,entity,entity_id,payload) values(v_tenant,v_uid,'finance.adjustment.approve','value_adjustment',p_adjustment_id,jsonb_build_object('item_id',v_adjustment.item_id,'location_id',v_adjustment.location_id));
  return jsonb_build_object('adjustment_id',p_adjustment_id,'status','approved','avg_unit_cost',v_new_avg);
end; $$;

create or replace function public.finance_value_adjustments() returns table(id uuid,item_id uuid,location_id uuid,amount numeric,reason text,status text,requested_by uuid,approved_by uuid,requested_at timestamptz,approved_at timestamptz)
language plpgsql security definer set search_path=public,finance,pg_temp as $$
declare v_uid uuid:=auth.uid(); v_tenant uuid;
begin
  select tenant_id into v_tenant from memberships where user_id=v_uid and status='active' and role in('owner','finance') and (expires_at is null or expires_at>now()) order by created_at limit 1;
  if v_tenant is null then raise exception 'finance_access_required'; end if;
  return query select a.id,a.item_id,a.location_id,a.amount,a.reason,a.status,a.requested_by,a.approved_by,a.requested_at,a.approved_at from finance.value_adjustments a where a.tenant_id=v_tenant order by a.requested_at desc;
end; $$;

revoke all on function public.request_value_adjustment(uuid,uuid,numeric,text,text),public.approve_value_adjustment(uuid),public.finance_value_adjustments() from public,anon;
grant execute on function public.request_value_adjustment(uuid,uuid,numeric,text,text),public.approve_value_adjustment(uuid),public.finance_value_adjustments() to authenticated;

-- Keep financial values out of public audit payloads. The finance RPC remains the
-- only read path for monetary columns.
create or replace function public.receive_purchase_order_unchecked_aal1(p_order_id uuid,p_location_id uuid,p_quantity numeric,p_lot_code text,p_expires_on date,p_unit_cost numeric default null,p_idempotency_key text default null) returns jsonb
language plpgsql security definer set search_path=public,finance,pg_temp as $$
declare v_uid uuid:=auth.uid(); v_tenant uuid; v_line record; v_lot uuid; v_receipt uuid; v_doc jsonb; v_received numeric; v_old_value numeric:=0; v_old_avg numeric:=0; v_total_q numeric:=0; v_cost numeric:=0; v_new_value numeric:=0; v_new_avg numeric:=0;
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
 select coalesce(stock_value,0),coalesce(avg_unit_cost,0) into v_old_value,v_old_avg from finance.stock_values where tenant_id=v_tenant and item_id=v_line.item_id and location_id=p_location_id for update;
 v_cost:=coalesce(p_unit_cost,v_old_avg,0);
 insert into lots(tenant_id,item_id,lot_code,expires_on,condition) values(v_tenant,v_line.item_id,coalesce(nullif(trim(p_lot_code),''),'REC-'||to_char(clock_timestamp(),'YYYYMMDDHH24MISSMS')),p_expires_on,'usable') on conflict(tenant_id,item_id,lot_code) do update set expires_on=excluded.expires_on returning id into v_lot;
 v_doc:=public.post_stock_movement('receipt',v_line.item_id,p_location_id,null,v_lot,p_quantity,v_line.base_uom,'Recebimento de pedido '||p_order_id,coalesce(p_idempotency_key,gen_random_uuid()::text));
 insert into receipts(tenant_id,order_id,location_id,status,received_by,idempotency_key) values(v_tenant,p_order_id,p_location_id,'posted',v_uid,p_idempotency_key) returning id into v_receipt;
 insert into receipt_lines(tenant_id,receipt_id,order_line_id,lot_id,accepted_q,rejected_q) values(v_tenant,v_receipt,v_line.id,v_lot,p_quantity,0);
 v_received:=v_line.received_q+p_quantity;
 update purchase_order_lines set received_q=v_received,unit_cost=coalesce(p_unit_cost,unit_cost) where tenant_id=v_tenant and id=v_line.id;
 update purchase_orders set status=case when v_received=v_line.ordered_q then 'received' else 'partial' end where tenant_id=v_tenant and id=p_order_id;
 update purchase_requests set status='received' where tenant_id=v_tenant and id=(select request_id from purchase_orders where tenant_id=v_tenant and id=p_order_id) and v_received=v_line.ordered_q;
 select coalesce(sum(on_hand_q),0) into v_total_q from stock_positions where tenant_id=v_tenant and item_id=v_line.item_id and location_id=p_location_id and condition='usable';
 v_new_value:=v_old_value+(p_quantity*v_cost);
 v_new_avg:=case when v_total_q>0 then v_new_value/v_total_q else 0 end;
 insert into finance.stock_values(tenant_id,item_id,location_id,avg_unit_cost,stock_value,updated_at) values(v_tenant,v_line.item_id,p_location_id,v_new_avg,v_new_value,now()) on conflict(tenant_id,item_id,location_id) do update set avg_unit_cost=excluded.avg_unit_cost,stock_value=excluded.stock_value,updated_at=now();
 insert into audit_events(tenant_id,actor_id,action,entity,entity_id,payload) values(v_tenant,v_uid,'finance.cost_projection','purchase_order',p_order_id,jsonb_build_object('item_id',v_line.item_id,'location_id',p_location_id));
 return v_doc||jsonb_build_object('receipt_id',v_receipt,'avg_unit_cost',v_new_avg);
end; $$;
revoke all on function public.receive_purchase_order_unchecked_aal1(uuid,uuid,numeric,text,date,numeric,text) from public,anon,authenticated;
