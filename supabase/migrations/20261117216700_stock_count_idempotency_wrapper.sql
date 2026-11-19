-- Registro de contagem cega idempotente após timeout.
create table if not exists private.stock_count_idempotency(
  tenant_id uuid not null references public.organizations(id) on delete cascade,
  idempotency_key text not null,
  fingerprint text not null,
  count_id uuid not null,
  created_at timestamptz not null default now(),
  primary key(tenant_id,idempotency_key)
);
revoke all on table private.stock_count_idempotency from public,anon,authenticated;

alter function public.record_stock_count(uuid,uuid,uuid,numeric,text) rename to record_stock_count_unchecked;
revoke all on function public.record_stock_count_unchecked(uuid,uuid,uuid,numeric,text) from public,anon,authenticated;

create or replace function public.record_stock_count(p_item_id uuid,p_location_id uuid,p_lot_id uuid,p_counted_q numeric,p_reason text default null,p_idempotency_key text default null) returns uuid
language plpgsql security definer set search_path=public,private,pgcrypto,pg_temp as $$
declare v_uid uuid:=auth.uid(); v_tenant uuid; v_key text:=coalesce(p_idempotency_key,gen_random_uuid()::text); v_fingerprint text; v_saved_fingerprint text; v_count uuid;
begin
  if v_uid is null then raise exception 'not_authenticated'; end if;
  select tenant_id into v_tenant from memberships where user_id=v_uid and status='active' and (expires_at is null or expires_at>now()) limit 1;
  if v_tenant is null then raise exception 'membership_required'; end if;
  v_fingerprint:=md5(jsonb_build_object('item_id',p_item_id,'location_id',p_location_id,'lot_id',p_lot_id,'counted_q',p_counted_q,'reason',trim(coalesce(p_reason,'')))::text);
  perform pg_advisory_xact_lock(hashtextextended(v_tenant::text||':'||v_key,0));
  select fingerprint,count_id into v_saved_fingerprint,v_count from private.stock_count_idempotency where tenant_id=v_tenant and idempotency_key=v_key;
  if v_count is not null then
    if v_saved_fingerprint<>v_fingerprint then raise exception 'idempotency_payload_conflict'; end if;
    return v_count;
  end if;
  v_count:=public.record_stock_count_unchecked(p_item_id,p_location_id,p_lot_id,p_counted_q,p_reason);
  insert into private.stock_count_idempotency(tenant_id,idempotency_key,fingerprint,count_id) values(v_tenant,v_key,v_fingerprint,v_count);
  return v_count;
end; $$;

revoke all on function public.record_stock_count(uuid,uuid,uuid,numeric,text,text) from public,anon;
grant execute on function public.record_stock_count(uuid,uuid,uuid,numeric,text,text) to authenticated;
