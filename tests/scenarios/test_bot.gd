extends "res://tests/test_case.gd"
## Fase 4: a raia sem rabiola corrigida (D-018) e o bot piloto.
## Faixas calibradas no protótipo (tools/prototipo/fase4).

const DT := 1.0 / 120.0


func _sem_rabiola(turbulencia := 0.15, semente := 1) -> SimWorld:
	return SimWorld.create_flight(WindField.new(5.0, turbulencia, semente), KiteDefinition.raia_sem_rabiola(),
		30.0, 30.0, 0.0, 4, true, 3.0)


func test_raia_sem_rabiola_fica_no_ar_sozinha_com_turbulencia() -> void:
	for semente in [1, 2, 3]:
		var w := _sem_rabiola(0.15, semente)
		var minima := INF
		for i in roundi(10.0 / DT):
			w.step(DT)
			if w.time > 3.0:
				minima = minf(minima, w.elevation_deg())
		print("      [sem rabiola, sozinha, semente %d] elevação mínima %.1f°, final %.1f°, bico %.0f°" % [
			semente, minima, w.elevation_deg(), w.flyers[0].nose_angle_deg()])
		assert_true(minima > 30.0, "não cai")
		assert_true(w.elevation_deg() > 50.0, "sobe e fica parada no alto")
		assert_true(absf(w.flyers[0].nose_angle_deg()) < 30.0, "com o bico para cima")


func test_folga_e_puxao_levam_a_pipa_para_o_lado() -> void:
	var w := _sem_rabiola(0.0)
	for i in roundi(8.0 / DT):
		w.step(DT)
	var f: Flyer = w.flyers[0]
	var antes := f.sky_position_deg()
	var giro := 0.0
	var bico := f.nose_angle_deg()
	w.input.slack = 1.0
	w.input.free_spool = true
	for i in roundi(0.5 / DT):
		w.step(DT)
		var novo := f.nose_angle_deg()
		giro += wrapf(novo - bico, -180.0, 180.0)
		bico = novo
	w.input.clear()
	w.input.pull = 1.0
	for i in roundi(1.5 / DT):
		w.step(DT)
	var depois := f.sky_position_deg()
	print("      [folga 0,5 s + puxar 1,5 s] bico girou %.0f°; pipa andou %.1f° de lado e %.1f° de altura" % [
		giro, depois.x - antes.x, depois.y - antes.y])
	assert_true(absf(giro) > 30.0, "com folga, o bico gira")
	assert_true(absf(depois.x - antes.x) > 15.0, "puxando, ela corre para o lado do bico")
	assert_true(sign(depois.x - antes.x) == sign(giro), "para o lado para onde o bico girou")


func _voo_com_bot(nivel: BotDifficulty.Level, segundos: float, semente: int) -> Dictionary:
	var w := _sem_rabiola(0.15, semente)
	var f: Flyer = w.flyers[0]
	var bot := BotPilot.new(BotDifficulty.create(nivel), semente)
	var rng := RandomNumberGenerator.new()
	rng.seed = semente + 100
	var minima := INF
	var no_chao := 0.0
	var linha_max := 0.0
	var passos := roundi(segundos / DT)
	for i in passos:
		var t := i * DT
		if i % 2400 == 2399:  # rajada de 7 a 10 m/s por 3 s a cada 20 s
			w.wind.set_gust(w.time, rng.randf_range(7.0, 10.0), 3.0)
		bot.target_azimuth = 25.0 if int(t / 10.0) % 2 == 0 else -25.0
		bot.update(f, t)
		w.step(DT)
		if t > 5.0:
			minima = minf(minima, w.elevation_deg())
		if f.kite_on_ground:
			no_chao += DT
		linha_max = maxf(linha_max, f.line_length())
	return {"minima": minima, "no_chao": no_chao, "linha_max": linha_max, "linha": f.line_length(),
		"folgas": bot.slack_count, "finito": w.is_finite_state()}


func test_bot_mantem_a_raia_sem_rabiola_no_ar_5_minutos_com_rajadas() -> void:
	for nivel in [BotDifficulty.Level.FACIL, BotDifficulty.Level.PROFISSIONAL]:
		var r := _voo_com_bot(nivel, 300.0, 1)
		print("      [bot %s, 5 min] elevação mínima %.1f°, no chão %.1f s, linha final %.1f m (máx %.1f), giros %d" % [
			BotDifficulty.level_name(nivel), r["minima"], r["no_chao"], r["linha"], r["linha_max"], r["folgas"]])
		assert_true(r["finito"])
		assert_near(r["no_chao"], 0.0, 0.01, "nunca toca o chão")
		assert_true(r["minima"] > 0.0)
		assert_true(r["linha"] > 25.0 and r["linha"] < 50.0, "não deixa a linha crescer sem limite")
		assert_true(r["folgas"] > 50, "está pilotando de verdade, não parado")


func test_todos_os_niveis_ficam_no_ar_1_minuto() -> void:
	for nivel in [BotDifficulty.Level.FACIL, BotDifficulty.Level.NORMAL, BotDifficulty.Level.DIFICIL, BotDifficulty.Level.PROFISSIONAL]:
		for semente in [2, 3]:
			var r := _voo_com_bot(nivel, 60.0, semente)
			print("      [bot %s, semente %d, 1 min] elevação mínima %.1f°, no chão %.1f s, linha %.1f m" % [
				BotDifficulty.level_name(nivel), semente, r["minima"], r["no_chao"], r["linha"]])
			assert_near(r["no_chao"], 0.0, 0.01, "%s, semente %d: nunca toca o chão" % [BotDifficulty.level_name(nivel), semente])


func test_dificuldade_muda_so_a_execucao() -> void:
	var facil := BotDifficulty.create(BotDifficulty.Level.FACIL)
	var pro := BotDifficulty.create(BotDifficulty.Level.PROFISSIONAL)
	assert_true(facil.reaction > pro.reaction, "o fácil reage mais devagar")
	assert_true(facil.noise_deg > pro.noise_deg, "e enxerga pior")
	assert_true(facil.tolerance_deg > pro.tolerance_deg, "e é menos preciso")


func test_bot_usa_so_a_interface_do_pipeiro() -> void:
	# O bot escreve só no PilotInput: a mesma pipa, a mesma física.
	var w := _sem_rabiola(0.15, 4)
	var f: Flyer = w.flyers[0]
	var bot := BotPilot.new(BotDifficulty.create(BotDifficulty.Level.NORMAL), 4)
	var usou := {"slack": false, "free_spool": false, "reel_in": false}
	for i in roundi(30.0 / DT):
		bot.target_azimuth = 25.0 if int(i * DT / 10.0) % 2 == 0 else -25.0
		bot.update(f, i * DT)
		usou["slack"] = usou["slack"] or f.input.slack > 0.0
		usou["free_spool"] = usou["free_spool"] or f.input.free_spool
		usou["reel_in"] = usou["reel_in"] or f.input.reel_in
		w.step(DT)
	print("      [comandos usados pelo bot] %s" % str(usou))
	assert_true(usou["slack"] and usou["free_spool"] and usou["reel_in"])


func test_bot_contra_bot_na_mesma_janela() -> void:
	var w := SimWorld.new()
	w.wind = WindField.new(5.0, 0.15, 5)
	w.add_flyer(KiteDefinition.raia_sem_rabiola(), Vector3(-5.0, 0.0, 0.0), 30.0, 30.0, 0.0, true, 3.0)
	w.add_flyer(KiteDefinition.raia_sem_rabiola(), Vector3(5.0, 0.0, 0.0), 30.0, 30.0, 0.0, true, 3.0)
	var bots := [BotPilot.new(BotDifficulty.create(BotDifficulty.Level.DIFICIL), 7),
		BotPilot.new(BotDifficulty.create(BotDifficulty.Level.NORMAL), 8)]
	var no_chao := [0.0, 0.0]
	var contato := 0.0
	for i in roundi(60.0 / DT):
		var t := i * DT
		for k in 2:
			(bots[k] as BotPilot).target_azimuth = 15.0 if k == 0 else -15.0  # cada um mira o lado do outro
			(bots[k] as BotPilot).update(w.flyers[k], t)
		w.step(DT)
		for k in 2:
			if (w.flyers[k] as Flyer).kite_on_ground:
				no_chao[k] += DT
		if w.combat.contacts_last_step > 0:
			contato += DT
	print("      [bot contra bot, 1 min] no chão %.1f s e %.1f s; linhas encostadas %.1f s; cortados: %s, %s" % [
		no_chao[0], no_chao[1], contato, w.flyers[0].cut, w.flyers[1].cut])
	assert_true(w.is_finite_state())
