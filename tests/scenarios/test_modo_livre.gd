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


## Pipa na mão (D-037): escolher pipa e linha, colocar no alto, recolher a
## linha toda e o que estava enroscado vai para o estoque.
func test_pipa_na_mao_escolher_subir_e_recolher() -> void:
	var modo := FreeMode.new(1, 9, false)
	modo.put_you_on_hand()
	assert_true(modo.you_on_hand)
	assert_null(modo.you())
	for i in 120:
		modo.update(DT)   # o jogo segue sem a sua pipa
	modo.launch_you(4, 8)   # Volantines (rabiola 0 → curtinha) e Linha 24 Vermelha (D-064)
	var eu := modo.you()
	assert_not_null(eu)
	assert_false(modo.you_on_hand)
	assert_true(eu.kite.definition.tail_length < KiteDefinition.pipa_rio().tail_length, "rabiola curta")
	assert_true(eu.line.strength > 1.2, "linha forte aguenta mais (%.2f)" % eu.line.strength)
	var maior := 0.0
	for i in 10 * 120:
		modo.update(DT)
		maior = maxf(maior, eu.kite.position.y - (modo.players[0]["base"] as Vector3).y)
	print("      [pipa na mão] rabiola curta + linha forte subiu até %.1f m" % maior)
	assert_true(maior > 8.0, "a pipa escolhida sobe")
	# Uma avoada enroscada na sua linha (montada direto) vai para o estoque.
	var av := modo.world.add_flyer(KiteDefinition.pipa_rio(), Vector3(20.0, 0.0, 0.0), 20.0)
	av.cut = true
	av.tag = -1
	av.caught_by = eu
	modo.world.combat.links.append({"avoada": av, "catcher": eu, "chain": eu.line, "idx": 2, "cchain": eu.line, "m": 1.0, "captured": false})
	modo._recolher()
	assert_true(modo.you_on_hand, "recolheu: pipa na mão")
	assert_null(modo.you())
	assert_eq(int(modo.players[0]["stock"]), 1, "a enroscada foi para o estoque")
	for i in 120:
		modo.update(DT)
	assert_false(modo.world.flyers.has(av), "a avoada saiu do céu")
	assert_true(modo.world.is_finite_state())


func test_recolher_a_linha_toda_tira_do_alto() -> void:
	var modo := FreeMode.new(1, 10, false)
	for i in 3 * 120:
		modo.update(DT)
	var eu := modo.you()
	for i in 30 * 120:
		if modo.you_on_hand:
			break
		eu.input.clear()
		eu.input.haul_speed = 4.0
		modo.update(DT)
	assert_true(modo.you_on_hand, "puxando a linha toda, a pipa chega na mão (linha %.1f m)" % eu.line_length())


## D-078: a pipa sai da mão com pouca linha e sobe pela física, com o
## pipeiro dando linha e tenteando, até uns 20 m — sem aparecer no alto.
func test_largada_da_mao_sobe_pela_fisica() -> void:
	for semente in [3, 7, 11]:
		var modo := FreeMode.new(1, semente, true)
		modo.put_you_on_hand()
		modo.launch_you(5, 2, true)
		var eu: Flyer = modo.you()
		var l0 := eu.line_length()
		var r := 0
		var t := 0.0
		while r == 0 and t < 35.0:
			r = modo.subir(DT)
			modo.update(DT)
			t += DT
		var base: Vector3 = modo.players[0]["base"]
		print("      [largada, semente %d] linha %.1f → %.1f m em %.1f s; altura %.1f m; elevação %.0f° (r=%d)" % [semente, l0, eu.line_length(), t, eu.kite.position.y - base.y, eu.elevation_deg(), r])
		assert_true(l0 < 5.0, "sai da mão com pouca linha")
		assert_eq(r, 1, "chegou no alto")
		assert_true(eu.line_length() > 15.0, "deu linha até o alto (%.1f m)" % eu.line_length())
		assert_true(eu.kite.position.y - base.y > 8.0, "está no alto")
