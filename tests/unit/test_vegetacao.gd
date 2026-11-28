extends "res://tests/test_case.gd"
## D-100: a mata da serra usa árvores de verdade em cartões (4 lados), mais
## árvores no Ultra que no Leve, e cada cartão tem só 2 triângulos.

const Bairro := preload("res://game/world/bairro.gd")


func _contar(qualidade: String) -> int:
	Bairro.qualidade = qualidade
	var raiz := Node3D.new()
	Bairro._morro(raiz)
	var n := 0
	for no in raiz.find_children("MataDaSerra_*", "MultiMeshInstance3D", true, false):
		var mm := (no as MultiMeshInstance3D).multimesh
		assert_true(mm.mesh is QuadMesh, "cartão é um retângulo")
		n += mm.instance_count
	raiz.free()
	Bairro.qualidade = "ultra"
	return n


func test_cartoes_das_arvores_estao_no_jogo() -> void:
	assert_true(Bairro._cartoes_existem())
	for info in Bairro.CARTOES:
		var tex := load("res://assets/vegetacao/%s_cartoes.png" % info[0]) as Texture2D
		assert_not_null(tex)
		assert_eq(tex.get_width(), tex.get_height() * 4, "4 lados lado a lado")


func test_mata_tem_mais_arvores_no_ultra_que_no_leve() -> void:
	var leve := _contar("leve")
	var ultra := _contar("ultra")
	assert_true(leve >= 1000, "leve: %d árvores" % leve)
	assert_true(ultra > leve, "ultra (%d) > leve (%d)" % [ultra, leve])
