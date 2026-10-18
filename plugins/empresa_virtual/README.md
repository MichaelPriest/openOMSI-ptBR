# Empresa Virtual — pacote instalável para openOMSI

Plugin Lua independente com carreira, XP/pontuação, cargos, cadastro de motoristas, despacho e sincronização multiplayer quando a API de rede estiver disponível.

## Dois modos de operação

### Solo/offline
- Não exige internet, portal, conta, servidor ou banco de dados online.
- Carreira, pontuação, cargos, eventos e configurações ficam no armazenamento local do jogo.
- Cadastro e funcionalidades locais continuam disponíveis; despacho remoto e sincronização com outros computadores não funcionam sem multiplayer.
- Se a build não oferecer API LAN completa, o plugin registra modo solo/offline e não inventa jogadores nem simula entrega de mensagens.

### Multiplayer online/LAN
- Com API LAN suportada pela build, o plugin pode trocar eventos, perfis e despachos pela sessão do próprio jogo.
- Todos os participantes devem instalar a mesma versão do plugin.
- É necessário suporte real à sessão LAN, envio de mensagens e JSON. Não há servidor externo, portal ou serviço pago.
- O modo multiplayer só é considerado disponível quando essas capacidades são detectadas; isso ainda precisa ser validado em runtime em cada versão.

## Instalação
1. Feche o openOMSI.
2. Na raiz de conteúdo reconhecida pelo jogo, crie `plugins/empresa_virtual/`.
3. Copie todos os arquivos deste diretório para essa pasta. `main.lua` e `compat.lua` devem ficar lado a lado.
4. Inicie o jogo e confira `game.log`; procure `Empresa Virtual compat` e o modo detectado.
5. Se a build oferecer o painel nativo de configurações do plugin, configure as opções por ele. Em builds antigas sem essa API, o plugin usa os valores padrão e registra essa limitação no log.

Não substitua arquivos do jogo nem instale dentro de `crates/`.

## Ideias incorporadas dos projetos relacionados

- **OMSI-Compatible-Runtime:** detecção por capacidade, compatibilidade em camadas e diagnóstico explícito por recurso, sem presumir que uma API existe em todas as versões.
- **OMSI-NavBR-Multiplayer:** painel de operação, atalhos e fluxos de despacho inspirados na experiência de HUD/CCO. Os atalhos atuais F4/F5/F6/F7 ainda precisam de uma camada configurável com verificação de conflito; não são considerados livres em todas as instalações.
- **Agente de Operações:** regras locais configuráveis para segurança, pontualidade, pontuação, promoções e despacho. O núcleo não depende de IA externa nem de serviço pago.

## Diagnóstico
- `modo=solo-offline`: carreira local habilitada; multiplayer não confirmado pela API.
- `painel visual não disponível`: a build não oferece a API de painéis; os alertas tentam usar as mensagens nativas.
- `painel nativo de configurações`: se ausente, os valores padrão são usados; a configuração editável por interface ainda depende de suporte da build.
- Falhas de API opcionais não devem impedir a carreira local.
- `OMSI_NO_PLUGINS=1` desativa plugins Lua.
- Para multiplayer, confirme `lan.active`, `lan.me`, `lan.players`, `lan.send`, `json.encode/decode` e uma sessão ativa.
- Progresso offline permanece no computador local e não é automaticamente fundido com dados de outros jogadores.

## Compatibilidade verificada
Referência de desenvolvimento: API documentada do openOMSI v0.3.37 (`docs/PLUGINS.md` e `docs/plugin-api.json`). A detecção não prova compatibilidade em execução. Nenhuma versão está marcada como testada dentro do jogo.

Homologação por versão: verificar inicialização/log, configurações, carreira e persistência offline, viagem com paradas, F4/F5/F7 e sessão multiplayer host + cliente. Registrar versão exata, sistema operacional e resultado.
