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


func step(dt: float) -> void:
	var h := dt / substeps
	for i in substeps:
		_substep(h)
		time += h


func _substep(h: float) -> void:
	var t := time
	for f in flyers:
		(f as Flyer).begin_substep(wind, t, h)
	for c in loose_chains:
		(c as ParticleChain).compute_forces(wind, t)
		(c as ParticleChain).integrate(h)
	for f in flyers:
		(f as Flyer).solve_internal(h)
	for c in loose_chains:
		(c as ParticleChain).solve_segments(h)
	combat.solve(flyers, loose_chains, h)
	for f in flyers:
		(f as Flyer).solve_ground()
	for c in loose_chains:
		(c as ParticleChain).solve_ground()
	for f in flyers:
		(f as Flyer).end_substep(h)
	for c in loose_chains:
		(c as ParticleChain).update_velocities(h)
	combat.check_breaks(flyers, loose_chains)


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
