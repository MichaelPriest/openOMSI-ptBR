# Portabilidade para openOMSI 0.3.37

## Base oficial confirmada

- Repositório oficial: https://github.com/openOMSI-org/openOMSI
- Tag-alvo: `v0.3.37`
- Commit da tag: `b5e4acca36b095617a87dcabb47a1eeb775422b1`
- Referência da tag: https://github.com/openOMSI-org/openOMSI/releases/tag/v0.3.37
- Referência principal para plugins: `docs/PLUGINS.md` e `docs/plugin-api.json` nessa tag.

## Estado deste branch

Este branch é uma área de portabilidade. Ele **ainda não contém uma cópia atualizada do motor Rust oficial 0.3.37**: o repositório `MichaelPriest/openOMSI-ptBR` é independente e não possui os objetos Git da origem oficial. A tentativa de criar uma branch diretamente no commit oficial foi rejeitada pelo GitHub porque esse objeto não existe neste repositório. Não se deve rotular uma build deste branch como 0.3.37 até importar a árvore oficial completa.

## DriverOps portado para a API atual

`plugins/driverops/main.lua` foi atualizado para usar a API pública documentada na tag-alvo:

- `omsi.bus.state()` e `omsi.bus.passengers()` para estado do ônibus;
- `omsi.duty.get()` e `omsi.fmt.delay()` para linha, viagem, próxima parada e atraso;
- painel nativo `omsi.ui.set()` com atualização periódica;
- F9 para mostrar/ocultar o painel e F8 para resumo rápido via `omsi.ui.toast()`.

A API documentada confirma as funções e eventos usados, mas o plugin ainda precisa ser executado dentro do binário 0.3.37 para validar layout, teclas e dados reais do ônibus.

## Próximas etapas obrigatórias

1. Importar o código-fonte completo da tag oficial em um branch de atualização separado, preservando a versão antiga.
2. Reaplicar as alterações próprias que ainda forem necessárias, sem copiar o motor antigo por cima do novo.
3. Compilar com Rust estável e executar `cargo test --workspace` conforme `docs/BUILDING.md`.
4. Rodar o verificador de conteúdo e testar um mapa/ônibus reais, com foco em texturas, veículos de IA e painéis.
5. Só então marcar a base como 0.3.37 e abrir PR de integração.

Nenhuma alteração foi feita na branch `main` e nenhum PR foi mesclado.
