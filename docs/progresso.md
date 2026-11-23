# Progresso

Atualizado em 2026-11-23.

## Fase atual: 3 — Linha avançada e combate (núcleo)

Portão para avançar: zero linhas atravessadas e custo de CPU dentro do
orçamento (cumprido no CI). Falta medir no celular.

| Item | Situação |
| --- | --- |
| Vários pipeiros no mesmo mundo (`Flyer`) | Feito; voo das Fases 1 e 2 idêntico (regressão 0,0000) |
| Contato linha × linha e linha × rabiola, sem atravessar | Feito: 500 cruzamentos aleatórios, 0 travessias |
| Grade espacial (só testa pares próximos) | Feito |
| Desgaste virtual por ponto da linha (faixas de 5 cm) | Feito (D-015) |
| Ruptura sem perder comprimento; pipa avoada com o pedaço de linha | Feito |
| Linha fixa entre postes (obstáculo) | Feito |
| Linha desenhada como fita com largura mínima na tela | Feito (D-017) |
| Laboratório: linha fixa, pipa rival parada, linha vermelha com desgaste, aviso de ruptura | Feito |
| Aparagem (prender uma pipa avoada com a linha ou a rabiola) | Pendente |
| Emaranhamento com nó (linhas que enroscam e não deslizam) | Pendente: hoje o contato não tem atrito, as linhas sempre deslizam |
| Colisão da linha com prédios, árvores e antenas | Pendente (entra com os cenários, Fase 7) |
| Medir o FPS no celular com duas pipas | Pendente |

### Medido no CI (raia com rabiola, vento 5 m/s, linha 30 m)

| Situação | Resultado |
| --- | --- |
| Linha da pipa sobe e encosta na linha fixa (9,5 m de altura, 10 m à frente) | encostada a 0,020 m por 6,9 s de 10; dobrada a 9,4 m (livre: cerca de 12 m) |
| Enganchada e parada, 10 s | desgaste máx 0,018 (pipa) e 0,025 (fixa); rompe em 1,0 |
| Recolhendo enganchada, 4 s | desgaste 0,020 (pipa, que corre pelo contato) × 0,700 (fixa, parada no ponto) |
| Linha fixa fraca rompe | 2 pedaços, nenhum comprimento perdido, a pipa volta a subir |
| Linha da pipa rompe | pipa avoada desce de 22 m para 12 m e vai 45 m vento abaixo em 8 s |
| Duas pipas soltas com as linhas cruzadas | 0 travessias |
| Custo, 2 pipas + linha fixa enganchada | 208 ms de CPU por segundo simulado no servidor do CI |

## Próxima tarefa

Fase 4 — Bot piloto: um bot que empina a raia usando só os comandos do
`PilotInput`, mantendo a pipa no ar 5 minutos com rajadas. Depois, um bot que
procura enganchar e disputar a linha. Antes ou junto: aparagem.

## Fases

| Fase | Nome | Situação |
| --- | --- | --- |
| 0 | Infraestrutura | Concluída (falta o teste no celular) |
| 1 | Laboratório de física | Concluída (falta o teste no celular) |
| 2 | Controle e rabiola | Concluída no CI; falta o teste no celular |
| 3 | Linha avançada | Núcleo concluído no CI; faltam aparagem e nó |
| 4 | Bot piloto | Próxima |
| 5 | Fatia vertical: 1x1 contra bot | — |
| 6 | Modelos de pipa e materiais | — |
| 7 | Mundo | — |
| 8 | Bots completos e combate livre | — |
| 9 | Interface, campeonatos, polimento | — |
| 10 | Multiplayer online | — |
