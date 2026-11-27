extends "res://tests/test_case.gd"
## D-086: experimento — barriga e "V" perto do cabresto nas linhas, conforme o
## jeito de rodar a física (passo, subpassos, passadas extras). A referência é
## 120 Hz × 4 (subpasso de 1/480 s), a física de todos os outros testes.
## Imprime uma tabela; o critério numérico fica em test_linha_firme_no_jogo.


func _medir(passo: float, sub: int, extras: int, segundos := 30.0) -> Dictionary:
	var modo := FreeMode.new(6, 7, true)
	modo.world.substeps = sub
	modo.passadas_extras = extras
	for p in modo.players:
		if p["flyer"] != null:
			(p["flyer"] as Flyer).extra_sweeps = extras
	var barriga := 0.0
	var v_max := 0.0
	var v_med := 0.0
	var tensao := 0.0
	var elev := 0.0
	var n := 0
	var custo := 0
	for k in roundi(segundos / passo):
		var t0 := Time.get_ticks_usec()
		modo.update(passo)
		custo += Time.get_ticks_usec() - t0
		if k * passo < 12.0 or k % 6 != 0:
			continue
		for f in modo.world.flyers:
			var fl: Flyer = f
			if fl.cut or fl.line == null or fl.line_length() < 15.0:
				continue
			var pos := fl.line.pos
			var a := pos[0]
			var b := pos[pos.size() - 1]
			var corda := b - a
			var L := corda.length()
			if L < 1.0:
				continue
			var dir := corda / L
			var maior := 0.0
			for i in range(1, pos.size() - 1):
				var r := pos[i] - a
				maior = maxf(maior, (r - dir * r.dot(dir)).length())
			barriga += maior / L * 100.0
			# "V": maior dobra entre segmentos vizinhos nos 6 últimos (perto do cabresto)
			var dobra := 0.0
			for i in range(maxi(1, pos.size() - 7), pos.size() - 1):
				var s1 := (pos[i] - pos[i - 1]).normalized()
				var s2 := (pos[i + 1] - pos[i]).normalized()
				dobra = maxf(dobra, rad_to_deg(acos(clampf(s1.dot(s2), -1.0, 1.0))))
			v_max = maxf(v_max, dobra)
			v_med += dobra
			tensao += fl.tension
			elev += fl.elevation_deg()
			n += 1
	var m := maxf(n, 1.0)
	return {"barriga": barriga / m, "v": v_med / m, "v_max": v_max, "tensao": tensao / m,
		"elev": elev / m, "ms_por_s": float(custo) / 1000.0 / segundos}


func _linha(nome: String, r: Dictionary) -> void:
	print("      [barriga] %-22s barriga %4.1f%% · V médio %4.1f° (pior %4.0f°) · tensão %5.1f N · elevação %3.0f° · %4.0f ms de CPU por s de jogo" % [
		nome, r["barriga"], r["v"], r["v_max"], r["tensao"], r["elev"], r["ms_por_s"]])


func test_linha_firme_no_jogo() -> void:
	var ref := _medir(1.0 / 120.0, 4, 0)
	_linha("120 Hz × 4 (referência)", ref)
	var jogo := _medir(1.0 / 60.0, 2, 2)
	_linha("60 Hz × 2 + 2 (0.30.3)", jogo)
	_linha("60 Hz × 2", _medir(1.0 / 60.0, 2, 0))
	_linha("60 Hz × 4", _medir(1.0 / 60.0, 4, 0))
	_linha("60 Hz × 4 + 2", _medir(1.0 / 60.0, 4, 2))
	_linha("60 Hz × 8", _medir(1.0 / 60.0, 8, 0))
	assert_true(ref["barriga"] < 30.0, "referência com barriga razoável")
