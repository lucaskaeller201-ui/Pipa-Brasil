extends "res://tests/test_case.gd"
## D-088: a linha de uma pipa que saiu da mão (5 m) e subiu dando linha tem
## que ficar igual à de uma pipa que já nasceu no alto: mesmo número de
## pontos (segmentos de ~1,25 m) e a mesma barriga.

const DT := 1.0 / 120.0


func _barriga(f: Flyer) -> float:
	var pos := f.line.pos
	var a := pos[0]
	var corda := pos[pos.size() - 1] - a
	var dir := corda.normalized()
	var maior := 0.0
	for i in range(1, pos.size() - 1):
		var r := pos[i] - a
		maior = maxf(maior, (r - dir * r.dot(dir)).length())
	return maior / corda.length() * 100.0


func _media_barriga(w: SimWorld, f: Flyer, s: float) -> float:
	var soma := 0.0
	var n := 0
	for i in roundi(s / DT):
		w.step(DT)
		if i % 12 == 0:
			soma += _barriga(f)
			n += 1
	return soma / n


func test_linha_solta_da_mao_igual_a_do_alto() -> void:
	# a sua pipa sai da mão (5 m) e sobe pela física, como no jogo
	var modo := FreeMode.new(1, 3, false)
	modo.put_you_on_hand()
	modo.launch_you(5, 2, true)
	var f: Flyer = modo.you()
	var r := 0
	var t := 0.0
	while r == 0 and t < 35.0:
		r = modo.subir(DT)
		modo.update(DT)
		t += DT
	print("      [linha da mão] subiu: r=%d, %.1f s, linha %.1f m, %d pontos" % [r, t, f.line_length(), f.line.size()])
	# depois dá linha até uns 40 m
	t = 0.0
	while f.line_length() < 40.0 and t < 40.0 and modo.world.is_finite_state():
		f.input.haul_speed = -2.0
		modo.update(DT)
		t += DT
		if fmod(t, 2.0) < DT:
			print("        t %.0f: linha %.1f m, %d pontos, rest0 %.2f, rest_length %.2f" % [t, f.line_length(), f.line.size(), f.line.rest[0], f.line.rest_length])
	f.input.haul_speed = 0.0
	for i in roundi(6.0 / DT):
		modo.update(DT)
	assert_true(modo.world.is_finite_state(), "estado finito")
	var b_mao := _media_barriga(modo.world, f, 8.0)
	var w2 := SimWorld.create_flight(modo.world.wind, f.kite.definition, f.line_length(), f.elevation_deg(), 0.0, 4, true, 3.0)
	var f2: Flyer = w2.flyers[0]
	for i in roundi(6.0 / DT):
		w2.step(DT)
	var b_alto := _media_barriga(w2, f2, 8.0)
	print("      [linha da mão] %.0f m: %d pontos (do alto: %d); barriga %.1f%% (do alto: %.1f%%)" % [
		f.line_length(), f.line.size(), f2.line.size(), b_mao, b_alto])
	assert_true(f.line.size() <= f2.line.size() + 3, "mesmo número de pontos")
	assert_true(b_mao < b_alto + 1.5, "mesma barriga")
