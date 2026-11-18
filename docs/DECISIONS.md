# Decisões técnicas do PRUMO

## 2026-11-17

- O repositório exclusivo é `MarVinRant/Prumo`; nenhum arquivo, banco ou deploy do Flow foi alterado.
- O Supabase exclusivo de homologação é `Prumo Homologacao` (`azuomlmqdnyvdgnhypao`), região `sa-east-1`. O banco é a fonte transacional; o frontend usa somente a chave publishable.
- A hospedagem escolhida é Cloudflare Workers com Static Assets, nome `prumo-stock-hml`, com fallback SPA apenas para rotas sem arquivo. Erros de API não são redirecionados para `index.html`.
- O ledger fica em `stock_documents`, `stock_document_lines` e `stock_entries`; saldo é derivado em `stock_positions`. Comandos críticos de estoque usam funções `security definer` pequenas, com `search_path` fixo, validação de associação e locks.
- Valores monetários ficam no schema `finance`, sem grant para o Data API. O frontend não consulta custos; a política explícita `finance_deny_all` impede vazamento por RLS.
- O bootstrap de primeiro acesso cria dados sintéticos idempotentes para uma organização, dois locais, item, lote, políticas e saldo inicial. Não há senha ou usuário público privilegiado.
- A conversão de embalagem é por SKU (`item_packages.factor`), nunca universal; o documento guarda unidade e quantidade normalizada.
- A exportação CSV prefixa células iniciadas por `=`, `+`, `-` ou `@` para reduzir risco de fórmula maliciosa.
- PR-001/PR-002 e o piloto humano de PR-044 permanecem pendentes por serem validações fora do alcance do código.
