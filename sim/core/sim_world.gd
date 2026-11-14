class_name SimWorld
extends RefCounted
## KitePhysicsCore: um mundo de simulação com vento, uma pipa, a linha e a rabiola.
##
## Tudo em passo fixo: step(dt) divide dt em `substeps` subpassos e, em cada
## um, aplica forças, integra e resolve as restrições (XPBD com passos
## pequenos). Nada aqui depende de nós ou cenas do Godot.
##
## Sem piloto (pilot == null) a mão é um ponto fixo e a linha não muda de
## comprimento (laboratório da Fase 1). Com piloto, a mão e a carretilha
## seguem os comandos em `input` e em Pilot.trigger() (Fase 2).

const LINE_MASS_PER_METER := 0.0003   ## kg/m (linha de náilon fina)
const LINE_STIFFNESS := 600.0         ## N: rigidez axial EA
const LINE_DIAMETER := 0.0006         ## m
const LINE_DRAG_COEFFICIENT := 1.1
const TAIL_STIFFNESS := 200.0         ## N
const TARGET_SEGMENT_LENGTH := 1.25   ## m
const GROUND_KITE_DAMPING := 0.9      ## atrito simples da pipa encostada no chão

var wind: WindField
var kite: KiteBody
var line: ParticleChain
var tail: ParticleChain  ## null se a pipa estiver sem rabiola
var hand_position := Vector3(0.0, 1.2, 0.0)
var pilot: Pilot  ## null = mão fixa
var input := PilotInput.new()
var substeps := 4
var time := 0.0

## Tensão da linha no cabresto (N), medida no último subpasso.
var tension := 0.0
## Direção da força da linha sobre a pipa (unitária).
var tension_direction := Vector3.ZERO
var kite_on_ground := false

var _attach_dl := 0.0


## Cria um voo pronto para começar: a linha esticada com o comprimento dado,
## na elevação e no azimute (graus) indicados, a pipa virada para o pipeiro.
## Com with_pilot, a mão começa na posição de descanso do braço do pipeiro.
## pre_tension (N) encurta a linha no lançamento para ela já sair esticada.
static func create_flight(p_wind: WindField, definition: KiteDefinition, line_length := 30.0,
		elevation_deg := 30.0, azimuth_deg := 0.0, p_substeps := 4, with_pilot := false,
		pre_tension := 0.0) -> SimWorld:
	var w := SimWorld.new()
	w.wind = p_wind
	w.substeps = p_substeps
	w.kite = KiteBody.new(definition)
	if with_pilot:
		w.pilot = Pilot.new()
		w.hand_position = w.pilot.hand_position

	var e := deg_to_rad(elevation_deg)
	var az := deg_to_rad(azimuth_deg)
	var dir := Vector3(cos(e) * sin(az), sin(e), -cos(e) * cos(az))
	var bridle := w.hand_position + dir * line_length
	var rot := Quaternion(Vector3.UP, -az) * Quaternion(Vector3.RIGHT, -e)
	w.kite.reset_pose(bridle - rot * definition.tow_point, rot)

	var segments := clampi(ceili(line_length / TARGET_SEGMENT_LENGTH), 8, 80)
	w.line = ParticleChain.new(ParticleChain.Kind.LINE, w.hand_position, bridle, segments,
		LINE_MASS_PER_METER * line_length, 1.0 / LINE_STIFFNESS, LINE_DIAMETER, LINE_DRAG_COEFFICIENT)
	w.line.inv_mass[0] = 0.0  # presa na mão
	if pre_tension > 0.0:
		w.line.scale_rest(1.0 - pre_tension / LINE_STIFFNESS)

	if definition.tail_enabled:
		var ta := w.kite.world_point(definition.tail_attach)
		w.tail = ParticleChain.new(ParticleChain.Kind.TAIL, ta, ta + Vector3(0.0, -definition.tail_length, 0.0),
			definition.tail_segments, definition.tail_mass, 1.0 / TAIL_STIFFNESS,
			definition.tail_width, definition.tail_drag_coefficient)
	return w


func step(dt: float) -> void:
	var h := dt / substeps
	for i in substeps:
		_substep(h)
		time += h


func _substep(h: float) -> void:
	var t := time
	var k := kite
	var d := k.definition

	if pilot != null:
		var dir := (bridle_position() - Pilot.SHOULDER).normalized()
		var delta := pilot.update(h, t, input, dir, tension, line.rest_total())
		if delta != 0.0:
			line.change_length(delta)
		hand_position = pilot.hand_position
	k.update_flex(tension, h)

	k.compute_aero(wind, t)
	k.integrate(h)

	line.compute_forces(wind, t)
	line.integrate(h)
	if tail != null:
		tail.compute_forces(wind, t)
		tail.integrate(h)

	# Linha: mão fixa, segmentos, alcance máximo e o último nó preso ao cabresto.
	line.pos[0] = hand_position
	line.solve_segments(h)
	line.solve_max_reach()
	_attach(line, line.size() - 1, d.tow_point)
	tension = absf(_attach_dl) / (h * h)

	# Rabiola presa na base da pipa.
	if tail != null:
		_attach(tail, 0, d.tail_attach)
		tail.solve_segments(h)

	# Chão.
	line.solve_ground()
	if tail != null:
		tail.solve_ground()
	kite_on_ground = false
	for c in d.corners:
		var wp := k.world_point(c)
		if wp.y < 0.0:
			_push_kite(c, Vector3.UP, -wp.y)
			kite_on_ground = true

	# Velocidades.
	line.update_velocities(h)
	if tail != null:
		tail.update_velocities(h)
	k.update_velocities(h)
	if kite_on_ground:
		k.velocity = Vector3(k.velocity.x * GROUND_KITE_DAMPING, k.velocity.y, k.velocity.z * GROUND_KITE_DAMPING)
		k.angular_velocity *= GROUND_KITE_DAMPING


## Prende a partícula idx da cadeia ao ponto local da pipa (comprimento zero,
## rígido). Guarda o multiplicador para medir a força.
func _attach(chain: ParticleChain, idx: int, local_point: Vector3) -> void:
	_attach_dl = 0.0
	var r := kite.world_offset(local_point)
	var bp := kite.position + r
	var dv := chain.pos[idx] - bp
	var dist := dv.length()
	if dist < 1e-9:
		return
	var n := dv / dist
	var wp := chain.inv_mass[idx]
	var wb := kite.generalized_inv_mass(r, n)
	var dl := -dist / (wp + wb)
	_attach_dl = dl
	if chain == line:
		tension_direction = n
	chain.pos[idx] += n * (wp * dl)
	kite.apply_position_impulse(r, n * (-dl))


func _push_kite(local_point: Vector3, n: Vector3, depth: float) -> void:
	var r := kite.world_offset(local_point)
	var dl := depth / kite.generalized_inv_mass(r, n)
	kite.apply_position_impulse(r, n * dl)


# ---------------- medidas ----------------

func bridle_position() -> Vector3:
	return kite.world_point(kite.definition.tow_point)


## Ângulo do cabresto acima da horizontal, visto da mão (graus).
func elevation_deg() -> float:
	var d := bridle_position() - hand_position
	return rad_to_deg(atan2(d.y, Vector2(d.x, d.z).length()))


## Desvio lateral da pipa em relação à direção do vento (m).
func lateral_offset() -> float:
	var side := wind.direction.normalized().cross(Vector3.UP).normalized()
	return (kite.position - hand_position).dot(side)


## Comprimento atual da linha dividido pelo comprimento de repouso.
func line_stretch() -> float:
	return line.current_length() / line.rest_total()


## Comprimento de linha solto (m), o que a carretilha controla.
func line_length() -> float:
	return line.rest_total()


## Dispara um comando de impulso (puxão, arrancão, desbicar).
func trigger(impulse: Pilot.Impulse) -> void:
	if pilot != null:
		pilot.trigger(impulse, time)


func is_finite_state() -> bool:
	return kite.position.is_finite() and kite.velocity.is_finite() and kite.rotation.is_finite()
