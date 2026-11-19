alter table public.reservations add column if not exists source text not null default 'plan' check(source in('plan','replenishment'));

create or replace function public.replenish_event_material(p_event_id uuid,p_item_id uuid,p_location_id uuid,p_quantity numeric,p_lot_id uuid default null) returns uuid
language plpgsql security definer set search_path=public,private,pg_temp as $$
declare v_uid uuid:=auth.uid(); v_tenant uuid; v_status text; v_lot uuid; v_res uuid; v_manifest uuid;
begin
  perform private.require_aal2();
  if p_quantity is null or p_quantity<=0 then raise exception 'quantity_must_be_positive'; end if;
  select tenant_id,status into v_tenant,v_status from events where id=p_event_id for update;
  if v_tenant is null then raise exception 'event_not_found'; end if;
  if v_status not in('operating','settling') then raise exception 'event_not_operating'; end if;
  if not exists(select 1 from memberships where tenant_id=v_tenant and user_id=v_uid and status='active' and role in('owner','manager','operator')) then raise exception 'operation_scope_required'; end if;
  if p_lot_id is null then
    select sp.lot_id into v_lot from stock_positions sp join lots l on l.tenant_id=sp.tenant_id and l.id=sp.lot_id
      where sp.tenant_id=v_tenant and sp.item_id=p_item_id and sp.location_id=p_location_id and sp.condition='usable' and l.condition='usable'
        and (l.expires_on is null or l.expires_on>=current_date) and sp.on_hand_q-sp.reserved_q>=p_quantity
      order by l.expires_on nulls last,sp.id limit 1 for update;
  else
    select sp.lot_id into v_lot from stock_positions sp join lots l on l.tenant_id=sp.tenant_id and l.id=sp.lot_id
      where sp.tenant_id=v_tenant and sp.item_id=p_item_id and sp.location_id=p_location_id and sp.lot_id=p_lot_id and sp.condition='usable' and l.condition='usable'
        and (l.expires_on is null or l.expires_on>=current_date) and sp.on_hand_q-sp.reserved_q>=p_quantity for update;
  end if;
  if v_lot is null then raise exception 'insufficient_reservable_stock'; end if;
  update stock_positions set reserved_q=reserved_q+p_quantity,updated_at=now()
    where tenant_id=v_tenant and item_id=p_item_id and location_id=p_location_id and lot_id=v_lot and condition='usable' and on_hand_q-reserved_q>=p_quantity;
  if not found then raise exception 'reservation_conflict'; end if;
  insert into reservations(tenant_id,event_id,item_id,location_id,quantity,status,source) values(v_tenant,p_event_id,p_item_id,p_location_id,p_quantity,'firm','replenishment') returning id into v_res;
  insert into reservation_allocations(tenant_id,reservation_id,lot_id,quantity) values(v_tenant,v_res,v_lot,p_quantity);
  select id into v_manifest from event_manifest_versions where tenant_id=v_tenant and event_id=p_event_id order by version desc limit 1;
  if v_manifest is not null then
    insert into event_manifest_lines(tenant_id,manifest_id,reservation_id,item_id,location_id,lot_id,planned_q,dispatched_q) values(v_tenant,v_manifest,v_res,p_item_id,p_location_id,v_lot,p_quantity,p_quantity);
    if v_status='settling' then perform public.prepare_event_settlement_unchecked_aal1(p_event_id); end if;
  end if;
  insert into audit_events(tenant_id,actor_id,action,entity,entity_id,payload) values(v_tenant,v_uid,'event.replenish','reservation',v_res,jsonb_build_object('event_id',p_event_id,'lot_id',v_lot,'quantity',p_quantity));
  return v_res;
end; $$;
revoke all on function public.replenish_event_material(uuid,uuid,uuid,numeric,uuid) from public,anon;
grant execute on function public.replenish_event_material(uuid,uuid,uuid,numeric,uuid) to authenticated;
