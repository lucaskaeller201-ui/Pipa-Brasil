# Histórico de alterações

## 0.6.0 — 2026-11-23

Depois do primeiro teste do Lucas no iPhone:
- Celular deitado de novo.
- Modo livre: sem tempo, solta até cansar; placar de cortes e aparadas contra
  3 bots com apelido; pipa nova depois do corte. A partida cronometrada saiu.
- Sem botões de comando: deslizar para baixo puxa, para cima dá linha,
  toques desbicam. No PC: W/S ou setas e Espaço.
- Pipa reta: com a linha esticada ela vai para onde o bico aponta, sem virar
  no caminho (D-024).
- Câmera com zoom na sua pipa, seta mostrando o bico, setas e nomes das pipas
  dos rivais; carretilha que gira com a linha.

## 0.5.0 — 2026-11-23

- Fase 5, primeira versão da partida: o jogo abre direto numa partida melhor
  de 3 contra um bot com apelido, na laje de um bairro ao pôr do sol.
  Jogos: suba a pipa, a mais alta sem corte e valendo corte (com manda busca).
- Celular em pé (retrato). Visão em primeira pessoa com carretilha e mão, e
  botão para a terceira pessoa. Seis botões grandes que aceitam vários dedos.
- O laboratório de voo continua disponível pelo botão "Lab".
- O bot dá linha quando precisa subir.
- Página web publicada automaticamente para jogar no iPhone pelo Safari.
- Testes: partida inteira entre bots, suba a pipa, desgaste por jogo, cena
  da partida e orientação da tela.

## 0.4.1 — 2026-11-23

- Manda busca: a linha ou a rabiola de uma pipa avoada enrosca na linha ou na
  rabiola de quem está em voo; recolhendo, ela vem até a mão (pipa aparada).
  Avoada que cai sem ninguém aparar é pipa perdida.
- O bot recolhe sozinho quando sente uma pipa enroscada.
- Laboratório: avisos de corte, enrosco, aparada e perdida; placar de cortes e
  aparadas.

## 0.4.0 — 2026-11-23

- Fase 4: bot piloto em `game/ai/` (`BotDifficulty`, `BotPerception`,
  `BotPilot`) que empina usando só os comandos do pipeiro.
- Raia sem rabiola corrigida: deixa de virar o bico para baixo parada, fica no
  ar sozinha e é dirigível por folga e puxão (D-018). Referência de regressão
  regenerada.
- Laboratório: pipa rival pilotada por bot (persegue a sua), nível escolhível e
  piloto automático na sua pipa.
- Testes: 7 novos, incluindo 5 minutos de voo do bot com rajadas.

## 0.3.0 — 2026-11-23

- Fase 3: vários pipeiros no mesmo mundo (`Flyer`); contato entre linhas e
  rabiolas com detecção de travessia e grade espacial; `KiteCombatSystem` com
  desgaste virtual por ponto da linha, ruptura e pipa avoada; linha fixa entre
  postes.
- A ruptura divide o segmento rompido ao meio, sem perder comprimento.
- Laboratório: linha fixa, pipa rival parada, linha que fica vermelha com o
  desgaste, aviso de ruptura e linhas desenhadas como fita visível de longe.
- Testes: 500 cruzamentos aleatórios sem travessia, 7 cenários de combate.

## 0.2.0 — 2026-11-14

- Fase 2: mão do pipeiro e carretilha em `sim/pilot/`; linha com comprimento
  variável; 8 comandos (puxar, afrouxar, dar linha, largar, recolher, puxão,
  arrancão, desbicar) que só movem a mão e a carretilha.
- `PilotInput`: interface única de comandos para jogador e bots.
- Vareta flexível e raia sem rabiola experimental (modelo de giro empírico).
- Laboratório: 8 botões de comando, teclado no PC, sensibilidade, escolha entre
  raia com e sem rabiola, câmera lateral ajustada ao zoom.
- Testes: 16 novos e regressão por trajetórias de referência (`tests/golden/`),
  com geração automática no CI (ramo `referencias-novas`).

## 0.1.0 — 2026-11-14

- Fase 1: núcleo físico em `sim/` (vento, raia com corpo rígido e painéis de
  placa plana, cabresto, linha XPBD, rabiola, chão), calibrado num protótipo
  Python guardado em `tools/prototipo/`.
- Laboratório de voo como cena principal: setas de força, painel com números e
  controles de vento, cabresto, linha, zoom, turbulência, rabiola, rajada e
  câmeras.
- 30 novos testes: unitários e 11 experimentos de voo com critério numérico.
- CI grava capturas de tela do laboratório (renderização por software) e
  publica no ramo `capturas`.

## 0.0.1 — 2026-11-14

- Estrutura inicial do repositório e documentação (especificação original,
  decisões, arquitetura, progresso).
- Projeto Godot mínimo com tela de teste (céu de fim de tarde, versão e FPS).
- Executor de testes próprio e testes de configuração e de abertura da cena.
- GitHub Actions: testes automáticos e builds Android, Windows e Web, publicados
  na release `ultima-versao`.
