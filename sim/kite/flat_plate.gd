class_name FlatPlate
extends RefCounted
## Aerodinâmica de placa plana de baixa razão de aspecto (aproximação).
##
## Coeficiente de força normal C_N em função do ângulo de ataque α:
##   C_N = A_LIFT · sen α · cos α + CN_90 · sen² α
## Começa em zero, sobe com inclinação A_LIFT perto de α = 0, tem pico perto
## de 60° e termina em CN_90 a 90° (placa de frente para o vento).
## Ainda não modela o estol abrupto; isso pode entrar na Fase 6, por modelo.

const A_LIFT := 2.2   ## inclinação inicial (por radiano), típica de razão de aspecto baixa
const CN_90 := 1.2    ## placa perpendicular ao vento
const CF := 0.02      ## atrito no plano da placa


static func normal_coefficient(sin_aoa: float) -> float:
	var s := absf(sin_aoa)
	var c := sqrt(maxf(0.0, 1.0 - s * s))
	return A_LIFT * s * c + CN_90 * s * s
