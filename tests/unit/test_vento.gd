extends "res://tests/test_case.gd"
## WindSystem: direção, perfil de altura, rajada e determinismo.


func test_sem_turbulencia_vale_a_velocidade_a_10_m() -> void:
	var w := WindField.new(7.0)
	assert_vec_near(w.sample(Vector3(3.0, 10.0, -5.0), 12.3), Vector3(0.0, 0.0, -7.0), 1e-5)


func test_vento_aumenta_com_a_altura() -> void:
	var w := WindField.new(5.0)
	var baixo := w.sample(Vector3(0.0, 2.0, 0.0), 0.0).length()
	var alto := w.sample(Vector3(0.0, 40.0, 0.0), 0.0).length()
	assert_true(alto > baixo * 1.2, "a 40 m o vento é mais forte que a 2 m")


func test_rajada_em_degrau() -> void:
	var w := WindField.new(3.0)
	w.set_gust(10.0, 12.0, 2.0)
	var p := Vector3(0.0, 10.0, 0.0)
	assert_near(w.sample(p, 9.9).length(), 3.0, 1e-5)
	assert_near(w.sample(p, 10.5).length(), 12.0, 1e-5)
	assert_near(w.sample(p, 12.5).length(), 3.0, 1e-5)


func test_mesma_semente_mesmo_vento() -> void:
	var a := WindField.new(5.0, 0.2, 42)
	var b := WindField.new(5.0, 0.2, 42)
	for i in 20:
		var p := Vector3(i * 1.3, 5.0 + i, -i * 2.0)
		var t := i * 0.37
		assert_eq(a.sample(p, t), b.sample(p, t))


func test_turbulencia_varia_no_tempo() -> void:
	var w := WindField.new(5.0, 0.2, 7)
	var p := Vector3(0.0, 10.0, -20.0)
	assert_true(w.sample(p, 0.0).distance_to(w.sample(p, 3.0)) > 0.05)
