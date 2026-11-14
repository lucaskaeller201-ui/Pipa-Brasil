extends "res://tests/test_case.gd"
## Testes de fumaça: a cena principal abre sem erros e monta o que deveria.


func test_cena_principal_abre_e_monta_os_elementos() -> void:
	var cena: PackedScene = load("res://scenes/main/main.tscn")
	assert_not_null(cena, "a cena principal precisa carregar")
	if cena == null:
		return

	var raiz := cena.instantiate()
	assert_not_null(raiz, "a cena principal precisa instanciar")
	if raiz == null:
		return

	tree.root.add_child(raiz)  # dispara _ready()
	assert_true(raiz.is_node_ready(), "_ready() precisa ter rodado ao entrar na árvore")
	for nome in ["Ambiente", "Sol", "Chao", "PipaDecorativa", "Camera", "Interface"]:
		assert_not_null(raiz.get_node_or_null(nome), "faltou o nó %s" % nome)

	var texto: String = raiz.call("texto_info")
	assert_true(texto.contains("PIPA BRASIL"), "o texto de informação mostra o nome do jogo")
	assert_true(texto.contains("0.0.1"), "o texto de informação mostra a versão")

	raiz.queue_free()
