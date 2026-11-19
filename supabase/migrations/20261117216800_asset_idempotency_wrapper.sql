-- Comandos de ativos idempotentes para retries de rede e proteção contra payload divergente.
create table if not exists private.asset_command_idempotency(
  tenant_id uuid not null references public.organizations(id) on delete cascade,
  command text not null check(command in('register','dispatch','return')),
  idempotency_key text not null,
  fingerprint text not null,
  result_id uuid,
  result_bool boolean,
  created_at timestamptz not null default now(),
  primary key(tenant_id,command,idempotency_key)
);
revoke all on table private.asset_command_idempotency from public,anon,authenticated;

alter function public.register_asset(uuid,text,text) rename to register_asset_unchecked_idempotent;
alter function public.dispatch_asset(uuid,uuid,uuid,uuid,text) rename to dispatch_asset_unchecked_idempotent;
alter function public.return_asset(uuid,text,uuid) rename to return_asset_unchecked_idempotent;
revoke all on function public.register_asset_unchecked_idempotent(uuid,text,text),public.dispatch_asset_unchecked_idempotent(uuid,uuid,uuid,uuid,text),public.return_asset_unchecked_idempotent(uuid,text,uuid) from public,anon,authenticated;

create or replace function public.register_asset(p_item_id uuid,p_asset_tag text,p_condition text default 'usable',p_idempotency_key text default null) returns uuid
language plpgsql security definer set search_path=public,private,pgcrypto,pg_temp as $$
declare v_uid uuid:=auth.uid(); v_tenant uuid; v_key text:=coalesce(p_idempotency_key,gen_random_uuid()::text); v_fingerprint text; v_saved_fingerprint text; v_result uuid;
begin
  if v_uid is null then raise exception 'not_authenticated'; end if;
  select tenant_id into v_tenant from memberships where user_id=v_uid and status='active' and role in('owner','manager') and (expires_at is null or expires_at>now()) limit 1;
  if v_tenant is null then raise exception 'manager_required'; end if;
  v_fingerprint:=md5(jsonb_build_object('item_id',p_item_id,'asset_tag',trim(coalesce(p_asset_tag,'')),'condition',coalesce(p_condition,'usable'))::text);
  perform pg_advisory_xact_lock(hashtextextended(v_tenant::text||':asset:register:'||v_key,0));
  select fingerprint,result_id into v_saved_fingerprint,v_result from private.asset_command_idempotency where tenant_id=v_tenant and command='register' and idempotency_key=v_key;
  if v_result is not null then
    if v_saved_fingerprint<>v_fingerprint then raise exception 'idempotency_payload_conflict'; end if;
    return v_result;
  end if;
  v_result:=public.register_asset_unchecked_idempotent(p_item_id,p_asset_tag,p_condition);
  insert into private.asset_command_idempotency(tenant_id,command,idempotency_key,fingerprint,result_id) values(v_tenant,'register',v_key,v_fingerprint,v_result);
  return v_result;
end; $$;

create or replace function public.dispatch_asset(p_asset_id uuid,p_location_id uuid,p_event_id uuid default null,p_responsible_user uuid default null,p_condition_out text default 'usable',p_idempotency_key text default null) returns uuid
language plpgsql security definer set search_path=public,private,pgcrypto,pg_temp as $$
declare v_uid uuid:=auth.uid(); v_tenant uuid; v_key text:=coalesce(p_idempotency_key,gen_random_uuid()::text); v_fingerprint text; v_saved_fingerprint text; v_result uuid;
begin
  if v_uid is null then raise exception 'not_authenticated'; end if;
  select tenant_id into v_tenant from assets where id=p_asset_id;
  if v_tenant is null then raise exception 'asset_not_found'; end if;
  v_fingerprint:=md5(jsonb_build_object('asset_id',p_asset_id,'location_id',p_location_id,'event_id',p_event_id,'responsible_user',p_responsible_user,'condition_out',coalesce(p_condition_out,'usable'))::text);
  perform pg_advisory_xact_lock(hashtextextended(v_tenant::text||':asset:dispatch:'||v_key,0));
  select fingerprint,result_id into v_saved_fingerprint,v_result from private.asset_command_idempotency where tenant_id=v_tenant and command='dispatch' and idempotency_key=v_key;
  if v_result is not null then
    if v_saved_fingerprint<>v_fingerprint then raise exception 'idempotency_payload_conflict'; end if;
    return v_result;
  end if;
  v_result:=public.dispatch_asset_unchecked_idempotent(p_asset_id,p_location_id,p_event_id,p_responsible_user,p_condition_out);
  insert into private.asset_command_idempotency(tenant_id,command,idempotency_key,fingerprint,result_id) values(v_tenant,'dispatch',v_key,v_fingerprint,v_result);
  return v_result;
end; $$;

create or replace function public.return_asset(p_asset_id uuid,p_condition_in text,p_location_id uuid default null,p_idempotency_key text default null) returns boolean
language plpgsql security definer set search_path=public,private,pgcrypto,pg_temp as $$
declare v_uid uuid:=auth.uid(); v_tenant uuid; v_key text:=coalesce(p_idempotency_key,gen_random_uuid()::text); v_fingerprint text; v_saved_fingerprint text; v_result boolean;
begin
  if v_uid is null then raise exception 'not_authenticated'; end if;
  select tenant_id into v_tenant from assets where id=p_asset_id;
  if v_tenant is null then raise exception 'asset_not_found'; end if;
  v_fingerprint:=md5(jsonb_build_object('asset_id',p_asset_id,'condition_in',p_condition_in,'location_id',p_location_id)::text);
  perform pg_advisory_xact_lock(hashtextextended(v_tenant::text||':asset:return:'||v_key,0));
  select fingerprint,result_bool into v_saved_fingerprint,v_result from private.asset_command_idempotency where tenant_id=v_tenant and command='return' and idempotency_key=v_key;
  if v_saved_fingerprint is not null then
    if v_saved_fingerprint<>v_fingerprint then raise exception 'idempotency_payload_conflict'; end if;
    return coalesce(v_result,false);
  end if;
  v_result:=public.return_asset_unchecked_idempotent(p_asset_id,p_condition_in,p_location_id);
  insert into private.asset_command_idempotency(tenant_id,command,idempotency_key,fingerprint,result_bool) values(v_tenant,'return',v_key,v_fingerprint,v_result);
  return v_result;
end; $$;

revoke all on function public.register_asset(uuid,text,text,text),public.dispatch_asset(uuid,uuid,uuid,uuid,text,text),public.return_asset(uuid,text,uuid,text) from public,anon;
grant execute on function public.register_asset(uuid,text,text,text),public.dispatch_asset(uuid,uuid,uuid,uuid,text,text),public.return_asset(uuid,text,uuid,text) to authenticated;
