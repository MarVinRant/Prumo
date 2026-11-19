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
- Advisor de segurança — política explícita de deny no schema financeiro; na verificação de 19/11 havia 42 avisos de funções `SECURITY DEFINER` intencionais, todos com `search_path` fixo, validação de tenant/capacidade quando aplicável e grants mínimos. Os comandos de acerto, alertas e seed sintético exigem as capacidades/AAL2 correspondentes. O advisor também aponta proteção contra senhas vazadas desabilitada no Auth; isso permanece pendente de configuração no projeto. Os avisos não são tratados como aprovação automática: testes de autorização por papel ainda estão pendentes.
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
- Build local com painel de enrollment/verificação TOTP — aprovado; fluxo usa `supabase.auth.mfa` e ainda requer conta autenticada com autenticador para teste de aceitação.
- Storage privado — bucket `prumo-private` confirmado como não público, com políticas SELECT/INSERT/UPDATE/DELETE por tenant em `storage.objects`; o conector de migrações expirou ao aplicar esse schema, então a mesma DDL foi executada pelo executor SQL e mantida nos arquivos de migração para reprodução.
- Migração `privileged_aal2` — aplicada no projeto `azuomlmqdnyvdgnhypao`; wrappers server-side exigem `auth.jwt()->>'aal' = 'aal2'` antes de convites, aprovação/recebimento de compras, leitura de custos, transições/fechamento/reabertura de eventos, cadastro de ativos e aprovação de contagens. Os corpos originais foram renomeados e tiveram `EXECUTE` revogado para `authenticated`.
- Migração `event_manifest_settlement` — aplicada no projeto `azuomlmqdnyvdgnhypao`; despacho cria manifesto versionado por lote, a transição para acerto cria diferenças por linha e o fechamento bloqueia enquanto houver diferença sem classificação/aprovação. Classificação de consumo/perda usa ledger idempotente; retorno libera reserva sem contar retorno como nova saída.
- Migração `event_difference_guard` — aplicada no projeto `azuomlmqdnyvdgnhypao`; classificação só ocorre no estado `settling`, impede reduzir consumo já registrado e move avaria para posição física `damaged` sem contar como perda.
- Migração `event_replenishment` — aplicada no projeto `azuomlmqdnyvdgnhypao`; reposição durante `operating`/`settling` reserva FEFO, registra origem `replenishment`, adiciona a linha ao manifesto vigente e prepara a diferença quando o acerto já começou.
- Migração `catalog_structure_commands` — aplicada no projeto `azuomlmqdnyvdgnhypao`; comandos autorizados para unidade/local, item/família/natureza, embalagem/fator, política min/reorder/max, fornecedor e vínculo comercial. O painel de Administração usa apenas essas RPCs para escrita.
- Migração `supplier_returns` — aplicada no projeto `azuomlmqdnyvdgnhypao`; devolução exige `aal2`, motivo e quantidade até o aceito líquido, baixa o lote por documento idempotente de retorno e atualiza `receipt_lines.returned_q`.
- Migração `alert_lifecycle` — aplicada no projeto `azuomlmqdnyvdgnhypao`; acknowledge/resolve de alertas é auditado, resolução exige `aal2` e o refresh não reabre ocorrências por conflito.
- Migração `alert_indexes` — aplicada no projeto `azuomlmqdnyvdgnhypao`; índices de FK da tabela de reconhecimentos adicionados.
- Migração `purchase_rejection` — aplicada no projeto `azuomlmqdnyvdgnhypao`; solicitações podem ser rejeitadas por comando transacional com motivo, AAL2 e auditoria.
- Migração `conversion_context` — aplicada no projeto `azuomlmqdnyvdgnhypao`; conversões `kg→g` e `L→ml` são condicionais à unidade base e as demais exigem fator do SKU.
- Migração `finance_value_adjustments` — aplicada no projeto `azuomlmqdnyvdgnhypao`; ajustes de valor ficam em schema privado, exigem aprovação independente/AAL2, não alteram quantidade e removem valores dos payloads públicos de auditoria.
- Migração `finance_adjustment_hardening` — aplicada no projeto `azuomlmqdnyvdgnhypao`; tabela financeira recebeu política explícita de deny e índices de FK.
- Migração `structure_lifecycle` — aplicada no projeto `azuomlmqdnyvdgnhypao`; arquivamento de unidade/local/item/fornecedor é reversível, auditado e bloqueado quando há saldo, reserva, custódia ou pedido aberto.
- Build local após custos e alertas — aprovado; TypeScript sem erros e Vite gerou `dist/`.
- `npm run smoke -- https://prumo-stock-hml.marcosranti.workers.dev` — aprovado; seis rotas profundas retornaram `200 text/html`.
- `npm run test:static` — aprovado; invariantes de segredos, RLS, finance, CSV, fallback SPA e storage privado.
- `npm run test:static` após o enforcement AAL2 — aprovado; verifica claim `aal2`, erro `mfa_required` e wrappers não executáveis diretamente por `authenticated`.
- `npm run build` após a fila de alertas — aprovado; TypeScript sem erros e bundle gerado.
- `npm run test:static` após a fila de alertas — aprovado; invariantes incluem os comandos auditáveis de acknowledge/resolve.
- `npm run test` após rejeição de compras — aprovado; build e invariantes de compras passaram.
- `npm run test:static` após o desafio MFA no login — aprovado; invariantes verificam `getAuthenticatorAssuranceLevel`, `mfa.challenge` e `MfaChallenge` antes da UI autenticada.
- `npm run test:static` após conversões contextuais — aprovado; invariantes verificam kg/L condicionais e rejeição de conversão não configurada.
- `npm run test:static` após ajustes financeiros — aprovado; invariantes verificam schema privado, segregação de aprovação, ausência de quantidade inventada e auditoria sem valores monetários.
- `npm run test` após ciclo de catálogo — aprovado; build, painel de status e invariantes de bloqueio de arquivamento passaram.
- `npm run build` após o painel de acerto de eventos — aprovado; TypeScript sem erros e bundle gerado.
- `npm run test` após a reposição durante operação — aprovado; build e invariantes de manifesto, acerto e reposição passaram.
- `npm run test` após o painel de catálogo — aprovado; build TypeScript/Vite e invariantes de segurança/catalogação passaram.
- `npm run test` após o fluxo de devolução ao fornecedor — aprovado; build e invariantes de devolução passaram.
- Deploy Cloudflare após manifesto/acerto — Worker `prumo-stock-hml`, versão `3a31a44f-fd17-43a1-9f3d-0c2074b494f2`, commit `8b4d765`.
- `npm run smoke -- https://prumo-stock-hml.marcosranti.workers.dev` após o deploy — `/`, `/stock`, `/events`, `/purchases`, `/reports` e `/admin` retornaram `200 text/html`.
- Deploy Cloudflare após reposição de evento — Worker `prumo-stock-hml`, versão `e7aca5af-0a1e-4b62-9c0a-e0eeecb89a30`, commit `1b36170`.
- Smoke HTTP após reposição — `/`, `/stock`, `/events`, `/purchases`, `/reports` e `/admin` retornaram `200 text/html`.
- Deploy Cloudflare após catálogo/estrutura — Worker `prumo-stock-hml`, versão `93250aad-75fa-4fbe-aaf7-c926812cbbdd`, commit `035a68a`.
- Smoke HTTP após catálogo/estrutura — `/`, `/stock`, `/events`, `/purchases`, `/reports` e `/admin` retornaram `200 text/html`.
- Deploy Cloudflare após devolução ao fornecedor — Worker `prumo-stock-hml`, versão `928cfde0-5ca2-4e18-bba6-f775fa0dc4f8`, commit `ece0aff`.
- Smoke HTTP após a devolução ao fornecedor — `/`, `/stock`, `/events`, `/purchases`, `/reports` e `/admin` retornaram `200 text/html`.
- Deploy Cloudflare após alertas, rejeição de compras e desafio MFA — Worker `prumo-stock-hml`, versão `d0e9403b-b699-4285-bc96-3c2cb4b72534`, commit `75e8f94`.
- Smoke HTTP após esse deploy — `/`, `/stock`, `/events`, `/purchases`, `/reports` e `/admin` retornaram `200 text/html`.
- Deploy Cloudflare após conversões contextuais — Worker `prumo-stock-hml`, versão `f9973b1e-a7a1-4ae4-aaca-fa8bfef767cb`, commit `04857e6`.
- Smoke HTTP após conversões — `/`, `/stock`, `/events`, `/purchases`, `/reports` e `/admin` retornaram `200 text/html`.
- Deploy Cloudflare após o módulo financeiro privado — Worker `prumo-stock-hml`, versão `d55efb60-a2ef-41a8-92ec-9618b9fc36df`, commit `e98cd21`.
- Smoke HTTP após o módulo financeiro — `/`, `/stock`, `/events`, `/purchases`, `/reports` e `/admin` retornaram `200 text/html`.
- Deploy Cloudflare após controles de ciclo do catálogo — Worker `prumo-stock-hml`, versão `fff87ebc-db1b-4837-81ff-e50eadf6620d`, commit `324905a`.
- Smoke HTTP após ciclo do catálogo — `/`, `/stock`, `/events`, `/purchases`, `/reports` e `/admin` retornaram `200 text/html`.
- Deploy Cloudflare após conferência de recebimento — Worker `prumo-stock-hml`, versão `14c93129-ba16-4aba-a2cc-22d0c4e3231a`, commit `d66d8d0`.
- Smoke HTTP após conferência de recebimento — `/`, `/stock`, `/events`, `/purchases`, `/reports` e `/admin` retornaram `200 text/html`.
- Deploy Cloudflare após disponibilidade de quarentena — Worker `prumo-stock-hml`, versão `dca1ee80-5dbf-4461-9bb8-d48c72edefa5`, commit `90dc80e`.
- Smoke HTTP após disponibilidade de quarentena — `/`, `/stock`, `/events`, `/purchases`, `/reports` e `/admin` retornaram `200 text/html`.
- Migração `receipt_conformance` aplicada no Supabase — `purchase_order_lines.delivered_q`, `receipt_lines.blocked_q` e RPC transacional `receive_purchase_order_split`.
- `npm test` após conferência de recebimento — aprovado; TypeScript/Vite e 24 invariantes estáticas, incluindo separação utilizável/quarentena/rejeitada e bloqueio de sobre-entrega.
- Verificação SQL de homologação — colunas `purchase_order_lines.delivered_q` e `receipt_lines.blocked_q` e função `receive_purchase_order_split(...)` presentes no projeto `azuomlmqdnyvdgnhypao`.
- Migração `quarantine_release` aplicada — RPC `release_quarantined_stock(...)` exige `aal2`, mantém o físico e audita a reclassificação.
- `npm test` após projeção de disponibilidade — aprovado; build e invariantes incluem bloqueio de quarentena/vencido e liberação gerencial.
- Migração `inventory_reconciliation` aplicada — RPC `reconcile_inventory()` presente e restrito a sessão `aal2` com papel de owner/manager/auditor; verificação SQL confirmou a função.
- Build local com comando de fechamento/reabertura no painel de eventos — aprovado; TypeScript sem erros e Vite gerou `dist/`.
- `npm run build` após o painel de ciclo de evento e ativos — aprovado; TypeScript sem erros e Vite gerou `dist/`.
- Build/deploy mais recente — commit `88f130a`, Worker `a215d474-166b-48ee-b8c1-d74cac7e01d8`.
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
- Smoke após MFA TOTP — seis rotas retornaram `200 text/html` no Worker `cdfecc20-a2a9-4303-8adc-c4a13ba29dde`.
- Smoke após storage privado — seis rotas retornaram `200 text/html` no Worker `a215d474-166b-48ee-b8c1-d74cac7e01d8`.
- Inspeção visual/DOM do deploy — tela de login PRUMO carregou com campos E-mail/Senha e ação de primeiro acesso.

## Ainda não executados

Os ciclos F01–F28, concorrência, RLS cross-tenant com dois usuários autenticados, E2E no Cloudflare, MFA, storage privado, restore de backup e medição de carga ainda dependem de contas de teste e/ou fixtures adicionais. Não são marcados como aprovados.

## Limitações atuais

O frontend já persiste login, workspace, catálogo e estrutura configuráveis, movimentações, eventos, reserva/consumo/liberação, ciclo de estados, reposição, manifesto versionado, acerto com classificação/aprovação, ativos individualizados, solicitações/aprovação/recebimento de compras, convites administrativos, alertas, contagem cega, MFA TOTP e CSV. O enforcement AAL2 agora existe no banco para comandos privilegiados, mas o teste autenticado de rejeição em `aal1` e desafio no login ainda não foram executados. Edição/inativação de catálogo, múltiplos lotes no acerto, testes autenticados de custos/storage e os testes integrados continuam pendentes e impedem declarar `PRONTO PARA TESTE INTEGRADO`.
