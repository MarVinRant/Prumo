# Status de implementação M

Legenda: `implementado` = evidência técnica no repositório/banco; `parcial` = base persistente existe, mas há critérios ainda não cobertos; `pendente-humano` = não pode ser inventado por código.

| ID | Status | Evidência | Dependência/Pendência |
|---|---|---|---|
| PR-001 | pendente-humano | Hipóteses documentadas | Entrevistas e observações reais |
| PR-002 | pendente-humano | Decisões D03-D10 registradas como premissas | Validação comercial real |
| PR-003 | implementado | React responsivo, tokens PRUMO, foco visível | Validação do nome da marca |
| PR-004 | implementado | Vite/TS lockfile, `.env.example`, `wrangler.jsonc` | URL Cloudflare |
| PR-005 | parcial | Supabase Auth, signup/login, recuperação por e-mail e sessão persistente | MFA obrigatório para perfis privilegiados |
| PR-006 | parcial | `bootstrap_workspace` transacional/idempotente | Troca de contexto |
| PR-007 | parcial | Convites com token hash, expiração, revogação e auditoria | Entrega automática por SMTP e aceite do convite |
| PR-008 | parcial | FKs compostas, RLS e isolamento por tenant | Capacidades/escopos finos por local |
| PR-009 | parcial | units/locations, seed de dois locais | UI de cadastro/arquivamento |
| PR-010 | parcial | Oito famílias e catálogo persistente | CRUD completo de catálogo |
| PR-011 | parcial | item_packages e fator por SKU | UI e validações kg/L completas |
| PR-012 | parcial | stock_positions com precisão decimal | Conversões adicionais e snapshots |
| PR-013 | implementado | ledger + RPC `post_stock_movement` | Fluxos de contagem cegos |
| PR-014 | parcial | lotes, validade e condição | FEFO e bloqueio vencido dedicado |
| PR-015 | parcial | políticas min/max/reorder | Alertas idempotentes automáticos |
| PR-016 | parcial | purchase_requests e RPC de solicitação | Aprovação, fornecedor e pedido |
| PR-017 | parcial | receipts e linhas modelados | Recebimento parcial conectado |
| PR-018 | parcial | ativos/custódias, cadastro e painel de expedição/retorno | Permissões finas e conferência por ativo |
| PR-019 | parcial | events, reserva FEFO com lock, transições e consumo/liberação no painel | Manifesto versionado e retorno de sobras |
| PR-020 | parcial | estrutura de manifesto prevista | Expedição/operação/retorno |
| PR-021 | parcial | estrutura de retornáveis | Conferência e proibição de consumo |
| PR-022 | parcial | custódia individual com comandos transacionais de expedição e retorno | Conferência completa por evento |
| PR-023 | parcial | tabelas de fechamento previstas | Classificação/aprovação de diferenças |
| PR-024 | parcial | reabertura exige motivo e gera auditoria | Snapshot versionado e diff do fechamento |
| PR-025 | parcial | schema finance privado | Custo médio móvel transacional |
| PR-026 | parcial | separação de grants | Ajustes monetários por capacidade |
| PR-027 | parcial | activity_feed com security_invoker | Relatórios completos |
| PR-028 | implementado | Exportação CSV com neutralização de fórmulas | Filtros avançados |
| PR-029 | parcial | auditoria de bootstrap/movimentos | Correlação e observabilidade externa |
| PR-030 | parcial | alertas e índices | Geração automática de alertas |
| PR-031 | parcial | status e constraints de compras | Aprovação/pedido/recebimento integrado |
| PR-032 | parcial | eventos, reservas FEFO, estados, consumo e liberação conectados ao painel | Reposição, manifesto e acerto operacional |
| PR-033 | parcial | RLS em todas as tabelas expostas | Escopo por capacidade |
| PR-034 | parcial | seed reproduzível com oito famílias, lotes válidos/vencidos, eventos e ativos sintéticos | Segundo tenant, manifesto/retorno e fechamento auditado |
| PR-035 | parcial | app mobile-first | Teste visual automatizado |
| PR-036 | parcial | estados de carregamento/erro no shell | Cobertura de conflito/rede |
| PR-037 | parcial | comando idempotente no ledger | Teste de timeout pós-commit |
| PR-038 | parcial | constraints de não-negatividade | Testes de concorrência |
| PR-039 | parcial | grants mínimos e search_path | MFA e e-mail de convite |
| PR-040 | parcial | documentação inicial | Runbook de recuperação |
| PR-041 | parcial | build verificado | E2E no deploy |
| PR-042 | parcial | modelo de auditoria | Backups/restauração ensaiados |
| PR-043 | parcial | Supabase e Worker Cloudflare exclusivos publicados; RLS, grants e advisors revisados | Testes E2E cross-tenant, custos e arquivos privados |
| PR-044 | pendente-humano | Piloto preparado por documentação | Quatro semanas de piloto humano |

Este arquivo é deliberadamente honesto: não afirma prontidão integrada enquanto os critérios parciais e a validação humana ainda não estiverem fechados.
