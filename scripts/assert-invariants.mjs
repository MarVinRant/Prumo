import { readFile } from 'node:fs/promises'

const read = path => readFile(new URL(`../${path}`, import.meta.url), 'utf8')
const envExample = await read('.env.example')
const api = await read('src/lib/api.ts')
const migrationFiles = await Promise.all([
  'supabase/migrations/20261117200000_prumo_mvp.sql',
  'supabase/migrations/20261117213000_private_storage_policies.sql',
  'supabase/migrations/20261117214000_privileged_aal2.sql',
  'supabase/migrations/20261117214100_event_manifest_settlement.sql',
  'supabase/migrations/20261117214300_event_replenishment.sql',
  'supabase/migrations/20261117214400_catalog_structure_commands.sql',
  'supabase/migrations/20261117214500_supplier_returns.sql',
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
]

const failures = checks.filter(([, passed]) => !passed)
for (const [label, passed] of checks) console.log(`${passed ? 'PASS' : 'FAIL'} ${label}`)
if (failures.length) process.exit(1)
