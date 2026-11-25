extends "res://tests/test_case.gd"
## "Pipa reta" (pedido do Lucas): a raia sem rabiola bem feita não "dá de lado".
## Com a linha esticada, vai para onde o bico aponta, sem virar sozinha; os
## toques (desbicar) giram o bico aos poucos.

const DT := 1.0 / 120.0


func _voo(turbulencia := 0.0, semente := 1) -> SimWorld:
	var w := SimWorld.create_flight(WindField.new(5.0, turbulencia, semente), KiteDefinition.raia_sem_rabiola(), 30.0, 45.0, 0.0, 4, true, 3.0)
	_rodar(w, 12.0)
	return w


func _rodar(w: SimWorld, s: float) -> void:
	for i in roundi(s / DT):
		w.step(DT)


func _f(w: SimWorld) -> Flyer:
	return w.flyers[0]


## Diferença entre dois ângulos em graus, entre -180 e 180.
func _dif(a: float, b: float) -> float:
	return wrapf(a - b, -180.0, 180.0)


func test_parada_com_turbulencia_o_bico_nao_vira_sozinho() -> void:
	for semente in [1, 2, 3]:
		var w := _voo(0.15, semente)
		var f := _f(w)
		var bico_max := 0.0
		var lado_max := 0.0
		for i in roundi(20.0 / DT):
			w.step(DT)
			bico_max = maxf(bico_max, absf(f.nose_angle_deg()))
			lado_max = maxf(lado_max, absf(f.sky_position_deg().x))
		print("      [parada, turbulência, semente %d] bico até %.0f° de lado; pipa até %.0f° para o lado; elevação %.0f°" % [
			semente, bico_max, lado_max, f.elevation_deg()])
		assert_true(bico_max < 35.0, "o bico fica para cima (máx %.0f°)" % bico_max)
		assert_true(lado_max < 25.0, "a pipa não escapa para o lado (máx %.0f°)" % lado_max)


func test_toques_giram_o_bico_e_a_puxada_vai_para_onde_ele_aponta() -> void:
	var w := _voo()
	var f := _f(w)
	var toques := 0
	var giros: Array[float] = []
	# Toques duplos (D-050/D-058: cada um leva a direção 30°), um a cada 0,5 s,
	# até o bico apontar uns 60° ou mais para o lado.
	f.input.kick_spin = 1.0
	f.input.kick_base_shift = 30.0
	while absf(f.nose_angle_deg()) < 60.0 and toques < 12:
		var antes := f.nose_angle_deg()
		f.pilot.trigger(Pilot.Impulse.DESBICAR_LADO, w.time)
		_rodar(w, 0.5)
		toques += 1
		giros.append(_dif(f.nose_angle_deg(), antes))
	f.input.kick_spin = 0.0
	f.input.kick_base_shift = 0.0
	var bico := f.nose_angle_deg()
	print("      [desbicar] %d toques; giro por toque: %s; bico em %.0f°" % [toques, giros, bico])
	assert_true(absf(bico) >= 60.0, "com toques o bico chega ao lado (%.0f°)" % bico)
	assert_true(toques <= 10, "não precisa de muitos toques")

	# Puxa com a mão 3 m/s por 1,2 s: a pipa anda para o lado do bico, em linha reta.
	var p0 := f.sky_position_deg()
	var bico0 := bico
	var rumo: Array[float] = []
	var anterior := p0
	f.input.haul_speed = 3.0
	for i in 6:
		_rodar(w, 0.2)
		var p := f.sky_position_deg()
		var d := Vector2(p.x - anterior.x, p.y - anterior.y)
		if d.length() > 0.3:
			rumo.append(rad_to_deg(atan2(d.x, d.y)))   # 0 = subindo, + = para a direita
		anterior = p
	f.input.clear()
	var p1 := f.sky_position_deg()
	print("      [puxada] bico %.0f° → %.0f°; rumo a cada 0,2 s: %s; andou %.0f° de lado e %.0f° de altura" % [
		bico0, f.nose_angle_deg(), rumo, p1.x - p0.x, p1.y - p0.y])
	assert_true(signf(p1.x - p0.x) == signf(bico0), "foi para o lado do bico")
	assert_true(absf(p1.x - p0.x) > 8.0, "andou de verdade (%.0f°)" % (p1.x - p0.x))
	assert_true(absf(_dif(f.nose_angle_deg(), bico0)) < 40.0, "o bico não virou durante a puxada")
	assert_true(w.is_finite_state())
