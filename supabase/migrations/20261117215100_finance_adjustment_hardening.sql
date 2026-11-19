drop policy if exists finance_deny_all_value_adjustments on finance.value_adjustments;
create policy finance_deny_all_value_adjustments on finance.value_adjustments
  for all to authenticated using(false) with check(false);
create index if not exists idx_value_adjustments_tenant_item
  on finance.value_adjustments(tenant_id,item_id);
create index if not exists idx_value_adjustments_tenant_location
  on finance.value_adjustments(tenant_id,location_id);
create index if not exists idx_value_adjustments_requested_by
  on finance.value_adjustments(requested_by);
create index if not exists idx_value_adjustments_approved_by
  on finance.value_adjustments(approved_by);
