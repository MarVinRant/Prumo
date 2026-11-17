# PRUMO — Estoque pronto para a operação

**Briefing de produto, especificação funcional e planejamento técnico**  
Versão 1.0 · 17 de novembro de 2026 · Idioma inicial: português do Brasil  
Status: proposta para validação, anterior à implementação.

Este documento define um produto novo para estoque de bares, restaurantes, catering e eventos. A inspiração no Bar Flow é funcional e limitada ao contexto de operação, estabelecimentos e equipes. Identidade, navegação, componentes e modelo de negócio serão próprios. Não foram criados aplicativo, banco, migrações, contas, repositórios ou deploys. Os trechos SQL adiante são especificações de projeto, sem execução.

**Decisão recomendada:** começar pelo ciclo completo de estoque e de um evento — cadastrar, receber, reservar, separar, movimentar, contar, devolver e acertar. Biblioteca de receitas, cardápio público e descoberta de drinks ficam fora do produto.

## Sumário

1. Nome e posicionamento
2. Referência e limites da análise
3. Problema, hipóteses e validação
4. Personas
5. Casos de uso por função
6. Escopo e prioridades
7. Princípios e vocabulário
8. Módulos e telas
9. Fluxos principais
10. Regras de estoque
11. Compras, fornecedores e recebimento
12. Eventos e acerto pós-evento
13. Lotes, validade e rastreabilidade
14. Unidades e conversões
15. Kits e fichas de consumo
16. Equipamentos e ativos
17. Multiunidade e permissões
18. Indicadores e relatórios
19. Design system e acessibilidade
20. Arquitetura React + Vite + Supabase
21. Modelo de dados completo
22. Schema SQL planejado
23. Autenticação, RLS e segurança
24. CSV, códigos de barras e offline
25. Demonstração e dados de teste
26. Plano de testes
27. Roadmap e critérios de lançamento
28. Backlog inicial
29. Riscos e decisões pendentes
30. Fontes e rastreabilidade dos requisitos

## 1. Nome e posicionamento

### 1.1 Proposta de marca

**Nome de trabalho: PRUMO.** Evoca organização, equilíbrio e operação sob controle. É suficientemente amplo para bebidas, alimentos, descartáveis, equipamentos e produção de eventos. A escolha é conceitual: disponibilidade de marca, domínio e perfis ainda precisa ser verificada antes do investimento comercial.

**Assinatura:** Estoque pronto para a operação.  
**Promessa:** saiba o que tem, onde está, o que falta e o que precisa voltar.  
**Categoria:** plataforma de estoque e materiais para operações de hospitalidade e eventos.  
**Posicionamento:** para equipes que precisam abastecer uma operação fixa ou temporária, PRUMO conecta estoque, compras e eventos em um histórico confiável de quantidades, custos e responsabilidades.

Alternativas conceituais para eventual impedimento do nome: **Lastro Operações** e **Doca Estoque**. Nenhuma foi validada juridicamente ou comercialmente. A recomendação é desenvolver um único território de marca após essa checagem, sem misturar as alternativas na interface.

### 1.2 Público inicial e proposta comercial

Primeiro público: pequenas e médias operações com um depósito central, um ou mais pontos de serviço e eventos recorrentes. O comprador típico é dono, gerente ou produtor; usuários diários são chefe de bar, estoquista e equipe de campo.

Hipótese comercial: assinatura por organização, com faixas por unidades e usuários operacionais ativos. O MVP piloto terá provisionamento assistido e não dependerá de checkout. Preço, limites e cobrança automática só serão definidos após entrevistas e medição de uso. Acesso de equipe temporária deve ser simples e revogável, sem obrigar um cadastro comercial por evento.

## 2. Referência e limites da análise

Foram consultados o [repositório Flow](https://github.com/MarVinRant/Flow), README, package.json, App.tsx, estilos e biblioteca de integração. Referência de leitura: branch `main`, árvore Git `fdce7d33a5e6874c2c3ffc71087769aec8c12370`, consultada em 17/11/2026. Uma árvore identifica o conteúdo observado; não é uma afirmação sobre o commit do deploy.

O código observado utiliza React, Vite, TypeScript e integração Supabase. A interface organiza biblioteca, acervo, cardápio, favoritos, plano e configurações; a integração contempla estabelecimentos, vínculos de usuários, itens privados e publicação de menus. Isso sustenta a referência funcional de organização por estabelecimento e equipe. Não demonstra um motor transacional de estoque, nem permite concluir quais políticas estão instaladas no banco remoto. [Fontes do projeto](https://github.com/MarVinRant/Flow/tree/main/src).

O [deploy informado](https://bar-flow-flow.vercel.app) não pôde ser inspecionado nesta sessão: a ferramenta de leitura não o recuperou e não havia navegador disponível. A avaliação funcional e a identificação visual partiram do código; não houve validação visual do estado publicado nem correspondência comprovada entre repositório e deploy.

| Referência funcional aproveitável | Nova definição do PRUMO |
|---|---|
| Estabelecimento e equipe | Organização, unidades, locais, eventos e acesso temporário |
| Itens privados | Cadastro operacional de todos os materiais e ativos |
| Busca | Busca por SKU, código, descrição, lote e localização |
| Visão geral | Fila de exceções e trabalho operacional do dia |
| Integração de autenticação | Auth com isolamento por organização e autorização por escopo |

O novo projeto parte de um repositório e de um projeto Supabase próprios quando a implementação for autorizada. Não se copiam CSS, componentes, imagens, estrutura de navegação, hero ou composição de cards. Do código atual não se assume herança de permissões ou maturidade de segurança.

## 3. Problema, hipóteses e validação

### 3.1 Problema central

O estoque real circula entre depósito, cozinha, bar, transporte e evento, enquanto o registro costuma ficar fragmentado em planilhas, mensagens e memória da equipe. Isso produz saldos desatualizados, compras urgentes, itens vencidos, materiais esquecidos e dificuldade para distinguir consumo, perda e equipamento ainda não devolvido.

**Resultado desejado:** cada material deve ter quantidade, localização, condição, responsável operacional e histórico suficiente para explicar seu saldo. Antes de um evento, a equipe deve conseguir confirmar abastecimento; depois dele, deve conseguir fechar o acerto sem presumir que toda diferença foi consumo.

### 3.2 Hipóteses a testar

Metas abaixo são propostas de piloto, não resultados já observados.

| ID | Hipótese | Experimento e evidência | Critério inicial |
|---|---|---|---|
| H1 | Registro rápido durante o trabalho melhora a atualização | Observar 6 operadores em tarefas com celular e acompanhar 4 semanas | 90% das movimentações de amostra registradas no mesmo turno |
| H2 | Reservar por evento reduz dupla alocação | Simular dois eventos concorrentes e acompanhar operações reais | Nenhuma reserva firme acima do saldo elegível |
| H3 | Acerto separando consumo e perdas melhora visibilidade | Comparar 6 eventos do piloto com seus históricos disponíveis | 100% dos eventos fechados com diferença classificada |
| H4 | Alertas de reposição reduzem urgências | Comparar 4 semanas de base e 4 de uso, ajustando número e porte dos eventos | Sinal de redução de 20% em pedidos marcados como emergenciais |
| H5 | Retornáveis precisam de fluxo próprio | Testar checklist de saída/retorno de 30 ativos | 100% dos ativos expedidos com responsável e resultado de retorno |
| H6 | Um cadastro amplo atende diferentes segmentos | Entrevistar bar, catering, restaurante e produtor | Principais itens de cada segmento cadastráveis sem campos de drinks |

Realizar 10–12 entrevistas, pelo menos 3 observações de operação e 5 testes de usabilidade antes do desenvolvimento amplo. Incluir uma operação fixa e uma itinerante no piloto. Se conectividade for impeditiva em todos os locais piloto, antecipar o estudo de offline e revisar o prazo do MVP antes de contratar o escopo.

Métrica principal de adoção: proporção de ciclos de evento concluídos com todas as pendências resolvidas. Guardrails: tempo de registro, divergências de estoque, falhas de autorização, latência e abandono. Não afirmar economia causada pelo produto com uma simples comparação antes/depois sem considerar volume, sazonalidade e mudanças de processo.

## 4. Personas

As personas são hipóteses de pesquisa, não pessoas reais nem segmentos comprovados.

| Persona | Contexto e responsabilidades | Dores e motivação | Dispositivo, restrições e sucesso |
|---|---|---|---|
| **Caio, bartender de equipe temporária** | Trabalha em dois eventos por semana; repõe estação, registra quebras e devolve materiais | Tem pouco tempo, mãos ocupadas e não sabe se pode retirar do estoque de outra estação | Celular pessoal, pouca luz, acesso só ao evento e turno. Sucesso: localizar e registrar retirada em poucos passos |
| **Renata, chefe de bar** | Prepara serviço de uma casa e coordena 5–10 pessoas | Descobre falta de gelo, copos ou bebidas tarde; precisa conferir abertos e sobras | Celular no salão, tablet no fechamento. Sucesso: abastecimento confirmado, perdas justificadas e fechamento confiável |
| **Bruno, produtor de eventos** | Coordena transporte, montagem, várias equipes e materiais alugados | Listas desencontradas, equipamentos sem responsável e retorno parcial | Notebook no planejamento, celular na carga. Sucesso: manifesto conferido e evento conciliado até o prazo combinado |
| **Lúcia, compradora** | Consolida demandas de 3 unidades e negocia fornecedores | Unidades diferentes, preços incomparáveis, entrega incompleta e urgências sem justificativa | Notebook, listas extensas e necessidade de custo normalizado. Sucesso: comprar quantidade correta e acompanhar saldo a receber |
| **Eduardo, gerente operacional** | Responde por custo, perdas e disponibilidade da operação | Relatórios atrasados e diferenças sem explicação entre físico e sistema | Notebook e visão diária no celular. Sucesso: priorizar exceções e conhecer o custo operacional dos eventos |
| **Sofia, administradora da organização** | Cadastra locais, convida usuários, define acessos e mantém governança | Temporários continuam com acesso, duplicidade de cadastro e mudanças sem rastreio | Notebook, várias organizações possíveis na mesma conta. Sucesso: provisionar e revogar acesso sem expor dados de outras unidades |

Características transversais: domínio variável de planilhas, interrupções frequentes, uso de quantidades fracionárias e linguagem operacional. O sistema deve permitir usuários com múltiplas funções, mantendo as permissões explícitas.

## 5. Casos de uso por função

| Função | Casos prioritários | Exceções e limites | Resultado verificável |
|---|---|---|---|
| Bartender | Consultar saldo da estação; registrar consumo; comunicar perda ou quebra; contar sobras; confirmar devolução | Saldo insuficiente, lote vencido, item não previsto, acesso expirado. Não ajusta saldo nem aprova própria perda | Movimento identificado ou solicitação pendente, com motivo e autor |
| Chefe de bar | Planejar materiais do turno; requisitar reposição; separar por lote; aprovar perdas; conferir inventário | Divergência exige recontagem; substituição precisa autorização | Estação abastecida e turno conciliado |
| Produtor | Criar evento; estimar materiais; reservar; emitir manifesto; expedir; receber retornos; fechar acerto | Dupla reserva, atraso no retorno e carga incompleta | Evento fechado ou bloqueado por pendências nominais |
| Comprador | Consolidar solicitações; selecionar fornecedor; emitir pedido; registrar prazo; acompanhar parcial | Aprovação de alçada, embalagem diferente e preço alterado. Cotação comparativa entra depois | Pedido rastreável e saldo a receber correto |
| Gerente | Configurar níveis; analisar faltas e custos; aprovar ajustes e compras; liberar fechamento | Não transforma divergência em consumo automaticamente | Exceções resolvidas com justificativa e trilha |
| Administrador | Criar organização/unidades; definir escopos; convidar e revogar equipe; consultar auditoria | Não possui autorização operacional ou financeira apenas por ser administrador técnico | Acesso correto e mudanças auditáveis |

Perfis adicionais na evolução: recebedor dedicado, auditor de consulta, responsável por manutenção e fornecedor com portal limitado. No MVP, recebimento é uma permissão delegável ao chefe ou comprador, com segregação configurada.

## 6. Escopo e prioridades

**M = obrigatório no MVP; I = importante depois; O = opcional; F = fora do escopo.** Toda decisão de fase nesta tabela prevalece sobre exemplos futuros do documento.

| Capacidade | M — MVP | I — próxima evolução | O / F |
|---|---|---|---|
| Cadastros | Todas as categorias; SKU; unidade base; embalagem; fornecedor; condição; item consumível/retornável | Duplicidade assistida, atributos por segmento | O: imagens de itens |
| Estrutura | Multi-tenant, várias unidades e locais, evento como local operacional temporário | Transferência com etapas de trânsito e recebimento | F: transferência de propriedade entre organizações |
| Estoque | Entradas, consumo, perdas, avarias, transferência imediata, bloqueio, ajuste aprovado, inventário cego | Contagem concorrente avançada e políticas por família | F: estoque negativo liberado por configuração |
| Reservas | Reserva firme de consumíveis por evento, separação e liberação; ativos ficam alocados fisicamente no MVP | Reserva de ativos por intervalo com prevenção de sobreposição | O: previsão automática de disponibilidade futura |
| Reposição | Mínimo/máximo e ponto de reposição manuais, alertas internos | Sugestões com histórico e lead time, resumo por e-mail | O: previsão estatística/IA |
| Compras | Solicitação, aprovação simples, fornecedor, pedido, recebimento parcial, devolução básica | Múltiplas cotações, comparação, alçadas, consignação | F: contas a pagar, emissão fiscal e conciliação bancária |
| Eventos | Planejamento manual, reserva, manifesto, expedição, retorno e acerto de consumíveis/ativos | Templates, comparação de eventos e checklists avançados | F: venda de ingressos e gestão de convidados |
| Perecíveis | Lote, validade por data, condição, FEFO, alerta e bloqueio de vencido | Abertura de embalagem, validade após abertura, recall assistido | O: sensores de temperatura |
| Unidades | g, ml, un, m; kg/L e embalagens por item com fator fixo | Peso variável, conversões contextuais revisadas | F: conversão massa/volume universal |
| Kits e fichas | Seleção manual de itens no evento, sem entidade kit no MVP | Kit virtual versionado e ficha de consumo operacional | F: biblioteca de drinks, curadoria e cardápio público |
| Ativos | Controle por quantidade ou patrimônio; saída, custódia, retorno, quebra e bloqueio | Manutenção, locação externa e agenda | F: depreciação contábil e gestão financeira patrimonial |
| Relatórios | Saldo, extrato, faltas, perdas, vencimentos, custo e acerto por evento; CSV de saída | ABC, cobertura, compras e comparações avançadas | O: BI externo e relatórios programados |
| Importação | Cadastro e saldo inicial por formulário; exportação CSV | Importação CSV validada; leitor USB/Bluetooth; PWA instalável | O: câmera, etiquetas e RFID |
| Offline | Mensagem clara de conexão; confirmação somente com resposta do servidor | Cache de leitura e rascunhos; depois fila de contagens/movimentos com reconciliação | F: promessa de saldo garantido em múltiplos dispositivos offline |
| Acesso | E-mail/senha, recuperação, convite, escopos de unidade/evento, MFA para perfis privilegiados | SSO e papéis personalizados | F no MVP: billing automático e marketplace |

O MVP é um piloto operacional completo, não apenas uma tela de cadastro. Mesmo no primeiro lançamento, multi-tenant, segurança de saldo, validade, eventos e retornáveis são requisitos de fundação. Cotações, kits e offline transacional são adiados para proteger a entrega do núcleo.

## 7. Princípios e vocabulário

- **Organização (tenant):** cliente isolado. Pode ter várias unidades e usuários.
- **Unidade:** operação administrativa, como uma casa ou base de produção.
- **Local:** posição física com saldo, como depósito, câmara, estação ou evento. Locais agrupadores não armazenam saldo.
- **Item/SKU:** identidade do material. Garrafas de 750 ml e 1 L de uma mesma bebida podem ser SKUs diferentes quando precisam de rastreio separado.
- **Consumível:** sai definitivamente ao ser usado. **Retornável:** deve voltar; pode ser controlado por quantidade ou patrimônio individual.
- **Lote:** origem e validade de um conjunto de unidades; não representa, sozinho, uma posição de estoque.
- **Posição:** combinação item + local + lote + condição. Um lote pode estar em mais de um local.
- **Documento:** intenção de movimentação com linhas, estado e aprovações. **Lançamento:** efeito imutável de um documento efetivado.
- **Reserva:** compromisso sobre estoque elegível; não é retirada física. **Separação:** preparação vinculada à reserva, com lotes selecionados.
- **Acerto:** classificação e aprovação do que foi consumido, perdido, devolvido, transferido ou ficou pendente.

Princípios: integridade antes de automação; quantidade física separada de disponibilidade; operações explícitas e reversíveis por compensação; rastreabilidade de origem; custo visível somente a quem precisa; acesso mínimo por função e local; catálogo centrado em materiais.

## 8. Módulos e telas

### 8.1 Organização da experiência

Desktop: cabeçalho com organização e contexto de unidade, seguido de navegação horizontal por **Operação, Estoque, Eventos, Compras, Análises, Administração**. Subnavegação fica no contexto do módulo. Mobile: barra inferior com **Hoje, Estoque, Movimentar, Eventos, Mais**; Compras e Administração ficam em Mais conforme permissões. A estrutura deriva das tarefas do novo produto.

| Módulo / telas | Conteúdo e ações principais | Estados obrigatórios |
|---|---|---|
| Acesso e início | Login, recuperação, aceite de convite; criar organização; cadastrar unidade/local; primeiro item e recebimento | Convite inválido/expirado, conta sem vínculo, e-mail não confirmado |
| Hoje | Pendências ordenadas por urgência; faltas, recebimentos, eventos e vencimentos; seletor de contexto | Sem movimento, sem permissão, dados em atualização, erro com tentativa novamente |
| Estoque / posições | Busca e filtros por item, local, condição, lote; físico, reservado e disponível | Estoque zerado, bloqueado, vencido, reservado, item inativo |
| Item / detalhe | Cadastro, embalagens, lotes, posições, histórico, fornecedores e níveis; custos em seção autorizada | SKU duplicado, unidade travada após uso, cadastro incompleto |
| Movimentar | Entrada, consumo, perda, avaria, transferência, ajuste; formulário com linhas e revisão | Rascunho, pendente, aprovado, efetivado, rejeitado; saldo mudou |
| Extrato | Linha do tempo por item/local/lote, documento e autor; vínculo de compensação | Filtro sem resultado, paginação, estorno parcial |
| Inventário | Abrir sessão, definir escopo, contagem cega, recontagem, divergências, aprovação | Em contagem, enviada, recontar, aprovada, cancelada |
| Eventos | Lista por data/estado e detalhe com Plano, Separação, Saída, Operação, Retorno, Acerto | Falta para reservar, carga parcial, divergência, atraso, bloqueio de fechamento |
| Compras | Solicitações, pedidos, detalhe, recebimentos e fornecedores | Aprovação, entrega parcial, sobre-entrega bloqueada, devolução |
| Ativos | Lista por item/patrimônio, condição, custódia, saída e retorno | Em uso, disponível, avariado, manutenção futura, extraviado |
| Alertas | Fila com gravidade, contexto, responsável e ação; reconhecer ou resolver | Novo, reconhecido, resolvido; condição recorrente |
| Análises | Relatórios com período, unidade, evento, material e exportação | Sem base para cálculo, custo oculto, informação estimada |
| Administração | Organização, unidades, locais, usuários, convites, papéis, políticas e auditoria | Último proprietário, escopo inválido, vínculo revogado |
| Evoluções | Cotações, kits/fichas, importação, sincronização e manutenção | Preview de importação, conflito offline, versão antiga |

### 8.2 Contrato de interação

Toda ação de estoque exibe item, unidade, quantidade, origem/destino, lote, condição e efeito estimado no saldo antes da confirmação. A resposta traz número do documento e saldo atualizado. Erros não apagam as linhas preenchidas. Repetir confirmação usa a mesma chave de idempotência. Mensagem de sucesso só aparece depois do commit.

Em celular, uma tarefa ocupa uma coluna; inclusão de linhas é sequencial; revisão tem resumo persistente. Em desktop, lotes e quantidades podem ser editados em tabela, com validação por linha. Operador sem acesso a custo recebe exatamente a mesma quantidade de etapas, sem campos monetários.

## 9. Fluxos principais

### 9.1 Primeiro uso

Criar conta → confirmar e-mail → criar organização transacionalmente → cadastrar unidade e local físico → convidar equipe → cadastrar item e embalagem → registrar estoque inicial com lote/validade quando aplicável → configurar reposição → concluir checklist. Fluxo reentrante: repetir não cria outra organização nem reaplica saldo inicial.

### 9.2 Receber compra

Demanda → solicitação → aprovação → pedido → entrega → conferir por linha/lote/condição → registrar parcial ou total → efetivar recebimento → atualizar saldo e quantidade pendente → abrir ocorrência se houver diferença. Mercadoria rejeitada não se torna disponível.

### 9.3 Abastecer operação fixa

Selecionar depósito → consultar saldo elegível → requisitar → separar FEFO → conferir → transferir para estação → registrar consumo ou perda no local efetivo → contar ao fim do turno → encaminhar divergências para aprovação.

### 9.4 Executar evento

Criar evento → planejar materiais → verificar falta → reservar consumíveis e alocar ativos → separar por lote → manifesto → confirmar expedição → confirmar operação no local do evento → registrar reposições, consumo e ocorrências → contar sobras e ativos → devolver/transferir → classificar diferenças → aprovar acerto → fechar.

No MVP, transferência é uma confirmação imediata da entrega física entre locais, feita por usuário autorizado nos dois lados. Antes disso a carga permanece na origem e marcada como separada. Se o deslocamento exigir saldo em trânsito e confirmação de destinatário, usar a evolução de transferência em duas etapas; não apresentar essa capacidade como entregue no piloto.

### 9.5 Inventariar

Gerente abre contagem por local/itens → sistema captura saldo de referência e bloqueia movimentos naquele escopo → operador informa contagem sem ver saldo esperado → envia → diferença acima da tolerância solicita recontagem independente → gerente aprova → documento de ajuste é efetivado → sessão libera o escopo. Expirar um bloqueio não pode aplicar ajuste automaticamente; o responsável cancela ou retoma a sessão.

### 9.6 Corrigir erro

Abrir documento efetivado → pedir compensação com motivo → validar saldo e dependências atuais → aprovar quando exigido → gerar documento inverso ou parcial → manter ambos no extrato. Se uma entrada incorreta já foi consumida, o sistema impede seu estorno físico integral e exige correção compatível com o estado atual. Não se altera o lançamento antigo.

## 10. Regras de estoque

### 10.1 Saldos e invariantes

**Físico:** soma dos lançamentos efetivados da posição. Inclui materiais presentes mas bloqueados, avariados ou vencidos. **Elegível:** físico em condição utilizável, dentro da validade e em local operacional habilitado. **Reservado:** compromisso firme ativo sobre o elegível. **Disponível:** elegível − reservado; nunca negativo.

**Projetado em uma data:** elegível + recebimentos confirmados até a data − demandas firmes ainda não atendidas até a data. É uma previsão; pedidos em aberto não aumentam o disponível físico. Alertar separadamente para material que vencerá antes da data do evento.

Na consulta, a elegibilidade e a reserva efetiva são avaliadas por posição. Se o lote venceu ou foi bloqueado, a contribuição dessa posição ao disponível é zero; suas alocações passam a ser pendências de substituição, sem consumir disponibilidade de outro lote. `reserved_q` é projeção das alocações ainda abertas e pode aguardar liberação pelo reconciliador; por isso não se calcula disponibilidade apenas subtraindo dois totais crus. Comandos sempre revalidam o lote e liberam/substituem alocações inválidas sob lock. A virada de data não depende de um job para impedir uso de vencidos.

Invariantes obrigatórios:

1. Nenhuma posição, disponibilidade ou quantidade patrimonial pode ficar negativa.
2. O saldo deriva de lançamentos imutáveis; uma tabela de saldo é projeção transacional reconstruível.
3. Transferência entre locais do mesmo tenant debita e credita a mesma quantidade base, item e lote; é atômica.
4. Reserva não altera físico. Expedição reduz a reserva atendida na mesma transação da transferência.
5. Documento rascunho ou pendente não movimenta estoque. Lançamentos só surgem na efetivação.
6. Itens, locais, lotes, documentos e relacionamentos pertencem ao mesmo tenant, verificado também por FKs compostas.
7. Estoque inicial, ajuste, perda e avaria têm motivo, autor, data efetiva, data de registro e origem rastreável.
8. Itens retornáveis não admitem baixa por consumo; perdas de ativos exigem ocorrência e aprovação.
9. Item e unidade base usados não podem ser substituídos retroativamente. Correção estrutural exige novo SKU e migração documentada.
10. Documento efetivado não aceita edição/exclusão; correção usa compensação vinculada e limita a quantidade ainda compensável.

### 10.2 Tipos de operação

| Operação | Efeito | Validações e aprovação |
|---|---|---|
| Saldo inicial | Crédito na posição e valor inicial informado | Gestor; lote/validade exigidos por política; impedir duplicação por importação/origem |
| Recebimento | Crédito aceito; valor de aquisição | Pedido e limite pendente, inspeção, unidade e lote; recebedor autorizado |
| Consumo | Débito de consumível elegível | Local, quantidade e destino operacional; evento/turno quando aplicável |
| Perda | Débito físico: descarte, desperdício ou extravio confirmado | Motivo padronizado, observação e aprovador diferente do solicitante |
| Avaria | Reclassificação utilizável → avariado no mesmo local/lote | Não reduz físico; reduz disponibilidade. Descarte posterior é perda vinculada |
| Bloqueio/quarentena | Reclassificação para condição bloqueada | Motivo, responsável e liberação autorizada; não é baixa |
| Transferência imediata | Débito origem + crédito destino | Permissão nos dois locais; saldo elegível, reserva e lote preservados |
| Devolução de evento | Transferência do evento para depósito, por condição | Conferência; avariado retorna avariado; não vira utilizável por voltar |
| Devolução a fornecedor | Débito físico vinculado a recebimento e ocorrência | Quantidade efetivamente devolvida, motivo, gestor; não simula pagamento/reembolso |
| Ajuste de inventário | Crédito ou débito da diferença aprovada | Contagem, justificativa, bloqueio do escopo e aprovação independente |
| Compensação | Lançamentos opostos ao documento de origem, parciais ou totais | Não exceder original líquido já compensado; saldo atual suficiente |

Perda e ajuste permanecem pendentes até aprovação; estoque suspeito é bloqueado imediatamente para impedir uso indevido. Em operação de uma única pessoa, a organização pode habilitar exceção de autoaprovação apenas para seu proprietário operacional, com motivo obrigatório, alerta e auditoria. O padrão para equipes é segregação entre solicitante e aprovador.

### 10.3 Concorrência, datas e custo

Efetivação bloqueia as posições e reservas envolvidas em ordem determinística, revalida o disponível e aplica documento, lançamentos, custos, saldo e auditoria em uma transação. Reservas sobre a mesma posição seguem o mesmo bloqueio; criação de posição ausente exige mecanismo de serialização da chave antes da inserção. Repetição com a mesma chave e payload retorna o resultado anterior; mesma chave com payload diferente é conflito.

No MVP, `effective_at` não pode anteceder o último fechamento do local e a ordenação de custeio segue o registro confirmado. Informar horário operacional passado preserva a informação, mas não recalcula silenciosamente custo histórico. Inventários com bloqueio não recebem movimentos retroativos. Reabertura de período é restrita e auditada.

**Custeio gerencial recomendado:** custo médio móvel por item/local, agregando seus lotes e condições físicas. Entrada calcula `(valor anterior + valor recebido)/(quantidade anterior + recebida)`. Saída captura o custo médio vigente. Transferência carrega o valor da origem e compõe a média do destino; não gera despesa de consumo. Valor e média ficam separados de quantidades para proteção de acesso. Quando quantidade zera, normalizar valor residual de arredondamento por regra explícita e lançamento técnico auditado.

No exemplo: 10 un a R$ 8 + 10 un a R$ 12 → 20 un com média R$ 10; consumo de 3 un → custo R$ 30; transferência de 5 un → R$ 50 entre locais. Devolução do evento é transferência pelo custo médio vigente na origem evento, com vínculo aos materiais retornados. Estornos usam o valor original quando viáveis e não podem criar valor de estoque negativo; correções posteriores exigem documento de ajuste de valor aprovado. Estes valores são gerenciais, sem promessa de equivalência contábil ou fiscal.

Ajuste exclusivamente de valor fica em documento financeiro próprio, sem lançamento de quantidade. Ele altera o valor e a média corrente do item/local, preserva o custo capturado de saídas antigas e exige `cost.adjust` e aprovação independente. É limitado ao valor de estoque existente; quando não há quantidade física, não se inventa estoque para corrigir uma diferença financeira. O caso precisa de resolução financeira externa ao módulo ou de documento operacional adequado.

### 10.4 Reposição e alertas

Parâmetros por item/local: mínimo, máximo, ponto de reposição, lead time em dias e fornecedor preferencial. Todos não negativos; `mínimo ≤ ponto de reposição ≤ máximo`. Se não informados, não inventar parâmetros. MVP usa valores definidos pelo gestor.

Na evolução, sugerir `ponto = demanda média diária × lead time + estoque de segurança`; usar dias de operação e excluir transferências e ajustes da demanda. Exibir janela e qualidade da amostra. Sugestão de compra: `máximo − posição de planejamento`, nunca menor que zero, arredondada à embalagem mínima; posição de planejamento considera elegível, compromissos ainda não atendidos e pedidos firmes sem duplicação. Validar validade até a necessidade.

Alertas: ruptura física/elegível; disponível abaixo do ponto; excesso acima do máximo; reserva incompleta; lote próximo do vencimento ou vencido; compra atrasada; evento sem fechamento; ativo sem retorno; contagem pendente. Janelas de validade iniciais: 30, 7 e 1 dia, configuráveis. Persistir uma ocorrência por regra/alvo/ciclo; reconhecer não resolve a causa. Reabrir só após mudança de estado ou novo ciclo; evitar uma notificação por atualização da página.

## 11. Compras, fornecedores e recebimento

### 11.1 Cadastro e demanda

Fornecedor: nome, identificação empresarial opcional, contatos de trabalho, situação, prazo usual, pedido mínimo, condições de entrega e itens/embalagens fornecidos. Dados bancários e pagamento não são necessários ao MVP. Inativar não apaga histórico. Um item pode ter vários fornecedores e códigos comerciais distintos.

Solicitação: unidade/local ou evento solicitante, necessidade até uma data, linhas, quantidade base, justificativa e marcação de emergência. Consolidação pode agrupar o mesmo SKU para compra, preservando vínculos com as demandas originais; não somar unidades incompatíveis. Comprador transforma solicitação aprovada em pedido a um fornecedor. No MVP, aprovação é única, com aprovador habilitado; alçadas por valor ficam para evolução.

Pedido preserva descrição, embalagem, fator, moeda BRL, preço, desconto, frete alocado, data prometida e destinatário. Alterar embalagem posteriormente no cadastro não muda pedido já aprovado. Frete e desconto devem ser rateados com regra declarada e fechamento de centavos; MVP pode usar rateio proporcional ao valor das linhas. Tributos não recuperáveis podem compor custo informado, sem motor tributário.

### 11.2 Estados

- Solicitação: rascunho → enviada → aprovada/rejeitada → parcialmente atendida → atendida/cancelada.
- Pedido: rascunho → aguardando aprovação → aprovado → emitido → parcialmente recebido → recebido → encerrado. Cancelamento afeta apenas a parte não recebida e exige motivo.
- Recebimento: rascunho → em conferência → aprovado para efetivação → efetivado; rejeitado/cancelado antes da efetivação.
- Devolução: solicitada → aprovada → expedida ao fornecedor; eventual crédito financeiro é somente referência externa.

Registro de “emitido” significa que a equipe registrou a emissão; não há envio automático ao fornecedor no MVP. Exportar pedido permite o envio pelo processo da empresa.

### 11.3 Conferência e parcial

Registrar por linha: quantidade entregue, aceita utilizável, aceita bloqueada e rejeitada; lote, fabricação quando disponível, validade, preço efetivo, referência do comprovante e responsável. Quantidades físicas entregues se particionam entre aceitas e rejeitadas. Somente aceitas entram no estoque; aceitas bloqueadas não ficam disponíveis.

Exemplo: pedido de 10 caixas com 12 latas = 120 un. Chegam 72 un; 60 utilizáveis, 6 aceitas em quarentena e 6 rejeitadas. Estoque físico aumenta 66, elegível aumenta 60; saldo original a receber é 54, antes de qualquer decisão de cancelamento ou reposição. A quantidade rejeitada não é contada como recebida aceita. Se o fornecedor repuser, novo recebimento atende o saldo; se houver devolução de aceitas, registrar saída vinculada e definir se reabre demanda ou encerra comercialmente. Devolução não reabre pedido implicitamente.

Receber acima do pendente é bloqueado; gestor precisa revisar o pedido ou registrar recebimento avulso aprovado. Variação de preço exige confirmação autorizada e não altera retroativamente os recebimentos anteriores. Recebimento repetido com a mesma chave não cria outra entrada. Numeração de documento externo ajuda a detectar duplicidade, mas não substitui idempotência.

### 11.4 Cotações — importante depois

Uma solicitação de cotação agrupa necessidades e prazo; propostas de vários fornecedores preservam versões e validade. Comparação normaliza custo por unidade base, frete, prazo, quantidade mínima e disponibilidade. Ganhar pelo menor preço não implica ganhar automaticamente: selecionar por linha ou fornecedor com justificativa. Aprovação gera pedido com snapshot da proposta escolhida. Preços vencidos recebem aviso e precisam de reconfirmação.

## 12. Eventos e acerto pós-evento

### 12.1 Planejamento e reserva

Evento contém nome, unidade responsável, local de realização, datas/horários, fuso, responsável, equipe, porte estimado e prazo de devolução/acerto. Informar número de participantes é opcional; nenhum dado de convidado é necessário. Criar um local físico temporário para seu estoque; outras estações podem ser sublocais na evolução.

Estados: rascunho → planejado → em separação → expedido → em operação → em acerto → fechado. Pode haver expedições parciais sem avançar para “expedido completo”. Cancelar antes da expedição libera reservas; cancelar após expedição inicia retorno/acerto, sem apagar movimentos.

Planejado é expectativa. Reserva firme de consumível escolhe origem e, no MVP, lote elegível que sobreviva à data de uso. Duas pessoas não conseguem reservar a mesma disponibilidade. Reserva insuficiente pode ser parcial e mostrar falta, mas não pode apresentar o evento como pronto. Recebimento futuro é previsão, não reserva firme. Substituição de SKU exige aprovação e preserva demanda e substituição.

Ao separar, confirmar lotes e quantidades. Expedição transfere material ao local evento e consome a reserva correspondente. A quantidade expedida não vira consumo. No MVP, retornáveis ficam fisicamente alocados ao local evento quando entregues; a agenda de reservas futuras de ativos é uma evolução.

### 12.2 Operação e retorno

Registrar reposições, compras avulsas recebidas no evento, transferências entre eventos autorizadas, consumos explícitos, perdas e bloqueios. Cada evento deve ter uma única origem de baixa para cada fato: consumo unitário ou ficha de consumo futura, com referência idempotente. Não registrar os dois para a mesma ocorrência.

No retorno, contar embalagens fechadas, conteúdo fracionado quando mensurável, descartáveis e ativos. Quantidade fracionária precisa ser informada na unidade adequada; “meia garrafa” converte pelo volume cadastrado com método de medição e indicação de estimativa. Itens abertos só voltam como utilizáveis se a política e sua validade permitirem. Retorno avariado vai para posição avariada e aguarda decisão.

### 12.3 Equação e exemplo de acerto

Para cada SKU e unidade base no evento:

`Inicial + entradas + reposições = consumo registrado + perdas confirmadas + devoluções + transferências de saída + saldo físico final + diferença não classificada`.

O saldo físico final inclui materiais avariados ainda presentes; não contá-los novamente como perda enquanto não houver baixa física. Diferença pode ser positiva (falta inexplicada) ou negativa (sobra inexplicada). Classificar por evidência: consumo adicional, perda, entrada omitida ou erro de contagem, cada um com documento adequado. Nunca converter toda diferença em consumo automaticamente.

Exemplo: 100 latas expedidas + 20 compradas no evento; 70 consumidas, 5 perdidas e 40 devolvidas. Se não ficou saldo final, há diferença não classificada de 5 latas. O fechamento fica bloqueado até recontagem e classificação. Para 20 caixas retornáveis, 18 devolvidas utilizáveis + 1 devolvida avariada + 1 desaparecida: 19 retornaram fisicamente; a desaparecida continua pendência até baixa por perda aprovada. Não existe “consumo” de caixa.

Cada linha de acerto armazena valores de referência, contagem observada, classificação, documentos gerados, responsáveis e aprovação. O custo do evento soma consumo + perdas + serviços operacionais informados futuramente, sem tratar transferência de ida/volta como despesa. Investimento em equipamento e ativo ainda em uso não integra custo de consumíveis. Sem receita cadastrada, não exibir margem, lucro ou CMV percentual de vendas.

### 12.4 Fechamento e reabertura

Condições para fechar: todas as linhas revisadas; diferenças classificadas; perdas e ajustes aprovados; retornáveis devolvidos, transferidos ou baixados formalmente; reservas liberadas; nenhum documento pendente; saldo do evento zerado. Se material continua em operação, transferir para outro local responsável antes de fechar.

Salvar snapshot do acerto e seu número de versão; impedir novos movimentos no evento fechado. Reabertura exige gerente com permissão, motivo e nova versão; o fechamento anterior continua auditável. Prazo sugerido de piloto: até 48 horas após o retorno físico, ajustável por operação. Não confundir prazo sugerido com garantia de serviço do sistema.

## 13. Lotes, validade e rastreabilidade

Todo saldo usa um identificador de lote. Para material sem controle de lote comercial, gerar lote interno por recebimento/origem; para itens rastreáveis, exigir código do fabricante/fornecedor e validade conforme política do SKU. Não agrupar tudo em um lote “genérico” que destrua a origem de compra.

FEFO: sugerir primeiro o lote com menor validade elegível; empatar por data de recebimento e ID. Sem validade aplicável, usar antiguidade de recebimento. A escolha de outro lote válido requer motivo quando política exigir. Lote vencido não admite reserva, consumo ou expedição operacional; pode ser movido para quarentena ou descarte por fluxo de exceção autorizado.

**Semântica de data:** `expires_on` é uma data local e o lote é válido até o fim desse dia no fuso da unidade, salvo política explícita mais restritiva. Não converter uma data de rótulo diretamente em meia-noite UTC. O servidor reavalia validade na confirmação e nas consultas de elegibilidade; não depender apenas de job noturno.

Rastrear recebimento → lote → posições → transferências → evento/consumo/perda/devolução. Um lote de fornecedor não deve ser único globalmente: o mesmo texto pode existir para outros produtos e organizações. Código e datas contraditórios geram conferência, sem fusão automática. Bloqueio de recall atinge todas as posições do lote, retira reservas elegíveis e gera pendências de substituição.

Evolução para embalagem aberta: registrar abertura e desdobrar a quantidade em lote filho, preservando lote de origem e validade original. Validade efetiva será a menor entre rótulo e prazo após abertura definido pelo responsável da operação. O produto armazena políticas fornecidas pela empresa e não inventa prazos sanitários. Reembalagem ou preparo produzido exige vínculos de lotes de entrada e lote de saída, com rendimento e perdas aprovados; fica depois do MVP.

## 14. Unidades e conversões

### 14.1 Modelo

Unidades base recomendadas: **un** para contáveis, **ml** para volume, **g** para massa e **m** para comprimento. Dimensão e precisão são atributos do cadastro de unidade. L e kg são apresentações convertíveis, com fatores 1.000 para ml e g. Quantidades usam decimal no banco, sem cálculos financeiros ou de estoque em ponto flutuante binário.

Embalagens são específicas por SKU: caixa 12 × lata 350 ml, garrafa 750 ml, fardo 6 un, saco 5 kg. A organização escolhe se o item é controlado por unidade de recipiente ou conteúdo. Se uma lata é controlada em un, seu volume é atributo e não permite saída de 0,2 un; se o conteúdo é controlado em ml, a embalagem converte para ml e aceita retirada fracionada.

| Exemplo | Unidade de estoque | Conversão |
|---|---|---|
| Bebida de garrafa para consumo fracionado | ml | 2 caixas × 6 garrafas × 750 ml = 9.000 ml |
| Lata distribuída fechada | un | 3 caixas × 12 = 36 un; 350 ml é atributo descritivo |
| Limão comprado a peso | g | 2,5 kg = 2.500 g; não presumir quantidade de frutas |
| Gelo | g | 4 sacos × 5.000 g = 20.000 g |
| Copos descartáveis | un | 2 pacotes × 100 = 200 un |
| Cabo de apoio | m | 2 rolos × 25 m = 50 m; ativo individual pode ter regra distinta |

Fator de embalagem é sempre positivo e versionado; quantidade convertida e fator usados ficam gravados na linha do documento. Desativar embalagem não altera fatos antigos. Código de barras aponta para item + embalagem, não para um fator universal de “caixa”.

### 14.2 Restrições

Não converter massa para volume sem densidade validada para o item e contexto; não converter kg de limão para un com uma regra geral. Peso variável entra na evolução: receber o peso real, preservar quantidade comercial e sua medição. `un` exige inteiro; ml/g/m respeitam precisão configurada. Arredondar apenas nos limites especificados e mostrar quando ocorreu. O estoque não pode ganhar quantidade por arredondamento repetido de embalagem.

MVP: BRL e interface pt-BR, aceitando entrada decimal com vírgula, mas serializando valores normalizados. Usuário sempre vê unidade junto à quantidade. Pedido em caixa e saldo em ml devem exibir ambos na conferência. Após a primeira movimentação, alteração de unidade base é bloqueada.

## 15. Kits e fichas de consumo

**Importante depois do MVP.** Kit virtual agrupa materiais para uma tarefa, por exemplo “Estação de atendimento para 100 pessoas”: copos, guardanapos, gelo, água, utensílios e caixas retornáveis. O kit não possui saldo próprio; expandi-lo gera demanda nos componentes. Ativos do kit geram alocação/retorno, sem baixa de consumo.

Ficha de consumo descreve consumo operacional por execução, por pessoa ou por serviço: montagem de estação, coffee break, limpeza, atendimento de uma área. Tem versão, unidade de execução, rendimento/coeficiente previsto, componentes e tolerância. Planejar 3 execuções multiplica a demanda; somente confirmar execução e quantidade real gera movimentação. Snapshot da versão impede que editar a ficha altere eventos antigos.

No primeiro estágio, kits não podem conter kits; isso evita ciclos e explosões de dependência. Substituições são explícitas por item e não alteram a ficha original. Retornável jamais vira consumo ao expandir ficha. Um kit físico pré-montado com SKU próprio exigiria ordem de montagem/desmontagem e transferência de valor, uma evolução opcional distinta do kit virtual.

O módulo não possui galeria pública, categorias de coquetel, curadoria, favoritos de receitas, apresentação de bebidas ou publicação de menu. Seus campos são materiais, quantidades, tarefas e evidências de execução. Desse modo a ficha auxilia o consumo sem reposicionar o produto como catálogo de drinks.

## 16. Equipamentos e ativos não consumíveis

Dois métodos de controle, definidos no SKU:

- **Por quantidade:** bandejas, caixas, talheres e copos reutilizáveis. Cada local mantém quantidade por condição e lote interno; saída ao evento e retorno são transferências. Quebra exige reclassificação e baixa aprovada quando descartada.
- **Individualizado:** freezer, chopeira, máquina, rádio ou equipamento com patrimônio/serial. Cada ativo pertence a um SKU, recebe código único no tenant, localização, condição e custódia. Quantidade de ativos disponíveis deve reconciliar com as posições do SKU; um ativo não pode estar em dois locais.

O documento de saída individual lista ativos, responsável, evento e prazo; a transferência física atualiza localização e registro de custódia na mesma transação. Retorno confirma identidade e condição. Extravio não desaparece da lista: gera pendência e baixa aprovada. Desabilitar um ativo avariado o retira da disponibilidade.

Itens próprios e de terceiros são identificados; locações recebidas têm responsável e data de devolução. O MVP permite registrar propriedade e movimentação, mas não inclui agenda comercial de locação ou cálculo de multas. Evolução: manutenção preventiva/corretiva, ordens de serviço, inspeções, fotos, leitura de etiqueta e reserva por intervalo com restrição de sobreposição.

Para ativos individualizados, lançamento por quantidade sem a lista de patrimônios é inválido. Para um SKU controlado por quantidade, não inventar patrimônio por peça. Conversão entre métodos após uso exige projeto de migração e inventário, sem alterar o passado.

## 17. Multiunidade, depósitos, locais e permissões

### 17.1 Hierarquia

Organização → unidades → locais físicos e agrupadores. Local pode ter pai dentro da mesma unidade, sem ciclos. Depósito e evento são tipos de local, não organizações independentes. Todo saldo existe apenas em local físico folha; mover para agrupador é proibido. Uma unidade não pode ser arquivada enquanto tiver saldo ou pendência.

Um usuário pode participar de várias organizações, com papéis diferentes. Selecionar contexto muda o que a interface consulta, mas **não concede acesso**. O servidor valida vínculo ativo a cada operação. Transferência entre unidades do mesmo tenant exige permissão nos dois locais; pode ser feita por gestor que possua os dois escopos. Transferência entre tenants está fora do escopo: não compartilhar saldos, cadastros ou fornecedores implicitamente.

### 17.2 Matriz inicial

✓ = permitido no escopo concedido; S = solicitar; P = permissão adicional explícita; — = não permitido por padrão.

| Capacidade | Bartender | Chefe de bar | Produtor | Comprador | Gerente | Admin de acesso |
|---|---:|---:|---:|---:|---:|---:|
| Consultar quantidades | ✓ | ✓ | ✓ | ✓ | ✓ | P |
| Consultar custos/preços | — | P | P | ✓ | ✓ | P |
| Consumo de consumível | ✓ | ✓ | P | — | ✓ | P |
| Solicitar perda/avaria | S | S | S | — | S | P |
| Aprovar perda/ajuste | — | P | P | — | ✓ | P |
| Contar inventário | ✓ | ✓ | ✓ | P | ✓ | P |
| Transferir entre seus locais | — | ✓ | ✓ | P | ✓ | P |
| Planejar/reservar evento | — | P | ✓ | — | ✓ | P |
| Criar solicitação de compra | S | ✓ | ✓ | ✓ | ✓ | P |
| Emitir pedido de compra | — | — | P | ✓ | ✓ | P |
| Receber e conferir | — | P | P | P | ✓ | P |
| Aprovar compra | — | P | P | P | ✓ | P |
| Alterar cadastro e níveis | — | P | P | P | ✓ | P |
| Fechar/reabrir evento | — | P | P | — | ✓ | P |
| Gerir convites e escopos | — | — | — | — | P | ✓ |
| Ler auditoria | — | — | — | — | P | ✓ |

Os seis perfis são templates de capacidades; não são seis níveis de hierarquia. Um usuário pode acumular papéis. Administrador de acesso não se torna gerente automaticamente. Proprietário da organização controla titularidade e recuperação administrativa; o papel operacional é atribuído separadamente. Impedir remoção do último proprietário.

### 17.3 Escopos e temporários

Vínculo ativo da organização é pré-condição para qualquer acesso. Concessões podem abranger organização, unidade, local ou evento. A concessão mais ampla cobre descendentes válidos; concessão de evento cobre apenas seus locais e sua janela de trabalho. Cada concessão contém início/fim, papel e criador. Fora da janela, o acesso deixa de valer mesmo que o JWT ainda exista.

No MVP, soma de permissões positivas, sem regras de negação personalizadas. Regras globais de segurança continuam superiores: acesso de custos explícito, separação de aprovador e autor, item vencido e saldo não negativo. Alterar ou revogar vínculo deve produzir efeito na próxima consulta/transação, consultando os vínculos no banco em vez de confiar apenas em claims antigos.

## 18. Relatórios, indicadores e dashboard operacional

### 18.1 Painel Hoje

A página inicial é uma fila de decisões: **Resolver agora**, **Preparar próximas operações** e **Conferir encerramentos**. Linhas de alerta trazem prioridade, item/evento, local, quantidade, prazo, responsável e ação. Uma faixa compacta resume disponível crítico, eventos sem abastecimento e retornos atrasados; não há banner editorial ou hero promocional.

MVP: saldos por item/local/lote/condição; extrato rastreável; itens abaixo do ponto; validade; perdas por motivo; divergências de inventário; compras pendentes; materiais expedidos/devolvidos por evento; ativos sem retorno; custo gerencial do evento.

### 18.2 Definições de métricas

| Indicador | Definição, janela e fonte | Observação / fase |
|---|---|---|
| Disponível agora | Elegível menos reservas firmes ativas, por item/local | M; quantidade e unidade, sem soma de dimensões diferentes |
| SKUs em ruptura | SKUs ativos com demanda operacional e elegível zero, no escopo | M; diferenciar falta de cadastro de saldo zerado |
| Necessidades não atendidas | Demanda firme − expedida − reserva firme, limitada a zero | M; unidade base por SKU; não agregar ml com un |
| Perdas em valor | Soma das baixas por perda ao custo capturado no período | M; avaria ainda física não entra como perda realizada |
| Taxa de perda | Valor perdido / (valor consumido + valor perdido), no período | M; denominador zero = não aplicável; não inclui transferências |
| Acurácia por posição | Posições contadas dentro da tolerância / posições efetivamente contadas | M; mostrar tamanho da amostra; não inferir todo o depósito |
| Diferença de inventário | Contado − saldo de referência no corte, por posição; valor na aprovação | M; divulgar tolerância em unidade e valor separadamente |
| Custo do evento | Consumos + perdas efetivadas vinculadas ao evento, líquidos de compensações | M; compras que continuam em estoque não são consumo |
| Prontidão do evento | Linhas obrigatórias totalmente reservadas/separadas / linhas obrigatórias | M; também listar faltas críticas, sem esconder em percentual |
| Retorno de ativos | Quantidade devolvida / quantidade com retorno devido, por SKU ou patrimônio | M; separar devolvido avariado e baixado como perda |
| Prazo de fechamento | Horas entre fim do evento e fechamento aprovado | M; evento aberto conta como pendente, sem média enganosa |
| Compras emergenciais | Pedidos com emergência justificada / pedidos emitidos no período | M; depende da disciplina de marcação |
| Cobertura | Elegível / consumo médio diário da janela, por SKU/local | I; sem histórico suficiente = não calculável |
| Giro | Custo consumido do período / estoque médio em valor no período | I; exige snapshots e política de custo estável |
| Curva ABC | Ordenação por valor de consumo, acumulado; faixas configuráveis | I; explicitar período, sem confundir com saldo atual |
| Entrega completa no prazo | Pedidos devidos totalmente aceitos até a data / pedidos devidos | I; registrar alterações de prazo sem apagar original |

Todo relatório exibe filtros, fuso, data de atualização, regra de cálculo e inclusão/exclusão de compensações. Cancelados e rascunhos não alteram indicadores realizados. Exportação respeita exatamente o mesmo escopo de acesso e ocultação de custos. Totais consolidados em dinheiro são permitidos; total de “quantidades de todos os itens” é proibido quando mistura unidades incompatíveis.

## 19. Design system próprio

### 19.1 Direção de marca e composição

Território visual: pranchetas de conferência, etiquetas de lote, marcações de carga, instrumentos e sinalização operacional. Personalidade: firme, direta e acolhedora. Superfícies claras e quentes com texto grafite, acento de argila e cor funcional de pinho; composição por faixas, tabelas e listas de tarefas. Cantos discretos, linhas marcadas, números alinhados e muito espaço para informação útil.

Símbolo proposto: duas marcas verticais alinhadas por uma base, sugerindo medição e organização. Desenvolver logo original na fase de identidade. Iconografia linear de caixa, rota, etiqueta, relógio, proteção e ferramenta; evitar taças como símbolo central de todas as categorias. Foto de bebidas não será padrão de item.

### 19.2 Paleta e tokens iniciais

| Token | Cor | Aplicação |
|---|---|---|
| `canvas` | `#F5F1E8` | Fundo principal papel quente |
| `surface` | `#FFFFFF` | Área de leitura e formulários |
| `ink` | `#262923` | Texto principal e números |
| `muted` | `#5C6258` | Texto secundário legível |
| `line-subtle` | `#D8D4C9` | Divisores decorativos, nunca única borda de campo |
| `line-control` | `#7B8075` | Bordas de campos e controles |
| `action` | `#983D25` | Ação principal argila; texto branco |
| `action-hover` | `#7D301D` | Hover/pressed da ação |
| `operational` | `#315246` | Seleção e informação operacional pinho |
| `success` | `#28603B` | Conclusão, com ícone e rótulo |
| `warning-ink` | `#755000` | Aviso sobre `#FFF0C2` |
| `danger` | `#A52B32` | Erro e perda, com mensagem textual |
| `focus` | `#5E3D85` | Contorno de foco de 3 px com afastamento |

Tokens são proposta inicial, sujeitos à validação de contraste em cada combinação e estado. Não usar `line-subtle` como única indicação de foco, erro ou limite de input. Estados de alerta usam rótulo, ícone e cor, para continuar compreensíveis sem percepção de cor.

Conferência matemática das combinações propostas: texto/canvas 13,08:1; secundário/canvas 5,57:1; branco/ação 6,93:1; branco/pinho 8,66:1; aviso 6,37:1; erro/branco 7,02:1; borda de controle/canvas 3,59:1; foco/canvas 7,51:1. Essas combinações atendem aos limites indicados para seus usos, mas estados, overlays e telas finais ainda exigirão verificação visual e de acessibilidade após implementação.

### 19.3 Tipografia, espaçamento e densidade

**IBM Plex Sans** para interface; **IBM Plex Mono** para SKU, lote, documento e identificadores. Hospedar arquivos de fonte no produto após verificar sua licença de distribuição. Fallback: system-ui e ui-monospace. Títulos 28/24/20 px, corpo 16 px, tabela desktop 14–16 px, metadados 13–14 px. Peso 400/500/600; números com alinhamento tabular. Não usar serifas decorativas ou títulos em itálico editorial.

Escala de espaço: 4, 8, 12, 16, 24, 32 e 48 px. Raios: 4 e 8 px; bordas 1 px; sombras apenas para superfícies flutuantes. Altura de interação recomendada 48 px em campo e mobile. Linhas de tabela 48 px padrão; densidade compacta desktop é preferência opcional e não reduz controles abaixo do critério de acessibilidade escolhido.

### 19.4 Componentes de produto

Inventário obrigatório: botão primário/secundário/destrutivo; campo com unidade incorporada; seletor de embalagem mostrando conversão; busca por SKU/código; combobox acessível; seletor de local com caminho; tabela com seleção e paginação; linha de posição; rótulo de condição; lista de alertas; quantidade com físico/reservado/disponível; editor de documento com revisão; seletor FEFO; etapas de evento; checklist de patrimônio; comparação contado/esperado; painel de aprovação; extrato de auditoria; estado vazio orientado à primeira ação; mensagem de erro com recuperação; confirmação de commit e aviso de conectividade.

Componentes futuros: comparação de cotações, kit expandido, preview de importação, bandeja de sincronização e resolução de conflito. Todo componente especifica normal, hover, foco, pressionado, carregando, desabilitado, vazio e erro. Botões desabilitados têm explicação próxima; toast não é único local de erro ou confirmação importante.

### 19.5 Responsividade e mobile-first

Desenhar primeiro em largura 360–430 px; validar reflow em 320 px e zoom. Uma coluna, ações próximas ao polegar, barra inferior respeitando safe area e teclado. Tablet a partir de 768 px pode usar duas áreas; desktop a partir de 1.024 px ganha tabela e painel de detalhes. Breakpoints são critérios de conteúdo, não promessa sobre modelo de aparelho.

Tabela no celular vira lista de linhas sem perder item, local, quantidade, unidade e status; detalhes ficam em expansão acessível. Comparações largas podem ter região rolável rotulada, sem fazer a página inteira rolar horizontalmente. Ações fixas não encobrem conteúdo, teclado ou foco. Formulários longos salvam rascunho online e preservam erros; não usar drag-and-drop como única forma de operar.

### 19.6 Acessibilidade e linguagem

Meta de entrega: WCAG 2.2 nível AA, com testes automatizados e manuais; não declarar conformidade apenas por passar em um scanner. Contraste mínimo 4,5:1 para texto comum e 3:1 para texto grande e elementos gráficos/controles relevantes; navegação por teclado, foco visível e não encoberto; rótulos associados, instrução e erro por campo; anúncio de atualização e retorno de foco em diálogos. Adotar alvos de toque de 48 px como regra interna, acima do mínimo geral de 24 px previsto no critério AA com suas exceções. [Referência WCAG 2.2](https://www.w3.org/WAI/WCAG22/quickref/).

Testar NVDA no Windows e VoiceOver em iOS, zoom a 200% e reflow equivalente a 400%, redução de movimento e orientação. Conteúdo nunca depende só de cor, posição ou ícone. Autenticação permite colar senha e usar gerenciadores. Entrada numérica traz unidade e exemplos; teclado decimal quando apropriado, sem impedir leitor de tela.

Tom: “Faltam 12 copos para separar este evento”; “Recebimento confirmado: 24 unidades”; “Saldo mudou. Restam 8 unidades; revise a quantidade”. Preferir verbos concretos, contexto e próximo passo. Evitar “otimize sua jornada”, vocabulário de inspiração de drinks e mensagens que culpem o operador. Quantidades estimadas são explicitamente rotuladas.

## 20. Arquitetura recomendada: React + Vite + Supabase

### 20.1 Visão de componentes

Fluxo de leitura: **React → supabase-js/Data API → views/tabelas autorizadas por RLS**. Fluxo de comando crítico: **React → Edge Function autenticada → RPC transacional → validações, lançamentos, projeções e auditoria**. Autenticação: Supabase Auth. Comprovantes e evidências: Storage privado. Jobs: avaliações de alerta e tarefas agendadas no servidor. O commit do banco é a fonte de confirmação.

React + Vite atende uma aplicação interna predominantemente autenticada, sem necessidade inicial de SEO ou renderização de páginas públicas. A escolha exige explicitar roteamento, carregamento de dados, recuperação de erros e divisão de bundles, em vez de presumir que o build tool cobre isso. O React documenta a criação com ferramentas como Vite e a necessidade dessas decisões em aplicações montadas dessa forma. [React](https://react.dev/learn/creating-a-react-app), [Vite](https://vite.dev/guide/).

| Camada | Recomendação | Responsabilidade |
|---|---|---|
| Interface | React + TypeScript + Vite | Rotas, formulários, tabelas, acessibilidade e contexto |
| Navegação | React Router, versão estável validada no início | Rotas por módulo, deep links e proteção visual |
| Dados remotos | TanStack Query, após validação da versão | Cache por tenant/escopo, invalidação, paginação e estados |
| Validação de formulários | React Hook Form + Zod, se aprovados na seleção técnica | Feedback local; regras repetidas no servidor |
| UI | Componentes próprios com primitives acessíveis avaliados | Design PRUMO, sem copiar tema do Bar Flow |
| Banco | PostgreSQL gerenciado no Supabase | Integridade, RLS, transações, índices e custeio |
| Auth | Supabase Auth | E-mail/senha, convite, recuperação, sessões e MFA |
| Comandos | Edge Functions e funções SQL restritas | Autorizar capacidades, executar uma transação e integrar serviços |
| Storage | Buckets privados | Comprovantes e evidências com acesso temporário |
| Alertas | Job agendado + tabela de ocorrências | Geração idempotente, reconhecimento e resolução |
| Atualização de tela | Invalidação após commit; Realtime opcional | Realtime avisa mudança; nunca determina saldo |
| Observabilidade | Logs correlacionados e métricas sem payload sensível | Falhas, latência, locks, fila e auditoria |

Bibliotecas adicionais são recomendações técnicas para a futura seleção, não dependências já instaladas nem versões garantidas. Fixar versões e lockfile, validar suporte do runtime e consultar documentação vigente antes da implementação. O changelog Supabase foi consultado; o planejamento considera exposição explícita da API e não depende de comandos de CLI presumidos. [Changelog Supabase](https://supabase.com/changelog).

### 20.2 Organização futura do código

Separar módulos de domínio: identidade/acesso, catálogo, estoque, inventário, eventos, compras, ativos, análises e administração. Cada módulo contém telas, validação de entrada, consultas e contratos. Componentes de design e utilitários ficam compartilhados; regras de estoque e autorização definitivas ficam no servidor.

O cliente guarda IDs de contexto e rascunhos, mas não envia um “saldo final confiável”. Toda consulta/cache inclui tenant e escopo; troca de organização limpa dados, assinaturas e rascunhos incompatíveis. Tabelas grandes usam paginação no servidor e filtros indexados; exportações extensas viram jobs na evolução.

### 20.3 Contratos de comando

Comandos previstos: criar organização; aceitar convite; salvar cadastro; criar reserva; liberar reserva; efetivar recebimento; movimentar estoque; aprovar/efetivar perda; transferir; contar/aprovar inventário; atribuir/devolver ativo; fechar/reabrir evento; compensar documento. Cada comando recebe versão de contrato, chave idempotente e payload validado.

Resposta comum: request_id, document_id quando aplicável, estado final, saldos afetados, pendências e erros por linha. Códigos de domínio: saldo insuficiente, lote indisponível, reserva conflitante, contagem bloqueada, escopo negado, versão desatualizada, aprovação necessária e repetição conflitante. A API não devolve erro SQL bruto ou existência de objetos de outro tenant.

Uma chamada SQL executa toda a mutação. Várias chamadas de atualização pelo navegador não compõem transação. A Edge Function usa o JWT do usuário no cliente de banco; não transforma qualquer usuário autenticado em `service_role`. Integrações e jobs privilegiados usam identidades de serviço dedicadas, contratos restritos e escopo validado.

### 20.4 Ambientes, implantação e operação

Planejar ambientes separados de desenvolvimento, homologação e produção, com dados e segredos distintos. Frontend estático pode ser hospedado em qualquer serviço compatível com SPA e HTTPS; Vercel é opção, não dependência funcional. Configurar fallback de rota para index, domínio/callback de Auth por ambiente, cabeçalhos e observabilidade.

Pipeline futuro: revisão → tipos/lint → testes de domínio e RLS → build → banco de homologação → migração revisada → smoke E2E → publicação controlada. Migrações serão criadas somente na implementação, com procedimento compatível com a CLI disponível e teste de rollback/roll-forward. Mudanças destrutivas usarão expansão/contração e backup verificado.

Definir metas de recuperação: piloto RPO até 24 h e RTO até 8 h, condicionados ao plano/rotina de backup e a um ensaio real de restauração. Reduzir metas antes da expansão comercial. Banco e objetos de Storage exigem plano de recuperação conjunto; não presumir que backup do banco inclui os arquivos. Capacidade, quotas, custos e região serão dimensionados na contratação, sem estimativa monetária não pesquisada.

## 21. Modelo de dados completo

### 21.1 Convenções e relacionamentos

O dicionário define o modelo alvo; a coluna de fase determina o que será criado no MVP. Tabelas futuras não devem ser antecipadas sem necessidade, mas suas relações orientam a extensibilidade.

Convenções: `id uuid` PK; tabelas do cliente têm `tenant_id uuid NOT NULL`, `created_at timestamptz` e `created_by uuid`; cadastros e rascunhos têm `updated_at`, `updated_by` e `version bigint`. Toda entidade referenciável do tenant tem `UNIQUE(tenant_id,id)`; relações entre tenants usam FK composta. Quantidades: `numeric(20,6)`; fatores: `numeric(24,12)`; valores: `numeric(20,6)` e exibição em duas casas; códigos e estados: text com CHECK ou domínio controlado. Datas de rótulo são `date`; instantes são `timestamptz`; fusos são identificadores IANA. `q` abaixo significa quantidade em unidade base.

Tabelas globais de referência são exceções explícitas a tenant_id: unidades, capacidades e templates de papel. `auth.users` é gerenciada pelo Supabase; não duplicar senhas. “M/I/O” mantém o significado da seção 6.

Relações centrais: organização 1:N unidades/usuários; unidade 1:N locais/eventos; item 1:N embalagens/lotes; posição N:1 item/local/lote; documento 1:N linhas 1:N lançamentos; posição 1:N lançamentos/alocações; evento 1:N plano/reservas/acertos; pedido 1:N linhas/recebimentos; ativo N:1 item e 1:1 posição corrente por identidade individual.

### 21.2 Identidade, estrutura e cadastro

| Entidade / fase | Campos específicos e relações | Restrições essenciais |
|---|---|---|
| `profiles` M | user_id FK auth.users PK, display_name, locale, timezone | Sem tenant; usuário edita apenas perfil próprio; não guarda papéis |
| `organizations` M | id, name, slug, timezone, currency, status, created_at | Slug único; currency=BRL no MVP; titularidade em memberships |
| `memberships` M | user_id FK, tenant_id FK organizations, status, is_owner | Único tenant/user; ao menos um proprietário ativo; sem autoelevação |
| `access_role_templates` M | code PK, label, description | Referência global privada, seis templates + proprietário administrativo |
| `capabilities` M | code PK, description | Referência global privada: stock.read, cost.read, stock.consume etc. |
| `role_capabilities` M | role_code FK, capability_code FK | PK composta; seed revisado, não editável pelo cliente |
| `scope_grants` M | membership_id FK, role_code FK, scope_kind, unit_id?, location_id?, event_id?, starts_at, ends_at, revoked_at | Um alvo conforme kind; organization sem alvo; fim > início; FK tenant em todos |
| `invitations` M | email_normalized, token_hash, expires_at, status, invited_by, accepted_by? | Token único, uso único; aceite confere e-mail confirmado; nunca guardar token puro |
| `invitation_grants` M | invitation_id FK, role_code, scope_kind, unit_id?/location_id?/event_id?, starts_at, ends_at | Escopo validado ao criar e ao aceitar |
| `business_units` M | name, code, timezone, address_text?, status | Código único tenant; sem dados de hóspedes/convidados |
| `locations` M | unit_id FK, parent_id FK locations?, code, name, type, is_stockable, status | Código único tenant; pai mesma unidade, sem ciclo; folhas físicas apenas |
| `uoms` M | code PK, dimension, factor_to_dimension_base, decimal_places | Referência global somente leitura; dimensão count/mass/volume/length |
| `categories` M | name, code, parent_id?, status | Hierarquia sem ciclo; código único tenant |
| `items` M | sku, name, category_id FK, base_uom FK, quantity_step, tracking_mode, asset_mode, lot_policy, expiry_required, status | SKU único tenant; consumable/returnable; asset_mode none/quantity/serial compatível |
| `item_packages` M | item_id FK, label, package_code, quantity_in_base, version_no, active | Fator >0, código único por item; versão usada é imutável |
| `item_barcodes` I | item_id FK, package_id FK, barcode_value text, symbology, active | Código como texto; unicidade tenant/código ativo; embalagem do mesmo item |
| `suppliers` M | name, business_reference?, contact_name?, email?, phone?, lead_days?, status | Dados empresariais mínimos; acesso restrito a compras/gestão |
| `supplier_items` M | supplier_id FK, item_id FK, package_id FK, supplier_sku?, min_order_q, lead_days | Relação N:N; preço fica em finance.supplier_prices |
| `item_location_policies` M | item_id FK, location_id FK, min_q, max_q, reorder_q, lead_days?, preferred_supplier_id? | Único tenant/item/local; mínimo ≤ ponto ≤ máximo |
| `operation_policies` M | tenant_id, approval rules, stock periods, count tolerances, alert windows | Configuração tipada; versão e auditoria; nunca política de estoque negativo |

### 21.3 Núcleo de estoque e eventos

| Entidade / fase | Campos específicos e relações | Restrições essenciais |
|---|---|---|
| `lots` M | item_id FK, internal_code, supplier_lot_code?, manufactured_on?, expires_on?, receipt_line_id?, parent_lot_id?, blocked_at?, block_reason? | Código interno único tenant; validade coerente; item do pai compatível |
| `stock_positions` M | item_id FK, location_id FK, lot_id FK, condition, on_hand_q, reserved_q, version | Único tenant/item/local/lote/condição; q≥0; reservado≤físico; disponibilidade também verifica validade |
| `stock_documents` M | number, type, status, event_id?, reason_code?, effective_at, posted_at?, requested_by, approved_by?, reversal_of_id?, idempotency_key | Número e chave únicos tenant; efetivado imutável; referência de compensação no mesmo tenant |
| `stock_document_lines` M | document_id FK, line_no, item_id FK, from_position_id?, to_position_id?, q, input_q, input_uom, package_id?, conversion_factor, source_line_id?, measured_method? | q>0; ao menos uma posição; posições compatíveis com item; snapshot de conversão |
| `stock_entries` M | document_id FK, line_id FK, position_id FK, signed_q, posted_at, entry_no | Assinado não zero; append-only; único document/entry_no; entradas/saídas validam tipo |
| `reason_codes` M | code, operation_type, label, requires_note, active | Tipos controlados; histórico mantém motivo mesmo após inativação |
| `events` M | unit_id FK, name, starts_at, ends_at, timezone, venue_text?, estimated_people?, manager_id FK membership, status, return_due_at, close_due_at | Fim≥início; transições válidas; fechar bloqueia movimentos |
| `event_locations` M | event_id FK, location_id FK, purpose | Local temporário associado a um único evento; mesma unidade no MVP |
| `event_plan_lines` M | event_id FK, item_id FK, planned_q, required, source_location_id?, version | Planejado≥0; reservar/expedir é derivado de documentos, não campo manual |
| `reservations` M | event_plan_line_id FK, item_id FK, status, requested_q, expires_at?, created_by | Requested≥0; evento aberto; não cria saldo |
| `reservation_allocations` M | reservation_id FK, position_id FK, allocated_q, fulfilled_q, released_q | Todos≥0; fulfilled+released≤allocated; reserva ativa = allocated−fulfilled−released |
| `dispatches` M | event_id FK, document_id FK, manifest_number, confirmed_at, confirmed_by, status | Uma efetivação por documento; confirma entrega física no MVP |
| `event_closures` M | event_id FK, version_no, status, submitted_by, approved_by?, closed_at?, reopened_reason? | Único evento/versão; só uma versão corrente; snapshot histórico |
| `event_closure_lines` M | closure_id FK, item_id FK, initial_q, in_q, consumed_q, lost_q, returned_q, out_q, counted_final_q, unclassified_q, classification_note? | Snapshot dos fatos e contagem; diferença zero para aprovar; links aos documentos |
| `event_closure_documents` M | closure_id FK, document_id FK, purpose | PK tenant/closure/document; impede somar documento duas vezes no acerto |
| `inventory_counts` M | location_id FK, status, opened_at, cutoff_at, submitted_at?, approved_at?, counter_id?, approver_id? | Ciclo formal; aprovação diferente do contador salvo exceção auditada |
| `inventory_count_scope` M | count_id FK, location_id FK, item_id FK, locked_at, released_at? | No máximo uma sessão ativa por tenant/local/item; todo movimento verifica bloqueio |
| `inventory_count_lines` M | count_id FK, position_id FK, expected_q, counted_q?, recount_q?, variance_q, counter_id, counted_at?, correction_document_id? | Contado≥0; desconhecido é NULL, não zero; fotografia do corte |
| `approvals` M | stock_document_id?, purchase_request_id?, purchase_order_id?, inventory_count_id?, event_closure_id?, state, requester_id, reviewer_id?, decision_at?, note? | Exatamente um alvo; FKs reais; política de segregação e alçada futura |
| `audit_events` M | actor_user_id?, actor_kind, action, entity_type, entity_id, request_id, occurred_at, redacted_before?, redacted_after?, reason? | Append-only; alvo polimórfico é registro histórico, não FK operacional; sem tokens/segredos |
| `idempotency_requests` M | actor_user_id, command, key, payload_hash, state, response_ref?, expires_at | Único tenant/command/key; resultado autorizado ao solicitante; hash não substitui validação |

`stock_entries` é a verdade quantitativa; `stock_positions` é projeção usada para bloqueio e consulta. A soma de entradas por posição deve reconciliar exatamente com `on_hand_q`; `reserved_q` reconcilia com alocações abertas. Atributos de linha precisam de validação transacional entre tabelas, além de CHECKs locais.

### 21.4 Compras, ativos, custos e suporte

| Entidade / fase | Campos específicos e relações | Restrições essenciais |
|---|---|---|
| `purchase_requests` M | number, unit_id FK, event_id?, needed_on, emergency, justification, status, requester_id | Número único tenant; urgência justificada |
| `purchase_request_lines` M | request_id FK, item_id FK, requested_q, location_id FK, note? | q>0; referências mesmo tenant |
| `purchase_orders` M | number, supplier_id FK, delivery_location_id FK, currency, expected_on, status, issued_at?, approved_by? | Preços em tabela financeira; status não substitui recebimentos |
| `purchase_order_lines` M | order_id FK, item_id FK, package_id FK, ordered_input_q, factor_snapshot, ordered_base_q, description_snapshot, cancelled_q | Quantidades positivas; cancelamento só sobre não recebido |
| `purchase_order_allocations` M | order_line_id FK, request_line_id FK, allocated_q | Liga consolidação às demandas originais; q≤pendências disponíveis |
| `receipts` M | order_id?, supplier_id FK, external_reference?, received_at, status, receiver_id, stock_document_id? | Avulso exige aprovação; documento efetivado único |
| `receipt_lines` M | receipt_id FK, order_line_id?, item_id FK, lot_id FK, delivered_q, accepted_usable_q, accepted_blocked_q, rejected_q, package/factor snapshot | Entregue=aceitas+rejeitada; valores não negativos; lote do item |
| `supplier_returns` M | receipt_id FK, stock_document_id FK, status, reason, commercial_resolution | Resolução replace/cancel/external_credit_reference; sem reembolso automático |
| `supplier_return_lines` M | return_id FK, receipt_line_id FK, returned_q, request_replacement | Soma devolvida não excede aceito líquido elegível à devolução |
| `asset_units` M | item_id FK, asset_tag, serial_number?, position_id FK, ownership, owner_reference?, status | Tag única tenant; position.item=item; item serializado; uma posição corrente |
| `asset_custodies` M | asset_id FK, event_id?, custodian_membership_id FK, checked_out_at, due_at, checked_in_at?, status | No máximo uma custódia aberta por ativo; encerramento não apaga extravio |
| `asset_document_links` M | asset_id FK, document_line_id FK, from_position_id?, to_position_id? | Único ativo/linha; quantidade dos patrimônios reconcilia com lançamentos |
| `finance.item_location_values` M | item_id FK, location_id FK, stock_value, stock_q_reference, avg_unit_cost, version | Schema não exposto; média e valor reconciliam com movimentos e quantidades |
| `finance.entry_values` M | stock_entry_id FK, signed_value, unit_cost_snapshot, currency | Um valor por entrada; transferência conserva valor; imutável |
| `finance.order_line_prices` M | order_line_id FK, input_unit_price, discount_value, freight_share, other_costs, total_value | Único por linha/version; snapshots de aprovação |
| `finance.receipt_line_costs` M | receipt_line_id FK, accepted_total_cost, unit_base_cost, freight_share, note? | Custo apenas aceitas; variações aprovadas |
| `finance.supplier_prices` M | supplier_item_id FK, package_price, currency, valid_from, valid_until? | Histórico; não editar preço usado retroativamente |
| `finance.value_adjustments` M | number, item_id FK, location_id FK, related_document_id?, status, requested_by, approved_by?, reason, posted_at? | Sem quantidade; segregação e capacidade cost.adjust; idempotência; efetivado imutável |
| `finance.value_adjustment_lines` M | adjustment_id FK, signed_value, currency, pool_version_before, note | Valor final não negativo; pool com quantidade positiva; conserva custos históricos |
| `alert_rules` M | rule_type, scope, thresholds, window_days, enabled | Alvo tipado item/local/lote/evento; versão e escopo |
| `alerts` M | rule_id FK, target_type, target_id, cycle_key, severity, status, assigned_to?, first_seen_at, resolved_at? | Chave única regra/alvo/ciclo; alvos validados no gerador |
| `alert_acknowledgements` M | alert_id FK, membership_id FK, acknowledged_at | Único alerta/usuário; reconhecimento não resolve causa |
| `attachments` M | object_path, file_name, mime_type, byte_size, stock_document_id?, receipt_id?, event_id?, asset_id?, uploaded_by | Bucket privado; exatamente um alvo FK; limite de tamanho/tipo; custo sensível herda restrição |
| `stock_periods` M | location_id FK, starts_at, ends_at, status, closed_by?, closed_at? | Não sobrepor fechamentos; bloqueia retroatividade indevida |

`finance.*` fica em schema não exposto à Data API, sem grants ao cliente. Leitura de preço/custo ocorre por projeções/RPCs restritas à capacidade `cost.read` ou `purchase.price.read`, conforme o relatório. RLS não é mecanismo de ocultação de coluna; por isso valores não ficam ao lado das quantidades em uma tabela livremente legível por operadores.

Constraints adicionais do dicionário: `stock_document_lines` tem UNIQUE(tenant_id,document_id,id) para suportar a FK de lançamentos e UNIQUE(tenant_id,document_id,line_no) para a sequência de linhas. Aprovações têm no máximo uma decisão corrente por alvo/etapa. Cada ajuste de valor financeiro é auditado no próprio comando; a tabela operacional de aprovações pode referenciá-lo por uma coluna FK adicional exclusiva `value_adjustment_id`, mantendo a regra de exatamente um alvo.

### 21.5 Modelo da evolução

| Entidade / fase | Campos e relacionamentos planejados | Regra principal |
|---|---|---|
| `quote_requests` I | supplier deadlines, request_id, status, issued_at | Escopo de compra validado |
| `quote_request_lines` I | quote_request_id, request_line_id, item_id, q, package preferences | Necessidade normalizada |
| `supplier_quotes` I | quote_request_id, supplier_id, version, valid_until, promised_on, status | Proposta versionada |
| `supplier_quote_lines` I | quote_id, request_line_id, package_id, offered_q, lead_days | Quantidades e prazo; preço em finance.quote_line_prices |
| `finance.quote_line_prices` I | quote_line_id, unit_price, freight, discount, normalized_unit_cost | Mesmo isolamento financeiro |
| `quote_awards` I | request_line_id, quote_line_id, awarded_q, decision_by, reason, order_line_id? | Adjudicação preserva versão |
| `transfer_orders` I | from_location_id, to_location_id, transit_location_id, status, dispatched_at, received_at | Duas etapas; perda em trânsito precisa ocorrência |
| `transfer_order_lines` I | transfer_id, item_id, lot_id, expected_q, dispatched_q, received_q, incident_q | Balanço e parcial sem criação de saldo |
| `kits` I | code, name, status, current_version_id | Kit virtual sem saldo |
| `kit_versions` I | kit_id, version_no, status, valid_from, notes | Versão publicada imutável |
| `kit_components` I | version_id, item_id, q_per_kit, mode consume/returnable | Sem aninhamento no primeiro estágio |
| `consumption_sheets` I | code, name, execution_uom, status | Tarefa operacional |
| `consumption_sheet_versions` I | sheet_id, version_no, output_quantity, status | Rendimento explícito |
| `consumption_sheet_lines` I | version_id, item_id, planned_input_q, tolerance | Entradas de consumíveis; ativos só alocação |
| `consumption_executions` I | sheet_version_id, event_id?, location_id, execution_q, document_id, external_occurrence_id | Uma baixa por ocorrência |
| `production_lot_inputs` I | output_lot_id, input_lot_id, consumed_q, document_id | Genealogia de preparo/reembalagem |
| `asset_reservations` I | asset_id ou item_id/q, event_id, interval, status | Sem sobreposição confirmada; validar quantidades simultâneas |
| `maintenance_orders` I | asset_id, type, status, opened_at, due_at, completed_at, responsible_id | Ativo indisponível enquanto bloqueado |
| `import_jobs` I | type, file_path, mapping_version, status, hash, requested_by, totals | Preview e idempotência por arquivo/linha |
| `import_rows` I | job_id, row_no, normalized_payload, errors, source_key, applied_entity_id? | Validação e resultado por linha |
| `sync_operations` I | device_id, user_id, command_id, base_version, payload_hash, status, conflict_code | Autorização reavaliada no replay |
| `devices` I | membership_id, local_identifier, last_sync_at, revoked_at | Sem identificador sensível desnecessário |
| `notification_deliveries` I | alert_id, membership_id, channel, attempt, status | Opt-in e retentativas sem duplicar envio |
| `daily_stock_snapshots` I | date, item_id, location_id, q, reserved_q | Base de giro/cobertura; valores em finance separado |
| `finance.daily_stock_values` I | snapshot_id, stock_value | Acesso financeiro independente |
| `webhook_outbox` O | event_type, entity_id, destination_ref, attempts, status | Assinatura, retry e idempotência |

Módulos opcionais de sensores/RFID e BI externo só terão entidades adicionais após definição do caso de uso. Não se usa JSON genérico para substituir relações essenciais; JSON é reservado a metadados de importação, snapshots e auditoria sanitizada.

## 22. Schema SQL planejado

### 22.1 Fronteiras e sequência de definição

`public`: dados operacionais e views explicitamente expostas; `private`: helpers, comandos internos, idempotência e configuração sensível; `finance`: custos e preços; `auth` e `storage`: gerenciados pelo Supabase. O dicionário acima indica entidades lógicas; auditoria, convites, regras de papel e tabelas de controle devem ficar em `private`, com leitura por endpoints limitados.

Ordem futura de criação: (1) schemas e papéis SQL; (2) organização, identidade e referência; (3) unidades/locais; (4) catálogo e fornecedores; (5) pedidos/eventos; (6) lotes/posições/documentos; (7) reservas/contagens/ativos; (8) custo; (9) constraints interdependentes; (10) helpers/RPCs; (11) RLS/grants; (12) views/índices; (13) seeds e testes. FKs circulares, como receipt_line ↔ lot, serão criadas após as duas tabelas; não exigir criação impossível em uma única ordem linear.

### 22.2 Amostra de DDL do núcleo

Os trechos ilustram decisões de tipos e integridade. **Não constituem migração executável completa**: dependem de tabelas, funções, triggers e políticas descritas neste documento. Não foram executados, compilados ou aplicados a um Supabase.

```sql
-- Referências simplificadas: organizations, items, locations e lots
-- possuem UNIQUE (tenant_id, id), exceto organizations (id).
-- lots também possui UNIQUE (tenant_id, item_id, id).
create table public.stock_positions (
  id uuid primary key default gen_random_uuid(),
  tenant_id uuid not null references public.organizations(id),
  item_id uuid not null,
  location_id uuid not null,
  lot_id uuid not null,
  condition text not null check
    (condition in ('usable', 'quarantine', 'damaged')),
  on_hand_q numeric(20,6) not null default 0 check (on_hand_q >= 0),
  reserved_q numeric(20,6) not null default 0 check (reserved_q >= 0),
  version bigint not null default 0,
  created_at timestamptz not null default now(),
  created_by uuid not null references auth.users(id),
  unique (tenant_id, id),
  unique (tenant_id, item_id, location_id, lot_id, condition),
  foreign key (tenant_id, item_id) references public.items(tenant_id,id),
  foreign key (tenant_id, location_id) references public.locations(tenant_id,id),
  foreign key (tenant_id, item_id, lot_id)
    references public.lots(tenant_id,item_id,id),
  check (reserved_q <= on_hand_q),
  check (condition = 'usable' or reserved_q = 0)
);

create table public.stock_documents (
  id uuid primary key default gen_random_uuid(),
  tenant_id uuid not null references public.organizations(id),
  number text not null,
  type text not null check (type in
    ('opening','receipt','consumption','loss','reclassification',
     'transfer','supplier_return','adjustment','reversal')),
  status text not null check (status in
    ('draft','pending','approved','posted','rejected','cancelled')),
  idempotency_key uuid not null,
  effective_at timestamptz not null,
  posted_at timestamptz,
  requested_by uuid not null references auth.users(id),
  approved_by uuid references auth.users(id),
  reversal_of_id uuid,
  unique (tenant_id,id),
  unique (tenant_id,number),
  unique (tenant_id,idempotency_key),
  foreign key (tenant_id,reversal_of_id)
    references public.stock_documents(tenant_id,id),
  check ((status = 'posted') = (posted_at is not null))
);

create table public.stock_entries (
  id uuid primary key default gen_random_uuid(),
  tenant_id uuid not null,
  document_id uuid not null,
  line_id uuid not null,
  position_id uuid not null,
  entry_no integer not null check (entry_no > 0),
  signed_q numeric(20,6) not null check (signed_q <> 0),
  posted_at timestamptz not null,
  unique (tenant_id,id),
  unique (tenant_id,document_id,entry_no),
  foreign key (tenant_id,document_id)
    references public.stock_documents(tenant_id,id),
  foreign key (tenant_id,document_id,line_id)
    references public.stock_document_lines(tenant_id,document_id,id),
  foreign key (tenant_id,position_id)
    references public.stock_positions(tenant_id,id)
);
```

Lançamentos só podem ser inseridos na transação de efetivação. Integridade adicional a implementar: documento aprovado quando necessário; posição física ativa; validade por local/fuso; item/linha/posição compatíveis; integridade do par de transferência; quantidades discretas; saldo e reserva; bloqueio de contagem; correspondência entre ativos e quantidades; soma dos custos. Triggers restritos proíbem UPDATE/DELETE em lançamentos e alteração de documento efetivado. Um CHECK local não consegue garantir a soma entre várias linhas.

### 22.3 Índices planejados

| Alvo | Índice/constraint proposto | Consulta atendida |
|---|---|---|
| memberships | UNIQUE tenant/user; user/status/tenant | Contextos e autorização |
| scope_grants | membership/status temporal; tenant/unit, tenant/location, tenant/event | Escopo corrente |
| items | UNIQUE tenant/sku; tenant/category/status; busca normalizada | Cadastro e pesquisa |
| positions | Unique da posição; tenant/location/item; tenant/item/condition | Saldo por local/item |
| lots | tenant/item/expires_on; tenant/internal_code único | FEFO, validade, origem |
| entries | tenant/position/posted_at/id; tenant/document | Extrato paginado e reconciliação |
| reservations | tenant/event_plan_line/status; allocations tenant/position | Concorrência e prontidão |
| events | tenant/unit/starts_at; tenant/status/ends_at | Agenda e acertos pendentes |
| receipts/orders | tenant/order; tenant/status/expected_on; linhas parent_id | Parcial e atrasos |
| assets | UNIQUE tenant/asset_tag; tenant/position; custódia aberta parcial | Patrimônio e retorno |
| counts | índice único parcial em scope(tenant,location,item) onde released_at IS NULL | Um bloqueio ativo por escopo |
| alerts | UNIQUE tenant/rule/target/cycle; tenant/status/severity | Deduplicação e fila |
| audit | tenant/occurred_at/id; tenant/entity_type/entity_id | Consulta histórica |

Indexar FKs e predicados reais de RLS; verificar planos com dados de escala antes de adicionar índices redundantes. No MVP não particionar por antecipação. A projeção de saldo evita somar o histórico inteiro a cada consulta; reconciliação reprocessa o ledger fora do caminho crítico. PostgreSQL oferece locks de linha e recomenda considerar deadlocks; as operações do produto adotarão ordem consistente. [Locks do PostgreSQL](https://www.postgresql.org/docs/current/explicit-locking.html).

### 22.4 Contrato transacional de efetivação

1. Validar sessão, vínculo atual, capacidade, tenant, escopos dos dois locais e janela do evento.
2. Inserir/obter registro idempotente exclusivo; comparar hash canônico do payload.
3. Bloquear documento e verificar versão, estado e aprovação.
4. Serializar chaves de posições ausentes; bloquear posições, pools de custo e reservas em ordem fixa.
5. Revalidar lotes, validade, saldo, reservas, período, contagem e ativos.
6. Escrever entradas, valores, atualização das posições/reservas/custódias e estado posted.
7. Gravar auditoria e resultado idempotente na mesma transação; commit.
8. Retornar confirmação e invalidar cache. Alertas secundários podem ser gerados depois; falha de alerta não desfaz movimento confirmado.

Deadlock/transient failure permite retry limitado com a mesma chave; erro de negócio exige revisão do operador. Para transferência, bloquear chaves em ordem lexical `(tenant,item,location,lot,condition)` e pools de valor em ordem previamente fixada; não escolher ordem conforme o sentido da transferência.

## 23. Autenticação, autorização, multi-tenant e segurança

### 23.1 Autenticação e sessões

MVP: e-mail/senha com confirmação de endereço; recuperação com redirecionamentos autorizados; convite de equipe; encerramento de sessão; MFA obrigatório para proprietário, administração de acesso, gestão e aprovação financeira. Não habilitar autenticação anônima para a aplicação operacional. Troca de senha e recuperação não revelam se uma conta existe por mensagens distintas.

Auth autentica a identidade; memberships e grants autorizam o negócio. Não confiar em user_metadata para papel, tenant ou capacidade. Consultar vínculo ativo no banco por operação, com checagem de validade temporal. JWT antigo não mantém permissão removida quando a autorização depende do vínculo atual. Para ações sensíveis, validar nível de MFA e estado da sessão no servidor. [RLS e Auth no Supabase](https://supabase.com/docs/guides/database/postgres/row-level-security).

Convite guarda hash de token, expira e tem uso único; aceite associa e-mail confirmado e cria vínculos numa transação. Só quem pode conceder determinado escopo pode convidar para ele; administrador não pode conceder acesso a uma organização de que não participa. Criação inicial da organização é comando controlado, sem liberar INSERT arbitrário em memberships.

### 23.2 Fronteiras de segurança

RLS habilitada em todas as tabelas expostas, inclusive tabelas filhas. Grants explícitos só para leitura necessária; `anon` não lê dados operacionais. Grants controlam acesso a tabelas; RLS controla linhas. A documentação atual do Supabase descreve a adoção de exposição explícita via GRANT; o projeto não dependerá de defaults históricos. [Mudança da Data API](https://supabase.com/changelog/45329-breaking-change-tables-not-exposed-to-data-and-graphql-api-automatically).

Publicar frontend apenas com URL e publishable key. Secret key e `service_role` nunca entram em variáveis `VITE_*`, bundle, log, CSV ou navegador. Política de CSP, prevenção de XSS, escaping, dependências fixadas e auditoria de pacote fazem parte do build. Headers e CORS não substituem RLS.

Comandos privilegiados são funções internas pequenas e revisadas. Preferir SECURITY INVOKER para consultas e wrappers. Quando a escrita append-only exigir SECURITY DEFINER, usar schema `private`, `search_path` fixo/vazio, nomes qualificados e proprietário SQL dedicado `NOLOGIN` com privilégios mínimos, sem criar uma função genérica de SQL. A função verifica identidade, capacidade e escopo internamente; o bypass implícito não é mecanismo de autorização. Não conceder associação do papel escritor aos usuários. [Funções e permissões Supabase](https://supabase.com/docs/guides/database/functions).

O escritor dedicado recebe só DML necessário e políticas próprias de escrita validando contexto do chamador; não precisa ser superuser nem ter BYPASSRLS. Helpers de leitura de autorização podem usar DEFINER restrito para evitar recursão em memberships, com acesso apenas às tabelas de autorização e predicados fixos. `authenticated` terá EXECUTE apenas nas funções intencionalmente usadas por políticas/wrappers; `PUBLIC` e `anon` perdem EXECUTE. Schema não exposto evita rota REST direta, mas não substitui verificação da função.

### 23.3 Matriz de RLS e acesso

| Grupo | SELECT | INSERT/UPDATE/DELETE pelo cliente |
|---|---|---|
| Profiles | Somente o próprio perfil | Campos permitidos do próprio perfil; sem autorização armazenada |
| Organizations/memberships | Organizações do usuário; vínculo próprio e equipe por capacidade administrativa | Só comandos de criação, convite e gestão de acesso |
| Catálogo/unidades/locais | Vínculo ativo e capacidade de catálogo; locais filtrados por escopo | Comandos de cadastro; tenant e chaves imutáveis |
| Posições/entradas/reservas | Escopo de local/evento e stock.read; validade na projeção de elegível | Nenhum DML direto; apenas comandos transacionais |
| Documentos/linhas | Documento completo apenas se todos os locais estão autorizados; extrato local sanitizado quando acesso é parcial | Rascunhos e efetivação por comandos; sem UPDATE de posted |
| Eventos/plano/acerto | Escopo do evento e capacidade correspondente | Comandos específicos; transições e fechamento protegidos |
| Compras/fornecedores | Capacidade de compras e unidade de destino autorizada | Comandos de solicitação/pedido/recebimento |
| Financeiro | Nenhum acesso direto a finance; projeções com capacidade e escopo próprios | Comandos financeiros controlados |
| Ativos/custódia | Locais/eventos autorizados | Transferência/custódia atômicas |
| Auditoria | Endpoint para auditor/admin, com redação por escopo | Append apenas pelo servidor, sem DELETE pelo cliente |
| Arquivos | Acesso derivado da entidade real anexada | Upload com validação de alvo; remoção por fluxo auditado |
| Globais de referência | UOMs públicos ao autenticado; papéis/capacidades só conforme necessidade | Somente manutenção da plataforma |

Um documento que cruza dois locais pode revelar quantidade e operação de local não autorizado. Por isso, leitura do documento inteiro exige autorização sobre todos os locais. O extrato de quem só possui um lado mostra sua própria entrada/saída com referência opaca e sem dados do outro local. Custos continuam ausentes. A política da tabela filha segue a do documento, não apenas um tenant_id fornecido na URL.

### 23.4 Exemplos planejados de políticas

Os helpers abaixo são contratos de autorização a implementar e testar, não funções já existentes. `can_at_location` exige auth.uid, vínculo ativo, capacidade e escopo/tempo; `can_catalog` verifica capacidade de cadastro/consulta. O tenant da linha sempre participa da verificação.

```sql
alter table public.stock_positions enable row level security;
revoke all on public.stock_positions from anon, authenticated;
grant select on public.stock_positions to authenticated;

create policy stock_position_read on public.stock_positions
for select to authenticated
using (
  private.can_at_location(tenant_id, location_id, 'stock.read')
);
-- Sem policy/grant de escrita para authenticated.

alter table public.items enable row level security;
grant select on public.items to authenticated;
create policy catalog_read on public.items
for select to authenticated
using (private.can_catalog(tenant_id, 'catalog.read'));

alter table public.profiles enable row level security;
grant select on public.profiles to authenticated;
grant update (display_name, locale, timezone)
  on public.profiles to authenticated;
create policy own_profile_read on public.profiles
for select to authenticated
using (user_id = (select auth.uid()));
create policy own_profile_update on public.profiles
for update to authenticated
using (user_id = (select auth.uid()))
with check (user_id = (select auth.uid()));

-- View futura, depois de criadas suas dependências:
create view public.position_quantities
with (security_invoker = true) as
select tenant_id, id, item_id, location_id, lot_id,
       condition, on_hand_q, reserved_q
from public.stock_positions;
```

A view é quantitativa; disponibilidade requer lote, validade e bloqueios. Qualquer view que os reúna também precisa obedecer RLS e não expor campos financeiros. Policies UPDATE têm USING e WITH CHECK explícitos e SELECT correspondente. Não se aplica a mesma policy genérica a todas as tabelas: relações, escopos e capacidade de leitura diferem. [Views e RLS](https://supabase.com/docs/guides/database/postgres/row-level-security#views).

### 23.5 Storage, privacidade e recuperação

Bucket privado; caminho inclui tenant e UUID do anexo, mas o nome do caminho não concede acesso. Policy consulta metadado `attachments` e autorização da entidade vinculada. Comprovante com preço herda permissão financeira. URLs assinadas são curtas e emitidas após autorização; política de download deve considerar que uma URL assinada permanece válida até expirar. Upsert só quando previsto, com permissões necessárias e controle de versão. [Controle de acesso Storage](https://supabase.com/docs/guides/storage/security/access-control).

Validar tipo real, tamanho, extensão e nome do arquivo; impedir HTML/SVG executável e armazenar conteúdo não confiável para download seguro. Importação nunca executa fórmula ou macro. Rotinas administrativas registram request_id, quem alterou acesso e por quê, sem senha, token, payload integral ou arquivo sensível no log.

Minimização: nome de equipe e contatos empresariais necessários; dados de convidados, documentos pessoais e dados bancários fora do MVP. Planejar exportação de dados da organização, revogação de conta e anonimização dos identificadores pessoais mantendo histórico operacional quando houver base de retenção definida. Prazos contratuais de retenção, residência e obrigações de privacidade serão validados antes do lançamento comercial; este briefing não fixa uma conclusão jurídica.

Backup, ensaio de restauração, rotação de segredos, monitoramento de acessos negados e resposta a incidente entram no checklist de produção. Revisar advisors de segurança/performance do Supabase após a futura implementação, incluindo RLS, funções, views e Storage; não declarar essas verificações como já realizadas.

## 24. CSV, leitor de código de barras e PWA/offline

### 24.1 CSV

MVP: exportar catálogo, saldos, extrato, compras e acerto com filtros/permissões aplicados no servidor. Oferecer formato pt-BR documentado e um formato de integração com datas ISO e decimal normalizado. Quantidades e códigos preservam precisão e zeros à esquerda. Informar unidade, fuso, data de extração e contexto. Escapar aspas/quebras de linha e neutralizar células que planilhas possam interpretar como fórmulas (`=`, `+`, `-`, `@`), considerando o tipo da coluna para não corromper números legítimos.

Importação é importante depois: upload privado → seleção do tipo → mapeamento de colunas → normalização → preview → erros/duplicatas por linha → confirmação → processamento em lotes → resumo e arquivo de rejeições. Tipos iniciais: itens, fornecedores, embalagens e saldo inicial. Importar saldo não significa sobrescrever a projeção: gera documento de abertura ou ajuste aprovado. Importação de histórico é projeto separado.

Contrato inicial de item: `external_key, sku, nome, categoria, natureza, controle_ativo, unidade_base, passo_quantidade, exige_validade, status`. Embalagem: `sku, codigo_embalagem, descricao, quantidade_base`. Saldo inicial: `external_key, sku, unidade_codigo, local_codigo, lote_interno_ou_comercial, validade, condicao, quantidade_base, custo_unitario_opcional`. Custo só pode ser enviado por perfil autorizado.

SKU existente gera escolha explícita de atualização de campos permitidos; não altera unidade base ou método de ativo já usado. Registrar hash do arquivo e chaves por linha; reenvio não reaplica estoque. Erro em uma linha não fica invisível num sucesso geral; modo atômico ou parcial é informado antes de confirmar. Em lote parcial, cada linha bem-sucedida tem resultado idempotente e trilha.

### 24.2 Códigos de barras

Leitor USB/Bluetooth que emula teclado é a primeira evolução: foco no campo de busca, terminador configurável, tratamento de repetição e mensagem para código não cadastrado. Ler código seleciona item/embalagem e propõe quantidade; não efetiva uma saída silenciosamente. Cadastro restringe código duplicado no tenant e preserva texto com zeros à esquerda.

Câmera é opcional e depende de permissões e suporte testado no dispositivo. Fallback por digitação sempre disponível. EAN/UPC identifica embalagem; QR interno pode identificar patrimônio, local ou documento com tipo explícito. Lote/validade só são extraídos de códigos estruturados quando o formato for validado e houver conferência. Não presumir que qualquer barcode contém esses dados.

### 24.3 PWA e estratégia offline por estágio

1. **MVP online:** detectar perda de conexão, preservar formulário na sessão e impedir mensagem de confirmação sem resposta. Timeout permite consultar pelo command_id antes de repetir. Sem prometer envio futuro oculto.
2. **PWA instalável e leitura:** manifest e shell em service worker; cache mínimo por usuário/tenant e indicador de última sincronização; limpar dados no logout/troca de organização. Instalar não significa funcionar integralmente offline.
3. **Rascunhos e contagens offline:** IndexedDB para escopo autorizado, prazo de validade local e fila explícita; contagem enviada exige revisão do corte e conflitos. Interface informa “salvo neste dispositivo” e “pendente de envio”.
4. **Movimentos offline limitados:** fila com UUID de comando, dispositivo, versão de base, hash, dependências e estado. Servidor revalida sessão/vínculo, validade, saldo e reservas ao reconectar. Conflito vira revisão humana; nunca last-write-wins em saldo. Aprovação, encerramento e administração continuam online.

Sem coordenação online não se pode garantir que duas retiradas de dispositivos distintos não disputem o mesmo saldo. Para eventos realmente sem rede, avaliar previamente cotas alocadas por dispositivo/local e reconciliação, ou procedimento de contingência em papel numerado. Isso exige descoberta própria. Background sync e execução em segundo plano variam por navegador; oferecer sincronização manual. [PWA offline e segundo plano](https://developer.mozilla.org/en-US/docs/Web/Progressive_web_apps/Guides/Offline_and_background_operation).

## 25. Estratégia de dados de demonstração e teste

### 25.1 Ambientes de demonstração

Dados inteiramente sintéticos; nunca copiar operação real sem base e autorização. Identificar “Demonstração” de forma persistente. Demo não deve usar fallback silencioso quando a conexão de produção falhar; erro de configuração precisa aparecer como erro. Sem envio de e-mail comercial ou compra a fornecedor real.

Criar dois tenants independentes, **Operação Farol** e **Equipe Horizonte**, com nomes e contatos fictícios. Farol: depósito central, bar fixo, cozinha e dois eventos simultâneos. Horizonte: unidade e equipe próprias, incluindo SKUs iguais aos de Farol para testar isolamento. Uma conta de QA participa dos dois com permissões diferentes; outras contas pertencem apenas a um.

Conjunto funcional proposto: 80 SKUs nas oito famílias — bebidas, alimentos, insumos, descartáveis, equipamentos, utensílios, materiais de evento e apoio —, 12 fornecedores, 6 usuários dos papéis básicos mais 2 temporários, 150 lotes, 20 ativos individualizados e retornáveis por quantidade, 15 pedidos e 8 eventos em estados distintos. Incluir item sem lote comercial, validade hoje/amanhã/vencida, reserva parcial, recebimento parcial, avaria, extravio, inventário discrepante e compensação.

### 25.2 Fixtures e cenários reproduzíveis

Datas relativas a um relógio de teste fixado, com fuso explícito; não deixar uma fixture válida vencer e quebrar testes meses depois. IDs/chaves determinísticos em ambiente de teste e geradores com seed. Repetir a carga não duplica entidades nem reaplica movimentos. Produzir o histórico por comandos de negócio, não por edição de `on_hand_q`; fixtures de projeção corrompida existem apenas no cenário de reconciliação.

Exemplos obrigatórios: compra 20 un com dois custos → consumo → transferência → perda → compensação permitida; duas reservas para 10 un disputando saldo 15; evento com 5 un sem classificação; ativo que retorna avariado; revogação de temporário com sessão aberta; CSV com zero à esquerda, vírgula, quebra de linha e fórmula maliciosa.

Guardar valores esperados do ledger, da projeção e do acerto por cenário. Massa de carga separada de demonstração: catálogo grande e histórico volumoso sem tornar a demo incompreensível. Reset só em ambientes identificados de teste, nunca em produção.

## 26. Plano de testes funcional, carga e segurança

### 26.1 Estratégia de verificação futura

Usar testes de domínio para conversões, transições e fórmulas; integração em PostgreSQL/Supabase para transações, RLS e constraints; E2E de fluxos reais no navegador; testes manuais de acessibilidade e operação em celular; carga contra ambiente isolado. Ferramentas candidatas: Vitest, Playwright, pgTAP e k6, a selecionar e versionar durante a implementação. Este documento é plano: nenhum teste de aplicativo foi executado.

### 26.2 Matriz funcional mínima

| Teste | Ação / condição | Resultado esperado |
|---|---|---|
| F01 | Criar organização e repetir chamada | Uma organização, um proprietário e mesmo resultado idempotente |
| F02 | Cadastrar SKU repetido ou unidade incompatível | Erro de domínio; histórico intacto |
| F03 | Receber duas caixas de 6 × 750 ml | Crédito de 9.000 ml, fator capturado e lote rastreável |
| F04 | Receber parcial com 60 utilizáveis, 6 bloqueadas, 6 rejeitadas | Físico +66, elegível +60, saldo a receber coerente |
| F05 | Retirar 11 un de saldo elegível 10 | Nenhum lançamento nem valor alterado |
| F06 | Duas transações retiram 7 un de saldo 10 | Uma confirma; outra falha por saldo; nunca negativo |
| F07 | Duas reservas de 10 un sobre saldo 15 | No máximo 15 alocadas firmemente; falta visível |
| F08 | Expedir reserva parcial e repetir confirmação | Reserva reduz uma vez; transferência aplicada uma vez |
| F09 | Lote vence entre seleção e confirmação | Servidor rejeita uso; reserva fica inválida e gera pendência |
| F10 | Reclassificar 2 un como avariadas e depois descartar 1 | Físico mantém total na avaria; descarte reduz uma vez |
| F11 | Transferência concorrente A→B e B→A | Sem saldo criado; locks em ordem, retry idempotente se necessário |
| F12 | Inventário aberto e entrada em item bloqueado | Movimento rejeitado; recontagem/cancelamento controlados |
| F13 | Contar item físico ausente da referência | Inclusão supervisionada com esperado zero, sem burlar lote/cadastro |
| F14 | Estornar entrada já consumida além do saldo | Estorno físico impossível bloqueado; correção orientada |
| F15 | Compensação parcial repetida | Soma compensada nunca excede original; sem repetição |
| F16 | Evento com diferença de 5 un | Fechamento bloqueado até classificação e aprovação |
| F17 | Evento sem saldo, com reserva ou perda pendente | Fechamento bloqueado até resolver ambas |
| F18 | Retornar patrimônio errado ou consumir retornável | Operação rejeitada; custódia correta preservada |
| F19 | Reabrir evento fechado | Nova versão auditada; snapshot anterior preservado |
| F20 | Alterar fator de embalagem após pedido aprovado | Pedido e recebimento usam snapshot aprovado |
| F21 | Custo médio e transferência entre locais | Quantidades e valor total conservados; consumo reconhecido uma vez |
| F21b | Ajuste exclusivamente financeiro aprovado | Quantidade intacta; valor corrente e média atualizados; histórico de saídas preservado; usuário sem cost.adjust impedido |
| F22 | Timeout após commit e repetição da ação | Mesmo documento retorna, sem duplicar |
| F23 | Revogar vínculo durante operação aberta | Próximo comando negado; sem mudança parcial |
| F24 | Exportar com usuário sem custo | Nenhum preço/valor em arquivo, API ou metadado |
| F25 | Falhar entre ledger e projeção em teste injetado | Rollback integral; reconciliação permanece exata |
| F26 | Consultar validade na virada do dia e em outro fuso | Mesma semântica de data local em tela e servidor |
| F27 | Job de alerta repetido e causa reconhecida | Uma ocorrência por ciclo; reconhecer não apaga causa |
| F28 | Movimentos aleatórios válidos e inválidos | Invariantes de saldo, reserva, valor e ativo preservados |

Kits, cotações, leitor e offline terão suites próprias quando entrarem em fase: versão de ficha não retroage; comparação normaliza embalagem; código não duplica movimento; replay offline com usuário revogado ou saldo insuficiente gera conflito. Não bloquear o MVP por testes de funcionalidades ainda não implementadas.

### 26.3 Carga e capacidade

Envelope inicial proposto, a confirmar com pilotos: 20 tenants sintéticos, tenant maior com 5 unidades, 30 locais, 10.000 SKUs, 100.000 posições e 1 milhão de lançamentos; 200 sessões simultâneas no total, com 30 comandos/s de leitura e 10 de escrita em carga sustentada por 30 minutos. Fazer teste separado de contenção com 50 comandos concorrentes sobre o mesmo SKU/local e teste de pico de 2× a taxa por 5 minutos.

Metas iniciais em homologação com rede/compute documentados: leitura paginada p95 ≤800 ms no servidor/API; comando de até 50 linhas p95 ≤1,5 s sem contenção artificial; conclusão visual usual ≤2,5 s na rede de teste; erros técnicos <1% sustentado e <2% no pico; zero violação de saldo, isolamento ou idempotência. Conflito de negócio esperado não conta como erro técnico, mas sua taxa é monitorada. Registrar p99, lock wait e deadlocks, e não esconder lentidão pela média.

Exportar 100 mil linhas em job é meta da evolução; no MVP limitar exportação síncrona a tamanho validado em carga e informar o limite, sem baixar toda a base no browser. Fazer soak de 2 h após estabilizar o padrão de carga para observar memória, conexões e jobs. Repetir só quando mudanças ou falhas justificarem, não como rito sem objetivo.

### 26.4 Segurança

Testar com cliente real autenticado contra Data API e RPC, não apenas no SQL Editor como proprietário:

- Tenant A tentando SELECT/INSERT/UPDATE/DELETE de B, inclusive IDs conhecidos, linhas filhas, joins, views, arquivos e exportações.
- Usuário com um local tentando ler documento completo de transferência e inferir o outro local.
- Usuário sem preço tentando selecionar finance, chamar projeção financeira, baixar comprovante ou incluir campos ocultos no payload.
- Autoelevação via user_metadata, alteração de tenant_id, papel, is_owner, approved_by ou contagem aprovada pelo próprio autor.
- Tokens ausentes/expirados, sessão revogada, convite reutilizado, temporário fora da janela e MFA insuficiente.
- Chamada direta aos helpers e RPCs: execução deve ser mínima e sem função genérica privilegiada.
- SQL injection, XSS em descrição/observação, CSV injection, upload executável, path traversal e URL assinada para entidade alheia.
- Retry e replay de comando, payload alterado com mesma chave, pedido recebido em duplicidade e fechamento concorrente.
- Rate limits de login, convite, recuperação, comandos e exportação; limites por usuário/tenant com configuração operacional.
- Segredos ausentes do bundle/log; views security_invoker; RLS e grants corretos em todas as tabelas expostas; índices de autorização.

Critério: nenhuma vulnerabilidade crítica/alta conhecida sem correção; nenhuma leitura/escrita entre tenants; nenhuma elevação de função; nenhum valor monetário vazado ao papel sem acesso. Revisão independente de segurança antes da expansão comercial, além da suite automatizada.

### 26.5 Usabilidade, acessibilidade e recuperação

Cinco usuários representativos concluem receber, transferir, contar e acertar evento sem assistência após introdução breve; meta de 90% de sucesso nas tarefas principais, com problemas graves corrigidos. Medir duração e erros; teste pequeno é qualitativo e não prova adoção de mercado.

Verificar teclado, leitores de tela, foco, contraste e zoom conforme seção 19; celular Android e iPhone em rede estável e instável. Simular timeout/queda após commit e refresh de página. Ensaio de restauração recupera banco e arquivos em homologação, reconcilia ledger/projeções e documenta RPO/RTO observado.

## 27. Roadmap, critérios de aceite e lançamento

### 27.1 Sequência sugerida

Estimativa preliminar para dois desenvolvedores full-stack, designer parcial, QA e responsável de produto disponíveis. Não é compromisso de prazo; reestimar após pesquisa e desenho transacional. Faixa recomendada: **18–24 semanas até avaliação do piloto**, com tarefas sobrepostas; execução totalmente sequencial pode levar mais. Não reduzir segurança e integridade para caber numa data comercial.

| Etapa | Duração indicativa | Entregas | Porta de saída |
|---|---|---|---|
| 0. Descoberta e identidade | 2 semanas | Entrevistas, ICP, fluxos, validação do nome, protótipo mobile | Problemas e escopo validados; decisões críticas resolvidas |
| 1. Fundação | 3 semanas | Tenant, Auth, escopos, design system, catálogo, ambientes | Isolamento e convites testados; cadastros completos |
| 2. Motor de estoque | 4 semanas | Ledger, projeção, custo, conversão, transferência, perdas e contagem | Invariantes, concorrência e compensação aprovadas |
| 3. Compras e validade | 3 semanas | Fornecedor, solicitação, pedido, recebimento, alertas | Parcial, validade e custo reconciliados |
| 4. Eventos e ativos | 4 semanas | Reservas, manifesto, custódia, retorno e acerto | Evento de ponta a ponta sem pendência oculta |
| 5. Qualidade e operação | 3 semanas, parcialmente paralelas | E2E, RLS, carga, acessibilidade, exportação e restore | Checklist de liberação concluído |
| 6. Piloto assistido | 4 semanas | Operação fixa e itinerante, treinamento, métricas e correções | Critérios de adoção e confiabilidade avaliados |
| Evolução I | Ciclos de 2–4 semanas | Cotações, kits, importação, scanner, manutenção e offline em estágios | Uma capacidade validada por ciclo, com testes específicos |

Prioridade da evolução depende de evidências: se entrada de cadastro é gargalo, importar CSV antes de cotações; se montagem é repetitiva, kits; se falta rede impede uso, estudo offline prioritário. Não prometer todas as capacidades I em uma única versão sem reestimativa.

### 27.2 Critérios de aceite do MVP

1. As oito famílias de material podem ser cadastradas e movimentadas sem campos obrigatórios de drinks.
2. Pelo menos duas unidades e três locais operam no mesmo tenant, com transferência e escopos corretos.
3. Organização A não acessa dados/arquivos/custos de B em nenhum teste de API, view, RPC ou exportação.
4. Entradas, consumo, avaria, perda, transferência, ajuste e compensação mantêm ledger, saldo, reserva, ativos e valor reconciliados.
5. Concorrência e repetição não permitem saldo negativo, reserva duplicada ou recebimento em duplicidade.
6. Compra parcial, rejeição e devolução preservam quantidade aceita e saldo comercial a receber.
7. Lote vencido é bloqueado no servidor; FEFO e alerta funcionam com data/fuso definidos.
8. Evento completo recebe planejamento, reserva, expedição, operação, retorno e acerto; diferença não classificada impede fechamento.
9. Equipamento individualizado sai com identidade/responsável e retorna com condição; retornável por quantidade também reconcilia.
10. Usuário sem capacidade financeira não obtém valores via tela, arquivo, API, comprovante ou erro.
11. Fluxos principais funcionam por teclado e celular; problemas graves de acessibilidade/usabilidade são corrigidos.
12. Exportação corresponde aos filtros e permissões, sem duplicidade ou fórmula executável injetada.
13. Metas de carga acordadas são atingidas no ambiente documentado; zero violação de integridade.
14. Backup/restore, logs, processo de suporte e revogação de equipe temporária são ensaiados.
15. Nenhum bloqueador funcional, de perda de dados ou de isolamento permanece; piloto tem responsáveis treinados e contingência documentada.

### 27.3 Definition of Ready e Definition of Done

História pronta para desenvolvimento: persona e capacidade; fase; fluxo normal/exceção; campos e estados; escopo de acesso; impacto no ledger/custo; exemplo de conversão quando aplicável; critérios de aceite e dependências. Design tem versão desktop e mobile com estados essenciais.

História concluída: comportamento implementado e revisado; tipos/validação; testes adequados à mudança; RLS/grants revisados quando afetados; auditoria/observabilidade; acessibilidade; migração testada se existir; documentação e dados de demo ajustados. Em comando de estoque, “salvou na tela” não satisfaz a conclusão sem transação, idempotência e reconciliação.

### 27.4 Lançamento e operação assistida

Iniciar com 2–3 organizações piloto e poucos eventos, cadastrando inventário inicial conferido. Durante transição, definir qual sistema é fonte de verdade e uma data de corte; evitar registros concorrentes sem reconciliação entre planilha e PRUMO. Treinar por função: receber, retirar, registrar ocorrência e fechar. Disponibilizar procedimento para rede indisponível e canal de suporte acordado.

Acompanhar pendências, falhas técnicas e perdas de integridade diariamente no piloto. Incidente de saldo ou isolamento bloqueia expansão e exige reconciliação e análise de causa. Após quatro semanas, revisar H1–H6, adoção, qualidade do cadastro e custo operacional; decidir avançar, ajustar ou reduzir o público inicial.

## 28. Backlog inicial pronto para refinamento

O arquivo complementar **PRUMO-backlog.csv** contém histórias, fase, dependências e critérios de aceite resumidos para importação em um gerenciador de trabalho. Os IDs abaixo são estáveis; a estimativa por história será feita pela equipe após protótipo e detalhamento técnico.

| Épico | Histórias | Resultado |
|---|---|---|
| Descoberta e produto | PR-001 a PR-003 | Público, regras e protótipo próprios validados |
| Identidade e acesso | PR-004 a PR-008 | Usuário, organização, convites, capacidades e isolamento |
| Catálogo e estrutura | PR-009 a PR-013 | Locais, materiais, embalagens, fornecedor e níveis |
| Estoque e custeio | PR-014 a PR-022 | Ledger transacional, saldos, custo, perdas, transferência e contagem |
| Compras | PR-023 a PR-026 | Solicitação, pedido, conferência e devolução |
| Evento e ativos | PR-027 a PR-034 | Plano, reserva, manifesto, custódia, retorno e fechamento |
| Informação e operação | PR-035 a PR-039 | Alertas, relatórios, CSV, trilha e prontidão de produção |
| Qualidade e piloto | PR-040 a PR-044 | E2E, acessibilidade, carga, segurança e uso assistido |
| Evolução | PR-045 a PR-054 | CSV de entrada, cotações, kits, scanner, PWA, manutenção e análises |
| Opcionais | PR-055 a PR-058 | Câmera, sensores, BI e previsão assistida |

Ordem técnica crítica: identidade/escopo → catálogo/unidades → ledger/conversão/custo → compras e ativos → reserva/evento → acerto/relatórios → operação e piloto. Design e testes de contrato acompanham os módulos, sem esperar que todo o produto esteja pronto. Toda história M deve estar atendida para o MVP definido; qualquer retirada é mudança explícita de escopo.

Fora do backlog de produto: cardápio público, receitas de drinks, curadoria, favoritos de coquetéis, delivery, POS completo, emissão fiscal, contabilidade, pagamento a fornecedores, ingressos, convidados e transferência entre organizações. Integração com POS pode ser estudada futuramente como fonte de fatos de consumo, sem transformar PRUMO em caixa de vendas.

## 29. Riscos, tradeoffs e decisões pendentes

### 29.1 Riscos prioritários

| Risco | Probabilidade/impacto iniciais | Mitigação e sinal de acompanhamento |
|---|---|---|
| MVP amplo para vários segmentos | Alta/alto | ICP inicial, pesquisa e mudanças de escopo explícitas; acompanhar dependências e lead time |
| Cadastro/conversão incorretos | Alta/alto | Unidade base travada, fatores versionados, conferência e treinamento; medir correções |
| Operador não registra durante pico | Alta/alto | Fluxo curto, mobile, favoritos de materiais por contexto futuro; medir atraso de registro |
| Rede indisponível em evento | Alta/alto | Pilotar conectividade cedo; contingência e roadmap offline sem promessa falsa |
| Corrida de estoque/reserva/custo | Média/crítico | Transação, locks, idempotência e testes de contenção; reconciliar automaticamente |
| Vazamento de tenant ou custo | Média/crítico | FKs compostas, RLS específica, finance isolado e testes de API adversariais |
| Diferença classificada indevidamente | Alta/alto | Acerto bloqueado, recontagem, aprovação e indicadores de ajustes recorrentes |
| Custeio gerencial confundido com fiscal | Média/alto | Rótulos e escopo claros; integração contábil futura depende de projeto separado |
| Equipamento some entre equipes | Alta/alto | Custódia nominal, prazo, checklist e pendência antes de fechar |
| Lote/validade incompletos | Alta/alto | Exigência por SKU no recebimento; bloquear uso sem informação obrigatória |
| Dependência de pessoa única para aprovar | Média/médio | Substitutos por escopo; exceção de proprietário com trilha e limite acordado |
| Custo/limites de infraestrutura | Média/médio | Envelope de carga, monitoramento de storage/egress/compute e índices |
| Métricas sem baseline confiável | Alta/médio | Definições, amostras e qualidade exibidas; piloto com coleta prévia |
| Marca indisponível | Desconhecida/médio | Validar nome/domínio antes de identidade final e divulgação |
| Recuperação incompleta de arquivos | Média/alto | Backup e ensaio conjunto de banco e objetos |

### 29.2 Decisões propostas e pendentes

| ID | Tema | Recomendação provisória | Responsável / momento |
|---|---|---|---|
| D01 | Público prioritário | Depósito central + bar/eventos recorrentes | Produto, antes do protótipo final |
| D02 | Nome | PRUMO como trabalho; checar marca e domínio | Fundador/branding, antes de investimento público |
| D03 | MVP | Manter integralmente a coluna M; demais por ciclos | Produto e engenharia, antes da estimativa fechada |
| D04 | Conectividade | MVP online se os pilotos suportarem; senão replanejar | Operações/engenharia, na descoberta |
| D05 | Custo | Média móvel item/local, BRL e gerencial | Gestão/financeiro/engenharia, antes do ledger |
| D06 | Aprovações | Separar autor e aprovador; exceção de proprietário explícita | Operações, antes da matriz final |
| D07 | Fracionamento | ml/g/un/m; definir quais SKUs controlam conteúdo ou embalagem | Operações, antes da carga inicial |
| D08 | Validade | Data local; políticas específicas fornecidas pela operação | Responsável técnico da operação, antes do recebimento |
| D09 | Ativos | Quantidade e serial no MVP; agenda futura depois | Operações, antes do modelo final de ativos |
| D10 | Transferência | Confirmação imediata no MVP; trânsito em evolução | Logística, antes do piloto |
| D11 | Infra e região | Projetos separados; região próxima dos usuários após avaliação | Engenharia, antes do provisionamento |
| D12 | Retenção/privacidade | Minimizar dados e definir política/contrato | Responsável de privacidade, antes do lançamento comercial |
| D13 | Preço e billing | Piloto assistido; hipótese por organização/unidade/usuário | Negócio, após evidência de uso |
| D14 | Tolerância de contagem | Zero para itens discretos críticos; demais por política validada | Gestor, antes do inventário |
| D15 | Carga e recuperação | Envelope e metas deste documento como ponto de partida | Engenharia e negócio, antes da homologação |
| D16 | Framework e dependências | React + Vite + Supabase, versões estáveis verificadas ao iniciar | Engenharia, antes de bootstrap |

Essas decisões orientam o refinamento; não autorizam implementação automaticamente. Próxima entrega de projeto, quando solicitada: validar decisões críticas, elaborar protótipo de tarefas e transformar histórias M em especificações finais de API, migrações e testes.

## 30. Fontes e rastreabilidade

### 30.1 Fontes consultadas

Consulta em 17/11/2026. Regras de produto, estimativas e métricas de piloto são propostas deste briefing, não conclusões extraídas das fontes.

- [Flow — repositório](https://github.com/MarVinRant/Flow), [README](https://github.com/MarVinRant/Flow/blob/main/README.md), [App.tsx](https://github.com/MarVinRant/Flow/blob/main/src/App.tsx), [integração de domínio](https://github.com/MarVinRant/Flow/blob/main/src/lib/barflow.ts) e [estilos](https://github.com/MarVinRant/Flow/blob/main/src/styles.css): referência funcional e identificação do território visual a substituir.
- [Deploy de referência](https://bar-flow-flow.vercel.app): fornecido pelo usuário, acesso não concluído; não foi usado como evidência de comportamento publicado.
- [React — criação de aplicações](https://react.dev/learn/creating-a-react-app) e [Vite — guia](https://vite.dev/guide/): opções e limites da camada de frontend.
- [Supabase — changelog](https://supabase.com/changelog) e [exposição explícita de tabelas](https://supabase.com/changelog/45329-breaking-change-tables-not-exposed-to-data-and-graphql-api-automatically): atualidade da API e grants.
- [Supabase — Row Level Security](https://supabase.com/docs/guides/database/postgres/row-level-security), [funções](https://supabase.com/docs/guides/database/functions) e [Storage](https://supabase.com/docs/guides/storage/security/access-control): autorização e superfícies privilegiadas.
- [PostgreSQL — explicit locking](https://www.postgresql.org/docs/current/explicit-locking.html): fundamento para concorrência e deadlocks; a versão efetiva do banco será confirmada no provisionamento.
- [W3C — WCAG 2.2 quick reference](https://www.w3.org/WAI/WCAG22/quickref/): critérios de acessibilidade.
- [MDN — PWA offline/background](https://developer.mozilla.org/en-US/docs/Web/Progressive_web_apps/Guides/Offline_and_background_operation): capacidades e limites de execução offline.

### 30.2 Cobertura dos 23 requisitos solicitados

| Requisito | Seções |
|---|---|
| 1. Nome e posicionamento | 1 |
| 2. Problema e hipóteses | 3 |
| 3. Personas detalhadas | 4 |
| 4. Casos de uso das seis funções | 5, 9, 17 |
| 5. MVP e versão completa | 6, 21.5, 27, 28 |
| 6. Módulos, telas e fluxos | 8, 9 |
| 7. Modelo de dados completo | 21 |
| 8. Regras de estoque | 10 |
| 9. Compras, fornecedores, cotações e recebimento | 11 |
| 10. Inventário e acerto por evento | 12 |
| 11. Lotes, validade e rastreabilidade | 13 |
| 12. Unidades e conversões | 14 |
| 13. Kits/fichas sem catálogo de drinks | 15 |
| 14. Ativos não consumíveis | 16 |
| 15. Multiunidade, depósitos e permissões | 17 |
| 16. Relatórios, indicadores e dashboard | 18 |
| 17. CSV, barcode e PWA/offline | 24 |
| 18. Auth, autorização, tenant e segurança | 17, 23 |
| 19. React + Vite e Supabase | 20 |
| 20. Schema SQL e RLS | 21, 22, 23 |
| 21. Dados de demonstração/teste | 25 |
| 22. Testes funcionais, carga e segurança | 26 |
| 23. Roadmap, aceite, riscos e pendências | 27, 28, 29 |
| Design próprio, mobile e acessibilidade | 19 |
| Obrigatório, importante depois, opcional e fora | 6, 28 |

### 30.3 Conferência desta entrega

Documento revisado quanto à presença dos 23 requisitos, às 30 seções, à estrutura das tabelas e ao fechamento dos blocos SQL ilustrativos. Backlog com 58 IDs únicos, todas as dependências existentes e sem ciclos; as 44 histórias M dependem somente de outras histórias M. As 10 histórias I e 4 O estão identificadas separadamente. Contrastes básicos da paleta foram calculados. Essas verificações avaliam o planejamento; testes de aplicativo, migrações, RLS instalada e inspeção de telas do produto serão atividades da implementação futura.
