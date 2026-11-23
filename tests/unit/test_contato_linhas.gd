extends "res://tests/test_case.gd"
## LineContact: pontos mais próximos, grade espacial e travessias aleatórias.

const H := 1.0 / 480.0
const RADIUS := 0.02


func test_pontos_mais_proximos_de_segmentos_cruzados() -> void:
	var st := LineContact.closest_params(Vector3(-1, 0, 0), Vector3(1, 0, 0), Vector3(0, -1, 0.5), Vector3(0, 1, 0.5))
	assert_near(st.x, 0.5, 1e-6)
	assert_near(st.y, 0.5, 1e-6)


func test_pontos_mais_proximos_fora_do_segmento_saturam() -> void:
	var st := LineContact.closest_params(Vector3(0, 0, 0), Vector3(1, 0, 0), Vector3(3, -1, 0), Vector3(3, 1, 0))
	assert_near(st.x, 1.0, 1e-6)
	assert_near(st.y, 0.5, 1e-6)


func test_grade_encontra_pares_proximos_e_ignora_o_mesmo_grupo() -> void:
	var a := _linha(Vector3(-3, 2, 0), Vector3(3, 2, 0), 6)
	var b := _linha(Vector3(0, -1, 0.01), Vector3(0, 5, 0.01), 6)
	var c := _linha(Vector3(0, -1, 50.0), Vector3(0, 5, 50.0), 6)
	var pares := LineContact.find_pairs([a, b, c], PackedInt32Array([0, 1, 2]), RADIUS * 2.0)
	var tem_ab := false
	var tem_c := false
	for p in pares:
		if (p[0] == 0 and p[2] == 1) or (p[0] == 1 and p[2] == 0):
			tem_ab = true
		if p[0] == 2 or p[2] == 2:
			tem_c = true
	assert_true(tem_ab, "A e B se cruzam")
	assert_false(tem_c, "C está longe")
	var mesmos := LineContact.find_pairs([a, b], PackedInt32Array([0, 0]), RADIUS * 2.0)
	assert_eq(mesmos.size(), 0, "mesmo grupo não colide")


func test_contato_empurra_as_linhas() -> void:
	var a := _linha(Vector3(-3, 2, 0), Vector3(3, 2, 0), 6)
	var b := _linha(Vector3(0, -1, 0.005), Vector3(0, 5, 0.005), 6)
	var forca := LineContact.solve_pair(a, 2, b, 2, RADIUS, H, 0.0)
	assert_true(forca > 0.0)
	var st := LineContact.closest_params(a.pos[2], a.pos[3], b.pos[2], b.pos[3])
	var dist := a.pos[2].lerp(a.pos[3], st.x).distance_to(b.pos[2].lerp(b.pos[3], st.y))
	assert_near(dist, RADIUS, 1e-4, "separadas pelo raio de contato")


func test_500_cruzamentos_aleatorios_sem_atravessar() -> void:
	# Linha A horizontal e flexível; linha B inclinada, com as pontas movidas
	# através de A em ângulos, velocidades (0,5 a 15 m/s) e posições aleatórias.
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	var falhas := 0
	var exemplo := ""
	var casos := 500
	var inicio := Time.get_ticks_usec()
	for caso in casos:
		var ang := rng.randf_range(0.3, PI - 0.3)
		var speed := rng.randf_range(0.5, 15.0)
		var off := rng.randf_range(-1.0, 1.0)
		var n := 8
		var a := _linha(Vector3(-3, 2, 0), Vector3(3, 2, 0), n)
		var dir_b := Vector3(cos(ang), sin(ang), 0.0)
		var centro := Vector3(off, 2.0, 0.6)
		var b := _linha(centro - dir_b * 3.0, centro + dir_b * 3.0, n)
		var passos := int(1.2 / speed / H) + 1
		var atravessou := false
		for k in passos:
			var z := 0.6 - speed * H * (k + 1)
			for c: ParticleChain in [a, b]:
				for i in c.pos.size():
					c.prev[i] = c.pos[i]
					if c.inv_mass[i] > 0.0:
						c.vel[i] += Vector3(0.0, -9.81 * H, 0.0)
						c.pos[i] += c.vel[i] * H
			b.pos[0] = Vector3(b.pos[0].x, b.pos[0].y, z)
			b.pos[n] = Vector3(b.pos[n].x, b.pos[n].y, z)
			for it in 4:
				a.solve_segments(H)
				b.solve_segments(H)
				for p in LineContact.find_pairs([a, b], PackedInt32Array([0, 1]), RADIUS * 2.0):
					LineContact.solve_pair(a if p[0] == 0 else b, p[1], b if p[2] == 1 else a, p[3], RADIUS, H, 0.0)
			for c: ParticleChain in [a, b]:
				for i in c.pos.size():
					c.vel[i] = (c.pos[i] - c.prev[i]) / H * 0.999
			for i in n:
				for j in n:
					if LineContact.crossed_between(a, i, b, j):
						atravessou = true
			if atravessou:
				break
		if atravessou:
			falhas += 1
			if exemplo.is_empty():
				exemplo = "ângulo %.2f rad, %.1f m/s, deslocamento %.2f m" % [ang, speed, off]
	print("      [cruzamentos] %d casos, %d travessias, %.1f s" % [casos, falhas, (Time.get_ticks_usec() - inicio) / 1e6])
	assert_eq(falhas, 0, "primeira travessia: %s" % exemplo)


func _linha(inicio: Vector3, fim: Vector3, segmentos: int) -> ParticleChain:
	var c := ParticleChain.new(ParticleChain.Kind.LINE, inicio, fim, segmentos,
		SimWorld.LINE_MASS_PER_METER * inicio.distance_to(fim), 1.0 / SimWorld.LINE_STIFFNESS,
		SimWorld.LINE_DIAMETER, SimWorld.LINE_DRAG_COEFFICIENT)
	c.inv_mass[0] = 0.0
	c.inv_mass[segmentos] = 0.0
	return c
