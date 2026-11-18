-- Privileged commands require a fresh Supabase Auth AAL2 session.
-- The original command bodies are retained under an uncallable-by-client name;
-- thin wrappers enforce the assurance check before entering the transaction.
create or replace function private.require_aal2() returns void
language plpgsql stable security definer
set search_path=auth,pg_catalog,pg_temp as $$
begin
  if auth.uid() is null then
    raise exception 'not_authenticated';
  end if;
  if coalesce(auth.jwt()->>'aal','aal1') <> 'aal2' then
    raise exception 'mfa_required';
  end if;
end;
$$;
revoke all on function private.require_aal2() from public,anon;
grant execute on function private.require_aal2() to authenticated;

alter function public.create_invitation(text,text,timestamptz) rename to create_invitation_unchecked_aal1;
create or replace function public.create_invitation(p_email text,p_role text,p_expires_at timestamptz default now()+interval '7 days') returns jsonb
language plpgsql security definer set search_path=public,private,pgcrypto,pg_temp as $$
begin
  perform private.require_aal2();
  return public.create_invitation_unchecked_aal1(p_email,p_role,p_expires_at);
end; $$;
revoke all on function public.create_invitation_unchecked_aal1(text,text,timestamptz) from public,anon,authenticated;
revoke all on function public.create_invitation(text,text,timestamptz) from public,anon;
grant execute on function public.create_invitation(text,text,timestamptz) to authenticated;

alter function public.revoke_invitation(uuid) rename to revoke_invitation_unchecked_aal1;
create or replace function public.revoke_invitation(p_invitation_id uuid) returns boolean
language plpgsql security definer set search_path=public,private,pg_temp as $$
begin
  perform private.require_aal2();
  return public.revoke_invitation_unchecked_aal1(p_invitation_id);
end; $$;
revoke all on function public.revoke_invitation_unchecked_aal1(uuid) from public,anon,authenticated;
revoke all on function public.revoke_invitation(uuid) from public,anon;
grant execute on function public.revoke_invitation(uuid) to authenticated;

alter function public.approve_purchase_request(uuid) rename to approve_purchase_request_unchecked_aal1;
create or replace function public.approve_purchase_request(p_request_id uuid) returns boolean
language plpgsql security definer set search_path=public,private,pg_temp as $$
begin
  perform private.require_aal2();
  return public.approve_purchase_request_unchecked_aal1(p_request_id);
end; $$;
revoke all on function public.approve_purchase_request_unchecked_aal1(uuid) from public,anon,authenticated;
revoke all on function public.approve_purchase_request(uuid) from public,anon;
grant execute on function public.approve_purchase_request(uuid) to authenticated;

alter function public.create_purchase_order_from_request(uuid) rename to create_purchase_order_from_request_unchecked_aal1;
create or replace function public.create_purchase_order_from_request(p_request_id uuid) returns uuid
language plpgsql security definer set search_path=public,private,pg_temp as $$
begin
  perform private.require_aal2();
  return public.create_purchase_order_from_request_unchecked_aal1(p_request_id);
end; $$;
revoke all on function public.create_purchase_order_from_request_unchecked_aal1(uuid) from public,anon,authenticated;
revoke all on function public.create_purchase_order_from_request(uuid) from public,anon;
grant execute on function public.create_purchase_order_from_request(uuid) to authenticated;

alter function public.receive_purchase_order(uuid,uuid,numeric,text,date,numeric,text) rename to receive_purchase_order_unchecked_aal1;
create or replace function public.receive_purchase_order(p_order_id uuid,p_location_id uuid,p_quantity numeric,p_lot_code text,p_expires_on date,p_unit_cost numeric default null,p_idempotency_key text default null) returns jsonb
language plpgsql security definer set search_path=public,private,pg_temp as $$
begin
  perform private.require_aal2();
  return public.receive_purchase_order_unchecked_aal1(p_order_id,p_location_id,p_quantity,p_lot_code,p_expires_on,p_unit_cost,p_idempotency_key);
end; $$;
revoke all on function public.receive_purchase_order_unchecked_aal1(uuid,uuid,numeric,text,date,numeric,text) from public,anon,authenticated;
revoke all on function public.receive_purchase_order(uuid,uuid,numeric,text,date,numeric,text) from public,anon;
grant execute on function public.receive_purchase_order(uuid,uuid,numeric,text,date,numeric,text) to authenticated;

alter function public.finance_stock_summary() rename to finance_stock_summary_unchecked_aal1;
create or replace function public.finance_stock_summary() returns table(item_id uuid,location_id uuid,avg_unit_cost numeric,stock_value numeric)
language plpgsql security definer set search_path=public,private,finance,pg_temp as $$
begin
  perform private.require_aal2();
  return query select * from public.finance_stock_summary_unchecked_aal1();
end; $$;
revoke all on function public.finance_stock_summary_unchecked_aal1() from public,anon,authenticated;
revoke all on function public.finance_stock_summary() from public,anon;
grant execute on function public.finance_stock_summary() to authenticated;

alter function public.set_event_status(uuid,text) rename to set_event_status_unchecked_aal1;
create or replace function public.set_event_status(p_event_id uuid,p_status text) returns boolean
language plpgsql security definer set search_path=public,private,pg_temp as $$
begin
  perform private.require_aal2();
  return public.set_event_status_unchecked_aal1(p_event_id,p_status);
end; $$;
revoke all on function public.set_event_status_unchecked_aal1(uuid,text) from public,anon,authenticated;
revoke all on function public.set_event_status(uuid,text) from public,anon;
grant execute on function public.set_event_status(uuid,text) to authenticated;

alter function public.reopen_event(uuid,text) rename to reopen_event_unchecked_aal1;
create or replace function public.reopen_event(p_event_id uuid,p_reason text) returns boolean
language plpgsql security definer set search_path=public,private,pg_temp as $$
begin
  perform private.require_aal2();
  return public.reopen_event_unchecked_aal1(p_event_id,p_reason);
end; $$;
revoke all on function public.reopen_event_unchecked_aal1(uuid,text) from public,anon,authenticated;
revoke all on function public.reopen_event(uuid,text) from public,anon;
grant execute on function public.reopen_event(uuid,text) to authenticated;

alter function public.close_event(uuid,text) rename to close_event_unchecked_aal1;
create or replace function public.close_event(p_event_id uuid,p_reason text) returns boolean
language plpgsql security definer set search_path=public,private,pg_temp as $$
begin
  perform private.require_aal2();
  return public.close_event_unchecked_aal1(p_event_id,p_reason);
end; $$;
revoke all on function public.close_event_unchecked_aal1(uuid,text) from public,anon,authenticated;
revoke all on function public.close_event(uuid,text) from public,anon;
grant execute on function public.close_event(uuid,text) to authenticated;

alter function public.register_asset(uuid,text,text) rename to register_asset_unchecked_aal1;
create or replace function public.register_asset(p_item_id uuid,p_asset_tag text,p_condition text default 'usable') returns uuid
language plpgsql security definer set search_path=public,private,pg_temp as $$
begin
  perform private.require_aal2();
  return public.register_asset_unchecked_aal1(p_item_id,p_asset_tag,p_condition);
end; $$;
revoke all on function public.register_asset_unchecked_aal1(uuid,text,text) from public,anon,authenticated;
revoke all on function public.register_asset(uuid,text,text) from public,anon;
grant execute on function public.register_asset(uuid,text,text) to authenticated;

alter function public.approve_stock_count(uuid) rename to approve_stock_count_unchecked_aal1;
create or replace function public.approve_stock_count(p_count_id uuid) returns jsonb
language plpgsql security definer set search_path=public,private,finance,pg_temp as $$
begin
  perform private.require_aal2();
  return public.approve_stock_count_unchecked_aal1(p_count_id);
end; $$;
revoke all on function public.approve_stock_count_unchecked_aal1(uuid) from public,anon,authenticated;
revoke all on function public.approve_stock_count(uuid) from public,anon;
grant execute on function public.approve_stock_count(uuid) to authenticated;
