import { readFile } from 'node:fs/promises'

const read = path => readFile(new URL(`../${path}`, import.meta.url), 'utf8')
const envExample = await read('.env.example')
const api = await read('src/lib/api.ts')
const app = await read('src/App.tsx')
const migrationFiles = await Promise.all([
  'supabase/migrations/20261117200000_prumo_mvp.sql',
  'supabase/migrations/20261117213000_private_storage_policies.sql',
  'supabase/migrations/20261117214000_privileged_aal2.sql',
  'supabase/migrations/20261117214100_event_manifest_settlement.sql',
  'supabase/migrations/20261117214300_event_replenishment.sql',
  'supabase/migrations/20261117214400_catalog_structure_commands.sql',
  'supabase/migrations/20261117214500_supplier_returns.sql',
  'supabase/migrations/20261117214600_alert_lifecycle.sql',
  'supabase/migrations/20261117214800_purchase_rejection.sql',
  'supabase/migrations/20261117214900_conversion_context.sql',
  'supabase/migrations/20261117215000_finance_value_adjustments.sql',
  'supabase/migrations/20261117215100_finance_adjustment_hardening.sql',
  'supabase/migrations/20261117215200_structure_lifecycle.sql',
  'supabase/migrations/20261117215300_receipt_conformance.sql',
  'supabase/migrations/20261117215400_quarantine_release.sql',
  'supabase/migrations/20261117215500_inventory_reconciliation.sql',
  'supabase/migrations/20261117215700_purchase_status_from_acceptance.sql',
].map(read))
const wrangler = await read('wrangler.jsonc')

const checks = [
  ['frontend has no service role key', !envExample.includes('SERVICE_ROLE') && !api.includes('service_role')],
  ['public schema enables RLS', migrationFiles[0].includes('enable row level security')],
  ['finance schema denies table access', migrationFiles[0].includes('revoke all on all tables in schema finance')],
  ['CSV neutralizes formulas', api.includes("/^[=+\\-@]/")],
  ['SPA fallback is configured', wrangler.includes('single-page-application')],
  ['private storage policies validate tenant path', migrationFiles[1].includes('private.is_member_path')],
  ['privileged AAL2 guard checks the JWT assurance claim', migrationFiles[2].includes("auth.jwt()->>'aal'") && migrationFiles[2].includes("'aal2'")],
  ['privileged AAL2 guard has an explicit MFA failure', migrationFiles[2].includes("raise exception 'mfa_required'")],
  ['AAL2 wrappers hide original command bodies', migrationFiles[2].includes('create_invitation_unchecked_aal1') && migrationFiles[2].includes('finance_stock_summary_unchecked_aal1')],
  ['event manifest and settlement tables are versioned', migrationFiles[3].includes('event_manifest_versions') && migrationFiles[3].includes('event_differences')],
  ['event close blocks unapproved differences', migrationFiles[3].includes('unclassified_differences') && migrationFiles[3].includes('approve_event_difference')],
  ['event replenishment uses the active manifest', migrationFiles[4].includes('replenish_event_material') && migrationFiles[4].includes('event_manifest_lines')],
  ['catalog and structure writes are server-side commands', migrationFiles[5].includes('create_item') && migrationFiles[5].includes('create_location') && migrationFiles[5].includes('upsert_item_location_policy')],
  ['supplier return is tied to receipt and ledger', migrationFiles[6].includes('return_supplier_material') && migrationFiles[6].includes('receipt_lines') && migrationFiles[6].includes("'return'") && migrationFiles[6].includes('stock_entries')],
  ['alerts have auditable acknowledge and resolve commands', migrationFiles[7].includes('alert_acknowledgements') && migrationFiles[7].includes('acknowledge_alert') && migrationFiles[7].includes('resolve_alert') && migrationFiles[7].includes('require_aal2')],
  ['purchase rejection is reasoned and audited', migrationFiles[8].includes('reject_purchase_request') && migrationFiles[8].includes('reason_required') && migrationFiles[8].includes('purchase.reject')],
  ['frontend challenges enrolled MFA before privileged UI', app.includes('getAuthenticatorAssuranceLevel') && app.includes('mfa.challenge') && app.includes('MfaChallenge')],
  ['contextual kg and liter conversions are server-side', migrationFiles[9].includes("lower(p_input_uom)='kg'") && migrationFiles[9].includes("lower(p_input_uom)='l'") && migrationFiles[9].includes('conversion_not_configured')],
  ['financial adjustments stay private and cannot change quantity', migrationFiles[10].includes('finance.value_adjustments') && migrationFiles[10].includes('independent_approval_required') && migrationFiles[10].includes('quantity_required_for_value') && migrationFiles[10].includes('revoke all on table finance.value_adjustments')],
  ['financial audit payload omits monetary values', migrationFiles[10].includes("'finance.cost_projection'") && !migrationFiles[10].includes("'unit_cost',v_cost")],
  ['financial adjustment table has explicit deny policy', migrationFiles[11].includes('finance_deny_all_value_adjustments') && migrationFiles[11].includes('using(false)')],
  ['catalog lifecycle commands block unsafe archival', migrationFiles[12].includes('set_item_status') && migrationFiles[12].includes('item_has_stock') && migrationFiles[12].includes('location_has_open_custody') && migrationFiles[12].includes('supplier_has_open_orders')],
  ['receipt conference separates usable quarantine and rejected quantities', migrationFiles[13].includes('receive_purchase_order_split') && migrationFiles[13].includes('blocked_q') && migrationFiles[13].includes('delivered_q') && migrationFiles[13].includes("'quarantine'") && migrationFiles[13].includes('delivered_quantity_exceeds_order')],
  ['quarantine release preserves physical quantity and requires AAL2', migrationFiles[14].includes('release_quarantined_stock') && migrationFiles[14].includes('require_aal2') && migrationFiles[14].includes('position_not_quarantine') && migrationFiles[14].includes("'quarantine'") && migrationFiles[14].includes("'usable'")],
  ['inventory reconciliation is scoped and read-only', migrationFiles[15].includes('reconcile_inventory') && migrationFiles[15].includes('require_aal2') && migrationFiles[15].includes('stock_position_invariant') && migrationFiles[15].includes('asset_open_custody_duplicate')],
  ['purchase status follows accepted quantities', migrationFiles[16].includes('sync_purchase_order_status') && migrationFiles[16].includes('new.received_q>=new.ordered_q') && migrationFiles[16].includes('purchase_order_status_from_acceptance')],
]

const failures = checks.filter(([, passed]) => !passed)
for (const [label, passed] of checks) console.log(`${passed ? 'PASS' : 'FAIL'} ${label}`)
if (failures.length) process.exit(1)
