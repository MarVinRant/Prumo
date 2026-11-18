create or replace function public.accept_invitation(p_token text,p_display_name text default '') returns uuid language plpgsql security definer set search_path=public,pgcrypto,pg_temp as $$
declare v_uid uuid:=auth.uid(); v_email text:=lower(coalesce(auth.jwt()->>'email','')); v_tenant uuid; v_invitation uuid; v_role text; v_id uuid;
begin
 if v_uid is null then raise exception 'not_authenticated'; end if;
 if nullif(trim(p_token),'') is null then raise exception 'invitation_token_required'; end if;
 select tenant_id,id,role into v_tenant,v_invitation,v_role from invitations where token_hash=encode(digest(trim(p_token),'sha256'),'hex') and lower(email)=v_email and accepted_at is null and revoked_at is null and expires_at>now() for update;
 if v_invitation is null then raise exception 'invitation_invalid_or_expired'; end if;
 if exists(select 1 from memberships where tenant_id=v_tenant and user_id=v_uid and status='active') then raise exception 'membership_already_exists'; end if;
 insert into profiles(user_id,display_name,email) values(v_uid,coalesce(nullif(trim(p_display_name),''),split_part(v_email,'@',1)),v_email) on conflict(user_id) do update set display_name=coalesce(nullif(trim(p_display_name),''),profiles.display_name),email=excluded.email;
 insert into memberships(tenant_id,user_id,role,status) values(v_tenant,v_uid,v_role,'active') returning id into v_id;
 update invitations set accepted_at=now() where id=v_invitation;
 insert into audit_events(tenant_id,actor_id,action,entity,entity_id,payload) values(v_tenant,v_uid,'access.accept_invitation','invitation',v_invitation,jsonb_build_object('role',v_role,'email',v_email));
 return v_id;
end; $$;
revoke all on function public.accept_invitation(text,text) from public,anon;
grant execute on function public.accept_invitation(text,text) to authenticated;
