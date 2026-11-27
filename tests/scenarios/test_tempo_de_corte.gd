extends "res://tests/test_case.gd"
## D-087: o tempo até cortar no laço não pode mudar com o jeito de rodar a
## física no jogo (o Lucas sentiu que estava demorando mais). Mesmo laço do
## test_laco, nas configurações de cada versão; o jogo tem que cortar no
## mesmo tempo da referência (120 × 4, como era até a 0.29).


func _corte(passo: float, sub: int, leve: bool, extras_a: int, extras_b: int, largada: bool) -> float:
	var w := SimWorld.new()
	w.wind = WindField.new(5.0)
	w.substeps = sub
	w.leve = leve
	var a := w.add_flyer(KiteDefinition.pipa_rio(), Vector3.ZERO, 30.0, 50.0, 0.0, true, 3.0)
	var b := w.add_flyer(KiteDefinition.pipa_rio(), Vector3(1.5, 0.0, 0.0), 30.0, 44.0, 0.0, true, 3.0)
	a.extra_sweeps = extras_a
	b.extra_sweeps = extras_b
	for i in roundi(6.0 / passo):
		w.step(passo)
	w.combat.engagements.append({"a": a, "b": b, "ma": a.line.rest_total() * 0.5, "mb": b.line.rest_total() * 0.5})
	for i in roundi(1.5 / passo):
		w.step(passo)
	var t := 0.0
	if largada:
		b.input.haul_speed = 3.0
		while t < 0.4:
			w.step(passo)
			t += passo
		b.input.haul_speed = -3.0
	else:
		b.input.haul_speed = -1.5
	while not a.cut and not b.cut and t < 30.0:
		w.step(passo)
		t += passo
	return t if a.cut or b.cut else 99.0


func _linha(nome: String, cfg: Array) -> Array:
	var r := [_corte(cfg[0], cfg[1], cfg[2], cfg[3], cfg[4], false),
		_corte(cfg[0], cfg[1], cfg[2], cfg[3], cfg[4], true)]
	print("      [corte] %-34s descarregando %5.1f s · largada %5.1f s" % [nome, r[0], r[1]])
	return r


func test_tempo_de_corte_igual_a_referencia() -> void:
	var ref := _linha("referência 120 × 4 (até 0.29)", [1.0 / 120.0, 4, false, 0, 0])
	_linha("0.30.3 (60 × 2 + 2)", [1.0 / 60.0, 2, false, 2, 2])
	var jogo := _linha("jogo: 60 × 3 + 4 leve", [1.0 / 60.0, 3, true, 4, 4])
	for k in 2:
		assert_true(absf(jogo[k] - ref[k]) < 0.15 * ref[k] + 0.3, "corta no mesmo tempo da referência (%.1f s × %.1f s)" % [jogo[k], ref[k]])
