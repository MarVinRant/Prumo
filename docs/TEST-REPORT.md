# Relatório de testes

Data: 2026-11-17/18 (America/Sao_Paulo)

## Executados

- `npm install --no-audit --no-fund --loglevel verbose` — concluído; lockfile gerado.
- `npm run build` — aprovado; TypeScript sem erros e Vite gerou `dist/`.
- Migração Supabase `prumo_mvp_foundation_v3` — aplicada no projeto `azuomlmqdnyvdgnhypao`.
- Migração `finance_rls_hardening` — aplicada.
- Migração `event_purchase_commands` — aplicada.
- `supabase_list_tables` — 30 tabelas públicas, todas com RLS habilitado.
- Advisor de saúde — sem findings.
- Consulta de privilégio — `anon` não possui SELECT em `public.stock_positions` nem USAGE no schema `finance`.
- Advisor de segurança — política explícita de deny no schema financeiro; há 22 avisos de funções `SECURITY DEFINER` intencionais, todos com `search_path` fixo, validação de tenant/capacidade quando aplicável e grants mínimos. O seed sintético foi adicionalmente restringido a owner/manager. Os avisos não são tratados como aprovação automática: testes de autorização por papel ainda estão pendentes.
- Deploy Cloudflare — `https://prumo-stock-hml.marcosranti.workers.dev`, versão `2b2edb33-42cc-4938-801e-bfdbad32863f`, build do commit `453930b`.
- Migração `access_event_commands` — aplicada; tabela de convites, recuperação de acesso no Auth e RPCs de reserva/liberação/fechamento adicionados.
- Build/deploy atualizado — commit `ca2e3a9`, Worker `c76b8cd1-c06d-4b7a-b31c-7a4d778b24b5`.
- Fixture sintética multi-família — migração `synthetic_fixture_seed` aplicada; bootstrap prepara oito famílias, lotes válidos/vencidos, fornecedor sintético e eventos planejado/em operação.
- Deploy mais recente — commit `31d71f6`, Worker `7f98ddf9-8d74-4980-a2b9-327480e690ba`.
- Migração `purchase_lifecycle` — aplicada; aprovação de solicitação, geração de pedido, recebimento parcial com lote e idempotência de recibo adicionados.
- Migração `expired_lot_guard` — aplicada; consumo, transferência e devolução de lotes vencidos são rejeitados no servidor.
- Migração `seed_owner_guard` — aplicada; a preparação de fixtures sintéticas não pode ser acionada por operador comum.
- Migração `event_asset_lifecycle` — aplicada; transições de evento, consumo idempotente de reserva, reabertura auditada e custódia individual de ativos estão disponíveis por RPC.
- Migração `event_reopened_transition` — aplicada; evento reaberto pode voltar à separação por transição auditada.
- Migração `purchase_cost_projection` — aplicada; recebimento com custo atualiza `finance.stock_values` com média móvel e auditoria, sem expor o schema ao Data API.
- Migração `operational_alerts` — aplicada; RPC idempotente recalcula alertas de ruptura, validade, falta em evento e compra atrasada.
- Migração `finance_projection_rpc` — aplicada; custos só são retornados por RPC para owner/finance, mantendo `finance` sem grants de tabela no Data API.
- Migração `return_pending_alerts` — aplicada; custódias abertas após o fim do evento geram alerta idempotente de retorno pendente.
- Migração `invitation_acceptance` — aplicada; token é validado por hash, e-mail autenticado, expiração, revogação e vínculo de papel antes de criar membership.
- Migração `blind_count_approval` — aplicada; contagem captura snapshot, detecta conflito e gera ajuste aprovado em transação única sem ultrapassar o reservado.
- Build local com painel de contagem cega — aprovado; TypeScript sem erros e Vite gerou `dist/`.
- Build local após custos e alertas — aprovado; TypeScript sem erros e Vite gerou `dist/`.
- `npm run smoke -- https://prumo-stock-hml.marcosranti.workers.dev` — aprovado; seis rotas profundas retornaram `200 text/html`.
- Build local com comando de fechamento/reabertura no painel de eventos — aprovado; TypeScript sem erros e Vite gerou `dist/`.
- `npm run build` após o painel de ciclo de evento e ativos — aprovado; TypeScript sem erros e Vite gerou `dist/`.
- Build/deploy mais recente — commit `4db2a9e`, Worker `0322e9c4-c053-4481-ac8f-bf535ddf0677`.
- `npm run build` após a remoção da ação sem suporte de reclassificação — aprovado; o build foi publicado no Worker `f7f67439-d61b-4e08-9451-f0a6b9ddca58`.
- Smoke HTTP — `/` e `/stock` retornaram HTTP 200 e `text/html`; a rota profunda recebeu o fallback SPA.
- Smoke HTTP ampliado — `/`, `/stock`, `/events`, `/purchases`, `/reports` e `/admin` retornaram HTTP 200 e `text/html`.
- Smoke HTTP após a correção — `/`, `/stock`, `/events`, `/purchases`, `/reports` e `/admin` retornaram HTTP 200 no Worker `57b8d858-7c59-40da-9514-a8904d1b39c3`.
- Build local com painel de reserva FEFO — aprovado; inclui listagem de reservas e liberação auditada.
- Smoke HTTP pós-fluxo de eventos — `/`, `/stock`, `/events`, `/purchases`, `/reports` e `/admin` retornaram HTTP 200 com HTML da SPA no Worker `70015e59-2a85-429e-a205-034dc97104ef`.
- Exportação CSV — botão de análises agora chama `downloadStockCsv` com neutralização de prefixos de fórmula.
- Smoke HTTP após a exportação CSV — `/`, `/stock`, `/events`, `/purchases`, `/reports` e `/admin` retornaram `200 text/html` no Worker `f7f67439-d61b-4e08-9451-f0a6b9ddca58`.
- Smoke HTTP após o ciclo de eventos/ativos — `/`, `/stock`, `/events`, `/purchases`, `/reports` e `/admin` retornaram `200 text/html` no Worker `194c16ed-88f8-4c20-8419-fa8a8f927ab1`.
- Smoke HTTP após custos e alertas — `/`, `/stock`, `/events`, `/purchases`, `/reports` e `/admin` retornaram `200 text/html` no Worker `8685b272-5724-48a1-bfa5-62c177543ff2`.
- Smoke HTTP após a correção de relacionamentos — `/`, `/stock`, `/events`, `/purchases`, `/reports` e `/admin` retornaram `200 text/html` no Worker `01e145bf-c66f-4557-8090-621a96112377`.
- `npm run smoke -- https://prumo-stock-hml.marcosranti.workers.dev` após alerta de retorno — seis rotas retornaram `200 text/html` no Worker `61db562a-a2fc-4d69-87fd-35e65feffa93`.
- Smoke após aceitação de convites — seis rotas retornaram `200 text/html` no Worker `22c6a720-32ce-4ea4-8bdc-d9a64e5a2494`.
- Smoke após fechamento auditado — seis rotas retornaram `200 text/html` no Worker `256b7b3b-251a-4833-97ea-c4f8bc3cf8d9`.
- Smoke após contagem cega — seis rotas retornaram `200 text/html` no Worker `0322e9c4-c053-4481-ac8f-bf535ddf0677`.
- Inspeção visual/DOM do deploy — tela de login PRUMO carregou com campos E-mail/Senha e ação de primeiro acesso.

## Ainda não executados

Os ciclos F01–F28, concorrência, RLS cross-tenant com dois usuários autenticados, E2E no Cloudflare, MFA, storage privado, restore de backup e medição de carga ainda dependem de contas de teste e/ou fixtures adicionais. Não são marcados como aprovados.

## Limitações atuais

O frontend já persiste login, workspace, catálogo sintético, movimentações, eventos, reserva/consumo/liberação, ciclo de estados, ativos individualizados, solicitações/aprovação/recebimento de compras, convites administrativos, alertas e CSV. Manifesto completo, acerto com diferenças, MFA, leitura financeira autorizada, arquivos privados e os testes integrados continuam pendentes e impedem declarar `PRONTO PARA TESTE INTEGRADO`.
