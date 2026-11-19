# Decisões técnicas do PRUMO

## 2026-11-17

- O repositório exclusivo é `MarVinRant/Prumo`; nenhum arquivo, banco ou deploy do Flow foi alterado.
- O Supabase exclusivo de homologação é `Prumo Homologacao` (`azuomlmqdnyvdgnhypao`), região `sa-east-1`. O banco é a fonte transacional; o frontend usa somente a chave publishable.
- A hospedagem escolhida é Cloudflare Workers com Static Assets, nome `prumo-stock-hml`, com fallback SPA apenas para rotas sem arquivo. Erros de API não são redirecionados para `index.html`.
- O ledger fica em `stock_documents`, `stock_document_lines` e `stock_entries`; saldo é derivado em `stock_positions`. Comandos críticos de estoque usam funções `security definer` pequenas, com `search_path` fixo, validação de associação e locks.
- Valores monetários ficam no schema `finance`, sem grant para o Data API. O frontend não consulta custos; a política explícita `finance_deny_all` impede vazamento por RLS.
- Ajustes de valor usam `finance.value_adjustments`: solicitação e aprovação são separadas, exigem `aal2`, bloqueiam valor negativo e quantidade zero incompatível, e não criam nem alteram quantidade física. O payload público de auditoria não contém valores monetários.
- O bootstrap de primeiro acesso cria dados sintéticos idempotentes para uma organização, dois locais, item, lote, políticas e saldo inicial. Não há senha ou usuário público privilegiado.
- Arquivos de homologação usam o bucket privado `prumo-private`, com o primeiro segmento do caminho como tenant e URLs assinadas curtas; a DDL permanece versionada mesmo tendo sido aplicada pelo executor SQL após expiração do conector de migrações.
- Comandos privilegiados passam por wrappers `SECURITY DEFINER` que exigem a claim de sessão Supabase Auth `aal2` antes de delegar ao corpo transacional. Os corpos internos mantêm `search_path` fixo e perderam `EXECUTE` para `authenticated`; o teste com conta real e o desafio MFA no login permanecem pendentes.
- O shell autenticado consulta `getAuthenticatorAssuranceLevel()` e apresenta um desafio TOTP antes de renderizar a operação quando a conta possui fator verificado; a sessão só prossegue após `challenge`/`verify` bem-sucedidos.
- O ciclo de evento usa manifesto imutável por versão no despacho. Ao entrar em acerto, cada linha gera uma diferença com quantidade esperada/consumida; classificações de retorno não criam saída física porque a reserva nunca foi saída, enquanto consumo/perda usam comandos do ledger. O fechamento exige todas as diferenças aprovadas.
- A conversão de embalagem é por SKU (`item_packages.factor`), nunca universal; o documento guarda unidade e quantidade normalizada.
- Conversões métricas não são globais: `kg → g` e `L → ml` só são aceitas quando a unidade base do SKU permite a relação; qualquer outra conversão exige embalagem configurada para o próprio SKU.
- A exportação CSV prefixa células iniciadas por `=`, `+`, `-` ou `@` para reduzir risco de fórmula maliciosa.
- PR-001/PR-002 e o piloto humano de PR-044 permanecem pendentes por serem validações fora do alcance do código.
- Alertas operacionais ganharam ciclo explícito: reconhecer grava a pessoa e não encerra a causa; resolver exige motivo, papel de owner/manager e sessão `aal2`. O refresh usa `ON CONFLICT DO NOTHING` para não reabrir silenciosamente uma ocorrência já reconhecida ou resolvida.
