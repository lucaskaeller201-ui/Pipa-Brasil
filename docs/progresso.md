# Progresso

Atualizado em 2026-11-23.

## Fase atual: 4 — Bot piloto

Portão para avançar: o bot mantém a pipa no ar 5 minutos com rajadas
(cumprido no CI com a raia sem rabiola, a mais difícil).

| Item | Situação |
| --- | --- |
| Raia sem rabiola corrigida: fica no ar sozinha e é dirigível | Feito (D-018) |
| `BotDifficulty`: 4 níveis (atraso, ruído, precisão, frequência de decisão) | Feito |
| `BotPerception`: só o que o pipeiro vê e sente, com atraso e ruído | Feito |
| `BotPilot`: empina usando só o `PilotInput` | Feito |
| 5 minutos no ar com rajadas, sem tocar o chão, linha controlada | Feito: fácil e profissional |
| Todos os níveis, 1 minuto, 2 ventos diferentes | Feito: nenhum toque no chão |
| Bot contra bot | Feito: as linhas se encostaram e uma rompeu, sem ninguém programar a disputa |
| Laboratório: rival pilotado por bot (persegue a sua pipa), nível escolhível, piloto automático | Feito |
| Mirar um lado do céu com precisão | Pendente: o bot chega ao lado certo só metade das vezes (D-018) |
| Bot que procura enganchar e disputar de propósito | Pendente (Fase 8) |
| Personalidades (defensivo, agressivo etc.) | Pendente (Fase 8) |

### Medido no CI

| Situação | Resultado |
| --- | --- |
| Raia sem rabiola sozinha, turbulência, 3 ventos | sobe e fica parada a 60–63° com o bico para cima; nunca abaixo de 58° |
| Folga 0,5 s (carretilha livre) e puxar 1,5 s | bico gira 79°; a pipa corre 32° para o lado e desce 14° |
| Bot fácil, 5 min, rajadas de 7–10 m/s a cada 20 s | mínimo 12,8°, nunca no chão, linha 42 m (máx 49), 264 giros |
| Bot profissional, 5 min | mínimo 24,2°, nunca no chão, linha 36 m (máx 43), 286 giros |
| Bot contra bot, 1 min | linhas encostadas 3,2 s; uma linha rompeu |

## Próxima tarefa

Fase 5 — Fatia vertical: partida 1 contra 1 contra o bot, no terreno aberto,
com pôr do sol básico, câmera em 3ª pessoa e aparagem. Antes, melhorar a mira
do bot (ele precisa conseguir ir atrás da sua pipa de propósito) e decidir com
o Lucas a regra do desgaste (D-015).

## Fases

| Fase | Nome | Situação |
| --- | --- | --- |
| 0 | Infraestrutura | Concluída (falta o teste no celular) |
| 1 | Laboratório de física | Concluída (falta o teste no celular) |
| 2 | Controle e rabiola | Concluída no CI; falta o teste no celular |
| 3 | Linha avançada | Núcleo concluído no CI; faltam aparagem e nó |
| 4 | Bot piloto | Concluída no CI; falta a mira precisa |
| 5 | Fatia vertical: 1x1 contra bot | Próxima |
| 6 | Modelos de pipa e materiais | — |
| 7 | Mundo | — |
| 8 | Bots completos e combate livre | — |
| 9 | Interface, campeonatos, polimento | — |
| 10 | Multiplayer online | — |
