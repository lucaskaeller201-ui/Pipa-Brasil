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
const Boneco := preload("res://game/world/boneco.gd")
const Pessoa := preload("res://game/world/pessoa.gd")
const PELES := [Color(0.55, 0.36, 0.24), Color(0.85, 0.64, 0.48), Color(0.4, 0.26, 0.18), Color(0.72, 0.5, 0.35)]
const BERMUDAS := [Color(0.15, 0.25, 0.55), Color(0.2, 0.2, 0.22), Color(0.5, 0.42, 0.3), Color(0.1, 0.45, 0.25)]
const KiteView := preload("res://game/views/kite_view.gd")
const Estilos := preload("res://game/views/estilos_pipa.gd")
const LinesView := preload("res://game/views/lines_view.gd")
const MaosView := preload("res://game/views/maos_view.gd")
const Visual := preload("res://game/ui/visual.gd")
const BotaoRedondo := preload("res://game/ui/botao_redondo.gd")
const BotaoCapsula := preload("res://game/ui/botao_capsula.gd")
const Logo := preload("res://game/ui/logo.gd")

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
const TOQUE_MAX_S := 0.35    ## D-080: toque um pouco mais demorado ainda vale (era 0,25 s)
const TOQUE_MAX_PX := 32.0   ## D-080: o dedo pode escorregar um pouco no toque rápido (era 18)
const CORES := [Color(0.97, 0.97, 0.97), Color(1.0, 0.82, 0.25), Color(0.45, 0.85, 1.0),
	Color(0.6, 1.0, 0.5), Color(1.0, 0.55, 0.8), Color(0.85, 0.7, 1.0), Color(1.0, 0.6, 0.3), Color(0.7, 0.7, 0.7)]

var modo: FreeMode

var _semente := 1
var _automatico := false
var _primeira_pessoa := true
var _camera: Camera3D
var _maos: Node3D               # D-089: as duas mãos em primeira pessoa
var _vitrine_maos := false
var _placar_painel: PanelContainer   # D-094: placar completo (abre tocando no placar compacto)
var _botao_placar: Button
var _painel_pausa: PanelContainer
var _botao_alto: Button
var _banner_ini := 0.0
var _largada_arg := false
var _guardar_arg := 0       ## D-106: captura: 1 põe uma aparada na linha, 2 recolhe, 3 feito
var _linhas: MeshInstance3D
var _vistas := {}               # Flyer -> KiteView
var _estilo_de := {}            # Flyer -> estilo (desenho e fitinhas)
var _quadros_medidos := 0
var _boneco_antigo := false   ## D-099: --boneco-antigo volta ao boneco feito por código
var _corpos: Array = []         # boneco de cada participante

# gestos
var _dedos := {}                # índice -> {"ini": Vector2, "t0": float, "ult": Vector2}
var _dy_quadro := 0.0           # pixels deslizados neste quadro (+ = para baixo)
var _velocidade_mao := 0.0      # m/s (+ = puxando)
var _puxada := Vector3.ZERO     # D-104: (média do dedo, puxada alisada, tempo sem puxar)
var _giro_carretilha := 0.0
var _embalo := 0.0              # m/s de linha ainda saindo pelo embalo da carretilha
var _toque_ate := -1.0          # até quando a mão recolhe a folga do desbico
var _ultimo_lado := 1.0         # lado do último tenteio
var _ultimo_toque := -99.0      # instante do último toque (s)
var _ultimo_duplo := false      # o último toque fechou um toque duplo
var _duplo_t := -99.0           # instante do último toque duplo (s)
var _puxao_ate := -1.0          # até quando o puxão também recolhe linha pela mão
var _puxoes := 0
var _olhar_yaw := 0.0     ## D-077: graus, para onde a câmera olha com a pipa na mão
var _olhar_pitch := 18.0  ## graus acima do horizonte                # D-070: quantos puxões (segurar a tela) o jogador deu
var _dir_volta := 0.0           # sentido em que os toques duplos estão virando
var _sentido_antes := 1.0       # lado do bico antes do último toque simples
var _penultimo_toque := -99.0   # instante do toque antes do último (s)
const BICO_DE_LADO_DEG := 20.0  ## o duplo só vira a pipa com o bico já para o lado (D-059)
var _sentido := -1.0            # sentido do giro do último tenteio (+1/-1)
## Tenteio (D-049, D-050): cada toque balança o bico ~30° para um lado e o
## próximo para o outro, em volta da direção em que a pipa estava (tocar não
## faz rodar). Toque DUPLO (dois toques bem juntos): a direção anda 30° para
## o lado do toque — de 30 em 30 o bico vai para o lado, para baixo, ou dá a
## volta (12 duplos = 360°).
const PUXAO_LINHA_S := 0.25      ## s em que o puxão recolhe linha no máximo da mão (~1,5 m)
const PUXAO_SEGURAR_S := 1.0     ## D-070: segurar o dedo parado 1 s = puxão (tranco forte)
const TOQUE_DUPLO_S := 0.28     ## s: o mais separado que os dois toques do duplo podem estar (D-073, D-076)
const RITMO_DUPLO := 2.0        ## o intervalo antes do par tem que ser 2× maior (D-076: tentear num ritmo irregular não vira duplo)      ## s entre os dois toques do toque duplo
const VOLTA_SEGUE_S := 1.5      ## s: outro duplo logo depois continua virando para o mesmo lado (D-052)
@export var graus_por_toque := 45.0   ## quanto cada toque duplo vira a direção (D-074: medido no vídeo)
@export var balanco_tenteio := 30.0   ## quanto o bico balança para cada lado no tenteio (D-074)

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
# Página inicial (D-063): mapa, hora do dia e JOGAR, com a cidade ao vivo atrás.
var _lobby: Control
var _no_lobby := false
var _mapa := "bairro"
var _hora := "por_do_sol"
var _cenario: Node3D
var _botao_mapa: Button
var _botao_hora: Button
var _botao_graficos: Button
## D-066: qualidade dos gráficos (ULTRA por padrão).
const GRAFICOS := ["ultra", "alto", "leve"]
const NOMES_GRAFICOS := {"ultra": "ULTRA", "alto": "Alto", "leve": "Leve (celular fraco)"}
var _graficos := "ultra"
var _titulo_pipa: Control
const ARQUIVO_PREFERENCIAS := "user://preferencias.json"
var _mapa_arg := ""
var _hora_arg := ""
var _inicio_arg := false
var _escolha_arg := false
var _cantos: Control
var _inicio_jogo := 0.0
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
		elif arg.begins_with("--mapa="):
			_mapa_arg = arg.trim_prefix("--mapa=")
		elif arg.begins_with("--hora="):
			_hora_arg = arg.trim_prefix("--hora=")
		elif arg == "--inicio":
			_inicio_arg = true
		elif arg == "--escolha":
			_escolha_arg = true
		elif arg == "--boneco-antigo":
			_boneco_antigo = true
		elif arg == "--largada":
			_largada_arg = true    # D-089: captura da largada pelos olhos
		elif arg == "--guardar":
			_guardar_arg = 1       # D-106: captura da animação de guardar
		elif arg == "--vitrine-maos":
			_vitrine_maos = true   # D-089: captura das mãos em cada movimento
	ThemeDB.fallback_font = Visual.fonte(600)   # D-094: Baloo 2 em toda a interface
	if _largada_arg:
		_automatico = false   # a captura passa --auto; a largada é sua, pelos olhos
	_conferir_versao_nova()
	modo = FreeMode.new(BOTS, _semente, _automatico)
	# D-082: no jogo, 2 subpassos por passo (era 4): a física custava quase um
	# segundo de processador por segundo de jogo e o celular travava
	# D-086: 60 passos × 3 subpassos (1/180 s) + 4 passadas extras na linha e
	# vento/pares por passo: linha como na física de referência (sem barriga
	# nem "V") e mais barato que a de 0.30.3 (medido em test_barriga.gd)
	modo.world.substeps = 3
	modo.world.leve = true
	modo.world.medir = true   # D-086: detalhe do tempo no canto da tela
	modo.rabiola_bots = 12    # D-083: rabiola dos bots com metade dos pontos (são vistos de longe)
	modo.passadas_extras = 4  # D-086: linha firme como na referência (sem barriga nem "V")
	for p in modo.players:
		if p["flyer"] != null:
			(p["flyer"] as Flyer).extra_sweeps = 4
	if not _automatico:
		modo.bots_para_a_mao()   # D-079: os bots também colocam a pipa no alto
	_carregar_estatisticas()
	_aplicar_giro()
	_carregar_preferencias()
	if Bairro.MAPAS.has(_mapa_arg):
		_mapa = _mapa_arg
	if Ambiente.HORAS.has(_hora_arg):
		_hora = _hora_arg
	_no_lobby = (not _automatico or _inicio_arg) and not _largada_arg
	_aplicar_graficos()
	_montar_cenario()
	for i in modo.players.size():
		# D-099: personagens Rocketbox quando estão no jogo; senão o Boneco
		var corpo: Node3D = Pessoa.new() if Pessoa.disponivel() and not _boneco_antigo else Boneco.new()
		add_child(corpo)
		if corpo.has_method("construir_pessoa"):
			# D-104: sem o boné feito por código (não encaixava na cabeça)
			corpo.call("construir_pessoa", i, false, CORES[(i + 2) % CORES.size()].darkened(0.2))
		else:
			corpo.call("construir", PELES[i % PELES.size()], CORES[i % CORES.size()].darkened(0.15), BERMUDAS[i % BERMUDAS.size()], i % 3 != 2)
		if i > 0:
			# D-083: os bonecos dos bots não fazem sombra (cada um tem ~45 peças
			# e cada faixa de sombra desenharia todas de novo)
			for m in corpo.find_children("*", "MeshInstance3D", true, false):
				(m as MeshInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		# D-073: no lugar do pipeiro da física (antes ficava 25 cm atrás e o
		# braço não alcançava a mão: parecia que a linha soltava da mão)
		corpo.position = modo.players[i]["base"] as Vector3
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
	# D-089: mãos em primeira pessoa, presas à câmera
	_maos = MaosView.new()
	_maos.name = "Maos"
	_camera.add_child(_maos)
	_maos.call("preparar", 0.45)
	if not _automatico:
		modo.put_you_on_hand()
	_criar_interface()
	_posicionar_camera(true)
	if _escolha_arg:
		_abrir_pipas()   # captura da tela de escolha


## Céu, chão, casas e enfeites do mapa e da hora escolhidos (D-063).
func _montar_cenario() -> void:
	if _cenario != null:
		remove_child(_cenario)
		_cenario.queue_free()
	_cenario = Node3D.new()
	_cenario.name = "Cenario"
	add_child(_cenario)
	move_child(_cenario, 0)
	Ambiente.criar(_cenario, _hora, _mapa)
	Bairro.criar(_cenario, modo.players.size(), 7, _mapa)
	modo.world.obstacles = Bairro.obstaculos   # D-079: a linha e a pipa não atravessam


## D-066: suavização das bordas (antisserrilhado), sombras nítidas e
## texturas nítidas de longe. É isso que tira o "pixelado"/serrilhado.
func _aplicar_graficos() -> void:
	Bairro.qualidade = _graficos   # D-100: quantas árvores e detalhes no cenário
	var vp := get_viewport()
	if vp == null:
		return
	# D-082: no navegador do celular a tela tem 3× mais pontos (iPhone): o 3D
	# é desenhado numa resolução menor e ampliado — quase não se nota e pesa
	# bem menos para a placa de vídeo.
	var celular := OS.has_feature("web_ios") or OS.has_feature("web_android") or OS.has_feature("mobile")
	# D-083: sombra do sol mais simples no celular (2 faixas, até 70 m; no
	# Leve, 1 faixa): cada faixa desenha a cena inteira de novo
	Ambiente.sombra_faixas = 4 if not celular else (2 if _graficos != "leve" else 1)
	if celular:
		match _graficos:
			"ultra":
				vp.msaa_3d = Viewport.MSAA_2X
				vp.screen_space_aa = Viewport.SCREEN_SPACE_AA_DISABLED
				vp.scaling_3d_scale = 0.75
				vp.anisotropic_filtering_level = Viewport.ANISOTROPY_4X
				RenderingServer.directional_shadow_atlas_set_size(2048, true)
				RenderingServer.directional_soft_shadow_filter_set_quality(RenderingServer.SHADOW_QUALITY_SOFT_LOW)
			"alto":
				vp.msaa_3d = Viewport.MSAA_DISABLED
				vp.screen_space_aa = Viewport.SCREEN_SPACE_AA_FXAA
				vp.scaling_3d_scale = 0.6
				vp.anisotropic_filtering_level = Viewport.ANISOTROPY_2X
				RenderingServer.directional_shadow_atlas_set_size(2048, true)
				RenderingServer.directional_soft_shadow_filter_set_quality(RenderingServer.SHADOW_QUALITY_HARD)
			_:
				vp.msaa_3d = Viewport.MSAA_DISABLED
				vp.screen_space_aa = Viewport.SCREEN_SPACE_AA_DISABLED
				vp.scaling_3d_scale = 0.45
				vp.anisotropic_filtering_level = Viewport.ANISOTROPY_DISABLED
				RenderingServer.directional_shadow_atlas_set_size(1024, true)
				RenderingServer.directional_soft_shadow_filter_set_quality(RenderingServer.SHADOW_QUALITY_HARD)
		return
	match _graficos:
		"ultra":
			vp.msaa_3d = Viewport.MSAA_4X
			vp.screen_space_aa = Viewport.SCREEN_SPACE_AA_FXAA
			vp.scaling_3d_scale = 1.0
			vp.anisotropic_filtering_level = Viewport.ANISOTROPY_16X
			RenderingServer.directional_shadow_atlas_set_size(4096, true)
			RenderingServer.directional_soft_shadow_filter_set_quality(RenderingServer.SHADOW_QUALITY_SOFT_HIGH)
		"alto":
			vp.msaa_3d = Viewport.MSAA_2X
			vp.screen_space_aa = Viewport.SCREEN_SPACE_AA_DISABLED
			vp.scaling_3d_scale = 1.0
			vp.anisotropic_filtering_level = Viewport.ANISOTROPY_4X
			RenderingServer.directional_shadow_atlas_set_size(2048, true)
			RenderingServer.directional_soft_shadow_filter_set_quality(RenderingServer.SHADOW_QUALITY_SOFT_LOW)
		_:
			vp.msaa_3d = Viewport.MSAA_DISABLED
			vp.screen_space_aa = Viewport.SCREEN_SPACE_AA_DISABLED
			vp.scaling_3d_scale = 0.8
			vp.anisotropic_filtering_level = Viewport.ANISOTROPY_DISABLED
			RenderingServer.directional_shadow_atlas_set_size(1024, true)
			RenderingServer.directional_soft_shadow_filter_set_quality(RenderingServer.SHADOW_QUALITY_HARD)


func _trocar_graficos() -> void:
	_graficos = String(GRAFICOS[(GRAFICOS.find(_graficos) + 1) % GRAFICOS.size()])
	_aplicar_graficos()
	_montar_cenario()   # a sombra do sol muda com a qualidade (D-083)
	_salvar_preferencias()
	_atualizar_lobby()


func _carregar_preferencias() -> void:
	if not FileAccess.file_exists(ARQUIVO_PREFERENCIAS):
		return
	var f := FileAccess.open(ARQUIVO_PREFERENCIAS, FileAccess.READ)
	if f == null:
		return
	var dados = JSON.parse_string(f.get_as_text())
	if dados is Dictionary:
		if Bairro.MAPAS.has(String((dados as Dictionary).get("mapa", ""))):
			_mapa = String(dados["mapa"])
		if Ambiente.HORAS.has(String((dados as Dictionary).get("hora", ""))):
			_hora = String(dados["hora"])
		if GRAFICOS.has(String((dados as Dictionary).get("graficos", ""))):
			_graficos = String(dados["graficos"])


func _salvar_preferencias() -> void:
	var f := FileAccess.open(ARQUIVO_PREFERENCIAS, FileAccess.WRITE)
	if f != null:
		f.store_string(JSON.stringify({"mapa": _mapa, "hora": _hora, "graficos": _graficos}))


## Avança o jogo (também usado pelos testes).
func avancar(segundos: float) -> void:
	for i in roundi(segundos * Engine.physics_ticks_per_second):
		_physics_process(1.0 / Engine.physics_ticks_per_second)


func _physics_process(delta: float) -> void:
	var eu := modo.you()
	if _lanc_fase > 0:
		_largada_passo(delta)   # a largada comanda; os dedos esperam
	elif _guardar_ativo() and eu != null and not eu.cut and not _automatico:
		eu.input.clear()   # D-107: guardando a aparada, segura a linha parada
		_puxada = Vector3.ZERO
	elif not _automatico and eu != null and not eu.cut:
		_ler_comandos(eu, delta)
	var t0 := Time.get_ticks_usec()
	modo.update(delta)
	_medir_tempo("passo", t0)
	_passos += 1
	for msg in modo.take_messages():
		_avisar(msg)


const PUXADA_MEDIA := 0.08      ## s: janela da média do dedo (os toques chegam aos pulos)
const PUXADA_QUEDA := 8.0       ## m/s²: quanto a puxada perde por segundo entre braçadas
const PUXADA_PAUSA := 0.15      ## s sem o dedo puxar: parou de abraçar, a puxada para na hora (D-106)


## D-104: puxada alisada. estado = (média do dedo, puxada, tempo sem puxar).
## A média junta os toques que chegam fora do ritmo dos quadros; na volta do
## dedo para a próxima braçada (menos de PUXADA_PAUSA) a puxada segue no
## embalo. D-106: parou de abraçar (dedo parado ou fora da tela por mais que
## isso), para na hora. Mandar linha corta na hora.
static func suavizar_puxada(estado: Vector3, dedo: float, delta: float) -> Vector3:
	if dedo < -0.3:
		return Vector3.ZERO
	var sem := 0.0 if dedo > 0.3 else estado.z + delta
	if sem > PUXADA_PAUSA:
		return Vector3(0.0, 0.0, sem)
	var media := lerpf(estado.x, maxf(dedo, 0.0), 1.0 - exp(-delta / PUXADA_MEDIA))
	var puxada := media if media >= estado.y else maxf(media, estado.y - PUXADA_QUEDA * delta)
	if puxada < 0.05:
		puxada = 0.0
	return Vector3(media, puxada, sem)


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
	if modo.world.time < _puxao_ate:
		v = Pilot.HAUL_MAX_SPEED   # puxão: o tranco recolhe linha no máximo
		e.haul_speed = v
		return
	e.haul_speed = clampf(v, -DAR_LINHA_MAX, forca_puxada)


var _versao: Label
var _fps_t := 0.0
## D-086: onde vai o tempo, por pedaço (µs somados desde o último relatório)
var _tempos := {}
var _passos := 0
var _quadros := 0


func _medir_tempo(nome: String, t0: int) -> int:
	var t := Time.get_ticks_usec()
	_tempos[nome] = int(_tempos.get(nome, 0)) + (t - t0)
	return t


## D-084: o app da tela de início (PWA) guarda o jogo no celular e às vezes
## abre a versão velha. No navegador, o jogo pergunta ao site qual é a versão
## atual (versao.txt, sem cache); se for outra, apaga o que está guardado e
## recarrega sozinho (uma vez por sessão, para não ficar em laço).
func _conferir_versao_nova() -> void:
	if not OS.has_feature("web"):
		return
	var minha := String(ProjectSettings.get_setting("application/config/version", ""))
	var js := """
(function(minha){
  try {
    if (sessionStorage.getItem('pipa_atualizou') === minha) return;
    fetch('versao.txt?t=' + Date.now(), {cache: 'no-store'}).then(function(r){ return r.ok ? r.text() : ''; }).then(function(t){
      t = (t || '').trim();
      if (!t || t === minha) return;
      sessionStorage.setItem('pipa_atualizou', minha);
      var limpar = [];
      if (window.caches) limpar.push(caches.keys().then(function(ks){ return Promise.all(ks.map(function(k){ return caches.delete(k); })); }));
      if (navigator.serviceWorker) limpar.push(navigator.serviceWorker.getRegistrations().then(function(rs){ return Promise.all(rs.map(function(r){ return r.unregister(); })); }));
      Promise.all(limpar).then(function(){ location.reload(); });
    }).catch(function(){});
  } catch (e) {}
})(%s);
""" % JSON.stringify(minha)
	JavaScriptBridge.eval(js, true)


func _process(delta: float) -> void:
	# D-103: custo de desenho (chamadas, triângulos, objetos) para comparar
	# versões nas capturas do CI (o FPS de lá não vale: não tem placa de vídeo)
	_quadros_medidos += 1
	if _automatico and _quadros_medidos % 100 == 0 and _quadros_medidos <= 300:
		print("DESENHO quadro=%d chamadas=%d triangulos=%d objetos=%d memoria_video_mb=%.0f" % [_quadros_medidos,
			RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME),
			RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_PRIMITIVES_IN_FRAME),
			RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_OBJECTS_IN_FRAME),
			RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_VIDEO_MEM_USED) / 1048576.0])
	# D-082: quadros por segundo ao lado da versão (para ver se está travando)
	_fps_t += delta
	if _versao != null and _fps_t > 0.5:
		_fps_t = 0.0
		# D-083: e onde vai o tempo de cada quadro, para achar o que trava
		var fis := Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS) * 1000.0
		var logica := Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0
		var des := int(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME))
		_versao.text = "PIPA BRASIL %s · build %s · %d fps · física %.1f ms · lógica %.1f ms · %d desenhos" % [ProjectSettings.get_setting("application/config/version", "?"), BuildInfo.COMMIT, Engine.get_frames_per_second(), fis, logica, des]
		# D-086: segunda linha com o detalhe (para o Lucas mandar no print)
		var q := maxf(_quadros, 1.0)
		var ps := maxf(_passos, 1.0)
		var det := "passos/quadro %.1f · passo %.1f ms" % [_passos / q, int(_tempos.get("passo", 0)) / ps / 1000.0]
		for k in modo.world.perfil:
			det += " · %s %.1f" % [String(k).get_slice(" ", 0), int(modo.world.perfil[k]) / ps / 1000.0]
		for k in ["linhas", "bonecos", "vistas", "câmera", "textos"]:
			det += " · %s %.1f" % [k, int(_tempos.get(k, 0)) / q / 1000.0]
		_versao.text += "\n" + det
		_tempos.clear()
		modo.world.perfil.clear()
		_passos = 0
		_quadros = 0
	_quadros += 1
	if _guardar_arg == 1 and modo.you() != null and modo.world.time > 2.5:
		# captura: uma avoada enroscada na sua linha (como em test_modo_livre)
		var eu_g: Flyer = modo.you()
		var av_g := modo.world.add_flyer(KiteDefinition.pipa_rio(), eu_g.kite.position + Vector3(2.0, -1.0, 3.0), 10.0)
		av_g.cut = true
		av_g.tag = -1
		av_g.caught_by = eu_g
		modo.world.combat.links.append({"avoada": av_g, "catcher": eu_g, "chain": av_g.line if av_g.line != null else eu_g.line, "idx": 1, "cchain": eu_g.line, "m": 1.0, "captured": false, "forca": 1.0})
		_guardar_arg = 2
	elif _guardar_arg == 2 and modo.world.time > 3.0:
		modo._recolher()
		_guardar_arg = 3
	if _largada_arg and _lanc_fase == 0 and modo.you_on_hand and modo.world.time > 1.0:
		_colocar_no_alto_animado()   # captura: coloca no alto sozinho
	var tq := Time.get_ticks_usec()
	_ver_toque_pendente()
	_animar_bonecos(delta)
	tq = _medir_tempo("bonecos", tq)
	if _no_lobby and _titulo_pipa != null:
		_titulo_pipa.queue_redraw()
	# Velocidade da mão a partir do deslizar deste quadro.
	var altura := maxf(1.0, get_viewport().get_visible_rect().size.y)
	var alvo := (_dy_quadro / altura) * LINHA_POR_TELA / maxf(delta, 1e-3)
	alvo = alvo if not _dedos.is_empty() else 0.0
	# D-104: puxada lisa — o dedo chega aos pulos (toques do iPhone fora do
	# ritmo dos quadros, e o dedo sobe entre uma braçada e outra); a mão
	# segue puxando no embalo, sem trancos na pipa.
	_puxada = suavizar_puxada(_puxada, alvo, delta)
	_velocidade_mao = alvo if alvo < -0.3 else _puxada.y
	_dy_quadro = 0.0

	tq = Time.get_ticks_usec()
	_atualizar_vistas()
	_guardar_passo(delta)
	tq = _medir_tempo("vistas", tq)
	_posicionar_camera(false)
	_atualizar_maos(modo.you(), delta)
	tq = _medir_tempo("câmera", tq)
	_linhas.set("camera_position", _camera.global_position)
	_linhas.set("min_width_per_meter", 2.0 * 2.0 * tan(deg_to_rad(_camera.fov * 0.5)) / altura)
	_linhas.call("limpar")
	for f in modo.world.flyers:
		var fl: Flyer = f
		if _tomadas.has(fl):
			continue   # D-106: está sendo guardada (a animação desenha o nó)
		var cor: Color = CORES[fl.tag] if fl.tag >= 0 else Color(0.85, 0.85, 0.85)
		if fl.tag == 0:
			cor = Estilos.LINHAS[modo.you_line]["cor"]   # a linha que você escolheu
		if fl.line != null:
			_linhas.call("desenhar_cadeia", _linha_da_mao(fl.line.pos) if fl.tag == 0 else fl.line.pos, cor.lerp(Color(1.0, 0.1, 0.05), clampf(fl.line.max_wear() / fl.line.strength, 0.0, 1.0)), 0.0012, 1.0, 4 if fl.tag == 0 else 2)
		if fl.trailing_line != null:
			_linhas.call("desenhar_cadeia", fl.trailing_line.pos, cor, 0.0012)
		if fl.tail != null:
			# Rabiola: o barbante fininho e as fitinhas coloridas (D-043).
			var estilo: Dictionary = _estilo_de.get(fl, Estilos.ESTILOS[0])
			_linhas.call("desenhar_cadeia", fl.tail.pos, Color(0.9, 0.9, 0.9, 0.8), 0.0008, 0.5, 2 if fl.tag == 0 else 1)
			_linhas.call("desenhar_fitinhas", fl.tail.pos, estilo["fitas"], Time.get_ticks_msec() / 1000.0)
	if _primeira_pessoa and _maos != null and _maos.visible and _pipa_mao != null:
		# D-089: na largada, a linha vai da mão até o cabresto da pipa na mão
		var tp := _pipa_mao.global_transform
		var cabresto := tp * modo.kite_for(modo.you_style).tow_point
		var pts := PackedVector3Array([_camera.global_transform * (_maos.call("ponto_mao", "d") as Vector3)])
		# D-091: o nó no cabresto — as voltas da linha vão aparecendo enquanto amarra
		var voltas := 3.0 if _lanc_fase != 1 else clampf(_lanc_t / LARGADA_AMARRAR, 0.0, 1.0) * 3.0
		var n := int(voltas * 10.0)
		for k in n:
			var a := float(k) / 10.0 * TAU
			pts.append(cabresto + tp.basis * Vector3(cos(a) * 0.009, sin(a) * 0.009, -0.004 + 0.003 * float(k) / 10.0))
		pts.append(cabresto)
		_linhas.call("desenhar_cadeia", pts, Estilos.LINHAS[modo.you_line]["cor"], 0.0012, 1.0, 1)
	if _guardar_ativo() and int(_guardando["fase"]) <= 2 and is_instance_valid(_guardando["v"]):
		# D-106: as voltas da linha (ou da rabiola) no cabresto vão sumindo
		var gv: Node3D = _guardando["v"]
		var tp2 := gv.global_transform
		var cab2 := tp2 * (_guardando["def"] as KiteDefinition).tow_point
		var resta := 1.0 if int(_guardando["fase"]) == 1 else 1.0 - clampf(float(_guardando["t"]) / GUARDAR_TIRAR, 0.0, 1.0)
		var pts2 := PackedVector3Array()
		var n2 := int(30.0 * resta)
		for k in n2:
			var a2 := float(k) / 10.0 * TAU
			pts2.append(cab2 + tp2.basis * Vector3(cos(a2) * 0.01, sin(a2) * 0.01, -0.004 + 0.003 * float(k) / 10.0))
		if n2 > 1:
			# a ponta solta pendurada
			pts2.append(pts2[pts2.size() - 1] + Vector3(0.0, -0.25 * resta, 0.0))
			var cor2: Color = Estilos.LINHAS[modo.you_line]["cor"] if bool(_guardando["sua"]) else (Color(0.95, 0.95, 0.95) if bool(_guardando["rabiola"]) else Color(0.85, 0.85, 0.85))
			_linhas.call("desenhar_cadeia", pts2, cor2, 0.003 if bool(_guardando["rabiola"]) else 0.0012, 1.0, 1)
	tq = _medir_tempo("linhas", tq)
	var eu := modo.you()
	_tratar_acontecimentos()
	var agora_real := Time.get_ticks_msec() / 1000.0
	if Engine.time_scale < 1.0 and agora_real > _lenta_ate:
		Engine.time_scale = 1.0
	_banner.visible = agora_real < _banner_ate
	if eu != null:
		_giro_carretilha += eu.input.haul_speed * delta * 3.0
	_painel_mao.visible = modo.you_on_hand and not _no_lobby and not _selecao.visible and _lanc_fase == 0 and not _guardar_ativo() and _guardar_fila.is_empty()
	if modo.you_on_hand:
		_atualizar_painel_mao()
	tq = Time.get_ticks_usec()
	_atualizar_textos(eu)
	_sobreposicao.queue_redraw()
	_medir_tempo("textos", tq)


func _atualizar_vistas() -> void:
	for g in modo.take_guardar():
		_tomar(g[0], bool(g[1]), bool(g[2]))
	var vivos := {}
	for f in modo.world.flyers:
		var fl: Flyer = f
		vivos[fl] = true
		if _tomadas.has(fl):
			continue
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
			if not _tomadas.has(fl):
				(_vistas[fl] as Node).queue_free()
			_vistas.erase(fl)
			_estilo_de.erase(fl)
	for fl in _tomadas.keys():
		if not vivos.has(fl):
			_tomadas.erase(fl)


## D-106: a vista desta pipa passa para a animação de guardar.
func _tomar(fl: Flyer, rabiola: bool, sua: bool) -> void:
	if _tomadas.has(fl) or not _vistas.has(fl):
		return
	var v: Node3D = _vistas[fl]
	_tomadas[fl] = true
	_guardar_fila.append({"v": v, "def": fl.kite.definition, "rabiola": rabiola, "sua": sua, "origem": v.global_transform})


## Onde a pipa fica segura na frente do pipeiro (como na largada).
func _guardar_segura(na_mao: bool) -> Transform3D:
	var base: Vector3 = modo.players[0]["base"]
	var b := Basis.IDENTITY   # de frente para o vento (-Z), como na largada
	var pos := base + b * (Vector3(0.0, 1.15, -0.45) if na_mao else Vector3(-0.45, 1.05, -0.35))
	return Transform3D(b * Basis(Vector3.RIGHT, -0.55), pos)


## Lugar da k-ésima pipa guardada: deitada no canto da sua laje.
func _guardar_canto(k: int) -> Transform3D:
	var base: Vector3 = modo.players[0]["base"]
	var giro := Basis(Vector3.UP, 0.35 * float(k % 5) - 0.6)
	var pos := base + Vector3(3.0 + 0.06 * float(k % 3), 0.04 + 0.03 * float(k), -2.3 + 0.05 * float(k % 2))
	return Transform3D(giro * Basis(Vector3.RIGHT, -PI * 0.5), pos)


func _guardar_ativo() -> bool:
	return not _guardando.is_empty()


func _guardar_passo(delta: float) -> void:
	if _guardando.is_empty():
		if _guardar_fila.is_empty():
			return
		_guardando = _guardar_fila.pop_front()
		_guardando["t"] = 0.0
		_guardando["fase"] = 1
		# com a sua pipa na mão, o pipeiro usa as duas mãos (animação inteira)
		# D-107: sempre com as mãos — com a sua pipa no alto, ele para, segura
		# a linha parada e guarda a aparada (os comandos esperam)
		_guardando["na_mao"] = true
		var quem := "a sua pipa" if bool(_guardando["sua"]) else "a aparada"
		_avisar("Pegando %s…" % quem)
	var g := _guardando
	var v: Node3D = g["v"]
	if not is_instance_valid(v):
		_guardando = {}
		return
	g["t"] = float(g["t"]) + delta
	var t: float = g["t"]
	var segura := _guardar_segura(bool(g["na_mao"]))
	match int(g["fase"]):
		1:
			var k := smoothstep(0.0, 1.0, t / GUARDAR_CHEGAR)
			var o: Transform3D = g["origem"]
			v.global_transform = Transform3D(o.basis.orthonormalized().slerp(segura.basis, k), o.origin.lerp(segura.origin, k))
			if t >= GUARDAR_CHEGAR:
				g["fase"] = 2
				g["t"] = 0.0
				if bool(g["sua"]):
					_avisar("Desamarrando a linha do cabresto…")
				else:
					_avisar("Tirando a rabiola do aparo…" if bool(g["rabiola"]) else "Tirando a linha do aparo…")
		2:
			v.global_transform = segura
			v.rotate_object_local(Vector3.FORWARD, sin(t * 9.0) * 0.05)
			if t >= GUARDAR_TIRAR:
				g["fase"] = 3
				g["t"] = 0.0
				g["de"] = v.global_transform
				g["slot"] = _pilha.size()
				_avisar("Guardando no canto da laje…")
		3:
			var k := smoothstep(0.0, 1.0, t / GUARDAR_POR)
			var de: Transform3D = g["de"]
			var para := _guardar_canto(int(g["slot"]))
			var pos := de.origin.lerp(para.origin, k) + Vector3(0.0, 0.35 * sin(k * PI), 0.0)
			v.global_transform = Transform3D(de.basis.orthonormalized().slerp(para.basis, k), pos)
			if t >= GUARDAR_POR:
				v.global_transform = para
				_pilha.append(v)
				while _pilha.size() > PILHA_MAX:
					var velha: Node3D = _pilha.pop_front()
					if is_instance_valid(velha):
						velha.queue_free()
				_guardando = {}
				if _guardar_fila.is_empty():
					_avisar("Guardada no canto da laje! Estoque: %d" % int(modo.players[0]["stock"]))


## Onde a pipa da animação está agora (para a câmera, as mãos e o boneco).
func _guardar_ponto() -> Vector3:
	var v: Node3D = _guardando.get("v")
	return v.global_position if v != null and is_instance_valid(v) else (modo.players[0]["base"] as Vector3) + Vector3(0.0, 1.1, -0.5)


# ---------------- câmera ----------------

func _posicionar_camera(imediato: bool) -> void:
	if _no_lobby:
		# Página inicial: a câmera passeia devagar em volta das lajes.
		# D-095: atrás do pipeiro, na laje, olhando o morro (e o Cristo), com
		# um balanço lento — como na imagem de referência
		var t := Time.get_ticks_msec() / 1000.0
		var base_l: Vector3 = modo.players[0]["base"]
		_corpos[0].visible = true
		var olho2 := base_l + Vector3(1.6 + sin(t * 0.13) * 0.5, 2.1 + sin(t * 0.21) * 0.15, 3.9)
		var alvo_l := base_l + Vector3(-3.0 + sin(t * 0.09) * 2.0, 9.0, -60.0)
		_camera.global_transform = Transform3D(Basis.looking_at(alvo_l - olho2, Vector3.UP), olho2)
		_camera.fov = 60.0
		_camera.h_offset = 0.0
		_camera.v_offset = 0.0
		return
	var eu := modo.you()
	var base: Vector3 = modo.players[0]["base"]
	if (modo.you_on_hand or (_lanc_fase >= 1 and _lanc_fase <= 3) or _guardar_ativo()) and _primeira_pessoa:
		# D-089: primeira pessoa com a pipa na mão — pelos olhos do pipeiro.
		# Escolhendo: o dedo olha em volta. Na largada: olha a pipa nas mãos
		# (amarrando), anda até a beira (com o balanço do passo) e ergue.
		_corpos[0].visible = false
		var olhos_q := _olhos_largada()
		if imediato:
			_camera.global_transform = olhos_q
		else:
			_camera.global_transform = _camera.global_transform.interpolate_with(olhos_q, 0.3)
		_camera.fov = lerpf(_camera.fov, 66.0, 0.2)
		_camera.h_offset = 0.0
		_camera.v_offset = 0.0
		return
	if modo.you_on_hand:
		# D-077: pipa na mão — câmera atrás do pipeiro, olhando em volta (o
		# dedo gira); dá para ver as pipas no céu, as lajes e o morro.
		_corpos[0].visible = true
		var yaw := deg_to_rad(_olhar_yaw)
		var pit := deg_to_rad(_olhar_pitch)
		var frente := Vector3(-sin(yaw) * cos(pit), sin(pit), -cos(yaw) * cos(pit))
		var ombro := base + Vector3(0.0, 1.6, 0.0)
		var plano := Vector3(-sin(yaw), 0.0, -cos(yaw))
		var olho_m := ombro - plano * 4.0 + Vector3(0.0, 1.2, 0.0) + plano.cross(Vector3.UP) * 0.8
		var quer := Transform3D(Basis.looking_at(frente, Vector3.UP), olho_m)
		if imediato:
			_camera.global_transform = quer
		else:
			_camera.global_transform = _camera.global_transform.interpolate_with(quer, 0.35)
		_camera.fov = lerpf(_camera.fov, 62.0, 0.2)
		return
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
	# D-074: como no Pipa Combate, a pipa aparece maior e no meio da tela
	var fov := clampf(rad_to_deg(envergadura / maxf(dist, 1.0)) / 0.1, 12.0, 55.0)
	if not _primeira_pessoa:
		fov = 50.0
	var guinada := atan2(-alvo.x, -alvo.z)
	var elevacao := rad_to_deg(atan2(alvo.y, Vector2(alvo.x, alvo.z).length()))
	# A pipa fica um pouco acima do meio (acima dos textos de baixo). A câmera
	# também olha para baixo do horizonte: afundando a pipa, ela continua na
	# tela (D-059).
	var inclinacao := clampf(elevacao - fov * 0.06, -45.0, 75.0)
	var desejada := Transform3D(Basis.from_euler(Vector3(deg_to_rad(inclinacao), guinada, 0.0)), olho)
	if imediato:
		_camera.global_transform = desejada
		_camera.fov = fov
	else:
		# segue a pipa o tempo todo, com um atraso pequeno e suave (D-074)
		_camera.global_transform = _camera.global_transform.interpolate_with(desejada, 0.3)
		_camera.fov = lerpf(_camera.fov, fov, 0.08)
	# Tremor (corte): deslocamento pequeno da imagem, que some rápido.
	_camera.h_offset = randf_range(-1.0, 1.0) * _tremor * 0.02
	_camera.v_offset = randf_range(-1.0, 1.0) * _tremor * 0.02
	_tremor = maxf(0.0, _tremor - 0.06)


## D-089: os olhos do pipeiro com a pipa na mão (e na largada).
func _olhos_largada() -> Transform3D:
	var base: Vector3 = modo.players[0]["base"]
	if _guardar_ativo() and bool(_guardando["na_mao"]) and _lanc_fase == 0:
		# D-106: olha a pipa que está guardando (e o canto da laje no fim)
		var olho_g := base + Vector3(0.0, 1.62, 0.0)
		var mira_g := _guardar_ponto()
		if int(_guardando["fase"]) == 1:
			mira_g = mira_g.lerp(_guardar_segura(true).origin, 0.5)
		return Transform3D(Basis.looking_at(mira_g - olho_g + Vector3(0.0, 0.001, 0.0), Vector3.UP), olho_g)
	if _lanc_fase >= 1 and _lanc_fase <= 3:
		var pose := _pose_largada()
		var olho: Vector3 = (pose["corpo"] as Vector3) + Vector3(0.0, 1.62, 0.0)
		var pipa: Vector3 = pose["pipa"]
		var mira := pipa
		match _lanc_fase:
			2:
				# andando: balança com o passo e olha para a frente, a pipa embaixo
				olho.y += 0.025 * sin(_lanc_t * TAU * 1.8)
				olho.x += 0.012 * sin(_lanc_t * PI * 1.8)
				mira = pipa + Vector3(0.0, 0.25, -3.0)
			3:
				mira = pipa + Vector3(0.0, 1.2, -3.0)
		return Transform3D(Basis.looking_at(mira - olho, Vector3.UP), olho)
	var yaw := deg_to_rad(_olhar_yaw)
	var pit := deg_to_rad(_olhar_pitch)
	var frente := Vector3(-sin(yaw) * cos(pit), sin(pit), -cos(yaw) * cos(pit))
	var olho2 := base + Vector3(0.0, 1.62, 0.0)
	return Transform3D(Basis.looking_at(frente, Vector3.UP), olho2)


## D-089: atualiza as mãos com o que a física está fazendo (ou com a fase da largada).
func _atualizar_maos(eu: Flyer, delta: float) -> void:
	if _maos == null:
		return
	var mostrar := _primeira_pessoa and not _no_lobby and (modo.you_on_hand or _lanc_fase > 0 or (eu != null and not eu.cut))
	_maos.visible = mostrar
	if not mostrar:
		return
	var estado := {"modo": "voo"}
	if _vitrine_maos:
		# captura: parado, puxando, mandando, desbicando, amarrando, erguendo
		var t := modo.world.time
		estado = {"modo": "voo", "tensao": 6.0, "lado": 1.0}
		if t < 4.0:
			pass
		elif t < 8.0:
			estado["haul"] = 3.0
		elif t < 12.0:
			estado["haul"] = -3.0
		elif t < 16.0:
			estado["desbico"] = fmod(t - 12.0, 0.6)
			estado["lado"] = 1.0 if fmod(t, 1.2) < 0.6 else -1.0
		elif t < 19.0:
			estado = {"modo": "amarrar", "fase": (t - 16.0) / 3.0, "pipa": Vector3(0.0, -0.45, -0.55)}
		else:
			estado = {"modo": "erguer", "fase": (t - 19.0) / 3.0, "pipa": Vector3(0.0, -0.1 + (t - 19.0) * 0.12, -0.55)}
		_maos.call("atualizar", _camera, estado, delta)
		return
	if _lanc_fase >= 1 and _lanc_fase <= 3:
		var pose := _pose_largada()
		var duracao: float = [1.0, LARGADA_AMARRAR, LARGADA_ANDAR, LARGADA_ERGUER][_lanc_fase]
		var inv := _camera.global_transform.affine_inverse()
		estado = {"modo": ["", "amarrar", "andar", "erguer"][_lanc_fase],
			"fase": clampf(_lanc_t / duracao, 0.0, 1.0),
			"pipa": inv * (pose["pipa"] as Vector3)}
		if _pipa_mao != null:
			estado["pipa_t"] = inv * _pipa_mao.global_transform
			estado["corpo"] = inv.basis * Basis(Vector3.UP, _corpos[0].rotation.y)
			estado["cabresto"] = inv * (_pipa_mao.global_transform * modo.kite_for(modo.you_style).tow_point)
	elif _guardar_ativo() and bool(_guardando["na_mao"]):
		# D-106: pega a pipa, desfaz o nó e põe no canto
		var inv2 := _camera.global_transform.affine_inverse()
		var gv2: Node3D = _guardando["v"]
		var f2 := int(_guardando["fase"])
		var tt: float = _guardando["t"]
		var perto := inv2 * gv2.global_position
		if f2 == 2:
			estado = {"modo": "amarrar", "fase": 1.0 - clampf(tt / GUARDAR_TIRAR, 0.0, 1.0), "pipa": perto,
				"pipa_t": inv2 * gv2.global_transform, "corpo": inv2.basis * Basis(Vector3.UP, _corpos[0].rotation.y),
				"cabresto": inv2 * (gv2.global_transform * (_guardando["def"] as KiteDefinition).tow_point)}
		elif perto.length() < 1.1:
			# segurando pelos lados; no fim da fase 3 solta no chão
			var solta := clampf(tt / GUARDAR_POR, 0.0, 0.999) if f2 == 3 else 0.0
			estado = {"modo": "erguer" if f2 == 3 else "andar", "fase": solta, "pipa": perto}
		else:
			estado = {"modo": "mao"}
	elif modo.you_on_hand or eu == null:
		estado = {"modo": "mao"}
	else:
		estado["arm"] = eu.pilot.arm_offset
		estado["tensao"] = eu.tension
		estado["haul"] = eu.input.haul_speed
		estado["desbico"] = eu.tenteio_age
		estado["lado"] = _ultimo_lado
		estado["puxao"] = eu.pilot.is_pulling(modo.world.time)
		_maos.set("cor_linha", Estilos.LINHAS[modo.you_line]["cor"])
	_maos.call("atualizar", _camera, estado, delta)


## D-089: na 1ª pessoa, a sua linha sai da mão da frente (o começo dela, perto
## dos olhos, é trocado pelo ponto da tela onde a mão está; daí em diante é a
## linha da física, ponto por ponto).
func _linha_da_mao(pos: PackedVector3Array) -> PackedVector3Array:
	if _maos == null or not _maos.visible or not _primeira_pessoa or pos.size() < 3:
		return pos
	var inicio: Vector3 = _maos.call("ponto_linha_no_mundo", _camera, 1.5)
	var out := PackedVector3Array([inicio])
	var olho := _camera.global_position
	var y_mao := _camera.unproject_position(inicio).y
	var achou := false
	for i in range(1, pos.size()):
		# D-090: pula o começo da linha da física, que fica perto dos olhos e,
		# com a linha frouxa, abaixo da mão (saía da mão para baixo da tela e
		# voltava pelo meio). Junta onde a linha já aparece acima da mão.
		var perto := pos[i].distance_to(olho) < 4.0
		var abaixo := pos[i].distance_to(olho) < 25.0 and (_camera.is_position_behind(pos[i]) or _camera.unproject_position(pos[i]).y > y_mao)
		if not achou and (perto or abaixo) and i < pos.size() - 2:
			continue
		achou = true
		out.append(pos[i])
	return out


# ---------------- gestos ----------------

func _input(evento: InputEvent) -> void:
	if _selecao != null and _selecao.visible and _rolar_lista(evento):
		return
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
	var agora := Time.get_ticks_msec() / 1000.0
	if apertou:
		if _sobre_botao(posicao):
			return
		if _guardar_ativo():
			return   # D-107: guardando a pipa, os dedos esperam (uns 3 s)
		_dedos[indice] = {"ini": posicao, "t0": agora, "ult": posicao, "puxou": false}
		return
	if not _dedos.has(indice):
		return
	# D-080: o dedo sempre sai da lista ao soltar (antes, soltar em cima de um
	# botão deixava um "dedo fantasma": puxava linha ou dava puxão sozinho)
	var d: Dictionary = _dedos[indice]
	_dedos.erase(indice)
	if agora - float(d["t0"]) < TOQUE_MAX_S and posicao.distance_to(d["ini"]) < TOQUE_MAX_PX:
		_tentear()
		_marcar_toque(posicao, _ultimo_duplo)


## D-080: um círculo onde o dedo tocou: branco = tenteio, amarelo = toque
## duplo. Mostra na hora se o jogo entendeu o toque.
class MarcaToque extends Control:
	var vida := 0.35
	var cor := Color.WHITE
	func _process(delta: float) -> void:
		vida -= delta
		if vida <= 0.0:
			queue_free()
		queue_redraw()
	func _draw() -> void:
		var f := clampf(vida / 0.35, 0.0, 1.0)
		draw_arc(Vector2.ZERO, 18.0 + (1.0 - f) * 26.0, 0.0, TAU, 32, Color(cor.r, cor.g, cor.b, 0.85 * f), 4.0)


var _camada_marcas: CanvasLayer


func _marcar_toque(posicao: Vector2, duplo: bool) -> void:
	if _camada_marcas == null or _automatico:
		return
	var m := MarcaToque.new()
	m.position = posicao
	m.mouse_filter = Control.MOUSE_FILTER_IGNORE
	m.cor = Color(1.0, 0.85, 0.2) if duplo else Color.WHITE
	_camada_marcas.add_child(m)


func _arrasto(indice: int, posicao: Vector2, relativo: Vector2) -> void:
	if not _dedos.has(indice):
		return
	if modo.you_on_hand and not _no_lobby:
		# D-077: pipa na mão — arrastar o dedo gira a câmera e olha em volta
		_olhar_yaw -= relativo.x * 0.25
		# D-096: arrastar para cima olha para cima (era invertido)
		_olhar_pitch = clampf(_olhar_pitch - relativo.y * 0.2, -25.0, 75.0)
		(_dedos[indice] as Dictionary)["ult"] = posicao
		return
	_dy_quadro += relativo.y
	var d: Dictionary = _dedos[indice]
	d["ult"] = posicao
	if relativo.y > 0.0 and posicao.y - (d["ini"] as Vector2).y > PUXOU_PX:
		d["puxou"] = true   # este dedo é de puxar (enquanto estiver na tela)


## Tenteio pelo toque (D-041).
func _tentear() -> void:
	if _lanc_fase > 0:
		return
	var agora := Time.get_ticks_msec() / 1000.0
	if _eh_toque_duplo(agora):
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
	_penultimo_toque = _ultimo_toque
	_ultimo_toque = agora


## Toque duplo (D-070, D-073): na tela toda, com o bico em qualquer posição.
## O jeito do Lucas é "um toque... e dois rápidos": o par conta como duplo
## quando é bem mais junto que o intervalo antes dele (ritmo diferente), até
## 0,4 s — assim tentear num ritmo constante continua sendo tenteio, mesmo
## rápido. Logo depois de um duplo, outro par continua a volta.
func _eh_toque_duplo(agora: float) -> bool:
	if _ultimo_duplo:
		return false
	var junto := agora - _ultimo_toque
	if junto >= TOQUE_DUPLO_S:
		return false
	if agora - _duplo_t < VOLTA_SEGUE_S:
		return true
	var antes := _ultimo_toque - _penultimo_toque
	return antes >= RITMO_DUPLO * junto

## D-070: puxão — o dedo ficou parado na tela por PUXAO_SEGURAR_S, sem
## arrastar: a mão dá um tranco forte para trás (o mesmo puxão da física,
## Pilot.Impulse.PUXAO; a pipa responde conforme o estado em que está).
func _ver_toque_pendente() -> void:
	var agora := Time.get_ticks_msec() / 1000.0
	for k in _dedos:
		var d: Dictionary = _dedos[k]
		if d.get("puxao", false) or bool(d["puxou"]):
			continue
		if (d["ult"] as Vector2).distance_to(d["ini"]) > TOQUE_MAX_PX:
			continue
		if agora - float(d["t0"]) >= PUXAO_SEGURAR_S:
			d["puxao"] = true
			_puxao()


func _puxao() -> void:
	var eu := modo.you()
	if eu == null or eu.cut or eu.line == null:
		return
	eu.pilot.trigger(Pilot.Impulse.PUXAO, modo.world.time)
	_puxao_ate = modo.world.time + PUXAO_LINHA_S
	_puxoes += 1
	_avisar("PUXÃO!")


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

var _textos_t := 0.0


func _atualizar_textos(eu: Flyer) -> void:
	# D-085: trocar o texto de um rótulo refaz o desenho das letras (caro no
	# celular): o placar é refeito 4 vezes por segundo, e só se mudou
	_aviso.visible = Time.get_ticks_msec() / 1000.0 < _aviso_ate and not _no_lobby
	_dica.visible = modo.world.time - _inicio_jogo < 15.0 and not _no_lobby
	# na página inicial, só a cidade e os botões (D-063)
	_botao_placar.visible = not _no_lobby
	if _no_lobby:
		_placar_painel.visible = false
	_info.visible = not _no_lobby
	_sobreposicao.visible = not _no_lobby
	_cantos.visible = not _no_lobby
	_versao.visible = not _no_lobby
	var agora := Time.get_ticks_msec() / 1000.0
	if agora - _textos_t < 0.25 and not _automatico:
		return
	_textos_t = agora
	var linhas: Array[String] = []
	for p in modo.ranking():
		linhas.append("%s — %d %s · %d %s · estoque %d" % [p["name"], p["cuts"], "corte" if int(p["cuts"]) == 1 else "cortes", p["catches"], "aparada" if int(p["catches"]) == 1 else "aparadas", p["stock"]])
	var seq := int(modo.players[0]["streak"])
	if seq >= 2:
		linhas.append("Sequência: %d cortes · x%d%s" % [seq, _multiplicador(seq), "  · REI DA LAJE" if seq >= 3 else ""])
	linhas.append("Total salvo: %d cortes · %d aparadas · melhor sequência %d" % [_estatisticas["cortes"], _estatisticas["aparadas"], _estatisticas["melhor_sequencia"]])
	var novo := "\n".join(linhas)
	if _placar.text != novo:
		_placar.text = novo
	var p0: Dictionary = modo.players[0]
	if eu == null:
		_info.text = "Pipa na mão · estoque %d" % int(p0["stock"])
	elif eu.cut:
		_info.text = "Sua linha foi cortada…"
	else:
		var extra := "   ENROSCOU: puxe a linha toda para trazer!" if eu.holding > 0 else ""
		_info.text = "Linha %d m · altura %d m%s" % [roundi(eu.line_length()), roundi(eu.kite.position.y - (p0["base"] as Vector3).y), extra]


func _avisar(texto: String) -> void:
	_aviso.text = texto
	_aviso_ate = Time.get_ticks_msec() / 1000.0 + 3.5


## Desenha a carretilha, a seta do bico da sua pipa e os nomes/setas dos rivais.
func _desenhar_sobreposicao() -> void:
	var c := _sobreposicao
	var tela := c.get_viewport_rect().size
	var fonte := ThemeDB.fallback_font
	# Carretilha no canto de baixo à esquerda (gira com a linha) — só na 3ª
	# pessoa; na 1ª, as mãos mostram a linha (D-089).
	if not _primeira_pessoa:
		_desenhar_carretilha(c, tela)
	_desenhar_relo_e_vento(c, tela)
	_desenhar_resto_sobreposicao(c, tela, fonte)
	_desenhar_hud(c, tela)


func _desenhar_carretilha(c: Control, tela: Vector2) -> void:
	var centro := Vector2(110.0, tela.y - 110.0)
	c.draw_circle(centro, 86.0, Color(0.42, 0.25, 0.12, 0.92))
	c.draw_circle(centro, 70.0, Color(0.93, 0.92, 0.88, 0.95))
	c.draw_circle(centro, 22.0, Color(0.42, 0.25, 0.12, 1.0))
	for k in 4:
		var a := _giro_carretilha + k * PI / 2.0
		c.draw_line(centro + Vector2.from_angle(a) * 24.0, centro + Vector2.from_angle(a) * 68.0, Color(0.6, 0.55, 0.5, 0.8), 3.0)
	var cabo := centro + Vector2.from_angle(_giro_carretilha) * 58.0
	c.draw_circle(cabo, 11.0, Color(0.25, 0.15, 0.08))


func _desenhar_resto_sobreposicao(c: Control, tela: Vector2, fonte: Font) -> void:
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
			# D-094: nome numa pílula pequena com a cor do pipeiro (não cobre o céu)
			var w := Visual.largura(nome, 14, 700)
			var r := Rect2(s + Vector2(-w * 0.5 - 16.0, -44.0), Vector2(w + 30.0, 24.0))
			Visual.pilula(c, r, Color(0.04, 0.08, 0.18, 0.62), Color(cor.r, cor.g, cor.b, 0.7))
			c.draw_circle(r.position + Vector2(12.0, 12.0), 4.5, cor)
			Visual.texto(c, r.position + Vector2(21.0, 17.5), nome, 14, Visual.BRANCO, 700)
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
			Visual.texto(c, ponta - dir * 30.0 + Vector2(-30.0, 6.0), nome, 14, cor, 700, 5)


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
	_camada_marcas = camada
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

	# D-094: placar completo num painel que abre tocando no placar compacto
	_placar_painel = PanelContainer.new()
	_placar_painel.name = "PlacarCompleto"
	_placar_painel.add_theme_stylebox_override("panel", Visual.caixa(18))
	_placar_painel.position = Vector2(20.0, 84.0)
	_placar_painel.visible = false
	_placar_painel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	raiz.add_child(_placar_painel)
	_placar = _rotulo(_placar_painel, 17, Color.WHITE, HORIZONTAL_ALIGNMENT_LEFT)
	_placar.add_theme_constant_override("outline_size", 0)
	_botao_placar = Button.new()
	_botao_placar.name = "Placar"
	_botao_placar.flat = true
	_botao_placar.focus_mode = Control.FOCUS_NONE
	for s in ["normal", "hover", "pressed", "focus", "hover_pressed"]:
		_botao_placar.add_theme_stylebox_override(s, StyleBoxEmpty.new())
	_botao_placar.position = Vector2(20.0, 16.0)
	_botao_placar.size = Vector2(330.0, 58.0)
	_botao_placar.add_to_group("botao_livre")
	_botao_placar.pressed.connect(func() -> void: _placar_painel.visible = not _placar_painel.visible)
	raiz.add_child(_botao_placar)
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
	_dica.text = "Deslize ↑ manda linha · ↓ puxa · toque: tenteio · 2 toques: vira · segure 1 s: puxão"
	_dica.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	_dica.offset_left = -420.0
	_dica.offset_right = 420.0
	_dica.offset_top = -90.0
	_dica.offset_bottom = -54.0
	# D-094: estes rótulos guardam o texto; o desenho é feito pela interface nova
	for l in [_info, _aviso, _banner, _dica]:
		l.modulate.a = 0.0

	# D-094: botões redondos com ícone — câmera, ajustes, pausa (o Lab fica na pausa)
	var cantos := HBoxContainer.new()
	cantos.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	cantos.offset_left = -260.0
	cantos.offset_right = -20.0
	cantos.offset_top = 14.0
	cantos.alignment = BoxContainer.ALIGNMENT_END
	cantos.add_theme_constant_override("separation", 14)
	raiz.add_child(cantos)
	_cantos = cantos
	var cam: Button = BotaoRedondo.new("camera")
	cam.name = "Camera"
	cantos.add_child(cam)
	cam.pressed.connect(func() -> void: _primeira_pessoa = not _primeira_pessoa)
	var ajustes: Button = BotaoRedondo.new("engrenagem")
	ajustes.name = "Ajustes"
	cantos.add_child(ajustes)
	ajustes.pressed.connect(func() -> void: _painel_ajustes.visible = not _painel_ajustes.visible)
	var pausa: Button = BotaoRedondo.new("pausa")
	pausa.name = "Pausa"
	cantos.add_child(pausa)
	pausa.pressed.connect(_pausar)
	camada.process_mode = Node.PROCESS_MODE_ALWAYS
	_criar_pausa(raiz)

	_painel_ajustes = PanelContainer.new()
	_painel_ajustes.name = "Ajustes"
	_painel_ajustes.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	_painel_ajustes.offset_left = -430.0
	_painel_ajustes.offset_right = -12.0
	_painel_ajustes.offset_top = 150.0
	_painel_ajustes.add_theme_stylebox_override("panel", Visual.caixa(18))
	_painel_ajustes.visible = false
	_painel_ajustes.add_to_group("botao_livre")
	raiz.add_child(_painel_ajustes)
	var caixa := VBoxContainer.new()
	_painel_ajustes.add_child(caixa)
	_ajuste(caixa, "Giro máximo mandando linha (°/s)", 60.0, 900.0, 20.0, velocidade_giro_mandando_linha, "giro")
	_ajuste(caixa, "Força da puxada (m/s)", 2.0, 10.0, 0.5, forca_puxada, "puxada")
	_ajuste(caixa, "Balanço do tenteio, para cada lado (°)", 15.0, 90.0, 5.0, balanco_tenteio, "balanco")
	_ajuste(caixa, "Giro do toque duplo (°)", 15.0, 90.0, 5.0, graus_por_toque, "toque")

	_criar_painel_mao(raiz)
	_criar_lobby(raiz)

	var versao := Label.new()
	_versao = versao
	versao.text = "PIPA BRASIL %s · build %s" % [ProjectSettings.get_setting("application/config/version", "?"), BuildInfo.COMMIT]
	versao.add_theme_font_size_override("font_size", 11)
	versao.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	versao.offset_left = 12.0
	versao.offset_top = -34.0
	versao.modulate.a = 0.7
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


## Bonecos (D-057): viram para a pipa, um braço na linha, o outro abraça ao
## puxar.
func _animar_bonecos(delta: float) -> void:
	for i in mini(_corpos.size(), modo.players.size()):
		var corpo: Node3D = _corpos[i]
		var fl: Flyer = modo.players[i]["flyer"]
		var base: Vector3 = modo.players[i]["base"]
		if i == 0 and _lanc_fase >= 1 and _lanc_fase <= 3:
			var pose := _pose_largada()
			corpo.position = pose["corpo"]
			corpo.call("atualizar", pose["mao"], (pose["corpo"] as Vector3) + Vector3(0.0, 8.0, -20.0), 0.0, delta)
			if _pipa_mao != null:
				_pipa_mao.global_position = pose["pipa"]
				_pipa_mao.global_rotation = Vector3(0.0, corpo.rotation.y, 0.0)
				# D-091: a frente da pipa (papel e cabresto) fica virada para o
				# pipeiro; amarrando, deitada para os olhos verem o cabresto;
				# andando, meio inclinada; erguendo, vai ficando em pé
				var deita := -0.55
				if _lanc_fase == 2:
					deita = lerpf(-0.55, -0.35, smoothstep(0.0, 1.0, _lanc_t / LARGADA_ANDAR))
				elif _lanc_fase == 3:
					deita = lerpf(-0.35, 0.1, _lanc_t / LARGADA_ERGUER)
				_pipa_mao.rotate_object_local(Vector3.RIGHT, deita)
				# amarrando: a pipa balança um pouco na mão
				if _lanc_fase == 1:
					_pipa_mao.rotate_object_local(Vector3.FORWARD, sin(_lanc_t * 9.0) * 0.05)
			continue
		if i == 0:
			corpo.position = base
		if i == 0 and _guardar_ativo() and bool(_guardando["na_mao"]):
			var gp := _guardar_ponto()
			corpo.call("atualizar", gp, gp + Vector3(0.0, -0.3, -0.6), 0.0, delta)
			continue
		if fl == null or fl.cut or fl.line == null:
			corpo.call("atualizar", base + Vector3(0.3, 1.0, -0.4), base + Vector3(0.0, 10.0, -20.0), 0.0, delta)
			continue
		var puxando := 1.0 if fl.input.haul_speed > 0.1 or fl.input.pull > 0.05 or fl.pilot.is_pulling(modo.world.time) else 0.0
		corpo.call("atualizar", fl.hand_position, fl.kite.position, puxando, delta)


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
	elif qual == "balanco":
		balanco_tenteio = v
		modo.your_kick_deg = v
		if modo.you() != null:
			modo.you().kite.definition.spin_kick_rate_deg = v
	elif qual == "giro":
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
	_banner_ini = Time.get_ticks_msec() / 1000.0
	_banner_ate = _banner_ini + 1.7


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
		var y0 := 150.0
		Visual.pilula(c, Rect2(x0 - 10, y0 - 8, largura + 20, 38))
		# metade esquerda: quanto a SUA linha já gastou; direita: a dele
		c.draw_rect(Rect2(x0, y0, largura * 0.5 * eu, 22), Color(0.95, 0.2, 0.15))
		c.draw_rect(Rect2(x0 + largura * 0.5, y0, largura * 0.5 * ele, 22), Color(0.2, 0.85, 0.3))
		c.draw_line(Vector2(x0 + largura * 0.5, y0 - 4), Vector2(x0 + largura * 0.5, y0 + 26), Color.WHITE, 2.0)
		var nome := String(modo.players[int(r["other"])]["name"]) if int(r["other"]) >= 0 else "rival"
		var aviso := "RELÔ com %s — você está ganhando!" % nome if ele >= eu else "RELÔ com %s — sua linha vai estourar, descarregue!" % nome
		var cor := Color(0.4, 1.0, 0.5) if ele >= eu else Color(1.0, 0.45, 0.35)
		c.draw_string_outline(fonte, Vector2(x0, y0 + 50), aviso, HORIZONTAL_ALIGNMENT_CENTER, largura, 18, 6, Color(0, 0, 0, 0.85))
		c.draw_string(fonte, Vector2(x0, y0 + 50), aviso, HORIZONTAL_ALIGNMENT_CENTER, largura, 18, cor)


# ---------------- interface nova (D-094) ----------------

## Pílulas e mensagens desenhadas: placar compacto, vento, linha e altura,
## aviso, dica e as mensagens de combate (LARGADA!, CORTE!…).
func _desenhar_hud(c: Control, tela: Vector2) -> void:
	var m := 20.0
	var eu := modo.you()
	var agora := Time.get_ticks_msec() / 1000.0
	# placar compacto: cortes salvos | sequência (tocar abre o completo)
	var cortes := str(int(_estatisticas["cortes"]))
	var seq := str(int(modo.players[0]["streak"]))
	var xs := m + 70.0 + maxf(Visual.largura(cortes, 26, 780), 52.0) + 16.0
	var r := Rect2(Vector2(m, 16.0), Vector2(xs - m + 62.0 + maxf(Visual.largura(seq, 26, 780), Visual.largura("sequência", 14)) + 22.0, 58.0))
	_botao_placar.size.x = r.size.x
	Visual.pilula(c, r)
	Visual.icone(c, "trofeu", r.position + Vector2(34.0, 30.0), 19.0)
	Visual.texto(c, r.position + Vector2(62.0, 31.0), cortes, 26, Visual.BRANCO, 780)
	Visual.texto(c, r.position + Vector2(62.0, 49.0), "cortes", 14, Color(0.85, 0.9, 1.0))
	c.draw_line(Vector2(xs, r.position.y + 12.0), Vector2(xs, r.end.y - 12.0), Color(1, 1, 1, 0.35), 2.0)
	Visual.icone(c, "coroa", Vector2(xs + 34.0, r.position.y + 29.0), 18.0)
	Visual.texto(c, Vector2(xs + 62.0, r.position.y + 31.0), seq, 26, Visual.BRANCO, 780)
	Visual.texto(c, Vector2(xs + 62.0, r.position.y + 49.0), "sequência", 14, Color(0.85, 0.9, 1.0))
	# vento: pílula embaixo dos botões, com a direção vista da câmera
	var ref := eu.kite.position if eu != null else _camera.global_position + Vector3(0.0, 15.0, 0.0)
	var vento := modo.world.wind.sample(ref, modo.world.time)
	var na_tela := _camera.global_transform.basis.inverse() * vento
	var dir := Vector2(na_tela.x, -na_tela.y - na_tela.z * 0.3)
	dir = dir.normalized() if dir.length() > 0.01 else Vector2.DOWN
	var rv := Rect2(Vector2(tela.x - m - 168.0, 90.0), Vector2(168.0, 52.0))
	Visual.pilula(c, rv)
	Visual.icone(c, "vento", rv.position + Vector2(30.0, 26.0), 15.0, Color(0.5, 0.85, 1.0))
	var pc := rv.position + Vector2(68.0, 26.0)
	c.draw_line(pc - dir * 10.0, pc + dir * 8.0, Visual.BRANCO, 3.0, true)
	c.draw_colored_polygon(PackedVector2Array([pc + dir * 14.0, pc + dir * 5.0 + dir.orthogonal() * 6.0, pc + dir * 5.0 - dir.orthogonal() * 6.0]), Visual.BRANCO)
	var vtxt := str(roundi(vento.length()))
	Visual.texto(c, rv.position + Vector2(90.0, 35.0), vtxt, 26, Visual.BRANCO, 780)
	Visual.texto(c, rv.position + Vector2(92.0 + Visual.largura(vtxt, 26, 780), 35.0), "m/s", 15, Color(0.85, 0.9, 1.0))
	# linha e altura (ou pipa na mão / cortada), embaixo no meio
	var partes: Array = []   # [texto, cor, tamanho, ícone]
	var p0: Dictionary = modo.players[0]
	if eu == null:
		partes = [["", Visual.BRANCO, 0, "pipa"], ["Pipa na mão · estoque ", Visual.BRANCO, 19, ""], [str(int(p0["stock"])), Visual.AMARELO, 21, ""]]
	elif eu.cut:
		partes = [["Sua linha foi cortada…", Color(1.0, 0.6, 0.5), 19, ""]]
	else:
		partes = [["", Visual.BRANCO, 0, "carretel"], ["Linha: ", Visual.BRANCO, 19, ""], ["%d m" % roundi(eu.line_length()), Visual.AMARELO, 21, ""],
			["   |   ", Color(1, 1, 1, 0.4), 19, ""], ["", Visual.BRANCO, 0, "altura"], ["Altura: ", Visual.BRANCO, 19, ""],
			["%d m" % roundi(eu.kite.position.y - (p0["base"] as Vector3).y), Visual.AMARELO, 21, ""]]
		if eu.holding > 0:
			partes.append(["   ENROSCOU: puxe tudo!", Visual.AMARELO, 17, ""])
	var larg := 36.0
	for pt in partes:
		larg += 30.0 if String(pt[3]) != "" else Visual.largura(String(pt[0]), int(pt[2]), 700)
	var rb := Rect2(Vector2((tela.x - larg) * 0.5, tela.y - 70.0), Vector2(larg, 50.0))
	if not _no_lobby:
		Visual.pilula(c, rb)
		var x := rb.position.x + 18.0
		for pt in partes:
			if String(pt[3]) != "":
				Visual.icone(c, String(pt[3]), Vector2(x + 13.0, rb.position.y + 25.0), 12.0, Visual.BRANCO)
				x += 30.0
			else:
				Visual.texto(c, Vector2(x, rb.position.y + 33.0), String(pt[0]), int(pt[2]), pt[1], 700)
				x += Visual.largura(String(pt[0]), int(pt[2]), 700)
	# dica dos gestos (só no começo)
	if _dica.visible and _dica.text != "":
		var wd := Visual.largura(_dica.text, 16) + 40.0
		var rd := Rect2(Vector2((tela.x - wd) * 0.5, tela.y - 120.0), Vector2(wd, 38.0))
		Visual.pilula(c, rd, Color(0.04, 0.08, 0.18, 0.7))
		Visual.texto(c, rd.position + Vector2(20.0, 25.0), _dica.text, 16, Color(0.9, 0.95, 1.0))
	# aviso curto (toast) no alto, no meio
	if _aviso.visible and _aviso.text != "":
		var wa := Visual.largura(_aviso.text, 20, 700) + 48.0
		var ra := Rect2(Vector2((tela.x - wa) * 0.5, 90.0), Vector2(wa, 44.0))
		Visual.pilula(c, ra, Visual.AZUL, Visual.AMARELO)
		Visual.texto(c, ra.position + Vector2(24.0, 29.0), _aviso.text, 20, Visual.BRANCO, 700)
	# mensagem de combate: faixa de pincel, letra grossa amarela, entra e some
	if agora < _banner_ate and _banner.text != "":
		var t := agora - _banner_ini
		var esc := 1.0
		if t < 0.12:
			esc = lerpf(0.5, 1.12, t / 0.12)
		elif t < 0.25:
			esc = lerpf(1.12, 1.0, (t - 0.12) / 0.13)
		var alfa := clampf((_banner_ate - agora) / 0.3, 0.0, 1.0)
		var tam := 64
		var fonte_t := Visual.fonte_titulo()
		var wt := fonte_t.get_string_size(_banner.text, HORIZONTAL_ALIGNMENT_LEFT, -1, tam).x
		var centro := Vector2(tela.x * 0.5, tela.y * 0.3)
		c.draw_set_transform(centro, -0.06, Vector2(esc, esc))
		Visual.pincel(c, Vector2.ZERO, Vector2(wt + 60.0, 92.0), Color(0.06, 0.07, 0.1, 0.88 * alfa), hash(_banner.text) % 97)
		var pos := Vector2(-wt * 0.5, tam * 0.36)
		c.draw_string_outline(fonte_t, pos + Vector2(3, 4), _banner.text, HORIZONTAL_ALIGNMENT_LEFT, -1, tam, 12, Color(0.35, 0.12, 0.0, 0.8 * alfa))
		c.draw_string_outline(fonte_t, pos, _banner.text, HORIZONTAL_ALIGNMENT_LEFT, -1, tam, 8, Color(0.5, 0.2, 0.0, alfa))
		c.draw_string(fonte_t, pos, _banner.text, HORIZONTAL_ALIGNMENT_LEFT, -1, tam, Color(1.0, 0.82, 0.12, alfa))
		c.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


## Pausa (D-094): para o jogo; dá para continuar ou abrir o laboratório de voo.
func _criar_pausa(raiz: Control) -> void:
	_painel_pausa = PanelContainer.new()
	_painel_pausa.name = "Pausa"
	_painel_pausa.set_anchors_preset(Control.PRESET_CENTER)
	_painel_pausa.offset_left = -190.0
	_painel_pausa.offset_right = 190.0
	_painel_pausa.offset_top = -130.0
	_painel_pausa.offset_bottom = 130.0
	_painel_pausa.add_theme_stylebox_override("panel", Visual.caixa(26, Visual.AZUL))
	_painel_pausa.visible = false
	_painel_pausa.add_to_group("botao_livre")
	raiz.add_child(_painel_pausa)
	var caixa := VBoxContainer.new()
	caixa.add_theme_constant_override("separation", 14)
	caixa.alignment = BoxContainer.ALIGNMENT_CENTER
	_painel_pausa.add_child(caixa)
	var t := Label.new()
	t.text = "PAUSA"
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	t.add_theme_font_override("font", Visual.fonte_titulo())
	t.add_theme_font_size_override("font_size", 40)
	t.add_theme_color_override("font_color", Visual.AMARELO)
	caixa.add_child(t)
	var cont := _botao_capsula(caixa, "Continuar", Visual.VERDE)
	cont.pressed.connect(_pausar)
	var lab := _botao_capsula(caixa, "Laboratório de voo", Visual.AZUL_CLARO)
	lab.pressed.connect(func() -> void:
		get_tree().paused = false
		_ao_abrir_laboratorio())


func _botao_capsula(pai: Control, texto: String, cor: Color) -> Button:
	var b := Button.new()
	b.text = texto
	b.focus_mode = Control.FOCUS_NONE
	b.custom_minimum_size = Vector2(300.0, 58.0)
	b.add_theme_font_override("font", Visual.fonte(780))
	b.add_theme_font_size_override("font_size", 22)
	var sb := StyleBoxFlat.new()
	sb.bg_color = cor
	sb.set_corner_radius_all(29)
	sb.anti_aliasing = true
	sb.shadow_color = Color(0, 0, 0, 0.3)
	sb.shadow_size = 4
	sb.shadow_offset = Vector2(0, 3)
	var ap := sb.duplicate() as StyleBoxFlat
	ap.bg_color = cor.darkened(0.2)
	ap.shadow_size = 1
	b.add_theme_stylebox_override("normal", sb)
	b.add_theme_stylebox_override("hover", sb)
	b.add_theme_stylebox_override("pressed", ap)
	b.add_theme_stylebox_override("hover_pressed", ap)
	b.add_to_group("botao_livre")
	pai.add_child(b)
	return b


func _pausar() -> void:
	var pausado := not get_tree().paused
	get_tree().paused = pausado
	_painel_pausa.visible = pausado


func _mostrar_aviso_curto(texto: String) -> void:
	_avisar(texto)


# ---------------- pipa na mão (D-037) ----------------

func _criar_painel_mao(raiz: Control) -> void:
	# Pipa na mão (D-064): o estoque e o botão COLOCAR NO ALTO, que abre a
	# escolha da pipa e depois da linha (como no Pipa Combate).
	# D-094: o COLOCAR NO ALTO é um botão redondo no canto de baixo à direita,
	# com aro amarelo iluminado (o estoque aparece na pílula de baixo)
	_painel_mao = PanelContainer.new()
	_painel_mao.name = "PipaNaMao"
	_painel_mao.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	_painel_mao.offset_left = -190.0
	_painel_mao.offset_right = -24.0
	_painel_mao.offset_top = -190.0
	_painel_mao.offset_bottom = -24.0
	_painel_mao.add_theme_stylebox_override("panel", StyleBoxEmpty.new())
	_painel_mao.add_to_group("botao_livre")
	raiz.add_child(_painel_mao)
	var caixa := VBoxContainer.new()
	caixa.add_theme_constant_override("separation", 8)
	_painel_mao.add_child(caixa)
	_rotulo_mao = _rotulo(caixa, 18, Color(1.0, 0.9, 0.5), HORIZONTAL_ALIGNMENT_CENTER)
	_rotulo_mao.visible = false
	var subir: Button = BotaoRedondo.new("pipa", "alto", "Colocar\nno Alto")
	subir.name = "ColocarNoAlto"
	caixa.add_child(subir)
	_botao_alto = subir
	subir.pressed.connect(_abrir_pipas)
	_painel_mao.visible = modo.you_on_hand
	_criar_selecao(raiz)


func _atualizar_painel_mao() -> void:
	var e: Dictionary = Estilos.ESTILOS[modo.you_style]
	_rotulo_mao.text = "Sua pipa está na mão · estoque: %d · última: %s" % [int(modo.players[0]["stock"]), String(e["nome"])]


# ---------------- escolha da pipa e da linha (D-064) ----------------

var _selecao: Control
var _sel_titulo: Label
var _sel_grade: GridContainer
var _sel_rolagem: ScrollContainer
var _rolou := false          ## D-078: o dedo arrastou a lista (não é escolha)
var _rol_ini := Vector2.ZERO
const PreviaPipa := preload("res://game/ui/previa_pipa.gd")
const Carretel := preload("res://game/ui/carretel.gd")


## D-078: arrastar o dedo rola a lista de pipas/linhas (o iPhone não rolava:
## os cartões pegavam o toque). Se o dedo andou, soltar não escolhe nada.
func _rolar_lista(evento: InputEvent) -> bool:
	if evento is InputEventScreenTouch:
		var t := evento as InputEventScreenTouch
		if t.pressed:
			_rolou = false
			_rol_ini = t.position
		return false
	if evento is InputEventScreenDrag:
		var d := evento as InputEventScreenDrag
		if d.position.distance_to(_rol_ini) > 14.0:
			_rolou = true
		if _rolou and _sel_rolagem != null:
			_sel_rolagem.scroll_vertical -= roundi(d.relative.y)
		return false
	return false


func _criar_selecao(raiz: Control) -> void:
	_selecao = PanelContainer.new()
	_selecao.name = "Selecao"
	_selecao.set_anchors_preset(Control.PRESET_FULL_RECT)
	var fundo := StyleBoxFlat.new()
	fundo.bg_color = Color(0.04, 0.06, 0.14, 0.96)
	_selecao.add_theme_stylebox_override("panel", fundo)
	_selecao.add_to_group("botao_livre")
	_selecao.visible = false
	raiz.add_child(_selecao)
	var coluna := VBoxContainer.new()
	coluna.add_theme_constant_override("separation", 8)
	_selecao.add_child(coluna)
	var topo := HBoxContainer.new()
	coluna.add_child(topo)
	var voltar := _botao(topo, "‹ Voltar")
	voltar.add_theme_font_size_override("font_size", 22)
	voltar.pressed.connect(_fechar_selecao)
	_sel_titulo = _rotulo(topo, 28, Color(1.0, 0.86, 0.2), HORIZONTAL_ALIGNMENT_CENTER)
	_sel_titulo.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_sel_rolagem = ScrollContainer.new()
	_sel_rolagem.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_sel_rolagem.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	coluna.add_child(_sel_rolagem)
	_sel_grade = GridContainer.new()
	_sel_grade.columns = 6
	_sel_grade.add_theme_constant_override("h_separation", 8)
	_sel_grade.add_theme_constant_override("v_separation", 8)
	_sel_grade.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_sel_rolagem.add_child(_sel_grade)


func _limpar_grade() -> void:
	for filho in _sel_grade.get_children():
		_sel_grade.remove_child(filho)
		filho.queue_free()
	_sel_rolagem.scroll_vertical = 0


func _cartao(texto_cima: String, linhas: Array) -> Button:
	var b := Button.new()
	b.custom_minimum_size = Vector2(200.0, 250.0)
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var estilo := StyleBoxFlat.new()
	estilo.bg_color = Color(0.13, 0.36, 0.72)
	estilo.bg_color = estilo.bg_color.lerp(Color(0.98, 0.72, 0.42), 0.15)
	estilo.set_corner_radius_all(10)
	estilo.border_color = Color(0.25, 0.55, 0.95)
	estilo.set_border_width_all(2)
	b.add_theme_stylebox_override("normal", estilo)
	b.add_theme_stylebox_override("hover", estilo)
	var apertado := estilo.duplicate() as StyleBoxFlat
	apertado.border_color = Color(1.0, 0.86, 0.2)
	apertado.set_border_width_all(4)
	b.add_theme_stylebox_override("pressed", apertado)
	var caixa := VBoxContainer.new()
	caixa.set_anchors_preset(Control.PRESET_FULL_RECT)
	caixa.offset_left = 6.0
	caixa.offset_right = -6.0
	caixa.offset_top = 4.0
	caixa.offset_bottom = -4.0
	caixa.add_theme_constant_override("separation", 2)
	caixa.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.add_child(caixa)
	var numero := Label.new()
	numero.text = texto_cima
	numero.add_theme_font_size_override("font_size", 14)
	numero.mouse_filter = Control.MOUSE_FILTER_IGNORE
	caixa.add_child(numero)
	b.set_meta("caixa", caixa)
	return b


func _linha_info(caixa: VBoxContainer, texto: String, grande := false) -> void:
	var l := Label.new()
	l.text = texto
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.add_theme_font_size_override("font_size", 19 if grande else 15)
	l.add_theme_color_override("font_color", Color(1.0, 0.95, 0.6) if grande else Color.WHITE)
	l.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.8))
	l.add_theme_constant_override("outline_size", 4 if grande else 2)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	caixa.add_child(l)


func _abrir_pipas() -> void:
	_limpar_grade()
	_sel_titulo.text = "Escolha a sua pipa"
	for i in Estilos.ESTILOS.size():
		var e: Dictionary = Estilos.ESTILOS[i]
		var b := _cartao(str(i + 1), [])
		var caixa: VBoxContainer = b.get_meta("caixa")
		var previa: Control = PreviaPipa.new()
		previa.custom_minimum_size = Vector2(0.0, 112.0)
		previa.mouse_filter = Control.MOUSE_FILTER_IGNORE
		caixa.add_child(previa)
		previa.set("estilo", e)
		_linha_info(caixa, String(e["nome"]).to_upper(), true)
		_linha_info(caixa, "Velocidade %d km" % int(e["velocidade"]))
		_linha_info(caixa, "Força %d g" % int(e["forca"]))
		_linha_info(caixa, "Rabiola %d m" % int(e["rabiola"]))
		b.pressed.connect(_escolheu_pipa.bind(i))
		_sel_grade.add_child(b)
	_selecao.visible = true


func _escolheu_pipa(i: int) -> void:
	if _rolou:
		return   # D-078: o dedo estava rolando a lista, não escolhendo
	modo.you_style = i
	_abrir_linhas()


func _abrir_linhas() -> void:
	_limpar_grade()
	_sel_titulo.text = "Agora escolha a linha"
	for i in Estilos.LINHAS.size():
		var l: Dictionary = Estilos.LINHAS[i]
		var b := _cartao("", [])
		b.custom_minimum_size = Vector2(200.0, 230.0)
		var caixa: VBoxContainer = b.get_meta("caixa")
		var c: Control = Carretel.new()
		c.custom_minimum_size = Vector2(0.0, 110.0)
		c.mouse_filter = Control.MOUSE_FILTER_IGNORE
		c.set("grossura", float(l["grossura"]))
		c.set("cor", l["cor"])
		caixa.add_child(c)
		_linha_info(caixa, String(l["nome"]), true)
		_linha_info(caixa, "Resistência %d%%" % roundi(float(l["resistencia"]) * 100.0))
		_linha_info(caixa, "Peso %s" % ("leve" if float(l["peso"]) < 0.9 else ("pesada" if float(l["peso"]) > 1.2 else "médio")))
		b.pressed.connect(_escolheu_linha.bind(i))
		_sel_grade.add_child(b)


func _escolheu_linha(i: int) -> void:
	if _rolou:
		return   # D-078: o dedo estava rolando a lista, não escolhendo
	modo.you_line = i
	_selecao.visible = false
	_colocar_no_alto_animado()


func _fechar_selecao() -> void:
	_selecao.visible = false


## D-078: colocar no alto como gente: pega a pipa, amarra a linha no
## cabresto, vai até a beira da laje, larga — e ela sobe pela física, com o
## pipeiro dando linha e tenteando (FreeMode.subir) até uns 20 m. Aí o
## controle é seu.
const LARGADA_AMARRAR := 1.6
const LARGADA_ANDAR := 1.2
const LARGADA_ERGUER := 0.5
## D-106: pipa chegando na mão → tirar a linha ou a rabiola → canto da laje.
const GUARDAR_CHEGAR := 0.8
const GUARDAR_TIRAR := 1.4
const GUARDAR_POR := 1.0
const PILHA_MAX := 12
var _guardar_fila: Array = []     ## [{v, def, rabiola, sua, origem}]
var _guardando := {}              ## a da vez (+ "t", "fase", "na_mao")
var _tomadas := {}                ## Flyer -> true: a vista é da animação
var _pilha: Array = []            ## vistas já guardadas no canto
var _lanc_fase := 0         ## 0 parado · 1 amarrando · 2 indo para a beira · 3 erguendo · 4 subindo
var _lanc_t := 0.0
var _pipa_mao: Node3D


func _colocar_no_alto_animado() -> void:
	if not modo.you_on_hand or _lanc_fase != 0 or _guardar_ativo() or not _guardar_fila.is_empty():
		return
	_painel_mao.visible = false
	_dedos.clear()
	_lanc_fase = 1
	_lanc_t = 0.0
	_pipa_mao = KiteView.new()
	_pipa_mao.name = "PipaNaMao"
	add_child(_pipa_mao)
	_pipa_mao.call("construir", modo.kite_for(modo.you_style), Estilos.ESTILOS[modo.you_style])
	_avisar("Amarrando a linha no cabresto…")


func _largada_passo(delta: float) -> void:
	_lanc_t += delta
	match _lanc_fase:
		1:
			if _lanc_t >= LARGADA_AMARRAR:
				_lanc_fase = 2
				_lanc_t = 0.0
				_avisar("Indo para a beira da laje…")
		2:
			if _lanc_t >= LARGADA_ANDAR:
				_lanc_fase = 3
				_lanc_t = 0.0
		3:
			if _lanc_t >= LARGADA_ERGUER:
				if _pipa_mao != null:
					_pipa_mao.queue_free()
					_pipa_mao = null
				modo.launch_you(modo.you_style, modo.you_line, true)
				_embalo = 0.0
				_lanc_fase = 4
				_lanc_t = 0.0
				_avisar("Largou! Dando linha e tenteando…")
		4:
			var r := modo.subir(delta)
			if r == 1:
				_lanc_fase = 0
				_avisar("No alto! Agora é com você.")
			elif r == -1:
				_lanc_fase = 0
				modo.put_you_on_hand()
				_avisar("Não subiu… tenta de novo.")


## Onde o boneco e a pipa na mão ficam durante a largada (fases 1 a 3).
func _pose_largada() -> Dictionary:
	var base: Vector3 = modo.players[0]["base"]
	var atras := base + Vector3(0.0, 0.0, 1.8)
	var pos := atras
	if _lanc_fase == 2:
		pos = atras.lerp(base, smoothstep(0.0, 1.0, _lanc_t / LARGADA_ANDAR))
	elif _lanc_fase >= 3:
		pos = base
	var alto := 1.15
	if _lanc_fase == 3:
		alto = lerpf(1.6, 2.1, _lanc_t / LARGADA_ERGUER)
	elif _lanc_fase == 2:
		alto = 1.6
	var pipa := pos + Vector3(0.0, alto, -0.45)
	return {"corpo": pos, "pipa": pipa, "mao": pipa + Vector3(0.0, -0.25, 0.15)}


func _colocar_no_alto() -> void:
	if not modo.you_on_hand:
		return
	modo.launch_you(modo.you_style, modo.you_line)
	_dedos.clear()
	_embalo = 0.0
	_painel_mao.visible = false


# ---------------- página inicial (D-063) ----------------

func _criar_lobby(raiz: Control) -> void:
	# D-095: página inicial no estilo das imagens do Lucas — cenário 3D na tela
	# toda, logo, JOGAR verde grande, seletores em cápsula, recorde com troféu
	# e botões redondos no canto.
	_lobby = Control.new()
	_lobby.name = "PaginaInicial"
	_lobby.set_anchors_preset(Control.PRESET_FULL_RECT)
	_lobby.mouse_filter = Control.MOUSE_FILTER_STOP
	_lobby.add_to_group("botao_livre")
	raiz.add_child(_lobby)
	# sombra suave à esquerda, só para o texto ler bem (sem faixa escura)
	var grad := Gradient.new()
	grad.set_color(0, Color(0.0, 0.03, 0.1, 0.42))
	grad.set_color(1, Color(0.0, 0.03, 0.1, 0.0))
	var tex := GradientTexture2D.new()
	tex.gradient = grad
	tex.fill_from = Vector2(0.0, 0.5)
	tex.fill_to = Vector2(1.0, 0.5)
	var sombra := TextureRect.new()
	sombra.texture = tex
	sombra.set_anchors_preset(Control.PRESET_LEFT_WIDE)
	sombra.offset_right = 760.0
	sombra.stretch_mode = TextureRect.STRETCH_SCALE
	sombra.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_lobby.add_child(sombra)
	var logo: Control = Logo.new()
	logo.position = Vector2(34.0, 14.0)
	_lobby.add_child(logo)
	_titulo_pipa = logo
	var jogar: Button = BotaoCapsula.new("jogar")
	jogar.name = "Jogar"
	jogar.position = Vector2(56.0, 300.0)
	jogar.size = jogar.custom_minimum_size
	jogar.pressed.connect(_jogar)
	_lobby.add_child(jogar)
	var linha := HBoxContainer.new()
	linha.position = Vector2(46.0, 398.0)
	linha.add_theme_constant_override("separation", 10)
	_lobby.add_child(linha)
	_botao_mapa = BotaoCapsula.new("seletor", "mapa", "Mapa")
	_botao_mapa.pressed.connect(_trocar_mapa)
	linha.add_child(_botao_mapa)
	_botao_hora = BotaoCapsula.new("seletor", "sol", "Hora")
	_botao_hora.pressed.connect(_trocar_hora)
	linha.add_child(_botao_hora)
	_botao_graficos = BotaoCapsula.new("seletor", "graficos", "Gráficos")
	_botao_graficos.pressed.connect(_trocar_graficos)
	linha.add_child(_botao_graficos)
	var recorde: Button = BotaoCapsula.new("recorde", "trofeu", "Meu recorde", "%d cortes" % int(_estatisticas["cortes"]))
	recorde.name = "Recorde"
	recorde.position = Vector2(56.0, 480.0)
	recorde.size = recorde.custom_minimum_size
	recorde.pressed.connect(func() -> void:
		_avisar("%d cortes · %d aparadas · melhor sequência %d" % [_estatisticas["cortes"], _estatisticas["aparadas"], _estatisticas["melhor_sequencia"]]))
	_lobby.add_child(recorde)
	# botões redondos no canto: ajustes, câmera (1ª/3ª pessoa) e laboratório
	var canto := HBoxContainer.new()
	canto.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	canto.offset_left = -260.0
	canto.offset_right = -20.0
	canto.offset_top = 14.0
	canto.alignment = BoxContainer.ALIGNMENT_END
	canto.add_theme_constant_override("separation", 14)
	_lobby.add_child(canto)
	var aj: Button = BotaoRedondo.new("engrenagem")
	aj.pressed.connect(func() -> void: _painel_ajustes.visible = not _painel_ajustes.visible)
	canto.add_child(aj)
	var cam: Button = BotaoRedondo.new("camera")
	cam.pressed.connect(func() -> void:
		_primeira_pessoa = not _primeira_pessoa
		_avisar("Câmera: " + ("pelos olhos (mãos)" if _primeira_pessoa else "atrás do boneco")))
	canto.add_child(cam)
	var lab: Button = BotaoRedondo.new("lab")
	lab.pressed.connect(_ir_laboratorio)
	canto.add_child(lab)
	_atualizar_lobby()
	_lobby.visible = _no_lobby


func _atualizar_lobby() -> void:
	_botao_mapa.set("valor", String(Bairro.NOMES_MAPAS[_mapa]))
	_botao_hora.set("valor", String(Ambiente.HORAS[_hora]["nome"]))
	_botao_graficos.set("valor", String(NOMES_GRAFICOS[_graficos]).get_slice(" ", 0))


func _trocar_mapa() -> void:
	var i := Bairro.MAPAS.find(_mapa)
	_mapa = String(Bairro.MAPAS[(i + 1) % Bairro.MAPAS.size()])
	_montar_cenario()
	_salvar_preferencias()
	_atualizar_lobby()


func _trocar_hora() -> void:
	var i := Ambiente.ORDEM_HORAS.find(_hora)
	_hora = String(Ambiente.ORDEM_HORAS[(i + 1) % Ambiente.ORDEM_HORAS.size()])
	_montar_cenario()
	_salvar_preferencias()
	_atualizar_lobby()


func _jogar() -> void:
	_no_lobby = false
	_inicio_jogo = modo.world.time
	_lobby.visible = false
	_posicionar_camera(true)


func _ir_laboratorio() -> void:
	get_tree().change_scene_to_file("res://scenes/lab/lab.tscn")


## A pipinha do título, balançando no vento.
func _desenhar_pipinha() -> void:
	var t := Time.get_ticks_msec() / 1000.0
	var c := Vector2(55.0, 60.0)
	var ang := sin(t * 1.6) * 0.25
	var b := Transform2D(ang, c + Vector2(sin(t * 0.9) * 6.0, cos(t * 1.3) * 4.0))
	var topo := b * Vector2(0.0, -42.0)
	var esq := b * Vector2(-34.0, -6.0)
	var dir := b * Vector2(34.0, -6.0)
	var baixo := b * Vector2(0.0, 48.0)
	_titulo_pipa.draw_colored_polygon(PackedVector2Array([topo, dir, b * Vector2(0.0, -6.0)]), Color(0.95, 0.2, 0.15))
	_titulo_pipa.draw_colored_polygon(PackedVector2Array([topo, b * Vector2(0.0, -6.0), esq]), Color(1.0, 0.85, 0.15))
	_titulo_pipa.draw_colored_polygon(PackedVector2Array([esq, dir, baixo]), Color(0.1, 0.45, 0.9))
	# rabiola de fitinhas
	var p := baixo
	for k in 9:
		var q := p + Vector2(sin(t * 4.0 + k * 0.8) * 5.0, 9.0)
		_titulo_pipa.draw_line(p, q, Color(1, 1, 1, 0.8), 1.5)
		_titulo_pipa.draw_line(q + Vector2(-5.0, 0.0), q + Vector2(5.0, 0.0), [Color(0.95, 0.2, 0.15), Color(1.0, 0.85, 0.15)][k % 2], 3.0)
		p = q
