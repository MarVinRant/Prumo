create or replace function public.set_event_status(p_event_id uuid,p_status text) returns boolean language plpgsql security definer set search_path=public,pg_temp as $$
declare v_uid uuid:=auth.uid(); v_tenant uuid; v_current text; v_allowed boolean:=false; v_count integer;
begin
 if v_uid is null then raise exception 'not_authenticated'; end if;
 if p_status not in('planned','separating','dispatched','operating','settling','cancelled') then raise exception 'invalid_event_status'; end if;
 select tenant_id,status into v_tenant,v_current from events where id=p_event_id for update;
 if v_tenant is null then raise exception 'event_not_found'; end if;
 if not exists(select 1 from memberships where tenant_id=v_tenant and user_id=v_uid and status='active' and role in('owner','manager')) then raise exception 'manager_required'; end if;
 v_allowed := (v_current='planned' and p_status in('separating','cancelled')) or (v_current='separating' and p_status in('dispatched','cancelled')) or (v_current='dispatched' and p_status='operating') or (v_current='operating' and p_status='settling');
 if not v_allowed then raise exception 'invalid_event_transition'; end if;
 update events set status=p_status where tenant_id=v_tenant and id=p_event_id;
 get diagnostics v_count = row_count;
 insert into audit_events(tenant_id,actor_id,action,entity,entity_id,payload) values(v_tenant,v_uid,'event.status','event',p_event_id,jsonb_build_object('from',v_current,'to',p_status));
 return v_count=1;
end; $$;

create or replace function public.reopen_event(p_event_id uuid,p_reason text) returns boolean language plpgsql security definer set search_path=public,pg_temp as $$
declare v_uid uuid:=auth.uid(); v_tenant uuid; v_status text; v_count integer;
begin
 if v_uid is null then raise exception 'not_authenticated'; end if;
 if nullif(trim(p_reason),'') is null then raise exception 'reopen_reason_required'; end if;
 select tenant_id,status into v_tenant,v_status from events where id=p_event_id for update;
 if v_tenant is null then raise exception 'event_not_found'; end if;
 if not exists(select 1 from memberships where tenant_id=v_tenant and user_id=v_uid and status='active' and role in('owner','manager')) then raise exception 'manager_required'; end if;
 if v_status<>'closed' then raise exception 'event_not_reopenable'; end if;
 update events set status='reopened' where tenant_id=v_tenant and id=p_event_id;
 get diagnostics v_count = row_count;
 insert into audit_events(tenant_id,actor_id,action,entity,entity_id,payload) values(v_tenant,v_uid,'event.reopen','event',p_event_id,jsonb_build_object('reason',trim(p_reason)));
 return v_count=1;
end; $$;

create or replace function public.consume_event_reservation(p_reservation_id uuid) returns boolean language plpgsql security definer set search_path=public,pg_temp as $$
declare v_uid uuid:=auth.uid(); v_tenant uuid; v_event uuid; v_item uuid; v_location uuid; v_lot uuid; v_qty numeric; v_status text; v_event_status text; v_pos uuid; v_on numeric; v_reserved numeric; v_count integer;
begin
 if v_uid is null then raise exception 'not_authenticated'; end if;
 select tenant_id,event_id,item_id,location_id,quantity,status into v_tenant,v_event,v_item,v_location,v_qty,v_status from reservations where id=p_reservation_id for update;
 if v_tenant is null then raise exception 'reservation_not_found'; end if;
 if not exists(select 1 from memberships where tenant_id=v_tenant and user_id=v_uid and status='active' and role in('owner','manager','operator')) then raise exception 'operation_scope_required'; end if;
 select status into v_event_status from events where tenant_id=v_tenant and id=v_event for update;
 if v_event_status not in('operating','settling') then raise exception 'event_not_operating'; end if;
 if v_status<>'firm' then return false; end if;
 select lot_id into v_lot from reservation_allocations where tenant_id=v_tenant and reservation_id=p_reservation_id order by created_at limit 1 for update;
 if v_lot is null then raise exception 'reservation_allocation_not_found'; end if;
 select id,on_hand_q,reserved_q into v_pos,v_on,v_reserved from stock_positions where tenant_id=v_tenant and item_id=v_item and location_id=v_location and lot_id=v_lot and condition='usable' for update;
 if v_pos is null or v_on<v_qty or v_reserved<v_qty then raise exception 'reservation_stock_conflict'; end if;
 update stock_positions set reserved_q=reserved_q-v_qty,updated_at=now() where id=v_pos;
 perform public.post_stock_movement('consumption',v_item,v_location,null,v_lot,v_qty,null,'Consumo de evento','event-reservation-'||p_reservation_id::text);
 update reservations set status='consumed' where tenant_id=v_tenant and id=p_reservation_id and status='firm';
 get diagnostics v_count = row_count;
 insert into audit_events(tenant_id,actor_id,action,entity,entity_id,payload) values(v_tenant,v_uid,'event.consume_reservation','reservation',p_reservation_id,jsonb_build_object('event_id',v_event,'quantity',v_qty,'lot_id',v_lot));
 return v_count=1;
end; $$;

create or replace function public.register_asset(p_item_id uuid,p_asset_tag text,p_condition text default 'usable') returns uuid language plpgsql security definer set search_path=public,pg_temp as $$
declare v_uid uuid:=auth.uid(); v_tenant uuid; v_id uuid;
begin
 if v_uid is null then raise exception 'not_authenticated'; end if;
 select tenant_id into v_tenant from memberships where user_id=v_uid and status='active' and role in('owner','manager') limit 1;
 if v_tenant is null then raise exception 'manager_required'; end if;
 if p_condition not in('usable','quarantine','damaged','lost','retired') then raise exception 'invalid_asset_condition'; end if;
 if not exists(select 1 from items where tenant_id=v_tenant and id=p_item_id and nature='asset' and status='active') then raise exception 'asset_item_required'; end if;
 insert into assets(tenant_id,item_id,asset_tag,condition,status) values(v_tenant,p_item_id,trim(p_asset_tag),p_condition,case when p_condition='retired' then 'retired' else 'available' end) returning id into v_id;
 insert into audit_events(tenant_id,actor_id,action,entity,entity_id,payload) values(v_tenant,v_uid,'asset.register','asset',v_id,jsonb_build_object('asset_tag',trim(p_asset_tag),'condition',p_condition));
 return v_id;
end; $$;

create or replace function public.dispatch_asset(p_asset_id uuid,p_location_id uuid,p_event_id uuid default null,p_responsible_user uuid default null,p_condition_out text default 'usable') returns uuid language plpgsql security definer set search_path=public,pg_temp as $$
declare v_uid uuid:=auth.uid(); v_tenant uuid; v_status text; v_condition text; v_custody uuid; v_responsible uuid;
begin
 if v_uid is null then raise exception 'not_authenticated'; end if;
 select tenant_id,status,condition into v_tenant,v_status,v_condition from assets where id=p_asset_id for update;
 if v_tenant is null then raise exception 'asset_not_found'; end if;
 if not exists(select 1 from memberships where tenant_id=v_tenant and user_id=v_uid and status='active' and role in('owner','manager','operator')) then raise exception 'operation_scope_required'; end if;
 if v_status not in('available','returned') or v_condition in('lost','retired') then raise exception 'asset_not_dispatchable'; end if;
 if not exists(select 1 from locations where tenant_id=v_tenant and id=p_location_id and status='active') then raise exception 'location_not_found'; end if;
 if p_event_id is not null and not exists(select 1 from events where tenant_id=v_tenant and id=p_event_id and status in('planned','separating','dispatched','operating')) then raise exception 'event_not_dispatchable'; end if;
 if exists(select 1 from asset_custodies where tenant_id=v_tenant and asset_id=p_asset_id and closed_at is null) then raise exception 'asset_already_in_custody'; end if;
 v_responsible:=coalesce(p_responsible_user,v_uid);
 insert into asset_custodies(tenant_id,asset_id,location_id,event_id,responsible_user,condition_out) values(v_tenant,p_asset_id,p_location_id,p_event_id,v_responsible,p_condition_out) returning id into v_custody;
 update assets set status='dispatched' where tenant_id=v_tenant and id=p_asset_id;
 insert into audit_events(tenant_id,actor_id,action,entity,entity_id,payload) values(v_tenant,v_uid,'asset.dispatch','asset',p_asset_id,jsonb_build_object('custody_id',v_custody,'event_id',p_event_id,'location_id',p_location_id));
 return v_custody;
end; $$;

create or replace function public.return_asset(p_asset_id uuid,p_condition_in text,p_location_id uuid default null) returns boolean language plpgsql security definer set search_path=public,pg_temp as $$
declare v_uid uuid:=auth.uid(); v_tenant uuid; v_custody uuid; v_count integer;
begin
 if v_uid is null then raise exception 'not_authenticated'; end if;
 if p_condition_in not in('usable','quarantine','damaged','lost','retired') then raise exception 'invalid_asset_condition'; end if;
 select tenant_id into v_tenant from assets where id=p_asset_id for update;
 if v_tenant is null then raise exception 'asset_not_found'; end if;
 if not exists(select 1 from memberships where tenant_id=v_tenant and user_id=v_uid and status='active' and role in('owner','manager','operator')) then raise exception 'operation_scope_required'; end if;
 select id into v_custody from asset_custodies where tenant_id=v_tenant and asset_id=p_asset_id and closed_at is null for update;
 if v_custody is null then raise exception 'open_custody_not_found'; end if;
 update asset_custodies set closed_at=now(),condition_in=p_condition_in,location_id=coalesce(p_location_id,location_id) where tenant_id=v_tenant and id=v_custody;
 update assets set condition=p_condition_in,status=case when p_condition_in='retired' then 'retired' else 'returned' end where tenant_id=v_tenant and id=p_asset_id;
 get diagnostics v_count = row_count;
 insert into audit_events(tenant_id,actor_id,action,entity,entity_id,payload) values(v_tenant,v_uid,'asset.return','asset',p_asset_id,jsonb_build_object('custody_id',v_custody,'condition_in',p_condition_in));
 return v_count=1;
end; $$;

create or replace function public.seed_demo_assets() returns uuid language plpgsql security definer set search_path=public,pg_temp as $$
declare v_uid uuid:=auth.uid(); v_tenant uuid; v_equ uuid; v_utl uuid;
begin
 if v_uid is null then raise exception 'not_authenticated'; end if;
 select tenant_id into v_tenant from memberships where user_id=v_uid and status='active' and role in('owner','manager') limit 1;
 if v_tenant is null then raise exception 'fixture_seed_requires_manager'; end if;
 select id into v_equ from items where tenant_id=v_tenant and sku='EQU-001';
 select id into v_utl from items where tenant_id=v_tenant and sku='UTL-001';
 if v_equ is not null then insert into assets(tenant_id,item_id,asset_tag,condition,status) values(v_tenant,v_equ,'DEMO-EQU-001','usable','available') on conflict(tenant_id,asset_tag) do nothing; end if;
 if v_utl is not null then insert into assets(tenant_id,item_id,asset_tag,condition,status) values(v_tenant,v_utl,'DEMO-UTL-001','usable','available') on conflict(tenant_id,asset_tag) do nothing; end if;
 return v_tenant;
end; $$;

revoke all on function public.set_event_status(uuid,text),public.reopen_event(uuid,text),public.consume_event_reservation(uuid),public.register_asset(uuid,text,text),public.dispatch_asset(uuid,uuid,uuid,uuid,text),public.return_asset(uuid,text,uuid),public.seed_demo_assets() from public,anon;
grant execute on function public.set_event_status(uuid,text),public.reopen_event(uuid,text),public.consume_event_reservation(uuid),public.register_asset(uuid,text,text),public.dispatch_asset(uuid,uuid,uuid,uuid,text),public.return_asset(uuid,text,uuid),public.seed_demo_assets() to authenticated;
