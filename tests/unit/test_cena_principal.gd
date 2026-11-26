extends "res://tests/test_case.gd"

const Estilos := preload("res://game/views/estilos_pipa.gd")
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


func test_modo_livre_abre_e_as_pipas_voam() -> void:
	var cena: PackedScene = load("res://scenes/main/main.tscn")
	assert_not_null(cena, "a cena principal precisa carregar")
	if cena == null:
		return
	var raiz := cena.instantiate()
	raiz.set("_automatico", true)  # um bot pilota a sua pipa no teste
	tree.root.add_child(raiz)
	for nome in ["Linhas", "Camera", "Interface"]:
		assert_not_null(raiz.get_node_or_null(nome), "faltou o nó %s" % nome)
	assert_not_null(raiz.find_child("Sobreposicao", true, false), "faltou a sobreposição (carretilha e setas)")
	var modo: FreeMode = raiz.get("modo")
	assert_not_null(modo)
	assert_eq(modo.players.size(), 6, "você e 5 bots (festival)")
	var alto := {}
	for k in 20:
		raiz.call("avancar", 1.0)
		for p in modo.players:
			var f: Flyer = p["flyer"]
			alto[p["name"]] = maxf(float(alto.get(p["name"], 0.0)), f.kite.position.y)
	for nome in alto:
		assert_true(float(alto[nome]) > 15.0, "%s subiu a pipa (máx %.1f m)" % [nome, alto[nome]])
	assert_true(modo.world.is_finite_state())
	raiz.call("_process", 0.016)
	raiz.queue_free()


## Gesto de puxar: dedo na tela deslizando para baixo vira puxada (não descarrega).
func test_deslizar_para_baixo_puxa() -> void:
	var cena: PackedScene = load("res://scenes/main/main.tscn")
	var raiz := cena.instantiate()
	tree.root.add_child(raiz)
	var modo: FreeMode = raiz.get("modo")
	assert_true(modo.you_on_hand, "o jogo começa com a pipa na mão (D-037)")
	assert_null(modo.you(), "nenhuma pipa sua no alto antes de escolher")
	raiz.call("_process", 1.0 / 60.0)   # a tela sem pipa no alto não quebra
	raiz.call("_jogar")   # sai da página inicial (D-063)
	raiz.call("_colocar_no_alto")
	raiz.call("avancar", 3.0)
	var eu := modo.you()
	assert_not_null(eu, "colocou a pipa no alto")
	var toque := InputEventScreenTouch.new()
	toque.index = 0
	toque.position = Vector2(640, 300)
	toque.pressed = true
	raiz.call("_input", toque)
	# dedo parado um tempo (como quem encosta antes de puxar)
	var dedos: Dictionary = raiz.get("_dedos")
	(dedos[0] as Dictionary)["t0"] = float((dedos[0] as Dictionary)["t0"]) - 1.0
	var maior := 0.0
	for k in 6:
		var arrasto := InputEventScreenDrag.new()
		arrasto.index = 0
		arrasto.position = Vector2(640, 300 + 25 * (k + 1))
		arrasto.relative = Vector2(0, 25)
		raiz.call("_input", arrasto)
		raiz.call("_process", 1.0 / 60.0)
		raiz.call("_physics_process", 1.0 / 120.0)
		maior = maxf(maior, eu.input.haul_speed)
	print("      [gesto] puxada pelo deslizar: %.1f m/s" % maior)
	assert_true(maior > 2.0, "deslizar para baixo puxa (%.1f m/s)" % maior)
	# parou o dedo depois de puxar: segura, não descarrega
	raiz.call("_process", 1.0 / 60.0)
	raiz.call("_physics_process", 1.0 / 120.0)
	assert_true(eu.input.haul_speed >= 0.0, "dedo de puxar parado não descarrega")
	raiz.queue_free()


## D-070: duplo = dois toques com menos de 0,3 s, com o bico em qualquer
## posição (sem as travas de pausa e de 20°); segurar parado 1 s = puxão.
func test_toque_duplo_livre_e_puxao_segurando() -> void:
	var cena: PackedScene = load("res://scenes/main/main.tscn")
	var raiz := cena.instantiate()
	tree.root.add_child(raiz)
	raiz.call("_jogar")   # sai da página inicial (D-063)
	raiz.call("_colocar_no_alto")
	raiz.call("avancar", 3.0)
	var t := 100.0
	raiz.set("_duplo_t", -99.0)
	raiz.set("_ultimo_duplo", false)
	raiz.set("_penultimo_toque", t - 0.4)
	raiz.set("_ultimo_toque", t - 0.2)
	var modo: FreeMode = raiz.get("modo")
	print("      [duplo] bico em %.0f°" % modo.you().nose_angle_deg())
	assert_true(bool(raiz.call("_eh_toque_duplo", t)), "dois toques juntos = duplo, mesmo com o bico para cima e no ritmo")
	raiz.set("_ultimo_toque", t - 0.45)
	assert_false(bool(raiz.call("_eh_toque_duplo", t)), "toques separados = tenteio")
	raiz.set("_ultimo_toque", t - 0.1)
	raiz.set("_ultimo_duplo", true)
	assert_false(bool(raiz.call("_eh_toque_duplo", t)), "o toque depois de um duplo começa de novo")
	# puxão: segurar o dedo parado
	var eu: Flyer = modo.you()
	raiz.call("_toque", 0, Vector2(900, 400), true)
	var dedos: Dictionary = raiz.get("_dedos")
	dedos[0]["t0"] = float(dedos[0]["t0"]) - 0.5
	raiz.call("_ver_toque_pendente")
	assert_eq(int(raiz.get("_puxoes")), 0, "meio segundo ainda não é puxão")
	var linha0 := eu.line_length()
	var tensao0 := eu.tension
	dedos[0]["t0"] = float(dedos[0]["t0"]) - 0.6
	raiz.call("_ver_toque_pendente")
	raiz.call("_ver_toque_pendente")
	assert_eq(int(raiz.get("_puxoes")), 1, "1 s parado = um puxão (só um por dedo)")
	var maior := tensao0
	for k in 40:
		raiz.call("_physics_process", 1.0 / 120.0)
		maior = maxf(maior, eu.tension)
	print("      [puxão] tensão %.1f → pico %.1f N; recolheu %.2f m" % [tensao0, maior, linha0 - eu.line_length()])
	assert_true(maior > tensao0 * 1.3, "o puxão dá um tranco na linha")
	assert_true(linha0 - eu.line_length() > 0.8, "e recolhe linha")
	raiz.call("_toque", 0, Vector2(900, 400), false)
	raiz.queue_free()



## D-063: o jogo abre na página inicial; trocar mapa e hora remonta o cenário.
func test_pagina_inicial_mapa_e_hora() -> void:
	var cena: PackedScene = load("res://scenes/main/main.tscn")
	var raiz := cena.instantiate()
	tree.root.add_child(raiz)
	assert_true(bool(raiz.get("_no_lobby")), "abre na página inicial")
	var lobby: Control = raiz.get("_lobby")
	assert_true(lobby.visible)
	var mapa_antes := String(raiz.get("_mapa"))
	raiz.call("_trocar_mapa")
	assert_true(String(raiz.get("_mapa")) != mapa_antes, "trocou o mapa")
	raiz.call("_trocar_mapa")
	assert_eq(String(raiz.get("_mapa")), mapa_antes, "volta ao primeiro mapa")
	for k in 3:
		raiz.call("_trocar_hora")
	# D-066: começa em ULTRA (antisserrilhado ligado) e troca de qualidade
	assert_eq(String(raiz.get("_graficos")), "ultra")
	assert_eq(raiz.get_viewport().msaa_3d, Viewport.MSAA_4X, "ULTRA liga o antisserrilhado")
	for k in 3:
		raiz.call("_trocar_graficos")
	assert_eq(String(raiz.get("_graficos")), "ultra", "volta ao ULTRA")
	raiz.set("_mapa", "praia")
	raiz.call("_montar_cenario")
	var cenario: Node3D = raiz.get("_cenario")
	assert_not_null(cenario.get_node_or_null("Mar"), "a praia tem mar")
	raiz.call("_process", 1.0 / 60.0)
	raiz.call("_jogar")
	assert_false(lobby.visible, "JOGAR fecha a página inicial")
	raiz.call("_process", 1.0 / 60.0)
	raiz.queue_free()



## D-064: COLOCAR NO ALTO abre a escolha da pipa e depois da linha.
func test_escolher_pipa_e_linha() -> void:
	var cena: PackedScene = load("res://scenes/main/main.tscn")
	var raiz := cena.instantiate()
	tree.root.add_child(raiz)
	raiz.call("_jogar")
	var modo: FreeMode = raiz.get("modo")
	assert_true(modo.you_on_hand)
	raiz.call("_abrir_pipas")
	var grade: GridContainer = raiz.get("_sel_grade")
	assert_eq(grade.get_child_count(), Estilos.ESTILOS.size(), "um cartão por pipa")
	raiz.call("_escolheu_pipa", 13)
	assert_eq(grade.get_child_count() > 0, true)
	raiz.call("_process", 1.0 / 60.0)
	raiz.call("_escolheu_linha", 3)
	assert_false(modo.you_on_hand, "a pipa subiu")
	assert_eq(modo.you_style, 13)
	assert_eq(modo.you_line, 3)
	assert_not_null(modo.you())
	raiz.queue_free()
