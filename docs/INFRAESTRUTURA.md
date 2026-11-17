# Infraestrutura exclusiva — estado verificável

Data da preparação: 17/11/2026.

## Alvos

| Recurso | Alvo | Estado nesta preparação |
|---|---|---|
| Git local | Pasta deste pacote `prumo-stock` | Inicializado em branch main; pacote de documentação |
| GitHub | Repositório público `MarVinRant/Prumo` indicado pelo usuário | Documentação publicada em main via Git; primeiro commit ad6407a |
| Cloudflare | Homologação `prumo-stock-hml` | Sem deploy confirmado; conta e autenticação necessárias |
| Supabase | Projeto próprio do PRUMO | A provisionar durante implementação, após verificar conta/plano/região |

O usuário criou e indicou o repositório MarVinRant/Prumo durante esta preparação. O conector confirmou sua existência e visibilidade pública, mas recusou escrita com erro 403. A publicação foi concluída pelo Git usando credencial já disponível no sistema, sem exigir outro login GitHub. A tentativa adicional de login da CLI foi encerrada por ser desnecessária.

A CLI oficial Cloudflare Wrangler 4.164.0 confirmou ausência de autenticação. Foi iniciado o fluxo oficial de autorização por dispositivo, com armazenamento no cofre do Windows; sua conclusão exige ação do titular da conta. Não existe deploy confirmado. Não foi encontrada integração Cloudflare entre os plugins pesquisados. Isso não exclui sessões existentes no navegador ou outras configurações não consultadas.

Não colar tokens ou senhas no chat. Usar login OAuth da CLI ou secret store apropriado. Publicação final exige verificar URL, rotas da SPA, autenticação e comunicação com o Supabase.

## Sequência de publicação

1. Usar a credencial Git autorizada para o repositório MarVinRant/Prumo indicado pelo usuário; a publicação inicial da documentação já foi concluída.
2. Preservar a visibilidade e conferir o estado remoto antes de cada publicação, sem sobrescrever trabalho existente.
3. Publicar este pacote e, durante a execução da meta, o código do novo produto.
4. Autenticar Cloudflare por fluxo oficial; verificar conta e limites antes de provisionar o recurso exclusivo.
5. Implementar o MVP e configurar o deploy reproduzível conforme documentação vigente.
6. Publicar a homologação integrada, registrar URLs/commit/deployment e validar os fluxos reais.

Nenhuma URL futura deve ser inventada. Uma página provisória não equivale ao MVP pronto para teste integrado. Não alterar DNS, domínio, repositório ou banco do Bar Flow.

## Documentação oficial consultada

- [Cloudflare React + Vite](https://developers.cloudflare.com/workers/framework-guides/web-apps/react/)
- [Cloudflare Static Assets](https://developers.cloudflare.com/workers/static-assets/)
- [Cloudflare SPA](https://developers.cloudflare.com/workers/static-assets/routing/single-page-application/)
- [GitHub CLI — autenticação](https://cli.github.com/manual/gh_auth_login)
