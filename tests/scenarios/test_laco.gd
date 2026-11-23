extends "res://tests/test_case.gd"
## Linhas laçadas (D-027): quando duas linhas em voo se encostam, ficam juntas
## até uma romper — não se soltam do nada. E a linha que corre gasta a outra.

const DT := 1.0 / 120.0


func _mundo() -> SimWorld:
	var w := SimWorld.new()
	w.wind = WindField.new(5.0)
	w.add_flyer(KiteDefinition.pipa_rio(), Vector3.ZERO, 30.0, 50.0, 0.0, true, 3.0)
	w.add_flyer(KiteDefinition.pipa_rio(), Vector3(12.0, 0.0, 0.0), 30.0, 22.0, -10.0, true, 3.0)
	for i in roundi(8.0 / DT):
		w.step(DT)
	return w


## B anda pela laje de um lado para o outro, passando a linha por baixo da de A.
func _cruzar(w: SimWorld) -> bool:
	var b: Flyer = w.flyers[1]
	for i in roundi(12.0 / DT):
		b.pilot.base.x = maxf(-25.0, b.pilot.base.x - 4.0 * DT)
		w.step(DT)
		if not w.combat.engagements.is_empty():
			return true
	return false


func test_linhas_lacadas_nao_se_soltam_ate_alguem_cortar() -> void:
	var w := _mundo()
	assert_true(_cruzar(w), "as linhas se encontraram e laçaram")
	var a: Flyer = w.flyers[0]
	var b: Flyer = w.flyers[1]
	# B descarrega (dá linha) sobre a linha de A, que fica parada.
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
	assert_true(w.is_finite_state())
