-- Operational alerts are durable workflow records: acknowledgement does not resolve
-- the cause, and resolution is a privileged, auditable action.
create table if not exists public.alert_acknowledgements(
  id uuid primary key default gen_random_uuid(),
  tenant_id uuid not null references public.organizations(id) on delete cascade,
  alert_id uuid not null references public.alerts(id) on delete cascade,
  membership_id uuid not null references public.memberships(id) on delete cascade,
  acknowledged_at timestamptz not null default now(),
  unique(tenant_id,alert_id,membership_id)
);

alter table public.alert_acknowledgements enable row level security;
drop policy if exists tenant_select on public.alert_acknowledgements;
create policy tenant_select on public.alert_acknowledgements
  for select to authenticated using(private.is_member(tenant_id));
revoke all on table public.alert_acknowledgements from anon,authenticated;
grant select on table public.alert_acknowledgements to authenticated;

create or replace function public.acknowledge_alert(p_alert_id uuid) returns boolean
language plpgsql security definer set search_path=public,private,pg_temp as $$
declare
  v_uid uuid:=auth.uid();
  v_tenant uuid;
  v_membership uuid;
  v_status text;
begin
  if v_uid is null then raise exception 'not_authenticated'; end if;
  select m.tenant_id,m.id into v_tenant,v_membership
    from memberships m
   where m.user_id=v_uid and m.status='active'
     and (m.expires_at is null or m.expires_at>now())
   order by m.created_at
   limit 1;
  if v_tenant is null then raise exception 'membership_required'; end if;
  select status into v_status from alerts where tenant_id=v_tenant and id=p_alert_id for update;
  if v_status is null then raise exception 'alert_not_found'; end if;
  insert into alert_acknowledgements(tenant_id,alert_id,membership_id)
  values(v_tenant,p_alert_id,v_membership)
  on conflict(tenant_id,alert_id,membership_id) do nothing;
  update alerts set status='acknowledged'
   where tenant_id=v_tenant and id=p_alert_id and status='new';
  insert into audit_events(tenant_id,actor_id,action,entity,entity_id,payload)
  values(v_tenant,v_uid,'alert.acknowledge','alert',p_alert_id,jsonb_build_object('previous_status',v_status));
  return true;
end; $$;

create or replace function public.resolve_alert(p_alert_id uuid,p_reason text) returns boolean
language plpgsql security definer set search_path=public,private,pg_temp as $$
declare
  v_uid uuid:=auth.uid();
  v_tenant uuid;
  v_status text;
  v_role text;
begin
  perform private.require_aal2();
  select m.tenant_id,m.role into v_tenant,v_role
    from memberships m
   where m.user_id=v_uid and m.status='active'
     and (m.expires_at is null or m.expires_at>now())
     and m.role in('owner','manager')
   order by m.created_at
   limit 1;
  if v_tenant is null then raise exception 'manager_membership_required'; end if;
  if nullif(trim(coalesce(p_reason,'')),'') is null then raise exception 'reason_required'; end if;
  select status into v_status from alerts where tenant_id=v_tenant and id=p_alert_id for update;
  if v_status is null then raise exception 'alert_not_found'; end if;
  if v_status='resolved' then return true; end if;
  update alerts set status='resolved',resolved_at=now()
   where tenant_id=v_tenant and id=p_alert_id;
  insert into audit_events(tenant_id,actor_id,action,entity,entity_id,payload)
  values(v_tenant,v_uid,'alert.resolve','alert',p_alert_id,jsonb_build_object('previous_status',v_status,'reason',trim(p_reason)));
  return true;
end; $$;

revoke all on function public.acknowledge_alert(uuid),public.resolve_alert(uuid,text) from public,anon;
grant execute on function public.acknowledge_alert(uuid),public.resolve_alert(uuid,text) to authenticated;

-- Re-running a refresh must not erase a user's acknowledgement or resolution.
-- A future condition gets a new dedupe key from its target/cycle and is therefore
-- still able to create a new occurrence.
create or replace function public.refresh_operational_alerts() returns integer
language plpgsql security definer set search_path=public,pg_temp as $$
declare v_uid uuid:=auth.uid(); v_tenant uuid; v_count integer:=0; v_added integer;
begin
 if v_uid is null then raise exception 'not_authenticated'; end if;
 select tenant_id into v_tenant from memberships where user_id=v_uid and status='active' limit 1;
 if v_tenant is null then raise exception 'membership_required'; end if;
 insert into alerts(tenant_id,kind,item_id,status,dedupe_key,message)
 select v_tenant,'rupture',sp.item_id,'new','rupture:'||sp.item_id::text||':'||sp.location_id::text,'Saldo abaixo do mínimo em '||l.name
 from stock_positions sp join item_location_policies p on p.tenant_id=sp.tenant_id and p.item_id=sp.item_id and p.location_id=sp.location_id join locations l on l.tenant_id=sp.tenant_id and l.id=sp.location_id
 where sp.tenant_id=v_tenant and sp.condition='usable' and sp.on_hand_q-sp.reserved_q<=p.min_q
 on conflict(tenant_id,dedupe_key) do nothing;
 get diagnostics v_added=row_count; v_count:=v_count+v_added;
 insert into alerts(tenant_id,kind,item_id,status,dedupe_key,message)
 select distinct v_tenant,'expiry',l.item_id,'new','expiry:'||l.id::text,'Lote '||l.lot_code||' vence em '||to_char(l.expires_on,'DD/MM/YYYY')
 from lots l join stock_positions sp on sp.tenant_id=l.tenant_id and sp.lot_id=l.id and sp.on_hand_q>0
 where l.tenant_id=v_tenant and l.condition='usable' and l.expires_on is not null and l.expires_on<=current_date+interval '7 days'
 on conflict(tenant_id,dedupe_key) do nothing;
 get diagnostics v_added=row_count; v_count:=v_count+v_added;
 insert into alerts(tenant_id,kind,event_id,status,dedupe_key,message)
 select pr.tenant_id,pr.event_id,'event_shortage','new','event_shortage:'||pr.event_id::text||':'||pr.item_id::text,'Reserva abaixo do planejado para o evento'
 from event_plan_lines pr left join (select tenant_id,event_id,item_id,sum(quantity) quantity from reservations where status in('firm','consumed') group by tenant_id,event_id,item_id) r on r.tenant_id=pr.tenant_id and r.event_id=pr.event_id and r.item_id=pr.item_id
 where pr.tenant_id=v_tenant and coalesce(r.quantity,0)<pr.planned_q
 on conflict(tenant_id,dedupe_key) do nothing;
 get diagnostics v_added=row_count; v_count:=v_count+v_added;
 insert into alerts(tenant_id,kind,status,dedupe_key,message)
 select v_tenant,'purchase_delay','new','purchase_delay:'||id::text,'Solicitação de compra vencida sem recebimento'
 from purchase_requests where tenant_id=v_tenant and needed_by<current_date and status not in('received','cancelled','rejected')
 on conflict(tenant_id,dedupe_key) do nothing;
 get diagnostics v_added=row_count; v_count:=v_count+v_added;
 return v_count;
end; $$;

create or replace function public.refresh_return_pending_alerts() returns integer
language plpgsql security definer set search_path=public,pg_temp as $$
declare v_uid uuid:=auth.uid(); v_tenant uuid; v_count integer;
begin
 if v_uid is null then raise exception 'not_authenticated'; end if;
 select tenant_id into v_tenant from memberships where user_id=v_uid and status='active' limit 1;
 if v_tenant is null then raise exception 'membership_required'; end if;
 insert into alerts(tenant_id,kind,event_id,status,dedupe_key,message)
 select ac.tenant_id,'return_pending',ac.event_id,'new','return_pending:'||ac.id::text,'Ativo com retorno pendente após o encerramento do evento'
 from asset_custodies ac join events e on e.tenant_id=ac.tenant_id and e.id=ac.event_id
 where ac.tenant_id=v_tenant and ac.closed_at is null and e.ends_at<now() and ac.event_id is not null
 on conflict(tenant_id,dedupe_key) do nothing;
 get diagnostics v_count=row_count;
 return v_count;
end; $$;

revoke all on function public.refresh_operational_alerts(),public.refresh_return_pending_alerts() from public,anon;
grant execute on function public.refresh_operational_alerts(),public.refresh_return_pending_alerts() to authenticated;
