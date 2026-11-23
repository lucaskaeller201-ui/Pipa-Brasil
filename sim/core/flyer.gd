class_name Flyer
extends RefCounted
## Um pipeiro com a sua pipa: mão, carretilha, linha, pipa e rabiola.
## O SimWorld tem uma lista de Flyers e cuida do vento, do chão e do contato
## entre as linhas de pipeiros diferentes.

const GROUND_KITE_DAMPING := 0.9  ## atrito simples da pipa encostada no chão

var id := 0
var kite: KiteBody
var line: ParticleChain          ## linha presa à mão; depois de cortada, o pedaço que ficou na mão
var tail: ParticleChain          ## null se a pipa estiver sem rabiola
var hand_position := Vector3(0.0, 1.2, 0.0)
var pilot: Pilot                 ## null = mão fixa
var input := PilotInput.new()
## Se a linha foi cortada: a pipa está "avoada", presa só ao pedaço solto.
var cut := false
var trailing_line: ParticleChain  ## pedaço de linha que ficou preso à pipa depois do corte

## Tensão da linha no cabresto (N), medida no último subpasso.
var tension := 0.0
## Direção da força da linha sobre a pipa (unitária).
var tension_direction := Vector3.ZERO
var kite_on_ground := false

var _attach_dl := 0.0


## Linha que está presa ao cabresto neste momento (a da mão ou o pedaço solto).
func kite_line() -> ParticleChain:
	return trailing_line if cut else line


## Todas as cadeias deste pipeiro que participam do contato entre linhas.
func chains() -> Array:
	var out: Array = []
	if line != null:
		out.append(line)
	if trailing_line != null:
		out.append(trailing_line)
	if tail != null:
		out.append(tail)
	return out


func bridle_position() -> Vector3:
	return kite.world_point(kite.definition.tow_point)


# ---------------- subpasso ----------------

func begin_substep(wind: WindField, t: float, h: float) -> void:
	var k := kite
	var d := k.definition
	if pilot != null and not cut:
		var dir := (bridle_position() - pilot.shoulder_position()).normalized()
		var delta := pilot.update(h, t, input, dir, tension, line.rest_total())
		if delta != 0.0:
			line.change_length(delta)
		hand_position = pilot.hand_position
	k.update_flex(tension if not cut else 0.0, h)
	k.compute_aero(wind, t)
	k.integrate(h)
	for c in chains():
		c.compute_forces(wind, t)
		c.integrate(h)
	if line != null:
		line.pos[0] = hand_position


## Restrições internas: segmentos, alcance, cabresto, rabiola.
func solve_internal(h: float) -> void:
	var d := kite.definition
	if line != null:
		line.pos[0] = hand_position
		line.solve_segments(h)
		line.solve_max_reach()
		if not cut:
			_attach(line, line.size() - 1, d.tow_point)
			tension = absf(_attach_dl) / (h * h)
	if cut and trailing_line != null:
		trailing_line.solve_segments(h)
		_attach(trailing_line, trailing_line.size() - 1, d.tow_point)
		tension = absf(_attach_dl) / (h * h)
	if tail != null:
		_attach(tail, 0, d.tail_attach)
		tail.solve_segments(h)


func solve_ground() -> void:
	for c in chains():
		c.solve_ground()
	kite_on_ground = false
	for c in kite.definition.corners:
		var wp := kite.world_point(c)
		if wp.y < 0.0:
			_push_kite(c, Vector3.UP, -wp.y)
			kite_on_ground = true


func end_substep(h: float) -> void:
	for c in chains():
		c.update_velocities(h)
	kite.update_velocities(h)
	if kite_on_ground:
		kite.velocity = Vector3(kite.velocity.x * GROUND_KITE_DAMPING, kite.velocity.y, kite.velocity.z * GROUND_KITE_DAMPING)
		kite.angular_velocity *= GROUND_KITE_DAMPING


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
	if chain == line or chain == trailing_line:
		tension_direction = n
	chain.pos[idx] += n * (wp * dl)
	kite.apply_position_impulse(r, n * (-dl))


func _push_kite(local_point: Vector3, n: Vector3, depth: float) -> void:
	var r := kite.world_offset(local_point)
	var dl := depth / kite.generalized_inv_mass(r, n)
	kite.apply_position_impulse(r, n * dl)


## Corta a linha no segmento `segment`. O pedaço da mão continua com o pipeiro
## (ponta solta); o pedaço da pipa vira `trailing_line` e a pipa fica avoada.
func cut_line(segment: int) -> void:
	if cut or line == null:
		return
	trailing_line = line.split(segment)
	cut = true
	tension = 0.0
	if pilot != null:
		input.clear()


# ---------------- medidas ----------------

## Ângulo do cabresto acima da horizontal, visto da mão (graus).
func elevation_deg() -> float:
	var d := bridle_position() - hand_position
	return rad_to_deg(atan2(d.y, Vector2(d.x, d.z).length()))


## Posição da pipa no céu vista pelo pipeiro: azimute (graus, + = direita de
## quem olha vento abaixo) e elevação (graus). Só o que dá para ver.
func sky_position_deg() -> Vector2:
	var d := bridle_position() - hand_position
	return Vector2(rad_to_deg(atan2(d.x, -d.z)), rad_to_deg(atan2(d.y, Vector2(d.x, d.z).length())))


## Para onde o bico aponta no céu, visto do pipeiro: 0 = para cima,
## + = para a direita, ±180 = para baixo (graus).
func nose_angle_deg() -> float:
	var bico := kite.rotation * Vector3.UP
	var linha := (kite.position - hand_position).normalized()
	var cima := (Vector3.UP - linha * Vector3.UP.dot(linha)).normalized()
	var direita := linha.cross(cima).normalized()
	return rad_to_deg(atan2(bico.dot(direita), bico.dot(cima)))


func line_length() -> float:
	return line.rest_total() if line != null else 0.0
