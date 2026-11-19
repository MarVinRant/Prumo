# Infraestrutura exclusiva — estado verificável

## Recursos confirmados (homologação)

- Supabase: `https://azuomlmqdnyvdgnhypao.supabase.co` (`Prumo Homologacao`, `sa-east-1`).
- Cloudflare Worker: `https://prumo-stock-hml.marcosranti.workers.dev` (`prumo-stock-hml`).
- Versão publicada: `d0e9403b-b699-4285-bc96-3c2cb4b72534` (commit `75e8f94`).
- Repositório: `https://github.com/MarVinRant/Prumo`.

Data da preparação: 19/11/2026.

## Alvos

| Recurso | Alvo | Estado nesta preparação |
|---|---|---|
| Git local | Pasta deste pacote `prumo-stock` | Inicializado em branch main; pacote de documentação |
| GitHub | Repositório público `MarVinRant/Prumo` indicado pelo usuário | Documentação publicada em main via Git; primeiro commit ad6407a |
| Cloudflare | Homologação `prumo-stock-hml` | Worker publicado e validado por smoke HTTP |
| Supabase | Projeto próprio do PRUMO | Ativo, saudável, região `sa-east-1`; migrações aplicadas |

O usuário criou e indicou o repositório MarVinRant/Prumo durante esta preparação. O conector confirmou sua existência e visibilidade pública, mas recusou escrita com erro 403. A publicação foi concluída pelo Git usando credencial já disponível no sistema, sem exigir outro login GitHub. A tentativa adicional de login da CLI foi encerrada por ser desnecessária.

Wrangler 4.164.0 foi autorizado pelo fluxo oficial e o Worker exclusivo foi publicado. A configuração usa Static Assets com fallback SPA; não há domínio customizado nem alteração de DNS.

Não colar tokens ou senhas no chat. Usar login OAuth da CLI ou secret store apropriado. Publicação final exige verificar URL, rotas da SPA, autenticação e comunicação com o Supabase.

## Sequência de publicação

1. Usar a credencial Git autorizada para o repositório MarVinRant/Prumo indicado pelo usuário; a publicação inicial da documentação já foi concluída.
2. Preservar a visibilidade e conferir o estado remoto antes de cada publicação, sem sobrescrever trabalho existente.
3. Publicar este pacote e, durante a execução da meta, o código do novo produto.
4. Verificar a conta Cloudflare e manter o Worker exclusivo sem alterar DNS.
5. Aplicar migrações reproduzíveis e configurar o deploy conforme documentação vigente.
6. Publicar novas versões somente após build, smoke HTTP e registro do commit/deployment.

Nenhuma URL futura deve ser inventada. Uma página provisória não equivale ao MVP pronto para teste integrado. Não alterar DNS, domínio, repositório ou banco do Bar Flow.

## Documentação oficial consultada

- [Cloudflare React + Vite](https://developers.cloudflare.com/workers/framework-guides/web-apps/react/)
- [Cloudflare Static Assets](https://developers.cloudflare.com/workers/static-assets/)
- [Cloudflare SPA](https://developers.cloudflare.com/workers/static-assets/routing/single-page-application/)
- [GitHub CLI — autenticação](https://cli.github.com/manual/gh_auth_login)
