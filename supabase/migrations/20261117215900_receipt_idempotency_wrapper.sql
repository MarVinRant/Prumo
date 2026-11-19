-- Serializa o recebimento por chave e rejeita a mesma chave com payload diferente.
create table if not exists private.receipt_idempotency(
  tenant_id uuid not null references public.organizations(id) on delete cascade,
  idempotency_key text not null,
  fingerprint text not null,
  result jsonb not null,
  created_at timestamptz not null default now(),
  primary key(tenant_id,idempotency_key)
);
revoke all on table private.receipt_idempotency from public,anon,authenticated;

alter function public.receive_purchase_order_split(uuid,uuid,numeric,numeric,numeric,text,date,numeric,text) rename to receive_purchase_order_split_unchecked;
revoke all on function public.receive_purchase_order_split_unchecked(uuid,uuid,numeric,numeric,numeric,text,date,numeric,text) from public,anon,authenticated;

create or replace function public.receive_purchase_order_split(
  p_order_id uuid,
  p_location_id uuid,
  p_accepted_q numeric,
  p_blocked_q numeric,
  p_rejected_q numeric,
  p_lot_code text,
  p_expires_on date,
  p_unit_cost numeric default null,
  p_idempotency_key text default null
) returns jsonb
language plpgsql security definer set search_path=public,private,pgcrypto,pg_temp as $$
declare
  v_uid uuid:=auth.uid(); v_tenant uuid; v_key text:=coalesce(p_idempotency_key,gen_random_uuid()::text); v_fingerprint text; v_result jsonb; v_saved_fingerprint text;
begin
  perform private.require_aal2();
  select tenant_id into v_tenant from memberships where user_id=v_uid and status='active' and role in('owner','manager','purchasing') and (expires_at is null or expires_at>now()) order by created_at limit 1;
  if v_tenant is null then raise exception 'receiving_required'; end if;
  v_fingerprint:=md5(jsonb_build_object('order_id',p_order_id,'location_id',p_location_id,'accepted_q',p_accepted_q,'blocked_q',p_blocked_q,'rejected_q',p_rejected_q,'lot_code',p_lot_code,'expires_on',p_expires_on,'unit_cost',p_unit_cost)::text);
  perform pg_advisory_xact_lock(hashtextextended(v_tenant::text||':'||v_key,0));
  select fingerprint,result into v_saved_fingerprint,v_result from private.receipt_idempotency where tenant_id=v_tenant and idempotency_key=v_key;
  if v_result is not null then
    if v_saved_fingerprint<>v_fingerprint then raise exception 'idempotency_payload_conflict'; end if;
    return v_result;
  end if;
  v_result:=public.receive_purchase_order_split_unchecked(p_order_id,p_location_id,p_accepted_q,p_blocked_q,p_rejected_q,p_lot_code,p_expires_on,p_unit_cost,v_key);
  insert into private.receipt_idempotency(tenant_id,idempotency_key,fingerprint,result) values(v_tenant,v_key,v_fingerprint,v_result);
  return v_result;
end; $$;

revoke all on function public.receive_purchase_order_split(uuid,uuid,numeric,numeric,numeric,text,date,numeric,text) from public,anon;
grant execute on function public.receive_purchase_order_split(uuid,uuid,numeric,numeric,numeric,text,date,numeric,text) to authenticated;
