extends "res://tests/test_case.gd"
## Coeficientes de placa plana e forças da pipa parada no vento.


func test_coeficiente_zero_sem_angulo() -> void:
	assert_near(FlatPlate.normal_coefficient(0.0), 0.0, 1e-9)


func test_coeficiente_de_frente_para_o_vento() -> void:
	assert_near(FlatPlate.normal_coefficient(1.0), FlatPlate.CN_90, 1e-6)


func test_coeficiente_simetrico() -> void:
	for a in [5.0, 20.0, 45.0, 70.0]:
		var s := sin(deg_to_rad(a))
		assert_near(FlatPlate.normal_coefficient(-s), FlatPlate.normal_coefficient(s), 1e-9, "α = %s°" % a)


func test_pico_entre_45_e_75_graus() -> void:
	var melhor := 0.0
	var angulo_melhor := 0.0
	for a in range(0, 91):
		var c := FlatPlate.normal_coefficient(sin(deg_to_rad(a)))
		if c > melhor:
			melhor = c
			angulo_melhor = a
	assert_true(angulo_melhor >= 45.0 and angulo_melhor <= 75.0, "pico em %s°" % angulo_melhor)
	assert_true(melhor > FlatPlate.CN_90, "o pico passa do valor a 90°")


func test_pipa_de_frente_para_o_vento_e_empurrada_na_direcao_do_vento() -> void:
	var d := KiteDefinition.raia_laboratorio(0.0)  # sem diedro: placa plana
	var k := KiteBody.new(d)
	# Vento soprando para -Z; a face da pipa (+Z) recebe o vento de frente.
	k.reset_pose(Vector3(0.0, 10.0, 0.0), Quaternion.IDENTITY)
	var wind := WindField.new(6.0)
	k.compute_aero(wind, 0.0)
	var v := wind.sample(Vector3(0.0, 10.0, 0.0), 0.0).length()
	var esperado := 0.5 * KiteBody.RHO * v * v * d.total_area * FlatPlate.CN_90
	var f := k.last_aero_force
	assert_near(f.z, -esperado, esperado * 0.05, "força para onde o vento sopra")
	assert_near(f.x, 0.0, esperado * 0.01, "sem força lateral")
	assert_near(k.last_aoa_deg, 90.0, 0.5)


func test_pipa_de_lado_para_o_vento_quase_nao_tem_forca() -> void:
	var d := KiteDefinition.raia_laboratorio(0.0)
	var k := KiteBody.new(d)
	# Gira 90° em Y: o vento passa paralelo à placa.
	k.reset_pose(Vector3(0.0, 10.0, 0.0), Quaternion(Vector3.UP, PI / 2.0))
	k.compute_aero(WindField.new(6.0), 0.0)
	var v := 6.0
	var frente := 0.5 * KiteBody.RHO * v * v * d.total_area * FlatPlate.CN_90
	assert_true(k.last_aero_force.length() < frente * 0.05, "só sobra o atrito")


func test_area_da_raia() -> void:
	var d := KiteDefinition.raia_laboratorio(0.0)
	assert_near(d.total_area, 0.15, 1e-6, "losango de 0,60 m × 0,50 m")
	assert_eq(d.panel_areas.size(), 4)
