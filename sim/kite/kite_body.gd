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
## Desbico para o lado (D-034): sentido do pulo do bico (+1/-1, no eixo da normal).
var kick_sign := 1.0
var kick_scale := 1.0
## Puxada (D-034): velocidade da mão puxando e se a linha está esticada; dá
## "pressão" para a pipa ir longe para os lados (e até para trás).
var pull_speed := 0.0
var pull_taut := false
## Segundos desde o último tenteio: o vento só traz o bico de volta depois de
## uma pausa (D-036), para o tenteio mudar a direção de verdade.
var since_kick := 99.0
var _hold_ang := 0.0   ## ângulo do bico guardado no fim do tenteio (rad)
## Direção da linha (da mão para a pipa), informada pelo Flyer.
var line_dir := Vector3.UP
## Coice da largada (D-042): s restantes do empurrão para a frente.
var lunge := 0.0
const LUNGE_TIME := 0.45
const LUNGE_ACCEL := 40.0       ## m/s² no começo do coice
const LUNGE_KICK := 4.0         ## m/s de tranco na hora da largada
const MURCHA_MAX_DEG := 20.0    ## tenteio: um lado da pipa "murcha" (inclina)
var _tenteio_ativo := false ## o bico está seguindo o ângulo-alvo do tenteio
var _kick_prev := false
const KICK_HOLD := 1.5 ## s: depois do último toque o bico fica onde parou
var _spin_controlado := false
var _spin_alvo := 0.0
var _spin_teto := -1.0

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
	var ar := 0.3 if towed else (0.14 if drifting else 1.0)
	if lunge > 0.0:
		# Na largada a linha corre solta e a vela não segura o ar: o vento freia
		# pouco e a pipa dispara para a frente (D-045).
		ar *= 1.0 - 0.4 * lunge / LUNGE_TIME
	var f := last_aero_force * ar + GRAVITY * m
	if lunge >= LUNGE_TIME:
		# Largada: o tranco inicial (a pressão guardada solta de uma vez).
		velocity += lunge_dir() * LUNGE_KICK
	if lunge > 0.0:
		# Largada: a pipa dá um coice para a frente (para onde o bico aponta)
		# e vai embora levando linha — nunca de volta para a mão.
		f += lunge_dir() * (m * LUNGE_ACCEL * lunge / LUNGE_TIME)
		lunge = maxf(0.0, lunge - h)
	if d_pull_assist() > 0.0 and pull_taut and pull_speed > 0.1:
		# Pressão da puxada: a pipa ganha velocidade na direção do bico.
		f += (rotation * Vector3.UP) * (d_pull_assist() * pull_speed)
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
				# acelera aos poucos até o comando, mas nunca passa dele (nem gira
				# ao contrário): vento e rabiola não fazem furacão
				var teto := absf(alvo)
				novo = clampf(move_toward(clampf(wnn, -teto, teto), alvo, deg_to_rad(d.spin_give_accel_deg) * h), -teto, teto)
				if lunge > LUNGE_TIME - 0.25:
					novo = 0.0   # no coice da largada ela vai reta antes de girar
			SpinMode.SPIN_KICK:
				# Tenteio (D-041): cada toque soma um passo fixo ao ângulo-alvo
				# do bico; o bico vai até lá suave e para exato (sem passar).
				if not _kick_prev:
					var base := _hold_ang if _tenteio_ativo else _nose_ang(nn)
					_hold_ang = wrapf(base - kick_sign * kick_scale * deg_to_rad(d.spin_kick_rate_deg), -PI, PI)
					_tenteio_ativo = true
			SpinMode.SPIN_LOCK:
				novo = 0.0   # puxando: trava seca, o bico fica onde está (D-033)
			_:
				novo = wnn * exp(-d.spin_release_drag * bow_factor() * h)
				# solta, mas sem furacão: nunca mais rápido que o teto do giro
				var teto_livre := deg_to_rad(d.spin_give_rate_deg)
				novo = clampf(novo, -teto_livre, teto_livre)
				if d.spin_return > 0.0 and not drifting and not towed and since_kick > KICK_HOLD:
					# Retorno elástico (D-035): o vento traz o bico para cima.
					var bico := rotation * Vector3.UP
					var cima := Vector3.UP - nn * Vector3.UP.dot(nn)
					if cima.length_squared() > 1e-6:
						cima = cima.normalized()
						var ang := atan2(nn.dot(bico.cross(cima)), bico.dot(cima))
						var volta := clampf(ang * d.spin_return, -deg_to_rad(160.0), deg_to_rad(160.0))
						novo = lerpf(novo, volta, 1.0 - exp(-8.0 * h))
		_kick_prev = spin_mode == SpinMode.SPIN_KICK
		if spin_mode == SpinMode.SPIN_GIVE or spin_mode == SpinMode.SPIN_LOCK or drifting or towed \
				or (spin_mode == SpinMode.SPIN_FREE and since_kick >= KICK_HOLD):
			_tenteio_ativo = false
		# O bico persegue o ângulo-alvo do tenteio: arco redondo e curto, para
		# exato onde os toques mandaram; toques seguidos emendam (D-041).
		var segura := _tenteio_ativo and (spin_mode == SpinMode.SPIN_KICK or spin_mode == SpinMode.SPIN_FREE)
		if segura:
			var erro := wrapf(_nose_ang(nn) - _hold_ang, -PI, PI)
			novo = clampf(erro * d.spin_kick_damp, -deg_to_rad(d.spin_kick_max_deg), deg_to_rad(d.spin_kick_max_deg))
		var girando := segura
		angular_velocity += nn * (novo - wnn)
		_spin_controlado = spin_mode != SpinMode.SPIN_FREE or segura or girando
		_spin_teto = deg_to_rad(d.spin_give_rate_deg) if spin_mode == SpinMode.SPIN_FREE and not segura and not girando else -1.0
		_spin_alvo = novo
		if spin_mode == SpinMode.SPIN_GIVE or spin_mode == SpinMode.SPIN_KICK or girando:
			# Mandando linha a pipa gira no plano dela, sem capotar: a rabiola
			# segura a face virada para o vento (sem "furacão").
			var fora := angular_velocity - nn * angular_velocity.dot(nn)
			angular_velocity -= fora * (1.0 - exp(-12.0 * h))
		if segura:
			# Tenteio de verdade (D-042): girando, um lado da pipa murcha (ela
			# inclina para o lado da curva) e o vento a leva para a frente, para
			# onde o bico está indo: curva redonda, não ponteiro de relógio.
			var bico := rotation * Vector3.UP
			var forca_giro := clampf(absf(novo) / deg_to_rad(d.spin_kick_max_deg) * 3.0, 0.0, 1.0)
			var alvo_murcha := -signf(novo) * deg_to_rad(MURCHA_MAX_DEG) * forca_giro
			var atual := roll_angle()
			angular_velocity += bico * (clampf((alvo_murcha - atual) * 8.0, -3.0, 3.0) - angular_velocity.dot(bico))
	elif definition.spin_rate_max_deg > 0.0:
		var n2 := rotation * Vector3(0.0, 0.0, 1.0)
		var wn2 := angular_velocity.dot(n2)
		var lim := deg_to_rad(definition.spin_rate_max_deg)
		if absf(wn2) > lim:
			angular_velocity -= n2 * (wn2 - signf(wn2) * lim)
	if drifting:
		# Avoada vai embora devagar (D-038): dá tempo de correr atrás e aparar.
		velocity *= exp(-3.5 * h)
		angular_velocity *= exp(-6.0 * h)
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
	if _spin_controlado:
		# Giro comandado (D-028/D-032): as restrições da linha e da rabiola não
		# podem acelerar o giro no plano da pipa além do comando.
		var n := rotation * Vector3(0.0, 0.0, 1.0)
		var wn := angular_velocity.dot(n)
		var correcao := (_spin_alvo - wn) * h
		rotation = (Quaternion(n, correcao) * rotation).normalized()
		angular_velocity += n * (_spin_alvo - wn)
		_spin_controlado = false
	elif _spin_teto > 0.0:
		# Solta: a física (rabiola, cabresto) age livre, só sem passar do teto.
		var n2 := rotation * Vector3(0.0, 0.0, 1.0)
		var wn2 := angular_velocity.dot(n2)
		if absf(wn2) > _spin_teto:
			var alvo2 := signf(wn2) * _spin_teto
			rotation = (Quaternion(n2, (alvo2 - wn2) * h) * rotation).normalized()
			angular_velocity += n2 * (alvo2 - wn2)
		_spin_teto = -1.0
	if towed:
		# Aparada vindo para a mão: vem reta, sem girar no próprio plano (D-037).
		var n3 := rotation * Vector3(0.0, 0.0, 1.0)
		var wn3 := angular_velocity.dot(n3)
		rotation = (Quaternion(n3, -wn3 * h) * rotation).normalized()
		angular_velocity -= n3 * wn3
	if towed or drifting:
		# Avoada ou rebocada: balança, mas sem giro de furacão.
		var lim := deg_to_rad(25.0 if towed else 90.0)
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


func d_pull_assist() -> float:
	return definition.pull_assist


## Ângulo do bico em relação ao "para cima", no plano da pipa (rad, com sinal:
## girar com velocidade positiva em torno da normal diminui este ângulo).
func _nose_ang(nn: Vector3) -> float:
	# Medido no céu (em torno da linha), não no plano da pipa: assim a pipa
	# murchar de lado não muda o ângulo do bico (D-042).
	var eixo := line_dir * (1.0 if nn.dot(line_dir) >= 0.0 else -1.0)
	if line_dir.length_squared() < 0.5:
		eixo = nn
	var bico := rotation * Vector3.UP
	bico -= eixo * bico.dot(eixo)
	var cima := Vector3.UP - eixo * Vector3.UP.dot(eixo)
	if cima.length_squared() < 1e-6 or bico.length_squared() < 1e-6:
		return 0.0
	return atan2(eixo.dot(bico.cross(cima)), bico.normalized().dot(cima.normalized()))


## Inclinação de lado (rad): quanto a face da pipa virou em torno do eixo do
## bico, em relação ao plano que contém o bico e a linha.
func roll_angle() -> float:
	var nn := rotation * Vector3(0.0, 0.0, 1.0)
	var bico := rotation * Vector3.UP
	var lado := bico.cross(line_dir)
	if lado.length_squared() < 1e-6:
		return 0.0
	# medido no mesmo sentido de girar em torno do bico (+ = girou para +)
	var s := signf(nn.dot(line_dir))
	return asin(clampf(nn.dot(lado.normalized()), -1.0, 1.0)) * (s if s != 0.0 else 1.0)


## Direção do coice da largada: para onde o bico aponta, de través da linha
## (nem para a mão, nem esticando a linha).
func lunge_dir() -> Vector3:
	var bico := rotation * Vector3.UP
	var ld := line_dir if line_dir.length_squared() > 0.5 else Vector3.ZERO
	# só a parte de lado (de través da linha): com a linha esticada é para lá
	# que a pipa consegue disparar, varrendo o céu (D-046)
	var d := bico - ld * bico.dot(ld)
	return d.normalized() if d.length_squared() > 1e-6 else bico
