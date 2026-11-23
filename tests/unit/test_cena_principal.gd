extends "res://tests/test_case.gd"
## Testes de fumaça: a partida (cena principal) e o laboratório de voo abrem,
## montam o que deveriam e as pipas voam usando o núcleo físico.


func test_laboratorio_abre_e_a_pipa_voa() -> void:
	var cena: PackedScene = load("res://scenes/lab/lab.tscn")
	assert_not_null(cena, "o laboratório precisa carregar")
	if cena == null:
		return

	var raiz := cena.instantiate()
	assert_not_null(raiz, "a cena principal precisa instanciar")
	if raiz == null:
		return

	tree.root.add_child(raiz)  # dispara _ready()
	assert_true(raiz.is_node_ready(), "_ready() precisa ter rodado ao entrar na árvore")
	for nome in ["Ambiente", "Sol", "Chao", "Pipeiro", "Pipa", "Linhas", "Forcas", "Camera", "Interface"]:
		assert_not_null(raiz.get_node_or_null(nome), "faltou o nó %s" % nome)

	raiz.call("avancar", 3.0)
	var world: SimWorld = raiz.get("world")
	assert_not_null(world)
	if world != null:
		assert_true(world.is_finite_state())
		assert_true(world.kite.position.y > 5.0, "depois de 3 s a pipa está no ar (y = %.1f m)" % world.kite.position.y)

	var texto: String = raiz.call("texto_info")
	assert_true(texto.contains("PIPA BRASIL"), "o painel mostra o nome do jogo")
	assert_true(texto.contains("Tensão"), "o painel mostra a tensão da linha")

	# Liga a pipa rival (bot) e o piloto automático: o mundo passa a ter 2 pipeiros.
	raiz.call("_ao_mudar_rival", true)
	raiz.call("_ao_mudar_piloto", true)
	world = raiz.get("world")
	assert_eq(world.flyers.size(), 2, "a rival entra no mundo")
	for i in 120:
		raiz.call("_physics_process", 1.0 / 120.0)
	assert_true(world.is_finite_state())

	raiz.queue_free()


func test_partida_abre_e_as_duas_pipas_voam() -> void:
	var cena: PackedScene = load("res://scenes/main/main.tscn")
	assert_not_null(cena, "a cena principal precisa carregar")
	if cena == null:
		return
	var raiz := cena.instantiate()
	raiz.set("_automatico", true)  # um bot pilota a sua pipa no teste
	tree.root.add_child(raiz)
	for nome in ["Pipa", "PipaRival", "Linhas", "Camera", "Interface", "Mao"]:
		assert_not_null(raiz.get_node_or_null(nome), "faltou o nó %s" % nome)
	assert_not_null(raiz.get_node_or_null("Camera/Carretilha"), "a carretilha fica presa à câmera")
	assert_not_null(raiz.get_node_or_null("Interface"))
	var regras: MatchRules = raiz.get("regras")
	assert_not_null(regras)
	assert_eq(regras.mode(), MatchRules.Mode.SUBA, "a partida começa pelo suba a pipa")
	assert_true(String(raiz.get("apelido_rival")).length() > 2, "o rival tem apelido")
	raiz.call("avancar", 6.0)
	regras = raiz.get("regras")
	assert_eq(regras.state, MatchRules.State.PLAYING, "depois da contagem, valendo")
	for i in 2:
		var f: Flyer = regras.world.flyers[i]
		assert_true(f.kite.position.y > 8.0, "pipa %d no ar acima da laje (y = %.1f m)" % [i, f.kite.position.y])
	assert_true(regras.world.is_finite_state())
	raiz.call("_process", 0.016)
	raiz.queue_free()
