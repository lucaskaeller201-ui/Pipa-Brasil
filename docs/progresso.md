# Progresso

Atualizado em 2026-11-14.

## Fase atual: 2 — Controle e rabiola

Portão para avançar: o Lucas empina e direciona no celular só com folga e
puxão. Os testes automáticos da fase passam no GitHub Actions.

| Item | Situação |
| --- | --- |
| Mão do pipeiro com braço (mola criticamente amortecida, velocidade máxima) | Feito |
| Carretilha: dar linha (com freio, até 2 m/s), largar (livre), recolher (1,2 m/s) | Feito |
| Linha com comprimento variável na ponta da mão (cria e remove nós) | Feito |
| 8 comandos como movimentos da mão e da carretilha (D-003) | Feito |
| `PilotInput`: a mesma interface para jogador e bots | Feito |
| Vareta flexível (diedro depende da tensão) | Feito |
| Raia sem rabiola com modelo de giro | Experimental (D-012) |
| Controles na tela (8 botões grandes) e teclado no PC, sensibilidade | Feito |
| Testes dos comandos (10) e do modelo da raia sem rabiola (6) | Feito, passando |
| Trajetórias de referência (regressão) | Feito: 3 cenários em `tests/golden/` |
| Lucas testa no celular: empinar e direcionar | Pendente |
| Toque com vários dedos ao mesmo tempo | Pendente (os botões atuais aceitam um toque por vez) |

### Comandos medidos no CI (raia com rabiola, vento 5 m/s, linha 30 m, tensão parada 2,9 N)

| Comando | Efeito medido |
| --- | --- |
| Puxão | tensão até 11,7 N, pipa a 4,9 m/s |
| Arrancão | tensão até 17,7 N, pipa a 7,9 m/s |
| Desbicar | linha frouxa (0 N) e depois puxão de 15 N |
| Dar linha 3 s | +5,9 m, pipa se afasta e desce de 48° para 35° |
| Largar 3 s | +7,8 m, tensão média 0,35 N |
| Recolher 3 s | −3,6 m, pipa sobe de 48° para 56° |
| Afrouxar 1 s | tensão média 2,4 N |
| Puxar 1 s | tensão média 3,9 N, pipa sobe |

## Próxima tarefa

Fase 3 — Linha avançada: colisão da linha com o cenário, contato entre linhas
(dobra), emaranhamento, ruptura virtual e pedaços soltos, linha desenhada como
fita com largura mínima na tela.

Antes disso, se o teste no celular mostrar que a raia sem rabiola é difícil
demais, ajustar os parâmetros de giro (`spin_bias`, `bow_stability`).

## Fases

| Fase | Nome | Situação |
| --- | --- | --- |
| 0 | Infraestrutura | Concluída (falta o teste no celular) |
| 1 | Laboratório de física | Concluída (falta o teste no celular) |
| 2 | Controle e rabiola | Concluída no CI; falta o teste no celular |
| 3 | Linha avançada | Próxima |
| 4 | Bot piloto | — |
| 5 | Fatia vertical: 1x1 contra bot | — |
| 6 | Modelos de pipa e materiais | — |
| 7 | Mundo | — |
| 8 | Bots completos e combate livre | — |
| 9 | Interface, campeonatos, polimento | — |
| 10 | Multiplayer online | — |
