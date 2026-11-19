-- Serializa retries/concorrrência da mesma chave antes do ledger.
alter function public.post_stock_movement(text,uuid,uuid,uuid,uuid,numeric,text,text,text) rename to post_stock_movement_unchecked;
revoke all on function public.post_stock_movement_unchecked(text,uuid,uuid,uuid,uuid,numeric,text,text,text) from public,anon,authenticated;

create or replace function public.post_stock_movement(p_type text,p_item_id uuid,p_location_id uuid,p_to_location_id uuid default null,p_lot_id uuid default null,p_quantity numeric default 0,p_input_uom text default null,p_reason text default null,p_idempotency_key text default null) returns jsonb
language plpgsql security definer set search_path=public,private,pgcrypto,pg_temp as $$
declare v_uid uuid:=auth.uid(); v_tenant uuid; v_key text:=p_idempotency_key;
begin
  if v_uid is null then raise exception 'not_authenticated'; end if;
  if v_key is null then return public.post_stock_movement_unchecked(p_type,p_item_id,p_location_id,p_to_location_id,p_lot_id,p_quantity,p_input_uom,p_reason,null); end if;
  select tenant_id into v_tenant from memberships where user_id=v_uid and status='active' and (expires_at is null or expires_at>now()) limit 1;
  if v_tenant is null then raise exception 'membership_required'; end if;
  perform pg_advisory_xact_lock(hashtextextended(v_tenant::text||':'||v_key,0));
  return public.post_stock_movement_unchecked(p_type,p_item_id,p_location_id,p_to_location_id,p_lot_id,p_quantity,p_input_uom,p_reason,v_key);
end; $$;

revoke all on function public.post_stock_movement(text,uuid,uuid,uuid,uuid,numeric,text,text,text) from public,anon;
grant execute on function public.post_stock_movement(text,uuid,uuid,uuid,uuid,numeric,text,text,text) to authenticated;
