extends "res://tests/test_case.gd"
## D-093: puxando a linha (braçada), a pipa vem lisa e rápida — sem trancos.
## Mede, como no jogo (60 × 3 + 4, modo leve), a linha que entra por segundo
## e os trancos (salto da velocidade da pipa de um passo para o outro), com
## os segmentos de agora (1,25 m) e os de antes da 0.30.6 (0,6 m).

const DT := 1.0 / 60.0


func _puxar(seg: float, haul: float) -> Dictionary:
	var w := SimWorld.create_flight(WindField.new(5.0, 0.0, 3), KiteDefinition.pipa_rio(), 40.0, 45.0, 0.0, 3, true, 3.0)
	w.leve = true
	var f: Flyer = w.flyers[0]
	f.extra_sweeps = 4
	f.line.rest_length = seg
	for i in roundi(4.0 / DT):
		w.step(DT)
	var l0 := f.line_length()
	var v_ant := f.kite.velocity
	var tranco := 0.0
	var soma := 0.0
	var n := 0
	f.input.haul_speed = haul
	for i in roundi(3.0 / DT):
		w.step(DT)
		var dv := (f.kite.velocity - v_ant).length() / DT
		v_ant = f.kite.velocity
		if i > 6:
			tranco = maxf(tranco, dv)
			soma += dv
			n += 1
	return {"entrou": (l0 - f.line_length()) / 3.0, "tranco_max": tranco, "tranco_medio": soma / n}


func test_puxada_lisa() -> void:
	for haul in [3.0, 6.0]:
		var novo := _puxar(SimWorld.TARGET_SEGMENT_LENGTH, haul)
		var antigo := _puxar(0.625, haul)
		print("      [puxada %.0f m/s] segmento 1,25 m: entram %.2f m/s, aceleração da pipa máx %.0f / média %.0f m/s² · segmento 0,6 m: %.2f m/s, máx %.0f / média %.0f" % [
			haul, novo["entrou"], novo["tranco_max"], novo["tranco_medio"], antigo["entrou"], antigo["tranco_max"], antigo["tranco_medio"]])
		assert_true(novo["entrou"] > 0.8 * haul, "a linha entra na velocidade da puxada")
		assert_true(novo["tranco_max"] < antigo["tranco_max"] * 1.5 + 5.0, "sem trancos a mais que antes")
