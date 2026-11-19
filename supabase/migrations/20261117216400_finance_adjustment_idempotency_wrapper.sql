-- Solicitações de ajuste monetário idempotentes e com conflito explícito.
create table if not exists private.finance_adjustment_idempotency(
  tenant_id uuid not null references public.organizations(id) on delete cascade,
  idempotency_key text not null,
  fingerprint text not null,
  result jsonb not null,
  created_at timestamptz not null default now(),
  primary key(tenant_id,idempotency_key)
);
revoke all on table private.finance_adjustment_idempotency from public,anon,authenticated;

alter function public.request_value_adjustment(uuid,uuid,numeric,text,text) rename to request_value_adjustment_unchecked;
revoke all on function public.request_value_adjustment_unchecked(uuid,uuid,numeric,text,text) from public,anon,authenticated;

create or replace function public.request_value_adjustment(p_item_id uuid,p_location_id uuid,p_amount numeric,p_reason text,p_idempotency_key text default null) returns jsonb
language plpgsql security definer set search_path=public,finance,private,pgcrypto,pg_temp as $$
declare v_uid uuid:=auth.uid(); v_tenant uuid; v_key text:=coalesce(p_idempotency_key,gen_random_uuid()::text); v_fingerprint text; v_saved_fingerprint text; v_result jsonb;
begin
  if v_uid is null then raise exception 'not_authenticated'; end if;
  select tenant_id into v_tenant from memberships where user_id=v_uid and status='active' and role in('owner','manager','finance') and (expires_at is null or expires_at>now()) order by created_at limit 1;
  if v_tenant is null then raise exception 'finance_adjustment_required'; end if;
  v_fingerprint:=md5(jsonb_build_object('item_id',p_item_id,'location_id',p_location_id,'amount',p_amount,'reason',trim(coalesce(p_reason,'')))::text);
  perform pg_advisory_xact_lock(hashtextextended(v_tenant::text||':'||v_key,0));
  select fingerprint,result into v_saved_fingerprint,v_result from private.finance_adjustment_idempotency where tenant_id=v_tenant and idempotency_key=v_key;
  if v_result is not null then
    if v_saved_fingerprint<>v_fingerprint then raise exception 'idempotency_payload_conflict'; end if;
    return v_result;
  end if;
  v_result:=public.request_value_adjustment_unchecked(p_item_id,p_location_id,p_amount,p_reason,v_key);
  insert into private.finance_adjustment_idempotency(tenant_id,idempotency_key,fingerprint,result) values(v_tenant,v_key,v_fingerprint,v_result);
  return v_result;
end; $$;

revoke all on function public.request_value_adjustment(uuid,uuid,numeric,text,text) from public,anon;
grant execute on function public.request_value_adjustment(uuid,uuid,numeric,text,text) to authenticated;
