class_name FreeMode
extends RefCounted
## Modo livre: sem tempo, solta pipa até cansar. Placar de cortes e aparadas.
##
## Cada participante (você e os bots) fica numa laje. Quem tem a linha cortada
## ganha uma pipa nova depois de alguns segundos; a pipa cortada sai avoada e
## pode ser aparada por qualquer um (manda busca). Só lógica: a cena lê o
## estado e envia os comandos do jogador.

const Bairro := preload("res://game/world/bairro.gd")

const APELIDOS := ["Tião do Morro", "Biel Rabiola", "Nando Carretilha", "Dudu Desbica",
	"Kiko da Esquina", "Lelo Relo", "Zé da Laje"]
const LINHA_INICIAL := 20.0
const PIPA_NOVA_APOS := 3.0      ## s depois do corte
const SOME_APARADA := 4.0        ## s até a avoada aparada sair do céu
const SOME_PERDIDA := 6.0        ## s até a avoada perdida sumir do chão
const RAIO_MAXIMO := 450.0
const RECOLHER_LINHA := Pilot.MIN_LINE + 0.5   ## m: linha toda recolhida, a pipa chega na mão (D-037)
## Escolhas antes de subir a pipa (D-037). As pipas brasileiras novas entram
## aqui quando chegarem as fotos; por enquanto, a do Rio em três montagens.
const Estilos := preload("res://game/views/estilos_pipa.gd")
const PIPAS := ["Rabiola média", "Rabiola curta", "Rabiola longa"]
const PIPAS_INFO := ["a de sempre", "mais ágil: gira e tenteia mais rápido", "mais firme: gira mais devagar"]
const LINHAS := ["Leve", "Comum", "Forte"]
const LINHAS_INFO := ["sobe fácil, mas rompe antes", "equilibrada", "pesada (faz barriga), mas aguenta mais no relô"]
const CAIDA_RELANCA := 6.0       ## s com a pipa no chão até subir outra       ## m: avoada que vai mais longe que isso some

## Um participante: {"name", "base", "flyer", "bot", "cuts", "catches", "losses",
## "respawn" (s até a pipa nova; < 0 = voando)}
var players: Array = []
var world: SimWorld
var _messages: Array[String] = []
var _remocoes: Array = []        ## [Flyer, instante (s)]
var _rng := RandomNumberGenerator.new()
## Velocidade do giro mandando linha da SUA pipa (graus/s), ajustável na tela.
var your_spin_rate := 900.0
## Giro por toque do SEU tenteio (graus), ajustável na tela.
var your_kick_deg := 30.0   ## balanço do tenteio para cada lado (D-074)
## Acontecimentos para a tela (tremor, câmera lenta, avisos): {"type", ...}
var screen_events: Array = []
## Sua pipa está na mão, na laje: a tela mostra a escolha de pipa e linha e o
## botão de colocar no alto (D-037).
var you_on_hand := false
var _coices_vistos := 0
var you_kite := 0
var you_line := 2
var you_style := 0     ## desenho da sua pipa (estilos_pipa.gd)
var _you_bot := false
## Jeitos de jogar dos bots (Prompt 2 do Lucas): "alto" fica lá em cima
## esperando; "cacador" vai atrás da sua pipa; "fujao" foge do relô dando
## linha; "equilibrado" troca de alvo de tempos em tempos.
const PERFIS := ["cacador", "alto", "equilibrado", "fujao", "cacador", "alto", "equilibrado"]


## n_bots rivais; se `you_bot`, um bot também pilota a sua pipa (testes, capturas).
func _init(n_bots := 3, seed_ := 1, you_bot := false) -> void:
	_rng.seed = seed_
	_you_bot = you_bot
	world = SimWorld.new()
	world.wind = WindField.new(5.0, 0.15, seed_)
	world.combat.wear_rate = 1.0
	var nomes := APELIDOS.duplicate()
	for i in nomes.size():
		var j := _rng.randi_range(i, nomes.size() - 1)
		var tmp = nomes[i]
		nomes[i] = nomes[j]
		nomes[j] = tmp
	var total := mini(n_bots + 1, Bairro.LAJES.size())
	for i in total:
		var p := {
			"name": "Você" if i == 0 else String(nomes[i - 1]),
			"base": (Bairro.LAJES[i] as Vector3) + Vector3(0.0, Bairro.ALTURA_LAJE, 0.0),
			"flyer": null, "bot": null, "cuts": 0, "catches": 0, "losses": 0, "respawn": -1.0, "stock": 0,
			"streak": 0, "profile": "jogador" if i == 0 else String(PERFIS[(i - 1) % PERFIS.size()]),
			"style": 0 if i == 0 else (i * 7 + seed_) % 48,
		}
		if i > 0 or you_bot:
			var niveis := [BotDifficulty.Level.NORMAL, BotDifficulty.Level.DIFICIL, BotDifficulty.Level.FACIL]
			var nivel: BotDifficulty.Level = BotDifficulty.Level.DIFICIL if i == 0 else niveis[i % 3]
			var bot := BotPilot.new(BotDifficulty.create(nivel), seed_ * 31 + i)
			bot.line_target = _rng.randf_range(30.0, 55.0)
			if p["profile"] == "alto":
				bot.line_target = _rng.randf_range(65.0, 85.0)
			p["bot"] = bot
		players.append(p)
		_lancar(i)


## Pipa nova para um bot: da mão, subindo (jogo), ou já no alto (testes).
func _relancar(i: int) -> void:
	if largada_da_mao and i > 0:
		_lancar_da_mao(i)
	else:
		_lancar(i)


func you() -> Flyer:
	return players[0]["flyer"]


func take_messages() -> Array[String]:
	var m := _messages
	_messages = []
	return m


## Placar ordenado: mais cortes primeiro.
func ranking() -> Array:
	var r := players.duplicate()
	r.sort_custom(func(a, b): return int(a["cuts"]) * 10 + int(a["catches"]) > int(b["cuts"]) * 10 + int(b["catches"]))
	return r


## Avança um passo de física. Os comandos do jogador já devem estar em you().input.
func update(dt: float) -> void:
	var t := world.time
	for i in players.size():
		var p: Dictionary = players[i]
		var f: Flyer = p["flyer"]
		var bot: BotPilot = p["bot"]
		if i > 0 and float(p.get("espera", -1.0)) >= 0.0:
			# D-079: bot esperando a vez de colocar a dele no alto
			p["espera"] = float(p["espera"]) - dt
			if float(p["espera"]) < 0.0:
				_lancar_da_mao(i)
			continue
		if i > 0 and bool(p.get("sub", false)):
			if _subir(i, dt) == -1:
				p["respawn"] = 2.0
			continue
		if bot != null and f != null and not f.cut:
			bot.target_azimuth = _mira(i)
			bot.update(f, t)
			# Todo pipeiro tenteia: toques de vez em quando, cada um para um lado.
			# (só com a pipa já no alto: subindo, ele cuida de dar linha)
			if p["profile"] != "alto" and f.input.haul_speed <= 0.1 and f.input.pull < 0.05 and f.line_length() > bot.line_target - 5.0 \
					and absf(f.nose_angle_deg()) < 25.0 and _rng.randf() < dt / 1.2:
				var lado := -float(p.get("ultimo_lado", 1.0))
				p["ultimo_lado"] = lado
				f.input.kick_side = lado
				f.input.kick_spin = 0.0
				f.input.kick_scale = 1.0
				f.input.kick_base_shift = 0.0
				f.pilot.trigger(Pilot.Impulse.DESBICAR_LADO, t)
			# Fujão: com a linha laçada (dá para ver), descarrega para escapar.
			if p["profile"] == "fujao" and _lacado(f):
				f.input.haul_speed = -2.0
	world.step(dt)
	_ver_largada()
	for e in world.combat.take_events():
		_evento(e)
	for i in players.size():
		var p: Dictionary = players[i]
		# Pipa caída no chão (sem cortar) por muito tempo: o pipeiro sobe outra.
		var fl: Flyer = p["flyer"]
		if fl != null and not fl.cut and fl.kite.position.y < (p["base"] as Vector3).y - 2.0:
			p["chao"] = float(p.get("chao", 0.0)) + dt
			if float(p["chao"]) > CAIDA_RELANCA:
				p["chao"] = 0.0
				world.remove_flyer(fl)
				p["flyer"] = null
				if i == 0 and not _you_bot:
					you_on_hand = true
					_messages.append("Sua pipa caiu. Escolha e coloque outra no alto.")
					continue
				_relancar(i)
				if i == 0:
					_messages.append("Sua pipa caiu. Pipa nova no alto!")
				continue
		else:
			p["chao"] = 0.0
		if float(p["respawn"]) >= 0.0:
			p["respawn"] = float(p["respawn"]) - dt
			if float(p["respawn"]) < 0.0:
				if i == 0 and not _you_bot:
					_para_a_mao()
				else:
					_relancar(i)
	# Tirar do alto: recolheu a linha toda, a pipa chegou na mão (D-037).
	var eu := you()
	# (durante a subida a linha começa curta: não é "tirar do alto", D-078)
	if eu != null and not eu.cut and not _you_bot and not subindo and eu.line != null and eu.line_length() < RECOLHER_LINHA:
		_recolher()
	# Avoadas: somem depois de aparadas, perdidas ou muito longe.
	for f in world.flyers:
		var fl: Flyer = f
		if fl.tag >= 0 or _agendada(fl):
			continue
		if fl.captured:
			_remocoes.append([fl, world.time + SOME_APARADA])
		elif fl.lost:
			_remocoes.append([fl, world.time + SOME_PERDIDA])
		elif Vector2(fl.kite.position.x, fl.kite.position.z).length() > RAIO_MAXIMO:
			_remocoes.append([fl, world.time])
	# Pedaços de linha soltos (cortes e decepadas): guarda só os mais novos.
	while world.loose_chains.size() > 10:
		world.loose_chains.remove_at(0)
	for r in _remocoes.duplicate():
		if world.time >= float(r[1]):
			world.remove_flyer(r[0])
			_remocoes.erase(r)


func _agendada(f: Flyer) -> bool:
	for r in _remocoes:
		if r[0] == f:
			return true
	return false


## Para onde o bot i mira: a pipa de outro participante, trocando de alvo de
## tempos em tempos (cada bot tem o seu).
func _lacado(f: Flyer) -> bool:
	for e in world.combat.engagements:
		if e["a"] == f or e["b"] == f:
			return true
	return false


var _ultima_largada := -10.0


## Avisa a tela quando você dá uma largada no relô.
func _ver_largada() -> void:
	var eu := you()
	if eu == null or eu.cut or world.time - _ultima_largada < 1.5:
		return
	if eu.lunges > _coices_vistos:
		_coices_vistos = eu.lunges
		_ultima_largada = world.time
		_messages.append("LARGADA!")
		return
	if _lacado(eu) and world.combat._largada(eu) > 1.0:
		_ultima_largada = world.time
		_messages.append("LARGADA!")


## Relô da sua linha agora: {"other": índice do rival, "you": desgaste da sua
## linha no laço, "them": desgaste da dele} ou vazio.
func your_relo() -> Dictionary:
	var eu := you()
	for e in world.combat.engagements:
		if e["a"] == eu or e["b"] == eu:
			var outro: Flyer = e["b"] if e["a"] == eu else e["a"]
			var w_eu := float(e.get("wa", 0.0)) if e["a"] == eu else float(e.get("wb", 0.0))
			var w_ele := float(e.get("wb", 0.0)) if e["a"] == eu else float(e.get("wa", 0.0))
			return {"other": outro.tag, "you": w_eu, "them": w_ele, "strength": eu.line.strength if eu.line != null else 1.0}
	return {}


func _mira(i: int) -> float:
	var me: Flyer = players[i]["flyer"]
	var perfil := String(players[i]["profile"])
	if perfil == "alto":
		return 0.0
	var alvo_i := (i + 1 + int(world.time / 25.0)) % players.size()
	if perfil == "cacador":
		alvo_i = 0
	if alvo_i == i:
		alvo_i = (alvo_i + 1) % players.size()
	var outro: Flyer = players[alvo_i]["flyer"]
	if outro == null or outro.cut:
		return 0.0
	var d := outro.kite.position - me.hand_position
	return clampf(rad_to_deg(atan2(d.x, -d.z)), -50.0, 50.0)


## Coloca a sua pipa no alto com a pipa e a linha escolhidas.
## kite: pipa do catálogo (Estilos.ESTILOS); line_kind: linha (Estilos.LINHAS).
func launch_you(kite := -1, line_kind := -1, da_mao := false) -> void:
	if kite >= 0:
		you_style = clampi(kite, 0, Estilos.ESTILOS.size() - 1)
	if line_kind >= 0:
		you_line = clampi(line_kind, 0, Estilos.LINHAS.size() - 1)
	you_on_hand = false
	players[0]["style"] = you_style
	if da_mao:
		# D-078: largada de verdade — a pipa sai da mão com pouca linha e sobe
		# pela física, com o pipeiro dando linha e tenteando (subir()).
		_lancar_da_mao(0)
	else:
		_lancar(0)


## D-078: subida depois da largada. O pipeiro dá linha com o bico para cima
## e ela alta; dá uma puxadinha quando cai; com o bico de lado, segura e
## desbica para cima. Tudo pelos mesmos comandos do jogador (PilotInput/
## Pilot) — os bots sobem do mesmo jeito (D-079).
## Devolve 0 = subindo, 1 = no alto (o controle volta), -1 = caiu.
const SUBIDA_LINHA_INICIAL := 5.0   ## a linha mínima da carretilha
const SUBIDA_LINHA := 10.0          ## D-079: com 10 m o controle é seu (o Lucas achou 20 m muito)
var subir_motivo := ""
## true: os bots também começam com a pipa na mão e sobem pela física (o jogo
## liga; os testes de combate deixam desligado para começar já no alto).
var largada_da_mao := false
## D-083: pontos da rabiola dos bots no jogo (0 = o da pipa; o jogo usa 12)
var rabiola_bots := 0
## D-085: passadas extras nas linhas (o jogo usa 2, com 2 subpassos)
var passadas_extras := 0

var subindo: bool:
	get:
		return players.size() > 0 and bool(players[0].get("sub", false))


func subir(dt: float) -> int:
	return _subir(0, dt)


func _lancar_da_mao(i: int) -> void:
	_lancar(i, SUBIDA_LINHA_INICIAL, 30.0, 0.0)
	var p: Dictionary = players[i]
	p["sub"] = true
	p["sub_t"] = 0.0
	p["sub_toque"] = 0.3


## Os bots descem para a laje e cada um coloca a sua no alto, um de cada vez.
func bots_para_a_mao() -> void:
	largada_da_mao = true
	for i in range(1, players.size()):
		var p: Dictionary = players[i]
		var f: Flyer = p["flyer"]
		if f != null:
			world.remove_flyer(f)
			p["flyer"] = null
		p["espera"] = 1.0 + 2.5 * i + _rng.randf_range(0.0, 1.5)


func _subir(i: int, dt: float) -> int:
	var p: Dictionary = players[i]
	var f: Flyer = p["flyer"]
	if f == null or f.cut or f.line == null:
		subir_motivo = "sem pipa" if f == null else ("cortada" if f.cut else "sem linha")
		p["sub"] = false
		return -1
	p["sub_t"] = float(p.get("sub_t", 0.0)) + dt
	p["sub_toque"] = float(p.get("sub_toque", 0.0)) - dt
	var e := f.input
	var elev := f.elevation_deg()
	var bico := f.nose_angle_deg()
	e.kick_base_shift = 0.0
	if absf(bico) > 35.0:
		# bico de lado: segura a linha e desbica para cima (como o pipeiro
		# faz); dar linha agora faria a pipa girar mais (D-055)
		e.haul_speed = 0.0
		if float(p["sub_toque"]) <= 0.0:
			p["sub_toque"] = 0.35
			e.kick_side = signf(bico)
			e.kick_spin = signf(bico)
			e.kick_scale = 0.3
			e.kick_base_shift = minf(30.0, absf(bico))
			f.pilot.trigger(Pilot.Impulse.DESBICAR_LADO, world.time)
	elif elev < 35.0:
		e.haul_speed = 1.2      # baixa: puxadinha, ela sobe
	else:
		e.haul_speed = -2.0     # bico para cima e alta: manda linha
	if (f.line_length() >= SUBIDA_LINHA and elev >= 28.0) or float(p["sub_t"]) > 30.0:
		e.haul_speed = 0.0
		e.kick_spin = 0.0
		p["sub"] = false
		return 1
	if f.kite.position.y < (p["base"] as Vector3).y - 1.0:
		e.haul_speed = 0.0
		subir_motivo = "caiu (y %.1f)" % f.kite.position.y
		p["sub"] = false
		return -1
	return 0


## Deixa você na laje sem pipa no alto (início do jogo ou depois do corte).
func put_you_on_hand() -> void:
	var eu := you()
	if eu != null and not eu.cut:
		world.remove_flyer(eu)
		players[0]["flyer"] = null
	elif eu != null:
		_para_a_mao()
	you_on_hand = true


func _para_a_mao() -> void:
	var velha: Flyer = players[0]["flyer"]
	if velha != null:
		velha.tag = -1
		velha.line = null
	players[0]["flyer"] = null
	players[0]["respawn"] = -1.0
	you_on_hand = true


## Pipa na mão: o que estava enroscado na sua linha vai para o estoque.
func _recolher() -> void:
	var eu := you()
	var trouxe := 0
	for l in world.combat.links.duplicate():
		if l["catcher"] != eu:
			continue
		var av: Flyer = l["avoada"]
		if not bool(l["captured"]):
			players[0]["catches"] = int(players[0]["catches"]) + 1
			players[0]["stock"] = int(players[0]["stock"]) + 1
			screen_events.append({"type": "aparada", "quem": 0})
		trouxe += 1
		av.captured = true
		if not _agendada(av):
			_remocoes.append([av, world.time])
	world.remove_flyer(eu)
	players[0]["flyer"] = null
	you_on_hand = true
	if trouxe > 0:
		_messages.append("Pipa na mão! %d para o estoque (estoque: %d)." % [trouxe, int(players[0]["stock"])])
	else:
		_messages.append("Pipa na mão. Escolha e coloque no alto de novo.")


## A pipa do catálogo vira física (D-064): velocidade muda o quanto ela anda
## e gira; rabiola muda o tamanho e o peso da rabiola (as "sem rabiola" levam
## uma curtinha, de 1,5 m, para a física continuar estável).
static func kite_for(estilo_i: int) -> KiteDefinition:
	var d := KiteDefinition.pipa_rio()
	var e: Dictionary = Estilos.ESTILOS[clampi(estilo_i, 0, Estilos.ESTILOS.size() - 1)]
	var v := float(e.get("velocidade", 55)) / 55.0
	d.pull_assist *= v
	d.spin_give_rate_deg *= clampf(v, 0.7, 1.4)
	d.nose_drag_rate /= clampf(v, 0.6, 1.4)
	var r := clampf(float(e.get("rabiola", 5)), 1.5, 8.0)
	d.tail_length = r
	d.tail_mass = 0.0015 * r
	d.tail_segments = clampi(roundi(r * 4.0), 8, 28)
	return d


## Força da pipa (g) no relô: multiplica a resistência da linha.
static func kite_strength(estilo_i: int) -> float:
	var e: Dictionary = Estilos.ESTILOS[clampi(estilo_i, 0, Estilos.ESTILOS.size() - 1)]
	return clampf(0.8 + float(e.get("forca", 100)) / 500.0, 0.85, 1.15)


## Linhas fictícias do jogo: resistência, espessura e peso (D-064).
static func apply_line(f: Flyer, k: int, estilo_i := -1) -> void:
	if f.line == null:
		return
	var l: Dictionary = Estilos.LINHAS[clampi(k, 0, Estilos.LINHAS.size() - 1)]
	var forca: float = float(l["resistencia"]) * (kite_strength(estilo_i) if estilo_i >= 0 else 1.0)
	var grossura: float = float(l["grossura"])
	var peso: float = float(l["peso"])
	f.line.strength *= forca
	f.line.thickness *= grossura
	f.line.mass_per_particle *= peso
	for j in f.line.inv_mass.size():
		if f.line.inv_mass[j] > 0.0:
			f.line.inv_mass[j] /= peso


func _lancar(i: int, comprimento := LINHA_INICIAL, elevacao := 45.0, tensao := 3.0) -> void:
	var p: Dictionary = players[i]
	var velha: Flyer = p["flyer"]
	if velha != null:
		velha.tag = -1           # vira avoada de ninguém
		velha.line = null        # o pedaço que ficou na mão vai junto com o pipeiro
	var def := KiteDefinition.pipa_rio()
	if i == 0:
		def = kite_for(you_style)
		def.spin_give_rate_deg = your_spin_rate * def.spin_give_rate_deg / KiteDefinition.pipa_rio().spin_give_rate_deg
		def.spin_kick_rate_deg = your_kick_deg
	if i > 0 and rabiola_bots > 0:
		def.tail_segments = rabiola_bots
	var f := world.add_flyer(def, p["base"], comprimento, elevacao, 0.0, true, tensao)
	f.extra_sweeps = passadas_extras
	if i == 0:
		apply_line(f, you_line, you_style)
	f.tag = i
	p["flyer"] = f
	p["respawn"] = -1.0


func _dono(id: int) -> int:
	if id < 0 or id >= world.flyers.size():
		return -1
	return (world.flyers[id] as Flyer).tag


func _evento(e: Dictionary) -> void:
	match e["type"]:
		"ruptura":
			var vitima := _dono(int(e["flyer"]))
			var autor := _dono(int(e.get("by", -1)))
			if vitima < 0:
				return
			players[vitima]["losses"] = int(players[vitima]["losses"]) + 1
			players[vitima]["respawn"] = PIPA_NOVA_APOS
			players[vitima]["streak"] = 0
			screen_events.append({"type": "corte", "autor": autor, "vitima": vitima})
			if autor >= 0 and autor != vitima:
				players[autor]["cuts"] = int(players[autor]["cuts"]) + 1
				players[autor]["streak"] = int(players[autor]["streak"]) + 1
				_messages.append("%s cortou %s!" % [_nome(autor), _nome_obj(vitima)])
			else:
				_messages.append("A linha de %s rompeu!" % _nome_obj(vitima))
		"lacou":
			var x := _dono(int(e["flyer"]))
			var y := _dono(int(e["other"]))
			if x >= 0 and y >= 0:
				_messages.append("Laçou! %s × %s" % [_nome(x), _nome(y)])
		"enroscou":
			var quem := _dono(int(e["catcher"]))
			if quem >= 0:
				if quem > 0:
					_messages.append("Embolou na linha de %s!" % _nome_obj(quem))
				else:
					_messages.append("EMBOLOU! Mande linha para firmar, ou puxe devagar.")
		"embolo_firme":
			if _dono(int(e["catcher"])) == 0:
				_messages.append("EMBOLO FIRME! Pode trazer rápido.")
		"decepou":
			var quem := _dono(int(e["catcher"]))
			if quem >= 0:
				var parte := "rabiola" if bool(e["tail"]) else "linha"
				if quem > 0:
					_messages.append("%s fatiou a %s da avoada." % [_nome(quem), parte])
				else:
					_messages.append("FATIOU a %s da avoada!" % parte)
		"fatiou":
			if bool(e.get("voando", false)):
				var quem3 := _dono(int(e["catcher"]))
				var vitima := _dono(int(e["flyer"]))
				if quem3 == 0:
					_messages.append("FATIOU a rabiola de %s!" % _nome(vitima))
				elif vitima == 0:
					_messages.append("%s fatiou a sua rabiola!" % _nome(quem3))
		"soltou":
			if _dono(int(e["catcher"])) == 0:
				_messages.append("Tenteou e a avoada saiu do aparo.")
		"aparada":
			var quem := _dono(int(e["catcher"]))
			if quem >= 0:
				players[quem]["catches"] = int(players[quem]["catches"]) + 1
				players[quem]["stock"] = int(players[quem]["stock"]) + 1
				screen_events.append({"type": "aparada", "quem": quem})
				_messages.append("MANDA BUSCA! %s aparou a pipa." % _nome(quem))


func _nome(i: int) -> String:
	return "Você" if i == 0 else String(players[i]["name"])


func _nome_obj(i: int) -> String:
	return "você" if i == 0 else String(players[i]["name"])


func take_screen_events() -> Array:
	var e := screen_events
	screen_events = []
	return e
