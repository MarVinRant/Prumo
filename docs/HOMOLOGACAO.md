# Homologação PRUMO

## Acesso

1. Abra [https://prumo-stock-hml.marcosranti.workers.dev](https://prumo-stock-hml.marcosranti.workers.dev).
2. Crie uma conta com e-mail de teste controlado e confirme o e-mail se o projeto exigir SMTP.
3. O primeiro acesso cria a organização sintética `Operação Farol`, o Bar principal, o Depósito central, um item e um lote.

## Roteiro integrado

1. Em Movimentar, registre recebimento, consumo, perda e transferência; atualize Estoque após cada ação. Em uma repetição pós-timeout, reuse a mesma chave/payload e confirme que o ledger não duplica; mude o payload mantendo a chave e confirme o conflito.
2. Exporte CSV e confirme que fórmulas não são executadas ao abrir em planilha.
3. Em Compras, crie uma solicitação, repita o envio após timeout com o mesmo payload e confirme que não duplica; aprove, emita o pedido e registre um recebimento parcial com lote separando utilizável, quarentena e rejeitada (por exemplo, 60/6/6); confirme após refresh que só a parcela utilizável aparece como disponível, a quarentena fica física porém bloqueada e a rejeitada permanece no saldo a receber.
4. Em Eventos, crie um evento com período válido, reserve material pela seção Reserva FEFO e libere a reserva; confirme que a quantidade disponível é restaurada sem baixar o físico. Simule uma repetição da mesma reserva após timeout usando a mesma chave/payload e confirme que não há segunda reserva; altere o payload mantendo a chave e confirme o conflito.
5. Para o ciclo completo, avance o evento por separação, expedição, operação e acerto. O despacho cria um manifesto por lote; no acerto, classifique cada diferença como retornada, consumida, perda, avariada ou não localizada e obtenha aprovação gerencial antes de fechar. Avaria deve permanecer física em posição `damaged`, enquanto perda baixa o físico. Na reposição durante operação, repita a mesma chamada após timeout e confirme que a reserva não duplica.
6. Em Análises, exporte o CSV e confirme que fórmulas não são executadas ao abrir em planilha.
7. Verifique que logout/login preserva os dados e que rotas profundas carregam no refresh. Antes de aprovar compras, fechar/reabrir eventos, cadastrar ativos, aprovar contagens ou consultar custos, eleve a sessão para `aal2` no painel MFA.
8. Na fila de alertas da tela Hoje, reconheça uma ocorrência com qualquer papel autorizado e confirme que ela permanece aberta; com uma sessão gerencial `aal2`, informe a causa corrigida e resolva-a. Atualizar a página não deve reabrir a mesma ocorrência enquanto a causa não gerar um novo ciclo.
9. Em Compras, use uma solicitação sintética para testar os dois caminhos: rejeite-a com motivo e confirme a auditoria/status; depois crie outra e execute aprovação, pedido, recebimento parcial e devolução vinculada ao recebimento. Em caso de timeout na devolução, repita com a mesma chave/payload e confirme que o documento não duplica; mude o payload mantendo a chave e confirme o conflito.
10. Em Movimentar, selecione um SKU com base `g` ou `ml` e confirme que `kg`/`L` normaliza para a unidade base; tente uma combinação incompatível e confirme a rejeição do servidor.
11. Em Análises, confirme que um operador vê apenas “Custos protegidos”. Com uma conta financeira `aal2`, solicite um ajuste de valor, repita a solicitação após timeout com a mesma chave/payload e confirme que não duplica; altere o payload mantendo a chave e confirme o conflito. Tente aprová-lo com o mesmo usuário (deve falhar) e conclua a aprovação com outro usuário financeiro.
12. Em Administração, registre uma contagem cega, repita após timeout com o mesmo payload e confirme que não cria uma segunda contagem; depois tente arquivar um local com saldo ou um material com reserva; o servidor deve bloquear. Após zerar as pendências com dados sintéticos, arquive e reative o registro sem apagar o histórico.
13. Tente receber acima do saldo físico ainda não conferido e repita a mesma conferência com a mesma chave idempotente; a primeira deve ser bloqueada e a repetição deve retornar o mesmo recebimento sem duplicar estoque.
14. Com um recebimento em quarentena, confirme que o saldo disponível permanece zero; com uma sessão gerencial `aal2`, libere a quantidade e confirme que ela aparece como utilizável sem alterar o físico total. Tente liberar uma posição vencida e confirme o bloqueio.
15. Registre uma entrega somente rejeitada e confirme que o pedido permanece parcial, com saldo a receber para reposição.
16. Em Ativos, cadastre um equipamento individualizado e repita o cadastro após uma falha recuperável com a mesma chave; confirme que o mesmo patrimônio não é duplicado. Expedir e retornar o ativo devem preservar uma única custódia aberta; mude o payload mantendo a chave e confirme `idempotency_payload_conflict`.
17. Em Análises, filtre o extrato por tipo (por exemplo, perda) e por período; confirme que consumo, perda, transferência e retorno aparecem como direções distintas, que lote/local/documento são preservados e que nenhum custo é exibido para operador. Exporte o extrato filtrado e valide a neutralização de fórmulas.

Reposição operacional, testes autenticados e fechamento completo com múltiplos lotes ainda estão marcados como parciais em `IMPLEMENTATION-STATUS.md`; não trate a reserva FEFO isolada como entrega desses ciclos.

## Registro de problemas

Inclua data/hora, papel, tenant sintético, rota, passos, resultado esperado/real e identificador do documento. Nunca inclua tokens, senhas ou dados de operação real.
