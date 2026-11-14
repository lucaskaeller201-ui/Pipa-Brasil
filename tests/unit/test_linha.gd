extends "res://tests/test_case.gd"
## RopePhysics: comprimento, alcance máximo e linha parada sem tremer.


func _cadeia(inicio: Vector3, fim: Vector3, segmentos: int) -> ParticleChain:
	# Linha de náilon fina, presa na ponta 0.
	var c := ParticleChain.new(ParticleChain.Kind.LINE, inicio, fim,
		segmentos, 0.003, 1.0 / 600.0, 0.0006, 1.1)
	c.inv_mass[0] = 0.0
	return c


func _simular(c: ParticleChain, segundos: float) -> void:
	var sem_vento := WindField.new(0.0)
	var h := 1.0 / 480.0
	var anchor := c.pos[0]
	for i in roundi(segundos / h):
		c.compute_forces(sem_vento, 0.0)
		c.integrate(h)
		c.pos[0] = anchor
		c.solve_segments(h)
		c.solve_max_reach()
		c.update_velocities(h)


func test_linha_balancando_mantem_o_comprimento() -> void:
	var c := _cadeia(Vector3(0.0, 20.0, 0.0), Vector3(10.0, 20.0, 0.0), 10)
	_simular(c, 6.0)
	assert_near(c.current_length(), c.rest_total(), c.rest_total() * 0.01, "erro de comprimento até 1%")
	assert_true(c.pos[c.size() - 1].is_finite())


func test_linha_pendurada_parada_nao_treme() -> void:
	var c := _cadeia(Vector3(0.0, 20.0, 0.0), Vector3(0.0, 10.0, 0.0), 10)
	_simular(c, 3.0)
	assert_vec_near(c.pos[c.size() - 1], Vector3(0.0, 10.0, 0.0), 0.1, "a ponta fica onde estava")
	assert_true(c.max_speed() < 0.05, "velocidade máxima %.4f m/s" % c.max_speed())


func test_alcance_maximo_nunca_e_ultrapassado() -> void:
	var c := _cadeia(Vector3(0.0, 20.0, 0.0), Vector3(12.0, 20.0, 0.0), 12)
	_simular(c, 3.0)
	for i in range(1, c.size()):
		var dist := c.pos[i].distance_to(c.pos[0])
		assert_true(dist <= i * c.rest_length + 1e-4, "partícula %d" % i)
