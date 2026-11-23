extends "res://tests/test_case.gd"
## Pipa do Rio (D-026), com as regras pedidas pelo Lucas:
## 1. com a linha esticada não anda de lado: vai para onde o bico aponta;
## 2. dando linha, gira num ritmo constante e legível;
## 3. um toque (puxão curto) trava o giro e ela arranca reta;
## 4. tem rabiola. E o vento deixa ir bem para os lados.
## Faixas calibradas no protótipo (tools/prototipo/fase4/exp8.py e exp9.py).

const DT := 1.0 / 120.0


func _voo(semente := 2) -> SimWorld:
	var w := SimWorld.create_flight(WindField.new(5.0, 0.15, semente), KiteDefinition.pipa_rio(), 30.0, 45.0, 0.0, 4, true, 3.0)
	_rodar(w, 12.0)
	return w


func _rodar(w: SimWorld, s: float) -> void:
	for i in roundi(s / DT):
		w.step(DT)


func _dif(a: float, b: float) -> float:
	return wrapf(a - b, -180.0, 180.0)


func test_tem_rabiola_e_fica_parada_com_o_bico_para_cima() -> void:
	var w := _voo()
	var f: Flyer = w.flyers[0]
	assert_not_null(f.tail, "a pipa do Rio tem rabiola")
	var bico := 0.0
	for i in roundi(10.0 / DT):
		w.step(DT)
		bico = maxf(bico, absf(f.nose_angle_deg()))
	print("      [pipa do Rio parada, turbulência] bico até %.0f°; elevação %.0f°" % [bico, f.elevation_deg()])
	assert_true(bico < 25.0, "bico para cima (máx %.0f°)" % bico)
	assert_true(f.elevation_deg() > 35.0)


func test_dando_linha_gira_num_ritmo_constante() -> void:
	var w := _voo()
	var f: Flyer = w.flyers[0]
	f.input.haul_speed = -3.0
	var taxas: Array[float] = []
	for i in 10:
		var a := f.nose_angle_deg()
		_rodar(w, 0.2)
		taxas.append(_dif(f.nose_angle_deg(), a) / 0.2)
	f.input.clear()
	print("      [dando linha 3 m/s] giro (°/s) a cada 0,2 s: %s" % [taxas.map(func(x): return roundi(x))])
	var soma := 0.0
	for k in range(3, 10):
		soma += absf(taxas[k])
		assert_true(absf(taxas[k]) < 185.0, "nunca gira rápido demais (%.0f°/s)" % taxas[k])
	var media := soma / 7.0
	assert_true(media > 100.0, "gira de verdade enquanto descarrega (média %.0f°/s)" % media)
	assert_true(w.is_finite_state())


## Dá linha, espera o bico apontar perto de `alvo` graus, toca (puxão) e puxa.
func _mirar_e_puxar(w: SimWorld, alvo: float, segundos: float) -> Dictionary:
	var f: Flyer = w.flyers[0]
	f.input.haul_speed = -3.0
	var t := 0.0
	while absf(_dif(f.nose_angle_deg(), alvo)) > 12.0 and t < 8.0:
		w.step(DT)
		t += DT
	f.input.clear()
	var bico0 := f.nose_angle_deg()
	f.pilot.trigger(Pilot.Impulse.PUXAO, w.time)
	var b_antes := f.nose_angle_deg()
	_rodar(w, 0.15)
	var giro_toque := absf(_dif(f.nose_angle_deg(), b_antes)) / 0.15
	var bico_travado := f.nose_angle_deg()
	f.input.haul_speed = 3.0
	var p0 := f.sky_position_deg()
	var rumos: Array[float] = []
	var az_max := 0.0
	var el_min := 90.0
	var anterior := p0
	for i in roundi(segundos / 0.25):
		_rodar(w, 0.25)
		var p := f.sky_position_deg()
		var d := p - anterior
		if d.length() > 0.5:
			# azimute vale menos no alto do céu: corrige por cos(elevação)
			rumos.append(rad_to_deg(atan2(d.x * cos(deg_to_rad(p.y)), d.y)))
		anterior = p
		az_max = maxf(az_max, absf(p.x))
		el_min = minf(el_min, p.y)
	f.input.clear()
	return {"bico0": bico_travado, "bico_antes_do_toque": bico0, "bico1": f.nose_angle_deg(), "giro_toque": giro_toque, "rumos": rumos,
		"az_max": az_max, "el_min": el_min, "andou": f.sky_position_deg() - p0}


func test_toque_trava_o_giro_e_a_pipa_vai_reta_como_flecha() -> void:
	for alvo in [-60.0, 50.0, 0.0]:
		var w := _voo()
		var r := _mirar_e_puxar(w, alvo, 2.0)
		var rumos: Array[float] = r["rumos"]
		print("      [mira %.0f°] bico %.0f° → %.0f°; giro logo após o toque %.0f°/s; rumo: %s; andou %s" % [
			alvo, r["bico0"], r["bico1"], r["giro_toque"], rumos.map(func(x): return roundi(x)), r["andou"]])
		assert_true(rumos.size() >= 4, "andou durante a puxada")
		var media := 0.0
		for x in rumos:
			media += x
		media /= maxf(1.0, rumos.size())
		for x in rumos:
			assert_true(absf(_dif(x, media)) < 15.0, "trajetória reta (rumo %.0f°, média %.0f°)" % [x, media])
		assert_true(absf(_dif(media, r["bico0"])) < 25.0, "vai para onde o bico aponta (rumo %.0f°, bico %.0f°)" % [media, r["bico0"]])
		assert_true(absf(_dif(r["bico0"], r["bico_antes_do_toque"])) < 15.0, "o toque trava o bico quase onde estava")
		assert_true(absf(_dif(r["bico1"], r["bico0"])) < 20.0, "o bico não vira durante a puxada")
		assert_true(w.is_finite_state())


func test_o_vento_deixa_ir_bem_para_o_lado() -> void:
	for alvo in [-90.0, 90.0]:
		var w := _voo()
		var r := _mirar_e_puxar(w, alvo, 4.0)
		print("      [para o lado %.0f°] chegou a %.0f° de azimute; elevação mínima %.0f°" % [alvo, r["az_max"], r["el_min"]])
		assert_true(r["az_max"] > 50.0, "foi longe para o lado (%.0f°)" % r["az_max"])
		assert_true(r["el_min"] > -2.0)
