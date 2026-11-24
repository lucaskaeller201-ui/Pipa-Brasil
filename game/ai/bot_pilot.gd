class_name BotPilot
extends RefCounted
## BotFlightController (Fase 4): bot que empina usando SÓ os comandos do
## pipeiro (PilotInput), exatamente os mesmos do jogador.
##
## Estratégia (calibrada no protótipo tools/prototipo/fase4/bot.py):
## - Linha esticada: a pipa fica parada com o bico para cima ou avança para
##   onde o bico aponta. Para ir para o lado, o bot dá folga (o bico gira),
##   estica de novo quando o bico chega na direção desejada e recolhe linha
##   enquanto avança (recolher estica a linha e empurra a pipa).
## - Solta a carretilha no máximo 0,25 s por giro e recolhe o que soltou.
## - Segurança: pipa baixa, para de manobrar e sobe; bico para baixo, solta a
##   carretilha para a pipa parar de mergulhar.
##
## Limitação conhecida: a mira para o lado ainda é fraca (D-018).

enum State { FLY, SLACK }

var difficulty: BotDifficulty
var perception: BotPerception
var target_azimuth := 0.0   ## graus no céu
var line_target := 30.0     ## m de linha desejados

var state: State = State.FLY
var slack_count := 0
var _t_state := 0.0
var _prev: Dictionary = {}
var _rate := 0.0            ## graus/s do giro do bico (estimado)
var _next_decision := 0.0
var _decision := {}


func _init(p_difficulty: BotDifficulty, seed := 1) -> void:
	difficulty = p_difficulty
	perception = BotPerception.new(p_difficulty, seed)


## Atualiza e escreve os comandos em flyer.input. Chamar a cada passo.
func update(flyer: Flyer, t: float) -> void:
	var o := perception.observe(flyer, t)
	if not _prev.is_empty():
		var dt := float(o["t"]) - float(_prev["t"])
		if dt > 0.0:
			_rate = 0.7 * _rate + 0.3 * wrapf(float(o["nose"]) - float(_prev["nose"]), -180.0, 180.0) / dt
	_prev = o
	if t >= _next_decision:
		_next_decision = t + 1.0 / difficulty.decisions_per_second
		_decision = _decide(o, t)
		# Manda busca: sentiu uma pipa enroscada na linha, recolhe para trazer.
		if flyer.holding > 0 and absf(float(o["nose"])) < 110.0:
			_decision = {"reel_in": true}
	_apply(flyer.input, _decision)


func desired_heading(o: Dictionary) -> float:
	if float(o["el"]) < 22.0:
		return 0.0
	var daz := target_azimuth - float(o["az"])
	if daz > 8.0:
		return 55.0
	if daz < -8.0:
		return -55.0
	return 0.0


func _decide(o: Dictionary, t: float) -> Dictionary:
	var nose := float(o["nose"])
	var el := float(o["el"])
	var line := float(o["line"])
	var tol := difficulty.tolerance_deg
	var hd := desired_heading(o)
	var e := wrapf(nose - hd, -180.0, 180.0)
	var pred := wrapf(nose + _rate * (difficulty.lead + difficulty.reaction) - hd, -180.0, 180.0)
	var dist := absf(target_azimuth - float(o["az"])) if el >= 22.0 else 0.0

	if state == State.FLY:
		if absf(e) > tol * 2.0 and t - _t_state > 0.25 and (absf(target_azimuth - float(o["az"])) > 6.0 or absf(nose) > 60.0):
			state = State.SLACK
			_t_state = t
			slack_count += 1
	elif absf(pred) < tol or t - _t_state > 1.5:
		state = State.FLY
		_t_state = t

	var d := {}
	if state == State.SLACK:
		d = {"slack": 1.0, "free_spool": t - _t_state < 0.25 and absf(pred) > tol * 2.0 and line < line_target + 8.0}
	else:
		if absf(e) < tol and dist > 6.0:
			d = {"reel_in": true} if line > line_target - 8.0 else {"pull": 1.0}
		if el < 15.0 and absf(nose) > 100.0:
			d = {"slack": 1.0}
		if d.is_empty() and absf(nose) < 60.0 and line > line_target:
			d = {"reel_in": true}
		if absf(nose) < 25.0 and line > line_target + 2.0:
			d = {"reel_in": true}
		if not d.has("reel_in") and absf(nose) < 100.0 and line > line_target + 6.0:
			d = {"reel_in": true}
		# Muita linha sobrando e o bico para cima: puxa linha com a mão ("abraça").
		if absf(nose) < 45.0 and line > line_target + 12.0:
			d = {"haul": 2.0}
		# Falta linha (por exemplo, para subir mais): dá linha com o bico para cima.
		if d.is_empty() and absf(nose) < 40.0 and line < line_target - 4.0:
			d = {"pay_out": true}
	# Emergência: bico para baixo, solta a carretilha para parar o mergulho.
	if absf(nose) > 110.0 and el < 40.0 and line < line_target + 25.0:
		d = {"slack": 1.0, "free_spool": true}
	return d


func _apply(input: PilotInput, d: Dictionary) -> void:
	input.clear()
	input.pull = float(d.get("pull", 0.0))
	input.slack = float(d.get("slack", 0.0))
	input.free_spool = bool(d.get("free_spool", false))
	input.reel_in = bool(d.get("reel_in", false))
	input.pay_out = bool(d.get("pay_out", false))
	input.haul_speed = float(d.get("haul", 0.0))
