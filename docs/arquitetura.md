# Arquitetura

Resumo técnico. O plano completo, com diagramas, riscos e critérios de cada
fase, está no doc "PIPA BRASIL — Análise técnica e plano de desenvolvimento".

## Ideia central

Toda a física fica num núcleo próprio (`sim/`, o KitePhysicsCore), escrito em
GDScript puro e executado em passo fixo. O jogador e os bots só enviam
**comandos do pipeiro** para esse núcleo; a tela, os testes, o replay e o
futuro multiplayer só **leem o estado** dele.

```
Jogador (toque, teclado, mouse)      BotAI (percepção com ruído e atraso)
                 \                      /
              Comandos do pipeiro (mesma interface)
                               |
        sim/ · KitePhysicsCore (passo fixo de 120 Hz)
        ├── wind/    WindSystem: vento, rajadas, turbulência
        ├── pilot/   mão, braço, carretilha, comprimento da linha
        ├── rope/    RopePhysics: linha Verlet/XPBD, colisões
        ├── kite/    corpo rígido, painéis, cabresto, centro de pressão
        ├── tail/    TailPhysics: rabiola em segmentos
        └── combat/  KiteCombatSystem: contato entre linhas, desgaste
                     virtual, ruptura, pedaços soltos, aparagem
                               |
     game/ (o que se vê)   tests/ (sem tela)   replay e multiplayer
```

## Modelo físico (alvo)

- **Pipa:** corpo rígido 6 graus de liberdade. Cada painel calcula o vento
  aparente (vento menos a velocidade do ponto), o ângulo de ataque e uma força
  normal de placa plana com estol e arrasto, aplicada no centro de pressão. A
  soma dá força e torque. Cada modelo é um arquivo de parâmetros em
  `data/kites/` (geometria, massa, inércia, painéis, cabresto, rigidez).
- **Cabresto:** ponto onde a linha prende; define o ângulo de equilíbrio.
- **Linha:** cadeia de partículas com integração de Verlet e restrições XPBD,
  comprimento variável (a carretilha adiciona e retira nós), limite de
  distância até a mão para evitar efeito elástico.
- **Rabiola:** cadeia leve com arrasto por segmento, presa à base da pipa.
- **Comandos:** movem a mão e a carretilha (veja `docs/decisoes.md`, D-003).
- **Combate:** teste de distância entre segmentos de linhas diferentes, com
  subpassos para não atravessar; contato como restrição (a linha dobra);
  desgaste virtual acumulado por pressão e deslizamento; ruptura ao atingir o
  limite; linha e pipa soltas viram corpos livres; encostar numa pipa avoada
  cria uma ligação (aparagem).
- **Bots:** mesma interface de comandos. Dificuldade muda ruído, atraso e
  precisão; personalidade muda os pesos das decisões.

## Desempenho

Orçamento medido por benchmarks em `tests/benchmarks/`. Se o GDScript não
couber no orçamento do celular, só o laço interno da linha vai para C++
(GDExtension), compilado no GitHub Actions.
