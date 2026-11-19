import { FormEvent, useEffect, useState } from 'react'
import { CheckCircle2, CircleDollarSign, ShieldCheck } from 'lucide-react'
import { approveValueAdjustment, listFinanceAdjustments, listItems, listLocations, requestValueAdjustment } from './lib/api'
import type { FinanceAdjustment } from './lib/types'

type Option = { id: string; name: string; sku?: string }

export default function FinancePanel() {
  const [authorized, setAuthorized] = useState<boolean | null>(null)
  const [adjustments, setAdjustments] = useState<FinanceAdjustment[]>([])
  const [items, setItems] = useState<Option[]>([])
  const [locations, setLocations] = useState<Option[]>([])
  const [form, setForm] = useState({ item_id: '', location_id: '', amount: '', reason: '' })
  const [busy, setBusy] = useState(false)
  const [error, setError] = useState('')

  async function reload() {
    try {
      const [nextAdjustments, nextItems, nextLocations] = await Promise.all([listFinanceAdjustments(), listItems(), listLocations()])
      setAdjustments(nextAdjustments); setItems(nextItems); setLocations(nextLocations); setAuthorized(true)
      setForm(current => ({ ...current, item_id: current.item_id || nextItems[0]?.id || '', location_id: current.location_id || nextLocations[0]?.id || '' }))
    } catch (err) {
      if (String(err instanceof Error ? err.message : err).includes('finance_access_required')) { setAuthorized(false); return }
      setError(err instanceof Error ? err.message : 'Não foi possível carregar os ajustes financeiros.')
    }
  }
  useEffect(() => { void reload() }, [])

  async function submit(event: FormEvent) {
    event.preventDefault(); setBusy(true); setError('')
    try { await requestValueAdjustment({ item_id: form.item_id, location_id: form.location_id, amount: Number(form.amount), reason: form.reason }); await reload(); setForm(current => ({ ...current, amount: '', reason: '' })) }
    catch (err) { setError(err instanceof Error ? err.message : 'Não foi possível solicitar o ajuste.') }
    finally { setBusy(false) }
  }
  async function approve(id: string) {
    setBusy(true); setError('')
    try { await approveValueAdjustment(id); await reload() } catch (err) { setError(err instanceof Error ? err.message : 'Não foi possível aprovar o ajuste.') } finally { setBusy(false) }
  }

  if (authorized === false) return <div className="panel" style={{ marginTop: 18 }}><div className="audit-score"><ShieldCheck size={24} /><strong>Custos protegidos</strong><span>Esta conta não possui a capacidade financeira necessária para consultar ou ajustar valores.</span></div></div>
  if (authorized === null) return <div className="panel" style={{ marginTop: 18 }}><p className="muted">Verificando capacidade financeira…</p></div>
  return <div className="panel" style={{ marginTop: 18 }}><div className="panel-heading"><div><h2>Ajustes monetários</h2><p>Não altera quantidade física; exige solicitação, aprovação independente e AAL2.</p></div><CircleDollarSign size={20} /></div><form className="form-grid" onSubmit={submit}><label>Material<select value={form.item_id} onChange={event => setForm({ ...form, item_id: event.target.value })} required>{items.map(item => <option key={item.id} value={item.id}>{item.name} · {item.sku}</option>)}</select></label><label>Local<select value={form.location_id} onChange={event => setForm({ ...form, location_id: event.target.value })} required>{locations.map(location => <option key={location.id} value={location.id}>{location.name}</option>)}</select></label><label>Valor delta<input type="number" step="0.000001" value={form.amount} onChange={event => setForm({ ...form, amount: event.target.value })} required placeholder="+/-" /></label><label>Motivo<input value={form.reason} onChange={event => setForm({ ...form, reason: event.target.value })} required /></label><button className="primary-btn" disabled={busy}>{busy ? 'Salvando…' : 'Solicitar ajuste'}</button></form><div className="table-scroll" style={{ marginTop: 18 }}><table><thead><tr><th>Item/local</th><th>Valor</th><th>Status</th><th>Ação</th></tr></thead><tbody>{adjustments.length ? adjustments.map(adjustment => <tr key={adjustment.id}><td>{items.find(item => item.id === adjustment.item_id)?.name || adjustment.item_id.slice(0, 8)}<small>{locations.find(location => location.id === adjustment.location_id)?.name || adjustment.location_id.slice(0, 8)}</small></td><td>{Number(adjustment.amount).toLocaleString('pt-BR', { style: 'currency', currency: 'BRL' })}</td><td><span className={adjustment.status === 'approved' ? 'tag ok' : 'tag warning'}>{adjustment.status}</span></td><td>{adjustment.status === 'requested' && <button className="ghost-btn" disabled={busy} onClick={() => void approve(adjustment.id)}><CheckCircle2 size={15} /> Aprovar</button>}</td></tr>) : <tr><td colSpan={4}>Nenhum ajuste solicitado.</td></tr>}</tbody></table></div>{error && <p className="notice error" role="alert">{error}</p>}</div>
}
