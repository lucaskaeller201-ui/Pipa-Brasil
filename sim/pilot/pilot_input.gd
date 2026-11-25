class_name PilotInput
extends RefCounted
## Comandos do pipeiro num instante. É a ÚNICA forma de controlar a pipa,
## para o jogador e para os bots (a mesma interface, sem atalhos).
##
## Comandos contínuos (enquanto o botão está apertado) ficam aqui. Os comandos
## de impulso (puxão, arrancão, desbicar) são disparados com Pilot.trigger().

var pull := 0.0         ## Puxar: 0..1, recua a mão (mais tensão)
var slack := 0.0        ## Afrouxar: 0..1, leva a mão em direção à pipa (menos tensão)
var pay_out := false    ## Dar linha: solta linha com freio (até 2 m/s)
var free_spool := false ## Largar: carretilha livre, a pipa puxa a linha
var reel_in := false    ## Recolher: enrola linha (1,2 m/s, se a força deixar)
## Linha pela mão (m/s): + = puxa linha para si ("abraçar"), - = dá linha com a
## mão. É o gesto de deslizar o dedo; tem prioridade sobre a carretilha.
var haul_speed := 0.0
## Lado do desbico (D-034): +1 = bico para a direita do pipeiro, -1 = esquerda.
var kick_side := 1.0
## Volta com a pipa (D-039): se não for zero, o tenteio gira neste sentido fixo
## (o mesmo do tenteio anterior), em vez de ir para um lado do céu.
var kick_spin := 0.0
## Tamanho do pulo do tenteio (1 = normal).
var kick_scale := 1.0
## Toque duplo (D-050): quantos graus a direção do tenteio anda junto, no
## sentido do toque (0 = só balança em volta da direção).
var kick_base_shift := 0.0


func clear() -> void:
	pull = 0.0
	slack = 0.0
	pay_out = false
	free_spool = false
	reel_in = false
	haul_speed = 0.0


func copy_from(other: PilotInput) -> void:
	pull = other.pull
	slack = other.slack
	pay_out = other.pay_out
	free_spool = other.free_spool
	reel_in = other.reel_in
	haul_speed = other.haul_speed
