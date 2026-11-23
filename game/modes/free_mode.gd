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
const RAIO_MAXIMO := 450.0       ## m: avoada que vai mais longe que isso some

## Um participante: {"name", "base", "flyer", "bot", "cuts", "catches", "losses",
## "respawn" (s até a pipa nova; < 0 = voando)}
var players: Array = []
var world: SimWorld
var _messages: Array[String] = []
var _remocoes: Array = []        ## [Flyer, instante (s)]
var _rng := RandomNumberGenerator.new()
## Velocidade do giro mandando linha da SUA pipa (graus/s), ajustável na tela.
var your_spin_rate := 900.0


## n_bots rivais; se `you_bot`, um bot também pilota a sua pipa (testes, capturas).
func _init(n_bots := 3, seed_ := 1, you_bot := false) -> void:
	_rng.seed = seed_
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
		}
		if i > 0 or you_bot:
			var niveis := [BotDifficulty.Level.NORMAL, BotDifficulty.Level.DIFICIL, BotDifficulty.Level.FACIL]
			var nivel: BotDifficulty.Level = BotDifficulty.Level.DIFICIL if i == 0 else niveis[i % 3]
			var bot := BotPilot.new(BotDifficulty.create(nivel), seed_ * 31 + i)
			bot.line_target = _rng.randf_range(30.0, 55.0)
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
	world.step(dt)
	for e in world.combat.take_events():
		_evento(e)
	for i in players.size():
		var p: Dictionary = players[i]
		if float(p["respawn"]) >= 0.0:
			p["respawn"] = float(p["respawn"]) - dt
			if float(p["respawn"]) < 0.0:
				_lancar(i)
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
func _mira(i: int) -> float:
	var me: Flyer = players[i]["flyer"]
	var alvo_i := (i + 1 + int(world.time / 25.0)) % players.size()
	if alvo_i == i:
		alvo_i = (alvo_i + 1) % players.size()
	var outro: Flyer = players[alvo_i]["flyer"]
	if outro == null or outro.cut:
		return 0.0
	var d := outro.kite.position - me.hand_position
	return clampf(rad_to_deg(atan2(d.x, -d.z)), -50.0, 50.0)


func _lancar(i: int) -> void:
	var p: Dictionary = players[i]
	var velha: Flyer = p["flyer"]
	if velha != null:
		velha.tag = -1           # vira avoada de ninguém
		velha.line = null        # o pedaço que ficou na mão vai junto com o pipeiro
	var def := KiteDefinition.pipa_rio()
	if i == 0:
		def.spin_give_rate_deg = your_spin_rate
	var f := world.add_flyer(def, p["base"], LINHA_INICIAL, 45.0, 0.0, true, 3.0)
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
			if autor >= 0 and autor != vitima:
				players[autor]["cuts"] = int(players[autor]["cuts"]) + 1
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
				_messages.append("Embolou na linha de %s!" % _nome_obj(quem) if quem > 0 else "EMBOLOU! Puxe devagar para trazer.")
		"decepou":
			var quem := _dono(int(e["catcher"]))
			if quem >= 0:
				_messages.append(("%s decepou a %s da avoada." % [_nome(quem), "rabiola" if bool(e["tail"]) else "linha"]) if quem > 0 else ("Decepou a %s! A avoada escapou." % ("rabiola" if bool(e["tail"]) else "linha")))
		"aparada":
			var quem := _dono(int(e["catcher"]))
			if quem >= 0:
				players[quem]["catches"] = int(players[quem]["catches"]) + 1
				players[quem]["stock"] = int(players[quem]["stock"]) + 1
				_messages.append("MANDA BUSCA! %s aparou a pipa." % _nome(quem))


func _nome(i: int) -> String:
	return "Você" if i == 0 else String(players[i]["name"])


func _nome_obj(i: int) -> String:
	return "você" if i == 0 else String(players[i]["name"])
