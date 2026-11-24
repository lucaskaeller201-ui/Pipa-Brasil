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
	# freia até quase parar; depois o vento vai trazendo o bico para cima (mola)
	var menor: float = depois.min()
	assert_true(menor < 0.3 * antes, "em meio segundo quase parou (%.0f°/s)" % menor)


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


func _tentear(w: SimWorld, f: Flyer, lado: float) -> void:
	f.input.kick_side = lado
	f.pilot.trigger(Pilot.Impulse.DESBICAR_LADO, w.time)
	_rodar(w, 0.7)   # o arco do tenteio vai freando (D-040)


func test_tenteio_cada_toque_para_um_lado_e_o_vento_traz_de_volta() -> void:
	var w := _voo()
	var f: Flyer = w.flyers[0]
	var l0 := f.line_length()
	var b0 := f.nose_angle_deg()
	_tentear(w, f, 1.0)
	var b1 := f.nose_angle_deg()
	_tentear(w, f, -1.0)
	var b2 := f.nose_angle_deg()
	_tentear(w, f, -1.0)
	var b3 := f.nose_angle_deg()
	_rodar(w, 0.4)
	var b_pausa := f.nose_angle_deg()
	_rodar(w, 1.6)
	var b4 := f.nose_angle_deg()
	print("      [tenteio] bico %.0f° → (direita) %.0f° → (esquerda) %.0f° → (esquerda) %.0f°; parado 1 s: %.0f°; linha %.1f → %.1f m" % [b0, b1, b2, b3, b4, l0, f.line_length()])
	assert_true(_dif(b1, b0) > 25.0 and _dif(b1, b0) < 50.0, "toque para a direita: pulo firme (%.0f°)" % _dif(b1, b0))
	assert_true(_dif(b2, b1) < -10.0, "toque para a esquerda: pulo para o outro lado (%.0f°)" % _dif(b2, b1))
	assert_true(absf(_dif(b3, b2)) < 12.0, "outro para a esquerda: fica do lado esquerdo, não acumula (D-049)")
	assert_true(absf(_dif(b_pausa, b3)) < 15.0, "logo depois do toque, o bico fica onde foi (%.0f° → %.0f°)" % [b3, b_pausa])
	assert_true(absf(b4) < absf(b_pausa) - 4.0, "parando um tempo, o vento vai trazendo o bico para cima (%.0f° → %.0f°)" % [b_pausa, b4])
	assert_true(absf(f.line_length() - l0) < 0.5, "o tenteio não puxa nem solta linha de verdade")


func test_tenteio_e_puxada_vai_para_onde_o_bico_apontou() -> void:
	var w := _voo()
	var f: Flyer = w.flyers[0]
	var p0 := f.sky_position_deg()
	_tentear(w, f, 1.0)   # um toque: ~60° (vários seguidos dão a volta, D-038)
	var bico := f.nose_angle_deg()
	f.input.haul_speed = 3.0
	_rodar(w, 0.8)
	f.input.clear()
	var d := f.sky_position_deg() - p0
	print("      [tenteio + puxada] bico %.0f°; a pipa andou %.1f° de lado e %.1f° de altura" % [bico, d.x, d.y])
	assert_true(bico > 25.0 and bico < 120.0, "um toque para a direita (%.0f°)" % bico)
	assert_true(d.x > 2.0, "puxando, foi para a direita")


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
			assert_true(absf(_dif(x, media)) < 20.0, "trajetória reta (rumo %.0f°, média %.0f°)" % [x, media])
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


func test_tocar_rapido_tenteia_e_nao_roda() -> void:
	# D-049: dez toques rápidos (um para cada lado): o bico balança em volta
	# da direção em que estava, sem rodar.
	var w := _voo()
	var f: Flyer = w.flyers[0]
	var b0 := f.nose_angle_deg()
	var maior := 0.0
	var lado := 1.0
	for k in 10:
		f.input.kick_spin = lado
		f.pilot.trigger(Pilot.Impulse.DESBICAR_LADO, w.time)
		lado = -lado
		for i in roundi(0.15 / DT):
			w.step(DT)
			maior = maxf(maior, absf(_dif(f.nose_angle_deg(), b0)))
	f.input.kick_spin = 0.0
	print("      [tenteio rápido] 10 toques: o bico saiu no máximo %.0f° da direção" % maior)
	assert_true(maior > 15.0, "o bico balança")
	assert_true(maior < 60.0, "não roda (%.0f°)" % maior)
	assert_true(w.is_finite_state())

func test_tenteio_murcha_um_lado() -> void:
	var w := _voo()
	var f: Flyer = w.flyers[0]
	var maior := 0.0
	for k in 3:
		f.input.kick_spin = 1.0
		f.pilot.trigger(Pilot.Impulse.DESBICAR_LADO, w.time)
		for i in roundi(0.2 / DT):
			w.step(DT)
			maior = maxf(maior, absf(rad_to_deg(f.kite.roll_angle())))
	f.input.kick_spin = 0.0
	_rodar(w, 3.0)
	var depois := absf(rad_to_deg(f.kite.roll_angle()))
	print("      [murcha] inclinação no tenteio até %.0f°; depois de parar %.0f°" % [maior, depois])
	assert_true(maior > 8.0, "girando, a pipa murcha de um lado (%.0f°)" % maior)
	assert_true(w.is_finite_state())


## D-042: largada — puxou forte e mandou linha logo depois: coice para a frente.
func test_largada_da_coice() -> void:
	var com := _coice(true)
	var sem := _coice(false)
	print("      [largada] avanço para a frente em 0,6 s: com puxada antes %.1f m, sem %.1f m" % [com, sem])
	assert_true(com > sem + 0.5, "na largada a pipa dá um coice para a frente")


func _coice(puxar_antes: bool) -> float:
	var w := _voo()
	var f: Flyer = w.flyers[0]
	if puxar_antes:
		f.input.haul_speed = 5.0
		_rodar(w, 0.5)
	f.input.haul_speed = -3.0
	var bico := f.kite.rotation * Vector3.UP
	var p0 := f.kite.position
	var l0 := f.line_length()
	var paralinha := (f.kite.position - f.hand_position).normalized()
	var dir0 := f.kite.lunge_dir()
	_rodar(w, 0.6)
	f.input.clear()
	var dp := f.kite.position - p0
	print("      [largada %s] andou %.1f m (ao longo da linha %.1f m, bico·linha %.2f); linha %.1f → %.1f m" % [
		"com" if puxar_antes else "sem", dp.length(), dp.dot(paralinha), bico.dot(paralinha), l0, f.line_length()])
	if puxar_antes:
		assert_eq(f.lunges, 1, "deu uma largada")
	return dp.dot(dir0)
