# Registro de decisões

Cada decisão tem data, o que foi decidido e o motivo. Decisões novas entram no
topo da seção correspondente. A especificação original fica em
`docs/especificacao/` e não é editada.

## Decisões do Lucas (escopo e estilo do jogo)

| Data | Tema | Decisão |
| --- | --- | --- |
| 2026-11-23 | Celular de teste | iPhone: joga pela página web; repositório passa a ser público |
| 2026-11-23 | Tela | Celular DEITADO (paisagem). O retrato dos vídeos do Manda Busca era recorte para o TikTok (D-023) |
| 2026-11-23 | Modo de jogo | Modo livre sem tempo, até cansar, com placar de quem cortou mais (substitui a partida cronometrada) |
| 2026-11-23 | Controles | Sem botões: deslizar para baixo puxa ("abraçar"), para cima dá linha, toques desbicam |
| 2026-11-23 | Pipa reta | A pipa não pode "dar de lado" (ficar pensa): com a linha esticada vai reta |
| 2026-11-23 | Pipa do Rio | Com rabiola ("tabula"); dando linha ela gira num ritmo constante; um toque trava o giro e ela arranca reta |
| 2026-11-23 | Giro | Mandando linha: 2 a 3 voltas por segundo (900°/s), imediato; puxando: trava seca. Valores ajustáveis na tela |
| 2026-11-23 | Aparar | Só embola girando em contato; puxada rápida decepa a linha solta ou a rabiola; devagar traz rebocada até a mão, para o estoque |
| 2026-11-23 | Mandar linha e desbico | Mandar linha = deslizar para cima (a carretilha embala); desbico = a pipa se endireita, bico para cima (não vira para um lado) |
| 2026-11-23 | Relo | Linhas que se cruzam ficam laçadas até alguém cortar; quem está dando ou puxando linha leva vantagem sobre a linha parada |
| 2026-11-23 | Referência principal | O jogo Manda Busca (Beedro Games): cortar e aparar, soltar pipa na laje, mapas Bairro, Praia e Montanha, salas de até 8. Projeto Rélo e Pipa Combate ficam só como inspiração distante |
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

### D-075 — Céu de foto, pipa de papel de seda, serra com favela (2026-11-26)
O Lucas pediu para focar em deixar tudo mais bonito, inclusive as casas do
morro ao fundo.
- Céu de foto real (HDRI CC0 do Poly Haven, 2k), escolhido numa folha de
  prévias: manhã com cúmulos (kloofendal_48d_partly_cloudy), meio-dia com
  nuvens (sunflowers), pôr do sol dourado (kloppenheim_06). O CI acha o sol
  na foto e mede o brilho do céu e a cor do horizonte (assets/ceus/ceus.json).
  A luz do sol fica na mesma altura do sol da foto e o céu gira para o sol
  da foto ficar onde está a luz (sombras batem com o céu). A névoa usa a cor
  do horizonte da foto. Sem as fotos, volta o céu por código.
- Pipa: papel de seda num shader próprio — fibra, manchas, amassado
  (relevo), brilho leve e luz atravessando o papel: contra o sol a pipa acende
  na cor dela e as varetas aparecem como sombra por dentro. Varetas de bambu
  com volume (a de cima e a de baixo vergam). A vela não faz sombra em si.
- Serra ao fundo: terreno com picos e vales (ruído + dois morros mais
  altos) no lugar das bolas lisas; pedra nas encostas íngremes; favela de
  ~2.600 casinhas 3D pequenas e grudadas (55% tijolo), caixas d'água azuis,
  manchas de mata e árvores — tudo em MultiMesh (poucas chamadas de desenho).
- Oclusão de ambiente (sombra nos cantos) não existe no renderizador do
  navegador; ficam as sombras do sol (4096) e a sombra no pé das paredes.

### D-074 — Tenteio e câmera medidos no vídeo do Pipa Combate (2026-11-26)
O Lucas mandou um vídeo de tela do Pipa Combate. Analisado quadro a quadro
(30 por segundo, pela letra "B" e pela armação do bico):
- o bico balança em volta de uma direção que fica (para a esquerda de 13 a
  16 s, para baixo de 8 a 11 s), uma ida e volta a cada ~0,6 s; a pipa anda
  para onde a direção aponta (confirma D-070);
- cada balanço gira 60–90° em ~0,15 s (~550°/s), para seco e segura;
- balanço de 30–45° para cada lado;
- para mudar a direção, degraus com volta, andando ~45° por ciclo (cima →
  baixo em ~2 s);
- a câmera segue a pipa o tempo todo, perto do meio da tela.
Com aprovação do Lucas: balanço de ~40° de verdade (o alvo de 30° em
spin_kick_rate_deg já dava 42° medido no teste; com 40 dava 52°, então ficou
30), giro até 550°/s
com ganho 20 (para seco), toque duplo de 45°, câmera com a pipa maior e
mais no meio, seguindo mais firme. Os toques em si não aparecem no vídeo.
Ajustes ganhou dois controles separados: balanço e giro do duplo.

### D-073 — "Um toque e dois rápidos", linha que não solta da mão, linha lisa (2026-11-25)
- Duplo: o Lucas faz "um toque... e dois rápidos" e o jogo não pegava
  quando o par passava de 0,3 s. Agora o par vale até 0,4 s desde que seja
  bem mais junto (1,6×) que o intervalo antes dele; tentear num ritmo
  constante continua sendo tenteio. Bico em qualquer posição (D-070).
- "A largada solta minha linha" (desde a 0.23.0): o boneco novo tem braço
  de tamanho real e ficava 25 cm atrás do pipeiro da física, então a mão não
  alcançava o ponto da linha e parecia que a linha saía da mão. O boneco
  agora fica no lugar certo e se debruça quando a mão vai longe (dando linha).
  A física da largada não mudou.
- "V" na linha: a fita era desenhada reta entre os pontos da física, com
  quinas nas emendas. Agora a curva passa suave pelos mesmos pontos
  (Catmull-Rom) e a fita é contínua. Só desenho; a simulação é a mesma.

### D-072 — Volta a D-070 (2026-11-25)
Depois de pedir para desfazer, o Lucas aprendeu a usar a 0.24.0 e achou boa:
o controle voltou ao da 0.24.0 (D-070: duplo sem travas, bico que fica,
puxão segurando 1 s). D-071 fica sem efeito.

### D-071 — Volta do tenteio da 0.23.0 (desfaz D-070) (2026-11-25)
O Lucas testou a 0.24.0 e achou que mandar linha, desbicar e tentear
ficaram piores. Pediu para voltar como era: o código de controle (livre.gd,
kite_body.gd) e os testes voltaram exatamente ao da 0.23.0 (D-059, D-060,
D-062 valem de novo). O puxão segurando 1 s saiu junto. O documento de
análise dele fica em docs/analise-mecanicas-lucas.txt para consulta.

### D-070 — Tenteio sem travas, bico que fica e puxão segurando (2026-11-25)
O Lucas mandou o documento de análise das mecânicas (Pipa Combate X/4) e
disse que ainda não conseguia pôr o bico onde queria. Diagnóstico: o duplo
era recusado com o bico para cima ou sem pausa antes (D-059), e cada toque
simples puxava a direção 20° de volta para cima (D-060, D-062). Ele aprovou:
- Duplo = dois toques com menos de 0,3 s, na tela toda, com o bico em
  qualquer posição (sem as travas de pausa e de 20°). O lado continua sendo
  o de antes (duplos seguidos giram para o mesmo lado).
- O bico FICA na direção escolhida: o toque simples só balança ±30° em volta
  dela. Para voltar para cima, duplos para o outro lado. (A volta automática
  ficou desligada em KiteBody.tenteio_volta_cima.)
- Puxão (do documento: segurar a tela ~1 s): dedo parado 1 s dispara o
  puxão da física (mão recua rápido, Pilot.Impulse.PUXAO) e recolhe ~1,5 m de
  linha no máximo da mão em 0,25 s — um tranco que a pipa sente conforme o
  estado em que está. Um por dedo. É separado do tenteio e combina com ele.
- Arrancão: ainda sem demonstração, não foi inventado (regra do documento).

### D-069 — Fachadas 3D e boneco com corpo torneado (2026-11-25)
Casas: as janelas e portas deixaram de ser desenho na parede (o shader só
desenha de longe, nas casinhas do morro). Agora são peças 3D: vidro que
reflete, caixilho (branco, alumínio, madeira ou preto), folha do meio,
peitoril, grade no térreo, porta com batente, maçaneta e degrau, sacadas com
guarda-corpo, ar-condicionado, beiral da laje, faixa entre andares e, nas
casas de tijolo, pilares e vigas de concreto aparentes. Tudo junto em duas
malhas (detalhes e vidros), para o celular desenhar em duas chamadas.
Boneco: corpo "torneado" por seções (ombro, cintura, quadril, coxa, joelho,
panturrilha), braço com cotovelo que dobra (IK de dois ossos: a mão chega na
linha), rosto com nariz, orelhas, olhos com íris, sobrancelhas e boca; boné
com aba curva ou cabelo; camiseta com manga e gola, bermuda com cós,
chinelo de dedo; luz de contorno para dar volume. Continua só visual.

### D-068 — Modelos 3D CC0 do Poly Haven e morro com casinhas 3D (2026-11-25)
Modelos fotográficos leves (poucos milhares de triângulos) baixados pelo
GitHub Actions (tools/baixar_modelos.py; créditos em
assets/modelos/CREDITOS.md): cadeira de plástico, engradado, bombona e vasos
nas lajes; luminária de rua, caixa de luz e saco de lixo nos postes; portas
de enrolar e arbustos nas casas. As árvores do Poly Haven têm milhões de
triângulos (pesadas demais para o celular), então a copa das árvores usa o
arbusto ampliado e a copa dos coqueiros usa a samambaia ampliada (a folha
parece palma). As folhas vêm em PNG com transparência (o JPG não tem).
Os morros do bairro deixaram de ser desenho na encosta: são centenas de
casinhas 3D (MultiMesh, um só desenho por morro) com o shader de parede.

### D-067 — Texturas fotográficas CC0 do Poly Haven (2026-11-25)
Para sair do visual "desenhado por código", o chão (asfalto, calçada,
terra, mato, areia, calçadão), as paredes (reboco, tijolo, laje), os
telhados e os troncos usam fotos de materiais reais do Poly Haven
(licença CC0: grátis e livre). O workflow "Texturas" baixa as fotos (1k JPG,
cor + relevo) com tools/baixar_texturas.py e guarda em assets/texturas,
com os créditos em CREDITOS.md. Os shaders mantêm o desenho do mapa (ruas,
janelas, cores das casas) e "repintam" a foto pela cor média, para cada
casa continuar com sua cor. Duas leituras em escalas diferentes escondem
a repetição. Sem as fotos, volta o visual por código. Importadas com
mipmaps e compressão de GPU (ETC2/ASTC no iPhone).

### D-066 — Gráficos ULTRA: antisserrilhado e sombras nítidas (2026-11-25)
O Lucas achou o jogo "pixelado". A causa principal era o serrilhado das bordas
(o jogo rodava sem antisserrilhado) e a sombra em baixa resolução. Agora há um
botão "Gráficos" na página inicial: ULTRA (padrão: MSAA 4x + FXAA, filtro
anisotrópico 16x, sombra 4096 com 4 faixas e borda macia), Alto e Leve (para
celular fraco: sem MSAA e resolução 80%). Fica salvo nas preferências.

### D-065 — Visual mais realista: árvores, coqueiros, telhados, nuvens (2026-11-25)
O Lucas achou tudo com cara de Minecraft. Ainda por código (leve, de graça):
- Árvores: tronco que afina, galhos e copa de várias bolas de folhagem com um
  shader que fura a bola com ruído (vira um monte de folhas recortado), tons
  variados, topo mais claro e balanço com o vento.
- Coqueiros: tronco curvado em gomos, folhas de palha que vergam com o peso e
  se dividem em folíolos (shader), balançando; cocos.
- Telhados de telha de barro (fileiras, canais e sombra) em parte das casas.
- Nuvens com forma de cúmulo (ruído dobrado) e luz: topo claro, barriga
  cinza, borda prateada perto do sol.
- Paredes com manchas, escorrido de chuva, sombra no pé da parede e vidro que
  reflete o céu.
- Boneco mais liso (mais segmentos).

### D-064 — Catálogo de pipas e linhas; escolher como no Pipa Combate (2026-11-25)
O Lucas mandou as telas de escolha do Pipa Combate e pediu igual. Agora o
botão COLOCAR NO ALTO abre a tela de pipas (cartões com o desenho, nome,
velocidade, força e rabiola) e, depois de escolher, a de linhas (carretel na
cor, resistência e peso); escolhida a linha, a pipa sobe.
- 48 pipas, com desenhos NOSSOS (não copiamos artes do outro jogo nem
  personagens de filme): os tipos (Flechinha, Patang, Tukkal, Volantines,
  Raia, GT, Britt, Latão, Come Rato, Pizza, Veloster...) com medidas de pipeiro
  e estampas por código (estrela, olhos, raios, xadrez, coração, V, X...).
  Raias e losangos têm papel no corpo todo; pipas de caixa têm o bico aberto.
- Os números viram física (FreeMode.kite_for): velocidade muda puxada, giro e
  freio; rabiola muda o tamanho e o peso da rabiola (as "0 m" levam uma
  curtinha de 1,5 m para a física ficar estável); força soma na resistência
  da linha no relô.
- 10 linhas fictícias (4, 10 e 24, em cores), com resistência, peso e
  grossura; a cor aparece na sua linha no céu. Sem cerol, chilena, "pó de
  ferro" ou nada de linha cortante de verdade — regra do projeto.

### D-063 — Página inicial, mapa da praia, horas do dia (2026-11-25)
O Lucas pediu gráficos melhores e leves, céu azul, sol, pôr do sol, pisos com
verniz leve, mapas e uma página inicial criativa. Tudo por código:
- Página inicial: título PIPA BRASIL com uma pipinha desenhada voando, e a
  cidade ao vivo atrás (a câmera passeia em volta das lajes, as pipas dos
  rivais voando). Botões: JOGAR, Mapa, Hora e Laboratório; o recorde aparece
  embaixo. Mapa e hora ficam guardados (user://preferencias.json).
- Horas: Manhã e Meio-dia de céu azul (sol mais alto, névoa azulada) e o Pôr do
  sol de antes.
- Mapa Praia: avenida da orla, calçadão com as ondas pretas e brancas, areia
  (mais escura e molhada perto do mar), mar com ondinhas, brilho do sol e
  espuma, coqueiros, quiosques, guarda-sóis, prédios mais altos e morros
  verdes saindo do mar. As lajes de soltar pipa são as mesmas.
- O shader do chão tinha um "return" no meio e não compilava no navegador
  (chão branco nas capturas); reescrito sem ele.
- De dia (manhã e meio-dia) sem glow e com menos luz ambiente: nas capturas
  as cores claras estouravam (chão e morros brancos).
- Na página inicial o placar, os avisos e os botões do canto somem.
- Pisos das lajes com verniz leve (brilham com o sol, sem ofuscar).
- Boneco mais arredondado (cápsulas), com mãos, olhos, cabelo e faixa na
  camisa.

### D-062 — Desistir do mergulho com poucos toques (2026-11-25)
O Lucas: dando martelão ou afundando para aparar, se desistia no meio só
conseguia voltar mandando linha; os toques mudavam pouco a trajetória. Agora,
com o bico a mais de 45° do alto, cada toque simples é um desbico PARA CIMA:
a direção do tenteio volta metade do caminho (no mínimo 20°) e o bico vai
para o lado de cima (não alterna). Do bico para baixo, uns 3 ou 4 toques
tiram a pipa. Perto do alto, o tenteio continua alternando como antes.

### D-061 — No aparo pela linha, embola também pela rabiola (2026-11-25)
O Lucas: com a avoada no seu aparo pela linha dela, dá para embolar e aparar
também pela rabiola (e vice-versa). Antes, qualquer avoada já enroscada não
embolava de novo. Agora quem já aparou pode embolar no outro pedaço (o mesmo
pedaço não embola duas vezes; outro pipeiro não embola numa avoada já
aparada). Presa também pela rabiola, ela vem rodando (D-053).

### D-060 — Tenteio traz o bico de volta para cima; mureta baixa na sua laje (2026-11-25)
O Lucas: com o bico para a direita não conseguia desbicar de volta para cima
ou para a esquerda; e a mureta da frente da sua laje tapava a pipa quando ele
afundava. Agora cada toque simples traz a direção do tenteio 20° de volta para
cima (os duplos continuam levando 30° para o lado): tenteando, o bico volta e
passa para o outro lado. Na sua laje a mureta da frente tem 25 cm.

### D-059 — Toque duplo mais rigoroso; câmera acompanha a pipa afundando (2026-11-25)
O Lucas: tenteando rápido a pipa ainda rodava com o bico para cima (toques
rápidos viravam "duplos"); e a câmera perdia a pipa quando ele afundava.
Agora o toque duplo só conta se: os dois toques vêm juntos (menos de 0,3 s)
depois de uma pausa (pelo menos 0,35 s e o dobro do intervalo do par — no
ritmo do tenteio não conta), e o bico já está para o lado (20° ou mais).
Duplos seguidos na volta continuam valendo. Câmera: pode olhar até 45° para
baixo do horizonte (antes não descia do horizonte), segue a pipa mais rápido
e o zoom ficou um pouco mais aberto (a pipa em ~7% da altura da tela).

### D-058 — Parada ou tenteando para cima, a pipa não tende a rodar (2026-11-25)
O Lucas: tenteando com o bico para cima a pipa parecia sempre querer rodar
(mais para a esquerda); ela só deve rodar quando ele leva o bico (toques
duplos) ou manda linha. O empurrão de giro do vento (spin_bias) agora só vale
mandando linha ou com folga de propósito (afrouxar/largar, usados pelos
bots) na pipa do Rio (spin_bias_only_giving); parada ou tenteando, o vento
traz o bico para cima. A raia de laboratório não muda.

### D-057 — Cenário e boneco por código (2026-11-25)
O Lucas pediu foco no visual (gráfico, boneco, cenário, chão, casas, árvores,
céu, shaders). Tudo feito por código, sem modelos externos (custo zero):
- Céu por shader: degradê de fim de tarde, sol com brilho e nuvens andando;
  névoa leve no horizonte.
- Chão por shader: ruas de asfalto com faixa tracejada, calçadas de lajota e
  terra com manchas (as ruas são as mesmas em Bairro.RUAS).
- Casas com shader de parede: reboco pintado ou tijolo aparente, janelas (às
  vezes acesas), portas, laje de concreto; muretas, ferragem saindo da laje,
  caixas d'água com tampa, antenas e varais com roupas.
- Árvores e coqueiros nas calçadas; postes com luminária e fios com barriga.
- Morros ao fundo com casinhas coladas e mato no alto.
- Boneco de peças: pele, camisa, bermuda, chinelo e boné; vira para a pipa,
  um braço vai até a mão da física (a linha), o outro segura a carretilha e
  "abraça" ao puxar. Só visual.

### D-056 — Fatiar (2026-11-25)
O Lucas explicou o "fatiar": passando a linha abraçando (puxando forte) em
cima da linha ou da rabiola de uma avoada, ela é decepada; e na RABIOLA de uma
pipa em voo também — não precisa estar avoada. Agora: com a linha em cima da
rabiola de um rival em voo, puxando acima de 3,5 m/s, ao somar 1,5 m puxados
a rabiola é fatiada no ponto de contato (o pedaço cai; a pipa segue voando com
o que sobrou). Na avoada, o decepar ao passar abraçando vale a partir de
3,5 m/s (era 5,5) e o aviso diz "fatiou". Combate só virtual, como sempre.

### D-055 — Sem lado preferido: gira para onde o bico aponta (2026-11-25)
O Lucas notou que quase tudo ia para a esquerda. Causas: o giro mandando linha
tinha sentido fixo (spin_give_sign) e a pipa do Rio tinha um torque de vento
para um lado só (spin_bias 1,0); e o toque duplo virava conforme a paridade
dos toques anteriores. Agora: mandando linha, o sentido é escolhido no começo
pelo lado em que o bico aponta (bico em pé: o do último tenteio); o torque
do spin_bias passa a seguir esse sentido; o toque duplo vira para o lado em que o bico estava antes
do 1º toque dele (bico à direita + duplo = mais para a direita).

### D-054 — Pipa mais calma sem puxar (2026-11-24)
O Lucas: tenteando, e mesmo com a tela parada, a pipa ia rápido demais "como
vento forte", e a volta fazia um círculo grande. A vela solta (sem puxar)
ganha um freio ao longo do bico (KiteDefinition.nose_drag_rate = 6/s na pipa
do Rio): a pipa não dispara sozinha para onde o bico aponta. Puxando, no
coice da largada, avoada e rebocada, o freio não vale. A puxadinha do toque
caiu de 3 m/s por 0,3 s para 1,5 m/s por 0,2 s (círculo da volta menor).

### D-053 — Aparada pela rabiola vem rodando (2026-11-24)
O Lucas: aparada pela rabiola a avoada tem que vir rodando (puxada pela
traseira, sem o cabresto segurando), diferente da aparada pela linha, que
vem reta (D-037). O combate marca a avoada como enroscada pela rabiola
(Flyer.caught_by_tail) e a pipa rebocada assim gira 300°/s em volta da
vareta central (parafuso), com o resto do balanço limitado a 60°/s.

### D-052 — Duplos seguidos viram para o mesmo lado; bico segura 3 s (2026-11-24)
No celular o bico só ia para a direita e para a esquerda: o 1º toque de cada
duplo troca de lado (é tenteio), então o duplo seguinte virava para o lado
contrário e desfazia o anterior. Agora um duplo até 1,5 s depois de outro
continua virando para o MESMO lado (60°, 90°, 120°, 150°, 180°...), e o bico
fica onde parou por 3 s depois do último toque (era 1,5 s), dando tempo de
puxar.

### D-051 — Toque duplo no iPhone (2026-11-24)
No celular do Lucas o toque duplo não virava o bico. Provável causa: o Safari
do iPhone usa o toque duplo para dar zoom e engole o segundo toque, ou os
toques dele vêm com mais de 0,2 s. Agora a página do jogo bloqueia o zoom e
os gestos do Safari (viewport sem zoom, touch-action: none, dblclick e
gesturestart bloqueados), o intervalo do duplo subiu para 0,3 s e aparece um
aviso "↻ 30°" quando o toque duplo é reconhecido.

### D-050 — Toque duplo vira a direção de 30 em 30 (2026-11-24)
O Lucas aprovou o tenteio da D-049 ("é exatamente assim que se tenteia") e
explicou o que faltava: com os cliques dá para pôr o bico em qualquer direção
(360°), de 30 em 30 a cada dois cliques. Agora o toque duplo (dois toques com
menos de 0,2 s) faz a direção em volta da qual o bico balança andar 30° para
o lado do toque (PilotInput.kick_base_shift). Toques simples continuam só
balançando; 12 duplos = uma volta.

### D-049 — Tenteio balança em volta da direção, não roda (2026-11-24)
O Lucas: dando vários toques a pipa ainda girava; girar é consequência, não o
tenteio. Agora cada toque leva o bico ~30° para um lado e o próximo para o
outro, sempre em volta da direção em que o bico estava quando o tenteio
começou (o alvo nunca acumula). Tocar rápido = a pipa tenteia (balança o
bico), sem rodar. Para virar a pipa para outra direção (ou rodar), manda
linha — ela gira — e tenteia de novo na direção nova; puxa quando o bico
apontar para onde quer ir. Sai o toque duplo da D-047 (e a espera de 0,22 s).

### D-048 — Rabiola de longe fina (2026-11-24)
De longe a rabiola ainda parecia grossa: as fitinhas tinham tamanho mínimo na
tela (uns 6 px). Agora as fitinhas têm o tamanho de verdade (5 cm para cada
lado) e somem quando ficariam menores que ~1 px, sobrando o barbante, que
tem metade da espessura mínima da linha e é um pouco transparente.

### D-047 — Bico sem papel; tenteio de 30° que não roda sozinho (2026-11-24)
O Lucas: o bico das pipas (acima da vareta de cima) não tem papel — só a
linha da ponta às pontas da vareta; agora o desenho (3D e prévia) começa na
vareta de cima e o bico mostra só essa linha.
Tenteio: toques simples, mesmo rápidos, não podem fazer a pipa rodar. Agora
cada toque simples muda o bico ~30°, alternando o lado; o toque DUPLO (dois
toques em menos de 0,22 s) segue 60° no mesmo sentido do último tenteio — é
assim que se leva o bico para baixo ou dá a volta (6 duplos = 360°). Para
distinguir, o toque simples espera 0,22 s antes de agir. Substitui a regra
de toques seguidos da D-039/D-041.

### D-046 — Largada de volta ao jeito da 0.15 com coice; prévia dos modelos (2026-11-24)
O Lucas achou a largada da 0.16 esquisita (a linha frouxa como se tivesse
soltado da mão). A linha não corre mais sozinha na largada e o ar só perde
40% durante o coice; o coice fica: tranco de 4 m/s e 40 m/s² caindo a zero em
0,45 s, para onde o bico aponta (nunca de volta para a mão).
Os modelos "pareciam iguais": no céu a pipa ocupava uns 6% da tela e o
formato não aparecia. Agora a tela de pipa na mão mostra a prévia do modelo
(formato com as medidas, estampa e varetas) e a câmera em 1ª pessoa aproxima
mais (a pipa ocupa uns 10% da altura).

### D-045 — Modelos de pipa com medidas reais; rabiola maior e fitinhas finas; largada forte (2026-11-24)
O Lucas mandou moldes da Voar Pipas e a página "Pipas e medidas" da Escola de
Pipeiros. Agora há 20 modelos (GT, Pizza, Come Rato, Mucha Mucha, Carrapeta,
Britt, Charutinho, Palito, Bicuda, Gigante, Vanda, Latão, Francesinha, Lápis,
Charuto, Batata, Bicão…), cada um com as medidas do pipeiro (vareta central,
vareta de cima e de baixo, bico, caixa e rabeta), desenhados na escala da
pipa da física, com a estampa do molde (aproximada) e as varetas. Só visual
por enquanto: todos voam com a física da pipa do Rio. Flechinha e Veloster
não estão nas tabelas.
Rabiola: 5 m, 7,5 g, 24 pedaços; fitinhas com ~1 px de largura e ~3 px para
cada lado (antes cresciam demais com a distância e pareciam mais grossas que
a pipa).
Largada: tranco de 9 m/s e coice de 70 m/s² caindo a zero em 0,6 s e a linha corre junto (até 12 m/s; era
8 m/s no começo); vale puxar e mandar linha até 0,5 s depois.

### D-044 — Aparo no meio-termo; rabiola comprida, fina e leve (2026-11-24)
Pedido do Lucas (vídeos do Manda Busca e Pipa Combate):
- Aparada: puxar num ritmo normal traz para a mão sem decepar. Decepar exige
  puxar RÁPIDO (acima de 3,5 m/s) e MUITOS metros: 3 m puxados rápido em
  contato (o acumulado cai 1,5 m/s quando para). Substitui o tempo da D-036.
- Sair do aparo: tenteando sem parar (toques com menos de 0,6 s entre eles)
  por uns 3 s, o embolo solta e a avoada segue avoada.
- Pipa avoada no chão ainda pode ser aparada por 5 s (a linha e a rabiola
  ainda caem); só depois vira perdida.
- Rabiola da pipa do Rio: 3,5 m, 6,5 g, 18 pedaços, 1,2 cm de largura de
  arrasto — comprida, fina e leve, balança bastante; desenho com barbante fino
  e fitinhas pequenas.
Ficam para depois (registrados em progresso.md): enroscar e cortar na rabiola
do rival; o plano de física do tenteio do texto do Lucas.

### D-043 — Desenhos de pipa e rabiola de fitinhas (2026-11-24)
O Lucas pediu para focar no visual: pipas como as dos vídeos (raias e
peixinhos com estampas fortes) e rabiola de fitinhas (antes era só uma linha
colorida). Só visual, a física não muda. Oito desenhos em
game/views/estilos_pipa.gd (forma raia ou peixinho + estampa: borda, xadrez,
olho, losango, metades, cruz, listras, quadrantes); a vela é uma grade 14×14
colorida pela estampa e o peixinho ganha rabo de peixe. A rabiola é um
barbante fino com três fitinhas atravessadas por pedaço, nas cores do desenho,
balançando. Escolha do desenho na tela "pipa na mão"; cada bot tem o seu.
O tenteio fica como está (D-042) por enquanto, a pedido do Lucas.

### D-042 — Tenteio que murcha e vai para a frente; coice da largada (2026-11-24)
O Lucas mandou um vídeo de pipa de verdade: no tenteio um lado da pipa murcha
(ela inclina) e ela vai para a frente, para onde foi desbicada — não gira como
ponteiro de relógio. Agora, enquanto o bico segue o ângulo do tenteio, a pipa
inclina em torno do eixo do bico até 20° para o lado da curva (o vento a leva
para onde o bico vai) e a puxadinha do toque voltou a 3 m/s por 0,3 s.
Largada: puxar forte (mais de 2,5 m/s) e mandar linha até 0,35 s depois dá um
coice: empurrão para a frente na direção do bico (30 m/s² caindo a zero em
0,4 s), sem girar nos primeiros 0,25 s, e conta como largada no relô.

### D-041 — Tenteio por ângulo-alvo: 36° por toque, para exato (2026-11-24)
O Lucas ainda achou injogável e explicou (com um texto de apoio): cada toque
gira o bico um passo fixo; o bico vai até lá suave e PARA exato (sem passar,
para conseguir apontar o bico para baixo e aparar). Toque simples alterna o
sentido (desbica para um lado e para o outro); toque duplo continua no mesmo
sentido, e seguindo com toques duplos a pipa dá a volta num círculo curto.
Regra: cada toque soma ±36° ao ângulo-alvo do bico (10 toques = 360°,
ajustável na tela: "Giro por toque"); o bico persegue o alvo com ganho 14/s
(no máximo 420°/s); o alvo vale até 1,5 s depois do último toque e então o
vento traz o bico de volta. A puxadinha do tenteio ficou pequena (1,2 m/s
por 0,2 s), para o círculo ser curto. Substitui o impulso da D-040.

### D-040 — Tenteio redondo: impulso de giro freado pelo ar (2026-11-24)
O Lucas achou o giro "quadrado" (mandou um texto explicando o Pipa Combate). O
tenteio era um giro a velocidade fixa por 0,08 s e uma parada seca. Agora cada
toque SOMA um impulso de giro (330°/s) que o ar freia aos poucos (6/s): o bico
gira uns 55° num arco que começa rápido e desacelera suave; toques seguidos
somam o giro que ainda resta (arco contínuo na volta com toques duplos). Mandar
linha ou puxar forte zera o que resta. Depois que o giro acaba, o bico fica
onde parou até 1,2 s do toque e então o vento o traz de volta.

### D-039 — Toque duplo para dar a volta; toque simples como antes (2026-11-24)
A D-038 estragou o tenteio (toques rápidos giravam sem parar). O Lucas explicou
o Pipa Combate: o toque simples continua como antes (cada toque para um lado,
o pulo vai para o lado do céu); a volta sai com TOQUES DUPLOS — uns 6 toques
duplos rápidos dão a volta inteira. Regra: o 2º toque do duplo (até 0,3 s
depois do 1º) dá um empurrãozinho no mesmo sentido do 1º; se outro toque
duplo vier até 0,9 s depois, ele continua no mesmo sentido (cerca de 60° por
toque duplo). O sentido da volta vai no comando (PilotInput.kick_spin), a
mesma interface dos bots. Fica da D-038 só: a avoada mais devagar e o bico que
segura o ângulo logo depois do tenteio.

### D-038 — Volta de 360° no tenteio; avoada mais devagar (2026-11-24)
Pedido do Lucas (vídeo do Pipa Combate): o tenteio tem que levar o bico para
onde ele quiser, inclusive dar a volta inteira. Regra: toques seguidos (menos de
0,45 s entre eles) continuam girando para o MESMO lado — vários toques dão a
volta; depois de uma pausa, o próximo toque vai para o outro lado (desbicar da
esquerda para a direita). A avoada vai embora mais devagar: força do vento
×0,14 (era 0,2) e freio do ar 3,5/s (era 2,5/s) — devagar, mas não parada
(teste: entre 2 e 22 m em 5 s).

### D-037 — Pipa na mão, tirar do alto, aparada reta, tenteio com puxadinha (2026-11-24)
Pedido do Lucas (vídeo da 0.12.1), como no Pipa Combate:
- O jogo começa com a pipa NA MÃO: a tela mostra a escolha de pipa (por
  enquanto a do Rio em três montagens de rabiola, até chegarem as fotos das
  brasileiras) e de linha (Leve, Comum, Forte — linhas fictícias do jogo, que
  mudam só resistência, espessura e peso) e o botão "COLOCAR NO ALTO".
- Tirar do alto: puxando a linha toda (até o mínimo de 5 m) a pipa chega na mão; o
  que estiver enroscado na sua linha, mesmo perto do cabresto, vai para o
  estoque. Depois do corte ou da queda, também volta para a escolha.
- A aparada (rebocada) vem reta: o giro no próprio plano é zerado.
- Tenteio: pulo de uns 55° e, logo depois, uma puxadinha de 0,45 s (força
  na direção do bico, como a da puxada), para a pipa já sair para o lado.
- O aviso de pipa enroscada é recontado a cada passo (não fica preso).

### D-036 — Tenteio que muda a direção; aparar mais fácil (2026-11-24)
O Lucas achou o tenteio lerdo (não mudava a direção) e o decepar fácil demais.
Tenteio: pulo de uns 45° (560°/s por 0,08 s); o vento só traz o bico de volta
depois de 0,6 s sem tenteio (o bico fica parado onde foi; mola 4/s) — dá tempo de puxar
para o lado escolhido. Aparar: embola com 0,25 s girando em contato, e
tenteando também conta como girar. Decepar exige puxar forte (acima de 5,5 m/s)
SEGUIDO por 0,35 s em contato; um tranco não decepa.

### D-035 — Tenteio (2026-11-24)
O Lucas descreveu o tenteio do Pipa Combate: toques curtos dão impulsos de
rotação curtos, cada toque para um lado, sem puxar a pipa; parando de tocar,
o vento traz o bico de volta para cima; amortecimento alto (movimento seco).
Agora: toque = pulo de uns 25° (310°/s por 0,08 s), alternando o lado a cada
toque (no PC, Q/E escolhem o lado, Espaço alterna); quase sem mexer na linha.
Solta, a pipa volta o bico para cima com uma "mola" de 5/s. Para ir para um
lado: tenteia até o bico apontar e puxa (deslizar para baixo trava o bico e
arranca). No relô, cada tenteio também serra (como 2 m/s de linha correndo, por
0,3 s). Todos os bots tenteiam de vez em quando. Substitui o desbico da D-034.

### D-034 — Desbico para o lado, largada e pressão da puxada (2026-11-24)
Pedido do Lucas, comparando com o Pipa Combate 4. Desbico: cada toque joga o
bico para um lado — o lado do toque (metade esquerda ou direita da tela; no PC
Q/E ou setas) — uns 45° em 0,15 s (300°/s), e então o tranco trava e a mão
recolhe a folga: a pipa arranca para lá. Largada: com a linha laçada, se você
vinha com pressão (tensão recente acima de 8 N, bem mais que o voo parado) e solta de uma vez (manda
linha acima de 1,5 m/s), a sua linha serra com o dobro de força; aviso
"LARGADA!". Pressão da puxada (`pull_assist`, 0,12 N por m/s): com a linha
esticada, puxar empurra a pipa na direção do bico, para ela ir bem mais longe
para os lados. Avoada ainda mais lenta (força do ar a 20%, mais arrasto).

### D-033 — Desbico trava e arranca; aparar com mais calma (2026-11-24)
O Lucas aprovou o giro mandando linha (pediu só um pouco mais rápido: 100°/s
por m/s, teto 360°/s) e explicou o desbico: é para mudar a direção para o lado
que ele quer. Toque = tranco curto: o giro trava na hora (puxando, o giro é
zerado), a mão recolhe a folga a 4 m/s até a linha esticar e a pipa arranca
reta para onde o bico parou. Para escolher o lado: manda linha, ela gira, toca
quando o bico apontar. Avoada: força do ar a 35%, mais arrasto e giro limitado
a 90°/s (rebocada, 60°/s); não decepa nos 4 s depois do corte e decepar exige
puxar acima de 5,5 m/s.

### D-032 — Giro conforme o dedo; avoada mais lenta; decepar com calma (2026-11-23)
Depois do vídeo do Lucas: o giro mandando linha agora é proporcional à
velocidade da linha saindo (80°/s por m/s, teto padrão 300°/s, ajustável):
deslizar devagar gira devagar e dá para acertar o bico. O toque de desbico
para o embalo da carretilha (sem giro depois). A pipa avoada solta (sem
ninguém aparando) desce mais devagar: força do ar a 55% e arrasto extra, para
dar tempo de aparar. Uma avoada recém-cortada (2,5 s) não é decepada, e decepar
exige puxar acima de 4,5 m/s (era 3).

### D-031 — Mandar linha deslizando; desbico endireita (2026-11-23)
O Lucas corrigiu: mandar linha é DESLIZAR o dedo para cima (não segurar), e
desbicar não vira a pipa para um lado — na vida real, o desbico tira a pipa
de embicada: a folga curta deixa ela se endireitar, bico para cima. Agora:
deslizar para cima solta linha no ritmo do dedo e a carretilha embala (segue
soltando, cada vez menos, por até 0,6 s); a pipa gira enquanto a linha corre
(giro da D-030). Toque: folga de 0,4 s em que o bico volta para cima pelo
caminho mais curto (até 500°/s); com o bico já para cima, nada muda. Segurar
o dedo parado não faz nada.

### D-030 — Descarregar redondo e desbico de verdade (2026-11-23)
O Lucas achou o giro "quadrado" (velocidade constante, como hélice), que só
girava enquanto deslizava o dedo, e o toque não mudava o bico. Agora:
segurar o dedo = descarregar (linha corre 2,5 m/s); o giro acelera aos poucos
(2500°/s²) até o teto (720°/s, ajustável), e varia com o bico: até 40% mais
rápido com o bico para baixo, mais devagar com ele para cima. Soltar o dedo:
freio do giro proporcional à vareta envergada (a linha volta a esticar).
Deslizar para baixo: puxa e freia o giro forte. Toque: desbico — o bico dá um
pulo de uns 60° (400°/s por 0,2 s) e firma; cada toque, outro pulo. A força
lateral caiu para 2: a pipa derrapa um pouco e faz curvas em arco. O
bombeamento automático e o balanço senoidal sugeridos nos textos que o Lucas
mandou ficaram de fora por ora: a linha (barriga, atraso) e o vento já são
físicos no jogo.

### D-029 — Aparar: embolar, decepar e rebocar (2026-11-23)
Regras pedidas pelo Lucas. A linha solta e a rabiola da avoada colidem. Só
encostar não prende: o embolo se forma enquanto quem apara está mandando linha
(girando) com contato recente (até 0,3 s atrás), e embola ao somar 0,4 s.
Puxando rápido (linha correndo na mão acima de 3 m/s) em contato ou com a
avoada já embolada, decepa a linha solta ou a rabiola no ponto de contato: o
pedaço cai solto e a avoada escapa (no máximo um decepar a cada 0,5 s).
Embolada, a avoada é rebocada como pêndulo amortecido: folga de 0,3 m no ponto
embolado, força do ar reduzida, muito arrasto e giro limitado a 120°/s. Puxando
devagar chega à mão: aparada, entra no estoque de quem aparou.

### D-028 — Giro de dois estados (2026-11-23)
Pedido explícito do Lucas, como mecânica de jogo (exceção consciente ao modelo
puramente aerodinâmico do giro da D-026): mandando linha com a mão, a
velocidade de giro no plano da pipa é imposta direto (`spin_give_rate_deg`,
padrão 900°/s, ajustável na tela em "Ajustes"); puxando (deslizar para baixo,
toque, puxão), o giro é zerado na hora a cada subpasso (trava seca). Sem
comando, a física normal (rabiola, vareta) segura o bico. Translação, linha,
vento e colisões continuam 100% físicos. Os bots não usam o gesto de mandar
linha com a mão e continuam com o giro físico.

### D-027 — Laço e relo (2026-11-23)
Pedido do Lucas: linhas que se cruzam não podem se soltar do nada; alguém
sempre corta. Quando duas linhas em voo se encostam, ficam laçadas: a cada
subpasso o ponto de encontro é procurado de novo perto do anterior e as linhas
são mantidas encostadas até uma romper. Cada linha tem a sua integridade no
laço. Regra do relo: a linha que corre (quem está dando ou puxando linha, medido
na mão) gasta a outra; um pouco de desgaste para as duas sempre. A rabiola não
desgasta linha (só enrosca). A linha rompe no ponto de encontro e o corte conta
para o dono da outra linha. Tipos de linha com nomes reais de material cortante
não entram no jogo (regra do projeto); combate é só virtual.

### D-026 — Pipa do Rio (2026-11-23)
Regras pedidas pelo Lucas, feitas na física (não em animação):
rabiola de 2 m; força lateral contra a derrapagem (`side_force_coefficient`):
com a linha esticada a pipa vai na direção da espinha, como flecha; dando
linha (descarregando) a vareta relaxa (`flex_reference_tension` 2,5 N) e a
pipa gira num ritmo constante, limitado a 240°/s (`spin_rate_max_deg`; era
170°/s, o Lucas achou lento); um toque é um puxão curto em que a mão recolhe
a folga até a linha esticar (até 0,5 s): a vareta enverga e o amortecimento
firme (`spin_damping_taut` 150/s) trava o bico; a pipa arranca reta. Dar
linha vai até 4 m/s, 2,5 m por altura de tela deslizada. Calibrada
no protótipo (`tools/prototipo/fase4/exp8.py` a `exp11.py`). Testes:
`tests/scenarios/test_pipa_rio.gd`. Limite conhecido: puxando para o lado por
4 s ela chega a uns 55° de azimute (o Lucas quer 90° ou mais).

### D-025 — Gestos do pipeiro e modo livre (2026-11-23)
Pedido do Lucas depois de testar no iPhone: nada de botões. Deslizar o dedo
para baixo puxa linha com a mão no ritmo do dedo (1,6 m de linha por altura de
tela, até 6 m/s); para cima dá linha, e soltando o dedo no embalo a carretilha
continua girando por quase 1 s; toques rápidos disparam o desbicar (folga
curta). Os gestos viram `PilotInput.haul_speed` (movimento da mão, D-003) e o
impulso de desbicar, a mesma interface dos bots. O modo livre (`FreeMode`) não
tem tempo: placar de cortes e aparadas, pipa nova 3 s depois do corte, a cortada
fica no céu como avoada para quem aparar. A ruptura agora informa quem cortou
(último pipeiro cuja linha encostou na linha rompida). A partida cronometrada
(D-021) foi removida.

### D-024 — Pipa reta: a vareta envergada segura o bico (2026-11-23)
A raia sem rabiola girava fácil demais e, ao puxar, voltava a apontar para
cima no meio do caminho (a trajetória fazia curva). Novo parâmetro
`spin_damping_taut` (20/s na raia sem rabiola): amortecimento do giro no plano
da pipa proporcional ao quadrado do quanto a vareta está envergada, aplicado de
forma implícita (decaimento exato, estável). Com a linha esticada o bico fica
onde está e a pipa vai reta para onde ele aponta; com a linha frouxa o efeito
some e o bico gira (cada toque gira uns 15° a 30°, sempre para o mesmo lado,
como antes). Testado no protótipo com 4 valores (0, 10, 20 e 40/s) e com
alternativas descartadas: estabilidade pelo fluxo (derruba a pipa no
lançamento, nos dois sinais) e tranco lateral da mão (a linha não transmite).
Experimento no CI: `tests/scenarios/test_pipa_reta.gd`. Referência de
regressão da raia sem rabiola regenerada e revisada.

### D-023 — Celular deitado (2026-11-23)
Revoga a tela em pé da D-021. Os vídeos do Manda Busca estavam em pé porque
eram recortes para o TikTok; o jogo é deitado. Tela 1280×720, orientação
paisagem com sensor.

### D-022 — iPhone pelo navegador (2026-11-23)
O celular do Lucas é iPhone. App nativo de iOS exige Mac, Xcode e a conta paga
da Apple (US$ 99/ano), fora do custo zero. Caminho escolhido: a exportação Web
(Compatibility, sem threads) publicada no GitHub Pages a cada entrega no main.
O Pages gratuito exige repositório público; o Lucas escolheu tornar o
repositório público. Desempenho no Safari do iPhone ainda a medir.

### D-021 — Partida melhor de 3, em pé, na laje (2026-11-23)
A cena principal passa a ser a partida (`game/match/partida.gd`); o
laboratório vira `scenes/lab/lab.tscn`, aberto pelo botão "Lab". Tela em
retrato (720×1280). A partida tem 3 jogos, inspirados no formato do Manda
Busca: suba a pipa (começa com 8 m de linha; ganha quem chegar a 30 m acima da
laje), a mais alta sem corte (o contato existe, mas não desgasta) e valendo
corte (cortou, manda busca). As regras ficam em `MatchRules`, separadas da
tela, para testar partidas inteiras entre bots sem gráficos. As lajes são
só visuais por enquanto: a física ainda usa o chão em y = 0 (colisão com
lajes e casas fica para a Fase 7). Controles: 6 botões grandes embaixo, com
vários dedos ao mesmo tempo; teclado no PC.

### D-020 — Aparagem ("manda busca") e nova prioridade (2026-11-23)
Quando um contato acontece entre a linha (pedaço que ficou com a pipa) ou a
rabiola de uma pipa avoada e a linha ou a rabiola de um pipeiro em voo, cria-se
um enrosco: uma restrição de distância zero entre a partícula da avoada e um
ponto fixo no MATERIAL da linha de quem aparou (coordenada a partir da ponta de
fora, que não muda ao recolher). Recolhendo, esse ponto vem até a mão; a pipa é
aparada quando o enrosco chega a 3 m da mão (a linha da avoada está na mão).
Se quem aparou tiver a linha cortada, o enrosco se desfaz. Avoada que toca o
chão sem enrosco é perdida. Por ora o primeiro enrosco vale (sem disputa pela
mesma avoada) e o contato continua sem atrito; enrosco é uma regra do jogo,
não uma simulação de nó.

Com o Manda Busca como referência, a ordem muda: cortar e aparar passam a ser o
centro do jogo, a fatia vertical (Fase 5) acontece na laje de um bairro em vez
de um terreno aberto, e o combate livre offline com até 8 pipas (bots) entra
antes do online. Online com 8 jogadores continua por último e terá de ser
gratuito (um jogador hospeda a sala), porque servidor dedicado custa dinheiro.

### D-018 — Raia sem rabiola sem estabilidade direcional da vareta (2026-11-23)
O termo de estabilidade direcional criado na D-012 alinhava a espinha da pipa
com o fluxo de ar no plano da vela. Com a pipa parada no céu, esse fluxo vem do
lado da base para o bico, então o termo virava o bico para baixo e a pipa
mergulhava em 2 s mesmo sem vento turbulento: nenhum controle conseguiria
pilotá-la, e foi por isso que o controlador da Fase 2 falhou. Testei o termo
com o sinal oposto e com o fluxo só do movimento da pipa; os dois pioravam.
Sem o termo (`bow_stability = 0`), a raia sem rabiola fica parada a 60° com o
bico para cima, gira com a linha frouxa e corre para onde o bico aponta quando
puxada, e volta a apontar para cima em cerca de 0,5 s. O mecanismo continua no
código para outros modelos.

Consequência: como ela só gira para um lado (`spin_bias`) e se endireita
rápido, atravessar o céu de lado exige girar e arrancar várias vezes. O bot da
Fase 4 mantém a pipa no ar com segurança, mas acerta o lado do céu pedido só
cerca de metade das vezes. Melhorar a mira é a primeira tarefa antes da
Fase 5.

### D-019 — Bot: percepção limitada e mesma interface (2026-11-23)
O bot lê do próprio pipeiro só posição da pipa no céu, ângulo do bico, tensão
na mão e comprimento de linha, com atraso de reação e ruído que dependem da
dificuldade. Não lê o vento, velocidades exatas nem nada do adversário além
do que se vê. Escreve só no `PilotInput`, como o jogador. A dificuldade muda
só a percepção e a precisão, nunca a física.

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
