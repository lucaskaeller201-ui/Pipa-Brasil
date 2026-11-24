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
## Estado do giro (D-028): SPIN_FREE = física normal; SPIN_GIVE = mandando
## linha (gira direto); SPIN_LOCK = puxando (giro zerado).
enum SpinMode { SPIN_FREE, SPIN_GIVE, SPIN_LOCK, SPIN_KICK }
var spin_mode: SpinMode = SpinMode.SPIN_FREE
## Pipa avoada embolada na linha de alguém: rebocada com muito arrasto, sem girar.
var towed := false
## Velocidade com que a linha está saindo (m/s) enquanto manda linha: o giro é
## proporcional a ela (D-032).
var give_speed := 0.0
## Pipa avoada solta (ninguém aparou ainda): desce devagar, dá tempo de aparar.
var drifting := false

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

## Diedro atual (rad) da vareta flexível. Estado da pipa, não da definição.
var dihedral := 0.0


func _init(p_definition: KiteDefinition) -> void:
	definition = p_definition
	dihedral = deg_to_rad(p_definition.dihedral_max_deg)


## 0 = vareta relaxada (linha frouxa), 1 = totalmente envergada.
func bow_factor() -> float:
	var d := definition
	if not d.flex_enabled:
		return 1.0
	var dmin := deg_to_rad(d.dihedral_min_deg)
	var dmax := deg_to_rad(d.dihedral_max_deg)
	return clampf((dihedral - dmin) / (dmax - dmin), 0.0, 1.0)


## A vareta enverga rápido quando a linha estica e relaxa mais devagar.
func update_flex(tension: float, h: float) -> void:
	var d := definition
	if not d.flex_enabled:
		return
	var dmin := deg_to_rad(d.dihedral_min_deg)
	var dmax := deg_to_rad(d.dihedral_max_deg)
	var alvo := dmin + (dmax - dmin) * minf(1.0, tension / d.flex_reference_tension)
	var tau := 0.03 if alvo > dihedral else 0.4
	dihedral += (alvo - dihedral) * minf(1.0, h / tau)


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
	var sin_dh := sin(dihedral)
	var cos_dh := cos(dihedral)
	for i in d.panel_areas.size():
		var r := rotation * d.panel_centers[i]
		var n_local := d.panel_normals[i]
		if d.flex_enabled:
			n_local = Vector3(d.panel_sides[i] * sin_dh, 0.0, cos_dh)
		var n := rotation * n_local
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
	torque += _spin_moments(wind, t)
	if d.side_force_coefficient > 0.0:
		# Contra a derrapagem: ar ao longo da envergadura empurra de volta.
		var x := rotation * Vector3(1.0, 0.0, 0.0)
		var vx := (last_wind - velocity).dot(x)
		force += x * (d.side_force_coefficient * 0.5 * RHO * d.total_area * absf(vx) * vx)
	last_aero_force = force
	last_aero_torque = torque
	last_aoa_deg = aoa_acc / area_acc if area_acc > 0.0 else 0.0


## Momentos em torno da normal (giro no plano da pipa). Modelo empírico com
## parâmetros por pipa: amortecimento das bordas, estabilidade direcional da
## vareta envergada e tendência de giro com a linha frouxa. Zero para pipas
## que não usam esses parâmetros (como a raia de laboratório).
func _spin_moments(wind: WindField, t: float) -> Vector3:
	var d := definition
	if d.spin_damping_quadratic == 0.0 and d.spin_damping_linear == 0.0 and d.bow_stability == 0.0 and d.spin_bias == 0.0:
		return Vector3.ZERO
	var n := rotation * Vector3(0.0, 0.0, 1.0)
	var area := d.total_area
	var va := last_wind - velocity
	var speed := va.length()
	var wn := angular_velocity.dot(n)
	var r := d.reference_chord * 0.5
	var tau := -(d.spin_damping_quadratic * 0.5 * RHO * area * r * r * r * absf(wn) * wn
		+ d.spin_damping_linear * 0.5 * RHO * maxf(speed, 1.0) * area * r * r * wn)
	var b := bow_factor()
	if d.bow_stability != 0.0 and speed > 0.5:
		var vt := va - n * va.dot(n)
		var vt_len := vt.length()
		if vt_len > 1e-3:
			var tail_dir := rotation * Vector3(0.0, -1.0, 0.0)
			var s_th := n.dot(tail_dir.cross(vt / vt_len))
			tau += d.bow_stability * b * 0.5 * RHO * speed * speed * area * d.reference_chord * s_th * (vt_len / speed)
	if d.spin_bias != 0.0:
		var vw := last_wind.length()
		tau += d.spin_bias * (1.0 - b) * (1.0 - b) * 0.5 * RHO * vw * vw * area * d.reference_chord
	return n * tau


## Avança com as forças externas (aerodinâmica já calculada + gravidade).
func integrate(h: float) -> void:
	var m := definition.mass
	var f := last_aero_force * (0.3 if towed else (0.55 if drifting else 1.0)) + GRAVITY * m
	velocity += f * (h / m)
	var iw := inertia_world(angular_velocity)
	angular_velocity += inv_inertia_world(last_aero_torque - angular_velocity.cross(iw)) * h
	if definition.spin_damping_taut > 0.0:
		# Implícito (decaimento exato): estável mesmo com amortecimento forte.
		var b := bow_factor()
		var n := rotation * Vector3(0.0, 0.0, 1.0)
		var wn := angular_velocity.dot(n)
		angular_velocity -= n * (wn * (1.0 - exp(-definition.spin_damping_taut * b * b * h)))
	if definition.spin_give_rate_deg > 0.0:
		# Giro controlado (D-028, D-030), no plano da pipa.
		var d := definition
		var nn := rotation * Vector3(0.0, 0.0, 1.0)
		var wnn := angular_velocity.dot(nn)
		var novo := wnn
		match spin_mode:
			SpinMode.SPIN_GIVE:
				var bico_cima := (rotation * Vector3.UP).dot(Vector3.UP)
				var taxa := minf(d.spin_give_rate_deg, d.spin_per_line_speed_deg * give_speed)
				var alvo := d.spin_give_sign * deg_to_rad(taxa) * (1.0 - d.spin_gravity_mod * bico_cima)
				novo = move_toward(wnn, alvo, deg_to_rad(d.spin_give_accel_deg) * h)
				if signf(novo) == signf(alvo) and absf(novo) > absf(alvo):
					novo = alvo   # o vento não passa do teto
			SpinMode.SPIN_KICK:
				# Desbico (D-031): a folga curta deixa a pipa se endireitar —
				# o bico volta para cima pelo caminho mais curto.
				var bico := rotation * Vector3.UP
				var cima := Vector3.UP - nn * Vector3.UP.dot(nn)
				if cima.length_squared() > 1e-6:
					cima = cima.normalized()
					var ang := atan2(nn.dot(bico.cross(cima)), bico.dot(cima))
					var lim := deg_to_rad(d.spin_kick_rate_deg)
					novo = clampf(ang * 8.0, -lim, lim)
			SpinMode.SPIN_LOCK:
				novo = wnn * exp(-d.spin_pull_drag * h)
			_:
				novo = wnn * exp(-d.spin_release_drag * bow_factor() * h)
		angular_velocity += nn * (novo - wnn)
	elif definition.spin_rate_max_deg > 0.0:
		var n2 := rotation * Vector3(0.0, 0.0, 1.0)
		var wn2 := angular_velocity.dot(n2)
		var lim := deg_to_rad(definition.spin_rate_max_deg)
		if absf(wn2) > lim:
			angular_velocity -= n2 * (wn2 - signf(wn2) * lim)
	if drifting:
		velocity *= exp(-0.8 * h)
		angular_velocity *= exp(-3.0 * h)
	if towed:
		# Rebocada: balança como um pêndulo amortecido, sem girar.
		angular_velocity *= exp(-20.0 * h)
		velocity *= exp(-1.5 * h)
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
	if towed:
		# Rebocada: sem giro de furacão, mesmo com os trancos do reboque.
		var lim := deg_to_rad(120.0)
		if angular_velocity.length() > lim:
			angular_velocity = angular_velocity.normalized() * lim


## Começa o estado do zero (sem velocidade), na pose dada.
func reset_pose(p_position: Vector3, p_rotation: Quaternion) -> void:
	position = p_position
	rotation = p_rotation.normalized()
	velocity = Vector3.ZERO
	angular_velocity = Vector3.ZERO
	_step_delta = Vector3.ZERO
	_prev_rotation = rotation
