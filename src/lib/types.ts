export type Tab = 'today' | 'stock' | 'move' | 'events' | 'purchases' | 'reports' | 'admin'
export type MovementType = 'opening' | 'receipt' | 'consumption' | 'loss' | 'reclassification' | 'transfer' | 'adjustment' | 'reversal'
export type ItemNature = 'consumable' | 'returnable'
export type ItemFamily = 'beverages' | 'food' | 'supplies' | 'disposables' | 'equipment' | 'utensils' | 'event_materials' | 'support'

export type StockSummary = {
  totalItems: number
  availableValue: number
  criticalItems: number
  openEvents: number
  pendingReceipts: number
  openAlerts: number
}

export type StockRow = {
  id: string
  sku: string
  name: string
  family: ItemFamily
  nature: ItemNature
  base_uom: string
  location_name: string
  on_hand_q: number
  reserved_q: number
  available_q: number
  min_q: number
  reorder_q: number
  condition: string
  expires_on: string | null
  avg_unit_cost: number
}

export type ActivityRow = {
  id: string
  type: string
  document_number: string
  item_name: string | null
  quantity: number | null
  unit: string | null
  location_name: string | null
  created_at: string
  status: string
}

export type AlertRow = {
  id: string
  kind: string
  status: 'new' | 'acknowledged' | 'resolved'
  message: string
  created_at: string
  resolved_at: string | null
  item_id: string | null
  event_id: string | null
  items?: { name: string; sku: string } | { name: string; sku: string }[] | null
  events?: { name: string; code: string } | { name: string; code: string }[] | null
}
