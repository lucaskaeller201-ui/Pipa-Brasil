class_name KiteBody
extends RefCounted
## Corpo rígido da pipa (6 graus de liberdade) com aerodinâmica por painéis.
##
## Integração por posição (XPBD): a cada subpasso a pipa avança com as forças
## externas, as restrições (linha, rabiola, chão) corrigem posição e rotação,
## e as velocidades são recalculadas a partir do deslocamento.

const RHO := 1.2  ## densidade do ar, kg/m³
const GRAVITY := Vector3(0.0, -9.81, 0.0)

var definition: KiteDefinition

var position := Vector3.ZERO
var rotation := Quaternion.IDENTITY
var velocity := Vector3.ZERO
var angular_velocity := Vector3.ZERO  ## rad/s, no referencial do mundo

var _prev_rotation := Quaternion.IDENTITY
# Deslocamento acumulado no subpasso. Guardado à parte porque Vector3 usa
# precisão simples: a 100 m de altura, (posição - posição anterior) perde
# precisão e a velocidade derivada dela acumula erro.
var _step_delta := Vector3.ZERO

# Últimos valores calculados, para depuração e testes.
var last_aero_force := Vector3.ZERO
var last_aero_torque := Vector3.ZERO
var last_aoa_deg := 0.0
var last_wind := Vector3.ZERO


func _init(p_definition: KiteDefinition) -> void:
	definition = p_definition


func world_point(local_point: Vector3) -> Vector3:
	return position + rotation * local_point


func world_offset(local_point: Vector3) -> Vector3:
	return rotation * local_point


func point_velocity(world_pos: Vector3) -> Vector3:
	return velocity + angular_velocity.cross(world_pos - position)


func inv_inertia_world(v: Vector3) -> Vector3:
	var l := rotation.inverse() * v
	var i := definition.inertia
	return rotation * Vector3(l.x / i.x, l.y / i.y, l.z / i.z)


func inertia_world(v: Vector3) -> Vector3:
	var l := rotation.inverse() * v
	var i := definition.inertia
	return rotation * Vector3(l.x * i.x, l.y * i.y, l.z * i.z)


## Massa inversa generalizada de um ponto do corpo (offset r) na direção n.
func generalized_inv_mass(r: Vector3, n: Vector3) -> float:
	var rn := r.cross(n)
	return 1.0 / definition.mass + rn.dot(inv_inertia_world(rn))


## Aplica uma correção de posição (impulso posicional P) no ponto de offset r.
func apply_position_impulse(r: Vector3, impulse: Vector3) -> void:
	var dx := impulse / definition.mass
	position += dx
	_step_delta += dx
	var dtheta := inv_inertia_world(r.cross(impulse))
	var dq := Quaternion(dtheta.x, dtheta.y, dtheta.z, 0.0) * rotation
	rotation = Quaternion(
		rotation.x + 0.5 * dq.x,
		rotation.y + 0.5 * dq.y,
		rotation.z + 0.5 * dq.z,
		rotation.w + 0.5 * dq.w
	).normalized()


## Calcula força e torque aerodinâmicos (em relação ao centro de massa).
## Placa plana por painel, com o centro de pressão avançando para o lado de
## onde vem o fluxo quando o ângulo de ataque é pequeno.
func compute_aero(wind: WindField, t: float) -> void:
	var force := Vector3.ZERO
	var torque := Vector3.ZERO
	var aoa_acc := 0.0
	var area_acc := 0.0
	var d := definition
	last_wind = wind.sample(position, t)
	for i in d.panel_areas.size():
		var r := rotation * d.panel_centers[i]
		var n := rotation * d.panel_normals[i]
		var area := d.panel_areas[i]
		var va := wind.sample(position + r, t) - (velocity + angular_velocity.cross(r))
		var speed := va.length()
		if speed < 1e-6:
			continue
		var vn := va.dot(n)
		var sin_aoa := vn / speed
		var q := 0.5 * RHO * speed * speed
		var fn := n * (q * area * FlatPlate.normal_coefficient(sin_aoa) * (1.0 if vn >= 0.0 else -1.0))
		var vt := va - n * vn
		var vt_len := vt.length()
		var ft := Vector3.ZERO
		var shift := Vector3.ZERO
		if vt_len > 1e-6:
			ft = vt * (q * area * FlatPlate.CF / vt_len)
			shift = vt * (-0.25 * d.reference_chord * (1.0 - absf(sin_aoa)) / vt_len)
		var f := fn + ft
		force += f
		torque += (r + shift).cross(f)
		aoa_acc += rad_to_deg(asin(minf(1.0, absf(sin_aoa)))) * area
		area_acc += area
	last_aero_force = force
	last_aero_torque = torque
	last_aoa_deg = aoa_acc / area_acc if area_acc > 0.0 else 0.0


## Avança com as forças externas (aerodinâmica já calculada + gravidade).
func integrate(h: float) -> void:
	var m := definition.mass
	var f := last_aero_force + GRAVITY * m
	velocity += f * (h / m)
	var iw := inertia_world(angular_velocity)
	angular_velocity += inv_inertia_world(last_aero_torque - angular_velocity.cross(iw)) * h
	_prev_rotation = rotation
	_step_delta = velocity * h
	position += _step_delta
	var dq := Quaternion(angular_velocity.x, angular_velocity.y, angular_velocity.z, 0.0) * rotation
	rotation = Quaternion(
		rotation.x + 0.5 * h * dq.x,
		rotation.y + 0.5 * h * dq.y,
		rotation.z + 0.5 * h * dq.z,
		rotation.w + 0.5 * h * dq.w
	).normalized()


## Recalcula as velocidades a partir do deslocamento do subpasso.
func update_velocities(h: float) -> void:
	velocity = _step_delta / h
	var dq := rotation * _prev_rotation.inverse()
	var s := 2.0 / h if dq.w >= 0.0 else -2.0 / h
	angular_velocity = Vector3(dq.x, dq.y, dq.z) * s


## Começa o estado do zero (sem velocidade), na pose dada.
func reset_pose(p_position: Vector3, p_rotation: Quaternion) -> void:
	position = p_position
	rotation = p_rotation.normalized()
	velocity = Vector3.ZERO
	angular_velocity = Vector3.ZERO
	_step_delta = Vector3.ZERO
	_prev_rotation = rotation
