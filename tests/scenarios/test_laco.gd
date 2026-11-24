extends "res://tests/test_case.gd"
## Linhas laçadas (D-027): depois de laçadas, as linhas ficam juntas até uma
## romper — não se soltam do nada. E quem corre linha gasta a linha parada.
## (O cruzamento em si é testado em test_contato_linhas e acontece sozinho no
## modo livre; aqui o laço começa já feito, para o teste não depender do acaso.)

const DT := 1.0 / 120.0


func _mundo() -> SimWorld:
	var w := SimWorld.new()
	w.wind = WindField.new(5.0)
	w.add_flyer(KiteDefinition.pipa_rio(), Vector3.ZERO, 30.0, 50.0, 0.0, true, 3.0)
	w.add_flyer(KiteDefinition.pipa_rio(), Vector3(1.5, 0.0, 0.0), 30.0, 44.0, 0.0, true, 3.0)
	for i in roundi(6.0 / DT):
		w.step(DT)
	var a: Flyer = w.flyers[0]
	var b: Flyer = w.flyers[1]
	w.combat.engagements.append({"a": a, "b": b, "ma": a.line.rest_total() * 0.5, "mb": b.line.rest_total() * 0.5})
	return w


func test_linhas_lacadas_nao_se_soltam_ate_alguem_cortar() -> void:
	var w := _mundo()
	var a: Flyer = w.flyers[0]
	var b: Flyer = w.flyers[1]
	# Laçadas e paradas por 1,5 s (a pressão do começo do laço passa), depois
	# B descarrega devagar (sem largada) e A fica parada.
	for i in roundi(1.5 / DT):
		w.step(DT)
	if a.cut or b.cut:
		assert_true(false, "ninguém corta só com as linhas paradas")
		return
	b.input.haul_speed = -1.5
	var t := 0.0
	var soltou := false
	while not a.cut and not b.cut and t < 30.0:
		w.step(DT)
		t += DT
		if w.combat.engagements.is_empty() and not a.cut and not b.cut:
			soltou = true
			break
	var quem := "A" if a.cut else ("B" if b.cut else "ninguém")
	print("      [laço] %.1f s até o corte; cortada: %s" % [t, quem])
	assert_false(soltou, "as linhas não se soltaram sem corte")
	assert_true(a.cut or b.cut, "alguém foi cortado")
	assert_true(a.cut, "quem descarrega (B) gasta a linha parada (A)")
	assert_true(t > 0.5, "o laço leva um tempo até cortar (%.1f s)" % t)
	assert_true(w.is_finite_state())


func test_largada_puxa_e_solta_de_uma_vez_serra_mais() -> void:
	var w := _mundo()
	var b: Flyer = w.flyers[1]
	b.input.haul_speed = 3.0   # puxa: pressão na linha
	for i in roundi(0.4 / DT):
		w.step(DT)
	var memo := b.tension_memo
	b.input.haul_speed = -3.0  # solta de uma vez
	for i in roundi(0.15 / DT):
		w.step(DT)
	var fator := w.combat._largada(b)
	print("      [largada] pressão antes %.1f N; fator de corte %.1f" % [memo, fator])
	assert_true(memo > KiteCombatSystem.LARGADA_PRESSAO, "puxando, a linha ganhou pressão")
	assert_eq(fator, 2.0, "soltando de uma vez depois de puxar: largada")
