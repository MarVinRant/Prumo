create table if not exists public.event_manifest_versions(
  id uuid primary key default gen_random_uuid(),
  tenant_id uuid not null references public.organizations(id) on delete cascade,
  event_id uuid not null,
  version integer not null check(version>0),
  status text not null default 'dispatched' check(status in('draft','dispatched','closed')),
  created_by uuid not null references auth.users(id),
  created_at timestamptz not null default now(),
  unique(tenant_id,event_id,version),
  unique(tenant_id,id),
  foreign key(tenant_id,event_id) references public.events(tenant_id,id) on delete cascade
);

create table if not exists public.event_manifest_lines(
  id uuid primary key default gen_random_uuid(),
  tenant_id uuid not null references public.organizations(id) on delete cascade,
  manifest_id uuid not null,
  reservation_id uuid not null,
  item_id uuid not null,
  location_id uuid not null,
  lot_id uuid not null,
  planned_q numeric(20,6) not null check(planned_q>0),
  dispatched_q numeric(20,6) not null check(dispatched_q>0),
  created_at timestamptz not null default now(),
  unique(tenant_id,manifest_id,reservation_id,lot_id),
  unique(tenant_id,id),
  foreign key(tenant_id,manifest_id) references public.event_manifest_versions(tenant_id,id) on delete cascade,
  foreign key(tenant_id,reservation_id) references public.reservations(tenant_id,id),
  foreign key(tenant_id,item_id) references public.items(tenant_id,id),
  foreign key(tenant_id,location_id) references public.locations(tenant_id,id),
  foreign key(tenant_id,lot_id) references public.lots(tenant_id,id)
);

create table if not exists public.event_differences(
  id uuid primary key default gen_random_uuid(),
  tenant_id uuid not null references public.organizations(id) on delete cascade,
  event_id uuid not null,
  manifest_line_id uuid not null,
  reservation_id uuid not null,
  item_id uuid not null,
  location_id uuid not null,
  lot_id uuid not null,
  expected_q numeric(20,6) not null check(expected_q>=0),
  consumed_q numeric(20,6) not null default 0 check(consumed_q>=0),
  difference_q numeric(20,6) not null check(difference_q>=0),
  classification text check(classification in('none','returned','consumed','loss','damaged','unaccounted')),
  status text not null default 'pending' check(status in('pending','approved')),
  reason text,
  created_by uuid not null references auth.users(id),
  approved_by uuid references auth.users(id),
  approved_at timestamptz,
  created_at timestamptz not null default now(),
  unique(tenant_id,manifest_line_id),
  unique(tenant_id,id),
  foreign key(tenant_id,event_id) references public.events(tenant_id,id) on delete cascade,
  foreign key(tenant_id,manifest_line_id) references public.event_manifest_lines(tenant_id,id) on delete cascade,
  foreign key(tenant_id,reservation_id) references public.reservations(tenant_id,id),
  foreign key(tenant_id,item_id) references public.items(tenant_id,id),
  foreign key(tenant_id,location_id) references public.locations(tenant_id,id),
  foreign key(tenant_id,lot_id) references public.lots(tenant_id,id),
  check(consumed_q<=expected_q),
  check(difference_q=expected_q-consumed_q),
  check(status='pending' or classification is not null)
);

alter table public.event_manifest_versions enable row level security;
alter table public.event_manifest_lines enable row level security;
alter table public.event_differences enable row level security;
drop policy if exists tenant_select on public.event_manifest_versions;
create policy tenant_select on public.event_manifest_versions for select to authenticated using(private.is_member(tenant_id));
drop policy if exists tenant_select on public.event_manifest_lines;
create policy tenant_select on public.event_manifest_lines for select to authenticated using(private.is_member(tenant_id));
drop policy if exists tenant_select on public.event_differences;
create policy tenant_select on public.event_differences for select to authenticated using(private.is_member(tenant_id));
grant select on public.event_manifest_versions,public.event_manifest_lines,public.event_differences to authenticated;

create or replace function public.create_event_manifest_unchecked_aal1(p_event_id uuid) returns uuid
language plpgsql security definer set search_path=public,pg_temp as $$
declare v_uid uuid:=auth.uid(); v_tenant uuid; v_status text; v_manifest uuid; v_version integer;
begin
  select tenant_id,status into v_tenant,v_status from events where id=p_event_id for update;
  if v_tenant is null then raise exception 'event_not_found'; end if;
  if v_status<>'separating' then raise exception 'event_manifest_requires_separating'; end if;
  select coalesce(max(version),0)+1 into v_version from event_manifest_versions where tenant_id=v_tenant and event_id=p_event_id;
  insert into event_manifest_versions(tenant_id,event_id,version,status,created_by) values(v_tenant,p_event_id,v_version,'dispatched',v_uid) returning id into v_manifest;
  insert into event_manifest_lines(tenant_id,manifest_id,reservation_id,item_id,location_id,lot_id,planned_q,dispatched_q)
    select r.tenant_id,v_manifest,r.id,r.item_id,r.location_id,a.lot_id,r.quantity,a.quantity
    from reservations r join reservation_allocations a on a.tenant_id=r.tenant_id and a.reservation_id=r.id
    where r.tenant_id=v_tenant and r.event_id=p_event_id and r.status='firm';
  insert into audit_events(tenant_id,actor_id,action,entity,entity_id,payload)
    values(v_tenant,v_uid,'event.manifest.create','event_manifest',v_manifest,jsonb_build_object('event_id',p_event_id,'version',v_version));
  return v_manifest;
end; $$;

create or replace function public.prepare_event_settlement_unchecked_aal1(p_event_id uuid) returns integer
language plpgsql security definer set search_path=public,pg_temp as $$
declare v_uid uuid:=auth.uid(); v_tenant uuid; v_manifest uuid; v_count integer;
begin
  select tenant_id into v_tenant from events where id=p_event_id for update;
  if v_tenant is null then raise exception 'event_not_found'; end if;
  select id into v_manifest from event_manifest_versions where tenant_id=v_tenant and event_id=p_event_id order by version desc limit 1;
  if v_manifest is null then return 0; end if;
  insert into event_differences(tenant_id,event_id,manifest_line_id,reservation_id,item_id,location_id,lot_id,expected_q,consumed_q,difference_q,classification,status,reason,created_by,approved_by,approved_at)
    select ml.tenant_id,p_event_id,ml.id,ml.reservation_id,ml.item_id,ml.location_id,ml.lot_id,ml.dispatched_q,
      case when r.status='consumed' then ml.dispatched_q else 0 end,
      case when r.status='consumed' then 0 else ml.dispatched_q end,
      case when r.status='consumed' then 'none' else null end,
      case when r.status='consumed' then 'approved' else 'pending' end,
      case when r.status='consumed' then 'Sem diferença' else null end,
      v_uid,
      case when r.status='consumed' then v_uid else null end,
      case when r.status='consumed' then now() else null end
    from event_manifest_lines ml join reservations r on r.tenant_id=ml.tenant_id and r.id=ml.reservation_id
    where ml.tenant_id=v_tenant and ml.manifest_id=v_manifest
    on conflict(tenant_id,manifest_line_id) do nothing;
  get diagnostics v_count=row_count;
  insert into audit_events(tenant_id,actor_id,action,entity,entity_id,payload)
    values(v_tenant,v_uid,'event.settlement.prepare','event',p_event_id,jsonb_build_object('manifest_id',v_manifest,'differences',v_count));
  return v_count;
end; $$;

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
  if p_classification in('loss') and v_remaining>0 then
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

create or replace function public.approve_event_difference(p_difference_id uuid) returns boolean
language plpgsql security definer set search_path=public,private,pg_temp as $$
declare v_uid uuid:=auth.uid(); v_tenant uuid; v_status text; v_classification text; v_count integer;
begin
  perform private.require_aal2();
  select tenant_id,status,classification into v_tenant,v_status,v_classification from event_differences where id=p_difference_id for update;
  if v_tenant is null then raise exception 'event_difference_not_found'; end if;
  if not exists(select 1 from memberships where tenant_id=v_tenant and user_id=v_uid and status='active' and role in('owner','manager')) then raise exception 'difference_approval_required'; end if;
  if v_classification is null then raise exception 'difference_classification_required'; end if;
  if v_status='approved' then return true; end if;
  update event_differences set status='approved',approved_by=v_uid,approved_at=now() where tenant_id=v_tenant and id=p_difference_id and status='pending';
  get diagnostics v_count=row_count;
  insert into audit_events(tenant_id,actor_id,action,entity,entity_id,payload) values(v_tenant,v_uid,'event.difference.approve','event_difference',p_difference_id,jsonb_build_object('classification',v_classification));
  return v_count=1;
end; $$;

create or replace function public.set_event_status_unchecked_aal1(p_event_id uuid,p_status text) returns boolean
language plpgsql security definer set search_path=public,private,pg_temp as $$
declare v_uid uuid:=auth.uid(); v_tenant uuid; v_current text; v_allowed boolean:=false; v_count integer;
begin
  if v_uid is null then raise exception 'not_authenticated'; end if;
  if p_status not in('planned','separating','dispatched','operating','settling','cancelled') then raise exception 'invalid_event_status'; end if;
  select tenant_id,status into v_tenant,v_current from events where id=p_event_id for update;
  if v_tenant is null then raise exception 'event_not_found'; end if;
  if not exists(select 1 from memberships where tenant_id=v_tenant and user_id=v_uid and status='active' and role in('owner','manager')) then raise exception 'manager_required'; end if;
  v_allowed := (v_current='planned' and p_status in('separating','cancelled')) or (v_current='reopened' and p_status='separating') or (v_current='separating' and p_status in('dispatched','cancelled')) or (v_current='dispatched' and p_status='operating') or (v_current='operating' and p_status='settling');
  if not v_allowed then raise exception 'invalid_event_transition'; end if;
  if v_current='separating' and p_status='dispatched' then perform public.create_event_manifest_unchecked_aal1(p_event_id); end if;
  if v_current='operating' and p_status='settling' then perform public.prepare_event_settlement_unchecked_aal1(p_event_id); end if;
  update events set status=p_status where tenant_id=v_tenant and id=p_event_id;
  get diagnostics v_count=row_count;
  insert into audit_events(tenant_id,actor_id,action,entity,entity_id,payload) values(v_tenant,v_uid,'event.status','event',p_event_id,jsonb_build_object('from',v_current,'to',p_status));
  return v_count=1;
end; $$;

create or replace function public.close_event_unchecked_aal1(p_event_id uuid,p_reason text) returns boolean
language plpgsql security definer set search_path=public,private,pg_temp as $$
declare v_uid uuid:=auth.uid(); v_tenant uuid; v_open numeric; v_unapproved numeric; v_changed boolean; v_count integer;
begin
  select tenant_id into v_tenant from memberships where user_id=v_uid and status='active' and role in('owner','manager') limit 1;
  if v_tenant is null then raise exception 'manager_required'; end if;
  select count(*) into v_open from reservations where tenant_id=v_tenant and event_id=p_event_id and status in('firm','draft');
  if v_open>0 then raise exception 'open_reservations_block_close'; end if;
  select count(*) into v_unapproved from event_differences where tenant_id=v_tenant and event_id=p_event_id and status<>'approved';
  if v_unapproved>0 then raise exception 'unclassified_differences'; end if;
  update events set status='closed' where tenant_id=v_tenant and id=p_event_id and status in('settling','operating');
  get diagnostics v_count=row_count; v_changed:=v_count>0;
  if not v_changed then raise exception 'event_not_closable'; end if;
  update event_manifest_versions set status='closed' where tenant_id=v_tenant and event_id=p_event_id and status='dispatched';
  insert into audit_events(tenant_id,actor_id,action,entity,entity_id,payload) values(v_tenant,v_uid,'event.close','event',p_event_id,jsonb_build_object('reason',p_reason));
  return true;
end; $$;

revoke all on function public.create_event_manifest_unchecked_aal1(uuid),public.prepare_event_settlement_unchecked_aal1(uuid) from public,anon,authenticated;
revoke all on function public.classify_event_difference(uuid,text,numeric,text),public.approve_event_difference(uuid) from public,anon;
grant execute on function public.classify_event_difference(uuid,text,numeric,text),public.approve_event_difference(uuid) to authenticated;
