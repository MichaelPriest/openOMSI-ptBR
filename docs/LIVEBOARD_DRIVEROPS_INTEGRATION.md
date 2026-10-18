# Integração Liveboard + DriverOps no openOMSI

## Base e segurança

Este trabalho usa o repositório pessoal `MichaelPriest/openOMSI-ptBR` como área de integração, sem alterar `main`. A branch de trabalho é `feature/liveboard-driverops-integration`.

O projeto exige uma instalação original de OMSI 2 e não distribui mapas, veículos, sons ou outros arquivos proprietários. O runtime C# `OMSI-Compatible-Runtime` permanece preservado como referência; não vamos tentar juntar os dois motores.

## Etapa 1 — DriverOps inicial (implementada nesta branch)

Arquivo: `plugins/driverops/main.lua`

O plugin lê o estado real que o openOMSI expõe:

- veículo atual;
- linha e viagem/tabela ativa;
- velocidade atual;
- atraso/adiantamento da tabela;
- próxima parada.

Atalhos:
- **F9** — resumo operacional completo;
- **F10** — status rápido.

Não há tráfego, passageiros, velocidade, atrasos ou viagens simulados pelo plugin. Quando a API não fornece um dado, a interface informa que ele está indisponível ou não informado.

### Instalação manual para teste

Copie a pasta `plugins/driverops` para a pasta `plugins` de uma raiz de conteúdo que o openOMSI carrega, por exemplo:

```text
<raiz de conteúdo OMSI>/
  plugins/
    driverops/
      main.lua
```

Inicie o openOMSI, carregue um mapa, assuma uma viagem e pressione F9/F10. A pasta deste repositório não é automaticamente a pasta de conteúdo do usuário.

## Próximas etapas

1. **Validar o plugin no jogo real** com uma viagem ativa e registrar comportamento de F9/F10, valores ausentes e reload.
2. **Liveboard nativo:** criar seletor de ônibus durante a sessão usando o estado/fluxo de veículos do núcleo Rust. A API Lua documentada permite ler o veículo e acionar comandos de menu conhecidos, mas não expõe um comando público para substituir o ônibus atual; portanto, não vamos fingir que um plugin Lua sozinho implementa troca de veículo.
3. **Liveboard/HOF:** listar arquivos `.bus` e arquivos HOF reais da instalação selecionada, com confirmação/cancelamento e sem copiar conteúdo original para o repositório.
4. **DriverOps ampliado:** evoluir para um painel persistente na UI nativa, com estados reais de viagem, parada, horário e diagnóstico.
5. **NavBR/multiplayer:** avaliar integração por etapas para evitar dois motores de tráfego ou duas autoridades de estado concorrentes.

## Critérios de aceite

- Plugin Lua carrega sem erro no openOMSI.
- F9 e F10 só mostram valores retornados pelo estado real da sessão.
- Sem ônibus/viagem, os campos ausentes são tratados sem exceção.
- Não alterar `main`, não distribuir arquivos proprietários e não enfraquecer testes.
- Liveboard de troca de veículo só será marcado como concluído após integração e teste no núcleo Rust.
