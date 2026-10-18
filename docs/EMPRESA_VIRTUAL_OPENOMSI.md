# Empresa Virtual openOMSI — arquitetura local

## Decisões confirmadas
- Sem portal web e sem banco de dados online.
- Multiplayer nativo do openOMSI; conexão externa por VPN privada (por exemplo, Tailscale ou Radmin VPN).
- Modelo de IA instalado no computador do host, inicialmente através da API local do Ollama.
- Cada computador mantém registros locais; o host atribui a sequência oficial dos eventos da sessão.
- O plugin nunca executa ações de jogo recebidas do modelo. A IA produz recomendações em texto; automatização decisória fica para uma fase posterior com regras determinísticas.

## API pública verificada
Base de referência: tag oficial `v0.3.37`, `docs/PLUGINS.md` e `docs/plugin-api.json`.

O plugin usa somente interfaces documentadas: `omsi.plugin.settings`, `omsi.lan.me/active/send`, eventos `duty_start`, `stop_arrive`, `stop_depart`, `crash`, `lan_message`, `omsi.storage`, `omsi.json`, `omsi.send`, `omsi.plugin.read`, `omsi.ui.toast` e `omsi.game.notify`. O envio UDP do jogo é apenas para `127.0.0.1`; ele não é usado para comunicar entre jogadores.

O canal multiplayer tem limite documentado de 120 caracteres por mensagem e cerca de 10 mensagens/segundo. O plugin valida o tamanho e não envia o caractere `|`. O host recebe os eventos dos clientes, atribui sequência e retransmite; os clientes aceitam apenas eventos numerados pelo host. O formato é compacto para manter mensagens pequenas. A sincronização é por eventos, não replicação de todos os arquivos.

## Arquivos e responsabilidades
- `plugins/empresa_virtual/main.lua`: coleta eventos, salva até 300 eventos recentes por instalação, sincroniza eventos da sessão e envia estado periódico ao agente local apenas no host.
- `tools/empresa_virtual_ai.py`: processo Python local; recebe UDP de loopback, chama o Ollama em loopback e grava uma recomendação em `agent-inbox.json`, na pasta do plugin.
- `agent-inbox.json`: arquivo de troca local host-agente. Não deve ser compartilhado nem conter segredos.
- `omsi.storage`: armazenamento nativo por instalação para eventos e sequência.

## Instalação inicial
1. Use uma build oficial de openOMSI que contenha a API da tag alvo. O branch deste repositório ainda não incorpora o motor oficial completo; não é uma build pronta do simulador 0.3.37.
2. Copie `plugins/empresa_virtual/main.lua` para `<raiz de conteúdo>/plugins/empresa_virtual/main.lua`.
3. No host, instale Python 3.10+ e Ollama; baixe um modelo local adequado, por exemplo `ollama pull qwen2.5:3b`.
4. Execute o agente com `python tools/empresa_virtual_ai.py --plugin-dir "CAMINHO\para\plugins\empresa_virtual"`. O Ollama deve estar ativo no mesmo computador.
5. Nas configurações do plugin, habilite a Empresa Virtual. Marque "Este computador hospeda a IA local" apenas no host. F7 mostra o resumo; F6 salva os registros.
6. Conecte os jogadores à mesma sessão multiplayer através de uma VPN privada. Todos precisam instalar o mesmo plugin.

## Limitações conhecidas / próxima fase
- A API multiplayer expõe nomes, posição e estado básico de jogadores; não garante que todos tenham mapas, ônibus ou arquivos idênticos.
- Mensagens de 120 caracteres não são adequadas para replicar arquivos grandes. O protocolo sincroniza eventos compactos.
- A sequência do host evita duplicação simples, mas não resolve reconciliação após quedas, host migration, adulteração deliberada nem conflitos de arquivos. Exportação/importação e snapshot/recuperação precisam ser implementados antes de chamar a persistência de resiliente.
- O plugin não pode receber UDP diretamente pela API; o agente usa um arquivo de entrada local para devolver recomendações ao plugin. Testar permissões e comportamento real de leitura do arquivo no binário-alvo ainda é obrigatório.
- O plugin e o agente não foram executados no simulador nesta etapa. Não declarar a funcionalidade validada em jogo até realizar teste multiplayer real.
- Próximas entregas: painel nativo de operações, protocolo de sincronização com checksum/ack/replay, cadastro local de empresa/cargos/frota, motor determinístico de escalas, integração IA com timeout e testes de falha/offline.
