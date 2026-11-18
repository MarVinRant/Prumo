import { FormEvent, useState } from 'react'
import { CheckCircle2, ChevronRight } from 'lucide-react'
import { acceptInvitation } from './lib/api'

export default function InviteAcceptancePanel() {
  const [token, setToken] = useState(''); const [displayName, setDisplayName] = useState(''); const [message, setMessage] = useState(''); const [busy, setBusy] = useState(false)
  async function submit(event: FormEvent) { event.preventDefault(); setBusy(true); setMessage(''); try { await acceptInvitation(token, displayName); setMessage('Convite aceito. Atualize a sessão para aplicar o novo vínculo.') ; setToken('') } catch (error) { setMessage(error instanceof Error ? error.message : 'Não foi possível aceitar o convite.') } finally { setBusy(false) } }
  return <div className="panel" style={{ marginTop: 18 }}><div className="panel-heading"><div><h2>Aceitar convite</h2><p>Use o token recebido por canal seguro; ele expira e só pode ser usado uma vez.</p></div><CheckCircle2 size={20} /></div><form className="form-grid" onSubmit={submit}><label>Token<input value={token} onChange={event => setToken(event.target.value)} required autoComplete="one-time-code" /></label><label>Nome exibido<input value={displayName} onChange={event => setDisplayName(event.target.value)} placeholder="Nome da pessoa" /></label><button className="primary-btn" disabled={busy}>{busy ? 'Validando…' : 'Aceitar convite'}<ChevronRight size={17} /></button></form>{message && <p className="muted" role="status">{message}</p>}</div>
}
