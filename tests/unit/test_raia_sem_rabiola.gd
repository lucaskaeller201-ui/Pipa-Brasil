extends "res://tests/test_case.gd"
## Modelo experimental da raia sem rabiola: vareta flexível e momentos de giro.


func _pipa_inclinada(def: KiteDefinition, giro_no_plano_deg: float) -> KiteBody:
	# Pipa a 20 m, inclinada 30° para trás e girada no próprio plano, para o
	# vento ter uma componente ao longo da vela.
	var k := KiteBody.new(def)
	var q := Quaternion(Vector3.RIGHT, deg_to_rad(-30.0)) * Quaternion(Vector3.BACK, deg_to_rad(giro_no_plano_deg))
	k.reset_pose(Vector3(0.0, 20.0, 0.0), q)
	return k


func _torque_na_normal(k: KiteBody) -> float:
	k.compute_aero(WindField.new(6.0), 0.0)
	return k._spin_moments(WindField.new(6.0), 0.0).dot(k.rotation * Vector3.BACK)


func test_vareta_enverga_com_a_tensao_e_relaxa_sem_ela() -> void:
	var k := KiteBody.new(KiteDefinition.raia_sem_rabiola())
	for i in 240:
		k.update_flex(5.0, 1.0 / 480.0)
	assert_near(k.bow_factor(), 1.0, 1e-3, "linha esticada: vareta envergada")
	for i in 960:
		k.update_flex(0.0, 1.0 / 480.0)
	assert_true(k.bow_factor() < 0.05, "linha frouxa: vareta relaxada")


func test_raia_de_laboratorio_nao_usa_o_modelo_novo() -> void:
	var k := _pipa_inclinada(KiteDefinition.raia_laboratorio(), 25.0)
	assert_near(_torque_na_normal(k), 0.0, 1e-9, "a raia da Fase 1 continua igual")


func test_vareta_envergada_alinha_a_pipa_com_o_fluxo() -> void:
	var def := KiteDefinition.raia_sem_rabiola()
	def.spin_bias = 0.0
	var a := _pipa_inclinada(def, 25.0)
	var b := _pipa_inclinada(def, -25.0)
	var ta := _torque_na_normal(a)
	var tb := _torque_na_normal(b)
	print("      [vareta envergada] torque com +25°: %.5f N·m, com −25°: %.5f N·m" % [ta, tb])
	assert_true(ta * tb < 0.0, "giros opostos geram torques opostos")
	assert_true(absf(ta) > 1e-4)


func test_tendencia_de_giro_so_com_a_linha_frouxa() -> void:
	var def := KiteDefinition.raia_sem_rabiola()
	def.bow_stability = 0.0
	var k := _pipa_inclinada(def, 0.0)
	k.dihedral = deg_to_rad(def.dihedral_max_deg)
	var esticada := _torque_na_normal(k)
	k.dihedral = deg_to_rad(def.dihedral_min_deg)
	var frouxa := _torque_na_normal(k)
	print("      [tendência de giro] esticada %.5f N·m, frouxa %.5f N·m" % [esticada, frouxa])
	assert_near(esticada, 0.0, 1e-9)
	assert_true(frouxa * def.spin_bias > 0.0, "gira no sentido preferido da pipa")


func test_giro_e_amortecido() -> void:
	var def := KiteDefinition.raia_sem_rabiola()
	def.bow_stability = 0.0
	def.spin_bias = 0.0
	var k := _pipa_inclinada(def, 0.0)
	k.angular_velocity = k.rotation * Vector3(0.0, 0.0, 20.0)
	assert_true(_torque_na_normal(k) < 0.0, "o arrasto freia o giro")


func test_sem_autorrotacao_descontrolada() -> void:
	var maximo := 0.0
	for semente in [1, 2, 3]:
		var w := SimWorld.create_flight(WindField.new(5.0, 0.15, semente), KiteDefinition.raia_sem_rabiola(),
			30.0, 30.0, 0.0, 4, true, 3.0)
		for i in 1800:  # 15 s
			w.step(1.0 / 120.0)
			var n := w.kite.rotation * Vector3.BACK
			maximo = maxf(maximo, absf(w.kite.angular_velocity.dot(n)))
		assert_true(w.is_finite_state())
	print("      [sem rabiola] giro máximo %.1f rad/s (%.1f voltas/s)" % [maximo, maximo / TAU])
	assert_true(maximo < 25.0, "no máximo 4 voltas por segundo (antes do modelo: 9)")
