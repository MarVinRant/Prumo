import { supabase } from './supabase'
import type { ActivityRow, AlertRow, FinanceAdjustment, MovementType, ReconciliationRow, StockRow, StockSummary } from './types'

export async function getStockSummary(): Promise<StockSummary> {
  if (!supabase) return { totalItems: 0, availableValue: 0, criticalItems: 0, openEvents: 0, pendingReceipts: 0, openAlerts: 0 }
  const [{ data: positions }, { data: policies }, { count: openEvents }, { count: pendingReceipts }, { count: openAlerts }] = await Promise.all([
    supabase.from('stock_positions').select('on_hand_q,reserved_q,condition,item_id,location_id,expires_on:lots(expires_on)').limit(1000),
    supabase.from('item_location_policies').select('item_id,location_id,min_q').limit(1000),
    supabase.from('events').select('id', { count: 'exact', head: true }).in('status', ['planned', 'separating', 'dispatched', 'operating', 'settling']),
    supabase.from('receipts').select('id', { count: 'exact', head: true }).in('status', ['draft', 'checking']),
    supabase.from('alerts').select('id', { count: 'exact', head: true }).in('status', ['new', 'acknowledged']),
  ])
  const rows = positions ?? []
  const availableValue = 0
  const minByPosition = new Map((policies ?? []).map(policy => [`${policy.item_id}:${policy.location_id}`, Number(policy.min_q)]))
  const today = new Date().toISOString().slice(0, 10)
  const criticalItems = new Set(rows.filter(row => { const lot = (row.expires_on as { expires_on?: string }[] | null)?.[0]; return String(row.condition ?? '') === 'usable' && (!lot?.expires_on || lot.expires_on >= today) && Number(row.on_hand_q) - Number(row.reserved_q) <= (minByPosition.get(`${row.item_id}:${row.location_id}`) ?? 0) }).map(row => row.item_id)).size
  return { totalItems: rows.length, availableValue, criticalItems, openEvents: openEvents ?? 0, pendingReceipts: pendingReceipts ?? 0, openAlerts: openAlerts ?? 0 }
}

export async function refreshAlerts() {
  if (!supabase) return 0
  const { data, error } = await supabase.rpc('refresh_operational_alerts')
  if (error) throw error
  const { data: returnData, error: returnError } = await supabase.rpc('refresh_return_pending_alerts')
  if (returnError) throw returnError
  return Number(data ?? 0) + Number(returnData ?? 0)
}

export async function listAlerts(): Promise<AlertRow[]> {
  if (!supabase) return []
  const { data, error } = await supabase.from('alerts').select('id,kind,status,message,created_at,resolved_at,item_id,event_id,items(name,sku),events(name,code)').order('created_at', { ascending: false }).limit(100)
  if (error) throw error
  return (data ?? []) as AlertRow[]
}

export async function acknowledgeAlert(id: string) {
  if (!supabase) throw new Error('Configure o Supabase antes de reconhecer alertas.')
  const { data, error } = await supabase.rpc('acknowledge_alert', { p_alert_id: id })
  if (error) throw error
  return data
}

export async function resolveAlert(id: string, reason: string) {
  if (!supabase) throw new Error('Configure o Supabase antes de resolver alertas.')
  const { data, error } = await supabase.rpc('resolve_alert', { p_alert_id: id, p_reason: reason })
  if (error) throw error
  return data
}

export async function getFinanceSummary() {
  if (!supabase) return []
  const { data, error } = await supabase.rpc('finance_stock_summary')
  if (error) throw error
  return data ?? []
}

export async function listFinanceAdjustments(): Promise<FinanceAdjustment[]> {
  if (!supabase) return []
  const { data, error } = await supabase.rpc('finance_value_adjustments')
  if (error) throw error
  return (data ?? []) as FinanceAdjustment[]
}

export async function requestValueAdjustment(input: { item_id: string; location_id: string; amount: number; reason: string; idempotency_key?: string }) {
  if (!supabase) throw new Error('Configure o Supabase antes de solicitar ajuste financeiro.')
  const { data, error } = await supabase.rpc('request_value_adjustment', { p_item_id: input.item_id, p_location_id: input.location_id, p_amount: input.amount, p_reason: input.reason, p_idempotency_key: input.idempotency_key ?? crypto.randomUUID() })
  if (error) throw error
  return data
}

export async function approveValueAdjustment(id: string) {
  if (!supabase) throw new Error('Configure o Supabase antes de aprovar ajuste financeiro.')
  const { data, error } = await supabase.rpc('approve_value_adjustment', { p_adjustment_id: id })
  if (error) throw error
  return data
}

export async function reconcileInventory(): Promise<ReconciliationRow[]> {
  if (!supabase) throw new Error('Configure o Supabase antes de reconciliar o estoque.')
  const { data, error } = await supabase.rpc('reconcile_inventory')
  if (error) throw error
  return (data ?? []) as ReconciliationRow[]
}

export async function listStock(search = ''): Promise<StockRow[]> {
  if (!supabase) return []
  const [{ data, error }, { data: policies, error: policyError }] = await Promise.all([
    supabase.from('stock_positions').select('id,item_id,location_id,on_hand_q,reserved_q,condition,expires_on:lots(expires_on),items!inner(id,sku,name,family,nature,base_uom),locations!inner(name)').order('created_at', { ascending: false }).limit(300),
    supabase.from('item_location_policies').select('item_id,location_id,min_q,reorder_q').limit(1000),
  ])
  if (error) throw error
  if (policyError) throw policyError
  const policyByPosition = new Map((policies ?? []).map(policy => [`${policy.item_id}:${policy.location_id}`, { min_q: Number(policy.min_q), reorder_q: Number(policy.reorder_q) }]))
  return (data ?? []).filter((row) => !search || String((row.items as { name?: string }).name ?? '').toLowerCase().includes(search.toLowerCase()) || String((row.items as { sku?: string }).sku ?? '').toLowerCase().includes(search.toLowerCase())).map(row => {
    const item = row.items as unknown as { id: string; sku: string; name: string; family: StockRow['family']; nature: StockRow['nature']; base_uom: string }
    const location = row.locations as unknown as { name: string }
    const lot = (row.expires_on as { expires_on?: string }[] | null)?.[0]
    const policy = policyByPosition.get(`${row.item_id}:${row.location_id}`) ?? { min_q: 0, reorder_q: 0 }
    const eligible = row.condition === 'usable' && (!lot?.expires_on || lot.expires_on >= new Date().toISOString().slice(0, 10))
    return { id: row.id, sku: item.sku, name: item.name, family: item.family, nature: item.nature, base_uom: item.base_uom, location_name: location.name, on_hand_q: Number(row.on_hand_q), reserved_q: eligible ? Number(row.reserved_q) : 0, available_q: eligible ? Number(row.on_hand_q) - Number(row.reserved_q) : 0, min_q: policy.min_q, reorder_q: policy.reorder_q, condition: eligible ? row.condition : (row.condition === 'usable' ? 'expired' : row.condition), expires_on: lot?.expires_on ?? null, avg_unit_cost: 0 }
  })
}

export async function releaseQuarantinedStock(input: { position_id: string; quantity: number; reason: string; idempotency_key?: string }) {
  if (!supabase) throw new Error('Configure o Supabase antes de liberar quarentena.')
  const { data, error } = await supabase.rpc('release_quarantined_stock', { p_position_id: input.position_id, p_quantity: input.quantity, p_reason: input.reason, p_idempotency_key: input.idempotency_key ?? crypto.randomUUID() })
  if (error) throw error
  return data
}

export async function listCountTargets() {
  if (!supabase) return []
  const { data, error } = await supabase.from('stock_positions').select('id,item_id,location_id,lot_id,on_hand_q,items(name,sku,base_uom),locations(name),lots(lot_code,expires_on)').eq('condition', 'usable').order('created_at', { ascending: false }).limit(300)
  if (error) throw error
  return data ?? []
}

export async function listStockCounts() {
  if (!supabase) return []
  const { data, error } = await supabase.from('stock_counts').select('id,item_id,location_id,lot_id,counted_q,status,reason,created_at,items(name,sku),locations(name),lots(lot_code)').order('created_at', { ascending: false }).limit(100)
  if (error) throw error
  return data ?? []
}

export async function recordStockCount(input: { item_id: string; location_id: string; lot_id: string; counted_q: number; reason?: string }) {
  if (!supabase) throw new Error('Configure o Supabase antes de registrar contagens.')
  const { data, error } = await supabase.rpc('record_stock_count', { p_item_id: input.item_id, p_location_id: input.location_id, p_lot_id: input.lot_id, p_counted_q: input.counted_q, p_reason: input.reason ?? null })
  if (error) throw error
  return data
}

export async function approveStockCount(id: string) {
  if (!supabase) throw new Error('Configure o Supabase antes de aprovar contagens.')
  const { data, error } = await supabase.rpc('approve_stock_count', { p_count_id: id })
  if (error) throw error
  return data
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

export async function postMovement(input: { type: MovementType; item_id: string; location_id: string; quantity: number; uom: string; lot_id?: string; reason?: string; to_location_id?: string; idempotency_key?: string }) {
  if (!supabase) throw new Error('Configure o Supabase antes de movimentar estoque.')
  const { data, error } = await supabase.rpc('post_stock_movement', { p_type: input.type, p_item_id: input.item_id, p_location_id: input.location_id, p_to_location_id: input.to_location_id ?? null, p_lot_id: input.lot_id ?? null, p_quantity: input.quantity, p_input_uom: input.uom, p_reason: input.reason ?? null, p_idempotency_key: input.idempotency_key ?? crypto.randomUUID() })
  if (error) throw error
  return data
}

export async function listItems(includeInactive = false) {
  if (!supabase) return []
  let query = supabase.from('items').select('id,sku,name,base_uom,family,nature,status').order('name').limit(300)
  if (!includeInactive) query = query.eq('status', 'active')
  const { data, error } = await query
  if (error) throw error
  return data ?? []
}

export async function listLocations(includeInactive = false) {
  if (!supabase) return []
  let query = supabase.from('locations').select('id,name,type,status,is_stockable').eq('is_stockable', true).order('name')
  if (!includeInactive) query = query.eq('status', 'active')
  const { data, error } = await query
  if (error) throw error
  return data ?? []
}

export async function listUnits(includeInactive = false) {
  if (!supabase) return []
  let query = supabase.from('units').select('id,name,code,status').order('name')
  if (!includeInactive) query = query.eq('status', 'active')
  const { data, error } = await query
  if (error) throw error
  return data ?? []
}

export async function listSuppliers(includeInactive = false) {
  if (!supabase) return []
  let query = supabase.from('suppliers').select('id,name,status').order('name')
  if (!includeInactive) query = query.eq('status', 'active')
  const { data, error } = await query
  if (error) throw error
  return data ?? []
}

export async function createUnit(input: { name: string; code: string }) {
  if (!supabase) throw new Error('Configure o Supabase antes de cadastrar unidades.')
  const { data, error } = await supabase.rpc('create_unit', { p_name: input.name, p_code: input.code })
  if (error) throw error
  return data
}

export async function createLocation(input: { unit_id: string; name: string; type: string; is_stockable: boolean }) {
  if (!supabase) throw new Error('Configure o Supabase antes de cadastrar locais.')
  const { data, error } = await supabase.rpc('create_location', { p_unit_id: input.unit_id, p_name: input.name, p_type: input.type, p_is_stockable: input.is_stockable })
  if (error) throw error
  return data
}

export async function createItem(input: { sku: string; name: string; family: string; nature: string; base_uom: string; category_name?: string }) {
  if (!supabase) throw new Error('Configure o Supabase antes de cadastrar materiais.')
  const { data, error } = await supabase.rpc('create_item', { p_sku: input.sku, p_name: input.name, p_family: input.family, p_nature: input.nature, p_base_uom: input.base_uom, p_category_name: input.category_name ?? null })
  if (error) throw error
  return data
}

export async function createItemPackage(input: { item_id: string; name: string; factor: number; barcode?: string }) {
  if (!supabase) throw new Error('Configure o Supabase antes de cadastrar embalagens.')
  const { data, error } = await supabase.rpc('create_item_package', { p_item_id: input.item_id, p_name: input.name, p_factor: input.factor, p_barcode: input.barcode ?? null })
  if (error) throw error
  return data
}

export async function upsertItemLocationPolicy(input: { item_id: string; location_id: string; min_q: number; reorder_q: number; max_q: number }) {
  if (!supabase) throw new Error('Configure o Supabase antes de configurar reposição.')
  const { data, error } = await supabase.rpc('upsert_item_location_policy', { p_item_id: input.item_id, p_location_id: input.location_id, p_min_q: input.min_q, p_reorder_q: input.reorder_q, p_max_q: input.max_q })
  if (error) throw error
  return data
}

export async function createSupplier(input: { name: string; email?: string; phone?: string }) {
  if (!supabase) throw new Error('Configure o Supabase antes de cadastrar fornecedores.')
  const { data, error } = await supabase.rpc('create_supplier', { p_name: input.name, p_tax_id: null, p_email: input.email ?? null, p_phone: input.phone ?? null })
  if (error) throw error
  return data
}

export async function linkSupplierItem(input: { supplier_id: string; item_id: string; lead_time_days: number; supplier_sku?: string; last_unit_cost?: number }) {
  if (!supabase) throw new Error('Configure o Supabase antes de vincular fornecedor.')
  const { data, error } = await supabase.rpc('link_supplier_item', { p_supplier_id: input.supplier_id, p_item_id: input.item_id, p_lead_time_days: input.lead_time_days, p_supplier_sku: input.supplier_sku ?? null, p_last_unit_cost: input.last_unit_cost ?? null })
  if (error) throw error
  return data
}

export async function setUnitStatus(id: string, status: 'active' | 'inactive') {
  if (!supabase) throw new Error('Configure o Supabase antes de arquivar unidades.')
  const { data, error } = await supabase.rpc('set_unit_status', { p_unit_id: id, p_status: status })
  if (error) throw error
  return data
}

export async function setLocationStatus(id: string, status: 'active' | 'inactive') {
  if (!supabase) throw new Error('Configure o Supabase antes de arquivar locais.')
  const { data, error } = await supabase.rpc('set_location_status', { p_location_id: id, p_status: status })
  if (error) throw error
  return data
}

export async function setItemStatus(id: string, status: 'active' | 'inactive') {
  if (!supabase) throw new Error('Configure o Supabase antes de inativar materiais.')
  const { data, error } = await supabase.rpc('set_item_status', { p_item_id: id, p_status: status })
  if (error) throw error
  return data
}

export async function setSupplierStatus(id: string, status: 'active' | 'inactive') {
  if (!supabase) throw new Error('Configure o Supabase antes de inativar fornecedores.')
  const { data, error } = await supabase.rpc('set_supplier_status', { p_supplier_id: id, p_status: status })
  if (error) throw error
  return data
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

export async function listEventDifferences(eventId?: string) {
  if (!supabase) return []
  let query = supabase.from('event_differences').select('id,event_id,manifest_line_id,reservation_id,item_id,location_id,lot_id,expected_q,consumed_q,difference_q,classification,status,reason,created_at,items(name,sku),locations(name),lots(lot_code,expires_on)').order('created_at', { ascending: false }).limit(100)
  if (eventId) query = query.eq('event_id', eventId)
  const { data, error } = await query
  if (error) throw error
  return data ?? []
}

export async function classifyEventDifference(input: { difference_id: string; classification: string; consumed_q: number; reason?: string }) {
  if (!supabase) throw new Error('Configure o Supabase antes de classificar diferenças.')
  const { data, error } = await supabase.rpc('classify_event_difference', { p_difference_id: input.difference_id, p_classification: input.classification, p_consumed_q: input.consumed_q, p_reason: input.reason ?? null })
  if (error) throw error
  return data
}

export async function approveEventDifference(id: string) {
  if (!supabase) throw new Error('Configure o Supabase antes de aprovar diferenças.')
  const { data, error } = await supabase.rpc('approve_event_difference', { p_difference_id: id })
  if (error) throw error
  return data
}

export async function createEvent(input: { name: string; code: string; venue: string; starts_at: string; ends_at: string }) {
  if (!supabase) throw new Error('Configure o Supabase antes de criar eventos.')
  const { data, error } = await supabase.rpc('create_event', { p_name: input.name, p_code: input.code, p_venue: input.venue, p_starts_at: input.starts_at, p_ends_at: input.ends_at })
  if (error) throw error
  return data
}

export async function listPurchaseRequests() {
  if (!supabase) return []
  const { data, error } = await supabase.from('purchase_requests').select('id,status,needed_by,reason,created_at,purchase_request_lines(quantity,items(name,sku),locations(name)),purchase_orders(id,order_no,status,purchase_order_lines(ordered_q,received_q,delivered_q,items(name,sku)),receipts(id,location_id,status,receipt_lines(id,accepted_q,blocked_q,rejected_q,returned_q,lot_id)))').order('created_at', { ascending: false }).limit(100)
  if (error) throw error
  return data ?? []
}

export async function returnSupplierMaterial(input: { receipt_id: string; quantity: number; reason: string; idempotency_key?: string }) {
  if (!supabase) throw new Error('Configure o Supabase antes de devolver ao fornecedor.')
  const { data, error } = await supabase.rpc('return_supplier_material', { p_receipt_id: input.receipt_id, p_quantity: input.quantity, p_reason: input.reason, p_idempotency_key: input.idempotency_key ?? crypto.randomUUID() })
  if (error) throw error
  return data
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

export async function rejectPurchaseRequest(id: string, reason: string) {
  if (!supabase) throw new Error('Configure o Supabase antes de rejeitar compras.')
  const { data, error } = await supabase.rpc('reject_purchase_request', { p_request_id: id, p_reason: reason })
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

export async function receivePurchaseOrderSplit(input: { order_id: string; location_id: string; accepted_q: number; blocked_q: number; rejected_q: number; lot_code: string; expires_on: string; unit_cost?: number; idempotency_key?: string }) {
  if (!supabase) throw new Error('Configure o Supabase antes de receber pedidos.')
  const { data, error } = await supabase.rpc('receive_purchase_order_split', { p_order_id: input.order_id, p_location_id: input.location_id, p_accepted_q: input.accepted_q, p_blocked_q: input.blocked_q, p_rejected_q: input.rejected_q, p_lot_code: input.lot_code, p_expires_on: input.expires_on, p_unit_cost: input.unit_cost ?? null, p_idempotency_key: input.idempotency_key ?? crypto.randomUUID() })
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

export async function acceptInvitation(token: string, displayName = '') {
  if (!supabase) throw new Error('Configure o Supabase antes de aceitar convites.')
  const { data, error } = await supabase.rpc('accept_invitation', { p_token: token, p_display_name: displayName })
  if (error) throw error
  return data
}

export async function reserveEventMaterial(input: { event_id: string; item_id: string; location_id: string; quantity: number; lot_id?: string; idempotency_key?: string }) {
  if (!supabase) throw new Error('Configure o Supabase antes de reservar materiais.')
  const { data, error } = await supabase.rpc('reserve_event_material', { p_event_id: input.event_id, p_item_id: input.item_id, p_location_id: input.location_id, p_quantity: input.quantity, p_lot_id: input.lot_id ?? null, p_idempotency_key: input.idempotency_key ?? crypto.randomUUID() })
  if (error) throw error
  return data
}

export async function replenishEventMaterial(input: { event_id: string; item_id: string; location_id: string; quantity: number; lot_id?: string; idempotency_key?: string }) {
  if (!supabase) throw new Error('Configure o Supabase antes de repor eventos.')
  const { data, error } = await supabase.rpc('replenish_event_material', { p_event_id: input.event_id, p_item_id: input.item_id, p_location_id: input.location_id, p_quantity: input.quantity, p_lot_id: input.lot_id ?? null, p_idempotency_key: input.idempotency_key ?? crypto.randomUUID() })
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

export async function uploadPrivateFile(tenantId: string, path: string, file: File) {
  if (!supabase) throw new Error('Configure o Supabase antes de enviar arquivos.')
  const objectPath = `${tenantId}/${path.replace(/^\/+/, '')}`
  const { data, error } = await supabase.storage.from('prumo-private').upload(objectPath, file, { upsert: false })
  if (error) throw error
  return data
}

export async function createPrivateDownloadUrl(tenantId: string, path: string, expiresIn = 300) {
  if (!supabase) throw new Error('Configure o Supabase antes de baixar arquivos.')
  const objectPath = `${tenantId}/${path.replace(/^\/+/, '')}`
  const { data, error } = await supabase.storage.from('prumo-private').createSignedUrl(objectPath, expiresIn)
  if (error) throw error
  return data.signedUrl
}

export function downloadStockCsv(rows: { sku: string; name: string; location_name: string; on_hand_q: number; reserved_q: number; available_q: number; base_uom: string; condition: string }[]) {
  const escape = (value: string | number) => { const text = String(value); return /^[=+\-@]/.test(text) ? `'${text}` : `"${text.replaceAll('"', '""')}"` }
  const csv = ['SKU,Item,Local,Físico,Reservado,Disponível,Unidade,Condição', ...rows.map(row => [row.sku,row.name,row.location_name,row.on_hand_q,row.reserved_q,row.available_q,row.base_uom,row.condition].map(escape).join(','))].join('\r\n')
  const link = document.createElement('a'); link.href = URL.createObjectURL(new Blob([`\ufeff${csv}`], { type: 'text/csv;charset=utf-8' })); link.download = `prumo-estoque-${new Date().toISOString().slice(0,10)}.csv`; link.click(); URL.revokeObjectURL(link.href)
}
