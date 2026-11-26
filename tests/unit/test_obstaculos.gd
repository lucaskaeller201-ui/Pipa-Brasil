extends "res://tests/test_case.gd"
## D-079: a linha e a pipa não atravessam casas, telhados e árvores.

const DT := 1.0 / 120.0


## Linha presa nos dois lados de uma casa, frouxa: com o peso ela desce e
## dobra por cima do telhado, sem atravessar a casa.
func test_linha_dobra_por_cima_da_casa() -> void:
	var w := SimWorld.new()
	w.wind = WindField.new(0.0, 0.0, 1)
	var obs := Obstacles.new()
	obs.add_caixa(Vector3(0.0, 2.0, 0.0), Vector3(4.0, 4.0, 6.0))
	w.obstacles = obs
	var c := w.add_fixed_line(Vector3(-5.0, 6.0, 0.0), Vector3(5.0, 6.0, 0.0), 40)
	c.scale_rest(1.25)
	for k in roundi(4.0 / DT):
		w.step(DT)
	var menor := 99.0
	var dentro := 0
	for p in c.pos:
		if absf(p.x) < 1.9 and absf(p.z) < 2.9:
			menor = minf(menor, p.y)
		if not obs.contato(p).is_empty():
			dentro += 1
	print("      [linha sobre a casa] ponto mais baixo em cima da casa: %.2f m (telhado em 4 m); %d pontos dentro" % [menor, dentro])
	assert_true(menor > 3.9, "fica em cima do telhado (%.2f m)" % menor)
	assert_eq(dentro, 0, "nenhum ponto dentro da casa")


## Pipa voando e uma casa logo abaixo dela: puxando a linha, a pipa encosta
## na casa e não entra.
func test_pipa_puxada_nao_entra_na_casa() -> void:
	var w := SimWorld.create_flight(WindField.new(5.0, 0.0, 2), KiteDefinition.pipa_rio(), 25.0, 45.0, 0.0, 4, true, 3.0)
	for k in roundi(6.0 / DT):
		w.step(DT)
	var f: Flyer = w.flyers[0]
	var k0 := f.kite.position
	var obs := Obstacles.new()
	obs.add_caixa(Vector3(k0.x, k0.y * 0.5 - 2.0, k0.z + 1.0), Vector3(10.0, k0.y - 4.0, 8.0))
	w.obstacles = obs
	var pior := 0.0
	f.input.haul_speed = 2.0
	for k in roundi(4.0 / DT):
		w.step(DT)
		for c in f.kite.definition.corners:
			var ct := obs.contato(f.kite.world_point(c))
			if not ct.is_empty():
				pior = maxf(pior, float(ct[1]))
	print("      [pipa puxada contra a casa] maior entrada de um canto da pipa: %.3f m" % pior)
	assert_true(pior < 0.1, "a pipa não entra na casa (%.3f m)" % pior)


## Copa de árvore agarra: o que encosta quase não escorrega; telhado é liso.
func test_copa_de_arvore_agarra() -> void:
	var obs := Obstacles.new()
	obs.add_bola(Vector3.ZERO, 2.0, 0.1)
	obs.add_caixa(Vector3(10.0, 0.0, 0.0), Vector3(4.0, 4.0, 4.0), 0.9)
	var arv := obs.resolver(Vector3(0.3, 1.9, 0.0), Vector3(-0.2, 2.1, 0.0))
	var tel := obs.resolver(Vector3(10.3, 1.9, 0.0), Vector3(9.8, 2.1, 0.0))
	print("      [atrito] na copa andou %.2f m de lado; no telhado %.2f m" % [absf(arv.x + 0.2), absf(tel.x - 9.8)])
	assert_true(absf(arv.x + 0.2) < 0.2, "na copa quase não escorrega")
	assert_true(absf(tel.x - 9.8) > 0.3, "no telhado escorrega")


## O cenário do jogo registra casas, postes e árvores como obstáculos.
func test_bairro_registra_obstaculos() -> void:
	var B = load("res://game/world/bairro.gd")
	var raiz := Node3D.new()
	B.criar(raiz, 6, 7)
	var obs: Obstacles = B.obstaculos
	print("      [obstáculos do bairro] %d caixas, %d copas, %d hastes; até %.0f m de altura" % [obs.caixas.size(), obs.bolas.size(), obs.hastes.size(), obs.altura_max])
	assert_true(obs.caixas.size() > 80, "casas e lajes")
	assert_true(obs.bolas.size() > 10, "copas de árvore")
	assert_true(obs.hastes.size() > 20, "postes e troncos")
	raiz.free()



## D-079: a linha apoia nas águas do telhado (não atravessa a parte de cima).
func test_linha_escorrega_no_telhado_de_duas_aguas() -> void:
	var w := SimWorld.new()
	w.wind = WindField.new(0.0, 0.0, 1)
	var obs := Obstacles.new()
	# telhado com cumeeira ao longo de z, de 3 m a 5 m de altura
	obs.add_telhado(Vector3(0.0, 3.0, 0.0), 6.0, 2.0, 8.0, false)
	w.obstacles = obs
	var c := w.add_fixed_line(Vector3(-5.0, 6.0, 0.0), Vector3(5.0, 6.0, 0.0), 40)
	c.scale_rest(1.25)
	for k in roundi(4.0 / DT):
		w.step(DT)
	var dentro := 0
	var no_meio := 0.0
	for p in c.pos:
		var ct := obs.contato(p)
		if not ct.is_empty() and float(ct[1]) > 0.01:   # apoiado na água conta como fora
			dentro += 1
		if absf(p.x) < 0.3:
			no_meio = maxf(no_meio, p.y)
	print("      [linha no telhado] %d pontos dentro; na cumeeira a %.2f m (cumeeira em 5 m)" % [dentro, no_meio])
	assert_eq(dentro, 0, "nenhum ponto dentro do telhado")
	assert_true(no_meio > 4.85, "a linha passa por cima da cumeeira")
