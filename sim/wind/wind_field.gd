class_name WindField
extends RefCounted
## WindSystem: o vento do cenário.
##
## Determinístico: a mesma semente produz exatamente o mesmo vento, o que
## permite repetir experimentos, replays e testes de regressão.
## A velocidade cresce com a altura (perfil de potência) e pode ter
## turbulência suave e uma rajada em degrau.

const ALTURA_REFERENCIA := 10.0  ## m: "speed" vale a esta altura
const EXPOENTE_PERFIL := 0.14    ## perfil de vento em terreno aberto
const ALTURA_MINIMA := 0.5       ## m: evita vento zero colado no chão

var speed := 5.0                       ## m/s a 10 m de altura
var direction := Vector3(0.0, 0.0, -1.0)  ## para onde o vento sopra (horizontal)
var turbulence := 0.0                  ## intensidade relativa (0 = vento constante)
var gust_start := -1.0                 ## s; negativo = sem rajada
var gust_end := INF                    ## s
var gust_speed := 0.0                  ## m/s a 10 m durante a rajada

var _modes: Array = []  # cada modo: [direção: Vector3, omega: float, fase: float, número de onda: Vector3]


func _init(p_speed := 5.0, p_turbulence := 0.0, p_seed := 1) -> void:
	speed = p_speed
	turbulence = p_turbulence
	var rng := RandomNumberGenerator.new()
	rng.seed = p_seed
	for i in 3:
		var d := Vector3(rng.randf_range(-1.0, 1.0), rng.randf_range(-0.3, 0.3), rng.randf_range(-1.0, 1.0))
		var omega := rng.randf_range(0.15, 0.9)
		var phase := rng.randf_range(0.0, TAU)
		var k := Vector3(rng.randf_range(-0.05, 0.05), rng.randf_range(-0.05, 0.05), rng.randf_range(-0.05, 0.05))
		_modes.append([d, omega, phase, k])


## Rajada temporária (ou permanente, se duration for INF) a partir de start.
func set_gust(start: float, new_speed: float, duration := INF) -> void:
	gust_start = start
	gust_end = start + duration
	gust_speed = new_speed


func base_speed(t: float) -> float:
	if gust_start >= 0.0 and t >= gust_start and t < gust_end:
		return gust_speed
	return speed


## Velocidade do vento (m/s) no ponto pos, no instante t.
func sample(pos: Vector3, t: float) -> Vector3:
	var h := maxf(pos.y, ALTURA_MINIMA)
	var s := base_speed(t) * pow(h / ALTURA_REFERENCIA, EXPOENTE_PERFIL)
	var v := direction.normalized() * s
	if turbulence > 0.0:
		var d := Vector3.ZERO
		for m in _modes:
			var dir_m: Vector3 = m[0]
			var k_m: Vector3 = m[3]
			d += dir_m * sin(float(m[1]) * t + float(m[2]) + k_m.dot(pos))
		v += d * (turbulence * s / 1.7)
	return v
