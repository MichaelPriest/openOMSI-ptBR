# Empresa Virtual — pacote instalável para openOMSI

Plugin Lua independente com carreira, XP/pontuação, cargos, cadastro de motoristas, despacho e sincronização multiplayer quando a API de rede estiver disponível.

## Dois modos de operação

### Solo/offline
- Não exige internet, portal, conta, servidor ou banco de dados online.
- Carreira, pontuação, cargos, eventos e configurações ficam no armazenamento local do jogo.
- Cadastro e funcionalidades locais continuam disponíveis; despacho remoto e sincronização com outros computadores não funcionam sem multiplayer.
- Se a build não oferecer API LAN completa, o plugin registra modo solo/offline e não inventa jogadores nem simula entrega de mensagens.

### Multiplayer online/LAN
- Com API LAN suportada pela build, o plugin pode trocar eventos, perfis e despachos pela sessão do próprio jogo. O despacho automático também exige a API nativa de início de escala; se ela faltar, o plugin não finge que iniciou a viagem.
- Todos os participantes devem instalar a mesma versão do plugin.
- É necessário suporte real à sessão LAN, envio de mensagens e JSON. Não há servidor externo, portal ou serviço pago.
- O modo multiplayer só é considerado disponível quando essas capacidades são detectadas; isso ainda precisa ser validado em runtime em cada versão.

## Instalação
1. Feche o openOMSI.
2. Na raiz de conteúdo reconhecida pelo jogo, crie `plugins/empresa_virtual/`.
3. Copie todos os arquivos deste diretório para essa pasta. `main.lua` e `compat.lua` devem ficar lado a lado.
4. Inicie o jogo e confira `game.log`; procure `Empresa Virtual compat` e o modo detectado.
5. Confira o diagnóstico em `game.log`. O painel clicável e as configurações editáveis dependem das APIs visuais e de configuração disponíveis nessa build; sem elas, o plugin usa padrões locais e mensagens na tela.

Não substitua arquivos do jogo nem instale dentro de `crates/`.

## Ideias incorporadas dos projetos relacionados

- **OMSI-Compatible-Runtime:** detecção por capacidade, compatibilidade em camadas e diagnóstico explícito por recurso, sem presumir que uma API existe em todas as versões.
- **OMSI-NavBR-Multiplayer:** painel de operação no jogo, botões para motoristas/despacho/status/salvamento/configurações e atalhos editáveis nas configurações nativas do plugin. Os atalhos padrão usam combinações Ctrl+Alt; a rotina consulta os bindings do jogo quando a API existe e evita registrar um conflito exato. Isso não garante que não haja conflito com todos os mods externos.
- **Agente de Operações:** regras locais configuráveis para segurança, pontualidade, pontuação, promoções e despacho. O núcleo não depende de IA externa nem de serviço pago.

## Diagnóstico
- `modo=solo-offline`: carreira local habilitada; multiplayer não confirmado pela API.
- O painel principal inclui os botões `Carreira`, `Motoristas`, `Despachar`, `Status`, `Salvar` e `Configurar`. O painel `Carreira` mostra XP, patente, progresso da promoção seguinte, pontuação, paradas concluídas e atividade recente. A disponibilidade visual depende de `omsi.ui.set` e do suporte da versão.
- Se a API nativa de atalhos não existir, o plugin não captura teclas F por conta própria; use os botões do painel quando a API visual existir. Quando a API existe, F4–F7 são registrados somente após consulta aos bindings expostos pela build.
- Os atalhos padrão agora são `F4` (motoristas), `F5` (despacho), `F6` (salvar) e `F7` (status), para evitar conflitos observados entre `Ctrl+Alt+M` e `Ctrl+M`. As teclas F só são registradas se a API de bindings não indicar conflito; se já estiverem ocupadas, a ação fica sem atalho e o motivo é registrado/avisado. Os quatro valores antigos `Ctrl+Alt+KeyM/D/P/S` são migrados para os novos padrões. Os atalhos podem ser alterados nas configurações. A verificação só enxerga bindings expostos pelo jogo; não garante detectar todos os mods externos.
- `painel nativo de configurações`: se ausente, os valores padrão são usados; a configuração editável por interface ainda depende de suporte da build.
- A documentação base de `docs/PLUGINS.md` descreve `omsi.info`, `omsi.on`, `omsi.every`, `omsi.data` e `omsi.message`, mas não documenta painéis customizados, atalhos com modificadores ou início programático de escala. Nessas builds, carreira e mensagens podem funcionar, enquanto painel clicável, atalhos Ctrl+Alt, despacho automático e multiplayer ficam indisponíveis até a build expor as APIs correspondentes.
- O evento documentado `duty` e a mudança `next_stop` são usados como compatibilidade para registrar escala e progressão quando eventos mais específicos não existem. Os eventos equivalentes `duty`/`duty_start` e `next_stop`/`stop_depart` têm deduplicação temporizada para reduzir XP e registros duplicados entre versões.
- Falhas de API opcionais não devem impedir a carreira local.
- `OMSI_NO_PLUGINS=1` desativa plugins Lua.
- Para multiplayer, confirme `lan.active`, `lan.me`, `lan.players`, `lan.send`, `json.encode/decode` e uma sessão ativa.
- Progresso offline permanece no computador local e não é automaticamente fundido com dados de outros jogadores.

## Compatibilidade verificada
Referência de desenvolvimento: API documentada do openOMSI v0.3.37 (`docs/PLUGINS.md` e `docs/plugin-api.json`). A detecção não prova compatibilidade em execução. Nenhuma versão está marcada como testada dentro do jogo.

Homologação por versão: verificar inicialização/log, configurações, carreira e persistência offline, viagem com paradas, F4/F5/F7 e sessão multiplayer host + cliente. Registrar versão exata, sistema operacional e resultado.
