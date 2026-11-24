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


func _taxas(w: SimWorld, f: Flyer, n: int, passo := 0.05) -> Array[float]:
	var out: Array[float] = []
	for i in n:
		var a := f.nose_angle_deg()
		_rodar(w, passo)
		out.append(absf(_dif(f.nose_angle_deg(), a)) / passo)
	return out


func _giro_medio(velocidade: float) -> float:
	var w := _voo()
	var f: Flyer = w.flyers[0]
	f.input.haul_speed = -velocidade
	_rodar(w, 0.6)
	# Giro no plano da pipa (em torno da normal), medido no próprio corpo.
	var soma := 0.0
	var n := 0
	var soma_ceu := 0.0
	var taxas := _taxas(w, f, 16)
	for x in taxas:
		soma_ceu += x
	for i in roundi(0.8 / DT):
		w.step(DT)
		var normal := f.kite.rotation * Vector3(0.0, 0.0, 1.0)
		soma += absf(rad_to_deg(f.kite.angular_velocity.dot(normal)))
		n += 1
	print("      [giro %.1f m/s] no corpo %.0f°/s; visto do céu %.0f°/s; elevação %.0f°" % [velocidade, soma / n, soma_ceu / taxas.size(), f.elevation_deg()])
	return soma / n


func test_mandar_linha_gira_conforme_o_dedo() -> void:
	var devagar := _giro_medio(1.0)
	var rapido := _giro_medio(3.0)
	print("      [mandando linha] 1 m/s: %.0f°/s; 3 m/s: %.0f°/s" % [devagar, rapido])
	assert_true(devagar > 20.0 and devagar < 140.0, "devagar gira devagar (%.0f°/s)" % devagar)
	assert_true(rapido > devagar * 1.8, "mais rápido no dedo, mais giro")
	assert_true(rapido > 160.0 and rapido < 380.0, "rápido gira mais, sem furacão (%.0f°/s)" % rapido)


func test_soltar_o_dedo_freia_o_giro_em_fracao_de_segundo() -> void:
	var w := _voo()
	var f: Flyer = w.flyers[0]
	f.input.haul_speed = -3.5
	_rodar(w, 1.0)
	var antes := _taxas(w, f, 1)[0]
	f.input.clear()
	var depois := _taxas(w, f, 12)
	print("      [soltou] antes %.0f°/s; depois (a cada 0,05 s): %s" % [antes, depois.map(func(x): return roundi(x))])
	assert_true(depois[0] > 0.25 * antes, "não para seco: freia")
	var fim := (depois[8] + depois[9] + depois[10] + depois[11]) / 4.0
	assert_true(fim < 0.3 * antes, "em meio segundo quase parou (%.0f°/s)" % fim)


## Toque como no jogo: puxão curto e a mão recolhe a folga até esticar.
func _tocar(w: SimWorld, f: Flyer) -> void:
	f.input.clear()
	f.pilot.trigger(Pilot.Impulse.PUXAO, w.time)
	f.input.haul_speed = 4.0
	var t := 0.0
	while t < 0.4 and f.tension < 2.5:
		w.step(DT)
		t += DT
	f.input.clear()


func _tocar_lado(w: SimWorld, f: Flyer, lado: float) -> void:
	f.input.clear()
	f.input.kick_side = lado
	f.pilot.trigger(Pilot.Impulse.DESBICAR_LADO, w.time)
	f.input.haul_speed = 4.0
	var t := 0.0
	while t < 0.4 and (f.tension < 2.5 or t < Pilot.DESBICO_TIME):
		w.step(DT)
		t += DT
	f.input.clear()
	f.input.kick_side = lado


func test_toque_desbica_para_o_lado_pedido() -> void:
	for lado in [1.0, -1.0]:
		var w := _voo()
		var f: Flyer = w.flyers[0]
		var b0 := f.nose_angle_deg()
		var p0 := f.sky_position_deg()
		_tocar_lado(w, f, lado)
		var b1 := f.nose_angle_deg()
		_rodar(w, 0.5)
		var b2 := f.nose_angle_deg()
		var d := f.sky_position_deg() - p0
		print("      [desbico para %s] bico %.0f° → %.0f° → %.0f°; a pipa andou %.1f° de lado" % ["a direita" if lado > 0 else "a esquerda", b0, b1, b2, d.x])
		assert_true(_dif(b1, b0) * lado > 20.0 and _dif(b1, b0) * lado < 90.0, "o bico pulou para o lado do toque (%.0f°)" % _dif(b1, b0))
		assert_true(absf(_dif(b2, b1)) < 35.0, "e travou")
		assert_true(d.x * lado > 0.0, "a pipa foi para aquele lado")
		# dois toques do mesmo lado: mais um pulo
		_tocar_lado(w, f, lado)
		var b3 := f.nose_angle_deg()
		assert_true(_dif(b3, b2) * lado > 15.0, "outro toque, outro pulo para o mesmo lado")


## Dá linha, espera o bico apontar perto de `alvo` graus, toca (puxão) e puxa.
func _mirar_e_puxar(w: SimWorld, alvo: float, segundos: float) -> Dictionary:
	var f: Flyer = w.flyers[0]
	# Descarrega até o bico chegar perto do alvo (soltando um pouco antes, porque
	# o giro freia em fração de segundo) e puxa.
	f.input.haul_speed = -2.5
	var t := 0.0
	while absf(_dif(f.nose_angle_deg(), alvo - 25.0 * f.kite.definition.spin_give_sign)) > 8.0 and t < 8.0:
		w.step(DT)
		t += DT
	var bico0 := f.nose_angle_deg()
	f.input.haul_speed = 3.0
	var b_antes := f.nose_angle_deg()
	_rodar(w, 0.3)
	var giro_toque := absf(_dif(f.nose_angle_deg(), b_antes)) / 0.3
	var bico_travado := f.nose_angle_deg()
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


func test_puxando_a_pipa_vai_para_onde_o_bico_parou() -> void:
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
		assert_true(absf(_dif(media, r["bico0"])) < 45.0, "vai para onde o bico aponta (rumo %.0f°, bico %.0f°)" % [media, r["bico0"]])
		assert_true(absf(_dif(r["bico0"], r["bico_antes_do_toque"])) < 60.0, "puxando, o giro freia logo")
		# (o "para cima" do céu muda com a posição da pipa, por isso a folga)
		assert_true(absf(_dif(r["bico1"], r["bico0"])) < 35.0, "o bico não vira durante a puxada")
		assert_true(w.is_finite_state())


func test_o_vento_deixa_ir_bem_para_o_lado() -> void:
	for alvo in [-90.0, 90.0]:
		var w := _voo()
		var r := _mirar_e_puxar(w, alvo, 4.0)
		print("      [para o lado %.0f°] chegou a %.0f° de azimute; elevação mínima %.0f°" % [alvo, r["az_max"], r["el_min"]])
		assert_true(r["az_max"] > 30.0, "foi longe para o lado (%.0f°)" % r["az_max"])
		assert_true(r["el_min"] > -5.0)
