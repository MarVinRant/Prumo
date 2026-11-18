create or replace function public.finance_stock_summary() returns table(item_id uuid,location_id uuid,avg_unit_cost numeric,stock_value numeric) language plpgsql security definer set search_path=public,finance,pg_temp as $$
declare v_uid uuid:=auth.uid(); v_tenant uuid;
begin
 if v_uid is null then raise exception 'not_authenticated'; end if;
 select tenant_id into v_tenant from memberships where user_id=v_uid and status='active' and role in('owner','finance') limit 1;
 if v_tenant is null then raise exception 'finance_access_required'; end if;
 return query select sv.item_id,sv.location_id,sv.avg_unit_cost,sv.stock_value from finance.stock_values sv where sv.tenant_id=v_tenant;
end; $$;
revoke all on function public.finance_stock_summary() from public,anon;
grant execute on function public.finance_stock_summary() to authenticated;
