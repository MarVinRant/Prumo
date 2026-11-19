# Status de implementação M

Legenda: `implementado` = evidência técnica no repositório/banco; `parcial` = base persistente existe, mas há critérios ainda não cobertos; `pendente-humano` = não pode ser inventado por código.

| ID | Status | Evidência | Dependência/Pendência |
|---|---|---|---|
| PR-001 | pendente-humano | Hipóteses documentadas | Entrevistas e observações reais |
| PR-002 | pendente-humano | Decisões D03-D10 registradas como premissas | Validação comercial real |
| PR-003 | implementado | React responsivo, tokens PRUMO, foco visível | Validação do nome da marca |
| PR-004 | implementado | Vite/TS lockfile, `.env.example`, `wrangler.jsonc` | URL Cloudflare |
| PR-005 | parcial | Supabase Auth, signup/login, recuperação por e-mail, sessão persistente, painel TOTP e wrappers de comandos privilegiados exigindo JWT `aal2` | Teste autenticado com conta privilegiada, configuração de proteção contra senhas vazadas e fluxo de desafio no login |
| PR-006 | parcial | `bootstrap_workspace` transacional/idempotente | Troca de contexto |
| PR-007 | parcial | Convites com token hash, expiração, revogação, aceite autenticado e auditoria | Entrega automática por SMTP e teste multiusuário |
| PR-008 | parcial | FKs compostas, RLS e isolamento por tenant | Capacidades/escopos finos por local |
| PR-009 | parcial | units/locations, seed de dois locais | UI de cadastro/arquivamento |
| PR-010 | parcial | Oito famílias e catálogo persistente | CRUD completo de catálogo |
| PR-011 | parcial | item_packages e fator por SKU | UI e validações kg/L completas |
| PR-012 | parcial | stock_positions com precisão decimal | Conversões adicionais e snapshots |
| PR-013 | parcial | ledger + RPC de movimentação e contagem cega com aprovação | Reconciliação completa de todos os tipos de ajuste |
| PR-014 | parcial | lotes, validade e condição | FEFO e bloqueio vencido dedicado |
| PR-015 | parcial | políticas min/max/reorder | Alertas idempotentes automáticos |
| PR-016 | parcial | purchase_requests e RPC de solicitação | Aprovação, fornecedor e pedido |
| PR-017 | parcial | receipts e linhas modelados | Recebimento parcial conectado |
| PR-018 | parcial | ativos/custódias, cadastro e painel de expedição/retorno | Permissões finas e conferência por ativo |
| PR-019 | parcial | events, reserva FEFO com lock, transições, consumo/liberação e manifesto versionado no despacho | Reposição operacional e teste integrado do retorno |
| PR-020 | parcial | manifesto por versão com linhas de lote e snapshot automático na expedição | Conferência visual completa de expedição/operação/retorno |
| PR-021 | parcial | estrutura de retornáveis | Conferência e proibição de consumo |
| PR-022 | parcial | custódia individual com comandos transacionais de expedição e retorno | Conferência completa por evento |
| PR-023 | parcial | contagem cega com snapshot, conflito e aprovação transacional; diferenças de evento classificáveis e aprováveis | Teste autenticado do acerto com múltiplos lotes |
| PR-024 | parcial | reabertura exige motivo, gera auditoria e nova versão de manifesto no ciclo seguinte | Teste de reabertura com divergência persistida |
| PR-025 | parcial | schema finance privado e projeção de custo médio no recebimento | Baixas/transferências financeiras completas |
| PR-026 | parcial | finance fora do Data API e custo capturado no recebimento | Ajustes monetários por capacidade e UI financeira |
| PR-027 | parcial | activity_feed com security_invoker | Relatórios completos |
| PR-028 | implementado | Exportação CSV com neutralização de fórmulas | Filtros avançados |
| PR-029 | parcial | auditoria de bootstrap/movimentos | Correlação e observabilidade externa |
| PR-030 | parcial | RPC idempotente de alertas para ruptura, validade, evento e compra atrasada | Reconhecimento, retorno pendente e resolução por causa |
| PR-031 | parcial | status e constraints de compras | Aprovação/pedido/recebimento integrado |
| PR-032 | parcial | eventos, reservas FEFO, estados, consumo/liberação, manifesto e acerto com classificação/aprovação conectados ao painel | Reposição e teste operacional completo |
| PR-033 | parcial | RLS em todas as tabelas expostas | Escopo por capacidade |
| PR-034 | parcial | seed reproduzível com oito famílias, lotes válidos/vencidos, eventos, ativos e estrutura de manifesto/acerto | Segundo tenant, retorno e fechamento auditado com fixtures |
| PR-035 | parcial | app mobile-first | Teste visual automatizado |
| PR-036 | parcial | estados de carregamento/erro no shell | Cobertura de conflito/rede |
| PR-037 | parcial | comandos idempotentes no ledger, recebimento e consumo de reserva | Teste de timeout pós-commit autenticado |
| PR-038 | parcial | constraints de não-negatividade, locks e conflito de contagem | Testes de concorrência autenticados |
| PR-039 | parcial | grants mínimos, search_path fixo e enforcement server-side `aal2` para comandos de acesso, compras, custos, eventos, ativos e aprovação de contagem | Teste autenticado de rejeição em `aal1`, SMTP de convite e recuperação |
| PR-040 | parcial | documentação inicial | Runbook de recuperação |
| PR-041 | parcial | build verificado | E2E no deploy |
| PR-042 | parcial | modelo de auditoria e bucket privado com políticas por tenant | Backups/restauração ensaiados |
| PR-043 | parcial | Supabase e Worker Cloudflare exclusivos publicados; RLS, grants, custos autorizados e storage privado revisados | Testes E2E cross-tenant, enforcement AAL2 e autorização por papel |
| PR-044 | pendente-humano | Piloto preparado por documentação | Quatro semanas de piloto humano |

Este arquivo é deliberadamente honesto: não afirma prontidão integrada enquanto os critérios parciais e a validação humana ainda não estiverem fechados.
