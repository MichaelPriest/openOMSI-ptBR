# Empresa Virtual — funcionalidades e planos

Os planos abaixo são proposta inicial de produto, não preços publicados. Valores, limites e impostos serão configurados antes do lançamento.

## Matriz funcional

| Área | Gratuito | Premium | Equipe |
|---|---|---|---|
| Conta e perfil | Perfil e um dispositivo ativo | Vários dispositivos e personalização | Membros, convites e cargos |
| Carreira | XP, níveis e conquistas iniciais | Estatísticas, objetivos e histórico completo | Metas e carreira da empresa |
| Viagens | Registro individual com limite configurável | Mais histórico, filtros e relatórios | Escalas e atribuição de motoristas |
| Empresa | Participar de empresa pública quando permitido | Criar empresa e gerir recursos premium | Gestão de empresa, cargos e equipe |
| DriverOps | Painel essencial com dados disponíveis | Histórico, gráficos e relatórios | Indicadores agregados e painel operacional |
| Conquistas | Conjunto inicial | Conquistas avançadas e temporadas | Desafios internos |
| Rankings | Ranking público limitado e opt-in | Filtros e períodos adicionais | Ranking interno |
| Loja | Itens gratuitos | Temas e cosméticos próprios | Identidade visual da equipe |
| Suporte | Comunidade e FAQ | Fila prioritária | Suporte de gestão |
| Plugins | Recursos essenciais nos dois jogos | Recursos avançados autorizados pelo servidor | Recursos de equipe conforme assinatura |

## Regras
- Condução básica e compatibilidade fundamental não ficam atrás de paywall.
- Permissões premium são validadas no backend, não apenas ocultadas na interface.
- A interface informa recursos indisponíveis por limitações do runtime.
- Não vender vantagem competitiva por cosméticos.
- Plano expirado não apaga carreira, viagens, conquistas ou empresa; a conta retorna ao modo gratuito.
- Limites são configurados no backend, não duplicados nos plugins.

## Plano Gratuito
- Conta, perfil, carreira inicial e conquistas básicas.
- Registro de viagens com limite configurável.
- Painel de operação essencial dentro do jogo.
- Um vínculo de dispositivo ativo.
- Comunidade, FAQ e atualizações estáveis.

## Premium individual
- Carreira e relatórios avançados.
- Histórico, filtros, objetivos e personalização ampliados.
- Mais viagens e dispositivos dentro dos limites configurados.
- Temas e cosméticos sem vantagem competitiva.
- Suporte prioritário.

## Equipe / Empresa
- Gestão de membros, cargos e convites.
- Escalas, despacho, metas e rankings internos.
- Relatórios agregados e auditoria.
- Limites por assentos e ferramentas administrativas.
- Proprietário administra pagamento e assentos.

## Telas do portal
1. Público: início, funcionalidades, compatibilidade, preços, FAQ, termos, privacidade e status.
2. Conta: cadastro, login, verificação de e-mail, recuperação e dispositivos.
3. Painel: carreira, última viagem, XP, conquistas, plano e sincronização.
4. Carreira: níveis, XP, histórico, estatísticas e metas.
5. Viagens: lista, detalhe, rota quando disponível, veículo, duração, distância e eventos validados.
6. Empresas: criar/entrar/sair, convites, membros, cargos e escalas.
7. Conquistas: catálogo, progresso e desbloqueios.
8. Loja: itens digitais próprios e histórico de compra.
9. Plugins: downloads versionados, instruções, requisitos e changelog.
10. Assinatura: Checkout, faturas, cancelamento e Customer Portal.
11. Suporte: FAQ, incidentes, tickets e logs redigidos voluntariamente.
12. Administração: usuários, empresas, eventos suspeitos, planos, versões e auditoria.

## Antifraude
Não aceitar XP, pontuação ou duração declarados pelo cliente sem validação. Eventos devem ter ID único e sequência por sessão. Regras detectam velocidade impossível, saltos de posição, viagens duplicadas e duração irreal. Eventos suspeitos não geram recompensas até análise.