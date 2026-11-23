class_name MatchRules
extends RefCounted
## Partida 1 contra 1, melhor de 3 (inspirada no formato do Manda Busca).
##
## Jogo 1 — Suba a pipa: começa com 8 m de linha; ganha quem primeiro levar a
##   pipa a ALTURA_SUBA acima da própria laje. Se o tempo acabar, a mais alta.
## Jogo 2 — A mais alta, sem corte: o contato entre linhas existe, mas não
##   desgasta. Quando o tempo acaba, ganha a pipa mais alta.
## Jogo 3 — Valendo corte: ganha quem cortar a linha do outro. Se ninguém
##   cortar, a mais alta. Aparar a avoada (manda busca) vale a honra.
##
## Só lógica: lê o SimWorld e decide. Quem cria o mundo de cada jogo é a cena
## (ou o teste), por meio de `world_factory`.

enum Mode { SUBA, MAIS_ALTA, VALENDO_CORTE }
enum State { COUNTDOWN, PLAYING, ROUND_OVER, MATCH_OVER }

const ROUNDS: Array[Mode] = [Mode.SUBA, Mode.MAIS_ALTA, Mode.VALENDO_CORTE]
const COUNTDOWN := 3.0
const ROUND_PAUSE := 4.0
const ALTURA_SUBA := 30.0  ## m acima da laje
const DURACAO := {Mode.SUBA: 90.0, Mode.MAIS_ALTA: 60.0, Mode.VALENDO_CORTE: 120.0}
const LINHA_INICIAL := {Mode.SUBA: 8.0, Mode.MAIS_ALTA: 30.0, Mode.VALENDO_CORTE: 30.0}
const WEAR_RATE := 1.0

## Callable(mode: Mode, line_length: float) -> SimWorld, com flyers[0] = você
## e flyers[1] = rival.
var world_factory: Callable
var names := ["Você", "Rival"]

var world: SimWorld
var round_index := 0
var score := [0, 0]
var state: State = State.COUNTDOWN
var timer := 0.0           ## contagem regressiva ou tempo restante do jogo
var last_round_winner := -1
var match_winner := -1
## Mensagens para a tela: Array de Strings, consumidas com take_messages().
var _messages: Array[String] = []


func _init(p_factory: Callable, p_names := ["Você", "Rival"]) -> void:
	world_factory = p_factory
	names = p_names
	_start_round()


func mode() -> Mode:
	return ROUNDS[round_index]


static func mode_name(m: Mode) -> String:
	return ["Suba a pipa", "A mais alta, sem corte", "Valendo corte"][m]


static func mode_hint(m: Mode) -> String:
	match m:
		Mode.SUBA:
			return "Dê linha e leve a pipa a %d m de altura primeiro." % roundi(ALTURA_SUBA)
		Mode.MAIS_ALTA:
			return "Sem corte: no fim do tempo, ganha a pipa mais alta."
		_:
			return "Corte a linha do rival. Cortou? Manda busca!"


## Altura da pipa de um pipeiro acima da laje dele (m).
func altitude(i: int) -> float:
	var f: Flyer = world.flyers[i]
	return f.kite.position.y - (f.hand_position.y - 1.2)


## Avança as regras. Chamar a cada passo de física, depois de world.step().
func update(dt: float) -> void:
	match state:
		State.COUNTDOWN:
			timer -= dt
			if timer <= 0.0:
				state = State.PLAYING
				timer = DURACAO[mode()]
				_messages.append("VALENDO! " + mode_hint(mode()))
		State.PLAYING:
			timer -= dt
			_check_round()
		State.ROUND_OVER:
			timer -= dt
			if timer <= 0.0:
				_next_round()
		State.MATCH_OVER:
			pass


func take_messages() -> Array[String]:
	var m := _messages
	_messages = []
	return m


func _check_round() -> void:
	var m := mode()
	var vencedor := -1
	var motivo := ""
	for e in world.combat.take_events():
		match e["type"]:
			"ruptura":
				if m == Mode.VALENDO_CORTE and vencedor < 0:
					vencedor = 1 - int(e["flyer"])
					motivo = "%s cortou!" % names[vencedor]
			"aparada":
				_messages.append("MANDA BUSCA! %s aparou a pipa." % names[int(e["catcher"])])
			"enroscou":
				_messages.append("Enroscou na linha de %s!" % names[int(e["catcher"])])
	if vencedor < 0 and m == Mode.SUBA:
		for i in 2:
			if altitude(i) >= ALTURA_SUBA:
				vencedor = i
				motivo = "%s subiu primeiro!" % names[i]
				break
	if vencedor < 0 and timer <= 0.0:
		vencedor = 0 if altitude(0) >= altitude(1) else 1
		motivo = "Tempo! A pipa de %s está mais alta (%d m × %d m)." % [
			names[vencedor], roundi(altitude(vencedor)), roundi(altitude(1 - vencedor))]
	if vencedor >= 0:
		_end_round(vencedor, motivo)


func _end_round(vencedor: int, motivo: String) -> void:
	score[vencedor] += 1
	last_round_winner = vencedor
	_messages.append("%s  Placar: %d × %d" % [motivo, score[0], score[1]])
	if score[vencedor] >= 2:
		state = State.MATCH_OVER
		match_winner = vencedor
		_messages.append("FIM DE PARTIDA! %s venceu." % names[vencedor])
	else:
		state = State.ROUND_OVER
		timer = ROUND_PAUSE


func _next_round() -> void:
	round_index += 1
	_start_round()


func _start_round() -> void:
	world = world_factory.call(mode(), LINHA_INICIAL[mode()])
	world.combat.wear_rate = WEAR_RATE if mode() == Mode.VALENDO_CORTE else 0.0
	state = State.COUNTDOWN
	timer = COUNTDOWN
	_messages.append("JOGO %d: %s" % [round_index + 1, mode_name(mode()).to_upper()])
