create or replace function public.refresh_operational_alerts() returns integer language plpgsql security definer set search_path=public,pg_temp as $$
declare v_uid uuid:=auth.uid(); v_tenant uuid; v_count integer:=0; v_added integer;
begin
 if v_uid is null then raise exception 'not_authenticated'; end if;
 select tenant_id into v_tenant from memberships where user_id=v_uid and status='active' limit 1;
 if v_tenant is null then raise exception 'membership_required'; end if;
 insert into alerts(tenant_id,kind,item_id,status,dedupe_key,message)
 select v_tenant,'rupture',sp.item_id,'new','rupture:'||sp.item_id::text||':'||sp.location_id::text,'Saldo abaixo do mínimo em '||l.name
 from stock_positions sp join item_location_policies p on p.tenant_id=sp.tenant_id and p.item_id=sp.item_id and p.location_id=sp.location_id join locations l on l.tenant_id=sp.tenant_id and l.id=sp.location_id
 where sp.tenant_id=v_tenant and sp.condition='usable' and sp.on_hand_q-sp.reserved_q<=p.min_q
 on conflict(tenant_id,dedupe_key) do update set status='new',resolved_at=null,message=excluded.message;
 get diagnostics v_added=row_count; v_count:=v_count+v_added;
 insert into alerts(tenant_id,kind,item_id,status,dedupe_key,message)
 select distinct v_tenant,'expiry',l.item_id,'new','expiry:'||l.id::text,'Lote '||l.lot_code||' vence em '||to_char(l.expires_on,'DD/MM/YYYY')
 from lots l join stock_positions sp on sp.tenant_id=l.tenant_id and sp.lot_id=l.id and sp.on_hand_q>0
 where l.tenant_id=v_tenant and l.condition='usable' and l.expires_on is not null and l.expires_on<=current_date+interval '7 days'
 on conflict(tenant_id,dedupe_key) do update set status='new',resolved_at=null,message=excluded.message;
 get diagnostics v_added=row_count; v_count:=v_count+v_added;
 insert into alerts(tenant_id,kind,event_id,status,dedupe_key,message)
 select pr.tenant_id,pr.event_id,'event_shortage','new','event_shortage:'||pr.event_id::text||':'||pr.item_id::text,'Reserva abaixo do planejado para o evento'
 from event_plan_lines pr left join (select tenant_id,event_id,item_id,sum(quantity) quantity from reservations where status in('firm','consumed') group by tenant_id,event_id,item_id) r on r.tenant_id=pr.tenant_id and r.event_id=pr.event_id and r.item_id=pr.item_id
 where pr.tenant_id=v_tenant and coalesce(r.quantity,0)<pr.planned_q
 on conflict(tenant_id,dedupe_key) do update set status='new',resolved_at=null,message=excluded.message;
 get diagnostics v_added=row_count; v_count:=v_count+v_added;
 insert into alerts(tenant_id,kind,status,dedupe_key,message)
 select v_tenant,'purchase_delay','new','purchase_delay:'||id::text,'Solicitação de compra vencida sem recebimento'
 from purchase_requests where tenant_id=v_tenant and needed_by<current_date and status not in('received','cancelled','rejected')
 on conflict(tenant_id,dedupe_key) do update set status='new',resolved_at=null,message=excluded.message;
 get diagnostics v_added=row_count; v_count:=v_count+v_added;
 return v_count;
end; $$;
revoke all on function public.refresh_operational_alerts() from public,anon;
grant execute on function public.refresh_operational_alerts() to authenticated;
