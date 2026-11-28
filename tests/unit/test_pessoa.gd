extends "res://tests/test_case.gd"
## D-099: personagens Rocketbox. Cada um carrega com esqueleto, tem altura de
## gente e a mão da linha chega até a mão da física (IK), em qualquer lado.

const Pessoa := preload("res://game/world/pessoa.gd")


func _pessoa(i: int) -> Node3D:
	var p: Node3D = Pessoa.new()
	tree.root.add_child(p)
	p.call("construir_pessoa", i, true, Color.RED)
	return p


func _mao_d(p: Node3D) -> Vector3:
	var esq: Skeleton3D = p.get("_esq")
	var b: int = (p.get("_ossos") as Dictionary)["mao_d"]
	return esq.global_transform * (p.call("_global", b) as Transform3D).origin


func test_modelos_estao_no_jogo() -> void:
	assert_true(Pessoa.disponivel(), "assets/personagens com os GLB")


func test_cada_personagem_carrega_com_os_ossos_do_braco() -> void:
	for i in Pessoa.MODELOS.size():
		var p := _pessoa(i)
		assert_not_null(p.get("_esq"), "esqueleto %d" % i)
		for k in ["ombro_d", "cot_d", "mao_d", "ombro_e", "cot_e", "mao_e", "cabeca"]:
			assert_true(int((p.get("_ossos") as Dictionary)[k]) >= 0, "osso %s no %d" % [k, i])
		var cab: int = (p.get("_ossos") as Dictionary)["cabeca"]
		var esq: Skeleton3D = p.get("_esq")
		var altura := (esq.global_transform * (p.call("_global", cab) as Transform3D).origin).y
		assert_true(altura > 1.4 and altura < 1.85, "cabeça a %.2f m no %d" % [altura, i])
		p.free()


func test_mao_da_linha_alcanca_a_mao_da_fisica() -> void:
	var p := _pessoa(0)
	var alvos := [Vector3(0.35, 1.35, -0.4), Vector3(0.1, 1.6, -0.45), Vector3(0.45, 1.1, -0.2), Vector3(-0.1, 1.4, -0.5)]
	for alvo in alvos:
		var pipa := (alvo as Vector3) + Vector3(0.0, 15.0, -30.0)
		for k in 10:
			p.call("atualizar", alvo, pipa, 0.0, 1.0 / 60.0)
		var erro := _mao_d(p).distance_to(alvo)
		assert_true(erro < 0.06, "mão a %.3f m do alvo %s" % [erro, alvo])
	p.free()


func test_puxando_a_outra_mao_vai_e_volta() -> void:
	var p := _pessoa(1)
	var esq: Skeleton3D = p.get("_esq")
	var b: int = (p.get("_ossos") as Dictionary)["mao_e"]
	var lo := INF
	var hi := -INF
	for k in 120:
		p.call("atualizar", Vector3(0.35, 1.35, -0.4), Vector3(0.0, 15.0, -30.0), 1.0, 1.0 / 60.0)
		var z := (esq.global_transform * (p.call("_global", b) as Transform3D).origin).z
		lo = minf(lo, z)
		hi = maxf(hi, z)
	assert_true(hi - lo > 0.08, "abraço com %.2f m de vaivém" % (hi - lo))
	p.free()
