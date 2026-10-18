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
- Carreira local persistente: XP por parada concluída, níveis Aprendiz/Motorista/Motorista Sênior/Instrutor com limiares editáveis, nota de 0 a 100, recompensa por parada pontual e descontos por atraso, excesso de velocidade e colisão.
- Despacho inicial de linha/viagem pelo host com F5: linha e tabela padrão configuráveis, aceitação automática opcional nos clientes e nota mínima para aceitar.
- Painel nativo de motoristas com F4: mostra o motorista local, carreira/nota e jogadores multiplayer com linha, viagem e velocidade anunciadas pela sessão.

A carreira agora calcula XP por parada de saída registada, promove automaticamente conforme os limiares de XP e mantém uma nota local de 0 a 100. A nota considera pontualidade, alertas de velocidade e colisões com os pesos configurados. A API não oferece aqui uma métrica confiável de satisfação dos passageiros; por isso, o peso de qualidade do serviço permanece configurável, mas ainda não entra no cálculo. Não há salário, dinheiro ou rebaixamento automático.

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
4. F4 abre/fecha o painel de motoristas; F5: o host despacha a linha/viagem configurada; clientes podem desativar a aceitação automática nas opções. F7 mostra o status/carreira; F6 salva os registros locais.

## Limitações e próximos passos
- O código foi escrito contra a documentação pública; ainda precisa de execução real na versão-alvo para validar assinaturas e renderização de configurações.
- A sincronização atual inclui um identificador local por evento e evita duplicar no cliente o evento que volta do host. Ainda não tem ACK/retry, transferência de snapshot, migração de host ou reconciliação robusta após desconexão.
- A API LAN não garante integridade nem autenticidade dos clientes; não use os registros como anti-cheat forte. A deduplicação reduz duplicatas acidentais, mas não substitui ACK, replay e validação anti-fraude.
- A carreira e a nota são locais por instalação e ainda não são perfil global multiplayer. O painel de motoristas usa os dados da sessão que o jogo publica, não um cadastro persistente de empregados. O despacho F5 envia um comando simples para iniciar a mesma linha/tabela em clientes compatíveis. O host não substitui sua própria escala ativa; clientes que já estejam em uma escala recusam o novo despacho. Ainda não reserva veículos nem verifica conflitos entre motoristas, e não garante entrega se alguém estiver desconectado. A nota mínima pode impedir despacho/aceitação, mas não controla outras escalas iniciadas pelo menu do jogo. Próxima fase: cadastro de motoristas/cargos mais completo, escalas com disponibilidade/conflitos, sincronização com confirmação/replay e exportação/backup.
- O motor de regras não usa serviços pagos, conexão à internet ou modelo de IA. A arquitetura poderá aceitar uma IA opcional no futuro, sem torná-la necessária para jogar.
