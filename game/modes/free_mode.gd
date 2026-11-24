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
const PIPAS := ["Pipa do Rio", "Rabiola curta", "Rabiola longa"]
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
## Acontecimentos para a tela (tremor, câmera lenta, avisos): {"type", ...}
var screen_events: Array = []
## Sua pipa está na mão, na laje: a tela mostra a escolha de pipa e linha e o
## botão de colocar no alto (D-037).
var you_on_hand := false
var you_kite := 0
var you_line := 1
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
				_lancar(i)
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
					_lancar(i)
	# Tirar do alto: recolheu a linha toda, a pipa chegou na mão (D-037).
	var eu := you()
	if eu != null and not eu.cut and not _you_bot and eu.line != null and eu.line_length() < RECOLHER_LINHA:
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
func launch_you(kite := -1, line_kind := -1) -> void:
	if kite >= 0:
		you_kite = clampi(kite, 0, PIPAS.size() - 1)
	if line_kind >= 0:
		you_line = clampi(line_kind, 0, LINHAS.size() - 1)
	you_on_hand = false
	_lancar(0)


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


## Montagens da pipa (escolha antes de subir).
static func kite_for(k: int) -> KiteDefinition:
	var d := KiteDefinition.pipa_rio()
	if k == 1:
		d.tail_length *= 0.6
		d.tail_mass *= 0.6
		d.spin_give_rate_deg *= 1.25
		d.spin_kick_rate_deg *= 1.15
	elif k == 2:
		d.tail_length *= 1.4
		d.tail_mass *= 1.4
		d.spin_give_rate_deg *= 0.8
		d.spin_kick_rate_deg *= 0.9
	return d


## Linhas fictícias do jogo: só resistência, espessura e peso mudam.
static func apply_line(f: Flyer, k: int) -> void:
	if f.line == null:
		return
	var forca: float = [0.85, 1.0, 1.3][k]
	var grossura: float = [0.75, 1.0, 1.4][k]
	var peso: float = [0.75, 1.0, 1.5][k]
	f.line.strength *= forca
	f.line.thickness *= grossura
	f.line.mass_per_particle *= peso
	for j in f.line.inv_mass.size():
		if f.line.inv_mass[j] > 0.0:
			f.line.inv_mass[j] /= peso


func _lancar(i: int) -> void:
	var p: Dictionary = players[i]
	var velha: Flyer = p["flyer"]
	if velha != null:
		velha.tag = -1           # vira avoada de ninguém
		velha.line = null        # o pedaço que ficou na mão vai junto com o pipeiro
	var def := KiteDefinition.pipa_rio()
	if i == 0:
		def = kite_for(you_kite)
		def.spin_give_rate_deg = your_spin_rate * def.spin_give_rate_deg / KiteDefinition.pipa_rio().spin_give_rate_deg
	var f := world.add_flyer(def, p["base"], LINHA_INICIAL, 45.0, 0.0, true, 3.0)
	if i == 0:
		apply_line(f, you_line)
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
					_messages.append("EMBOLOU! Puxe devagar para trazer.")
		"decepou":
			var quem := _dono(int(e["catcher"]))
			if quem >= 0:
				var parte := "rabiola" if bool(e["tail"]) else "linha"
				if quem > 0:
					_messages.append("%s decepou a %s da avoada." % [_nome(quem), parte])
				else:
					_messages.append("Decepou a %s! A avoada escapou." % parte)
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
