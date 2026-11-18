# PRUMO

Estoque pronto para a operação.

Produto independente de gestão de estoque geral para bares, restaurantes, catering e eventos. Nome de trabalho sujeito a validação de marca.

## Estado atual

Aplicação React/Vite/TypeScript conectada ao projeto Supabase exclusivo de homologação, com autenticação, bootstrap sintético, saldo por lote/local, ledger transacional, movimentações, eventos básicos, solicitações de compra e exportação CSV. O status honesto por história está em [IMPLEMENTATION-STATUS.md](docs/IMPLEMENTATION-STATUS.md); não afirmar prontidão integrada enquanto houver itens parciais.

## Documentos

- [Planejamento completo](docs/PRUMO-planejamento-produto.md)
- [Backlog](docs/PRUMO-backlog.csv)
- [Prompt mestre de implementação](docs/PRUMO-prompt-mestre.md)
- [Infraestrutura e acessos](docs/INFRAESTRUTURA.md)
- [Decisões técnicas](docs/DECISIONS.md)
- [Status por história](docs/IMPLEMENTATION-STATUS.md)
- [Relatório de testes](docs/TEST-REPORT.md)
- [Roteiro de homologação](docs/HOMOLOGACAO.md)

Escopo escolhido: 44 histórias obrigatórias M. Evoluções I e opcionais O ficam para depois. Entrevistas, marca e piloto humano não serão apresentados como realizados por automação.

## Infraestrutura

- Repositório exclusivo fornecido pelo usuário: [MarVinRant/Prumo](https://github.com/MarVinRant/Prumo), público conforme configuração escolhida pelo usuário.
- Frontend: React + Vite + TypeScript.
- Backend: projeto Supabase exclusivo.
- Homologação: Cloudflare Workers com Static Assets, configuração em `wrangler.jsonc`, nome `prumo-stock-hml`.

O Supabase exclusivo foi criado e verificado: `https://azuomlmqdnyvdgnhypao.supabase.co`, região `sa-east-1`. O deploy Cloudflare só é considerado concluído após a CLI autenticada, URL respondendo e integração validada. Nenhum recurso de `MarVinRant/Flow` é reutilizado ou alterado.

## Desenvolvimento local

```powershell
npm install
Copy-Item .env.example .env.local
npm run dev
```

O arquivo `.env.local` nunca deve ser commitado. A chave publishable pode ser usada no navegador somente com as políticas RLS ativas.
