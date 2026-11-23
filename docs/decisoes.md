# Registro de decisões

Cada decisão tem data, o que foi decidido e o motivo. Decisões novas entram no
topo da seção correspondente. A especificação original fica em
`docs/especificacao/` e não é editada.

## Decisões do Lucas (escopo e estilo do jogo)

| Data | Tema | Decisão |
| --- | --- | --- |
| 2026-11-14 | Plataformas | PC (Windows) e celular (Android) |
| 2026-11-14 | Câmera | Primeira e terceira pessoa |
| 2026-11-14 | Gráficos | Realistas e otimizados; três perfis (Baixo, Médio, Alto); bonito já no Médio |
| 2026-11-14 | Estilo de jogo | Híbrido: física como base, com habilidade e estratégia do jogador |
| 2026-11-14 | Combate | Realista, baseado em física, tão desenvolvido quanto o voo |
| 2026-11-14 | Modalidades | 1 contra 1 e combate livre |
| 2026-11-14 | Bots | Obrigatórios em todos os modos; dificuldade e personalidade independentes |
| 2026-11-14 | Visual | Pôr do sol dourado e piso envernizado como identidade, mas com todos os horários e climas |
| 2026-11-14 | Custo | Zero: só ferramentas e assets gratuitos |
| 2026-11-14 | Segurança | Combate apenas virtual; nada de cerol, linha chilena ou técnicas reais de corte |
| 2026-11-14 | Referências | Estudar o comportamento de outros jogos de pipa, sem copiar código, arte ou mecânicas |

## Decisões técnicas

### D-017 — Linha desenhada como fita (2026-11-23)
A linha real tem 0,6 mm e some na tela a poucos metros. Linhas e rabiolas são
desenhadas como fitas viradas para a câmera, com largura mínima de cerca de
2 pixels na resolução atual. Só muda o desenho; a física usa o diâmetro real.

### D-016 — Testes de contato com linha fixa (2026-11-23)
Entre duas pipas soltas, as linhas engancharem ou não depende de centímetros:
a mesma linha passa por cima ou por baixo da outra (no protótipo, deslocar uma
linha 35 cm muda de "encostam por 2,2 s" para "não encostam"). Isso é física
real e vai virar jogo (o pipeiro manobra para enganchar), mas não serve para
teste automático. Os testes com resultado certo usam uma linha fixa entre
postes, que a linha da pipa encosta por baixo com metros de margem; entre
pipas soltas, o teste só exige que nada atravesse.

### D-015 — Desgaste virtual por ponto da linha (2026-11-23)
O desgaste é guardado por ponto do material da linha, em faixas de 5 cm
contadas a partir da ponta de fora (essa coordenada não muda quando a
carretilha solta ou enrola linha). Cada contato soma
`taxa × força de contato × deslizamento × tempo` no ponto de contato das duas
linhas; a linha rompe quando um ponto chega à resistência (1,0). Por isso a
linha que corre pelo ponto de contato espalha o desgaste e a que fica parada
no ponto o concentra. Com desgaste somado por segmento de 1,25 m, o resultado
saía quase empatado e dependia da ordem de cálculo.

Consequência que precisa do teste do Lucas: no protótipo, numa disputa entre
duas pipas, quem dá linha costuma carregar o cruzamento (o contato fica no
mesmo ponto da linha dele) e é quem rompe. Pode ser o contrário do que o
pipeiro espera. A regra pode ser ajustada (é uma grandeza do jogo), mas só
depois de jogar. São grandezas do jogo, sem relação com materiais cortantes
reais.

### D-014 — Trajetórias de referência (2026-11-14)
Os testes de regressão comparam trajetórias (posição da pipa, tensão e linha a
cada 0,5 s) com arquivos em `tests/golden/`. Quando um arquivo não existe, o CI
o gera e publica no ramo `referencias-novas`; ele só passa a valer depois de
revisado e guardado no repositório. Mudança intencional na física = apagar o
arquivo, gerar de novo e registrar o motivo aqui.

### D-013 — Mão e carretilha (2026-11-14)
A mão se move ao longo da linha com uma mola criticamente amortecida
(30 rad/s) e velocidade máxima por movimento (puxão 4,5 m/s, arrancão 7 m/s).
A carretilha muda o comprimento no segmento da mão: "dar linha" é a carretilha
com freio (a tensão puxa a linha até 2 m/s), "largar" é a carretilha livre e
"recolher" enrola a 1,2 m/s enquanto a tensão for menor que 35 N. Desbicar é
um movimento composto: folga rápida de 0,3 s e depois um puxão. "Puxar" foi
incluído como comando contínuo (o Documento Mestre para o Claude Code lista 8
comandos; o original, 7).

### D-012 — Raia sem rabiola: modelo de giro empírico (2026-11-14)
No protótipo, a raia sem rabiola com só a aerodinâmica de placa plana entrava
em autorrotação (9 voltas/s, mesmo com a linha esticada). Pipas reais não
fazem isso por causa do arrasto das bordas e da vareta envergada. Foram
incluídos três momentos em torno da normal, com parâmetros por pipa:
amortecimento do giro, estabilidade direcional proporcional à curvatura da
vareta e uma tendência de giro (sentido preferido) quando a vareta relaxa. São
forças da simulação, aplicadas igualmente a jogador e bots, não animações. O
resultado reproduz o comportamento de pipa de combate (voa para onde o bico
aponta com a linha esticada, gira com a linha frouxa), mas um controlador
automático simples ainda não consegue mantê-la no ar com turbulência. Por
isso ela é experimental; a calibração final virá com o bot piloto (Fase 4) e
com o teste do Lucas. A raia de laboratório (com rabiola) não usa esse modelo
e continua idêntica à da Fase 1.

### D-011 — Capturas de tela no CI (2026-11-14)
O CI grava quadros do laboratório com renderização por software (Xvfb + Mesa,
renderizador Compatibility) e publica no ramo `capturas`. Motivo: o Claude não
roda o Godot na sessão e precisa conferir o visual sem depender do celular.
As capturas não medem desempenho (o FPS ali é de software).

### D-010 — Critério de estiramento da linha (2026-11-14)
O náilon estica de verdade (T/EA; com EA = 600 N, cerca de 1,5% a 9 N). O
teste da linha longa mede o excesso de estiramento além disso, que seria erro
numérico, e exige menos de 1,2%. Substitui o critério "menor que 2%" do plano
inicial, que confundia o estiramento físico com o numérico.

### D-009 — Precisão simples nas posições (2026-11-14)
Vector3 no Godot usa precisão simples. A 100 m de altura, calcular a velocidade
como (posição − posição anterior) / passo acumula erro. O KiteBody guarda o
deslocamento do subpasso à parte e calcula a velocidade a partir dele.

### D-008 — Rabiola e diedro já na Fase 1 (2026-11-14)
No protótipo, a raia plana sem rabiola é instável e cai (o que é realista), e
sem diedro (vareta envergada) ela deriva para o lado e não volta. A Fase 1
inclui uma rabiola simples e 12° de diedro para permitir os experimentos de voo
estável. A rabiola completa (comprimento, peso, aparagem) segue na Fase 2.

### D-007 — Ordem das fases (2026-11-14)
Bot piloto antecipado para a Fase 4 e fatia vertical (1x1 contra bot) na Fase 5,
antes de cenários e personagens. Motivo: um bot que empina usando só os comandos
do jogador é o melhor teste automático de que a física é controlável, e
construir o mundo antes do combate funcionar arrisca retrabalho. Nenhum
requisito foi cortado.

### D-006 — Testes na nuvem (2026-11-14)
Os testes rodam no GitHub Actions com o Godot em modo sem tela, a cada envio.
Executor de testes próprio (`tests/run_tests.gd`), sem plugins. Motivo: o
Godot não roda na sessão do Claude e o PC do Lucas é fraco.

### D-005 — Renderizador (2026-11-14)
Mobile como base; Compatibility para celulares fracos e para a versão Web;
Forward+ fica como opção futura para o perfil Alto no PC. Motivo: Android é
alvo principal e o Documento Mestre pede o renderer Mobile como ponto de partida.

### D-004 — Passo fixo de 120 Hz (2026-11-14)
`physics_ticks_per_second = 120`, com subpassos internos para a linha. A tela
interpola entre passos. Motivo: física independente do FPS do aparelho.

### D-003 — Comandos são movimentos, não forças (2026-11-14)
Puxão, largada, dar linha etc. movem a mão do pipeiro e a carretilha. Nenhum
comando aplica força direta na pipa. Desbicar não é um botão de virar: a folga
deixa o bico girar e o puxão seguinte leva a pipa para onde ele aponta.

### D-002 — Física própria (2026-11-14)
A pipa usa corpo rígido e aerodinâmica por painéis próprios, não o
`RigidBody3D` do Godot. A física do Godot fica só para colisão com o cenário.
Motivo: forças por painel, cabresto e centro de pressão variável, e o mesmo
núcleo determinístico para jogador, bots, replay e testes.

### D-001 — Separação sim/ e game/ (2026-11-14)
`sim/` contém apenas GDScript puro, sem nós; `game/` contém a parte visual.
Motivo: testar a física sem gráficos e reutilizar o mesmo núcleo em tudo.
