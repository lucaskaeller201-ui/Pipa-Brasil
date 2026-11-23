extends "res://tests/test_case.gd"
## Fase 3: duas raias com as linhas cruzadas. As linhas se empurram e dobram
## sem atravessar; o desgaste virtual cresce com o deslizamento; no limite uma
## linha rompe e a pipa sai avoada com o pedaço que ficou preso nela.
## Faixas calibradas no protótipo (tools/prototipo/fase3/duel*.py).

const DT := 1.0 / 120.0


## Pipeiro A em x = -4 m e B em x = +4 m, cada pipa lançada 18° para o lado do
## outro: as linhas começam cruzadas. Só A tem piloto (B fica com a mão parada).
func _duelo() -> SimWorld:
	var w := SimWorld.new()
	w.wind = WindField.new(5.0)
	w.add_flyer(KiteDefinition.raia_laboratorio(), Vector3(-4.0, 0.0, 0.0), 30.0, 30.0, 18.0, true)
	w.add_flyer(KiteDefinition.raia_laboratorio(), Vector3(4.0, 0.0, 0.0), 30.0, 30.0, -18.0, false)
	return w


## Contagem de passos com contato e de travessias detectadas.
func _rodar(w: SimWorld, segundos: float, checar_travessia := false) -> Dictionary:
	var com_contato := 0
	var travessias := 0
	var forca_max := 0.0
	for i in roundi(segundos / DT):
		w.step(DT)
		if w.combat.contacts_last_step > 0:
			com_contato += 1
		forca_max = maxf(forca_max, w.combat.max_contact_force)
		if checar_travessia:
			var a: ParticleChain = w.flyers[0].line
			var b: ParticleChain = w.flyers[1].line
			for p in LineContact.find_pairs([a, b], PackedInt32Array([0, 1]), 0.5):
				var ca: ParticleChain = a if p[0] == 0 else b
				var cb: ParticleChain = b if p[2] == 1 else a
				if LineContact.crossed_between(ca, p[1], cb, p[3]):
					travessias += 1
	return {"segundos_com_contato": com_contato * DT, "travessias": travessias, "forca_max": forca_max}


func test_linhas_cruzadas_se_empurram_sem_atravessar_e_se_soltam_pelas_pontas() -> void:
	var w := _duelo()
	var r := _rodar(w, 10.0, true)
	var a: Flyer = w.flyers[0]
	var b: Flyer = w.flyers[1]
	print("      [cruzadas] contato por %.1f s, força máx %.2f N, travessias %d; pipas em x = %.1f e %.1f m, elevações %.1f° e %.1f°" % [
		r["segundos_com_contato"], r["forca_max"], r["travessias"], a.kite.position.x, b.kite.position.x,
		a.elevation_deg(), b.elevation_deg()])
	assert_eq(r["travessias"], 0, "uma linha nunca passa através da outra")
	assert_true(r["segundos_com_contato"] > 1.0, "as linhas ficam encostadas por um tempo")
	assert_true(a.kite.position.x < b.kite.position.x, "as pipas passaram uma pela outra e voltaram para o próprio lado")
	assert_true(a.elevation_deg() > 40.0 and b.elevation_deg() > 40.0, "e continuam voando")
	assert_false(a.cut or b.cut)


func test_sem_ninguem_mexer_o_desgaste_fica_baixo() -> void:
	var w := _duelo()
	_rodar(w, 5.0)
	var da: float = w.flyers[0].line.max_wear()
	var db: float = w.flyers[1].line.max_wear()
	print("      [parados] desgaste máximo A %.4f, B %.4f (rompe em 1,0)" % [da, db])
	assert_true(da < 0.05 and db < 0.05)


func test_so_um_puxao_nao_rompe() -> void:
	var w := _duelo()
	_rodar(w, 0.5)
	w.trigger(Pilot.Impulse.PUXAO)
	_rodar(w, 4.0)
	assert_false(w.flyers[0].cut or w.flyers[1].cut)
	assert_true(w.flyers[0].line.max_wear() < 0.2)


func test_dar_linha_no_cruzamento_decide_a_disputa() -> void:
	var w := _duelo()
	var a: Flyer = w.flyers[0]
	var b: Flyer = w.flyers[1]
	var rompeu_em := -1.0
	var linha_antes := 0.0
	for i in roundi(6.0 / DT):
		a.input.pay_out = not a.cut
		linha_antes = a.line_length()
		w.step(DT)
		if a.cut or b.cut:
			rompeu_em = w.time
			break
	var eventos := w.combat.take_events()
	print("      [dando linha] ruptura em %.2f s; rompeu: %s" % [rompeu_em, "A (quem deu linha)" if a.cut else ("B" if b.cut else "ninguém")])
	assert_true(rompeu_em > 0.5 and rompeu_em < 6.0, "uma linha rompe")
	assert_true(a.cut != b.cut, "só uma linha rompe")
	assert_eq(eventos.size(), 1)
	if eventos.size() == 1:
		assert_eq(eventos[0]["type"], "ruptura")
	var cortado: Flyer = a if a.cut else b
	var inteiro: Flyer = b if a.cut else a
	assert_not_null(cortado.trailing_line, "a pipa avoada leva um pedaço de linha")
	if cortado.trailing_line == null:
		return
	assert_true(cortado.line.inv_mass[0] == 0.0 and cortado.line.size() >= 2, "o pedaço da mão continua na mão")
	var total := cortado.line.rest_total() + cortado.trailing_line.rest_total()
	var esperado := linha_antes if cortado == a else 30.0
	assert_near(total, esperado, 0.5, "a linha não some nem cresce")

	var y0 := cortado.kite.position.y
	var z0 := cortado.kite.position.z
	_rodar(w, 8.0)
	print("      [avoada] altura %.1f → %.1f m, vento abaixo %.1f → %.1f m, vel %.1f m/s; a outra a %.1f°" % [
		y0, cortado.kite.position.y, z0, cortado.kite.position.z, cortado.kite.velocity.length(), inteiro.elevation_deg()])
	assert_true(w.is_finite_state())
	assert_true(cortado.kite.position.z < z0 - 20.0, "a avoada vai embora com o vento")
	assert_true(cortado.kite.position.y < y0, "e perde altura")
	assert_true(inteiro.elevation_deg() > 35.0, "quem não rompeu continua no ar")


func test_custo_com_duas_pipas_e_contato() -> void:
	var w := _duelo()
	var inicio := Time.get_ticks_usec()
	for i in 600:  # 5 s simulados, com as linhas encostadas boa parte do tempo
		w.step(DT)
	var ms_por_segundo := (Time.get_ticks_usec() - inicio) / 1000.0 / 5.0
	print("      [custo 2 pipas + contato] %.1f ms de CPU por segundo simulado" % ms_por_segundo)
	assert_true(ms_por_segundo < 600.0)
