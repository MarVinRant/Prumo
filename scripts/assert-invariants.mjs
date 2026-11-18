import { readFile } from 'node:fs/promises'

const read = path => readFile(new URL(`../${path}`, import.meta.url), 'utf8')
const envExample = await read('.env.example')
const api = await read('src/lib/api.ts')
const migrationFiles = await Promise.all([
  'supabase/migrations/20261117200000_prumo_mvp.sql',
  'supabase/migrations/20261117213000_private_storage_policies.sql',
].map(read))
const wrangler = await read('wrangler.jsonc')

const checks = [
  ['frontend has no service role key', !envExample.includes('SERVICE_ROLE') && !api.includes('service_role')],
  ['public schema enables RLS', migrationFiles[0].includes('enable row level security')],
  ['finance schema denies table access', migrationFiles[0].includes('revoke all on all tables in schema finance')],
  ['CSV neutralizes formulas', api.includes("/^[=+\\-@]/")],
  ['SPA fallback is configured', wrangler.includes('single-page-application')],
  ['private storage policies validate tenant path', migrationFiles[1].includes('private.is_member_path')],
]

const failures = checks.filter(([, passed]) => !passed)
for (const [label, passed] of checks) console.log(`${passed ? 'PASS' : 'FAIL'} ${label}`)
if (failures.length) process.exit(1)
