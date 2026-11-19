import { FormEvent, useEffect, useState } from 'react'
import { AlertTriangle, ChevronRight, PackageCheck } from 'lucide-react'
import { approveEventDifference, classifyEventDifference, closeEvent, consumeEventReservation, listEventDifferences, listEventReservations, listEvents, listItems, listLocations, releaseEventReservation, reopenEvent, reserveEventMaterial, setEventStatus } from './lib/api'
import AssetsPanel from './AssetsPanel'

type EventRow = { id: string; name: string; code: string; status: string }
type ReservationRow = { id: string; event_id: string; item_id: string; location_id: string; quantity: number; status: string; items?: { name: string; sku: string } | { name: string; sku: string }[]; locations?: { name: string } | { name: string }[] }
type DifferenceRow = { id: string; event_id: string; item_id: string; location_id: string; lot_id: string; expected_q: number; consumed_q: number; difference_q: number; classification: string | null; status: string; reason: string | null; items?: { name: string; sku: string } | { name: string; sku: string }[]; locations?: { name: string } | { name: string }[]; lots?: { lot_code: string; expires_on: string | null } | { lot_code: string; expires_on: string | null }[] }

export default function EventReservationPanel() {
  const [events, setEvents] = useState<EventRow[]>([])
  const [items, setItems] = useState<{ id: string; name: string; sku: string }[]>([])
  const [locations, setLocations] = useState<{ id: string; name: string }[]>([])
  const [reservations, setReservations] = useState<ReservationRow[]>([])
  const [differences, setDifferences] = useState<DifferenceRow[]>([])
  const [differenceEdits, setDifferenceEdits] = useState<Record<string, { classification: string; consumed_q: string; reason: string }>>({})
  const [form, setForm] = useState({ event_id: '', item_id: '', location_id: '', quantity: '' })
  const [busy, setBusy] = useState(false)
  const [error, setError] = useState('')

  async function reload() {
    const [nextEvents, nextItems, nextLocations, nextReservations, nextDifferences] = await Promise.all([listEvents(), listItems(), listLocations(), listEventReservations(), listEventDifferences()])
    setEvents(nextEvents as EventRow[])
    setItems(nextItems)
    setLocations(nextLocations)
    setReservations(nextReservations as ReservationRow[])
    setDifferences(nextDifferences as DifferenceRow[])
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

  async function consume(id: string) {
    setBusy(true); setError('')
    try { await consumeEventReservation(id); await reload() }
    catch (err) { setError(err instanceof Error ? err.message : 'Não foi possível registrar o consumo do evento.') }
    finally { setBusy(false) }
  }

  async function transition(id: string, status: string) {
    setBusy(true); setError('')
    try { await setEventStatus(id, status); await reload() }
    catch (err) { setError(err instanceof Error ? err.message : 'Não foi possível avançar o estado do evento.') }
    finally { setBusy(false) }
  }

  async function reopen(id: string) {
    setBusy(true); setError('')
    try { await reopenEvent(id, 'Reabertura para correção operacional na homologação'); await reload() }
    catch (err) { setError(err instanceof Error ? err.message : 'Não foi possível reabrir o evento.') }
    finally { setBusy(false) }
  }

  async function close(id: string) {
    setBusy(true); setError('')
    try { await closeEvent(id, 'Acerto homologação concluído'); await reload() }
    catch (err) { setError(err instanceof Error ? err.message : 'Não foi possível fechar o evento.') }
    finally { setBusy(false) }
  }

  async function classify(difference: DifferenceRow) {
    const edit = differenceEdits[difference.id] ?? { classification: 'returned', consumed_q: String(difference.consumed_q), reason: '' }
    setBusy(true); setError('')
    try { await classifyEventDifference({ difference_id: difference.id, classification: edit.classification, consumed_q: Number(edit.consumed_q), reason: edit.reason }); await reload() }
    catch (err) { setError(err instanceof Error ? err.message : 'Não foi possível classificar a diferença.') }
    finally { setBusy(false) }
  }

  async function approveDifference(id: string) {
    setBusy(true); setError('')
    try { await approveEventDifference(id); await reload() }
    catch (err) { setError(err instanceof Error ? err.message : 'Não foi possível aprovar a diferença.') }
    finally { setBusy(false) }
  }

  const reservableEvents = events.filter(event => ['planned', 'separating'].includes(event.status))
  return <>
    <div className="table-panel"><div className="panel-heading"><div><h2>Ciclo do evento</h2><p>Avance somente após conferir reserva, expedição e operação; cada transição é auditada.</p></div></div><div className="table-scroll"><table><thead><tr><th>Evento</th><th>Status</th><th>Ação</th></tr></thead><tbody>{events.length ? events.map(event => <tr key={event.id}><td><strong>{event.name}</strong><small>{event.code}</small></td><td><span className={event.status === 'closed' ? 'tag ok' : 'tag warning'}>{event.status}</span></td><td><div className="button-row">{event.status === 'planned' && <button className="ghost-btn" disabled={busy} onClick={() => void transition(event.id, 'separating')}>Iniciar separação</button>}{event.status === 'separating' && <button className="ghost-btn" disabled={busy} onClick={() => void transition(event.id, 'dispatched')}>Expedir</button>}{event.status === 'dispatched' && <button className="ghost-btn" disabled={busy} onClick={() => void transition(event.id, 'operating')}>Iniciar operação</button>}{event.status === 'operating' && <button className="ghost-btn" disabled={busy} onClick={() => void transition(event.id, 'settling')}>Iniciar acerto</button>}{event.status === 'settling' && <button className="ghost-btn" disabled={busy} onClick={() => void close(event.id)}>Fechar evento</button>}{event.status === 'closed' && <button className="ghost-btn" disabled={busy} onClick={() => void reopen(event.id)}>Reabrir</button>}</div></td></tr>) : <tr><td colSpan={3}>Nenhum evento disponível.</td></tr>}</tbody></table></div></div>
    <div className="form-panel"><div className="form-intro"><div className="status-icon green"><PackageCheck size={19} /></div><div><h2>Reserva FEFO</h2><p>Reserva bloqueia disponibilidade, mas não baixa o físico. O servidor escolhe o lote válido mais próximo do vencimento.</p></div></div><form onSubmit={reserve}><div className="form-grid"><label>Evento<select value={form.event_id} onChange={event => setForm({ ...form, event_id: event.target.value })} required>{reservableEvents.map(row => <option key={row.id} value={row.id}>{row.name} · {row.code}</option>)}</select></label><label>Item<select value={form.item_id} onChange={event => setForm({ ...form, item_id: event.target.value })} required>{items.map(item => <option key={item.id} value={item.id}>{item.name} · {item.sku}</option>)}</select></label><label>Local<select value={form.location_id} onChange={event => setForm({ ...form, location_id: event.target.value })} required>{locations.map(location => <option key={location.id} value={location.id}>{location.name}</option>)}</select></label><label>Quantidade<input type="number" min="0.000001" step="0.000001" value={form.quantity} onChange={event => setForm({ ...form, quantity: event.target.value })} required /></label></div><div className="form-actions"><span className="muted">{error}</span><button className="primary-btn" disabled={busy || !form.event_id || !form.item_id || !form.location_id}>Reservar material<ChevronRight size={17} /></button></div></form></div>
<div className="table-panel"><div className="panel-heading"><div><h2>Reservas ativas</h2><p>Liberação devolve a disponibilidade; consumir baixa o físico uma única vez.</p></div></div><div className="table-scroll"><table><thead><tr><th>Item</th><th>Evento</th><th>Quantidade</th><th>Status</th><th>Ação</th></tr></thead><tbody>{reservations.length ? reservations.map(reservation => { const item = Array.isArray(reservation.items) ? reservation.items[0] : reservation.items; const location = Array.isArray(reservation.locations) ? reservation.locations[0] : reservation.locations; const event = events.find(row => row.id === reservation.event_id); return <tr key={reservation.id}><td><strong>{item?.name || reservation.item_id.slice(0, 8)}</strong><small>{item?.sku || '—'} · {location?.name || '—'}</small></td><td>{event?.name || reservation.event_id.slice(0, 8)}</td><td>{Number(reservation.quantity).toLocaleString('pt-BR')}</td><td><span className={reservation.status === 'firm' ? 'tag warning' : 'tag ok'}>{reservation.status}</span></td><td><div className="button-row">{reservation.status === 'firm' && <><button className="ghost-btn" disabled={busy} onClick={() => void consume(reservation.id)}>Consumir</button><button className="ghost-btn" disabled={busy} onClick={() => void release(reservation.id)}>Liberar</button></>}</div></td></tr> }) : <tr><td colSpan={5}><div className="empty"><div className="status-icon blue"><PackageCheck size={17} /></div><strong>Nenhuma reserva</strong><span>Reserve um item para bloquear disponibilidade sem alterar o físico.</span></div></td></tr>}</tbody></table></div></div>
    <div className="table-panel"><div className="panel-heading"><div><h2>Acerto e diferenças</h2><p>O despacho cria um manifesto versionado. O fechamento exige toda diferença classificada e aprovada.</p></div></div><div className="table-scroll"><table><thead><tr><th>Item / lote</th><th>Esperado</th><th>Consumido</th><th>Diferença</th><th>Classificação</th><th>Ação</th></tr></thead><tbody>{differences.length ? differences.map(difference => { const item = Array.isArray(difference.items) ? difference.items[0] : difference.items; const lot = Array.isArray(difference.lots) ? difference.lots[0] : difference.lots; const edit = differenceEdits[difference.id] ?? { classification: difference.classification || 'returned', consumed_q: String(difference.consumed_q), reason: '' }; return <tr key={difference.id}><td><strong>{item?.name || difference.item_id.slice(0, 8)}</strong><small>{item?.sku || '—'} · lote {lot?.lot_code || difference.lot_id.slice(0, 8)}</small></td><td>{Number(difference.expected_q).toLocaleString('pt-BR')}</td><td>{Number(difference.consumed_q).toLocaleString('pt-BR')}</td><td>{Number(difference.difference_q).toLocaleString('pt-BR')}</td><td>{difference.status === 'approved' ? <span className="tag ok">{difference.classification || 'none'} · aprovado</span> : <div className="inline-form"><select aria-label="Classificação da diferença" value={edit.classification} onChange={event => setDifferenceEdits(current => ({ ...current, [difference.id]: { ...edit, classification: event.target.value } }))}><option value="returned">Retornado</option><option value="consumed">Consumido</option><option value="loss">Perda</option><option value="damaged">Avariado</option><option value="unaccounted">Não localizado</option></select><input aria-label="Quantidade consumida" type="number" min={difference.consumed_q} max={difference.expected_q} step="0.000001" value={edit.consumed_q} onChange={event => setDifferenceEdits(current => ({ ...current, [difference.id]: { ...edit, consumed_q: event.target.value } }))} /><input aria-label="Motivo da diferença" placeholder="Motivo" value={edit.reason} onChange={event => setDifferenceEdits(current => ({ ...current, [difference.id]: { ...edit, reason: event.target.value } }))} /></div>}</td><td><div className="button-row">{difference.status !== 'approved' && <><button className="ghost-btn" disabled={busy} onClick={() => void classify(difference)}>Classificar</button>{difference.classification && <button className="ghost-btn" disabled={busy} onClick={() => void approveDifference(difference.id)}>Aprovar</button>}</>}</div></td></tr> }) : <tr><td colSpan={6}>Nenhuma diferença preparada. Avance o evento até o acerto para gerar o manifesto e a conferência.</td></tr>}</tbody></table></div></div>
    <AssetsPanel />
    {error && <div className="notice error" role="alert"><AlertTriangle size={16} />{error}</div>}
  </>
}
