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
