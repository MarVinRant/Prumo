create index if not exists idx_alert_acknowledgements_alert
  on public.alert_acknowledgements(tenant_id,alert_id);
create index if not exists idx_alert_acknowledgements_membership
  on public.alert_acknowledgements(tenant_id,membership_id);
