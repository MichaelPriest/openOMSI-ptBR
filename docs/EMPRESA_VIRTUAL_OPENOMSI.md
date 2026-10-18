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
- Despacho de linha/viagem pelo host com F5: valida e inicia primeiro a escala local do host, depois envia a ordem aos clientes conectados; cada cliente responde aceitação ou recusa/falha com identificador de despacho, e o host apresenta o resultado das confirmações recebidas. A aceitação automática é opcional e a nota mínima continua configurável.
- Painel nativo de motoristas com F4: mostra o motorista local, cargo, carreira/nota e jogadores multiplayer com linha, viagem e velocidade anunciadas pela sessão.
- Cargos locais configuráveis (Aprendiz, Motorista, Motorista Sênior, Instrutor, Despachante, Supervisor e Administrador); o host grava os cargos anunciados pelos clientes num registro persistente indexado pelo nome apresentado na sessão.
- Disponibilidade observacional no painel F4: os clientes anunciam periodicamente cargo, linha/viagem e indicador de escala ativa; o host mantém o último estado recebido no cadastro local. O painel diferencia `EM SERVIÇO`, `DISPONÍVEL` e `SEM ATUALIZAÇÃO`; o último aparece quando não há perfil recente ou a atualização local ultrapassa 25 segundos. O temporizador de frescor é volátil e não trata dados persistidos antigos como presença atual.
- O host distribui aos clientes os perfis recebidos e o próprio perfil em mensagens compactas; cada instalação mantém uma cópia local do cadastro compartilhado, atualizada quando recebe as mensagens.

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
- A sincronização inclui identificador por evento, confirmação (ACK) do host, fila persistente no cliente e reenvio periódico limitado; eventos repetidos são deduplicados e eventos recebidos fora de ordem são aceitos sem descartar sequências anteriores. Ainda não tem transferência de snapshot, migração de host nem reconciliação completa de eventos enquanto o cliente esteve desconectado. O protocolo depende da entrega LAN do jogo e não é uma garantia transacional.
- A API LAN não garante integridade nem autenticidade dos clientes; não use os registros como anti-cheat forte. A deduplicação reduz duplicatas acidentais, mas não substitui ACK, replay e validação anti-fraude.
- A carreira e a nota continuam locais por instalação, não são perfil global multiplayer. O host mantém um cadastro persistente simples indexado pelo nome apresentado na sessão; nomes podem mudar ou se repetir, e cargos enviados pelo cliente não provam autorização. O cadastro compartilhado é distribuído em mensagens compactas, não como snapshot transacional; clientes que entram depois ou perdem mensagens podem ficar sem alguns perfis até novas atualizações. A disponibilidade é observacional: os perfis são anunciados nominalmente a cada 10 segundos e o painel marca `SEM ATUALIZAÇÃO` após 25 segundos sem receber atualização local. Isso não confirma uma desconexão, não reserva escala e não elimina estados desatualizados causados por perda de mensagens.
- O despacho F5 usa um identificador para associar as respostas dos clientes à ordem emitida. Clientes respondem quando aceitam, estão ocupados, não atingem a nota mínima ou estão com aceitação automática desativada. O host conta cada resposta uma vez por ID de jogador e informa o resultado recebido. Se faltarem respostas, o host encerra o acompanhamento após aproximadamente 60 segundos de tempo local do plugin e informa quantos motoristas aceitaram, recusaram/falharam ou não responderam. O timeout encerra apenas o acompanhamento; não cancela a escala já iniciada no host nem reverte escalas que os clientes iniciaram. Mensagens perdidas, desconexões ou falhas antes da resposta ainda podem causar divergência; não há reserva de veículos. O host inicia sua própria escala antes de transmitir, portanto uma falha de envio pode deixar a viagem ativa apenas no host.
- Ainda faltam identidade persistente menos ambígua, atribuição de cargos autorizada pelo host, sincronização de snapshot para quem entra depois, detecção robusta de desconexões e reconciliação do histórico após desconexão. A API LAN não garante integridade nem autenticidade dos clientes; não use os registros como anti-cheat forte.
- O motor de regras não usa serviços pagos, conexão à internet ou modelo de IA. A arquitetura poderá aceitar uma IA opcional no futuro, sem torná-la necessária para jogar.
