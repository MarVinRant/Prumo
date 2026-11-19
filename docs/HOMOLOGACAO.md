# Homologação PRUMO

## Acesso

1. Abra [https://prumo-stock-hml.marcosranti.workers.dev](https://prumo-stock-hml.marcosranti.workers.dev).
2. Crie uma conta com e-mail de teste controlado e confirme o e-mail se o projeto exigir SMTP.
3. O primeiro acesso cria a organização sintética `Operação Farol`, o Bar principal, o Depósito central, um item e um lote.

## Roteiro integrado

1. Em Movimentar, registre recebimento, consumo, perda e transferência; atualize Estoque após cada ação.
2. Exporte CSV e confirme que fórmulas não são executadas ao abrir em planilha.
3. Em Compras, crie uma solicitação, aprove, emita o pedido e registre um recebimento parcial com lote; confirme que ela reaparece após refresh.
4. Em Eventos, crie um evento com período válido, reserve material pela seção Reserva FEFO e libere a reserva; confirme que a quantidade disponível é restaurada sem baixar o físico.
5. Para o ciclo completo, avance o evento por separação, expedição, operação e acerto. O despacho cria um manifesto por lote; no acerto, classifique cada diferença como retornada, consumida, perda, avariada ou não localizada e obtenha aprovação gerencial antes de fechar. Avaria deve permanecer física em posição `damaged`, enquanto perda baixa o físico.
6. Em Análises, exporte o CSV e confirme que fórmulas não são executadas ao abrir em planilha.
7. Verifique que logout/login preserva os dados e que rotas profundas carregam no refresh. Antes de aprovar compras, fechar/reabrir eventos, cadastrar ativos, aprovar contagens ou consultar custos, eleve a sessão para `aal2` no painel MFA.

Reposição operacional, testes autenticados e fechamento completo com múltiplos lotes ainda estão marcados como parciais em `IMPLEMENTATION-STATUS.md`; não trate a reserva FEFO isolada como entrega desses ciclos.

## Registro de problemas

Inclua data/hora, papel, tenant sintético, rota, passos, resultado esperado/real e identificador do documento. Nunca inclua tokens, senhas ou dados de operação real.
