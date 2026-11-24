extends "res://tests/test_case.gd"
## "Manda busca": aparar a pipa avoada e trazer para a mão (regras da D-029:
## só embola mandando linha em contato; puxada rápida decepa; devagar traz).
##
## Montagem determinística: o pipeiro A (que vai aparar) voa normalmente; o
## pipeiro B fica 15 m atrás de A, no mesmo alinhamento do vento, com a pipa
## bem acima da linha de A. A linha de B é cortada no meio: a pipa de B sai
## avoada vento abaixo e os 15 m de linha pendurados nela caem sobre a linha
## de A lá no alto, longe da mão. (Se a ponta solta chegar na mão de quem está
## embaixo, a pipa já conta como aparada: a linha dela está na mão.)

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


## Espera a avoada encostar e embolar na linha de A, com A mandando linha.
func _embolar(w: SimWorld) -> bool:
	var a: Flyer = w.flyers[0]
	var b: Flyer = w.flyers[1]
	b.cut_line(12)
	# Espera encostar; aí manda linha (gira) enquanto está encostado.
	var mandando := 0.0
	var em_contato_mandando := 0
	for i in roundi(15.0 / DT):
		w.step(DT)
		if w.combat.contacts_last_step > 0 and mandando <= 0.0:
			mandando = 3.0
		if mandando > 0.0:
			a.input.haul_speed = -0.3   # manda pouca linha: a pipa gira e a linha continua encostada
			mandando -= DT
			if w.combat.contacts_last_step > 0:
				em_contato_mandando += 1
		else:
			a.input.clear()
		if b.caught_by != null:
			break
	a.input.clear()
	print("      [embolar] passos em contato mandando linha: %d; modo do giro de A: %d" % [em_contato_mandando, a.kite.spin_mode])
	return b.caught_by == a


func test_so_encostar_nao_embola() -> void:
	var w := _montagem()
	var a: Flyer = w.flyers[0]
	var b: Flyer = w.flyers[1]
	b.cut_line(12)
	var encostou := false
	for i in roundi(10.0 / DT):
		w.step(DT)
		for c in [b.trailing_line, b.tail]:
			if c != null and w.combat.contacts_last_step > 0:
				encostou = true
	print("      [só encostar] encostou: %s; embolou: %s" % [encostou, b.caught_by != null])
	assert_true(b.caught_by == null, "sem mandar linha, encostar não prende a avoada")
	assert_eq(a.holding, 0)


func test_mandando_linha_em_contato_embola() -> void:
	var w := _montagem()
	var a: Flyer = w.flyers[0]
	var b: Flyer = w.flyers[1]
	var t0 := w.time
	assert_true(_embolar(w), "mandando linha com a avoada encostada, embola")
	print("      [embolou] %.1f s depois do corte" % (w.time - t0))
	assert_eq(a.holding, 1)
	assert_eq(_eventos_do_tipo(w.combat.take_events(), "enroscou").size(), 1)


func test_puxar_devagar_traz_para_a_mao() -> void:
	var w := _montagem()
	var a: Flyer = w.flyers[0]
	var b: Flyer = w.flyers[1]
	assert_true(_embolar(w))
	var linha_antes := a.line_length()
	a.input.reel_in = true   # 1,2 m/s: devagar
	var aparou_em := -1.0
	var giro_max := 0.0
	for i in roundi(40.0 / DT):
		w.step(DT)
		if i > 120 and not b.captured:
			giro_max = maxf(giro_max, rad_to_deg(b.kite.angular_velocity.length()))
		if b.captured:
			aparou_em = i * DT
			break
	var eventos := _eventos_do_tipo(w.combat.take_events(), "aparada")
	print("      [manda busca] aparada %.1f s depois de começar a recolher; linha %.1f → %.1f m; giro máximo da rebocada %.0f°/s" % [
		aparou_em, linha_antes, a.line_length(), giro_max])
	assert_true(aparou_em > 0.0, "puxando devagar, a pipa embolada chega na mão")
	assert_eq(eventos.size(), 1)
	assert_eq(a.catches, 1)
	assert_eq(a.holding, 0)
	assert_true(giro_max < 200.0, "a rebocada não gira como furacão (%.0f°/s)" % giro_max)
	assert_true(w.is_finite_state())


func test_puxar_rapido_decepa_e_a_avoada_escapa() -> void:
	var w := _montagem()
	var a: Flyer = w.flyers[0]
	var b: Flyer = w.flyers[1]
	assert_true(_embolar(w))
	while b.cut_age < KiteCombatSystem.DECEPAR_GRACE + 0.1:
		w.step(DT)
	var soltos_antes := w.loose_chains.size()
	a.input.haul_speed = 6.0
	w.step(DT)
	w.step(DT)
	var no_tranco := _eventos_do_tipo(w.combat.take_events(), "decepou").size()
	assert_eq(no_tranco, 0, "um tranco curto não decepa")
	for i in roundi(0.4 / DT):
		w.step(DT)
	a.input.clear()
	var eventos := _eventos_do_tipo(w.combat.take_events(), "decepou")
	print("      [decepou] eventos %d; pedaços soltos %d → %d" % [eventos.size(), soltos_antes, w.loose_chains.size()])
	assert_eq(eventos.size(), 1, "a puxada rápida decepa")
	assert_true(b.caught_by == null, "a avoada escapa")
	assert_eq(a.holding, 0)
	assert_true(w.loose_chains.size() > soltos_antes, "o pedaço decepado cai solto")
	for i in 240:
		w.step(DT)
	assert_true(w.is_finite_state())


func test_avoada_sem_ninguem_embaixo_e_pipa_perdida() -> void:
	var w := _montagem(false)
	var b: Flyer = w.flyers[0]
	b.cut_line(12)
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


func test_bot_traz_a_pipa_embolada_sem_decepar() -> void:
	var w := _montagem()
	var a: Flyer = w.flyers[0]
	var b: Flyer = w.flyers[1]
	assert_true(_embolar(w))
	var bot := BotPilot.new(BotDifficulty.create(BotDifficulty.Level.NORMAL), 3)
	var aparou := false
	for i in roundi(60.0 / DT):
		bot.update(a, w.time)
		w.step(DT)
		if b.captured:
			aparou = true
			break
	print("      [bot manda busca] aparou: %s em %.1f s" % [aparou, w.time - 15.0])
	assert_true(aparou, "o bot sente a pipa embolada e recolhe devagar até a mão")


func test_quem_aparou_e_cortado_a_avoada_se_solta() -> void:
	var w := _montagem()
	var a: Flyer = w.flyers[0]
	var b: Flyer = w.flyers[1]
	var embolou := _embolar(w)
	assert_true(embolou)
	a.cut_line(2)
	w.step(DT)
	assert_true(b.caught_by == null, "sem a linha de A, nada segura a avoada")
	assert_eq(w.combat.links.size(), 0)



func test_avoada_desce_devagar_e_da_tempo_de_aparar() -> void:
	var w := _montagem(false)
	var b: Flyer = w.flyers[0]
	var p0 := b.kite.position
	b.cut_line(12)
	_rodar_seg(w, 5.0)
	var p1 := b.kite.position
	var longe := Vector2(p1.x - p0.x, p1.z - p0.z).length()
	print("      [avoada] em 5 s andou %.1f m e desceu %.1f m" % [longe, p0.y - p1.y])
	assert_true(longe < 30.0, "não vai embora rápido demais (%.1f m em 5 s)" % longe)


func _rodar_seg(w: SimWorld, s: float) -> void:
	for i in roundi(s / DT):
		w.step(DT)
