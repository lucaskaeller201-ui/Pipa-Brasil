extends "res://tests/test_case.gd"
## D-089: mãos em primeira pessoa. Os modelos e as poses carregam, e cada
## comando tem um movimento próprio (puxando ≠ mandando ≠ desbicando), que
## vem do estado da física.

const MaosView := preload("res://game/views/maos_view.gd")


func _montar() -> Array:
	var cam := Camera3D.new()
	tree.root.add_child(cam)
	var maos: Node3D = MaosView.new()
	cam.add_child(maos)
	maos.call("preparar", 0.45)
	return [cam, maos]


func _rodar(cam: Camera3D, maos: Node3D, estado: Dictionary, s: float) -> Array:
	var traj: Array = []
	for i in roundi(s * 60.0):
		maos.call("atualizar", cam, estado, 1.0 / 60.0)
		traj.append(maos.call("ponto_mao", "d"))
	return traj


func _alcance(traj: Array) -> float:
	var lo := Vector3(INF, INF, INF)
	var hi := -lo
	for p in traj:
		lo = lo.min(p)
		hi = hi.max(p)
	return (hi - lo).length()


func test_maos_carregam_com_esqueleto_e_poses() -> void:
	var r := _montar()
	var maos: Node3D = r[1]
	assert_true(bool(maos.get("pronto")))
	var dados: Dictionary = maos.get("_mao")
	for lado in ["d", "e"]:
		var m: Dictionary = dados[lado]
		assert_not_null(m["esqueleto"], "mão %s com esqueleto" % lado)
		var poses: Dictionary = m["poses"]
		for p in ["default_pose", "pinch_tight", "pinch_large", "grip", "hold"]:
			assert_true((poses[p] as Dictionary).size() >= 10, "pose %s da mão %s com os ossos dos dedos" % [p, lado])
	(r[0] as Node).queue_free()


func test_cada_comando_tem_movimento_proprio() -> void:
	var r := _montar()
	var cam: Camera3D = r[0]
	var maos: Node3D = r[1]
	var parado := _rodar(cam, maos, {"modo": "voo", "tensao": 5.0}, 2.0)
	var puxando := _rodar(cam, maos, {"modo": "voo", "tensao": 5.0, "haul": 3.0}, 2.0)
	var mandando := _rodar(cam, maos, {"modo": "voo", "tensao": 5.0, "haul": -3.0}, 2.0)
	var p_parado: Vector3 = parado[parado.size() - 1]
	var p_mandando: Vector3 = mandando[mandando.size() - 1]
	# desbico: estalo curto
	var desb: Array = []
	for i in 15:
		maos.call("atualizar", cam, {"modo": "voo", "tensao": 5.0, "desbico": i / 60.0, "lado": 1.0}, 1.0 / 60.0)
		desb.append(maos.call("ponto_mao", "d"))
	print("      [mãos] alcance da mão da linha: parado %.3f m · puxando %.3f m · mandando %.3f m · desbico %.3f m" % [
		_alcance(parado.slice(60)), _alcance(puxando.slice(30)), _alcance(mandando.slice(60)), _alcance(desb)])
	assert_true(_alcance(parado.slice(60)) < 0.02, "parada, a mão quase não mexe")
	assert_true(_alcance(puxando.slice(30)) > 0.08, "puxando, a braçada leva a mão para trás e para a frente")
	assert_true(p_mandando.z < p_parado.z - 0.02, "mandando, a mão vai para a frente (deixa a linha correr)")
	assert_true(_alcance(desb) > 0.02, "o desbico mexe a mão de uma vez")
	# a mão da frente acompanha o braço da física (Pilot.arm_offset)
	var recuada := _rodar(cam, maos, {"modo": "voo", "arm": -0.4}, 1.0)
	var avancada := _rodar(cam, maos, {"modo": "voo", "arm": 0.4}, 1.0)
	assert_true((avancada[avancada.size() - 1] as Vector3).z < (recuada[recuada.size() - 1] as Vector3).z - 0.1, "a mão segue o braço do pipeiro da física")
	cam.queue_free()
