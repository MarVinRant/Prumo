# PRUMO

Estoque pronto para a operação.

Produto independente de gestão de estoque geral para bares, restaurantes, catering e eventos. Nome de trabalho sujeito a validação de marca.

## Estado atual

Pacote inicial de documentação e objetivo de implementação. O aplicativo ainda não foi implementado neste pacote. O usuário autorizou repositório exclusivo e deploy Cloudflare para o novo projeto; o objetivo de execução é entregar o MVP integrado em homologação para testes de aceitação.

## Documentos

- [Planejamento completo](docs/PRUMO-planejamento-produto.md)
- [Backlog](docs/PRUMO-backlog.csv)
- [Prompt mestre de implementação](docs/PRUMO-prompt-mestre.md)
- [Infraestrutura e acessos](docs/INFRAESTRUTURA.md)

Escopo escolhido: 44 histórias obrigatórias M. Evoluções I e opcionais O ficam para depois. Entrevistas, marca e piloto humano não serão apresentados como realizados por automação.

## Infraestrutura pretendida

- Repositório exclusivo fornecido pelo usuário: [MarVinRant/Prumo](https://github.com/MarVinRant/Prumo), público conforme configuração escolhida pelo usuário.
- Frontend: React + Vite + TypeScript.
- Backend: projeto Supabase exclusivo.
- Homologação: recurso Cloudflare exclusivo, preferencialmente Workers com Static Assets, nome `prumo-stock-hml` sujeito à disponibilidade.

O repositório GitHub foi verificado; os recursos de homologação e Supabase ainda são alvos, sem deploy ou provisionamento confirmado. URLs reais serão registradas depois da verificação remota. Nenhum recurso de `MarVinRant/Flow` será reutilizado ou alterado.
