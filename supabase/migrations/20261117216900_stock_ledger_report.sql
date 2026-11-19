-- Projeção de extrato operacional sem custos, respeitando RLS das tabelas-base.
create or replace view public.stock_ledger_report
with (security_invoker=true) as
select
  e.id,
  e.tenant_id,
  d.type,
  d.document_no,
  d.reason,
  d.posted_at,
  e.quantity,
  e.direction,
  i.sku,
  i.name as item_name,
  i.base_uom,
  l.name as location_name,
  lot.lot_code,
  lot.expires_on
from public.stock_entries e
join public.stock_documents d on d.tenant_id=e.tenant_id and d.id=e.document_id
join public.items i on i.tenant_id=e.tenant_id and i.id=e.item_id
join public.locations l on l.tenant_id=e.tenant_id and l.id=e.location_id
join public.lots lot on lot.tenant_id=e.tenant_id and lot.id=e.lot_id;
grant select on public.stock_ledger_report to authenticated;
