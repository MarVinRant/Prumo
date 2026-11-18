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
- Advisor de segurança — política explícita de deny no schema financeiro; os dois security-definer expostos são comandos intencionais, com `search_path` fixo e grants mínimos.
- Deploy Cloudflare — `https://prumo-stock-hml.marcosranti.workers.dev`, versão `2b2edb33-42cc-4938-801e-bfdbad32863f`, build do commit `453930b`.
- Smoke HTTP — `/` e `/stock` retornaram HTTP 200 e `text/html`; a rota profunda recebeu o fallback SPA.
- Inspeção visual/DOM do deploy — tela de login PRUMO carregou com campos E-mail/Senha e ação de primeiro acesso.

## Ainda não executados

Os ciclos F01–F28, concorrência, RLS cross-tenant com dois usuários autenticados, E2E no Cloudflare, MFA, recuperação de e-mail, storage privado, restore de backup e medição de carga ainda dependem de contas de teste e/ou URL publicada. Não são marcados como aprovados.

## Limitações atuais

O frontend já persiste login, workspace, catálogo inicial, movimentações, eventos básicos, solicitações de compra e CSV. Os fluxos avançados de aprovação, reserva/expedição/retorno, fechamento auditado, convites, MFA e custos gerenciais continuam em implementação e impedem declarar `PRONTO PARA TESTE INTEGRADO`.
