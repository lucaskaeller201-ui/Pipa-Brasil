extends "res://tests/test_case.gd"
## Modo livre: sem tempo, placar de cortes e aparadas, pipa nova depois do corte.

const DT := 1.0 / 120.0


func test_corte_tem_autor_e_pipeiro_ganha_pipa_nova() -> void:
	var modo := FreeMode.new(1, 4, true)
	assert_eq(modo.players.size(), 2)
	for i in 6 * 120:
		modo.update(DT)
	var vitima: Flyer = modo.players[1]["flyer"]
	var autor: Flyer = modo.players[0]["flyer"]
	# Encosta a linha do autor e desgasta a da vítima "por ele" (sem esperar o acaso).
	vitima.line.last_contact = autor
	vitima.line.add_wear(vitima.line.size() / 2, 0.5, vitima.line.strength * 2.0)
	modo.update(DT)
	assert_true(vitima.cut, "a linha rompeu")
	assert_eq(modo.players[0]["cuts"], 1, "o corte conta para quem encostou")
	assert_eq(modo.players[1]["losses"], 1)
	var msgs := modo.take_messages()
	assert_true(msgs.size() > 0 and msgs[0].contains("cortou"), "aviso do corte: %s" % [msgs])
	for i in roundi((FreeMode.PIPA_NOVA_APOS + 0.5) * 120):
		modo.update(DT)
	var nova: Flyer = modo.players[1]["flyer"]
	assert_true(nova != vitima and not nova.cut, "pipa nova na laje")
	assert_eq(nova.tag, 1)
	assert_eq(vitima.tag, -1, "a cortada vira avoada de ninguém")
	assert_true(modo.world.flyers.has(vitima), "a avoada continua no céu para ser aparada")
	assert_true(modo.world.is_finite_state())


func test_remover_avoada_renumera_os_pipeiros() -> void:
	var w := SimWorld.new()
	w.wind = WindField.new(5.0)
	var a := w.add_flyer(KiteDefinition.raia_sem_rabiola(), Vector3.ZERO, 20.0, 45.0, 0.0, true, 3.0)
	var b := w.add_flyer(KiteDefinition.raia_sem_rabiola(), Vector3(10, 0, 0), 20.0, 45.0, 0.0, true, 3.0)
	var c := w.add_flyer(KiteDefinition.raia_sem_rabiola(), Vector3(-10, 0, 0), 20.0, 45.0, 0.0, true, 3.0)
	w.remove_flyer(b)
	assert_eq(w.flyers.size(), 2)
	assert_eq(a.id, 0)
	assert_eq(c.id, 1)
	for i in 240:
		w.step(DT)
	assert_true(w.is_finite_state())


func test_quatro_pipeiros_tres_minutos_sem_tempo_limite() -> void:
	var modo := FreeMode.new(3, 5, true)
	var cortes := 0
	var maximo_de_pipas := 0
	for i in 180 * 120:
		modo.update(DT)
		maximo_de_pipas = maxi(maximo_de_pipas, modo.world.flyers.size())
		for m in modo.take_messages():
			print("      [livre · %5.1f s] %s" % [modo.world.time, m])
	for p in modo.players:
		cortes += int(p["cuts"])
		print("      [placar] %s: %d cortes, %d aparadas, %d perdidas" % [p["name"], p["cuts"], p["catches"], p["losses"]])
	print("      [livre] pipas no mundo ao mesmo tempo: no máximo %d; agora %d" % [maximo_de_pipas, modo.world.flyers.size()])
	assert_true(modo.world.is_finite_state())
	assert_true(maximo_de_pipas <= 12, "avoadas antigas saem do céu")
	for p in modo.players:
		var f: Flyer = p["flyer"]
		assert_true(f.cut or f.kite.position.y > 6.0, "%s está voando ou esperando pipa nova" % p["name"])
