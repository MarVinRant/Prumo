# Homologação PRUMO

## Acesso

1. Abra a URL do Worker Cloudflare após a publicação.
2. Crie uma conta com e-mail de teste controlado e confirme o e-mail se o projeto exigir SMTP.
3. O primeiro acesso cria a organização sintética `Operação Farol`, o Bar principal, o Depósito central, um item e um lote.

## Roteiro integrado

1. Em Movimentar, registre recebimento, consumo, perda e transferência; atualize Estoque após cada ação.
2. Exporte CSV e confirme que fórmulas não são executadas ao abrir em planilha.
3. Em Compras, crie uma solicitação; confirme que ela reaparece após refresh.
4. Em Eventos, crie um evento com período válido e confirme persistência.
5. Verifique que logout/login preserva os dados e que rotas profundas carregam no refresh.

Os ciclos completos de reserva, expedição, retorno, aprovação e fechamento só devem ser testados quando os itens correspondentes estiverem marcados como implementados em `IMPLEMENTATION-STATUS.md`.

## Registro de problemas

Inclua data/hora, papel, tenant sintético, rota, passos, resultado esperado/real e identificador do documento. Nunca inclua tokens, senhas ou dados de operação real.
