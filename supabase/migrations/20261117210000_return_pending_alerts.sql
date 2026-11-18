create or replace function public.refresh_return_pending_alerts() returns integer language plpgsql security definer set search_path=public,pg_temp as $$
declare v_uid uuid:=auth.uid(); v_tenant uuid; v_count integer;
begin
 if v_uid is null then raise exception 'not_authenticated'; end if;
 select tenant_id into v_tenant from memberships where user_id=v_uid and status='active' limit 1;
 if v_tenant is null then raise exception 'membership_required'; end if;
 insert into alerts(tenant_id,kind,event_id,status,dedupe_key,message)
 select ac.tenant_id,'return_pending',ac.event_id,'new','return_pending:'||ac.id::text,'Ativo com retorno pendente após o encerramento do evento'
 from asset_custodies ac join events e on e.tenant_id=ac.tenant_id and e.id=ac.event_id
 where ac.tenant_id=v_tenant and ac.closed_at is null and e.ends_at<now() and ac.event_id is not null
 on conflict(tenant_id,dedupe_key) do update set status='new',resolved_at=null,message=excluded.message;
 get diagnostics v_count=row_count;
 return v_count;
end; $$;
revoke all on function public.refresh_return_pending_alerts() from public,anon;
grant execute on function public.refresh_return_pending_alerts() to authenticated;
