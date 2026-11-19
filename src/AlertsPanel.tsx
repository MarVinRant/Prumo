import { FormEvent, useEffect, useState } from 'react'
import { AlertTriangle, Check, CheckCircle2, ShieldCheck } from 'lucide-react'
import { acknowledgeAlert, listAlerts, resolveAlert } from './lib/api'
import type { AlertRow } from './lib/types'

function relatedLabel(alert: AlertRow) {
  const item = Array.isArray(alert.items) ? alert.items[0] : alert.items
  const event = Array.isArray(alert.events) ? alert.events[0] : alert.events
  if (item) return `${item.name} · ${item.sku}`
  if (event) return `${event.name} · ${event.code}`
  return 'Operação geral'
}

export default function AlertsPanel() {
  const [alerts, setAlerts] = useState<AlertRow[]>([])
  const [resolveId, setResolveId] = useState('')
  const [reason, setReason] = useState('')
  const [busy, setBusy] = useState(false)
  const [error, setError] = useState('')

  async function reload() {
    setAlerts(await listAlerts())
  }

  useEffect(() => { void reload().catch(error => setError(error instanceof Error ? error.message : 'Não foi possível carregar os alertas.')) }, [])

  async function acknowledge(id: string) {
    setBusy(true); setError('')
    try { await acknowledgeAlert(id); await reload() } catch (err) { setError(err instanceof Error ? err.message : 'Não foi possível reconhecer o alerta.') } finally { setBusy(false) }
  }

  async function resolve(event: FormEvent, id: string) {
    event.preventDefault(); setBusy(true); setError('')
    try { await resolveAlert(id, reason); setResolveId(''); setReason(''); await reload() } catch (err) { setError(err instanceof Error ? err.message : 'Não foi possível resolver o alerta.') } finally { setBusy(false) }
  }

  const openAlerts = alerts.filter(alert => alert.status !== 'resolved')
  return <section className="panel alerts-panel" aria-labelledby="alerts-title">
    <div className="panel-heading"><div><h2 id="alerts-title">Fila de alertas</h2><p>Reconhecer registra ciência; resolver exige causa corrigida e permissão de gestão.</p></div><span className="tag warning"><AlertTriangle size={14} /> {openAlerts.length} abertos</span></div>
    {openAlerts.length ? <div className="alert-list">{openAlerts.map(alert => <div className="alert-row" key={alert.id}><div className="status-icon warning"><AlertTriangle size={16} /></div><div className="row-grow"><strong>{alert.message}</strong><span>{relatedLabel(alert)} · {new Date(alert.created_at).toLocaleString('pt-BR')}</span>{alert.status === 'acknowledged' && <small>Reconhecido</small>}</div><div className="button-row">{alert.status === 'new' && <button className="ghost-btn" disabled={busy} onClick={() => void acknowledge(alert.id)}><Check size={15} /> Reconhecer</button>}{alert.status === 'acknowledged' && <button className="ghost-btn" disabled={busy} onClick={() => setResolveId(resolveId === alert.id ? '' : alert.id)}><CheckCircle2 size={15} /> Resolver</button>}</div>{resolveId === alert.id && <form className="inline-form" onSubmit={event => void resolve(event, alert.id)}><input aria-label="Causa resolvida" value={reason} onChange={event => setReason(event.target.value)} placeholder="Causa corrigida" required /><button className="primary-btn" disabled={busy}><ShieldCheck size={15} /> Confirmar</button></form>}</div>)}</div> : <div className="empty"><div className="status-icon green"><CheckCircle2 size={17} /></div><strong>Nenhum alerta aberto</strong><span>A fila operacional está sem pendências reconhecidas ou novas.</span></div>}
    {error && <p className="muted" role="alert">{error}</p>}
  </section>
}
