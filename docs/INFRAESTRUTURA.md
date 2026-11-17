# Infraestrutura exclusiva — estado verificável

Data da preparação: 17/11/2026.

## Alvos

| Recurso | Alvo | Estado nesta preparação |
|---|---|---|
| Git local | Pasta deste pacote `prumo-stock` | Inicializado em branch main; pacote de documentação |
| GitHub | Repositório público `MarVinRant/Prumo` indicado pelo usuário | Existência e permissão de push verificadas; inicialmente vazio |
| Cloudflare | Homologação `prumo-stock-hml` | Sem deploy confirmado; conta e autenticação necessárias |
| Supabase | Projeto próprio do PRUMO | A provisionar durante implementação, após verificar conta/plano/região |

O usuário criou e indicou o repositório MarVinRant/Prumo durante esta preparação. O conector confirmou identidade, existência, visibilidade pública e permissão de push. A publicação da documentação pode usar essa conexão e não depende de autenticar novamente a CLI. Não foi encontrada integração Cloudflare entre os plugins pesquisados nem credencial Cloudflare disponível nos locais de configuração verificados. Isso não exclui sessões existentes no navegador ou outras configurações não consultadas.

Não colar tokens ou senhas no chat. Usar login OAuth da CLI ou secret store apropriado. Publicação final exige verificar URL, rotas da SPA, autenticação e comunicação com o Supabase.

## Sequência de publicação

1. Usar a conexão GitHub autorizada para o repositório MarVinRant/Prumo indicado pelo usuário.
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
