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
	var w := SimWorld.create_flight(WindField.new(5.0, 0.0, 3), KiteDefinition.pipa_rio(), 5.0, 40.0, 0.0, 4, true, 0.0)
	var f: Flyer = w.flyers[0]
	f.input.haul_speed = -2.0
	var t := 0.0
	while f.line_length() < 40.0 and t < 60.0:
		w.step(DT)
		t += DT
	f.input.haul_speed = 0.0
	for i in roundi(6.0 / DT):
		w.step(DT)
	var b_mao := _media_barriga(w, f, 8.0)
	var w2 := SimWorld.create_flight(WindField.new(5.0, 0.0, 3), KiteDefinition.pipa_rio(), f.line_length(), f.elevation_deg(), 0.0, 4, true, 0.0)
	var f2: Flyer = w2.flyers[0]
	for i in roundi(6.0 / DT):
		w2.step(DT)
	var b_alto := _media_barriga(w2, f2, 8.0)
	print("      [linha da mão] %.0f m: %d pontos (do alto: %d); barriga %.1f%% (do alto: %.1f%%)" % [
		f.line_length(), f.line.size(), f2.line.size(), b_mao, b_alto])
	assert_true(f.line.size() <= f2.line.size() + 3, "mesmo número de pontos")
	assert_true(b_mao < b_alto + 1.5, "mesma barriga")
