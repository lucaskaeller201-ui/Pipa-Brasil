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
	var giro_plano := 0.0
	for i in roundi(40.0 / DT):
		w.step(DT)
		if i > 120 and not b.captured:
			giro_max = maxf(giro_max, rad_to_deg(b.kite.angular_velocity.length()))
			var n := b.kite.rotation * Vector3(0.0, 0.0, 1.0)
			giro_plano = maxf(giro_plano, absf(rad_to_deg(b.kite.angular_velocity.dot(n))))
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
	print("      [manda busca] giro da rebocada no próprio plano: até %.1f°/s" % giro_plano)
	assert_true(giro_plano < 5.0, "a aparada vem reta, sem rodar (D-037) (%.1f°/s)" % giro_plano)
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
	for i in roundi(1.0 / DT):
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
	assert_true(longe < 22.0, "não vai embora rápido demais (%.1f m em 5 s)" % longe)
	assert_true(longe > 2.0, "mas também não fica parada (%.1f m em 5 s)" % longe)


func _rodar_seg(w: SimWorld, s: float) -> void:
	for i in roundi(s / DT):
		w.step(DT)


## D-044: puxando num ritmo normal (3 m/s) a aparada vem, não decepa.
func test_puxar_normal_nao_decepa() -> void:
	var w := _montagem()
	var a: Flyer = w.flyers[0]
	var b: Flyer = w.flyers[1]
	assert_true(_embolar(w))
	while b.cut_age < KiteCombatSystem.DECEPAR_GRACE + 0.1:
		w.step(DT)
	a.input.haul_speed = 3.0
	for i in roundi(2.0 / DT):
		w.step(DT)
	a.input.clear()
	var eventos := _eventos_do_tipo(w.combat.take_events(), "decepou")
	assert_eq(eventos.size(), 0, "puxar normal não decepa")
	assert_true(b.caught_by == a or b.captured, "a avoada continua no aparo")


## D-044: tenteando sem parar uns 3 s, a avoada sai do aparo.
func test_tentear_sai_do_aparo() -> void:
	var w := _montagem()
	var a: Flyer = w.flyers[0]
	var b: Flyer = w.flyers[1]
	assert_true(_embolar(w))
	var soltou := -1.0
	var t0 := w.time
	for k in 20:
		a.input.kick_side = 1.0 if k % 2 == 0 else -1.0
		a.pilot.trigger(Pilot.Impulse.DESBICAR_LADO, w.time)
		for i in roundi(0.3 / DT):
			w.step(DT)
		if b.caught_by == null and not b.captured:
			soltou = w.time - t0
			break
	print("      [sair do aparo] soltou depois de %.1f s tenteando" % soltou)
	assert_true(soltou >= 2.5 and soltou <= 4.5, "sai do aparo tenteando uns 3 s (%.1f s)" % soltou)
	assert_eq(_eventos_do_tipo(w.combat.take_events(), "soltou").size(), 1)


## D-053: aparada pela rabiola vem rodando em volta do eixo; pela linha, reta.
func test_aparada_pela_rabiola_vem_rodando() -> void:
	var giro_rabiola := _giro_rebocada(true)
	var giro_linha := _giro_rebocada(false)
	print("      [aparada] giro em volta do eixo: pela rabiola %.0f°/s, pela linha %.0f°/s" % [giro_rabiola, giro_linha])
	assert_true(giro_rabiola > 150.0, "pela rabiola vem rodando (%.0f°/s)" % giro_rabiola)
	assert_true(giro_linha < 40.0, "pela linha vem sem rodar (%.0f°/s)" % giro_linha)


func _giro_rebocada(pela_rabiola: bool) -> float:
	var w := _montagem(true)
	var a: Flyer = w.flyers[0]
	var b: Flyer = w.flyers[1]
	b.cut_line(12)
	b.caught_by = a
	# um embolo de verdade, pela rabiola ou pela linha da avoada
	var pedaco: ParticleChain = b.tail if pela_rabiola else b.trailing_line
	w.combat.links.append({"avoada": b, "chain": pedaco, "idx": mini(3, pedaco.size() - 1), "catcher": a,
		"cchain": a.line, "m": a.line.rest_total() * 0.5, "captured": false})
	var soma := 0.0
	var n := 0
	for i in roundi(2.0 / DT):
		w.step(DT)
		if i > 60:
			var eixo := b.kite.rotation * Vector3.UP
			soma += absf(rad_to_deg(b.kite.angular_velocity.dot(eixo)))
			n += 1
	assert_true(w.is_finite_state())
	return soma / maxf(1.0, n)


## D-056: abraçando (puxando forte) com a linha em cima da rabiola de uma pipa
## em voo, a rabiola dela é fatiada — sem ela estar avoada. (O contato em si é
## o mesmo de sempre; aqui ele é informado direto a cada passo.)
func test_fatiar_a_rabiola_de_quem_esta_voando() -> void:
	var r := _fatiar(6.0)
	assert_true(bool(r["fatiou"]), "fatiou a rabiola")
	assert_false(bool(r["cortada"]), "a pipa do rival continua voando")
	assert_true(int(r["depois"]) < int(r["antes"]), "sobrou um pedaço da rabiola (%d de %d pontos)" % [r["depois"], r["antes"]])


func test_puxar_devagar_nao_fatia_a_rabiola() -> void:
	var r := _fatiar(2.0)
	assert_false(bool(r["fatiou"]), "devagar não fatia")
	assert_eq(int(r["depois"]), int(r["antes"]))


func _fatiar(velocidade: float) -> Dictionary:
	var w := _montagem(true)
	var a: Flyer = w.flyers[0]
	var b: Flyer = w.flyers[1]
	var antes := b.tail.size()
	a.input.haul_speed = velocidade
	var fatiou := false
	for i in roundi(1.5 / DT):
		if a.kite.spin_mode == KiteBody.SpinMode.SPIN_LOCK and a.line_rate > KiteCombatSystem.DECEPAR_RAPIDO:
			w.combat._fatia_want[b] = [b.tail, b.tail.size() / 2, a]
		w.step(DT)
		for e in w.combat.take_events():
			if e["type"] == "fatiou" and bool(e["voando"]):
				fatiou = true
		if fatiou:
			break
	a.input.clear()
	assert_true(w.is_finite_state())
	return {"fatiou": fatiou, "cortada": b.cut, "antes": antes, "depois": b.tail.size()}


## D-061: já no seu aparo pela linha, dá para embolar também pela rabiola.
func test_aparada_pela_linha_tambem_embola_pela_rabiola() -> void:
	var w := _montagem(true)
	var a: Flyer = w.flyers[0]
	var b: Flyer = w.flyers[1]
	assert_true(_embolar(w))
	assert_eq(b.caught_by, a)
	var primeiro: ParticleChain = w.combat.links[0]["chain"]
	var outro: ParticleChain = b.tail if primeiro != b.tail else b.trailing_line
	assert_not_null(outro, "a avoada tem o outro pedaço")
	# o embolo do outro pedaço já formado (o contato em si é o de sempre)
	var chave := [b.get_instance_id(), a.get_instance_id(), outro.get_instance_id()]
	w.combat._tangle[chave] = {"t": KiteCombatSystem.TANGLE_TIME + 0.1, "last": w.time, "av": b, "ct": a,
		"chain": outro, "idx": 2, "cchain": a.line, "m": 1.0}
	a.input.haul_speed = -1.0   # mandando linha (girando)
	w.step(DT)
	a.input.clear()
	var dela := 0
	for l in w.combat.links:
		if l["avoada"] == b:
			dela += 1
	assert_eq(dela, 2, "presa pela linha e pela rabiola")
	if outro == b.tail:
		w.step(DT)
		assert_true(b.caught_by_tail, "presa pela rabiola: vem rodando")
	assert_true(w.is_finite_state())
