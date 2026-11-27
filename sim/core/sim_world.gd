class_name SimWorld
extends RefCounted
## KitePhysicsCore: um mundo de simulação com vento, um ou mais pipeiros
## (Flyer: pipa, linha, rabiola, mão e carretilha), pedaços de linha soltos e
## o combate virtual entre linhas.
##
## Tudo em passo fixo: step(dt) divide dt em `substeps` subpassos e, em cada
## um, aplica forças, integra e resolve as restrições (XPBD com passos
## pequenos). Nada aqui depende de nós ou cenas do Godot.
##
## Os campos `kite`, `line`, `tail`, `pilot`, `input`, `hand_position` e
## `tension` são atalhos para o primeiro pipeiro (flyers[0]).

const LINE_MASS_PER_METER := 0.0003   ## kg/m (linha de náilon fina)
const LINE_STIFFNESS := 600.0         ## N: rigidez axial EA
const LINE_DIAMETER := 0.0006         ## m
const LINE_DRAG_COEFFICIENT := 1.1
const TAIL_STIFFNESS := 200.0         ## N
const TARGET_SEGMENT_LENGTH := 1.25   ## m

var wind: WindField
var flyers: Array = []          ## Array[Flyer]
var loose_chains: Array = []    ## pedaços de linha soltos (Array[ParticleChain])
var combat := KiteCombatSystem.new()
var obstacles: Obstacles = null   ## D-079: casas, postes, árvores (null = campo aberto)
var substeps := 4
var time := 0.0

# Atalhos para o primeiro pipeiro.
var kite: KiteBody:
	get:
		return flyers[0].kite
var line: ParticleChain:
	get:
		return flyers[0].line
var tail: ParticleChain:
	get:
		return flyers[0].tail
var pilot: Pilot:
	get:
		return flyers[0].pilot
var input: PilotInput:
	get:
		return flyers[0].input
var hand_position: Vector3:
	get:
		return flyers[0].hand_position
var tension: float:
	get:
		return flyers[0].tension
var tension_direction: Vector3:
	get:
		return flyers[0].tension_direction
var kite_on_ground: bool:
	get:
		return flyers[0].kite_on_ground


## Cria um mundo com um voo pronto para começar: a linha esticada com o
## comprimento dado, na elevação e no azimute (graus) indicados, a pipa virada
## para o pipeiro. Com with_pilot, a mão começa na posição de descanso do braço.
## pre_tension (N) encurta a linha no lançamento para ela já sair esticada.
static func create_flight(p_wind: WindField, definition: KiteDefinition, line_length := 30.0,
		elevation_deg := 30.0, azimuth_deg := 0.0, p_substeps := 4, with_pilot := false,
		pre_tension := 0.0) -> SimWorld:
	var w := SimWorld.new()
	w.wind = p_wind
	w.substeps = p_substeps
	w.add_flyer(definition, Vector3.ZERO, line_length, elevation_deg, azimuth_deg, with_pilot, pre_tension)
	return w


## Acrescenta um pipeiro em `ground_position` (o chão onde ele está) e devolve-o.
func add_flyer(definition: KiteDefinition, ground_position: Vector3, line_length := 30.0,
		elevation_deg := 30.0, azimuth_deg := 0.0, with_pilot := false, pre_tension := 0.0) -> Flyer:
	var f := Flyer.new()
	f.id = flyers.size()
	f.kite = KiteBody.new(definition)
	if with_pilot:
		f.pilot = Pilot.new()
		f.pilot.base = ground_position
		f.pilot.hand_position += ground_position
		f.hand_position = f.pilot.hand_position
	else:
		f.hand_position = ground_position + Vector3(0.0, 1.2, 0.0)

	var e := deg_to_rad(elevation_deg)
	var az := deg_to_rad(azimuth_deg)
	var dir := Vector3(cos(e) * sin(az), sin(e), -cos(e) * cos(az))
	var bridle := f.hand_position + dir * line_length
	var rot := Quaternion(Vector3.UP, -az) * Quaternion(Vector3.RIGHT, -e)
	f.kite.reset_pose(bridle - rot * definition.tow_point, rot)

	var segments := clampi(ceili(line_length / TARGET_SEGMENT_LENGTH), 8, 80)
	f.line = ParticleChain.new(ParticleChain.Kind.LINE, f.hand_position, bridle, segments,
		LINE_MASS_PER_METER * line_length, 1.0 / LINE_STIFFNESS, LINE_DIAMETER, LINE_DRAG_COEFFICIENT)
	f.line.inv_mass[0] = 0.0  # presa na mão
	if pre_tension > 0.0:
		f.line.scale_rest(1.0 - pre_tension / LINE_STIFFNESS)

	if definition.tail_enabled:
		var ta := f.kite.world_point(definition.tail_attach)
		f.tail = ParticleChain.new(ParticleChain.Kind.TAIL, ta, ta + Vector3(0.0, -definition.tail_length, 0.0),
			definition.tail_segments, definition.tail_mass, 1.0 / TAIL_STIFFNESS,
			definition.tail_width, definition.tail_drag_coefficient)
	flyers.append(f)
	return f


## Linha presa entre dois pontos fixos (um fio entre postes, uma linha de outra
## pipa enroscada num obstáculo). Colide com as linhas e rabiolas dos
## pipeiros, pode ser desgastada e romper. Devolve a cadeia criada.
func add_fixed_line(a: Vector3, b: Vector3, segments := 24) -> ParticleChain:
	var c := ParticleChain.new(ParticleChain.Kind.LINE, a, b, segments,
		LINE_MASS_PER_METER * a.distance_to(b), 1.0 / LINE_STIFFNESS, LINE_DIAMETER, LINE_DRAG_COEFFICIENT)
	c.inv_mass[0] = 0.0
	c.inv_mass[segments] = 0.0
	loose_chains.append(c)
	return c


## Tira um pipeiro do mundo (por exemplo, uma avoada já aparada ou perdida).
## Os índices (id) dos outros são renumerados.
func remove_flyer(f: Flyer) -> void:
	combat.forget(f)
	flyers.erase(f)
	for i in flyers.size():
		(flyers[i] as Flyer).id = i


func step(dt: float) -> void:
	var h := dt / substeps
	for i in substeps:
		_ultimo_subpasso = i == substeps - 1
		ParticleChain.reusar_vento = leve and i > 0
		combat.reusar_pares = leve and i > 0
		combat._leve_proximo = leve
		_substep(h)
		time += h
	ParticleChain.reusar_vento = false
	combat.reusar_pares = false


## D-086: modo leve do jogo — o vento nas linhas e a lista de pares de
## segmentos que podem se tocar são calculados no 1º subpasso de cada passo e
## reaproveitados nos outros (1/60 s: o vento quase não muda; a lista é feita
## com folga de 0,5 m e o contato em si continua exato). Os testes de física
## rodam sem isso (trajetória de referência intacta).
var leve := false


## D-082: os obstáculos (casas, postes, árvores) são resolvidos no último
## subpasso de cada passo: num passo (8 ms) quase nada entra neles, e era 1/3
## do tempo da física.
var _ultimo_subpasso := true


## D-082: medição de onde vai o tempo da física (liga só em teste).
var medir := false
var perfil := {}


func _marca(nome: String, t0: int) -> int:
	var t := Time.get_ticks_usec()
	perfil[nome] = int(perfil.get(nome, 0)) + (t - t0)
	return t


func _substep(h: float) -> void:
	var t := time
	var m := Time.get_ticks_usec() if medir else 0
	for f in flyers:
		var fl: Flyer = f
		if fl.micro > 1:
			var hm := h / fl.micro
			for k in fl.micro - 1:
				fl.begin_substep(wind, t + k * hm, hm)
				fl.solve_internal(hm)
				fl.solve_ground()
				fl.end_substep(hm)
			fl.begin_substep(wind, t + (fl.micro - 1) * hm, hm)
		else:
			fl.begin_substep(wind, t, h)
	for c in loose_chains:
		(c as ParticleChain).compute_forces(wind, t)
		(c as ParticleChain).integrate(h)
	if medir:
		m = _marca("forças e integração", m)
	for f in flyers:
		(f as Flyer).solve_internal(h / (f as Flyer).micro)
	for c in loose_chains:
		(c as ParticleChain).solve_segments(h)
	if medir:
		m = _marca("restrições (linha, pipa)", m)
	combat.solve(flyers, loose_chains, h)
	if medir:
		m = _marca("contato entre linhas", m)
	for f in flyers:
		(f as Flyer).solve_ground()
	for c in loose_chains:
		(c as ParticleChain).solve_ground()
	if obstacles != null and _ultimo_subpasso and not obstacles.vazio():
		for f in flyers:
			(f as Flyer).solve_obstacles(obstacles)
		for c in loose_chains:
			(c as ParticleChain).solve_obstacles(obstacles)
	if medir:
		m = _marca("chão e obstáculos", m)
	for f in flyers:
		(f as Flyer).end_substep(h / (f as Flyer).micro)
	for c in loose_chains:
		(c as ParticleChain).update_velocities(h)
	combat.check_breaks(flyers, loose_chains)
	combat.check_snags(flyers)
	if medir:
		m = _marca("fim (velocidades, enrosco)", m)


# ---------------- medidas (primeiro pipeiro) ----------------

func bridle_position() -> Vector3:
	return flyers[0].bridle_position()


## Ângulo do cabresto acima da horizontal, visto da mão (graus).
func elevation_deg() -> float:
	return flyers[0].elevation_deg()


## Desvio lateral da pipa em relação à direção do vento (m).
func lateral_offset() -> float:
	var side := wind.direction.normalized().cross(Vector3.UP).normalized()
	return (kite.position - hand_position).dot(side)


## Comprimento atual da linha dividido pelo comprimento de repouso.
func line_stretch() -> float:
	return line.current_length() / line.rest_total()


## Comprimento de linha solto (m), o que a carretilha controla.
func line_length() -> float:
	return flyers[0].line_length()


## Dispara um comando de impulso (puxão, arrancão, desbicar) no primeiro pipeiro.
func trigger(impulse: Pilot.Impulse) -> void:
	if pilot != null:
		pilot.trigger(impulse, time)


func is_finite_state() -> bool:
	for f in flyers:
		var k: KiteBody = (f as Flyer).kite
		if not (k.position.is_finite() and k.velocity.is_finite() and k.rotation.is_finite()):
			return false
	return true
