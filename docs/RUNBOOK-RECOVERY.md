# Runbook de recuperação PRUMO

## Escopo

Este procedimento é exclusivo para a homologação do PRUMO. Ele não apaga dados e não deve ser aplicado ao Flow ou a operações reais. A fonte transacional é o projeto Supabase `azuomlmqdnyvdgnhypao`; o Worker Cloudflare serve apenas os assets da SPA.

## Diagnóstico antes de qualquer correção

1. Preserve o identificador do commit, horário, tenant sintético e usuário que observou o incidente.
2. Com uma conta owner/manager/auditor em sessão `aal2`, execute o RPC `reconcile_inventory()` no SQL editor ou por uma ferramenta interna autorizada.
3. Registre cada linha retornada: `stock_position_invariant`, `purchase_order_quantity_invariant`, `asset_open_custody_duplicate` e `expired_usable_position`.
4. Não corrija saldo editando tabelas diretamente. Use comando compensatório idempotente e registre motivo; documentos efetivados são imutáveis.

## Falha de frontend ou Worker

1. Confirme `https://prumo-stock-hml.marcosranti.workers.dev` e as seis rotas profundas com `npm run smoke -- <url>`.
2. Se o Worker estiver indisponível, preserve o último commit/Version ID registrado em `docs/INFRAESTRUTURA.md` e publique somente após `npm test`.
3. O banco continua íntegro mesmo que o Worker esteja fora; não substitua a aplicação por dados em memória.

## Recuperação de dados sintéticos

1. Não execute `TRUNCATE`, `DROP`, `DELETE` amplo ou reset do projeto.
2. Para repetir o roteiro, use uma nova organização sintética pelo bootstrap ou um tenant de teste isolado.
3. Se um fixture precisar ser removido, confirme explicitamente o `tenant_id` sintético, faça exportação/backup disponível no projeto e remova apenas por migração revisável.
4. Após qualquer compensação, rode `reconcile_inventory()` novamente e anexe o resultado ao incidente.

## Dependências do provedor ainda pendentes

Backups gerenciados e restauração point-in-time dependem da configuração e do plano do Supabase. O ensaio de restauração real não foi inventado; permanece pendente até haver uma janela e um projeto de restauração isolado. SMTP, proteção contra senhas vazadas e testes de concorrência autenticados também continuam registrados em `docs/TEST-REPORT.md`.
