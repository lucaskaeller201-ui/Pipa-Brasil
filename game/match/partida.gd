extends Node3D
## Fase 5 — Partida 1 contra 1 na laje (tela principal, celular em pé).
##
## Visão em primeira pessoa: a carretilha no canto de baixo à esquerda, a mão
## segurando a linha, a linha saindo da mão para o céu. Botões embaixo do
## polegar, com vários toques ao mesmo tempo. A física é a mesma do
## laboratório; as regras estão em MatchRules.

const BuildInfo := preload("res://game/main/build_info.gd")
const Ambiente := preload("res://game/world/ambiente.gd")
const Bairro := preload("res://game/world/bairro.gd")
const Setup := preload("res://game/modes/match_setup.gd")
const KiteView := preload("res://game/views/kite_view.gd")
const LinesView := preload("res://game/views/lines_view.gd")

## Botões: nome -> tipo ("segurar" ou "toque").
const BOTOES := [
	["PUXA", "segurar"], ["PUXÃO", "toque"], ["DESBICA", "toque"],
	["SOLTA", "segurar"], ["DÁ LINHA", "segurar"], ["RECOLHE", "segurar"],
]
const TECLAS := {"PUXA": KEY_W, "SOLTA": KEY_Z, "DÁ LINHA": KEY_A, "RECOLHE": KEY_R, "AFROUXA": KEY_S}
const TECLAS_TOQUE := {KEY_SPACE: "PUXÃO", KEY_E: "DESBICA", KEY_Q: "ARRANCÃO"}

var regras: MatchRules
var apelido_rival := ""

var _semente := 1
var _primeira_pessoa := true
var _automatico := false   ## bot pilota a sua pipa (capturas e demonstração)
var _bot_rival: BotPilot
var _bot_meu: BotPilot
var _mundo_visto: SimWorld
var _jogos_criados := 0

var _camera: Camera3D
var _carretilha: Node3D
var _mao: MeshInstance3D
var _pipa: Node3D
var _pipa_rival: Node3D
var _rival_corpo: MeshInstance3D
var _meu_corpo: MeshInstance3D
var _linhas: MeshInstance3D

var _placar: Label
var _rodada: Label
var _alturas: Label
var _aviso: Label
var _aviso_ate := 0.0
var _botoes := {}           # nome -> Button
var _toques := {}           # índice do toque (ou -2 para o mouse) -> nome do botão
var _botao_novamente: Button


func _ready() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg == "--auto":
			_automatico = true
		elif arg == "--terceira":
			_primeira_pessoa = false
		elif arg.begins_with("--semente="):
			_semente = arg.trim_prefix("--semente=").to_int()
	Ambiente.criar_por_do_sol(self, false)
	Bairro.criar(self)

	_rival_corpo = _boneco(Color(0.75, 0.20, 0.18))
	_rival_corpo.position = Bairro.LAJE_RIVAL + Vector3(0.0, Bairro.ALTURA_LAJE + 0.8, 0.25)
	_meu_corpo = _boneco(Color(0.15, 0.45, 0.85))
	_meu_corpo.position = Vector3(0.0, Bairro.ALTURA_LAJE + 0.8, 0.25)

	_pipa = KiteView.new()
	_pipa.name = "Pipa"
	add_child(_pipa)
	_pipa_rival = KiteView.new()
	_pipa_rival.name = "PipaRival"
	add_child(_pipa_rival)
	_linhas = LinesView.new()
	_linhas.name = "Linhas"
	add_child(_linhas)

	_camera = Camera3D.new()
	_camera.name = "Camera"
	_camera.fov = 62.0
	_camera.near = 0.05
	_camera.far = 1500.0
	_camera.current = true
	add_child(_camera)
	_criar_carretilha_e_mao()
	_criar_interface()
	nova_partida()


func nova_partida() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = _semente
	apelido_rival = Setup.APELIDOS[rng.randi() % Setup.APELIDOS.size()]
	_jogos_criados = 0
	regras = MatchRules.new(_criar_mundo, ["Você", apelido_rival])
	_bot_rival = BotPilot.new(BotDifficulty.create(BotDifficulty.Level.NORMAL), _semente + 50)
	_bot_meu = BotPilot.new(BotDifficulty.create(BotDifficulty.Level.DIFICIL), _semente + 60)
	_botao_novamente.visible = false
	_preparar_mundo()


## Cada jogo da partida tem um vento um pouco diferente.
func _criar_mundo(m: MatchRules.Mode, linha: float) -> SimWorld:
	_jogos_criados += 1
	return Setup.create_world(m, linha, _semente * 10 + _jogos_criados)


func _preparar_mundo() -> void:
	_mundo_visto = regras.world
	var def := KiteDefinition.raia_sem_rabiola()
	_pipa.call("construir", def)
	_pipa_rival.call("construir", def)
	for b in [_bot_rival, _bot_meu]:
		(b as BotPilot).line_target = Setup.bot_line_target(regras.mode())
	_posicionar_camera(true)


## Avança a partida (também usado pelos testes).
func avancar(segundos: float) -> void:
	for i in roundi(segundos * Engine.physics_ticks_per_second):
		_physics_process(1.0 / Engine.physics_ticks_per_second)


func _physics_process(delta: float) -> void:
	if regras.world != _mundo_visto:
		_preparar_mundo()
	var w := regras.world
	var eu: Flyer = w.flyers[0]
	var rival: Flyer = w.flyers[1]
	if regras.state == MatchRules.State.MATCH_OVER:
		eu.input.clear()
	elif _automatico:
		if not eu.cut:
			_bot_meu.target_azimuth = Setup.bot_target_azimuth(regras.mode(), eu, rival)
			_bot_meu.update(eu, w.time)
	else:
		_ler_comandos(eu)
	if not rival.cut and regras.state != MatchRules.State.MATCH_OVER:
		_bot_rival.target_azimuth = Setup.bot_target_azimuth(regras.mode(), rival, eu)
		_bot_rival.update(rival, w.time)
	w.step(delta)
	regras.update(delta)
	for msg in regras.take_messages():
		_avisar(msg)
	if regras.state == MatchRules.State.MATCH_OVER and not _botao_novamente.visible:
		_botao_novamente.visible = true


func _process(_delta: float) -> void:
	if regras == null:
		return
	var w := regras.world
	var eu: Flyer = w.flyers[0]
	var rival: Flyer = w.flyers[1]
	_pipa.call("atualizar", eu.kite)
	_pipa_rival.call("atualizar", rival.kite)
	_posicionar_camera(false)
	_atualizar_mao(eu)

	_linhas.set("camera_position", _camera.global_position)
	_linhas.set("min_width_per_meter", 2.0 * 2.0 * tan(deg_to_rad(_camera.fov * 0.5)) / maxf(1.0, get_viewport().get_visible_rect().size.y))
	_linhas.call("limpar")
	_desenhar_pipeiro(eu, Color(0.97, 0.97, 0.97))
	_desenhar_pipeiro(rival, Color(1.0, 0.82, 0.25))

	_placar.text = "VOCÊ  %d × %d  %s" % [regras.score[0], regras.score[1], apelido_rival.to_upper()]
	var tempo := ""
	if regras.state == MatchRules.State.COUNTDOWN:
		tempo = "começa em %d" % ceili(regras.timer)
	elif regras.state == MatchRules.State.PLAYING:
		tempo = "%d:%02d" % [floori(regras.timer / 60.0), floori(fmod(regras.timer, 60.0))]
	_rodada.text = "Jogo %d · %s · %s" % [regras.round_index + 1, MatchRules.mode_name(regras.mode()), tempo]
	var extra := ""
	if eu.holding > 0:
		extra = "\nPIPA ENROSCADA NA SUA LINHA: RECOLHE!"
	elif eu.cut:
		extra = "\nSua linha foi cortada."
	_alturas.text = "Sua pipa: %d m · %s: %d m · linha %d m%s" % [
		roundi(regras.altitude(0)), apelido_rival, roundi(regras.altitude(1)), roundi(eu.line_length()), extra]
	_aviso.visible = Time.get_ticks_msec() / 1000.0 < _aviso_ate


func _desenhar_pipeiro(f: Flyer, cor: Color) -> void:
	_linhas.call("desenhar_cadeia", f.line.pos, cor.lerp(Color(1.0, 0.1, 0.05), clampf(f.line.max_wear() / f.line.strength, 0.0, 1.0)), 0.0012)
	if f.trailing_line != null:
		_linhas.call("desenhar_cadeia", f.trailing_line.pos, cor, 0.0012)
	if f.tail != null:
		_linhas.call("desenhar_cadeia", f.tail.pos, Color(1.0, 0.30, 0.60), 0.02)


# ---------------- câmera, carretilha e mão ----------------

func _posicionar_camera(imediato: bool) -> void:
	var eu: Flyer = regras.world.flyers[0]
	var olho: Vector3
	if _primeira_pessoa:
		olho = eu.pilot.shoulder_position() + Vector3(0.0, 0.22, 0.12)
	else:
		olho = eu.pilot.shoulder_position() + Vector3(1.4, 1.4, 6.5)
	# Vira para a pipa, mas inclina menos que ela: a pipa fica no alto da tela
	# e o horizonte com as casas aparece acima dos botões.
	var alvo := eu.kite.position - olho
	var guinada := atan2(-alvo.x, -alvo.z)
	var elevacao := rad_to_deg(atan2(alvo.y, Vector2(alvo.x, alvo.z).length()))
	var inclinacao := clampf(elevacao - 22.0, 4.0 if _primeira_pessoa else -4.0, 40.0)
	var desejada := Transform3D(Basis.from_euler(Vector3(deg_to_rad(inclinacao), guinada, 0.0)), olho)
	if imediato:
		_camera.global_transform = desejada
	else:
		_camera.global_transform = _camera.global_transform.interpolate_with(desejada, 0.08)
	_carretilha.visible = _primeira_pessoa
	_mao.visible = _primeira_pessoa
	_meu_corpo.visible = not _primeira_pessoa


func _criar_carretilha_e_mao() -> void:
	# Carretilha presa à câmera, no canto de baixo à esquerda.
	_carretilha = Node3D.new()
	_carretilha.name = "Carretilha"
	_camera.add_child(_carretilha)
	_carretilha.position = Vector3(-0.10, -0.15, -0.42)
	_carretilha.rotation_degrees = Vector3(70.0, 35.0, 0.0)
	var corpo := MeshInstance3D.new()
	var cil := CylinderMesh.new()
	cil.top_radius = 0.065
	cil.bottom_radius = 0.065
	cil.height = 0.05
	corpo.mesh = cil
	var madeira := StandardMaterial3D.new()
	madeira.albedo_color = Color(0.55, 0.33, 0.16)
	madeira.roughness = 0.45
	corpo.material_override = madeira
	_carretilha.add_child(corpo)
	var linha_enrolada := MeshInstance3D.new()
	var rolo := CylinderMesh.new()
	rolo.top_radius = 0.05
	rolo.bottom_radius = 0.05
	rolo.height = 0.056
	linha_enrolada.mesh = rolo
	var branco := StandardMaterial3D.new()
	branco.albedo_color = Color(0.95, 0.95, 0.92)
	branco.roughness = 0.6
	linha_enrolada.material_override = branco
	_carretilha.add_child(linha_enrolada)
	# Cabo (manivela) da carretilha.
	var cabo := MeshInstance3D.new()
	var cabo_malha := CylinderMesh.new()
	cabo_malha.top_radius = 0.009
	cabo_malha.bottom_radius = 0.009
	cabo_malha.height = 0.06
	cabo.mesh = cabo_malha
	cabo.material_override = madeira
	cabo.position = Vector3(0.04, 0.05, 0.0)
	_carretilha.add_child(cabo)

	# Mão que segura a linha: fica na posição da mão da simulação.
	_mao = MeshInstance3D.new()
	_mao.name = "Mao"
	var palma := CapsuleMesh.new()
	palma.radius = 0.03
	palma.height = 0.11
	_mao.mesh = palma
	var pele := StandardMaterial3D.new()
	pele.albedo_color = Color(0.55, 0.36, 0.24)
	pele.roughness = 0.7
	_mao.material_override = pele
	add_child(_mao)


func _atualizar_mao(eu: Flyer) -> void:
	var dir := (eu.line.pos[mini(1, eu.line.size() - 1)] - eu.hand_position).normalized()
	if dir.length_squared() < 0.5:
		dir = Vector3.UP
	var base := Basis.looking_at(dir, Vector3.UP if absf(dir.y) < 0.98 else Vector3.BACK)
	_mao.global_transform = Transform3D(base * Basis(Vector3.RIGHT, PI / 2.0), eu.hand_position - dir * 0.06)


func _boneco(cor: Color) -> MeshInstance3D:
	var m := MeshInstance3D.new()
	var cap := CapsuleMesh.new()
	cap.radius = 0.22
	cap.height = 1.6
	m.mesh = cap
	var mat := StandardMaterial3D.new()
	mat.albedo_color = cor
	m.material_override = mat
	add_child(m)
	return m


# ---------------- controles ----------------

func _segurando(nome: String) -> bool:
	if _toques.values().has(nome):
		return true
	return TECLAS.has(nome) and Input.is_physical_key_pressed(TECLAS[nome])


func _ler_comandos(eu: Flyer) -> void:
	var e := eu.input
	e.pull = 1.0 if _segurando("PUXA") else 0.0
	e.slack = 1.0 if _segurando("AFROUXA") else 0.0
	e.free_spool = _segurando("SOLTA")
	e.pay_out = _segurando("DÁ LINHA")
	e.reel_in = _segurando("RECOLHE")
	for nome in _botoes:
		(_botoes[nome] as Button).modulate = Color(1.4, 1.4, 1.4) if _segurando(nome) else Color.WHITE


func _disparar(nome: String) -> void:
	var w := regras.world
	if (w.flyers[0] as Flyer).cut or _automatico:
		return
	match nome:
		"PUXÃO":
			w.trigger(Pilot.Impulse.PUXAO)
		"DESBICA":
			w.trigger(Pilot.Impulse.DESBICAR)
		"ARRANCÃO":
			w.trigger(Pilot.Impulse.ARRANCAO)


func _input(evento: InputEvent) -> void:
	# Vários dedos ao mesmo tempo: cada toque é ligado ao botão onde começou.
	if evento is InputEventScreenTouch:
		var t := evento as InputEventScreenTouch
		_toque(t.index, t.position, t.pressed)
	elif evento is InputEventMouseButton and evento.device != InputEvent.DEVICE_ID_EMULATION:
		var m := evento as InputEventMouseButton
		if m.button_index == MOUSE_BUTTON_LEFT:
			_toque(-2, m.position, m.pressed)
	elif evento is InputEventKey and evento.pressed and not evento.echo:
		var tecla: Key = (evento as InputEventKey).physical_keycode
		if TECLAS_TOQUE.has(tecla):
			_disparar(TECLAS_TOQUE[tecla])


func _toque(indice: int, posicao: Vector2, apertou: bool) -> void:
	if not apertou:
		_toques.erase(indice)
		return
	for nome in _botoes:
		var b: Button = _botoes[nome]
		if b.visible and b.get_global_rect().has_point(posicao):
			if _tipo(nome) == "toque":
				_disparar(nome)
			else:
				_toques[indice] = nome
			return


func _tipo(nome: String) -> String:
	for b in BOTOES:
		if b[0] == nome:
			return b[1]
	return ""


func _avisar(texto: String) -> void:
	_aviso.text = texto
	_aviso_ate = Time.get_ticks_msec() / 1000.0 + 4.0


func _criar_interface() -> void:
	var camada := CanvasLayer.new()
	camada.name = "Interface"
	add_child(camada)
	var raiz := Control.new()
	raiz.set_anchors_preset(Control.PRESET_FULL_RECT)
	raiz.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var tema := Theme.new()
	tema.default_font_size = 24
	raiz.theme = tema
	camada.add_child(raiz)

	var topo := VBoxContainer.new()
	topo.set_anchors_preset(Control.PRESET_TOP_WIDE)
	topo.offset_top = 36.0
	topo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	raiz.add_child(topo)
	_placar = _rotulo(topo, 34, Color(1.0, 0.92, 0.55))
	_rodada = _rotulo(topo, 22, Color.WHITE)
	_alturas = _rotulo(topo, 20, Color(0.9, 0.95, 1.0))

	_aviso = Label.new()
	_aviso.set_anchors_preset(Control.PRESET_CENTER)
	_aviso.offset_left = -330.0
	_aviso.offset_right = 330.0
	_aviso.offset_top = -160.0
	_aviso.offset_bottom = -40.0
	_aviso.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_aviso.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_aviso.add_theme_font_size_override("font_size", 34)
	_aviso.add_theme_color_override("font_color", Color(1.0, 0.85, 0.2))
	_aviso.add_theme_color_override("font_outline_color", Color(0.0, 0.0, 0.0, 0.9))
	_aviso.add_theme_constant_override("outline_size", 10)
	_aviso.mouse_filter = Control.MOUSE_FILTER_IGNORE
	raiz.add_child(_aviso)

	var grade := GridContainer.new()
	grade.name = "Comandos"
	grade.columns = 3
	grade.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	grade.offset_left = 16.0
	grade.offset_right = -16.0
	grade.offset_top = -230.0
	grade.offset_bottom = -24.0
	grade.add_theme_constant_override("h_separation", 12)
	grade.add_theme_constant_override("v_separation", 12)
	grade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	raiz.add_child(grade)
	for b in BOTOES:
		var nome: String = b[0]
		var cor := Color(0.15, 0.35, 0.65, 0.85) if b[1] == "segurar" else Color(0.80, 0.38, 0.10, 0.85)
		var botao := _botao(grade, nome, cor)
		botao.custom_minimum_size = Vector2(0.0, 92.0)
		botao.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		botao.mouse_filter = Control.MOUSE_FILTER_IGNORE  # o toque é tratado em _input
		_botoes[nome] = botao

	var cantos := HBoxContainer.new()
	cantos.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	cantos.offset_left = -260.0
	cantos.offset_right = -12.0
	cantos.offset_top = 170.0
	cantos.alignment = BoxContainer.ALIGNMENT_END
	raiz.add_child(cantos)
	var cam := _botao(cantos, "Câmera", Color(0.0, 0.0, 0.0, 0.5))
	cam.pressed.connect(_ao_trocar_camera)
	var lab := _botao(cantos, "Lab", Color(0.0, 0.0, 0.0, 0.5))
	lab.pressed.connect(_ao_abrir_laboratorio)

	_botao_novamente = _botao(raiz, "JOGAR DE NOVO", Color(0.1, 0.55, 0.25, 0.95))
	_botao_novamente.set_anchors_preset(Control.PRESET_CENTER)
	_botao_novamente.offset_left = -180.0
	_botao_novamente.offset_right = 180.0
	_botao_novamente.offset_top = 0.0
	_botao_novamente.offset_bottom = 90.0
	_botao_novamente.pressed.connect(_ao_jogar_de_novo)
	_botao_novamente.visible = false

	var versao := Label.new()
	versao.text = "PIPA BRASIL %s · build %s" % [ProjectSettings.get_setting("application/config/version", "?"), BuildInfo.COMMIT]
	versao.add_theme_font_size_override("font_size", 14)
	versao.set_anchors_preset(Control.PRESET_TOP_LEFT)
	versao.position = Vector2(12.0, 8.0)
	raiz.add_child(versao)


func _rotulo(pai: Control, tamanho: int, cor: Color) -> Label:
	var l := Label.new()
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.add_theme_font_size_override("font_size", tamanho)
	l.add_theme_color_override("font_color", cor)
	l.add_theme_color_override("font_outline_color", Color(0.0, 0.0, 0.0, 0.85))
	l.add_theme_constant_override("outline_size", 8)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pai.add_child(l)
	return l


func _botao(pai: Control, texto: String, cor: Color) -> Button:
	var b := Button.new()
	b.text = texto
	b.focus_mode = Control.FOCUS_NONE
	var estilo := StyleBoxFlat.new()
	estilo.bg_color = cor
	estilo.set_corner_radius_all(18)
	estilo.set_content_margin_all(10)
	b.add_theme_stylebox_override("normal", estilo)
	b.add_theme_stylebox_override("hover", estilo)
	var apertado := estilo.duplicate() as StyleBoxFlat
	apertado.bg_color = cor.lightened(0.3)
	b.add_theme_stylebox_override("pressed", apertado)
	pai.add_child(b)
	return b


func _ao_trocar_camera() -> void:
	_primeira_pessoa = not _primeira_pessoa
	_posicionar_camera(true)


func _ao_abrir_laboratorio() -> void:
	get_tree().change_scene_to_file("res://scenes/lab/lab.tscn")


func _ao_jogar_de_novo() -> void:
	_semente += 100
	nova_partida()
