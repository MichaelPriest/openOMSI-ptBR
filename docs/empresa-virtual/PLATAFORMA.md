# Empresa Virtual — arquitetura da plataforma

## Objetivo
Plataforma de carreira e gestão de empresas virtuais para OMSI 2 e openOMSI, com portal web, planos gratuito e pagos, dois plugins específicos e modelo de dados compartilhado. O portal é a fonte oficial de contas, empresas, escalas, progressão, assinaturas e permissões.

## Componentes
1. **Portal web:** apresentação pública, cadastro/login, dashboard, perfil do motorista, empresas/equipes, carreira, viagens, conquistas, rankings, downloads, loja, suporte e assinatura.
2. **API/backend:** autenticação, autorização por empresa, validação de eventos, regras de carreira, sincronização idempotente, auditoria, rate limits e integração Stripe.
3. **Plugin openOMSI:** plugin Lua empacotado como OOP quando compatível com a versão-alvo; usa APIs documentadas para painéis, cliques e telemetria disponíveis. Detecta capacidades antes de usar APIs recentes.
4. **Plugin OMSI 2 clássico:** build separado para runtime clássico, normalmente DLL nativa x86 e manifesto OPL quando exigido. Usa callbacks, variáveis e triggers documentados. Interface gráfica avançada pode exigir overlay ou painel próprio e precisa de validação no jogo real.
5. **Contrato compartilhado:** esquema JSON versionado para eventos, sessão, configuração, capacidades e respostas da API.

## Regra de compatibilidade
Não presumir que os dois jogos ofereçam as mesmas APIs. Cada plugin declara plataforma, versão, protocolo e capacidades reais. Se uma função não existir no runtime, mostrar como indisponível — nunca simular sucesso.

## Integração online e offline
- Offline: condução, painel local e armazenamento temporário; fila de eventos sincroniza quando a rede voltar.
- Online: token de dispositivo curto e revogável, TLS, limites e idempotência.
- Nenhuma chave secreta Stripe, service-role ou segredo de backend embutido em Lua/DLL.
- Eventos validados no servidor por duração, distância, sequência, velocidades e duplicatas; pontuação suspeita fica pendente.
- Coletar somente dados necessários, permitir revogar dispositivos e definir retenção.

## Stripe e permissões
Stripe Checkout para assinatura e Customer Portal para faturas, cartão e cancelamento. Webhooks assinados atualizam a assinatura. Redirecionamento de sucesso do navegador não concede acesso por si só. O backend valida assinatura do webhook e aplica eventos de forma idempotente.

Estados mínimos: free, trialing, active, past_due, cancel_at_period_end, canceled, incomplete e unpaid. Regras de tolerância e downgrade devem ser explícitas. Preservar carreira e dados após expiração; restringir apenas funções premium.

## Segurança e operação
- RLS/autorização por usuário e empresa; cargos de motorista, despachante, gerente, proprietário e administrador.
- Auditoria de escalas, equipe, pagamentos e ações administrativas.
- Proteção contra replay, duplicação e alteração de eventos.
- Segredos somente em variáveis de ambiente do servidor.
- Testes para webhook inválido/duplicado, assinatura cancelada, perda de rede, token revogado e acesso cruzado entre empresas.
- Backups, logs sem tokens e plano de incidentes.

## Etapas
1. Contrato do produto, matriz funcional, identidade visual e contrato JSON.
2. Portal MVP com autenticação, dashboard e carreira persistida.
3. API, banco e políticas de acesso; testes de autorização.
4. Checkout/Customer Portal em modo de teste e webhooks idempotentes.
5. Plugin openOMSI com telas semitransparentes nativas e vinculação de conta.
6. Plugin OMSI 2 clássico com build x86 e adaptador validado em runtime.
7. Sincronização de viagens, pontuação, conquistas, equipes e telemetria.
8. QA de compatibilidade, segurança, acessibilidade e desempenho.

## Limites
A plataforma deve se apresentar como integração comunitária independente, sem sugerir parceria oficial. Não redistribuir arquivos do jogo, assets proprietários ou marcas oficiais sem permissão. Ícones e arte devem ser originais ou usados conforme licença.