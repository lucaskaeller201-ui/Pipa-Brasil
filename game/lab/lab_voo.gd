extends Node3D
## Laboratório de voo (Fases 1 e 2).
##
## Mostra a física funcionando: vento, pipa, linha, rabiola, mão do pipeiro e
## carretilha, com setas das forças e números ao vivo. Os comandos do pipeiro
## (botões na tela ou teclado) mexem a mão e a carretilha; a pipa responde só
## pela física.

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

var _vento := VENTO_PADRAO
var _comprimento_linha := 30.0
var _turbulencia := true
var _mostrar_forcas := true
var _camera_modo := 0
var _custo_ms := 0.0

var _pipa: Node3D
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
	reiniciar()


func reiniciar() -> void:
	var pre_tensao := 0.0 if definicao.tail_enabled else 3.0
	world = SimWorld.create_flight(WindField.new(_vento, TURBULENCIA if _turbulencia else 0.0, 1),
		definicao, _comprimento_linha, 30.0, 0.0, 4, true, pre_tensao)
	_pipa.call("construir", definicao)
	_atualizar_visual()


## Avança a simulação (usado também pelos testes).
func avancar(segundos: float) -> void:
	var passos := roundi(segundos * Engine.physics_ticks_per_second)
	for i in passos:
		world.step(1.0 / Engine.physics_ticks_per_second)


func _physics_process(delta: float) -> void:
	_ler_comandos()
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
	_atualizar_visual()
	_atualizar_camera()
	_info.text = texto_info()


func _atualizar_visual() -> void:
	_pipa.call("atualizar", world.kite)

	_linhas.call("limpar")
	_linhas.call("desenhar_cadeia", world.line.pos, Color(0.97, 0.97, 0.97))
	if world.tail != null:
		_linhas.call("desenhar_cadeia", world.tail.pos, Color(1.0, 0.30, 0.60))

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


func _atualizar_camera() -> void:
	var alvo := world.kite.position
	var mao := world.hand_position
	match _camera_modo:
		0:  # atrás do pipeiro, olhando a pipa
			_camera.position = mao + Vector3(0.6, 0.5, 3.0)
			_camera.look_at(alvo, Vector3.UP)
		1:  # de lado, vendo a linha inteira
			var meio := (mao + alvo) * 0.5
			_camera.position = meio + Vector3(_comprimento_linha * 1.1, 2.0, 0.0)
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
	var linhas := PackedStringArray([
		"PIPA BRASIL · Fase 2 · Laboratório de voo · %s" % definicao.model_name,
		"Linha: %s m · carretilha %s · comando: %s" % [_num(world.line_length(), 1), carretilha, _ultimo_comando],
		"Vento na pipa: %s m/s" % _num(k.last_wind.length(), 1),
		"Elevação: %d°   Ângulo de ataque: %d°" % [roundi(world.elevation_deg()), roundi(k.last_aoa_deg)],
		"Tensão da linha: %s N" % _num(world.tension, 2),
		"Altura: %s m   Lateral: %s m" % [_num(k.position.y, 1), _num(world.lateral_offset(), 1)],
		"Velocidade da pipa: %s m/s" % _num(k.velocity.length(), 1),
		"Física: %s ms/passo   FPS: %d" % [_num(_custo_ms, 2), Engine.get_frames_per_second()],
		"Setas: azul vento · verde ar · laranja linha · roxo peso",
		"Rabiola em rosa · Build %s" % BuildInfo.COMMIT,
		"Teclado: W puxar · S afrouxar · A dar linha · Z largar · R recolher · Espaço puxão · Q arrancão · E desbicar",
	])
	return "\n".join(linhas)


## Número com vírgula decimal, como se escreve no Brasil.
static func _num(valor: float, casas: int) -> String:
	var formato := "%." + str(casas) + "f"
	return (formato % valor).replace(".", ",")


# ---------------- cenário e interface ----------------

func _criar_pipeiro() -> void:
	# Marcador simples do pipeiro (o personagem de verdade vem na Fase 7).
	var corpo := MeshInstance3D.new()
	corpo.name = "Pipeiro"
	var capsula := CapsuleMesh.new()
	capsula.radius = 0.22
	capsula.height = 1.6
	corpo.mesh = capsula
	var material := StandardMaterial3D.new()
	material.albedo_color = Color(0.15, 0.35, 0.65)
	corpo.material_override = material
	corpo.position = Vector3(0.0, 0.8, 0.25)
	add_child(corpo)


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
	_toggle(caixa, "Rabiola (desligada = raia sem rabiola)", true, _ao_mudar_rabiola)
	_toggle(caixa, "Mostrar forças", _mostrar_forcas, _ao_mudar_forcas)
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
