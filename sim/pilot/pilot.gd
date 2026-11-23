class_name Pilot
extends RefCounted
## O pipeiro: mão e carretilha. Transforma comandos em MOVIMENTOS da mão e da
## carretilha; nenhum comando aplica força direta na pipa (decisão D-003).
##
## A mão se move ao longo da linha (para a pipa = folga, para trás = puxar),
## com uma mola criticamente amortecida e velocidade máxima, como um braço.
## A carretilha muda o comprimento da linha na ponta da mão.

enum Impulse { PUXAO, ARRANCAO, DESBICAR }

const SHOULDER := Vector3(0.0, 1.45, 0.0)  ## em relação a `base`
const HAND_DROP := 0.25          ## m abaixo do ombro
const ARM_REST := 0.35           ## m à frente, na direção da pipa
const ARM_STIFFNESS := 30.0      ## rad/s (mola do braço)
const PULL_RANGE := 0.5          ## m que a mão recua ao puxar
const SLACK_RANGE := 0.45        ## m que a mão avança ao afrouxar
const PAY_OUT_MAX_SPEED := 2.0   ## m/s
const REEL_IN_SPEED := 1.2       ## m/s
const REEL_IN_MAX_TENSION := 35.0  ## N: acima disso não dá para enrolar
const SPOOL_FRICTION := 0.3      ## N
const SPOOL_INERTIA := 0.05      ## kg equivalentes da carretilha
const MIN_LINE := 5.0            ## m
const MAX_LINE := 300.0          ## m
const HAUL_MAX_SPEED := 6.0      ## m/s: o mais rápido que a mão puxa ou dá linha
const DESBICO_TIME := 0.2        ## s: duração do toque de desbicar (folga curta)

var base := Vector3.ZERO  ## onde o pipeiro está pisando
var hand_position := SHOULDER + Vector3(0.0, -HAND_DROP, -ARM_REST)
var arm_offset := 0.0            ## m ao longo da linha (+ = para a pipa)
var arm_velocity := 0.0
var spool_speed := 0.0           ## m/s de linha saindo
var _desbico_ate := -1.0

# Movimentos agendados: [início (s), duração (s), alvo do braço (m), velocidade máx (m/s)]
var _moves: Array = []


## Dispara um comando de impulso no instante t (segundos de simulação).
func trigger(impulse: Impulse, t: float) -> void:
	match impulse:
		Impulse.PUXAO:
			_moves = [[t, 0.15, -0.45, 4.5], [t + 0.15, 0.45, 0.0, 1.5]]
		Impulse.ARRANCAO:
			_moves = [[t, 0.22, -0.7, 7.0], [t + 0.22, 0.6, 0.0, 1.5]]
		Impulse.DESBICAR:
			# folga curta e rápida, depois um puxão: o bico gira na folga; na
			# pipa com giro controlado, dá um pulo de direção (D-030)
			_moves = [[t, 0.30, 0.40, 5.0], [t + 0.30, 0.15, -0.40, 5.0], [t + 0.45, 0.4, 0.0, 1.5]]
			_desbico_ate = t + DESBICO_TIME


## Verdadeiro durante a folga curta do desbico.
func is_desbicando(t: float) -> bool:
	return t < _desbico_ate


## Verdadeiro se a mão está no meio de um puxão (puxão, arrancão, toque).
func is_pulling(t: float) -> bool:
	for m in _moves:
		if float(m[0]) <= t and t < float(m[0]) + float(m[1]) and float(m[2]) < 0.0:
			return true
	return false


func shoulder_position() -> Vector3:
	return base + SHOULDER


static func impulse_name(impulse: Impulse) -> String:
	return ["Puxão", "Arrancão", "Desbicar"][impulse]


## Atualiza mão e carretilha. Devolve a variação do comprimento de linha (m).
func update(h: float, t: float, input: PilotInput, dir_to_kite: Vector3, tension: float, line_length: float) -> float:
	var alvo := 0.0
	var vmax := 2.0
	var ativo: Array = []
	for m in _moves:
		if float(m[0]) <= t:
			ativo = m
	if not ativo.is_empty():
		alvo = float(ativo[2])
		vmax = float(ativo[3])
	var restantes: Array = []
	for m in _moves:
		if float(m[0]) + float(m[1]) > t:
			restantes.append(m)
	_moves = restantes
	alvo += -PULL_RANGE * input.pull + SLACK_RANGE * input.slack

	var w := ARM_STIFFNESS
	var acc := w * w * (alvo - arm_offset) - 2.0 * w * arm_velocity
	arm_velocity = clampf(arm_velocity + acc * h, -vmax, vmax)
	arm_offset += arm_velocity * h
	hand_position = shoulder_position() + Vector3(0.0, -HAND_DROP, 0.0) + dir_to_kite * (ARM_REST + arm_offset)

	# Carretilha.
	var delta := 0.0
	if input.haul_speed != 0.0:
		# Linha pela mão: puxar (abraçar) ou dar linha no ritmo do gesto.
		spool_speed = 0.0
		delta = -clampf(input.haul_speed, -HAUL_MAX_SPEED, HAUL_MAX_SPEED) * h
	elif input.free_spool:
		spool_speed = maxf(0.0, spool_speed + (tension - SPOOL_FRICTION) / SPOOL_INERTIA * h)
		delta = spool_speed * h
	elif input.pay_out:
		spool_speed = clampf(spool_speed + (tension - SPOOL_FRICTION) / SPOOL_INERTIA * h, 0.0, PAY_OUT_MAX_SPEED)
		delta = spool_speed * h
	elif input.reel_in and tension < REEL_IN_MAX_TENSION:
		spool_speed = 0.0
		delta = -REEL_IN_SPEED * h
	else:
		spool_speed = 0.0
	delta = clampf(line_length + delta, MIN_LINE, MAX_LINE) - line_length
	return delta
