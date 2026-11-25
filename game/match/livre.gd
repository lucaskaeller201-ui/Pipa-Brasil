extends Node3D
## Modo livre na laje (tela principal, celular deitado).
##
## Sem botões de comando: os gestos são os do pipeiro.
##   • Deslizar o dedo para BAIXO: puxa linha com a mão ("abraçar"); rápido = puxada forte.
##   • Deslizar para CIMA: dá linha (até 4 m/s); a pipa descarrega e gira num
##     ritmo constante, mostrando o bico para todos os lados.
##   • TOQUE rápido: tenteio — o bico dá um pulo de uns 25°, cada toque para um
##     lado; parando, o vento traz o bico de volta para cima. Puxe (deslize
##     para baixo) quando o bico apontar para onde quer ir (D-035).
##   • LARGADA: com a linha laçada, puxe (pressão) e logo deslize para cima de
##     uma vez: a linha corre e serra a do rival com o dobro de força.
## No PC: W/↓ puxa, S/↑ dá linha, Espaço desbica, arrastar com o mouse também vale.
## A física é a mesma do laboratório: os gestos viram comandos do PilotInput.

const BuildInfo := preload("res://game/main/build_info.gd")
const Ambiente := preload("res://game/world/ambiente.gd")
const Bairro := preload("res://game/world/bairro.gd")
const KiteView := preload("res://game/views/kite_view.gd")
const Estilos := preload("res://game/views/estilos_pipa.gd")
const LinesView := preload("res://game/views/lines_view.gd")

## Ajustes finos (também na tela, no botão "Ajustes"):
## velocidade do giro mandando linha (graus/s) e força da puxada (m/s de linha
## que a mão recolhe no toque e no máximo ao deslizar para baixo).
@export var velocidade_giro_mandando_linha := 360.0
@export var forca_puxada := 6.0

const BOTS := 5   ## festival: 5 rivais com jeitos diferentes de jogar
const ARQUIVO_ESTATISTICAS := "user://estatisticas.json"
const LINHA_POR_TELA := 2.5     ## m de linha por altura de tela deslizada
const DESCARREGAR := 2.5        ## m/s de linha saindo com a tecla S/↑
const TOQUE_RECOLHE := 0.4      ## s: no desbico, a mão recolhe a folga até a linha esticar
const TOQUE_VELOCIDADE := 4.0   ## m/s dessa recolhida (abaixo do que decepa)
const TOQUE_TENSAO := 2.5       ## N: linha esticada de novo
const EMBALO := 0.35            ## s que a carretilha leva para parar depois de mandar linha
const DAR_LINHA_MAX := 4.0      ## m/s: o mais rápido que se dá linha (segurando e deslizando para cima)
const PUXOU_PX := 6.0           ## px para baixo que transformam o dedo em dedo de puxar
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
var _estilo_de := {}            # Flyer -> estilo (desenho e fitinhas)
var _corpos: Array = []         # boneco de cada participante

# gestos
var _dedos := {}                # índice -> {"ini": Vector2, "t0": float, "ult": Vector2}
var _dy_quadro := 0.0           # pixels deslizados neste quadro (+ = para baixo)
var _velocidade_mao := 0.0      # m/s (+ = puxando)
var _giro_carretilha := 0.0
var _embalo := 0.0              # m/s de linha ainda saindo pelo embalo da carretilha
var _toque_ate := -1.0          # até quando a mão recolhe a folga do desbico
var _ultimo_lado := 1.0         # lado do último tenteio
var _ultimo_toque := -99.0      # instante do último toque (s)
var _ultimo_duplo := false      # o último toque fechou um toque duplo
var _duplo_t := -99.0           # instante do último toque duplo (s)
var _dir_volta := 0.0           # sentido em que os toques duplos estão virando
var _sentido_antes := 1.0       # lado do bico antes do último toque simples
var _sentido := -1.0            # sentido do giro do último tenteio (+1/-1)
## Tenteio (D-049, D-050): cada toque balança o bico ~30° para um lado e o
## próximo para o outro, em volta da direção em que a pipa estava (tocar não
## faz rodar). Toque DUPLO (dois toques bem juntos): a direção anda 30° para
## o lado do toque — de 30 em 30 o bico vai para o lado, para baixo, ou dá a
## volta (12 duplos = 360°).
const TOQUE_DUPLO_S := 0.3      ## s entre os dois toques do toque duplo
const VOLTA_SEGUE_S := 1.5      ## s: outro duplo logo depois continua virando para o mesmo lado (D-052)
@export var graus_por_toque := 30.0

# interface
var _placar: Label
var _aviso: Label
var _aviso_ate := 0.0
var _info: Label
var _dica: Label
var _sobreposicao: Control
var _painel_ajustes: PanelContainer
var _banner: Label
var _banner_ate := 0.0
var _tremor := 0.0              # força do tremor da câmera (decai)
var _lenta_ate := 0.0           # até quando (tempo real) fica em câmera lenta
var _painel_mao: PanelContainer     # escolher pipa e linha e colocar no alto (D-037)
var _botoes_pipa: Array = []
var _botoes_linha: Array = []
var _botao_desenho: Button
var _previa: Control
var _previa_estilo := -1
var _rotulo_mao: Label
var _estatisticas := {"cortes": 0, "aparadas": 0, "perdidas": 0, "melhor_sequencia": 0}


func _ready() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg == "--auto":
			_automatico = true
		elif arg == "--terceira":
			_primeira_pessoa = false
		elif arg.begins_with("--semente="):
			_semente = arg.trim_prefix("--semente=").to_int()
	modo = FreeMode.new(BOTS, _semente, _automatico)
	_carregar_estatisticas()
	_aplicar_giro()
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
	if not _automatico:
		modo.put_you_on_hand()
	_criar_interface()
	_posicionar_camera(true)


## Avança o jogo (também usado pelos testes).
func avancar(segundos: float) -> void:
	for i in roundi(segundos * Engine.physics_ticks_per_second):
		_physics_process(1.0 / Engine.physics_ticks_per_second)


func _physics_process(delta: float) -> void:
	var eu := modo.you()
	if not _automatico and eu != null and not eu.cut:
		_ler_comandos(eu, delta)
	modo.update(delta)
	for msg in modo.take_messages():
		_avisar(msg)


func _ler_comandos(eu: Flyer, delta: float) -> void:
	var e := eu.input
	var v := _velocidade_mao   # + = puxando (para baixo); - = mandando linha (para cima)
	if Input.is_physical_key_pressed(KEY_W) or Input.is_physical_key_pressed(KEY_DOWN):
		v = maxf(v, 3.0)
	if Input.is_physical_key_pressed(KEY_S) or Input.is_physical_key_pressed(KEY_UP):
		v = minf(v, -DESCARREGAR)
	# Mandando linha (deslizar para cima): a carretilha embala e continua
	# soltando um pouco depois do dedo parar; puxar corta o embalo na hora.
	if v < -0.3:
		_embalo = maxf(_embalo, -v)
	elif v > 0.3:
		_embalo = 0.0
	else:
		_embalo = move_toward(_embalo, 0.0, delta * DAR_LINHA_MAX / EMBALO)
		if _embalo > 0.2:
			v = -_embalo
	if modo.world.time < _toque_ate:
		if eu.tension < TOQUE_TENSAO:
			v = maxf(v, TOQUE_VELOCIDADE)
		else:
			_toque_ate = -1.0
	e.haul_speed = clampf(v, -DAR_LINHA_MAX, forca_puxada)


func _process(delta: float) -> void:
	_ver_toque_pendente()
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
		if fl.tail != null:
			# Rabiola: o barbante fininho e as fitinhas coloridas (D-043).
			var estilo: Dictionary = _estilo_de.get(fl, Estilos.ESTILOS[0])
			_linhas.call("desenhar_cadeia", fl.tail.pos, Color(0.9, 0.9, 0.9, 0.8), 0.0008, 0.5)
			_linhas.call("desenhar_fitinhas", fl.tail.pos, estilo["fitas"], Time.get_ticks_msec() / 1000.0)
	var eu := modo.you()
	_tratar_acontecimentos()
	var agora_real := Time.get_ticks_msec() / 1000.0
	if Engine.time_scale < 1.0 and agora_real > _lenta_ate:
		Engine.time_scale = 1.0
	_banner.visible = agora_real < _banner_ate
	if eu != null:
		_giro_carretilha += eu.input.haul_speed * delta * 3.0
	_painel_mao.visible = modo.you_on_hand
	if modo.you_on_hand:
		_atualizar_painel_mao()
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
			var estilo: Dictionary = Estilos.ESTILOS[int(modo.players[fl.tag].get("style", 0))] if fl.tag >= 0 else Estilos.ESTILOS[0]
			_estilo_de[fl] = estilo
			v.call("construir", fl.kite.definition, estilo)
			_vistas[fl] = v
		(_vistas[fl] as Node3D).call("atualizar", fl.kite)
	for fl in _vistas.keys():
		if not vivos.has(fl):
			(_vistas[fl] as Node).queue_free()
			_vistas.erase(fl)
			_estilo_de.erase(fl)


# ---------------- câmera ----------------

func _posicionar_camera(imediato: bool) -> void:
	var eu := modo.you()
	var base: Vector3 = modo.players[0]["base"]
	var olho := base + Pilot.SHOULDER + Vector3(0.0, 0.2, 0.15)
	if not _primeira_pessoa:
		olho = base + Pilot.SHOULDER + Vector3(1.5, 1.5, 6.5)
	_corpos[0].visible = not _primeira_pessoa
	var mira := eu.kite.position if eu != null else olho + Vector3(0.0, 14.0, -22.0)
	var alvo := mira - olho
	var dist := alvo.length()
	# Zoom (1ª pessoa): a pipa ocupa uns 10% da altura da tela (dá para ver o modelo). Na 3ª pessoa,
	# visão aberta para ver as lajes e as outras pipas.
	var envergadura := 0.6
	var fov := clampf(rad_to_deg(envergadura / maxf(dist, 1.0)) / 0.10, 8.0, 55.0)
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
	# Tremor (corte): deslocamento pequeno da imagem, que some rápido.
	_camera.h_offset = randf_range(-1.0, 1.0) * _tremor * 0.02
	_camera.v_offset = randf_range(-1.0, 1.0) * _tremor * 0.02
	_tremor = maxf(0.0, _tremor - 0.06)


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
		var tecla := (evento as InputEventKey).physical_keycode
		if tecla == KEY_Q or tecla == KEY_LEFT:
			_sentido = -1.0
			_desbicar(-1.0, -1.0)
		elif tecla == KEY_E or tecla == KEY_RIGHT:
			_sentido = 1.0
			_desbicar(1.0, 1.0)
		elif tecla == KEY_SPACE:
			_tentear()


func _toque(indice: int, posicao: Vector2, apertou: bool) -> void:
	if _sobre_botao(posicao):
		return
	var agora := Time.get_ticks_msec() / 1000.0
	if apertou:
		_dedos[indice] = {"ini": posicao, "t0": agora, "ult": posicao, "puxou": false}
		return
	if not _dedos.has(indice):
		return
	var d: Dictionary = _dedos[indice]
	_dedos.erase(indice)
	if agora - float(d["t0"]) < TOQUE_MAX_S and posicao.distance_to(d["ini"]) < TOQUE_MAX_PX:
		# toque na metade esquerda da tela: bico para a esquerda; direita: direita
		_tentear()


func _arrasto(indice: int, posicao: Vector2, relativo: Vector2) -> void:
	if not _dedos.has(indice):
		return
	_dy_quadro += relativo.y
	var d: Dictionary = _dedos[indice]
	d["ult"] = posicao
	if relativo.y > 0.0 and posicao.y - (d["ini"] as Vector2).y > PUXOU_PX:
		d["puxou"] = true   # este dedo é de puxar (enquanto estiver na tela)


## Tenteio pelo toque (D-041).
func _tentear() -> void:
	var agora := Time.get_ticks_msec() / 1000.0
	if agora - _ultimo_toque < TOQUE_DUPLO_S and not _ultimo_duplo:
		# 2º toque do duplo: a direção anda 30° (D-050). Duplos seguidos
		# continuam virando para o MESMO lado (D-052): 60°, 90°, 120°...
		_ultimo_duplo = true
		# D-055: o duplo vira para o lado em que o bico já estava (antes do 1º
		# toque dele): bico para a direita + duplo = mais para a direita.
		_sentido = _sentido_antes
		if agora - _duplo_t < VOLTA_SEGUE_S and _dir_volta != 0.0:
			_sentido = _dir_volta
		_dir_volta = _sentido
		_duplo_t = agora
		_desbicar(_sentido, _sentido, 1.0, graus_por_toque)
		_avisar("↻ %d°" % roundi(graus_por_toque) if _sentido > 0.0 else "↺ %d°" % roundi(graus_por_toque))
	else:
		# toque simples: o bico vai ~30° para o outro lado (na hora)
		_ultimo_duplo = false
		_sentido_antes = _sentido
		_sentido = -_sentido
		_desbicar(_sentido, _sentido, 1.0)
	_ultimo_toque = agora


func _ver_toque_pendente() -> void:
	pass


func _desbicar(lado: float, sentido := 0.0, escala := 1.0, anda := 0.0) -> void:
	var eu := modo.you()
	if _automatico or eu == null or eu.cut or eu.pilot == null:
		return
	# Tenteio (D-035): o bico dá um pulo curto para um lado (cada toque para
	# um lado), sem puxar; o vento traz de volta. Puxe quando apontar certo.
	_ultimo_lado = lado
	eu.input.kick_side = lado
	eu.input.kick_spin = sentido
	eu.input.kick_scale = escala
	eu.input.kick_base_shift = anda
	eu.pilot.trigger(Pilot.Impulse.DESBICAR_LADO, modo.world.time)
	_embalo = 0.0


func _sobre_botao(posicao: Vector2) -> bool:
	for b in get_tree().get_nodes_in_group("botao_livre"):
		if (b as Control).visible and (b as Control).get_global_rect().has_point(posicao):
			return true
	return false


# ---------------- interface ----------------

func _atualizar_textos(eu: Flyer) -> void:
	var linhas: Array[String] = []
	for p in modo.ranking():
		linhas.append("%s — %d %s · %d %s · estoque %d" % [p["name"], p["cuts"], "corte" if int(p["cuts"]) == 1 else "cortes", p["catches"], "aparada" if int(p["catches"]) == 1 else "aparadas", p["stock"]])
	var seq := int(modo.players[0]["streak"])
	if seq >= 2:
		linhas.append("Sequência: %d cortes · x%d%s" % [seq, _multiplicador(seq), "  · REI DA LAJE" if seq >= 3 else ""])
	linhas.append("Total salvo: %d cortes · %d aparadas · melhor sequência %d" % [_estatisticas["cortes"], _estatisticas["aparadas"], _estatisticas["melhor_sequencia"]])
	_placar.text = "\n".join(linhas)
	var p0: Dictionary = modo.players[0]
	if eu == null:
		_info.text = "Pipa na mão · estoque %d" % int(p0["stock"])
	elif eu.cut:
		_info.text = "Sua linha foi cortada…"
	else:
		var extra := "   ENROSCOU: puxe a linha toda para trazer!" if eu.holding > 0 else ""
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

	_desenhar_relo_e_vento(c, tela)
	# Faísca nos pontos em que as linhas estão laçadas.
	for p in modo.world.combat.contact_points:
		if _camera.is_position_behind(p):
			continue
		var s := _camera.unproject_position(p)
		var brilho := 0.6 + 0.4 * sin(Time.get_ticks_msec() * 0.03)
		for k in 6:
			var a := k * PI / 3.0 + Time.get_ticks_msec() * 0.005
			c.draw_line(s, s + Vector2.from_angle(a) * (10.0 + 6.0 * brilho), Color(1.0, 0.85, 0.3, brilho), 2.0)
		c.draw_circle(s, 4.0, Color(1.0, 1.0, 0.8, brilho))

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

	_placar = _rotulo(raiz, 16, Color(1.0, 0.95, 0.7), HORIZONTAL_ALIGNMENT_LEFT)
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
	_banner = _rotulo(raiz, 48, Color(1.0, 0.82, 0.15), HORIZONTAL_ALIGNMENT_CENTER)
	_banner.set_anchors_preset(Control.PRESET_CENTER)
	_banner.offset_left = -520.0
	_banner.offset_right = 520.0
	_banner.offset_top = -120.0
	_banner.offset_bottom = -40.0
	_banner.add_theme_constant_override("outline_size", 12)
	_banner.visible = false
	_dica = _rotulo(raiz, 20, Color(0.9, 0.95, 1.0), HORIZONTAL_ALIGNMENT_CENTER)
	_dica.text = "Deslize para CIMA: manda linha (a pipa gira) · para BAIXO: puxa · TOQUES: tenteio (o bico balança ~30° para cada lado) · TOQUE DUPLO: o bico vira 30° (de 30 em 30)"
	_dica.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	_dica.offset_left = -420.0
	_dica.offset_right = 420.0
	_dica.offset_top = -90.0
	_dica.offset_bottom = -54.0

	var cantos := HBoxContainer.new()
	cantos.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	cantos.offset_left = -360.0
	cantos.offset_right = -12.0
	cantos.offset_top = 12.0
	cantos.alignment = BoxContainer.ALIGNMENT_END
	raiz.add_child(cantos)
	var cam := _botao(cantos, "Câmera")
	cam.pressed.connect(func() -> void: _primeira_pessoa = not _primeira_pessoa)
	var ajustes := _botao(cantos, "Ajustes")
	ajustes.pressed.connect(func() -> void: _painel_ajustes.visible = not _painel_ajustes.visible)
	var lab := _botao(cantos, "Lab")
	lab.pressed.connect(_ao_abrir_laboratorio)

	_painel_ajustes = PanelContainer.new()
	_painel_ajustes.name = "Ajustes"
	_painel_ajustes.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	_painel_ajustes.offset_left = -430.0
	_painel_ajustes.offset_right = -12.0
	_painel_ajustes.offset_top = 70.0
	_painel_ajustes.visible = false
	_painel_ajustes.add_to_group("botao_livre")
	raiz.add_child(_painel_ajustes)
	var caixa := VBoxContainer.new()
	_painel_ajustes.add_child(caixa)
	_ajuste(caixa, "Giro máximo mandando linha (°/s)", 60.0, 900.0, 20.0, velocidade_giro_mandando_linha, "giro")
	_ajuste(caixa, "Força da puxada (m/s)", 2.0, 10.0, 0.5, forca_puxada, "puxada")
	_ajuste(caixa, "Giro por toque no tenteio (°)", 15.0, 90.0, 3.0, graus_por_toque, "toque")

	_criar_painel_mao(raiz)

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


func _aplicar_giro() -> void:
	modo.your_spin_rate = velocidade_giro_mandando_linha
	var eu := modo.you()
	if eu != null:
		eu.kite.definition.spin_give_rate_deg = velocidade_giro_mandando_linha


func _ao_ajustar(v: float, qual: String, rotulo: Label, nome: String) -> void:
	rotulo.text = "%s: %s" % [nome, str(v)]
	if qual == "toque":
		graus_por_toque = v
		modo.your_kick_deg = v
		if modo.you() != null:
			modo.you().kite.definition.spin_kick_rate_deg = v
	if qual == "giro":
		velocidade_giro_mandando_linha = v
		_aplicar_giro()
	else:
		forca_puxada = v


func _ajuste(caixa: VBoxContainer, nome: String, minimo: float, maximo: float, passo: float, valor: float, qual: String) -> void:
	var rotulo := Label.new()
	rotulo.add_theme_font_size_override("font_size", 18)
	caixa.add_child(rotulo)
	var s := HSlider.new()
	s.min_value = minimo
	s.max_value = maximo
	s.step = passo
	s.value = valor
	s.custom_minimum_size = Vector2(380.0, 40.0)
	caixa.add_child(s)
	rotulo.text = "%s: %s" % [nome, str(valor)]
	s.value_changed.connect(_ao_ajustar.bind(qual, rotulo, nome))



# ---------------- impacto, relô, sequência e estatísticas ----------------

func _tratar_acontecimentos() -> void:
	for e in modo.take_screen_events():
		match e["type"]:
			"corte":
				if int(e["autor"]) == 0:
					_tremor = 1.0
					_camera_lenta(0.3)
					var seq := int(modo.players[0]["streak"])
					_mostrar_banner("CORTOU! +%d" % _multiplicador(seq) if seq < 3 else "CORTOU! +%d · REI DA LAJE!" % _multiplicador(seq))
					_estatisticas["cortes"] = int(_estatisticas["cortes"]) + 1
					_estatisticas["melhor_sequencia"] = maxi(int(_estatisticas["melhor_sequencia"]), seq)
					_salvar_estatisticas()
				elif int(e["vitima"]) == 0:
					_tremor = 0.7
					_mostrar_banner("AVOOU! Sua linha foi cortada.")
					_estatisticas["perdidas"] = int(_estatisticas["perdidas"]) + 1
					_salvar_estatisticas()
			"aparada":
				if int(e["quem"]) == 0:
					_mostrar_banner("APAROU! A pipa foi para o estoque.")
					_estatisticas["aparadas"] = int(_estatisticas["aparadas"]) + 1
					_salvar_estatisticas()


## Sequência de cortes sem perder a pipa: 2 seguidos valem 2, 3 ou mais valem 3, 5 ou mais valem 5.
func _multiplicador(seq: int) -> int:
	if seq >= 5:
		return 5
	if seq >= 3:
		return 3
	if seq >= 2:
		return 2
	return 1


func _camera_lenta(segundos: float) -> void:
	Engine.time_scale = 0.3
	_lenta_ate = Time.get_ticks_msec() / 1000.0 + segundos


func _mostrar_banner(texto: String) -> void:
	_banner.text = texto
	_banner_ate = Time.get_ticks_msec() / 1000.0 + 2.0


func _carregar_estatisticas() -> void:
	if not FileAccess.file_exists(ARQUIVO_ESTATISTICAS):
		return
	var f := FileAccess.open(ARQUIVO_ESTATISTICAS, FileAccess.READ)
	if f == null:
		return
	var dados = JSON.parse_string(f.get_as_text())
	if dados is Dictionary:
		for k in _estatisticas:
			if (dados as Dictionary).has(k):
				_estatisticas[k] = int(dados[k])


func _salvar_estatisticas() -> void:
	var f := FileAccess.open(ARQUIVO_ESTATISTICAS, FileAccess.WRITE)
	if f != null:
		f.store_string(JSON.stringify(_estatisticas))


## Barra do relô (verde = você está ganhando; vermelho = sua linha vai
## estourar, descarregue!) e indicador de vento.
func _desenhar_relo_e_vento(c: Control, tela: Vector2) -> void:
	var fonte := ThemeDB.fallback_font
	var r := modo.your_relo()
	if not r.is_empty():
		var forca: float = maxf(0.01, float(r["strength"]))
		var eu := clampf(float(r["you"]) / forca, 0.0, 1.0)
		var ele := clampf(float(r["them"]) / forca, 0.0, 1.0)
		var largura := 420.0
		var x0 := (tela.x - largura) * 0.5
		var y0 := 170.0
		c.draw_rect(Rect2(x0 - 4, y0 - 4, largura + 8, 30), Color(0, 0, 0, 0.55))
		# metade esquerda: quanto a SUA linha já gastou; direita: a dele
		c.draw_rect(Rect2(x0, y0, largura * 0.5 * eu, 22), Color(0.95, 0.2, 0.15))
		c.draw_rect(Rect2(x0 + largura * 0.5, y0, largura * 0.5 * ele, 22), Color(0.2, 0.85, 0.3))
		c.draw_line(Vector2(x0 + largura * 0.5, y0 - 4), Vector2(x0 + largura * 0.5, y0 + 26), Color.WHITE, 2.0)
		var nome := String(modo.players[int(r["other"])]["name"]) if int(r["other"]) >= 0 else "rival"
		var aviso := "RELÔ com %s — você está ganhando!" % nome if ele >= eu else "RELÔ com %s — sua linha vai estourar, descarregue!" % nome
		var cor := Color(0.4, 1.0, 0.5) if ele >= eu else Color(1.0, 0.45, 0.35)
		c.draw_string_outline(fonte, Vector2(x0, y0 + 50), aviso, HORIZONTAL_ALIGNMENT_CENTER, largura, 18, 6, Color(0, 0, 0, 0.85))
		c.draw_string(fonte, Vector2(x0, y0 + 50), aviso, HORIZONTAL_ALIGNMENT_CENTER, largura, 18, cor)
	# Vento: seta no canto (direção vista da sua câmera) e força.
	var ref := modo.you().kite.position if modo.you() != null else _camera.global_position + Vector3(0.0, 15.0, 0.0)
	var vento := modo.world.wind.sample(ref, modo.world.time)
	var na_tela := _camera.global_transform.basis.inverse() * vento
	var dir := Vector2(na_tela.x, -na_tela.y - na_tela.z * 0.3)
	if dir.length() > 0.01:
		dir = dir.normalized()
	var centro := Vector2(tela.x - 70.0, 120.0)
	c.draw_circle(centro, 34.0, Color(0, 0, 0, 0.4))
	c.draw_line(centro - dir * 22.0, centro + dir * 22.0, Color(0.85, 0.95, 1.0), 4.0)
	c.draw_colored_polygon(PackedVector2Array([centro + dir * 30.0, centro + dir * 16.0 + dir.orthogonal() * 9.0, centro + dir * 16.0 - dir.orthogonal() * 9.0]), Color(0.85, 0.95, 1.0))
	var txt := "vento %d m/s" % roundi(vento.length())
	c.draw_string_outline(fonte, centro + Vector2(-46.0, 54.0), txt, HORIZONTAL_ALIGNMENT_LEFT, -1, 15, 5, Color(0, 0, 0, 0.8))
	c.draw_string(fonte, centro + Vector2(-46.0, 54.0), txt, HORIZONTAL_ALIGNMENT_LEFT, -1, 15, Color.WHITE)


func _mostrar_aviso_curto(texto: String) -> void:
	_avisar(texto)


# ---------------- pipa na mão (D-037) ----------------

func _criar_painel_mao(raiz: Control) -> void:
	_painel_mao = PanelContainer.new()
	_painel_mao.name = "PipaNaMao"
	_painel_mao.set_anchors_preset(Control.PRESET_CENTER)
	_painel_mao.offset_left = -470.0
	_painel_mao.offset_right = 470.0
	_painel_mao.offset_top = -200.0
	_painel_mao.offset_bottom = 200.0
	var fundo := StyleBoxFlat.new()
	fundo.bg_color = Color(0.05, 0.05, 0.12, 0.8)
	fundo.set_corner_radius_all(18)
	fundo.set_content_margin_all(16)
	_painel_mao.add_theme_stylebox_override("panel", fundo)
	_painel_mao.add_to_group("botao_livre")
	raiz.add_child(_painel_mao)
	var linha_mao := HBoxContainer.new()
	linha_mao.add_theme_constant_override("separation", 16)
	_painel_mao.add_child(linha_mao)
	# Prévia da pipa escolhida (formato e estampa do modelo).
	_previa = Control.new()
	_previa.name = "Previa"
	_previa.custom_minimum_size = Vector2(190.0, 300.0)
	_previa.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_previa.draw.connect(_desenhar_previa)
	linha_mao.add_child(_previa)
	var caixa := VBoxContainer.new()
	caixa.add_theme_constant_override("separation", 8)
	caixa.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	linha_mao.add_child(caixa)
	_rotulo_mao = _rotulo(caixa, 20, Color(1.0, 0.9, 0.5), HORIZONTAL_ALIGNMENT_CENTER)
	_rotulo(caixa, 16, Color.WHITE, HORIZONTAL_ALIGNMENT_LEFT).text = "Rabiola:"
	var linha_p := HBoxContainer.new()
	caixa.add_child(linha_p)
	for k in FreeMode.PIPAS.size():
		var b := _botao(linha_p, String(FreeMode.PIPAS[k]))
		b.add_theme_font_size_override("font_size", 14)
		b.pressed.connect(_escolher_pipa.bind(k))
		_botoes_pipa.append(b)
	_rotulo(caixa, 16, Color.WHITE, HORIZONTAL_ALIGNMENT_LEFT).text = "Linha:"
	var linha_l := HBoxContainer.new()
	caixa.add_child(linha_l)
	for k in FreeMode.LINHAS.size():
		var b := _botao(linha_l, String(FreeMode.LINHAS[k]))
		b.add_theme_font_size_override("font_size", 14)
		b.pressed.connect(_escolher_linha.bind(k))
		_botoes_linha.append(b)
	_botao_desenho = _botao(caixa, "")
	_botao_desenho.add_theme_font_size_override("font_size", 15)
	_botao_desenho.pressed.connect(_trocar_desenho)
	var subir := _botao(caixa, "COLOCAR NO ALTO")
	subir.name = "ColocarNoAlto"
	subir.add_theme_font_size_override("font_size", 26)
	subir.pressed.connect(_colocar_no_alto)
	_painel_mao.visible = modo.you_on_hand


func _escolher_pipa(k: int) -> void:
	modo.you_kite = k


func _trocar_desenho() -> void:
	modo.you_style = (modo.you_style + 1) % Estilos.ESTILOS.size()
	_previa.queue_redraw()


## Desenha o modelo escolhido: contorno com as medidas e a estampa.
func _desenhar_previa() -> void:
	var estilo: Dictionary = Estilos.ESTILOS[modo.you_style]
	var m: Array = estilo["m"]
	var area := _previa.size
	var escala := minf((area.y - 20.0) / float(m[0]), (area.x - 20.0) / maxf(float(m[1]), float(m[2])))
	var cx := area.x * 0.5
	var y0 := (area.y - float(m[0]) * escala) * 0.5
	var ys := [0.0, float(m[3]), float(m[3]) + float(m[4]), float(m[0])]
	var ws := [0.0, float(m[1]) * 0.5, float(m[2]) * 0.5, 0.0]
	var tb := float(m[3]) / float(m[0])
	var tc := (float(m[3]) + float(m[4])) / float(m[0])
	var meia := maxf(float(m[1]), float(m[2])) * 0.5
	for fx in range(1, 3):   # o bico não tem papel (D-047)
		for j in 8:
			var ya := lerpf(ys[fx], ys[fx + 1], j / 8.0)
			var yb := lerpf(ys[fx], ys[fx + 1], (j + 1) / 8.0)
			var wa := lerpf(ws[fx], ws[fx + 1], j / 8.0)
			var wb := lerpf(ws[fx], ws[fx + 1], (j + 1) / 8.0)
			for i in 16:
				var u0 := lerpf(-1.0, 1.0, i / 16.0)
				var u1 := lerpf(-1.0, 1.0, (i + 1) / 16.0)
				var cxm := (u0 + u1) * 0.25 * (wa + wb)
				var cor := Estilos.cor(estilo, cxm / meia, (ya + yb) * 0.5 / float(m[0]), tb, tc)
				var pts := PackedVector2Array([
					Vector2(cx + u0 * wa * escala, y0 + ya * escala), Vector2(cx + u1 * wa * escala, y0 + ya * escala),
					Vector2(cx + u1 * wb * escala, y0 + yb * escala), Vector2(cx + u0 * wb * escala, y0 + yb * escala)])
				if wa < 0.001:
					pts = PackedVector2Array([pts[0], pts[2], pts[3]])
				elif wb < 0.001:
					pts = PackedVector2Array([pts[0], pts[1], pts[2]])
				_previa.draw_colored_polygon(pts, cor)
	# linha do bico e varetas
	var topo := Vector2(cx, y0)
	var ys1: float = y0 + float(ys[1]) * escala
	var ws1: float = float(ws[1]) * escala
	_previa.draw_line(topo, Vector2(cx - ws1, ys1), Color(0.95, 0.95, 0.95), 1.5)
	_previa.draw_line(topo, Vector2(cx + ws1, ys1), Color(0.95, 0.95, 0.95), 1.5)
	var marrom := Color(0.35, 0.22, 0.1)
	_previa.draw_line(Vector2(cx, y0), Vector2(cx, y0 + float(m[0]) * escala), marrom, 2.0)
	for k in [1, 2]:
		var y: float = y0 + float(ys[k]) * escala
		_previa.draw_line(Vector2(cx - float(ws[k]) * escala, y), Vector2(cx + float(ws[k]) * escala, y), marrom, 2.0)


func _escolher_linha(k: int) -> void:
	modo.you_line = k


func _atualizar_painel_mao() -> void:
	_rotulo_mao.text = "Sua pipa está na mão · estoque: %d\n%s: %s · linha %s: %s" % [int(modo.players[0]["stock"]),
		FreeMode.PIPAS[modo.you_kite], FreeMode.PIPAS_INFO[modo.you_kite], FreeMode.LINHAS[modo.you_line], FreeMode.LINHAS_INFO[modo.you_line]]
	for k in _botoes_pipa.size():
		(_botoes_pipa[k] as Button).modulate = Color(1.0, 0.85, 0.2) if k == modo.you_kite else Color(1, 1, 1, 0.7)
	_botao_desenho.text = "Pipa: %s  (toque para trocar)" % String(Estilos.ESTILOS[modo.you_style]["nome"])
	if _previa_estilo != modo.you_style:
		_previa_estilo = modo.you_style
		_previa.queue_redraw()
	for k in _botoes_linha.size():
		(_botoes_linha[k] as Button).modulate = Color(1.0, 0.85, 0.2) if k == modo.you_line else Color(1, 1, 1, 0.7)


func _colocar_no_alto() -> void:
	if not modo.you_on_hand:
		return
	modo.launch_you()
	_dedos.clear()
	_embalo = 0.0
	_painel_mao.visible = false
