-- Reserva de evento idempotente para retries de rede e concorrência.
create table if not exists private.reservation_idempotency(
  tenant_id uuid not null references public.organizations(id) on delete cascade,
  idempotency_key text not null,
  fingerprint text not null,
  reservation_id uuid not null,
  created_at timestamptz not null default now(),
  primary key(tenant_id,idempotency_key)
);
revoke all on table private.reservation_idempotency from public,anon,authenticated;

alter function public.reserve_event_material(uuid,uuid,uuid,numeric,uuid) rename to reserve_event_material_unchecked;
revoke all on function public.reserve_event_material_unchecked(uuid,uuid,uuid,numeric,uuid) from public,anon,authenticated;

create or replace function public.reserve_event_material(p_event_id uuid,p_item_id uuid,p_location_id uuid,p_quantity numeric,p_lot_id uuid default null,p_idempotency_key text default null) returns uuid
language plpgsql security definer set search_path=public,private,pgcrypto,pg_temp as $$
declare v_uid uuid:=auth.uid(); v_tenant uuid; v_key text:=coalesce(p_idempotency_key,gen_random_uuid()::text); v_fingerprint text; v_saved_fingerprint text; v_reservation uuid;
begin
  if v_uid is null then raise exception 'not_authenticated'; end if;
  select tenant_id into v_tenant from memberships where user_id=v_uid and status='active' and (expires_at is null or expires_at>now()) limit 1;
  if v_tenant is null then raise exception 'membership_required'; end if;
  v_fingerprint:=md5(jsonb_build_object('event_id',p_event_id,'item_id',p_item_id,'location_id',p_location_id,'quantity',p_quantity,'lot_id',p_lot_id)::text);
  perform pg_advisory_xact_lock(hashtextextended(v_tenant::text||':'||v_key,0));
  select fingerprint,reservation_id into v_saved_fingerprint,v_reservation from private.reservation_idempotency where tenant_id=v_tenant and idempotency_key=v_key;
  if v_reservation is not null then
    if v_saved_fingerprint<>v_fingerprint then raise exception 'idempotency_payload_conflict'; end if;
    return v_reservation;
  end if;
  v_reservation:=public.reserve_event_material_unchecked(p_event_id,p_item_id,p_location_id,p_quantity,p_lot_id);
  insert into private.reservation_idempotency(tenant_id,idempotency_key,fingerprint,reservation_id) values(v_tenant,v_key,v_fingerprint,v_reservation);
  return v_reservation;
end; $$;

revoke all on function public.reserve_event_material(uuid,uuid,uuid,numeric,uuid,text) from public,anon;
grant execute on function public.reserve_event_material(uuid,uuid,uuid,numeric,uuid,text) to authenticated;
