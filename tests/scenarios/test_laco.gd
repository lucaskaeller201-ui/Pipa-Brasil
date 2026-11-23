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
	b.input.haul_speed = -1.5   # B descarrega; A fica parada
	var t := 0.0
	var soltou := false
	var dist_max := 0.0
	while not a.cut and not b.cut and t < 30.0:
		w.step(DT)
		t += DT
		if w.combat.engagements.is_empty() and not a.cut and not b.cut:
			soltou = true
			break
		if t > 1.0 and not w.combat.contact_points.is_empty():
			var p := w.combat.contact_points[0]
			dist_max = maxf(dist_max, p.distance_to(b.line.pos[b.line.locate_material(float(w.combat.engagements[0]["mb"])).x]))
	var quem := "A" if a.cut else ("B" if b.cut else "ninguém")
	print("      [laço] %.1f s até o corte; cortada: %s" % [t, quem])
	assert_false(soltou, "as linhas não se soltaram sem corte")
	assert_true(a.cut or b.cut, "alguém foi cortado")
	assert_true(a.cut, "quem descarrega (B) gasta a linha parada (A)")
	assert_true(w.is_finite_state())
