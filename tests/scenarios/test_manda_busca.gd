extends "res://tests/test_case.gd"
## "Manda busca": aparar a pipa avoada e trazer para a mão.
##
## Montagem determinística: o pipeiro A (que vai aparar) voa normalmente; o
## pipeiro B fica 15 m atrás de A, no mesmo alinhamento do vento, com a pipa
## bem acima da linha de A. Quando a linha de B é cortada perto da mão, a pipa
## de B sai avoada vento abaixo e o pedaço de linha pendurado nela cai sobre a
## linha de A, com metros de margem.

const DT := 1.0 / 120.0


func _montagem(com_aparador := true) -> SimWorld:
	var w := SimWorld.new()
	w.wind = WindField.new(5.0)
	if com_aparador:
		w.add_flyer(KiteDefinition.raia_laboratorio(), Vector3(0.0, 0.0, 0.0), 30.0, 30.0, 0.0, true)
	w.add_flyer(KiteDefinition.raia_laboratorio(), Vector3(0.0, 0.0, 15.0), 30.0, 30.0, 0.0, true)
	for i in roundi(15.0 / DT):
		w.step(DT)
	return w


func _eventos_do_tipo(eventos: Array, tipo: String) -> Array:
	var out: Array = []
	for e in eventos:
		if e["type"] == tipo:
			out.append(e)
	return out


func test_avoada_enrosca_na_linha_de_quem_esta_embaixo() -> void:
	var w := _montagem()
	var a: Flyer = w.flyers[0]
	var b: Flyer = w.flyers[1]
	assert_eq(w.combat.take_events().size(), 0, "nada acontece antes do corte")
	b.cut_line(1)
	var enroscou_em := -1.0
	for i in roundi(15.0 / DT):
		w.step(DT)
		if b.caught_by != null:
			enroscou_em = w.time - 15.0
			break
	var eventos := w.combat.take_events()
	print("      [enrosco] a avoada enroscou %.1f s depois do corte; eventos: %s" % [enroscou_em, str(eventos.map(func(e): return e["type"]))])
	assert_true(enroscou_em > 0.0, "a linha da avoada enrosca na linha de A")
	assert_true(b.caught_by == a)
	assert_eq(a.holding, 1)
	assert_eq(_eventos_do_tipo(eventos, "enroscou").size(), 1)


func test_recolher_traz_a_pipa_para_a_mao() -> void:
	var w := _montagem()
	var a: Flyer = w.flyers[0]
	var b: Flyer = w.flyers[1]
	b.cut_line(1)
	for i in roundi(15.0 / DT):
		w.step(DT)
		if b.caught_by != null:
			break
	assert_true(b.caught_by == a, "enroscou")
	var linha_antes := a.line_length()
	a.input.reel_in = true
	var aparou_em := -1.0
	for i in roundi(40.0 / DT):
		w.step(DT)
		if b.captured:
			aparou_em = i * DT
			break
	var eventos := _eventos_do_tipo(w.combat.take_events(), "aparada")
	print("      [manda busca] aparada %.1f s depois de começar a recolher; linha %.1f → %.1f m; pipa de B a %.1f m da mão de A" % [
		aparou_em, linha_antes, a.line_length(), b.kite.position.distance_to(a.hand_position)])
	assert_true(aparou_em > 0.0, "recolhendo, a pipa enroscada chega na mão")
	assert_eq(eventos.size(), 1)
	if eventos.size() == 1:
		assert_eq(eventos[0]["catcher"], 0)
		assert_eq(eventos[0]["flyer"], 1)
	assert_eq(a.catches, 1)
	assert_eq(a.holding, 0)
	assert_true(w.is_finite_state())


func test_avoada_sem_ninguem_embaixo_e_pipa_perdida() -> void:
	var w := _montagem(false)
	var b: Flyer = w.flyers[0]
	b.cut_line(1)
	var perdida := false
	for i in roundi(30.0 / DT):
		w.step(DT)
		if b.lost:
			perdida = true
			break
	var eventos := _eventos_do_tipo(w.combat.take_events(), "perdida")
	print("      [perdida] caiu no chão em %.1f s, %.1f m vento abaixo" % [w.time - 15.0, -b.kite.position.z])
	assert_true(perdida)
	assert_eq(eventos.size(), 1)
	assert_true(b.caught_by == null)


func test_bot_manda_busca_sozinho() -> void:
	var w := _montagem()
	var a: Flyer = w.flyers[0]
	var b: Flyer = w.flyers[1]
	var bot := BotPilot.new(BotDifficulty.create(BotDifficulty.Level.NORMAL), 3)
	b.cut_line(1)
	var aparou := false
	for i in roundi(60.0 / DT):
		bot.update(a, w.time)
		w.step(DT)
		if b.captured:
			aparou = true
			break
	print("      [bot manda busca] aparou: %s em %.1f s; pipas aparadas pelo bot: %d" % [aparou, w.time - 15.0, a.catches])
	assert_true(aparou, "o bot percebe a pipa enroscada e recolhe até a mão")


func test_quem_aparou_e_cortado_a_avoada_se_solta() -> void:
	var w := _montagem()
	var a: Flyer = w.flyers[0]
	var b: Flyer = w.flyers[1]
	b.cut_line(1)
	for i in roundi(15.0 / DT):
		w.step(DT)
		if b.caught_by != null:
			break
	assert_true(b.caught_by == a)
	a.cut_line(2)
	w.step(DT)
	assert_true(b.caught_by == null, "sem a linha de A, nada segura a avoada")
	assert_eq(w.combat.links.size(), 0)
