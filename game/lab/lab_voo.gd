extends Node3D
## Laboratório de voo (Fases 1 a 3).
##
## Mostra a física funcionando: vento, pipa, linha, rabiola, mão do pipeiro e
## carretilha, com setas das forças e números ao vivo. Os comandos do pipeiro
## (botões na tela ou teclado) mexem a mão e a carretilha; a pipa responde só
## pela física. Opcionalmente há uma linha fixa entre postes e uma pipa rival
## pilotada por um bot (que persegue a sua pipa), para treinar o contato entre
## linhas (a linha fica vermelha com o desgaste e pode romper). O piloto
## automático põe um bot para pilotar a sua pipa.

const BuildInfo := preload("res://game/main/build_info.gd")
const Ambiente := preload("res://game/world/ambiente.gd")
const KiteView := preload("res://game/views/kite_view.gd")
const LinesView := preload("res://game/views/lines_view.gd")

const VENTO_PADRAO := 5.0
const TURBULENCIA := 0.15
const ESCALA_FORCA := 0.6   ## m de seta por newton
const ESCALA_VENTO := 0.4   ## m de seta por m/s
const CAMERAS := ["Pipeiro", "Lateral", "Perto da pipa"]

var world: SimWorld
var definicao: KiteDefinition
var _def_com_rabiola: KiteDefinition
var _def_sem_rabiola: KiteDefinition
var _sensibilidade := 1.0
var _segurando := {}  # comando contínuo -> apertado (botão na tela)
var _ultimo_comando := "—"

const COMANDOS_CONTINUOS := ["Puxar", "Afrouxar", "Dar linha", "Largar", "Recolher"]
const TECLAS := {
	"Puxar": KEY_W, "Afrouxar": KEY_S, "Dar linha": KEY_A, "Largar": KEY_Z, "Recolher": KEY_R,
}
const TECLAS_IMPULSO := {KEY_SPACE: Pilot.Impulse.PUXAO, KEY_Q: Pilot.Impulse.ARRANCAO, KEY_E: Pilot.Impulse.DESBICAR}

var _linha_fixa := true
var _rival := false
var _nivel_rival: BotDifficulty.Level = BotDifficulty.Level.NORMAL
var _bot_rival: BotPilot
var _piloto_automatico := false
var _bot_meu: BotPilot
var _botao_nivel: Button
var _mensagem := ""
var _mensagem_ate := 0.0
var _cortes := 0

var _vento := VENTO_PADRAO
var _comprimento_linha := 30.0
var _turbulencia := true
var _mostrar_forcas := true
var _camera_modo := 0
var _custo_ms := 0.0

var _pipa: Node3D
var _pipa_rival: Node3D
var _pipeiro_rival: Node3D
var _postes: Node3D
var _linhas: MeshInstance3D
var _forcas: MeshInstance3D
var _camera: Camera3D
var _info: Label
var _rotulos := {}
var _botao_camera: Button


func _ready() -> void:
	_def_com_rabiola = KiteDefinition.raia_laboratorio()
	_def_sem_rabiola = KiteDefinition.raia_sem_rabiola()
	definicao = _def_com_rabiola
	for c in COMANDOS_CONTINUOS:
		_segurando[c] = false
	Ambiente.criar_por_do_sol(self)
	_criar_pipeiro()

	_pipa = KiteView.new()
	_pipa.name = "Pipa"
	add_child(_pipa)
	_pipa_rival = KiteView.new()
	_pipa_rival.name = "PipaRival"
	add_child(_pipa_rival)
	_pipeiro_rival = _criar_boneco("PipeiroRival", Color(0.70, 0.20, 0.20))
	_postes = Node3D.new()
	_postes.name = "Postes"
	add_child(_postes)
	_linhas = LinesView.new()
	_linhas.name = "Linhas"
	add_child(_linhas)
	_forcas = LinesView.new()
	_forcas.name = "Forcas"
	add_child(_forcas)

	_camera = Camera3D.new()
	_camera.name = "Camera"
	_camera.fov = 35.0
	_camera.far = 1000.0
	_camera.current = true
	add_child(_camera)

	_criar_interface()
	# Permite escolher a câmera pela linha de comando (usado nas capturas do CI).
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--camera="):
			_camera_modo = clampi(arg.trim_prefix("--camera=").to_int(), 0, CAMERAS.size() - 1)
			_botao_camera.text = "Câmera: %s" % CAMERAS[_camera_modo]
		elif arg == "--rival":
			_rival = true
		elif arg == "--auto":
			_piloto_automatico = true
	reiniciar()


func reiniciar() -> void:
	var pre_tensao := 0.0 if definicao.tail_enabled else 3.0
	world = SimWorld.create_flight(WindField.new(_vento, TURBULENCIA if _turbulencia else 0.0, 1),
		definicao, _comprimento_linha, 30.0, 0.0, 4, true, pre_tensao)
	_pipa.call("construir", definicao)
	# Linha fixa atravessada no vento, a 1/3 da linha: a linha da pipa sobe e
	# encosta nela por baixo.
	for filho in _postes.get_children():
		filho.queue_free()
	if _linha_fixa:
		var z := -_comprimento_linha / 3.0
		var y := 1.2 + 0.83 * _comprimento_linha / 3.0
		world.add_fixed_line(Vector3(-15.0, y, z), Vector3(15.0, y, z))
		for x in [-15.0, 15.0]:
			_postes.add_child(_criar_poste(Vector3(x, 0.0, z), y))
	_pipa_rival.visible = _rival
	_pipeiro_rival.visible = _rival
	_bot_rival = null
	if _rival:
		world.add_flyer(_def_sem_rabiola, Vector3(6.0, 0.0, 0.0), _comprimento_linha, 30.0, 0.0, true, 3.0)
		_pipa_rival.call("construir", _def_sem_rabiola)
		_pipeiro_rival.position = Vector3(6.0, 0.8, 0.25)
		_bot_rival = BotPilot.new(BotDifficulty.create(_nivel_rival), 11)
		_bot_rival.line_target = _comprimento_linha
	_bot_meu = BotPilot.new(BotDifficulty.create(BotDifficulty.Level.PROFISSIONAL), 12)
	_bot_meu.line_target = _comprimento_linha
	_mensagem = ""
	_atualizar_visual()


## Avança a simulação (usado também pelos testes).
func avancar(segundos: float) -> void:
	var passos := roundi(segundos * Engine.physics_ticks_per_second)
	for i in passos:
		world.step(1.0 / Engine.physics_ticks_per_second)


func _physics_process(delta: float) -> void:
	var meu: Flyer = world.flyers[0]
	if _piloto_automatico and not meu.cut:
		_bot_meu.target_azimuth = 0.0
		_bot_meu.update(meu, world.time)
		_ultimo_comando = "piloto automático"
	else:
		_ler_comandos()
	if _bot_rival != null and world.flyers.size() > 1 and not (world.flyers[1] as Flyer).cut:
		var rival: Flyer = world.flyers[1]
		# O rival persegue a sua pipa: mira o azimute dela visto do lugar dele.
		var alvo := meu.kite.position - rival.hand_position
		_bot_rival.target_azimuth = rad_to_deg(atan2(alvo.x, -alvo.z))
		_bot_rival.update(rival, world.time)
	var inicio := Time.get_ticks_usec()
	world.step(delta)
	var ms := (Time.get_ticks_usec() - inicio) / 1000.0
	_custo_ms = lerpf(_custo_ms, ms, 0.05)


func _apertado(comando: String) -> bool:
	return _segurando.get(comando, false) or Input.is_physical_key_pressed(TECLAS[comando])


func _ler_comandos() -> void:
	var e := world.input
	e.pull = _sensibilidade if _apertado("Puxar") else 0.0
	e.slack = _sensibilidade if _apertado("Afrouxar") else 0.0
	e.pay_out = _apertado("Dar linha")
	e.free_spool = _apertado("Largar")
	e.reel_in = _apertado("Recolher")
	for c in COMANDOS_CONTINUOS:
		if _apertado(c):
			_ultimo_comando = c


func disparar(impulso: Pilot.Impulse) -> void:
	world.trigger(impulso)
	_ultimo_comando = Pilot.impulse_name(impulso)


func _unhandled_input(evento: InputEvent) -> void:
	if evento is InputEventKey and evento.pressed and not evento.echo:
		var tecla: Key = (evento as InputEventKey).physical_keycode
		if TECLAS_IMPULSO.has(tecla):
			disparar(TECLAS_IMPULSO[tecla])


func _process(_delta: float) -> void:
	for e in world.combat.take_events():
		match e["type"]:
			"ruptura":
				_mensagem = "A SUA LINHA ROMPEU! Pipa avoada." if e["flyer"] == 0 else "CORTOU! A pipa do rival está avoada. Manda busca!"
				if e["flyer"] != 0:
					_cortes += 1
			"enroscou":
				if e["catcher"] == 0:
					_mensagem = "ENROSCOU NA SUA %s! Recolhe para trazer." % ("RABIOLA" if e["by_tail"] else "LINHA")
				else:
					_mensagem = "O rival enroscou a sua pipa..."
			"aparada":
				_mensagem = "MANDA BUSCA! Você aparou a pipa." if e["catcher"] == 0 else "O rival aparou a sua pipa."
			"perdida":
				_mensagem = "A pipa caiu no chão: ninguém aparou."
			_:
				_mensagem = "A linha fixa rompeu."
		_mensagem_ate = Time.get_ticks_msec() / 1000.0 + 5.0
	_atualizar_visual()
	_atualizar_camera()
	_info.text = texto_info()


func _atualizar_visual() -> void:
	_pipa.call("atualizar", world.kite)
	if _rival and world.flyers.size() > 1:
		_pipa_rival.call("atualizar", (world.flyers[1] as Flyer).kite)

	_linhas.set("camera_position", _camera.global_position)
	_linhas.set("min_width_per_meter", 2.0 * 2.0 * tan(deg_to_rad(_camera.fov * 0.5)) / maxf(1.0, get_viewport().get_visible_rect().size.y))
	_linhas.call("limpar")
	for f in world.flyers:
		var fl: Flyer = f
		var base := Color(0.97, 0.97, 0.97) if fl.id == 0 else Color(1.0, 0.85, 0.35)
		for c in [fl.line, fl.trailing_line]:
			if c != null:
				_linhas.call("desenhar_cadeia", (c as ParticleChain).pos, _cor_desgaste(c, base))
		if fl.tail != null:
			_linhas.call("desenhar_cadeia", fl.tail.pos, Color(1.0, 0.30, 0.60), 0.02)
	for c in world.loose_chains:
		_linhas.call("desenhar_cadeia", (c as ParticleChain).pos, _cor_desgaste(c, Color(0.15, 0.15, 0.15)))

	_forcas.call("limpar")
	if _mostrar_forcas:
		var k := world.kite
		var setas := [
			[k.position, k.last_wind * ESCALA_VENTO],
			[k.position, k.last_aero_force * ESCALA_FORCA],
			[world.bridle_position(), -world.tension_direction * world.tension * ESCALA_FORCA],
			[k.position, KiteBody.GRAVITY * k.definition.mass * ESCALA_FORCA],
		]
		var cores := [Color(0.3, 0.8, 1.0), Color(0.2, 0.95, 0.3), Color(1.0, 0.55, 0.1), Color(0.75, 0.4, 1.0)]
		_forcas.call("desenhar_setas", setas, cores)


## A linha vai ficando vermelha conforme o ponto mais gasto se aproxima da ruptura.
func _cor_desgaste(c: ParticleChain, base: Color) -> Color:
	return base.lerp(Color(1.0, 0.1, 0.05), clampf(c.max_wear() / c.strength, 0.0, 1.0))


func _atualizar_camera() -> void:
	var alvo := world.kite.position
	var mao := world.hand_position
	match _camera_modo:
		0:  # atrás do pipeiro, olhando a pipa
			_camera.position = mao + Vector3(0.6, 0.5, 3.0)
			_camera.look_at(alvo, Vector3.UP)
		1:  # de lado, vendo a linha inteira (distância ajustada ao zoom)
			var meio := (mao + alvo) * 0.5
			var distancia := (mao.distance_to(alvo) * 0.75 + 4.0) / tan(deg_to_rad(_camera.fov * 0.5))
			_camera.position = meio + Vector3(distancia, 2.0, 0.0)
			_camera.look_at(meio, Vector3.UP)
		_:  # perto da pipa, entre ela e o pipeiro
			var para_mao := (mao - alvo).normalized()
			_camera.position = alvo + para_mao * 4.0 + Vector3(1.5, 0.5, 0.0)
			_camera.look_at(alvo, Vector3.UP)


func texto_info() -> String:
	var k := world.kite
	var carretilha := "travada"
	if world.input.free_spool:
		carretilha = "livre"
	elif world.input.pay_out:
		carretilha = "soltando"
	elif world.input.reel_in:
		carretilha = "enrolando"
	var meu: Flyer = world.flyers[0]
	var desgaste := meu.line.max_wear() / meu.line.strength * 100.0 if not meu.cut else 100.0
	var linhas := PackedStringArray([
		"PIPA BRASIL · Laboratório de voo · %s" % definicao.model_name,
		"Linha: %s m · carretilha %s · comando: %s" % [_num(world.line_length(), 1), carretilha, _ultimo_comando],
		"Desgaste da sua linha: %d%% · linhas encostadas: %s" % [roundi(desgaste), "sim" if world.combat.contacts_last_step > 0 else "não"],
		"Cortes: %d · Aparadas: %d%s" % [_cortes, meu.catches, " · PIPA ENROSCADA NA SUA LINHA" if meu.holding > 0 else ""],
		"Vento na pipa: %s m/s" % _num(k.last_wind.length(), 1),
		"Elevação: %d°   Ângulo de ataque: %d°" % [roundi(world.elevation_deg()), roundi(k.last_aoa_deg)],
		"Tensão da linha: %s N" % _num(world.tension, 2),
		"Altura: %s m   Lateral: %s m" % [_num(k.position.y, 1), _num(world.lateral_offset(), 1)],
		"Velocidade da pipa: %s m/s" % _num(k.velocity.length(), 1),
		"Física: %s ms/passo   FPS: %d" % [_num(_custo_ms, 2), Engine.get_frames_per_second()],
		"Setas: azul vento · verde ar · laranja linha · roxo peso",
		"Rabiola em rosa · Build %s" % BuildInfo.COMMIT,
	])
	if not _mensagem.is_empty() and Time.get_ticks_msec() / 1000.0 < _mensagem_ate:
		linhas.insert(1, ">>> %s <<<" % _mensagem)
	if not OS.has_feature("mobile"):
		linhas.append("Teclado: W puxar · S afrouxar · A dar linha · Z largar")
		linhas.append("R recolher · Espaço puxão · Q arrancão · E desbicar")
	return "\n".join(linhas)


## Número com vírgula decimal, como se escreve no Brasil.
static func _num(valor: float, casas: int) -> String:
	var formato := "%." + str(casas) + "f"
	return (formato % valor).replace(".", ",")


# ---------------- cenário e interface ----------------

func _criar_pipeiro() -> void:
	# Marcador simples do pipeiro (o personagem de verdade vem na Fase 7).
	var corpo := _criar_boneco("Pipeiro", Color(0.15, 0.35, 0.65))
	corpo.position = Vector3(0.0, 0.8, 0.25)


func _criar_boneco(nome: String, cor: Color) -> MeshInstance3D:
	var corpo := MeshInstance3D.new()
	corpo.name = nome
	var capsula := CapsuleMesh.new()
	capsula.radius = 0.22
	capsula.height = 1.6
	corpo.mesh = capsula
	var material := StandardMaterial3D.new()
	material.albedo_color = cor
	corpo.material_override = material
	add_child(corpo)
	return corpo


func _criar_poste(base: Vector3, altura: float) -> MeshInstance3D:
	var poste := MeshInstance3D.new()
	var malha := CylinderMesh.new()
	malha.top_radius = 0.1
	malha.bottom_radius = 0.14
	malha.height = altura
	poste.mesh = malha
	var material := StandardMaterial3D.new()
	material.albedo_color = Color(0.55, 0.55, 0.52)
	poste.material_override = material
	poste.position = base + Vector3(0.0, altura * 0.5, 0.0)
	return poste


func _criar_interface() -> void:
	var camada := CanvasLayer.new()
	camada.name = "Interface"
	add_child(camada)

	var raiz := Control.new()
	raiz.set_anchors_preset(Control.PRESET_FULL_RECT)
	raiz.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var tema := Theme.new()
	tema.default_font_size = 19
	raiz.theme = tema
	camada.add_child(raiz)

	_info = Label.new()
	_info.position = Vector2(16.0, 12.0)
	_info.add_theme_color_override("font_color", Color.WHITE)
	_info.add_theme_color_override("font_outline_color", Color(0.0, 0.0, 0.0, 0.85))
	_info.add_theme_constant_override("outline_size", 6)
	raiz.add_child(_info)

	var painel := PanelContainer.new()
	painel.set_anchors_preset(Control.PRESET_RIGHT_WIDE)
	painel.offset_left = -360.0
	painel.offset_right = -8.0
	painel.offset_top = 8.0
	painel.offset_bottom = -8.0
	var fundo := StyleBoxFlat.new()
	fundo.bg_color = Color(0.0, 0.0, 0.0, 0.45)
	fundo.set_corner_radius_all(10)
	fundo.set_content_margin_all(12)
	painel.add_theme_stylebox_override("panel", fundo)
	raiz.add_child(painel)

	var rolagem := ScrollContainer.new()
	rolagem.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	painel.add_child(rolagem)
	var caixa := VBoxContainer.new()
	caixa.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	caixa.add_theme_constant_override("separation", 4)
	rolagem.add_child(caixa)

	_slider(caixa, "vento", 0.0, 14.0, 0.5, _vento, _ao_mudar_vento)
	_slider(caixa, "cabresto", 0.04, 0.18, 0.01, definicao.tow_point.y, _ao_mudar_cabresto)
	_slider(caixa, "linha", 10.0, 100.0, 5.0, _comprimento_linha, _ao_mudar_linha)
	_slider(caixa, "zoom", 15.0, 75.0, 1.0, _camera.fov, _ao_mudar_zoom)
	_slider(caixa, "sensibilidade", 0.5, 1.5, 0.1, _sensibilidade, _ao_mudar_sensibilidade)
	_toggle(caixa, "Turbulência", _turbulencia, _ao_mudar_turbulencia)
	_toggle(caixa, "Com rabiola", true, _ao_mudar_rabiola)
	_toggle(caixa, "Mostrar forças", _mostrar_forcas, _ao_mudar_forcas)
	_toggle(caixa, "Linha fixa entre postes", _linha_fixa, _ao_mudar_linha_fixa)
	_toggle(caixa, "Pipa rival (bot)", _rival, _ao_mudar_rival)
	_botao_nivel = _botao(caixa, "Nível do rival: %s" % BotDifficulty.level_name(_nivel_rival), _ao_tocar_nivel)
	_toggle(caixa, "Piloto automático na minha", _piloto_automatico, _ao_mudar_piloto)
	_botao(caixa, "Rajada (3 s)", _ao_tocar_rajada)
	_botao_camera = _botao(caixa, "Câmera: %s" % CAMERAS[_camera_modo], _ao_tocar_camera)
	_botao(caixa, "Reiniciar voo", reiniciar)
	_criar_comandos(raiz)


## Botões grandes dos comandos do pipeiro, no canto inferior esquerdo.
func _criar_comandos(raiz: Control) -> void:
	var grade := GridContainer.new()
	grade.name = "Comandos"
	grade.columns = 4
	grade.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	grade.offset_left = 12.0
	grade.offset_bottom = -12.0
	grade.offset_top = -148.0
	grade.grow_vertical = Control.GROW_DIRECTION_BEGIN
	grade.add_theme_constant_override("h_separation", 8)
	grade.add_theme_constant_override("v_separation", 8)
	raiz.add_child(grade)
	for c in COMANDOS_CONTINUOS:
		var b := _botao_comando(grade, c, Color(0.15, 0.35, 0.65, 0.85))
		b.button_down.connect(_ao_segurar.bind(c, true))
		b.button_up.connect(_ao_segurar.bind(c, false))
	for imp in [Pilot.Impulse.PUXAO, Pilot.Impulse.ARRANCAO, Pilot.Impulse.DESBICAR]:
		var b := _botao_comando(grade, Pilot.impulse_name(imp), Color(0.75, 0.35, 0.10, 0.85))
		b.pressed.connect(disparar.bind(imp))


func _botao_comando(grade: GridContainer, texto: String, cor: Color) -> Button:
	var b := Button.new()
	b.text = texto
	b.custom_minimum_size = Vector2(124.0, 64.0)
	b.focus_mode = Control.FOCUS_NONE
	var estilo := StyleBoxFlat.new()
	estilo.bg_color = cor
	estilo.set_corner_radius_all(12)
	b.add_theme_stylebox_override("normal", estilo)
	var apertado := estilo.duplicate() as StyleBoxFlat
	apertado.bg_color = cor.lightened(0.35)
	b.add_theme_stylebox_override("pressed", apertado)
	b.add_theme_stylebox_override("hover", estilo)
	grade.add_child(b)
	return b


func _ao_segurar(comando: String, apertado: bool) -> void:
	_segurando[comando] = apertado


func _ao_mudar_vento(v: float) -> void:
	_vento = v
	world.wind.speed = v


func _ao_mudar_cabresto(v: float) -> void:
	definicao.tow_point.y = v
	_pipa.call("construir", definicao)


func _ao_mudar_linha(v: float) -> void:
	_comprimento_linha = v
	reiniciar()


func _ao_mudar_zoom(v: float) -> void:
	_camera.fov = v


func _ao_mudar_turbulencia(ligado: bool) -> void:
	_turbulencia = ligado
	world.wind.turbulence = TURBULENCIA if ligado else 0.0


func _ao_mudar_rabiola(ligado: bool) -> void:
	definicao = _def_com_rabiola if ligado else _def_sem_rabiola
	_rotulos["cabresto"].get_parent().get_child(_rotulos["cabresto"].get_index() + 1).value = definicao.tow_point.y
	reiniciar()


func _ao_mudar_linha_fixa(ligado: bool) -> void:
	_linha_fixa = ligado
	reiniciar()


func _ao_mudar_rival(ligado: bool) -> void:
	_rival = ligado
	reiniciar()


func _ao_tocar_nivel() -> void:
	_nivel_rival = ((_nivel_rival + 1) % 4) as BotDifficulty.Level
	_botao_nivel.text = "Nível do rival: %s" % BotDifficulty.level_name(_nivel_rival)
	if _rival:
		reiniciar()


func _ao_mudar_piloto(ligado: bool) -> void:
	_piloto_automatico = ligado
	world.input.clear()


func _ao_mudar_sensibilidade(v: float) -> void:
	_sensibilidade = v


func _ao_mudar_forcas(ligado: bool) -> void:
	_mostrar_forcas = ligado


func _ao_tocar_rajada() -> void:
	world.wind.set_gust(world.time, minf(_vento * 2.0 + 2.0, 16.0), 3.0)


func _ao_tocar_camera() -> void:
	_camera_modo = (_camera_modo + 1) % CAMERAS.size()
	_botao_camera.text = "Câmera: %s" % CAMERAS[_camera_modo]


func _texto_slider(chave: String, v: float) -> String:
	match chave:
		"vento":
			return "Vento (a 10 m): %s m/s" % _num(v, 1)
		"cabresto":
			return "Cabresto: %s m (↑ = perto do bico)" % _num(v, 2)
		"linha":
			return "Linha inicial: %d m (reinicia o voo)" % roundi(v)
		"sensibilidade":
			return "Sensibilidade de puxar/afrouxar: %s" % _num(v, 1)
		_:
			return "Zoom (campo de visão): %d°" % roundi(v)


func _slider(caixa: VBoxContainer, chave: String, minimo: float, maximo: float, passo: float,
		valor: float, ao_mudar: Callable) -> void:
	var rotulo := Label.new()
	rotulo.text = _texto_slider(chave, valor)
	rotulo.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	caixa.add_child(rotulo)
	_rotulos[chave] = rotulo
	var s := HSlider.new()
	s.min_value = minimo
	s.max_value = maximo
	s.step = passo
	s.value = valor
	s.custom_minimum_size = Vector2(300.0, 36.0)
	s.value_changed.connect(_ao_mudar_slider.bind(chave, rotulo, ao_mudar))
	caixa.add_child(s)


func _ao_mudar_slider(v: float, chave: String, rotulo: Label, ao_mudar: Callable) -> void:
	rotulo.text = _texto_slider(chave, v)
	ao_mudar.call(v)


func _toggle(caixa: VBoxContainer, texto: String, ligado: bool, ao_mudar: Callable) -> void:
	var c := CheckButton.new()
	c.text = texto
	c.button_pressed = ligado
	c.custom_minimum_size = Vector2(0.0, 40.0)
	c.toggled.connect(ao_mudar)
	caixa.add_child(c)


func _botao(caixa: VBoxContainer, texto: String, ao_tocar: Callable) -> Button:
	var b := Button.new()
	b.text = texto
	b.custom_minimum_size = Vector2(0.0, 46.0)
	b.pressed.connect(ao_tocar)
	caixa.add_child(b)
	return b
