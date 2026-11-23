extends Node3D
## Modo livre na laje (tela principal, celular deitado).
##
## Sem botões de comando: os gestos são os do pipeiro.
##   • Deslizar o dedo para BAIXO: puxa linha com a mão ("abraçar"); rápido = puxada forte.
##   • Deslizar para CIMA: dá linha; soltando o dedo no embalo, a carretilha
##     continua girando um pouco.
##   • TOQUES rápidos: desbica (pequenas folgas; o bico gira a cada toque).
## No PC: W/↓ puxa, S/↑ dá linha, Espaço desbica, arrastar com o mouse também vale.
## A física é a mesma do laboratório: os gestos viram comandos do PilotInput.

const BuildInfo := preload("res://game/main/build_info.gd")
const Ambiente := preload("res://game/world/ambiente.gd")
const Bairro := preload("res://game/world/bairro.gd")
const KiteView := preload("res://game/views/kite_view.gd")
const LinesView := preload("res://game/views/lines_view.gd")

const BOTS := 3
const LINHA_POR_TELA := 1.6     ## m de linha por altura de tela deslizada
const EMBALO := 0.9             ## s: quanto dura o giro da carretilha depois de soltar o dedo
const TOQUE_MAX_S := 0.25
const TOQUE_MAX_PX := 18.0
const CORES := [Color(0.97, 0.97, 0.97), Color(1.0, 0.82, 0.25), Color(0.45, 0.85, 1.0),
	Color(0.6, 1.0, 0.5), Color(1.0, 0.55, 0.8), Color(0.85, 0.7, 1.0), Color(1.0, 0.6, 0.3), Color(0.7, 0.7, 0.7)]

var modo: FreeMode

var _semente := 1
var _automatico := false
var _primeira_pessoa := true
var _camera: Camera3D
var _linhas: MeshInstance3D
var _vistas := {}               # Flyer -> KiteView
var _corpos: Array = []         # boneco de cada participante

# gestos
var _dedos := {}                # índice -> {"ini": Vector2, "t0": float, "ult": Vector2}
var _dy_quadro := 0.0           # pixels deslizados neste quadro (+ = para baixo)
var _velocidade_mao := 0.0      # m/s (+ = puxando)
var _embalo := 0.0              # m/s de linha saindo depois de soltar o dedo
var _giro_carretilha := 0.0

# interface
var _placar: Label
var _aviso: Label
var _aviso_ate := 0.0
var _info: Label
var _dica: Label
var _sobreposicao: Control


func _ready() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg == "--auto":
			_automatico = true
		elif arg == "--terceira":
			_primeira_pessoa = false
		elif arg.begins_with("--semente="):
			_semente = arg.trim_prefix("--semente=").to_int()
	modo = FreeMode.new(BOTS, _semente, _automatico)
	Ambiente.criar_por_do_sol(self, false)
	Bairro.criar(self, modo.players.size())
	for i in modo.players.size():
		var corpo := _boneco(CORES[i].darkened(0.2))
		corpo.position = (modo.players[i]["base"] as Vector3) + Vector3(0.0, 0.8, 0.25)
		_corpos.append(corpo)
	_linhas = LinesView.new()
	_linhas.name = "Linhas"
	add_child(_linhas)
	_camera = Camera3D.new()
	_camera.name = "Camera"
	_camera.near = 0.05
	_camera.far = 2000.0
	_camera.current = true
	add_child(_camera)
	_criar_interface()
	_posicionar_camera(true)


## Avança o jogo (também usado pelos testes).
func avancar(segundos: float) -> void:
	for i in roundi(segundos * Engine.physics_ticks_per_second):
		_physics_process(1.0 / Engine.physics_ticks_per_second)


func _physics_process(delta: float) -> void:
	var eu := modo.you()
	if not _automatico and not eu.cut:
		_ler_comandos(eu, delta)
	modo.update(delta)
	for msg in modo.take_messages():
		_avisar(msg)


func _ler_comandos(eu: Flyer, delta: float) -> void:
	var e := eu.input
	var teclado := 0.0
	if Input.is_physical_key_pressed(KEY_W) or Input.is_physical_key_pressed(KEY_DOWN):
		teclado += 3.0
	if Input.is_physical_key_pressed(KEY_S) or Input.is_physical_key_pressed(KEY_UP):
		teclado -= 3.0
	_embalo = move_toward(_embalo, 0.0, absf(_embalo) * delta / EMBALO + 0.05 * delta)
	var v := _velocidade_mao + teclado
	if _dedos.is_empty() and v == 0.0:
		v = -_embalo
	e.haul_speed = clampf(v, -Pilot.HAUL_MAX_SPEED, Pilot.HAUL_MAX_SPEED)


func _process(delta: float) -> void:
	# Velocidade da mão a partir do deslizar deste quadro.
	var altura := maxf(1.0, get_viewport().get_visible_rect().size.y)
	var alvo := (_dy_quadro / altura) * LINHA_POR_TELA / maxf(delta, 1e-3)
	_velocidade_mao = alvo if not _dedos.is_empty() else 0.0
	_dy_quadro = 0.0

	_atualizar_vistas()
	_posicionar_camera(false)
	_linhas.set("camera_position", _camera.global_position)
	_linhas.set("min_width_per_meter", 2.0 * 2.0 * tan(deg_to_rad(_camera.fov * 0.5)) / altura)
	_linhas.call("limpar")
	for f in modo.world.flyers:
		var fl: Flyer = f
		var cor: Color = CORES[fl.tag] if fl.tag >= 0 else Color(0.85, 0.85, 0.85)
		if fl.line != null:
			_linhas.call("desenhar_cadeia", fl.line.pos, cor.lerp(Color(1.0, 0.1, 0.05), clampf(fl.line.max_wear() / fl.line.strength, 0.0, 1.0)), 0.0012)
		if fl.trailing_line != null:
			_linhas.call("desenhar_cadeia", fl.trailing_line.pos, cor, 0.0012)
	var eu := modo.you()
	_giro_carretilha += eu.input.haul_speed * delta * 3.0
	_atualizar_textos(eu)
	_sobreposicao.queue_redraw()


func _atualizar_vistas() -> void:
	var vivos := {}
	for f in modo.world.flyers:
		var fl: Flyer = f
		vivos[fl] = true
		if not _vistas.has(fl):
			var v: Node3D = KiteView.new()
			add_child(v)
			v.call("construir", fl.kite.definition)
			_vistas[fl] = v
		(_vistas[fl] as Node3D).call("atualizar", fl.kite)
	for fl in _vistas.keys():
		if not vivos.has(fl):
			(_vistas[fl] as Node).queue_free()
			_vistas.erase(fl)


# ---------------- câmera ----------------

func _posicionar_camera(imediato: bool) -> void:
	var eu := modo.you()
	var base: Vector3 = modo.players[0]["base"]
	var olho := base + Pilot.SHOULDER + Vector3(0.0, 0.2, 0.15)
	if not _primeira_pessoa:
		olho = base + Pilot.SHOULDER + Vector3(1.5, 1.5, 6.5)
	_corpos[0].visible = not _primeira_pessoa
	var alvo := eu.kite.position - olho
	var dist := alvo.length()
	# Zoom (1ª pessoa): a pipa ocupa uns 6% da altura da tela. Na 3ª pessoa,
	# visão aberta para ver as lajes e as outras pipas.
	var envergadura := 0.6
	var fov := clampf(rad_to_deg(envergadura / maxf(dist, 1.0)) / 0.06, 14.0, 55.0)
	if not _primeira_pessoa:
		fov = 50.0
	var guinada := atan2(-alvo.x, -alvo.z)
	var elevacao := rad_to_deg(atan2(alvo.y, Vector2(alvo.x, alvo.z).length()))
	# A pipa fica um pouco acima do meio; com pouca linha aparece o horizonte.
	var inclinacao := clampf(elevacao - fov * 0.18, 2.0, 70.0)
	var desejada := Transform3D(Basis.from_euler(Vector3(deg_to_rad(inclinacao), guinada, 0.0)), olho)
	if imediato:
		_camera.global_transform = desejada
		_camera.fov = fov
	else:
		_camera.global_transform = _camera.global_transform.interpolate_with(desejada, 0.1)
		_camera.fov = lerpf(_camera.fov, fov, 0.05)


# ---------------- gestos ----------------

func _input(evento: InputEvent) -> void:
	if evento is InputEventScreenTouch:
		var t := evento as InputEventScreenTouch
		_toque(t.index, t.position, t.pressed)
	elif evento is InputEventScreenDrag:
		var d := evento as InputEventScreenDrag
		_arrasto(d.index, d.position, d.relative)
	elif evento is InputEventMouseButton and evento.device != InputEvent.DEVICE_ID_EMULATION:
		var m := evento as InputEventMouseButton
		if m.button_index == MOUSE_BUTTON_LEFT:
			_toque(-2, m.position, m.pressed)
	elif evento is InputEventMouseMotion and evento.device != InputEvent.DEVICE_ID_EMULATION:
		var mm := evento as InputEventMouseMotion
		if _dedos.has(-2):
			_arrasto(-2, mm.position, mm.relative)
	elif evento is InputEventKey and evento.pressed and not evento.echo:
		if (evento as InputEventKey).physical_keycode == KEY_SPACE:
			_desbicar()


func _toque(indice: int, posicao: Vector2, apertou: bool) -> void:
	if _sobre_botao(posicao):
		return
	var agora := Time.get_ticks_msec() / 1000.0
	if apertou:
		_dedos[indice] = {"ini": posicao, "t0": agora, "ult": posicao}
		_embalo = 0.0
		return
	if not _dedos.has(indice):
		return
	var d: Dictionary = _dedos[indice]
	_dedos.erase(indice)
	if agora - float(d["t0"]) < TOQUE_MAX_S and posicao.distance_to(d["ini"]) < TOQUE_MAX_PX:
		_desbicar()
	elif _velocidade_mao < -0.5:
		_embalo = -_velocidade_mao  # soltou no embalo de dar linha: a carretilha segue girando


func _arrasto(indice: int, posicao: Vector2, relativo: Vector2) -> void:
	if not _dedos.has(indice):
		return
	_dy_quadro += relativo.y
	(_dedos[indice] as Dictionary)["ult"] = posicao


func _desbicar() -> void:
	var eu := modo.you()
	if _automatico or eu.cut or eu.pilot == null:
		return
	eu.pilot.trigger(Pilot.Impulse.DESBICAR, modo.world.time)


func _sobre_botao(posicao: Vector2) -> bool:
	for b in get_tree().get_nodes_in_group("botao_livre"):
		if (b as Control).visible and (b as Control).get_global_rect().has_point(posicao):
			return true
	return false


# ---------------- interface ----------------

func _atualizar_textos(eu: Flyer) -> void:
	var linhas: Array[String] = []
	for p in modo.ranking():
		linhas.append("%s — %d %s · %d %s" % [p["name"], p["cuts"], "corte" if int(p["cuts"]) == 1 else "cortes", p["catches"], "aparada" if int(p["catches"]) == 1 else "aparadas"])
	_placar.text = "\n".join(linhas)
	var p0: Dictionary = modo.players[0]
	if eu.cut:
		_info.text = "Sua linha foi cortada. Pipa nova em %d s…" % ceili(maxf(0.0, float(p0["respawn"])))
	else:
		var extra := "   PIPA ENROSCADA: puxe!" if eu.holding > 0 else ""
		_info.text = "Linha %d m · altura %d m%s" % [roundi(eu.line_length()), roundi(eu.kite.position.y - (p0["base"] as Vector3).y), extra]
	_aviso.visible = Time.get_ticks_msec() / 1000.0 < _aviso_ate
	_dica.visible = modo.world.time < 15.0


func _avisar(texto: String) -> void:
	_aviso.text = texto
	_aviso_ate = Time.get_ticks_msec() / 1000.0 + 3.5


## Desenha a carretilha, a seta do bico da sua pipa e os nomes/setas dos rivais.
func _desenhar_sobreposicao() -> void:
	var c := _sobreposicao
	var tela := c.get_viewport_rect().size
	var fonte := ThemeDB.fallback_font
	# Carretilha no canto de baixo à esquerda (gira com a linha).
	var centro := Vector2(110.0, tela.y - 110.0)
	c.draw_circle(centro, 86.0, Color(0.42, 0.25, 0.12, 0.92))
	c.draw_circle(centro, 70.0, Color(0.93, 0.92, 0.88, 0.95))
	c.draw_circle(centro, 22.0, Color(0.42, 0.25, 0.12, 1.0))
	for k in 4:
		var a := _giro_carretilha + k * PI / 2.0
		c.draw_line(centro + Vector2.from_angle(a) * 24.0, centro + Vector2.from_angle(a) * 68.0, Color(0.6, 0.55, 0.5, 0.8), 3.0)
	var cabo := centro + Vector2.from_angle(_giro_carretilha) * 58.0
	c.draw_circle(cabo, 11.0, Color(0.25, 0.15, 0.08))

	var eu := modo.you()
	for f in modo.world.flyers:
		var fl: Flyer = f
		var nome := ""
		var cor := Color(0.9, 0.9, 0.9)
		if fl.tag >= 0:
			cor = CORES[fl.tag]
			nome = String(modo.players[fl.tag]["name"]) if fl.tag > 0 else ""
		elif fl.cut and not fl.captured and not fl.lost:
			nome = "avoada!"
		if fl == eu:
			if not fl.cut:
				_seta_do_bico(fl)
			continue
		if nome == "":
			continue
		var p := fl.kite.position
		var na_frente := not _camera.is_position_behind(p)
		var s := _camera.unproject_position(p)
		var dentro := na_frente and Rect2(Vector2(30, 30), tela - Vector2(60, 60)).has_point(s)
		if dentro:
			c.draw_string_outline(fonte, s + Vector2(-40.0, -22.0), nome, HORIZONTAL_ALIGNMENT_LEFT, -1, 20, 6, Color(0, 0, 0, 0.8))
			c.draw_string(fonte, s + Vector2(-40.0, -22.0), nome, HORIZONTAL_ALIGNMENT_LEFT, -1, 20, cor)
		else:
			# Seta na borda da tela apontando para onde está a pipa.
			var meio := tela * 0.5
			var dir := (s - meio) if na_frente else (meio - s)
			if dir.length() < 1.0:
				dir = Vector2.UP
			dir = dir.normalized()
			var escala := minf((meio.x - 50.0) / maxf(absf(dir.x), 1e-3), (meio.y - 50.0) / maxf(absf(dir.y), 1e-3))
			var ponta := meio + dir * escala
			var lado := dir.orthogonal() * 12.0
			c.draw_colored_polygon(PackedVector2Array([ponta + dir * 18.0, ponta + lado, ponta - lado]), cor)
			c.draw_string_outline(fonte, ponta - dir * 30.0 + Vector2(-40.0, 6.0), nome, HORIZONTAL_ALIGNMENT_LEFT, -1, 18, 6, Color(0, 0, 0, 0.8))
			c.draw_string(fonte, ponta - dir * 30.0 + Vector2(-40.0, 6.0), nome, HORIZONTAL_ALIGNMENT_LEFT, -1, 18, cor)


## Seta curta saindo da sua pipa na direção do bico: ajuda a desbicar.
func _seta_do_bico(f: Flyer) -> void:
	var p := f.kite.position
	if _camera.is_position_behind(p):
		return
	var bico := f.kite.rotation * Vector3(0.0, 1.0, 0.0)
	var a := _camera.unproject_position(p)
	var b := _camera.unproject_position(p + bico * 0.6)
	var dir := (b - a)
	if dir.length() < 1.0:
		return
	dir = dir.normalized()
	var ponta := a + dir * 46.0
	_sobreposicao.draw_line(a + dir * 22.0, ponta, Color(1, 1, 1, 0.75), 3.0)
	_sobreposicao.draw_colored_polygon(PackedVector2Array([ponta + dir * 12.0, ponta + dir.orthogonal() * 7.0, ponta - dir.orthogonal() * 7.0]), Color(1, 1, 1, 0.75))


func _criar_interface() -> void:
	var camada := CanvasLayer.new()
	camada.name = "Interface"
	add_child(camada)
	var raiz := Control.new()
	raiz.set_anchors_preset(Control.PRESET_FULL_RECT)
	raiz.mouse_filter = Control.MOUSE_FILTER_IGNORE
	camada.add_child(raiz)

	_sobreposicao = Control.new()
	_sobreposicao.name = "Sobreposicao"
	_sobreposicao.set_anchors_preset(Control.PRESET_FULL_RECT)
	_sobreposicao.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_sobreposicao.draw.connect(_desenhar_sobreposicao)
	raiz.add_child(_sobreposicao)

	_placar = _rotulo(raiz, 20, Color(1.0, 0.95, 0.7), HORIZONTAL_ALIGNMENT_LEFT)
	_placar.position = Vector2(16.0, 28.0)
	_info = _rotulo(raiz, 20, Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER)
	_info.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	_info.offset_left = -360.0
	_info.offset_right = 360.0
	_info.offset_top = -48.0
	_info.offset_bottom = -12.0
	_aviso = _rotulo(raiz, 32, Color(1.0, 0.85, 0.2), HORIZONTAL_ALIGNMENT_CENTER)
	_aviso.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_aviso.offset_left = -420.0
	_aviso.offset_right = 420.0
	_aviso.offset_top = 70.0
	_aviso.offset_bottom = 160.0
	_dica = _rotulo(raiz, 20, Color(0.9, 0.95, 1.0), HORIZONTAL_ALIGNMENT_CENTER)
	_dica.text = "Deslize para BAIXO: puxa · para CIMA: dá linha · TOQUES: desbica"
	_dica.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	_dica.offset_left = -420.0
	_dica.offset_right = 420.0
	_dica.offset_top = -90.0
	_dica.offset_bottom = -54.0

	var cantos := HBoxContainer.new()
	cantos.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	cantos.offset_left = -240.0
	cantos.offset_right = -12.0
	cantos.offset_top = 12.0
	cantos.alignment = BoxContainer.ALIGNMENT_END
	raiz.add_child(cantos)
	var cam := _botao(cantos, "Câmera")
	cam.pressed.connect(func() -> void: _primeira_pessoa = not _primeira_pessoa)
	var lab := _botao(cantos, "Lab")
	lab.pressed.connect(_ao_abrir_laboratorio)

	var versao := Label.new()
	versao.text = "PIPA BRASIL %s · build %s" % [ProjectSettings.get_setting("application/config/version", "?"), BuildInfo.COMMIT]
	versao.add_theme_font_size_override("font_size", 12)
	versao.position = Vector2(16.0, 6.0)
	versao.mouse_filter = Control.MOUSE_FILTER_IGNORE
	raiz.add_child(versao)


func _rotulo(pai: Control, tamanho: int, cor: Color, alinhamento: HorizontalAlignment) -> Label:
	var l := Label.new()
	l.horizontal_alignment = alinhamento
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART if alinhamento == HORIZONTAL_ALIGNMENT_CENTER else TextServer.AUTOWRAP_OFF
	l.add_theme_font_size_override("font_size", tamanho)
	l.add_theme_color_override("font_color", cor)
	l.add_theme_color_override("font_outline_color", Color(0.0, 0.0, 0.0, 0.85))
	l.add_theme_constant_override("outline_size", 7)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pai.add_child(l)
	return l


func _botao(pai: Control, texto: String) -> Button:
	var b := Button.new()
	b.text = texto
	b.focus_mode = Control.FOCUS_NONE
	b.add_theme_font_size_override("font_size", 18)
	var estilo := StyleBoxFlat.new()
	estilo.bg_color = Color(0.0, 0.0, 0.0, 0.45)
	estilo.set_corner_radius_all(14)
	estilo.set_content_margin_all(10)
	b.add_theme_stylebox_override("normal", estilo)
	b.add_theme_stylebox_override("hover", estilo)
	b.add_to_group("botao_livre")
	pai.add_child(b)
	return b


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


func _ao_abrir_laboratorio() -> void:
	get_tree().change_scene_to_file("res://scenes/lab/lab.tscn")
