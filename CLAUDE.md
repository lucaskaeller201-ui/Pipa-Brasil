# PIPA BRASIL — instruções para o Claude

Simulador brasileiro de pipas em 3D (Godot 4 + GDScript, Windows e Android).
Dono do projeto: Lucas, estudante e iniciante em ferramentas técnicas. Responda
sempre em português, com instruções passo a passo para iniciante.

## Antes de qualquer trabalho

1. Leia `docs/progresso.md`: estado atual, fase e próxima tarefa.
2. A especificação oficial está em `docs/especificacao/`. Não edite esses
   arquivos; decisões novas vão em `docs/decisoes.md`.
3. Arquitetura resumida em `docs/arquitetura.md`. Plano completo (com diagramas)
   no doc "PIPA BRASIL — Análise técnica e plano de desenvolvimento":
   https://claude.ai/artifact/EywREPAQsVn51fXqvfHaoW

## Regras do projeto

- A física (`sim/`) é GDScript puro: classes `RefCounted`, sem `Node`, sem cenas,
  sem singletons, em passo fixo. `game/` só lê o estado da simulação ou envia
  comandos para ela.
- Nenhum comportamento físico pode ser substituído por animação falsa.
- Todo comportamento físico novo vem com teste em `tests/` (unitário ou
  experimento com critério numérico). Nenhuma fase avança com teste falhando.
- Não substituir sistema que funciona sem teste de regressão.
- Bots usam exatamente a mesma interface de comandos do jogador. Sem trapaça,
  sem teletransporte, sem ler informação escondida.
- Combate apenas virtual. Nunca escrever conteúdo sobre cerol, linha chilena ou
  técnicas reais de corte.
- Custo zero: só ferramentas e assets gratuitos (preferir CC0; conferir licença).
- A cada entrega: atualizar `docs/progresso.md` e `docs/changelog.md`.

## Como testar (o Godot não roda na sessão do Claude na nuvem)

- O workflow `.github/workflows/ci.yml` baixa o Godot (versão em `GODOT_VERSION`),
  roda `tests/run_tests.gd` e gera os builds Android, Windows e Web.
- Acompanhar a execução: `gh run list -R lucaskaeller201-ui/pipa-brasil` e
  `gh run view <id> -R lucaskaeller201-ui/pipa-brasil --log-failed`.
- Com o Godot instalado localmente:
  `godot --headless --path . --import` e depois
  `godot --headless --path . --script res://tests/run_tests.gd`.
- Os builds para o usuário ficam na release `ultima-versao` do GitHub.

## Estilo de código

- GDScript com tabs e tipagem estática.
- Módulos do Documento Mestre mantêm o nome em inglês (KitePhysicsCore,
  WindSystem, RopePhysics, TailPhysics, KiteCombatSystem, BotAI); comentários e
  documentação em português.
- Unidades do SI (metros, segundos, quilogramas, newtons). Eixo Y para cima.
