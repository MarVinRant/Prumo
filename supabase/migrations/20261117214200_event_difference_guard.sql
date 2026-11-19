-- Tighten the event-difference command after the initial settlement migration.
create or replace function public.classify_event_difference(p_difference_id uuid,p_classification text,p_consumed_q numeric,p_reason text default null) returns jsonb
language plpgsql security definer set search_path=public,private,pg_temp as $$
declare v_uid uuid:=auth.uid(); v_tenant uuid; v_event uuid; v_reservation uuid; v_item uuid; v_location uuid; v_lot uuid; v_expected numeric; v_before numeric; v_remaining numeric; v_status text; v_event_status text; v_uom text; v_count integer; v_usable_q numeric;
begin
  perform private.require_aal2();
  if p_classification not in('returned','consumed','loss','damaged','unaccounted') then raise exception 'invalid_difference_classification'; end if;
  if p_consumed_q is null or p_consumed_q<0 then raise exception 'consumed_quantity_invalid'; end if;
  select tenant_id,event_id,reservation_id,item_id,location_id,lot_id,expected_q,consumed_q,status into v_tenant,v_event,v_reservation,v_item,v_location,v_lot,v_expected,v_before,v_status from event_differences where id=p_difference_id for update;
  if v_tenant is null then raise exception 'event_difference_not_found'; end if;
  select status into v_event_status from events where tenant_id=v_tenant and id=v_event;
  if v_event_status<>'settling' then raise exception 'event_difference_requires_settling'; end if;
  if not exists(select 1 from memberships where tenant_id=v_tenant and user_id=v_uid and status='active' and role in('owner','manager','operator')) then raise exception 'operation_scope_required'; end if;
  if v_status='approved' then return jsonb_build_object('status','approved'); end if;
  if p_consumed_q>v_expected then raise exception 'consumed_quantity_exceeds_expected'; end if;
  if p_consumed_q<v_before then raise exception 'consumed_quantity_cannot_decrease'; end if;
  select base_uom into v_uom from items where tenant_id=v_tenant and id=v_item;
  update stock_positions sp set reserved_q=sp.reserved_q-a.quantity,updated_at=now()
    from reservation_allocations a join reservations r on r.tenant_id=a.tenant_id and r.id=a.reservation_id
    where a.tenant_id=v_tenant and a.reservation_id=v_reservation and a.lot_id=v_lot and r.status='firm'
      and sp.tenant_id=a.tenant_id and sp.item_id=v_item and sp.location_id=v_location and sp.lot_id=v_lot and sp.condition='usable';
  update reservations set status='released' where tenant_id=v_tenant and id=v_reservation and status='firm';
  v_remaining:=p_consumed_q-v_before;
  if v_remaining>0 then
    perform public.post_stock_movement('consumption',v_item,v_location,null,v_lot,v_remaining,v_uom,'Consumo no acerto do evento '||v_event::text,'event-difference-consumption-'||p_difference_id::text);
  end if;
  v_remaining:=v_expected-p_consumed_q;
  if p_classification='loss' and v_remaining>0 then
    perform public.post_stock_movement('loss',v_item,v_location,null,v_lot,v_remaining,v_uom,'Perda no acerto do evento '||v_event::text,'event-difference-loss-'||p_difference_id::text);
  end if;
  if p_classification='damaged' and v_remaining>0 then
    select on_hand_q-reserved_q into v_usable_q from stock_positions where tenant_id=v_tenant and item_id=v_item and location_id=v_location and lot_id=v_lot and condition='usable' for update;
    if v_usable_q is null or v_usable_q<v_remaining then raise exception 'insufficient_available_stock'; end if;
    update stock_positions set on_hand_q=on_hand_q-v_remaining,updated_at=now() where tenant_id=v_tenant and item_id=v_item and location_id=v_location and lot_id=v_lot and condition='usable';
    insert into stock_positions(tenant_id,item_id,location_id,lot_id,condition,on_hand_q,reserved_q) values(v_tenant,v_item,v_location,v_lot,'damaged',v_remaining,0)
      on conflict(tenant_id,item_id,location_id,lot_id,condition) do update set on_hand_q=stock_positions.on_hand_q+excluded.on_hand_q,updated_at=now();
  end if;
  update event_differences set consumed_q=p_consumed_q,difference_q=v_expected-p_consumed_q,classification=p_classification,reason=nullif(trim(p_reason),''),created_by=v_uid where tenant_id=v_tenant and id=p_difference_id;
  get diagnostics v_count=row_count;
  insert into audit_events(tenant_id,actor_id,action,entity,entity_id,payload) values(v_tenant,v_uid,'event.difference.classify','event_difference',p_difference_id,jsonb_build_object('classification',p_classification,'consumed_q',p_consumed_q,'remaining_q',v_expected-p_consumed_q));
  return jsonb_build_object('status','classified','updated',v_count,'remaining_q',v_expected-p_consumed_q);
end; $$;
revoke all on function public.classify_event_difference(uuid,text,numeric,text) from public,anon;
grant execute on function public.classify_event_difference(uuid,text,numeric,text) to authenticated;
