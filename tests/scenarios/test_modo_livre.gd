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


func test_quatro_pipeiros_dois_minutos_sem_tempo_limite() -> void:
	var modo := FreeMode.new(3, 5, true)
	var cortes := 0
	var maximo_de_pipas := 0
	for i in 120 * 120:
		modo.update(DT)
		maximo_de_pipas = maxi(maximo_de_pipas, modo.world.flyers.size())
		if i % (20 * 120) == 0:
			print("      [livre · %5.1f s] pipas %d, pedaços soltos %d, laços %d, enroscos %d" % [modo.world.time, modo.world.flyers.size(), modo.world.loose_chains.size(), modo.world.combat.engagements.size(), modo.world.combat.links.size()])
		for m in modo.take_messages():
			print("      [livre · %5.1f s] %s" % [modo.world.time, m])
	for p in modo.players:
		cortes += int(p["cuts"])
		print("      [placar] %s: %d cortes, %d aparadas, %d perdidas" % [p["name"], p["cuts"], p["catches"], p["losses"]])
	print("      [livre] pipas no mundo ao mesmo tempo: no máximo %d; agora %d" % [maximo_de_pipas, modo.world.flyers.size()])
	assert_true(modo.world.is_finite_state())
	assert_true(maximo_de_pipas <= 12, "avoadas antigas saem do céu")
	# Nos últimos 20 s, cada pipeiro teve a pipa no ar (acima da laje) em algum momento.
	var no_ar := {}
	for i in 20 * 120:
		modo.update(DT)
		for p in modo.players:
			var f: Flyer = p["flyer"]
			if f != null and not f.cut and f.kite.position.y > 8.0:
				no_ar[p["name"]] = true
	for p in modo.players:
		var f: Flyer = p["flyer"]
		print("      [livre] %s: pipa a %.1f m, no chão %s, cortada %s" % [p["name"], f.kite.position.y, f.kite_on_ground, f.cut])
		assert_true(no_ar.has(p["name"]), "%s solta pipa (no ar nos últimos 20 s)" % p["name"])


func test_festival_cinco_rivais_com_jeitos_diferentes() -> void:
	var modo := FreeMode.new(5, 7, true)
	var perfis := {}
	for p in modo.players:
		perfis[p["profile"]] = true
	print("      [festival] perfis: %s" % [perfis.keys()])
	assert_eq(modo.players.size(), 6)
	for perfil in ["cacador", "alto", "fujao", "equilibrado"]:
		assert_true(perfis.has(perfil), "tem bot %s" % perfil)
	var maior := 0.0
	for i in 30 * 120:
		modo.update(1.0 / 120.0)
		for p in modo.players:
			if p["profile"] == "alto":
				maior = maxf(maior, (p["flyer"] as Flyer).line_length())
	assert_true(modo.world.is_finite_state())
	print("      [festival] maior linha do bot 'alto' em 30 s: %.0f m" % maior)
	assert_true(maior > 40.0, "o bot 'alto' dá linha para ficar lá em cima")
