extends "res://tests/test_case.gd"
## Cenário e boneco (D-057): só visual, mas tem que montar sem erro.

const Ambiente := preload("res://game/world/ambiente.gd")
const Bairro := preload("res://game/world/bairro.gd")
const Boneco := preload("res://game/world/boneco.gd")


func test_shaders_carregam() -> void:
	for nome in ["ceu", "chao", "parede", "morro", "agua", "folhagem", "palha", "telha", "ceu_foto", "seda"]:
		var s: Shader = load("res://game/world/shaders/%s.gdshader" % nome)
		assert_not_null(s, "%s carrega" % nome)
		assert_true(s.code.length() > 100, "%s tem código" % nome)


## D-075: céu de foto em cada hora, com a luz do sol na altura do sol da foto.
func test_ceu_de_foto_com_sol_alinhado() -> void:
	var info = JSON.parse_string(FileAccess.get_file_as_string("res://assets/ceus/ceus.json"))
	for hora in ["manha", "meio_dia", "por_do_sol"]:
		var raiz := Node3D.new()
		Ambiente.criar(raiz, hora, "bairro")
		var amb: WorldEnvironment = raiz.get_node("Ambiente")
		var mat := amb.environment.sky.sky_material as ShaderMaterial
		assert_not_null(mat, "céu de %s é shader" % hora)
		assert_true(mat.shader.resource_path.ends_with("ceu_foto.gdshader"), "céu de %s é foto" % hora)
		assert_not_null(mat.get_shader_parameter("foto"), "a foto de %s carregou" % hora)
		var sol: DirectionalLight3D = raiz.get_node("Sol")
		var elev := float(info[hora]["sol_elevacao"])
		print("      [céu] %s: %s, sol a %.0f° (luz a %.0f°)" % [hora, info[hora]["nome"], elev, -sol.rotation_degrees.x])
		assert_true(absf(-sol.rotation_degrees.x - clampf(elev, 4.0, 75.0)) < 0.5, "luz na altura do sol da foto")
		raiz.free()


## D-075: a pipa é de papel de seda (shader) com varetas de bambu.
func test_pipa_de_papel_de_seda() -> void:
	var KV = load("res://game/views/kite_view.gd")
	var Est = load("res://game/views/estilos_pipa.gd")
	var v: Node3D = KV.new()
	v.call("construir", KiteDefinition.pipa_rio(), Est.ESTILOS[3])
	var vela: MeshInstance3D = v.get_node("Vela")
	var mat := vela.material_override as ShaderMaterial
	assert_not_null(mat)
	assert_true(mat.shader.resource_path.ends_with("seda.gdshader"), "vela de papel de seda")
	assert_not_null(v.get_node_or_null("Varetas"), "varetas com volume")
	v.free()


## D-067: as fotos CC0 estão no projeto e chegam aos shaders.
func test_texturas_fotograficas() -> void:
	var T = load("res://game/world/texturas.gd")
	for v in ["asfalto", "concreto", "terra", "grama", "areia", "reboco", "tijolo", "telha", "casca", "piso", "tecido"]:
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


## D-068: modelos 3D CC0 carregam e entram no cenário.
func test_modelos_3d() -> void:
	var M = load("res://game/world/modelos.gd")
	for n in ["plastic_monobloc_chair_01", "plastic_crate_02", "Barrel_02", "shrub_03", "fern_02", "potted_plant_04",
			"planter_pot_clay", "rollershutter_door", "utility_box_01", "trashbag", "street_lamp_02"]:
		assert_true(M.existe(n), "modelo %s existe" % n)
	assert_not_null(M.malha("shrub_03", "shrub_03_a"), "variante do arbusto")
	assert_not_null(M.malha("fern_02", "fern_02_b"), "variante da samambaia")
	var raiz := Node3D.new()
	Bairro.criar(raiz, 8, 7)
	var bairro: Node3D = raiz.get_node("Bairro")
	var cadeiras := 0
	var casinhas := 0
	for filho in bairro.get_children():
		if filho.scene_file_path.contains("plastic_monobloc_chair_01"):
			cadeiras += 1
		if filho is MultiMeshInstance3D and String(filho.name) == "Casinhas":
			casinhas += (filho as MultiMeshInstance3D).multimesh.instance_count
	print("      [cenário] %d cadeiras de laje, %d casinhas nos morros" % [cadeiras, casinhas])
	# D-069: fachadas 3D (janelas, portas, sacadas) numa malha só
	var fach: MeshInstance3D = bairro.get_node("Fachadas")
	var tri := (fach.mesh as ArrayMesh).surface_get_array_len(0) / 3
	print("      [cenário] fachadas 3D: %d triângulos" % tri)
	assert_true(tri > 5000, "fachadas com janelas e portas 3D")
	assert_not_null(bairro.get_node_or_null("Vidros"))
	assert_true(cadeiras >= 8, "cadeiras nas lajes")
	assert_true(casinhas > 1500, "serra cheia de casinhas 3D")
	# D-075: a serra é um terreno de verdade, com caixas d'água e mata
	assert_not_null(bairro.get_node_or_null("Serra"))
	assert_not_null(bairro.get_node_or_null("CaixasDagua"))
	assert_not_null(bairro.get_node_or_null("MataDaSerra"))
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
	tree.root.add_child(raiz)
	var b: Node3D = Boneco.new()
	raiz.add_child(b)
	b.call("construir", Color(0.5, 0.35, 0.25), Color.RED, Color.BLUE, true)
	# D-069: a mão (com cotovelo dobrado) chega no ponto da linha
	var mao := Vector3(0.35, 1.25, -0.3)
	for k in 30:
		b.call("atualizar", mao, Vector3(0.0, 20.0, -30.0), 0.0, 0.1)
	assert_true(b.get_child_count() > 0)
	var braco: Node3D = b.get("_braco_linha")
	var cot: Node3D = braco.get_node("Cotovelo")
	var ponta := cot.global_transform * Vector3(0.0, -b.ANTEBRACO, 0.0)
	print("      [boneco] mão a %.3f m do ponto da linha" % ponta.distance_to(mao))
	assert_true(ponta.distance_to(mao) < 0.03, "a mão alcança a linha")
	# longe do alcance (dando linha): o corpo se debruça para chegar mais perto
	var longe := b.global_position + Vector3(0.0, 1.5, -0.75)
	var erro_antes := (cot.global_transform * Vector3(0.0, -b.ANTEBRACO, 0.0)).distance_to(longe)
	for k in 40:
		b.call("atualizar", longe, Vector3(0.0, 20.0, -30.0), 0.0, 0.05)
	var erro := (cot.global_transform * Vector3(0.0, -b.ANTEBRACO, 0.0)).distance_to(longe)
	print("      [boneco] mão longe: faltava %.2f m, debruçando falta %.2f m" % [erro_antes, erro])
	assert_true(erro < 0.06, "debruçando, a mão chega na linha")
	for k in 60:
		b.call("atualizar", mao, Vector3(0.0, 20.0, -30.0), 0.0, 0.05)
	var cotovelo_y := cot.global_position.y
	assert_true(cotovelo_y < maxf(braco.global_position.y, mao.y), "cotovelo para baixo")
	raiz.queue_free()



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
