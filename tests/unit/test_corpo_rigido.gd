extends "res://tests/test_case.gd"
## Corpo rígido da pipa: queda livre, rotação e correções de posição.


func test_queda_livre_sem_ar() -> void:
	var d := KiteDefinition.raia_laboratorio()
	var k := KiteBody.new(d)
	k.reset_pose(Vector3(0.0, 100.0, 0.0), Quaternion.IDENTITY)
	var h := 1.0 / 480.0
	for i in 480:  # 1 s, sem chamar a aerodinâmica (força aerodinâmica zero)
		k.integrate(h)
		k.update_velocities(h)
	assert_near(k.position.y, 100.0 - 0.5 * 9.81, 0.05, "s = g·t²/2")
	assert_near(k.velocity.y, -9.81, 0.05)


func test_rotacao_livre_continua_normalizada() -> void:
	var k := KiteBody.new(KiteDefinition.raia_laboratorio())
	k.reset_pose(Vector3.ZERO, Quaternion.IDENTITY)
	k.angular_velocity = Vector3(3.0, 1.0, -2.0)
	var h := 1.0 / 480.0
	for i in 2400:
		k.position = Vector3.ZERO
		k.velocity = Vector3.ZERO
		k.integrate(h)
		k.update_velocities(h)
	assert_near(k.rotation.length(), 1.0, 1e-5)
	assert_true(k.angular_velocity.is_finite())
	assert_true(k.angular_velocity.length() < 20.0, "a rotação livre não ganha energia")


func test_correcao_no_centro_de_massa_so_translada() -> void:
	var k := KiteBody.new(KiteDefinition.raia_laboratorio())
	k.reset_pose(Vector3.ZERO, Quaternion.IDENTITY)
	k.apply_position_impulse(Vector3.ZERO, Vector3(0.0, 0.025, 0.0))
	assert_vec_near(k.position, Vector3(0.0, 1.0, 0.0), 1e-5, "Δx = P/m")
	assert_near(k.rotation.get_angle(), 0.0, 1e-6)
