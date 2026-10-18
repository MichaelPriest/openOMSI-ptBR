# Empresa Virtual — pacote instalável para openOMSI

Plugin Lua independente: carreira, XP/pontuação, cargos, cadastro local de motoristas,
despacho de viagens pelo host e sincronização LAN quando a API necessária estiver presente.

## Instalação

1. Feche o openOMSI.
2. Na pasta de conteúdo que o openOMSI usa, crie `plugins/empresa_virtual/`.
3. Copie **todos** os arquivos deste diretório para essa pasta. O resultado deve conter
   `main.lua` e `compat.lua` lado a lado.
4. Inicie o jogo e confira `game.log`; procure por `Empresa Virtual compat`.
5. Configure as opções do plugin na interface de configurações do openOMSI.

Não substitua arquivos do jogo e não instale dentro de `crates/` ou da pasta de código-fonte.
A versão do plugin deve ser instalada igualmente no host e nos clientes para sincronização.

## Diagnóstico

- `API incompativel ou incompleta`: o plugin lista as capacidades obrigatórias ausentes no log e
  não inicia; isso evita erros em cascata e não significa que essa versão esteja suportada.
- `OMSI_NO_PLUGINS=1`: desativa todos os plugins, incluindo Lua.
- Sem multiplayer: confirme que a sessão LAN está ativa e que `lan.active`, `lan.send` e
  `json.encode/decode` existem na build usada.
- Dados da carreira/eventos são locais. Não há portal, servidor, banco online ou serviço pago.
- Os registros e cargos não são anti-cheat: o protocolo LAN não autentica identidades e o cadastro
  é indexado por nome apresentado na sessão.

## Compatibilidade verificada

A versão de referência do código é a API documentada do openOMSI **v0.3.37**
(`docs/PLUGINS.md` e `docs/plugin-api.json`). Neste repositório, a implementação foi
inspecionada estaticamente, mas ainda não foi executada em cada binário oficial. Portanto,
**nenhuma versão do jogo está marcada como runtime-testada por este pacote**. A camada
`compat.lua` faz detecção de capacidades; ela não presume que números de versão impliquem
compatibilidade nem cria substitutos para APIs não confirmadas.

Para homologar uma versão: instalar em cópia separada, verificar inicialização no `game.log`,
abrir opções, verificar carreira/persistência, fazer uma viagem com paradas, testar F4/F5/F7,
e testar host + cliente numa sessão LAN. Registre versão exata, sistema operacional e resultado.
