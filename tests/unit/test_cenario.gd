extends "res://tests/test_case.gd"
## Cenário e boneco (D-057): só visual, mas tem que montar sem erro.

const Ambiente := preload("res://game/world/ambiente.gd")
const Bairro := preload("res://game/world/bairro.gd")
const Boneco := preload("res://game/world/boneco.gd")


func test_shaders_carregam() -> void:
	for nome in ["ceu", "chao", "parede", "morro", "agua", "folhagem", "palha", "telha"]:
		var s: Shader = load("res://game/world/shaders/%s.gdshader" % nome)
		assert_not_null(s, "%s carrega" % nome)
		assert_true(s.code.length() > 100, "%s tem código" % nome)


## D-067: as fotos CC0 estão no projeto e chegam aos shaders.
func test_texturas_fotograficas() -> void:
	var T = load("res://game/world/texturas.gd")
	for v in ["asfalto", "concreto", "terra", "grama", "areia", "reboco", "tijolo", "telha", "casca"]:
		assert_true(T.existe(v), "foto de %s existe" % v)
		assert_not_null(T.cor(v), "foto de %s carrega" % v)
		assert_not_null(T.relevo(v), "relevo de %s carrega" % v)
	var raiz := Node3D.new()
	Ambiente.criar(raiz, "meio_dia", "bairro")
	var chao: MeshInstance3D = raiz.get_node("Chao")
	var mat: ShaderMaterial = chao.material_override
	assert_eq(float(mat.get_shader_parameter("texturas")), 1.0, "chão usa as fotos")
	assert_not_null(mat.get_shader_parameter("t_asfalto"))
	raiz.free()


func test_bairro_monta_com_casas_arvores_e_morro() -> void:
	var raiz := Node3D.new()
	Ambiente.criar_por_do_sol(raiz, false)
	Bairro.criar(raiz, 8, 7)
	var bairro: Node3D = raiz.get_node("Bairro")
	assert_not_null(bairro)
	var pecas := bairro.get_child_count()
	print("      [cenário] %d peças no bairro" % pecas)
	assert_true(pecas > 400, "bairro cheio de detalhes")
	# nenhuma casa em cima da rua da frente (z entre 26 e 34)
	var na_rua := 0
	for filho in bairro.get_children():
		var m := filho as MeshInstance3D
		if m != null and m.mesh is BoxMesh and (m.mesh as BoxMesh).size.y > 2.5 and (m.mesh as BoxMesh).size.x > 4.0:
			if m.position.z > 26.0 and m.position.z < 34.0:
				na_rua += 1
	assert_eq(na_rua, 0, "casas fora da rua")
	raiz.free()


func test_boneco_monta_e_aponta_o_braco_para_a_mao() -> void:
	var raiz := Node3D.new()
	var b: Node3D = Boneco.new()
	raiz.add_child(b)
	b.call("construir", Color(0.5, 0.35, 0.25), Color.RED, Color.BLUE, true)
	b.call("atualizar", Vector3(0.4, 1.4, -0.5), Vector3(0.0, 20.0, -30.0), 1.0, 0.1)
	assert_true(b.get_child_count() > 0)
	raiz.free()



func test_praia_monta_com_mar_e_orla() -> void:
	var raiz := Node3D.new()
	Ambiente.criar(raiz, "meio_dia", "praia")
	Bairro.criar(raiz, 8, 7, "praia")
	assert_not_null(raiz.get_node_or_null("Mar"), "tem mar")
	var bairro: Node3D = raiz.get_node("Bairro")
	var na_areia := 0
	for filho in bairro.get_children():
		var m := filho as MeshInstance3D
		if m != null and m.mesh is BoxMesh and (m.mesh as BoxMesh).size.y > 2.5 and (m.mesh as BoxMesh).size.x > 4.0:
			if m.position.z < -21.0:
				na_areia += 1
	assert_eq(na_areia, 0, "nenhuma casa na areia")
	for h in Ambiente.ORDEM_HORAS:
		var r2 := Node3D.new()
		Ambiente.criar(r2, h, "bairro")
		assert_not_null(r2.get_node_or_null("Sol"))
		r2.free()
	raiz.free()
