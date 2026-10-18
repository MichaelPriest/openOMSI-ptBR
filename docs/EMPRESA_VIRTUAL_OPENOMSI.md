# Empresa Virtual openOMSI — agente configurável por regras

## Decisões
- Sem portal web, sem banco de dados online e sem dependência obrigatória de IA/modelo local.
- O “Agente de Operações” começa como um motor de regras determinísticas configuráveis no painel de configurações nativo do openOMSI.
- Multiplayer nativo através de VPN privada. Cada instalação mantém os seus dados locais.
- O host pode ser configurado como autoridade dos registros de sessão; isto não equivale a um sistema anti-fraude ou a uma replicação transacional.

## Configurações incluídas
- Ativar/desativar a Empresa Virtual; nome da empresa; mostrar status; registrar eventos.
- Sincronização de eventos multiplayer e autoridade do host.
- Alertas de excesso de velocidade, tolerância, intervalo de repetição.
- Alertas de atraso, limiar normal e limiar crítico.
- Registrar/alertar colisões e valor de penalidade de referência.
- Pesos configuráveis para pontualidade, segurança e qualidade do serviço, além de pontuação mínima recomendada.

Os pesos de avaliação estão preparados para o sistema de carreira/avaliação que será implementado na próxima fase; por enquanto, não geram uma nota final nem promovem/rebaixam automaticamente um motorista. Penalidades são apenas informativas e não alteram a carreira ou dinheiro ainda.

## API pública usada
Referência: openOMSI oficial v0.3.37, `docs/PLUGINS.md` e `docs/plugin-api.json`.
- `omsi.plugin.settings` e evento `setting` para opções persistentes.
- `omsi.info`, `omsi.duty.get`, `omsi.bus.state`, `omsi.map.speed_limit` para observar o estado do jogo.
- Eventos `duty_start`, `stop_arrive`, `stop_depart`, `crash`, `lan_message`.
- `omsi.storage` para dados locais, `omsi.lan.me/active/send` para sessão multiplayer, `omsi.ui.toast` e `omsi.game.notify` para avisos.
- A documentação limita mensagens LAN a 120 caracteres e aproximadamente 10 por segundo; cada evento é compacto e pode não ser sincronizado se exceder o limite.
- UDP `omsi.send` e agente Ollama não são necessários para as regras locais.

## Instalação e operação
1. Instale a build do openOMSI que corresponde à API usada.
2. Copie `plugins/empresa_virtual/main.lua` para `plugins/empresa_virtual/main.lua` dentro da raiz de conteúdo reconhecida pelo jogo.
3. Abra as configurações do plugin no jogo e ajuste as regras. O host e os clientes precisam instalar a mesma versão do plugin.
4. F7 mostra o status; F6 salva os registros locais.

## Limitações e próximos passos
- O código foi escrito contra a documentação pública; ainda precisa de execução real na versão-alvo para validar assinaturas e renderização de configurações.
- A sincronização inicial não tem ACK/retry, transferência de snapshot, migração de host ou reconciliação robusta após desconexão.
- A API LAN não garante integridade nem autenticidade dos clientes; não use os registros como anti-cheat forte.
- Os pesos de avaliação e a pontuação mínima ainda não são aplicados a uma nota calculada. Próxima fase: cadastro local de empresa, cargos e motoristas; score de condução com métricas disponíveis; escala e despacho por regras; sincronização com confirmação, replay e exportação/backup.
- O motor de regras não usa serviços pagos, conexão à internet ou modelo de IA. A arquitetura poderá aceitar uma IA opcional no futuro, sem torná-la necessária para jogar.
