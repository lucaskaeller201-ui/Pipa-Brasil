# Progresso

Atualizado em 2026-11-23.

## Fase atual: 5 — Partida 1 contra 1 na laje (primeira versão)

| Item | Situação |
| --- | --- |
| Celular em pé (retrato), tela 720×1280 | Feito (D-021) |
| Regras da partida melhor de 3 (`MatchRules`): suba a pipa, a mais alta sem corte, valendo corte | Feito |
| Bairro com duas lajes, caixas d'água, antenas, postes, pôr do sol | Feito (provisório, só visual) |
| Primeira pessoa com carretilha e mão; botão para 3ª pessoa | Feito |
| Placar, jogo, tempo, alturas e avisos (corte, enrosco, manda busca) | Feito |
| 6 botões grandes embaixo, vários dedos ao mesmo tempo | Feito |
| Rival bot com apelido; vai atrás da sua pipa no valendo corte | Feito |
| Laboratório aberto pelo botão "Lab" | Feito |
| Partida inteira bot contra bot termina com vencedor (teste) | Feito |
| Lajes e casas com colisão para linha e pipa | Pendente (Fase 7) |
| Página para jogar no iPhone (GitHub Pages) | Feito no CI; falta o Lucas ligar o Pages (D-022) |
| Teste no celular (FPS e sensação dos botões) | Pendente: depende do Lucas |

### Fase 4 — Bot piloto (concluída no CI)

| Item | Situação |
| --- | --- |
| Bot empina usando só o `PilotInput`, 4 níveis, percepção com atraso | Feito (D-019) |
| 5 minutos no ar com rajadas | Feito |
| Manda busca: aparar a avoada; o bot apara sozinho | Feito (D-020) |
| Mirar um lado do céu com precisão | Pendente: chega ao lado certo metade das vezes |
| Personalidades e disputa de propósito | Pendente (Fase 8) |

## Próxima tarefa

Lucas testar a versão 0.5.0 no celular e contar o FPS e a sensação. Depois:
melhorar a mira do bot, emendar a pipa aparada na carretilha, combate livre
offline com até 8 bots. Ainda falta a opinião do Lucas sobre a regra do
desgaste (D-015).

## Fases

| Fase | Nome | Situação |
| --- | --- | --- |
| 0 | Infraestrutura | Concluída (falta o teste no celular) |
| 1 | Laboratório de física | Concluída (falta o teste no celular) |
| 2 | Controle e rabiola | Concluída no CI; falta o teste no celular |
| 3 | Linha avançada | Núcleo concluído no CI; faltam aparagem e nó |
| 4 | Bot piloto | Concluída no CI; falta a mira precisa |
| 5 | Fatia vertical: 1x1 contra bot na laje (cortar e aparar) | Primeira versão pronta; falta o teste no celular |
| 6 | Modelos de pipa e materiais | — |
| 7 | Mundo | — |
| 8 | Bots completos e combate livre | — |
| 9 | Interface, campeonatos, polimento | — |
| 10 | Multiplayer online | — |
