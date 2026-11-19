-- Diagnóstico somente leitura para reconciliação operacional e pré-fechamento.
create or replace function public.reconcile_inventory()
returns table(check_name text, failure_count bigint, sample jsonb)
language plpgsql security definer set search_path=public,private,pg_temp as $$
declare v_uid uuid:=auth.uid(); v_tenant uuid;
begin
  perform private.require_aal2();
  select tenant_id into v_tenant from memberships where user_id=v_uid and status='active' and role in('owner','manager','auditor') and (expires_at is null or expires_at>now()) order by created_at limit 1;
  if v_tenant is null then raise exception 'reconciliation_required'; end if;
  return query
  select 'stock_position_invariant'::text, count(*)::bigint,
    coalesce((select jsonb_agg(jsonb_build_object('id',s.id,'item_id',s.item_id,'location_id',s.location_id,'on_hand_q',s.on_hand_q,'reserved_q',s.reserved_q)) from (select id,item_id,location_id,on_hand_q,reserved_q from stock_positions where tenant_id=v_tenant and (on_hand_q<0 or reserved_q<0 or reserved_q>on_hand_q) limit 10) s),'[]'::jsonb)
  from stock_positions where tenant_id=v_tenant and (on_hand_q<0 or reserved_q<0 or reserved_q>on_hand_q)
  union all
  select 'purchase_order_quantity_invariant'::text, count(*)::bigint,
    coalesce((select jsonb_agg(jsonb_build_object('id',p.id,'ordered_q',p.ordered_q,'received_q',p.received_q,'delivered_q',p.delivered_q)) from (select id,ordered_q,received_q,delivered_q from purchase_order_lines where tenant_id=v_tenant and (received_q>delivered_q or delivered_q>ordered_q) limit 10) p),'[]'::jsonb)
  from purchase_order_lines where tenant_id=v_tenant and (received_q>delivered_q or delivered_q>ordered_q)
  union all
  select 'asset_open_custody_duplicate'::text, count(*)::bigint,
    coalesce((select jsonb_agg(jsonb_build_object('asset_id',x.asset_id,'open_custodies',x.open_custodies)) from (select asset_id,count(*) as open_custodies from asset_custodies where tenant_id=v_tenant and closed_at is null group by asset_id having count(*)>1 limit 10) x),'[]'::jsonb)
  from (select asset_id from asset_custodies where tenant_id=v_tenant and closed_at is null group by asset_id having count(*)>1) dup
  union all
  select 'expired_usable_position'::text, count(*)::bigint,
    coalesce((select jsonb_agg(jsonb_build_object('id',s.id,'lot_id',s.lot_id,'on_hand_q',s.on_hand_q,'expires_on',l.expires_on)) from (select sp.id,sp.lot_id,sp.on_hand_q from stock_positions sp join lots l on l.tenant_id=sp.tenant_id and l.id=sp.lot_id where sp.tenant_id=v_tenant and sp.condition='usable' and sp.on_hand_q>0 and l.expires_on<current_date limit 10) s join lots l on l.id=s.lot_id),'[]'::jsonb)
  from stock_positions sp join lots l on l.tenant_id=sp.tenant_id and l.id=sp.lot_id where sp.tenant_id=v_tenant and sp.condition='usable' and sp.on_hand_q>0 and l.expires_on<current_date;
end; $$;

revoke all on function public.reconcile_inventory() from public,anon;
grant execute on function public.reconcile_inventory() to authenticated;
