import { supabase } from './supabase'
import type { ActivityRow, MovementType, StockRow, StockSummary } from './types'

export async function getStockSummary(): Promise<StockSummary> {
  if (!supabase) return { totalItems: 0, availableValue: 0, criticalItems: 0, openEvents: 0, pendingReceipts: 0, openAlerts: 0 }
  const [{ data: positions }, { count: openEvents }, { count: pendingReceipts }, { count: openAlerts }] = await Promise.all([
    supabase.from('stock_positions').select('on_hand_q,reserved_q,item_id').limit(1000),
    supabase.from('events').select('id', { count: 'exact', head: true }).in('status', ['planned', 'separating', 'dispatched', 'operating', 'settling']),
    supabase.from('receipts').select('id', { count: 'exact', head: true }).in('status', ['draft', 'checking']),
    supabase.from('alerts').select('id', { count: 'exact', head: true }).in('status', ['new', 'acknowledged']),
  ])
  const rows = positions ?? []
  const availableValue = 0
  const criticalItems = 0
  return { totalItems: rows.length, availableValue, criticalItems, openEvents: openEvents ?? 0, pendingReceipts: pendingReceipts ?? 0, openAlerts: openAlerts ?? 0 }
}

export async function refreshAlerts() {
  if (!supabase) return 0
  const { data, error } = await supabase.rpc('refresh_operational_alerts')
  if (error) throw error
  return Number(data ?? 0)
}

export async function getFinanceSummary() {
  if (!supabase) return []
  const { data, error } = await supabase.rpc('finance_stock_summary')
  if (error) throw error
  return data ?? []
}

export async function listStock(search = ''): Promise<StockRow[]> {
  if (!supabase) return []
  const query = supabase.from('stock_positions').select('id,on_hand_q,reserved_q,condition,expires_on:lots(expires_on),items!inner(id,sku,name,family,nature,base_uom),locations!inner(name)').order('created_at', { ascending: false }).limit(300)
  const { data, error } = await query
  if (error) throw error
  return (data ?? []).filter((row) => !search || String((row.items as { name?: string }).name ?? '').toLowerCase().includes(search.toLowerCase()) || String((row.items as { sku?: string }).sku ?? '').toLowerCase().includes(search.toLowerCase())).map(row => {
    const item = row.items as unknown as { id: string; sku: string; name: string; family: StockRow['family']; nature: StockRow['nature']; base_uom: string }
    const location = row.locations as unknown as { name: string }
    const lot = (row.expires_on as { expires_on?: string }[] | null)?.[0]
    return { id: row.id, sku: item.sku, name: item.name, family: item.family, nature: item.nature, base_uom: item.base_uom, location_name: location.name, on_hand_q: Number(row.on_hand_q), reserved_q: Number(row.reserved_q), available_q: Number(row.on_hand_q) - Number(row.reserved_q), min_q: 0, reorder_q: 0, condition: row.condition, expires_on: lot?.expires_on ?? null, avg_unit_cost: 0 }
  })
}

export async function bootstrapWorkspace() {
  if (!supabase) return null
  const { data, error } = await supabase.rpc('bootstrap_workspace', { p_name: 'Operação Farol' })
  if (error) throw error
  return data
}

export async function seedDemoData() {
  if (!supabase) return null
  const { data, error } = await supabase.rpc('seed_demo_data')
  if (error) throw error
  await supabase.rpc('seed_demo_assets')
  return data
}

export async function listActivity(): Promise<ActivityRow[]> {
  if (!supabase) return []
  const { data, error } = await supabase.from('activity_feed').select('*').order('created_at', { ascending: false }).limit(8)
  if (error) throw error
  return (data ?? []).map((row) => ({
    id: row.id,
    type: row.type,
    document_number: row.document_no,
    item_name: row.label,
    quantity: null,
    unit: null,
    location_name: row.location_name,
    created_at: row.created_at,
    status: 'posted',
  })) as ActivityRow[]
}

export async function postMovement(input: { type: MovementType; item_id: string; location_id: string; quantity: number; uom: string; lot_id?: string; reason?: string; to_location_id?: string }) {
  if (!supabase) throw new Error('Configure o Supabase antes de movimentar estoque.')
  const { data, error } = await supabase.rpc('post_stock_movement', { p_type: input.type, p_item_id: input.item_id, p_location_id: input.location_id, p_to_location_id: input.to_location_id ?? null, p_lot_id: input.lot_id ?? null, p_quantity: input.quantity, p_input_uom: input.uom, p_reason: input.reason ?? null, p_idempotency_key: crypto.randomUUID() })
  if (error) throw error
  return data
}

export async function listItems() {
  if (!supabase) return []
  const { data, error } = await supabase.from('items').select('id,sku,name,base_uom,family,nature').eq('status', 'active').order('name').limit(300)
  if (error) throw error
  return data ?? []
}

export async function listLocations() {
  if (!supabase) return []
  const { data, error } = await supabase.from('locations').select('id,name,type').eq('status', 'active').eq('is_stockable', true).order('name')
  if (error) throw error
  return data ?? []
}

export async function listEvents() {
  if (!supabase) return []
  const { data, error } = await supabase.from('events').select('id,name,code,venue,starts_at,ends_at,status').order('starts_at', { ascending: true }).limit(100)
  if (error) throw error
  return data ?? []
}

export async function listEventReservations(eventId?: string) {
  if (!supabase) return []
  let query = supabase.from('reservations').select('id,event_id,item_id,location_id,quantity,status,created_at,items(name,sku),locations(name)').order('created_at', { ascending: false }).limit(100)
  if (eventId) query = query.eq('event_id', eventId)
  const { data, error } = await query
  if (error) throw error
  return data ?? []
}

export async function createEvent(input: { name: string; code: string; venue: string; starts_at: string; ends_at: string }) {
  if (!supabase) throw new Error('Configure o Supabase antes de criar eventos.')
  const { data, error } = await supabase.rpc('create_event', { p_name: input.name, p_code: input.code, p_venue: input.venue, p_starts_at: input.starts_at, p_ends_at: input.ends_at })
  if (error) throw error
  return data
}

export async function listPurchaseRequests() {
  if (!supabase) return []
  const { data, error } = await supabase.from('purchase_requests').select('id,status,needed_by,reason,created_at,purchase_request_lines(quantity,items(name,sku),locations(name)),purchase_orders(id,order_no,status,purchase_order_lines(ordered_q,received_q,items(name,sku)))').order('created_at', { ascending: false }).limit(100)
  if (error) throw error
  return data ?? []
}

export async function createPurchaseRequest(input: { item_id: string; location_id: string; quantity: number; needed_by: string; reason: string }) {
  if (!supabase) throw new Error('Configure o Supabase antes de criar solicitações.')
  const { data, error } = await supabase.rpc('create_purchase_request', { p_item_id: input.item_id, p_location_id: input.location_id, p_quantity: input.quantity, p_needed_by: input.needed_by, p_reason: input.reason })
  if (error) throw error
  return data
}

export async function approvePurchaseRequest(id: string) {
  if (!supabase) throw new Error('Configure o Supabase antes de aprovar compras.')
  const { data, error } = await supabase.rpc('approve_purchase_request', { p_request_id: id })
  if (error) throw error
  return data
}

export async function createPurchaseOrderFromRequest(id: string) {
  if (!supabase) throw new Error('Configure o Supabase antes de emitir pedidos.')
  const { data, error } = await supabase.rpc('create_purchase_order_from_request', { p_request_id: id })
  if (error) throw error
  return data
}

export async function receivePurchaseOrder(input: { order_id: string; location_id: string; quantity: number; lot_code: string; expires_on: string; unit_cost?: number; idempotency_key?: string }) {
  if (!supabase) throw new Error('Configure o Supabase antes de receber pedidos.')
  const { data, error } = await supabase.rpc('receive_purchase_order', { p_order_id: input.order_id, p_location_id: input.location_id, p_quantity: input.quantity, p_lot_code: input.lot_code, p_expires_on: input.expires_on, p_unit_cost: input.unit_cost ?? null, p_idempotency_key: input.idempotency_key ?? crypto.randomUUID() })
  if (error) throw error
  return data
}

export async function createInvitation(input: { email: string; role: string; expires_at?: string }) {
  if (!supabase) throw new Error('Configure o Supabase antes de convidar equipe.')
  const { data, error } = await supabase.rpc('create_invitation', { p_email: input.email, p_role: input.role, p_expires_at: input.expires_at ?? new Date(Date.now() + 7 * 86400000).toISOString() })
  if (error) throw error
  return data as { id: string; token: string; expires_at: string }
}

export async function listInvitations() {
  if (!supabase) return []
  const { data, error } = await supabase.from('invitations').select('id,email,role,expires_at,accepted_at,revoked_at,created_at').order('created_at', { ascending: false }).limit(100)
  if (error) throw error
  return data ?? []
}

export async function revokeInvitation(id: string) {
  if (!supabase) throw new Error('Configure o Supabase antes de revogar convites.')
  const { data, error } = await supabase.rpc('revoke_invitation', { p_invitation_id: id })
  if (error) throw error
  return data
}

export async function reserveEventMaterial(input: { event_id: string; item_id: string; location_id: string; quantity: number; lot_id?: string }) {
  if (!supabase) throw new Error('Configure o Supabase antes de reservar materiais.')
  const { data, error } = await supabase.rpc('reserve_event_material', { p_event_id: input.event_id, p_item_id: input.item_id, p_location_id: input.location_id, p_quantity: input.quantity, p_lot_id: input.lot_id ?? null })
  if (error) throw error
  return data
}

export async function releaseEventReservation(id: string) {
  if (!supabase) throw new Error('Configure o Supabase antes de liberar reservas.')
  const { data, error } = await supabase.rpc('release_event_reservation', { p_reservation_id: id })
  if (error) throw error
  return data
}

export async function closeEvent(id: string, reason: string) {
  if (!supabase) throw new Error('Configure o Supabase antes de fechar eventos.')
  const { data, error } = await supabase.rpc('close_event', { p_event_id: id, p_reason: reason })
  if (error) throw error
  return data
}

export async function setEventStatus(id: string, status: string) {
  if (!supabase) throw new Error('Configure o Supabase antes de alterar o evento.')
  const { data, error } = await supabase.rpc('set_event_status', { p_event_id: id, p_status: status })
  if (error) throw error
  return data
}

export async function reopenEvent(id: string, reason: string) {
  if (!supabase) throw new Error('Configure o Supabase antes de reabrir eventos.')
  const { data, error } = await supabase.rpc('reopen_event', { p_event_id: id, p_reason: reason })
  if (error) throw error
  return data
}

export async function consumeEventReservation(id: string) {
  if (!supabase) throw new Error('Configure o Supabase antes de consumir reservas.')
  const { data, error } = await supabase.rpc('consume_event_reservation', { p_reservation_id: id })
  if (error) throw error
  return data
}

export async function listAssets() {
  if (!supabase) return []
  const { data, error } = await supabase.from('assets').select('id,asset_tag,condition,status,item_id,items(name,sku)').order('asset_tag').limit(200)
  if (error) throw error
  return data ?? []
}

export async function registerAsset(input: { item_id: string; asset_tag: string; condition?: string }) {
  if (!supabase) throw new Error('Configure o Supabase antes de cadastrar ativos.')
  const { data, error } = await supabase.rpc('register_asset', { p_item_id: input.item_id, p_asset_tag: input.asset_tag, p_condition: input.condition ?? 'usable' })
  if (error) throw error
  return data
}

export async function dispatchAsset(input: { asset_id: string; location_id: string; event_id?: string; responsible_user?: string; condition_out?: string }) {
  if (!supabase) throw new Error('Configure o Supabase antes de expedir ativos.')
  const { data, error } = await supabase.rpc('dispatch_asset', { p_asset_id: input.asset_id, p_location_id: input.location_id, p_event_id: input.event_id ?? null, p_responsible_user: input.responsible_user ?? null, p_condition_out: input.condition_out ?? 'usable' })
  if (error) throw error
  return data
}

export async function returnAsset(input: { asset_id: string; condition_in: string; location_id?: string }) {
  if (!supabase) throw new Error('Configure o Supabase antes de devolver ativos.')
  const { data, error } = await supabase.rpc('return_asset', { p_asset_id: input.asset_id, p_condition_in: input.condition_in, p_location_id: input.location_id ?? null })
  if (error) throw error
  return data
}

export function downloadStockCsv(rows: { sku: string; name: string; location_name: string; on_hand_q: number; reserved_q: number; available_q: number; base_uom: string; condition: string }[]) {
  const escape = (value: string | number) => { const text = String(value); return /^[=+\-@]/.test(text) ? `'${text}` : `"${text.replaceAll('"', '""')}"` }
  const csv = ['SKU,Item,Local,Físico,Reservado,Disponível,Unidade,Condição', ...rows.map(row => [row.sku,row.name,row.location_name,row.on_hand_q,row.reserved_q,row.available_q,row.base_uom,row.condition].map(escape).join(','))].join('\r\n')
  const link = document.createElement('a'); link.href = URL.createObjectURL(new Blob([`\ufeff${csv}`], { type: 'text/csv;charset=utf-8' })); link.download = `prumo-estoque-${new Date().toISOString().slice(0,10)}.csv`; link.click(); URL.revokeObjectURL(link.href)
}
