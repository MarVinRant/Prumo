import { FormEvent, useEffect, useState } from 'react'
import { AlertTriangle, ChevronRight, PackageCheck } from 'lucide-react'
import { listEventReservations, listEvents, listItems, listLocations, releaseEventReservation, reserveEventMaterial } from './lib/api'

type EventRow = { id: string; name: string; code: string; status: string }
type ReservationRow = { id: string; event_id: string; item_id: string; location_id: string; quantity: number; status: string; items?: { name: string; sku: string }[]; locations?: { name: string }[] }

export default function EventReservationPanel() {
  const [events, setEvents] = useState<EventRow[]>([])
  const [items, setItems] = useState<{ id: string; name: string; sku: string }[]>([])
  const [locations, setLocations] = useState<{ id: string; name: string }[]>([])
  const [reservations, setReservations] = useState<ReservationRow[]>([])
  const [form, setForm] = useState({ event_id: '', item_id: '', location_id: '', quantity: '' })
  const [busy, setBusy] = useState(false)
  const [error, setError] = useState('')

  async function reload() {
    const [nextEvents, nextItems, nextLocations, nextReservations] = await Promise.all([listEvents(), listItems(), listLocations(), listEventReservations()])
    setEvents(nextEvents as EventRow[])
    setItems(nextItems)
    setLocations(nextLocations)
    setReservations(nextReservations as ReservationRow[])
    setForm(current => ({ ...current, event_id: current.event_id || (nextEvents as EventRow[])[0]?.id || '', item_id: current.item_id || nextItems[0]?.id || '', location_id: current.location_id || nextLocations[0]?.id || '' }))
  }

  useEffect(() => { void reload().catch(err => setError(err instanceof Error ? err.message : 'Falha ao carregar reservas.')) }, [])

  async function reserve(event: FormEvent) {
    event.preventDefault(); setBusy(true); setError('')
    try { await reserveEventMaterial({ event_id: form.event_id, item_id: form.item_id, location_id: form.location_id, quantity: Number(form.quantity) }); await reload(); setForm(current => ({ ...current, quantity: '' })) }
    catch (err) { setError(err instanceof Error ? err.message : 'Não foi possível reservar o material.') }
    finally { setBusy(false) }
  }

  async function release(id: string) {
    setBusy(true); setError('')
    try { await releaseEventReservation(id); await reload() }
    catch (err) { setError(err instanceof Error ? err.message : 'Não foi possível liberar a reserva.') }
    finally { setBusy(false) }
  }

  const reservableEvents = events.filter(event => ['planned', 'separating'].includes(event.status))
  return <>
    <div className="form-panel"><div className="form-intro"><div className="status-icon green"><PackageCheck size={19} /></div><div><h2>Reserva FEFO</h2><p>Reserva bloqueia disponibilidade, mas não baixa o físico. O servidor escolhe o lote válido mais próximo do vencimento.</p></div></div><form onSubmit={reserve}><div className="form-grid"><label>Evento<select value={form.event_id} onChange={event => setForm({ ...form, event_id: event.target.value })} required>{reservableEvents.map(row => <option key={row.id} value={row.id}>{row.name} · {row.code}</option>)}</select></label><label>Item<select value={form.item_id} onChange={event => setForm({ ...form, item_id: event.target.value })} required>{items.map(item => <option key={item.id} value={item.id}>{item.name} · {item.sku}</option>)}</select></label><label>Local<select value={form.location_id} onChange={event => setForm({ ...form, location_id: event.target.value })} required>{locations.map(location => <option key={location.id} value={location.id}>{location.name}</option>)}</select></label><label>Quantidade<input type="number" min="0.000001" step="0.000001" value={form.quantity} onChange={event => setForm({ ...form, quantity: event.target.value })} required /></label></div><div className="form-actions"><span className="muted">{error}</span><button className="primary-btn" disabled={busy || !form.event_id || !form.item_id || !form.location_id}>Reservar material<ChevronRight size={17} /></button></div></form></div>
    <div className="table-panel"><div className="panel-heading"><div><h2>Reservas ativas</h2><p>Liberação devolve a disponibilidade sem gerar consumo.</p></div></div><div className="table-scroll"><table><thead><tr><th>Item</th><th>Evento</th><th>Quantidade</th><th>Status</th><th>Ação</th></tr></thead><tbody>{reservations.length ? reservations.map(reservation => { const item = reservation.items?.[0]; const location = reservation.locations?.[0]; const event = events.find(row => row.id === reservation.event_id); return <tr key={reservation.id}><td><strong>{item?.name || reservation.item_id.slice(0, 8)}</strong><small>{item?.sku || '—'} · {location?.name || '—'}</small></td><td>{event?.name || reservation.event_id.slice(0, 8)}</td><td>{Number(reservation.quantity).toLocaleString('pt-BR')}</td><td><span className={reservation.status === 'firm' ? 'tag warning' : 'tag ok'}>{reservation.status}</span></td><td>{reservation.status === 'firm' && <button className="ghost-btn" disabled={busy} onClick={() => void release(reservation.id)}>Liberar</button>}</td></tr> }) : <tr><td colSpan={5}><div className="empty"><div className="status-icon blue"><PackageCheck size={17} /></div><strong>Nenhuma reserva</strong><span>Reserve um item para bloquear disponibilidade sem alterar o físico.</span></div></td></tr>}</tbody></table></div></div>
    {error && <div className="notice error" role="alert"><AlertTriangle size={16} />{error}</div>}
  </>
}
