create or replace function public.reject_purchase_request(p_request_id uuid,p_reason text) returns boolean
language plpgsql security definer set search_path=public,private,pg_temp as $$
declare
  v_uid uuid:=auth.uid();
  v_tenant uuid;
  v_status text;
begin
  perform private.require_aal2();
  if nullif(trim(coalesce(p_reason,'')),'') is null then raise exception 'reason_required'; end if;
  select tenant_id into v_tenant
    from memberships
   where user_id=v_uid and status='active'
     and role in('owner','manager','purchasing')
     and (expires_at is null or expires_at>now())
   order by created_at
   limit 1;
  if v_tenant is null then raise exception 'purchase_approval_required'; end if;
  select status into v_status from purchase_requests where tenant_id=v_tenant and id=p_request_id for update;
  if v_status is null then raise exception 'request_not_found'; end if;
  if v_status not in('requested','approved') then raise exception 'request_not_rejectable'; end if;
  update purchase_requests set status='rejected' where tenant_id=v_tenant and id=p_request_id;
  insert into audit_events(tenant_id,actor_id,action,entity,entity_id,payload)
  values(v_tenant,v_uid,'purchase.reject','purchase_request',p_request_id,jsonb_build_object('previous_status',v_status,'reason',trim(p_reason)));
  return true;
end; $$;

revoke all on function public.reject_purchase_request(uuid,text) from public,anon;
grant execute on function public.reject_purchase_request(uuid,text) to authenticated;
