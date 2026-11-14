# Progresso

Atualizado em 2026-11-14.

## Fase atual: 1 — Laboratório de física

Portão para avançar: experimentos de voo básicos passando no GitHub Actions
(cumprido) e o Lucas abrir o laboratório no celular.

| Item | Situação |
| --- | --- |
| WindSystem: vento com perfil de altura, turbulência e rajada, determinístico | Feito |
| Raia de laboratório: corpo rígido, 4 painéis de placa plana, diedro, cabresto | Feito |
| Linha XPBD (30 m, 24 nós) com arrasto, alcance máximo e chão | Feito |
| Rabiola simples (2 m, 10 nós) | Feito (antecipada da Fase 2: sem ela a raia não fica estável) |
| 11 experimentos de voo com critério numérico | Feito, todos passando |
| Testes unitários (aerodinâmica, vento, linha, corpo rígido) | Feito |
| Laboratório de voo no celular (cena principal) | Feito |
| Capturas de tela automáticas no CI (ramo `capturas`) | Feito |
| Lucas abre o laboratório no celular e mede o FPS | Pendente |
| Trajetórias de referência gravadas (regressão) | Pendente, entra junto com a Fase 2 |

### Resultados medidos no CI (Godot 4.7, raia com rabiola, linha de 30 m)

| Experimento | Resultado |
| --- | --- |
| Vento 5 m/s | elevação 48,5°, ângulo de ataque 24°, tensão 2,9 N, sem oscilação |
| Tensão × vento (3, 5, 8 m/s) | 1,25 N · 2,92 N · 6,88 N (razão 8/5 = 2,35) |
| 4 × 8 subpassos | diferença de 0,03° e 0,8% na tensão |
| Turbulência com rabiola | fica entre 44° e 52°, desvio lateral até 1,7 m |
| Sem rabiola | perde o controle e cai |
| Começando 35° de lado | volta ao centro (15 m → 0,01 m) |
| Cabresto 0,08 × 0,14 m | ataque 32° × 21°, elevação 44° × 49° |
| Rajada 3 → 12 m/s | sem instabilidade numérica, linha estica 2,5% |
| Linha de 100 m, vento 8 m/s | estica 2,4%, sendo 1,6% do próprio náilon |
| Custo | cerca de 40 ms de CPU por segundo simulado (4% de um núcleo do servidor) |

## Próxima tarefa

Fase 2 — Controle e rabiola: mão do pipeiro móvel, carretilha com comprimento
de linha variável, os 7 comandos (puxão, arrancão, dar linha, recolher,
afrouxar, largar, desbicar) como movimentos da mão e da carretilha, controles
de toque e teclado, e uma raia sem rabiola para o desbicar.

## Fases

| Fase | Nome | Situação |
| --- | --- | --- |
| 0 | Infraestrutura | Concluída (falta só o teste no celular) |
| 1 | Laboratório de física | Concluída no CI; falta abrir no celular |
| 2 | Controle e rabiola | Próxima |
| 3 | Linha avançada | — |
| 4 | Bot piloto | — |
| 5 | Fatia vertical: 1x1 contra bot | — |
| 6 | Modelos de pipa e materiais | — |
| 7 | Mundo | — |
| 8 | Bots completos e combate livre | — |
| 9 | Interface, campeonatos, polimento | — |
| 10 | Multiplayer online | — |
