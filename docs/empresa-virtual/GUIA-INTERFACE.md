# Empresa Virtual — diretrizes de interface

## Direção visual
- Painel de operação de ônibus: azul-marinho/carvão, azul-ciano como acento, cinza claro para texto e âmbar/vermelho apenas para avisos.
- Painéis semitransparentes, com alvo inicial de 78–88% de opacidade para manter legibilidade; transparência configurável.
- Ícones de ônibus, volante, rota, relógio, pessoas, troféu, gráfico, engrenagem e nuvem. Preferir ícones já disponíveis no runtime quando permitido; no portal, usar ícones próprios/licenciados.
- Não copiar logotipos oficiais de OMSI nem apresentar o projeto como oficial.
- Tipografia legível em 720p e escalas variadas; evitar texto miúdo.
- Não cobrir velocímetro, espelhos, instrumentos essenciais ou avisos do simulador. Usuário escolhe posição, escala, opacidade e modo compacto.

## Telas dentro do jogo
### Painel rápido
Estado de conexão, conta vinculada, linha/viagem, próxima parada, atraso e velocidade somente quando fornecidos pelo runtime, progresso de carreira e acesso ao painel completo.

### Menu principal
Minha carreira; Viagens; Escalas/Despacho quando suportado; DriverOps; Conquistas; Equipe/Empresa; Sincronização e conta; Configurações; Ajuda/fechar.

### Carreira
Nível, XP até o próximo nível, cargo, pontuação e desbloqueios recentes. Indicar dados sincronizados e locais.

### Viagens
Viagem atual, estado do registro, cronômetro e destino quando disponível. Iniciar/encerrar registro somente se as condições reais forem satisfeitas. Mostrar fila offline e estado de sincronização.

### DriverOps
Velocidade, limite, atraso, próxima parada, passageiros e alertas disponíveis. Dados ausentes aparecem como indisponíveis, nunca inventados.

### Empresa/equipe
Próxima escala, motorista atribuído e estado de sessão. Despacho exige cargo autorizado e suporte real do adaptador. Multiplayer do portal não é necessariamente o multiplayer nativo do jogo.

### Configurações
Escala de UI, opacidade, posição, modo compacto, idioma, telemetria, consentimento, sincronização e atalhos. No openOMSI, F1–F4 ficam reservadas às câmeras. Não sobrescrever comandos existentes.

## Portal web
- Responsivo, navegação lateral no desktop e menu compacto no celular.
- Dashboard com cards de carreira, viagens, conquistas e plano.
- Tabelas com filtros, paginação, estados vazios e carregamento acessível.
- Contraste AA, foco de teclado, rótulos acessíveis e mensagens claras.
- Não apresentar dados de demonstração como reais.

## Comportamento e desempenho
- Não atualizar a interface a cada frame; atualizar quando os dados mudarem ou em intervalos moderados.
- UI não bloqueia simulação, direção ou renderização.
- Se API ficar indisponível, manter condução e painel local; sincronizar depois.
- No openOMSI, usar APIs documentadas de painel e eventos. No OMSI 2 clássico, validar UI no runtime e oferecer fallback de teclado/overlay quando necessário.