# Empresa Virtual — contrato de API e eventos

Documento inicial; endpoints e esquema precisam de implementação e testes antes de serem considerados estáveis.

## Identidade do cliente
Cada plugin envia plataforma (openomsi ou omsi2), versão do plugin, versão do protocolo, capacidades reais detectadas, device_id aleatório revogável e session_id por sessão. Não enviar segredos Stripe nem senhas do usuário.

## Endpoints propostos
- POST /v1/plugin/device/claim — vincular plugin à conta por código curto emitido no portal.
- POST /v1/plugin/session/start — iniciar sessão autenticada.
- POST /v1/plugin/events/batch — enviar eventos idempotentes.
- GET /v1/plugin/bootstrap — configuração e permissões mínimas.
- GET /v1/career/me — dados autorizados da carreira.
- POST /v1/trips/{trip_id}/finish — solicitar finalização após validação.
- POST /v1/billing/checkout — criar Checkout Session no servidor.
- POST /v1/billing/portal — criar sessão do Stripe Customer Portal.
- POST /v1/webhooks/stripe — receber eventos com assinatura validada sobre o corpo bruto.

## Envelope de evento
Campos necessários: event_id UUID, session_id UUID, sequence, occurred_at, platform, plugin_version, protocol_version, type e payload. O backend valida tamanho, timestamp, sequência e campos permitidos. Repetições do mesmo event_id não geram recompensa duplicada.

## Sincronização
- TLS obrigatório; limites por dispositivo, usuário e IP.
- Token de acesso curto e revogável; não armazenar senha no plugin.
- Fila local limitada, retentativa exponencial e idempotência.
- Eventos inválidos vão para quarentena e não alteram pontuação.
- Respostas informam versão de protocolo, IDs aceitos/rejeitados e motivos não sensíveis.

## Pagamentos e permissões
O servidor cria Checkout Session com price_id configurado no ambiente, nunca com preço enviado pelo cliente. Validar assinatura do webhook Stripe e registrar ID do evento Stripe para idempotência antes de aplicar alterações. Reprocessamentos devem ser seguros. Portal e plugins consultam permissões calculadas pelo backend, nunca a Stripe diretamente.

## Versionamento
Mudanças compatíveis incrementam versão menor; incompatíveis incrementam versão principal do protocolo. API informa versão mínima e recomendada do plugin. O plugin não executa código remoto arbitrário; artefatos são versionados, verificados e instalados conforme política explícita.