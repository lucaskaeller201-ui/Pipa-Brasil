extends "res://tests/test_case.gd"
## Fase 3: contato entre linhas, desgaste virtual e ruptura.
##
## Os testes que precisam de resultado certo usam uma LINHA FIXA presa entre
## dois postes, atravessada no vento a 10 m do pipeiro e a 9,5 m de altura. A
## linha da pipa sobe, encosta nela por baixo e fica dobrada, com metros de
## margem. Entre duas pipas soltas, enganchar ou não depende de centímetros (ir
## por cima ou por baixo), então ali só testamos que nada atravessa (D-016).
## Faixas calibradas no protótipo (tools/prototipo/fase3/fixed*.py).

const DT := 1.0 / 120.0
const ALTURA_FIXA := 9.5


func _pipa_e_linha_fixa() -> SimWorld:
	var w := SimWorld.create_flight(WindField.new(5.0), KiteDefinition.raia_laboratorio(), 30.0, 30.0, 0.0, 4, true)
	var fixa := w.add_fixed_line(Vector3(-15.0, ALTURA_FIXA, -10.0), Vector3(15.0, ALTURA_FIXA, -10.0))
	fixa.strength = 1e9
	return w


func _fixa(w: SimWorld) -> ParticleChain:
	return w.loose_chains[0]


func _rodar(w: SimWorld, segundos: float) -> float:
	var com_contato := 0
	for i in roundi(segundos / DT):
		w.step(DT)
		if w.combat.contacts_last_step > 0:
			com_contato += 1
	return com_contato * DT


func _menor_distancia(a: ParticleChain, b: ParticleChain) -> float:
	var menor := INF
	for i in a.size() - 1:
		for j in b.size() - 1:
			var st := LineContact.closest_params(a.pos[i], a.pos[i + 1], b.pos[j], b.pos[j + 1])
			menor = minf(menor, a.pos[i].lerp(a.pos[i + 1], st.x).distance_to(b.pos[j].lerp(b.pos[j + 1], st.y)))
	return menor


## Altura da linha da pipa onde ela passa pelo plano da linha fixa (z = -10 m).
func _altura_em_z(c: ParticleChain, z: float) -> float:
	for i in c.size() - 1:
		var a := c.pos[i]
		var b := c.pos[i + 1]
		if (a.z - z) * (b.z - z) <= 0.0 and absf(b.z - a.z) > 1e-6:
			return lerpf(a.y, b.y, (z - a.z) / (b.z - a.z))
	return NAN


func test_linha_da_pipa_dobra_sobre_a_linha_fixa() -> void:
	var w := _pipa_e_linha_fixa()
	var contato := _rodar(w, 10.0)
	var dist := _menor_distancia(w.line, _fixa(w))
	var altura := _altura_em_z(w.line, -10.0)
	print("      [dobra] contato por %.1f s, distância %.3f m, linha da pipa a %.2f m de altura em z = −10 m (livre seria cerca de 12 m), elevação %.1f°" % [
		contato, dist, altura, w.elevation_deg()])
	assert_true(contato > 4.0, "a linha encosta e fica encostada")
	assert_true(dist > 0.01 and dist < 0.04, "encostada, sem atravessar (raio de contato 0,02 m)")
	assert_true(altura < ALTURA_FIXA + 0.3, "a linha fixa segura a linha da pipa para baixo")
	assert_true(w.elevation_deg() > 40.0, "e a pipa continua voando")


func test_enganchada_e_parada_quase_nao_desgasta() -> void:
	var w := _pipa_e_linha_fixa()
	_rodar(w, 10.0)
	var da := w.line.max_wear()
	var df := _fixa(w).max_wear()
	print("      [parada] desgaste máximo: linha da pipa %.4f, linha fixa %.4f (rompe em 1,0)" % [da, df])
	assert_true(da < 0.05 and df < 0.05)


func test_recolher_enganchado_desgasta_a_linha_que_fica_parada_no_ponto() -> void:
	# A linha da pipa corre pelo ponto de contato (espalha o desgaste);
	# a linha fixa recebe o atrito sempre no mesmo ponto (concentra).
	var w := _pipa_e_linha_fixa()
	_rodar(w, 6.0)
	w.input.reel_in = true
	var contato := _rodar(w, 4.0)
	var da := w.line.max_wear()
	var df := _fixa(w).max_wear()
	print("      [recolhendo enganchada] contato %.1f s; desgaste: linha da pipa %.3f, linha fixa %.3f" % [contato, da, df])
	assert_true(contato > 3.0, "continua enganchada enquanto recolhe")
	assert_true(df > 0.3, "a linha fixa se desgasta num ponto")
	assert_true(da < df / 5.0, "a linha que corre espalha o desgaste")


func test_linha_fixa_rompe_e_vira_dois_pedacos() -> void:
	var w := _pipa_e_linha_fixa()
	_fixa(w).strength = 0.3
	_rodar(w, 6.0)
	w.input.reel_in = true
	var rompeu := false
	for i in roundi(6.0 / DT):
		w.step(DT)
		if w.loose_chains.size() > 1:
			rompeu = true
			break
	var eventos := w.combat.take_events()
	print("      [linha fixa rompe] rompeu: %s, pedaços %d, eventos %d" % [rompeu, w.loose_chains.size(), eventos.size()])
	assert_true(rompeu, "rompe recolhendo enganchada")
	assert_true(eventos.size() >= 1 and eventos[0]["type"] == "pedaco")
	var total := 0.0
	for c in w.loose_chains:
		total += (c as ParticleChain).rest_total()
	assert_near(total, 30.0, 0.05, "nenhum comprimento de linha some na ruptura")
	w.input.reel_in = false
	_rodar(w, 4.0)
	assert_true(w.is_finite_state())
	assert_true(w.elevation_deg() > 40.0, "livre do enganche, a pipa volta a subir")


func test_linha_da_pipa_rompe_e_a_pipa_sai_avoada() -> void:
	var w := _pipa_e_linha_fixa()
	w.line.strength = 0.005  # linha fraca de propósito, para romper só com o contato parado
	var rompeu_em := -1.0
	for i in roundi(15.0 / DT):
		w.step(DT)
		if w.flyers[0].cut:
			rompeu_em = w.time
			break
	var f: Flyer = w.flyers[0]
	var eventos := w.combat.take_events()
	print("      [linha da pipa rompe] em %.1f s, eventos %d" % [rompeu_em, eventos.size()])
	assert_true(rompeu_em > 0.0, "a linha da pipa rompe")
	if not f.cut:
		return
	assert_eq(eventos.size(), 1)
	assert_eq(eventos[0]["type"], "ruptura")
	assert_not_null(f.trailing_line, "a pipa avoada leva um pedaço de linha")
	assert_true(f.line.inv_mass[0] == 0.0, "o pedaço da mão continua na mão")
	assert_near(f.line.rest_total() + f.trailing_line.rest_total(), 30.0, 0.05, "nenhum comprimento de linha some")
	var y0 := f.kite.position.y
	var z0 := f.kite.position.z
	_rodar(w, 8.0)
	print("      [avoada] altura %.1f → %.1f m, vento abaixo %.1f → %.1f m, vel %.1f m/s" % [
		y0, f.kite.position.y, z0, f.kite.position.z, f.kite.velocity.length()])
	assert_true(w.is_finite_state())
	assert_true(f.kite.position.z < z0 - 20.0, "escorrega pela linha fixa e vai embora com o vento")
	assert_true(f.kite.position.y < y0, "e perde altura")


func test_duas_pipas_soltas_com_linhas_cruzadas_nunca_se_atravessam() -> void:
	# Pipeiros a 8 m um do outro, pipas lançadas 18° para o lado do outro.
	var w := SimWorld.new()
	w.wind = WindField.new(5.0)
	w.add_flyer(KiteDefinition.raia_laboratorio(), Vector3(-4.0, 0.0, 0.0), 30.0, 30.0, 18.0, true)
	w.add_flyer(KiteDefinition.raia_laboratorio(), Vector3(4.0, 0.0, 0.0), 30.0, 30.0, -18.0, true)
	var a: ParticleChain = w.flyers[0].line
	var b: ParticleChain = w.flyers[1].line
	var travessias := 0
	var com_contato := 0
	for i in roundi(10.0 / DT):
		# confere a cada subpasso, para não perder uma travessia entre passos
		for s in w.substeps:
			w.step(DT / w.substeps)
			for p in LineContact.find_pairs([a, b], PackedInt32Array([0, 1]), 0.5):
				var ca: ParticleChain = a if p[0] == 0 else b
				var cb: ParticleChain = b if p[2] == 1 else a
				if LineContact.crossed_between(ca, p[1], cb, p[3]):
					travessias += 1
			if w.combat.contacts_last_step > 0:
				com_contato += 1
	print("      [pipas soltas cruzadas] contato em %d subpassos, travessias %d, elevações %.1f° e %.1f°" % [
		com_contato, travessias, w.flyers[0].elevation_deg(), w.flyers[1].elevation_deg()])
	assert_eq(travessias, 0, "uma linha nunca passa através da outra")
	assert_true(w.is_finite_state())


func test_custo_com_duas_pipas_e_linha_fixa() -> void:
	var w := _pipa_e_linha_fixa()
	w.add_flyer(KiteDefinition.raia_laboratorio(), Vector3(6.0, 0.0, 0.0), 30.0, 30.0, 0.0, true)
	_rodar(w, 5.0)
	var inicio := Time.get_ticks_usec()
	for i in 600:  # 5 s simulados, enganchada
		w.step(DT)
	var ms_por_segundo := (Time.get_ticks_usec() - inicio) / 1000.0 / 5.0
	print("      [custo 2 pipas + linha fixa] %.1f ms de CPU por segundo simulado" % ms_por_segundo)
	assert_true(ms_por_segundo < 600.0)
