class_name KiteDefinition
extends Resource
## Parâmetros de um modelo de pipa.
##
## Coordenadas locais com origem no centro de massa:
##   X = envergadura (direita), Y = espinha (bico para cima),
##   Z = frente (lado do cabresto, voltado para o pipeiro).
## Cada modelo de pipa da Fase 6 será um arquivo .tres com estes campos.

@export var model_name := "Raia de laboratório"
@export var mass := 0.025                              ## kg
@export var inertia := Vector3(3.75e-4, 2.6e-4, 6.35e-4)  ## kg·m², momentos principais (X, Y, Z locais)
@export var reference_chord := 0.6                     ## m: escala do deslocamento do centro de pressão
@export var tow_point := Vector3(0.0, 0.12, 0.28)      ## cabresto: onde a linha prende
@export var tail_attach := Vector3(0.0, -0.35, 0.0)    ## onde a rabiola prende
@export var triangles := PackedVector3Array()          ## painéis: 3 vértices por triângulo
@export var corners := PackedVector3Array()            ## pontos de contato com o chão

@export_group("Vareta flexível e giro")
## Vareta transversal que enverga com a tensão: diedro entre o mínimo (linha
## frouxa) e o máximo (linha esticada). Desligado = diedro fixo da geometria.
@export var flex_enabled := false
@export var dihedral_min_deg := 2.0
@export var dihedral_max_deg := 16.0
@export var flex_reference_tension := 1.2  ## N: tensão em que a vareta enverga toda
## Estabilidade direcional da vareta envergada (alinha a espinha com o fluxo).
@export var bow_stability := 0.0
## Amortecimento do giro no plano da pipa (arrasto das bordas e varetas).
@export var spin_damping_quadratic := 0.0
@export var spin_damping_linear := 0.0
## Tendência de giro com a linha frouxa (sentido preferido da pipa; 0 = nenhum).
@export var spin_bias := 0.0
## Firmeza do giro com a linha esticada (1/s): a vareta envergada segura o bico
## onde ele está, e a pipa vai reta para onde aponta (D-024). Multiplica o
## quadrado do quanto a vareta está envergada; com a linha frouxa, some.
@export var spin_damping_taut := 0.0
## Giro máximo no plano da pipa (graus/s); 0 = sem limite. Com a linha frouxa
## a pipa gira num ritmo que dá para acompanhar (D-026).
@export var spin_rate_max_deg := 0.0
## Força lateral contra a derrapagem (ar ao longo da envergadura): a pipa não
## anda de lado; vai na direção da espinha, como uma flecha (D-026).
@export var side_force_coefficient := 0.0
## Freio ao longo do bico sem puxar (1/s, D-054): a vela solta arrasta mais e a
## pipa não dispara sozinha para onde o bico aponta; puxando, ele some.
@export var nose_drag_rate := 0.0
## D-058: o empurrão de giro (spin_bias) só vale mandando linha ou com folga
## de propósito; parada ou tenteando, a pipa não tende a rodar.
@export var spin_bias_only_giving := false
## Giro de dois estados (D-028, pedido do Lucas; 0 = desligado):
## mandando linha com a mão, o bico gira direto nesta velocidade (graus/s,
## "velocidadeGiroMandandoLinha"); puxando, o giro zera na hora (trava seca).
@export var spin_give_rate_deg := 0.0
## Sentido do giro mandando linha (+1 ou -1).
@export var spin_give_sign := -1.0
## Descarregar "redondo" (D-030): o giro acelera aos poucos (graus/s²) até o
## teto; com o bico para baixo gira mais rápido, para cima mais devagar.
@export var spin_give_accel_deg := 1200.0
## Giro por velocidade de linha saindo (graus/s por m/s): deslizar devagar
## gira devagar, rápido gira rápido, até o teto spin_give_rate_deg (D-032).
@export var spin_per_line_speed_deg := 100.0
@export var spin_gravity_mod := 0.4
## Freio do giro (1/s): ao soltar o dedo (linha volta a esticar) e ao puxar.
@export var spin_release_drag := 7.0
@export var spin_pull_drag := 25.0
## Desbico (toque, D-031): a pipa se endireita — o bico volta para cima, no
## máximo nesta velocidade (graus/s), enquanto dura a folga do toque.
## Tenteio (D-041): cada toque gira o bico este tanto (graus); 10 toques no
## mesmo sentido = uma volta. O bico chega lá suave (ganho spin_kick_damp por
## s, no máximo spin_kick_max_deg °/s) e para exato.
## D-074: medido no vídeo do Pipa Combate (30 quadros/s): cada balanço vai
## uns 40° para cada lado, gira uns 550°/s e para seco (sem passar do ponto).
## (O alvo de 30° já dá ~40° de balanço de verdade, com a puxadinha do toque.)
@export var spin_kick_rate_deg := 30.0
@export var spin_kick_damp := 20.0
@export var spin_kick_max_deg := 550.0
## Retorno elástico (D-035): solta (sem comando), o vento traz o bico de volta
## para cima com esta "mola" (1/s); 0 = desligado.
@export var spin_return := 0.0
## Pressão da puxada (N por m/s puxado, D-034): com a linha esticada, puxar
## empurra a pipa na direção do bico; deixa ir longe para os lados.
@export var pull_assist := 0.0

@export_group("Rabiola")
@export var tail_enabled := true
@export var tail_length := 2.0     ## m
@export var tail_mass := 0.006     ## kg
@export var tail_segments := 10
@export var tail_width := 0.025    ## m: largura efetiva para o arrasto
@export var tail_drag_coefficient := 0.6

# Calculados por rebuild() a partir dos triângulos.
var panel_centers := PackedVector3Array()
var panel_normals := PackedVector3Array()
var panel_areas := PackedFloat64Array()
var panel_sides := PackedFloat64Array()  ## -1 esquerda, +1 direita, 0 centro
var total_area := 0.0


## Recalcula centros, normais e áreas dos painéis. Chame após mudar triangles.
func rebuild() -> void:
	panel_centers.clear()
	panel_normals.clear()
	panel_areas.clear()
	panel_sides.clear()
	total_area = 0.0
	for i in range(0, triangles.size(), 3):
		var a := triangles[i]
		var b := triangles[i + 1]
		var c := triangles[i + 2]
		var cr := (b - a).cross(c - a)
		var area := 0.5 * cr.length()
		var n := cr.normalized()
		if n.z < 0.0:
			n = -n  # normal sempre para a frente (lado do cabresto)
		panel_centers.append((a + b + c) / 3.0)
		panel_normals.append(n)
		panel_areas.append(area)
		var cx := ((a + b + c) / 3.0).x
		panel_sides.append(-1.0 if cx < -1e-6 else (1.0 if cx > 1e-6 else 0.0))
		total_area += area


## Raia em losango de 0,60 m × 0,50 m, 25 g, com vareta transversal envergada
## (diedro) e rabiola de 2 m. Parâmetros calibrados no protótipo
## (tools/prototipo/sim_prototipo.py).
static func raia_laboratorio(dihedral_deg := 12.0) -> KiteDefinition:
	var d := KiteDefinition.new()
	var dh := deg_to_rad(dihedral_deg)
	var top := Vector3(0.0, 0.25, 0.0)
	var bottom := Vector3(0.0, -0.35, 0.0)
	var left := Vector3(-0.25 * cos(dh), 0.05, -0.25 * sin(dh))
	var right := Vector3(0.25 * cos(dh), 0.05, -0.25 * sin(dh))
	var center := Vector3(0.0, 0.05, 0.0)
	d.triangles = PackedVector3Array([
		center, top, left,
		center, right, top,
		center, left, bottom,
		center, bottom, right,
	])
	d.corners = PackedVector3Array([top, bottom, left, right])
	d.rebuild()
	return d


## Pipa do Rio (D-026): losango com vareta que enverga, rabiola de 2 m.
## Com a linha esticada segura o bico e vai reta para onde ele aponta; dando
## linha, gira num ritmo constante; um toque (puxão) trava o giro.
## Calibrada no protótipo (tools/prototipo/fase4/sim2_fase5.py, exp8/exp9).
static func pipa_rio() -> KiteDefinition:
	var d := raia_laboratorio(0.0)
	d.model_name = "Pipa do Rio"
	d.flex_enabled = true
	d.bow_stability = 0.0
	d.spin_damping_quadratic = 1.0
	d.spin_damping_linear = 0.3
	d.spin_bias = 1.0   # o sentido segue o lado do bico (D-055)
	d.spin_damping_taut = 12.0
	d.spin_rate_max_deg = 240.0
	d.side_force_coefficient = 2.0  # deixa derrapar um pouco: curvas em arco
	d.nose_drag_rate = 6.0
	d.spin_bias_only_giving = true
	d.spin_give_rate_deg = 360.0
	d.pull_assist = 0.12
	d.spin_return = 4.0
	d.flex_reference_tension = 2.5  # relaxa mais fácil ao descarregar: gira o tempo todo
	d.tail_enabled = true
	# Rabiola de verdade (D-044): comprida, fina e leve (mais fina e mais leve
	# que a linha de cortar por metro de arrasto), balança bastante.
	d.tail_length = 5.0
	d.tail_mass = 0.0075
	d.tail_segments = 24
	d.tail_width = 0.012
	d.spin_release_drag = 11.0   # a rabiola comprida embala: freia um pouco mais
	return d


## Raia de combate sem rabiola, com vareta que enverga com a tensão.
## Com a linha esticada fica parada no céu com o bico para cima e, puxada,
## avança para onde o bico aponta; com a linha frouxa a vareta relaxa e ela
## gira, o que permite desbicar. Calibrada com o bot piloto na Fase 4 (D-018):
## a estabilidade direcional da vareta ficou desligada, porque virava o bico
## para baixo com a pipa parada.
static func raia_sem_rabiola() -> KiteDefinition:
	var d := raia_laboratorio(0.0)
	d.model_name = "Raia sem rabiola"
	d.flex_enabled = true
	d.bow_stability = 0.0
	d.spin_damping_quadratic = 1.0
	d.spin_damping_linear = 0.3
	d.spin_bias = 0.3
	d.spin_damping_taut = 20.0
	d.tail_enabled = false
	return d
