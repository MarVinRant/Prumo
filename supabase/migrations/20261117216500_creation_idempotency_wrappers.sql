-- Criação de eventos e solicitações de compra idempotente após timeout.
create table if not exists private.event_creation_idempotency(
  tenant_id uuid not null references public.organizations(id) on delete cascade,
  idempotency_key text not null,
  fingerprint text not null,
  event_id uuid not null,
  created_at timestamptz not null default now(),
  primary key(tenant_id,idempotency_key)
);
create table if not exists private.purchase_request_idempotency(
  tenant_id uuid not null references public.organizations(id) on delete cascade,
  idempotency_key text not null,
  fingerprint text not null,
  request_id uuid not null,
  created_at timestamptz not null default now(),
  primary key(tenant_id,idempotency_key)
);
revoke all on table private.event_creation_idempotency,private.purchase_request_idempotency from public,anon,authenticated;

alter function public.create_event(text,text,text,timestamptz,timestamptz) rename to create_event_unchecked;
alter function public.create_purchase_request(uuid,uuid,numeric,date,text) rename to create_purchase_request_unchecked;
revoke all on function public.create_event_unchecked(text,text,text,timestamptz,timestamptz),public.create_purchase_request_unchecked(uuid,uuid,numeric,date,text) from public,anon,authenticated;

create or replace function public.create_event(p_name text,p_code text,p_venue text,p_starts_at timestamptz,p_ends_at timestamptz,p_idempotency_key text default null) returns uuid
language plpgsql security definer set search_path=public,private,pgcrypto,pg_temp as $$
declare v_uid uuid:=auth.uid(); v_tenant uuid; v_key text:=coalesce(p_idempotency_key,gen_random_uuid()::text); v_fingerprint text; v_saved_fingerprint text; v_event uuid;
begin
  if v_uid is null then raise exception 'not_authenticated'; end if;
  select tenant_id into v_tenant from memberships where user_id=v_uid and status='active' and (expires_at is null or expires_at>now()) limit 1;
  if v_tenant is null then raise exception 'membership_required'; end if;
  v_fingerprint:=md5(jsonb_build_object('name',trim(coalesce(p_name,'')),'code',trim(coalesce(p_code,'')),'venue',trim(coalesce(p_venue,'')),'starts_at',p_starts_at,'ends_at',p_ends_at)::text);
  perform pg_advisory_xact_lock(hashtextextended(v_tenant::text||':'||v_key,0));
  select fingerprint,event_id into v_saved_fingerprint,v_event from private.event_creation_idempotency where tenant_id=v_tenant and idempotency_key=v_key;
  if v_event is not null then
    if v_saved_fingerprint<>v_fingerprint then raise exception 'idempotency_payload_conflict'; end if;
    return v_event;
  end if;
  v_event:=public.create_event_unchecked(p_name,p_code,p_venue,p_starts_at,p_ends_at);
  insert into private.event_creation_idempotency(tenant_id,idempotency_key,fingerprint,event_id) values(v_tenant,v_key,v_fingerprint,v_event);
  return v_event;
end; $$;

create or replace function public.create_purchase_request(p_item_id uuid,p_location_id uuid,p_quantity numeric,p_needed_by date,p_reason text,p_idempotency_key text default null) returns uuid
language plpgsql security definer set search_path=public,private,pgcrypto,pg_temp as $$
declare v_uid uuid:=auth.uid(); v_tenant uuid; v_key text:=coalesce(p_idempotency_key,gen_random_uuid()::text); v_fingerprint text; v_saved_fingerprint text; v_request uuid;
begin
  if v_uid is null then raise exception 'not_authenticated'; end if;
  select tenant_id into v_tenant from memberships where user_id=v_uid and status='active' and (expires_at is null or expires_at>now()) limit 1;
  if v_tenant is null then raise exception 'membership_required'; end if;
  v_fingerprint:=md5(jsonb_build_object('item_id',p_item_id,'location_id',p_location_id,'quantity',p_quantity,'needed_by',p_needed_by,'reason',trim(coalesce(p_reason,'')))::text);
  perform pg_advisory_xact_lock(hashtextextended(v_tenant::text||':'||v_key,0));
  select fingerprint,request_id into v_saved_fingerprint,v_request from private.purchase_request_idempotency where tenant_id=v_tenant and idempotency_key=v_key;
  if v_request is not null then
    if v_saved_fingerprint<>v_fingerprint then raise exception 'idempotency_payload_conflict'; end if;
    return v_request;
  end if;
  v_request:=public.create_purchase_request_unchecked(p_item_id,p_location_id,p_quantity,p_needed_by,p_reason);
  insert into private.purchase_request_idempotency(tenant_id,idempotency_key,fingerprint,request_id) values(v_tenant,v_key,v_fingerprint,v_request);
  return v_request;
end; $$;

revoke all on function public.create_event(text,text,text,timestamptz,timestamptz,text),public.create_purchase_request(uuid,uuid,numeric,date,text,text) from public,anon;
grant execute on function public.create_event(text,text,text,timestamptz,timestamptz,text),public.create_purchase_request(uuid,uuid,numeric,date,text,text) to authenticated;
