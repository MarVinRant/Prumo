create or replace function public.set_event_status(p_event_id uuid,p_status text) returns boolean language plpgsql security definer set search_path=public,pg_temp as $$
declare v_uid uuid:=auth.uid(); v_tenant uuid; v_current text; v_allowed boolean:=false; v_count integer;
begin
 if v_uid is null then raise exception 'not_authenticated'; end if;
 if p_status not in('planned','separating','dispatched','operating','settling','cancelled') then raise exception 'invalid_event_status'; end if;
 select tenant_id,status into v_tenant,v_current from events where id=p_event_id for update;
 if v_tenant is null then raise exception 'event_not_found'; end if;
 if not exists(select 1 from memberships where tenant_id=v_tenant and user_id=v_uid and status='active' and role in('owner','manager')) then raise exception 'manager_required'; end if;
 v_allowed := (v_current='planned' and p_status in('separating','cancelled')) or (v_current='reopened' and p_status='separating') or (v_current='separating' and p_status in('dispatched','cancelled')) or (v_current='dispatched' and p_status='operating') or (v_current='operating' and p_status='settling');
 if not v_allowed then raise exception 'invalid_event_transition'; end if;
 update events set status=p_status where tenant_id=v_tenant and id=p_event_id;
 get diagnostics v_count = row_count;
 insert into audit_events(tenant_id,actor_id,action,entity,entity_id,payload) values(v_tenant,v_uid,'event.status','event',p_event_id,jsonb_build_object('from',v_current,'to',p_status));
 return v_count=1;
end; $$;
revoke all on function public.set_event_status(uuid,text) from public,anon;
grant execute on function public.set_event_status(uuid,text) to authenticated;
