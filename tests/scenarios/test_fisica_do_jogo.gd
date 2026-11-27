extends "res://tests/test_case.gd"
## D-087: a física do jogo (60 × 3 + 4 passadas, modo leve) tem que responder
## como a de referência (120 × 4, como era até a 0.29): mesmos toques
## (desbico), mesma largada (puxa e manda linha), mesma subida da mão.


func _roteiro(passo: float, sub: int, extras := 0, leve := false) -> Dictionary:
	var w := SimWorld.create_flight(WindField.new(5.0, 0.0, 3), KiteDefinition.pipa_rio(), 30.0, 45.0, 0.0, sub, true, 3.0)
	w.leve = leve
	var f: Flyer = w.flyers[0]
	f.extra_sweeps = extras
	var t := 0.0
	var elev := 0.0
	var n := 0
	var giro := 0.0
	var tensao_max := 0.0
	var linha0 := 0.0
	var proximo_toque := 12.0
	var lado := 1.0
	while t < 26.0:
		if t >= 12.0 and linha0 == 0.0:
			linha0 = f.line_length()
		# 12–18 s: um toque por segundo, alternando o lado (tenteio)
		if t >= proximo_toque and t < 18.0:
			f.input.kick_side = lado
			f.input.kick_spin = 0.0
			f.input.kick_scale = 1.0
			f.input.kick_base_shift = 0.0
			f.pilot.trigger(Pilot.Impulse.DESBICAR_LADO, w.time)
			lado = -lado
			proximo_toque += 1.0
		# 19–21 s: manda linha; 21,5–21,9 puxa forte; 21,9–23,5 manda (largada)
		f.input.haul_speed = 0.0
		if t >= 19.0 and t < 21.0 or t >= 21.9 and t < 23.5:
			f.input.haul_speed = -2.0
		elif t >= 21.5 and t < 21.9:
			f.input.haul_speed = 3.0
		var a := f.nose_angle_deg()
		w.step(passo)
		t += passo
		if t > 12.0 and t < 18.0:
			giro = maxf(giro, absf(f.nose_angle_deg()))
		if t > 12.0:
			elev += f.elevation_deg()
			n += 1
			tensao_max = maxf(tensao_max, f.tension)
	return {"elev": elev / n, "giro": giro, "linha": f.line_length() - linha0, "tensao": tensao_max,
		"altura": f.kite.position.y}


func _p(nome: String, r: Dictionary) -> void:
	print("      [física do jogo] %-24s elevação %4.1f° · bico até %3.0f° nos toques · linha dada %5.1f m · tensão máx %5.1f N · altura final %5.1f m" % [
		nome, r["elev"], r["giro"], r["linha"], r["tensao"], r["altura"]])


func test_sua_pipa_responde_como_a_referencia() -> void:
	var ref := _roteiro(1.0 / 120.0, 4)
	_p("referência 120 × 4", ref)
	_p("0.30.3 (60 × 2 + 2)", _roteiro(1.0 / 60.0, 2, 2))
	var novo := _roteiro(1.0 / 60.0, 3, 4, true)
	_p("jogo: 60 × 3 + 4 leve", novo)
	assert_true(absf(novo["elev"] - ref["elev"]) < 3.0, "mesma elevação")
	assert_true(absf(novo["giro"] - ref["giro"]) < 0.2 * ref["giro"] + 3.0, "mesmo giro do bico nos toques")
	assert_true(absf(novo["linha"] - ref["linha"]) < 0.1 * absf(ref["linha"]) + 1.0, "mesma linha dada na largada")
	assert_true(absf(novo["altura"] - ref["altura"]) < 3.0, "termina na mesma altura")


func _subida(passo: float, sub: int, extras: int, leve: bool, semente: int) -> Array:
	var modo := FreeMode.new(1, semente, false)
	modo.world.substeps = sub
	modo.world.leve = leve
	modo.passadas_extras = extras
	modo.put_you_on_hand()
	modo.launch_you(5, 2, true)
	var eu: Flyer = modo.you()
	var r := 0
	var t := 0.0
	while r == 0 and t < 35.0:
		r = modo.subir(passo)
		modo.update(passo)
		t += passo
	return [t, eu.line_length(), eu.kite.position.y - (modo.players[0]["base"] as Vector3).y]


func test_subida_da_mao_como_a_referencia() -> void:
	for semente in [3, 7]:
		var ref := _subida(1.0 / 120.0, 4, 0, false, semente)
		var velho := _subida(1.0 / 60.0, 2, 2, false, semente)
		var jogo := _subida(1.0 / 60.0, 3, 4, true, semente)
		print("      [subida %d] referência %.1f s, linha %.1f m, altura %.1f m · 0.30.3 %.1f s, %.1f m, %.1f m · jogo %.1f s, %.1f m, %.1f m" % [
			semente, ref[0], ref[1], ref[2], velho[0], velho[1], velho[2], jogo[0], jogo[1], jogo[2]])
		assert_true(absf(jogo[1] - ref[1]) < 2.0, "dá a mesma linha subindo")
