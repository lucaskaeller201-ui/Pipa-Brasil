class_name Flyer
extends RefCounted
## Um pipeiro com a sua pipa: mão, carretilha, linha, pipa e rabiola.
## O SimWorld tem uma lista de Flyers e cuida do vento, do chão e do contato
## entre as linhas de pipeiros diferentes.

const GROUND_KITE_DAMPING := 0.9  ## atrito simples da pipa encostada no chão

var id := 0
## Marca livre para o jogo (por exemplo, o índice do jogador dono da pipa).
var tag := -1
var kite: KiteBody
var line: ParticleChain          ## linha presa à mão; depois de cortada, o pedaço que ficou na mão
var tail: ParticleChain          ## null se a pipa estiver sem rabiola
var hand_position := Vector3(0.0, 1.2, 0.0)
var pilot: Pilot                 ## null = mão fixa
var input := PilotInput.new()
## Se a linha foi cortada: a pipa está "avoada", presa só ao pedaço solto.
var cut := false
var trailing_line: ParticleChain  ## pedaço de linha que ficou preso à pipa depois do corte

## Aparagem ("manda busca").
var caught_by: Flyer      ## quem enroscou esta pipa avoada (null = livre)
var caught_by_tail := false   ## enroscada pela rabiola (vem rodando, D-053)
var captured := false     ## a avoada chegou na mão de quem aparou
var lost := false         ## a avoada caiu no chão sem ninguém aparar
var holding := 0          ## quantas avoadas estão enroscadas na linha deste pipeiro
var catches := 0          ## pipas aparadas por este pipeiro

## Tensão da linha no cabresto (N), medida no último subpasso.
var tension := 0.0
## Direção da força da linha sobre a pipa (unitária).
var tension_direction := Vector3.ZERO
var kite_on_ground := false
var kite_snagged := 0.0   ## D-079: 0 solta · 1 agarrada (copa de árvore)
## Quão rápido a linha está correndo na mão (m/s): dando ou puxando linha.
## É o que decide o relo (D-027).
var line_rate := 0.0
## Segundos desde que a linha foi cortada (avoada recém-cortada não decepa).
var cut_age := 0.0
## Maior tensão recente (N), caindo devagar: diz se houve pressão antes de soltar.
var tension_memo := 0.0
## Segundos desde o último tenteio (para o relô: o tenteio serra a linha).
var tenteio_age := 99.0
var pull_age := 99.0     ## s desde a última puxada forte
var lunges := 0          ## quantas largadas (coices) deu
var _was_giving := false

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
		line_rate = absf(delta) / h + absf(pilot.arm_velocity) * 0.5
		if delta != 0.0:
			line.change_length(delta)
		hand_position = pilot.hand_position
	# Giro de dois estados (D-028): mandando linha com a mão gira; puxando trava.
	if cut or pilot == null:
		k.spin_mode = KiteBody.SpinMode.SPIN_FREE
	elif pilot.is_desbicando(t):
		k.spin_mode = KiteBody.SpinMode.SPIN_KICK
	elif input.haul_speed > 0.1 or input.pull > 0.05 or pilot.is_pulling(t):
		k.spin_mode = KiteBody.SpinMode.SPIN_LOCK
	elif input.haul_speed < -0.1:
		k.spin_mode = KiteBody.SpinMode.SPIN_GIVE
	else:
		k.spin_mode = KiteBody.SpinMode.SPIN_FREE
	k.towed = cut and caught_by != null
	k.towed_tail = k.towed and caught_by_tail
	k.slack_spin = not cut and (input.slack > 0.1 or input.free_spool)
	k.drifting = cut and caught_by == null and not lost
	k.give_speed = maxf(0.0, -input.haul_speed)
	k.pull_speed = maxf(0.0, input.haul_speed) if not cut else 0.0
	# Tenteio (D-037): o toque leva uma puxadinha; logo depois do pulo do bico
	# a pipa já sai andando para onde ele aponta.
	if not cut and tenteio_age > 0.04 and tenteio_age < 0.25:
		k.pull_speed = maxf(k.pull_speed, 1.5)   # puxadinha curta (D-042, D-054)
	k.line_dir = (k.position - hand_position).normalized() if not cut else Vector3.UP
	# Largada (D-042): puxou forte e logo em seguida mandou linha: coice.
	if not cut and input.haul_speed > 2.5:
		pull_age = 0.0
	else:
		pull_age += h
	if not cut and k.spin_mode == KiteBody.SpinMode.SPIN_GIVE and not _was_giving and pull_age < 0.5:
		k.lunge = KiteBody.LUNGE_TIME
		lunges += 1
	_was_giving = k.spin_mode == KiteBody.SpinMode.SPIN_GIVE
	k.pull_taut = tension > 1.0
	# Sentido do giro do desbico, para o bico ir para o lado pedido no céu.
	if k.spin_mode == KiteBody.SpinMode.SPIN_KICK:
		var n := k.rotation * Vector3(0.0, 0.0, 1.0)
		var linha := (k.position - hand_position).normalized()
		var cima := (Vector3.UP - linha * Vector3.UP.dot(linha)).normalized()
		var direita := linha.cross(cima).normalized()
		var bico := k.rotation * Vector3.UP
		var s := signf(n.cross(bico).dot(direita))
		k.kick_sign = input.kick_side * (s if s != 0.0 else 1.0)
		if input.kick_spin != 0.0:
			k.kick_sign = signf(input.kick_spin)   # volta: continua no mesmo sentido (D-039)
		k.kick_scale = input.kick_scale
		k.kick_base_shift = input.kick_base_shift
	# Memória da pressão: para a largada (puxa, e solta de uma vez no relô).
	tension_memo = maxf(tension, tension_memo - 6.0 * h)
	tenteio_age = 0.0 if k.spin_mode == KiteBody.SpinMode.SPIN_KICK else tenteio_age + h
	k.since_kick = tenteio_age
	if cut:
		cut_age += h
	k.update_flex(tension if not cut else 0.0, h)
	k.compute_aero(wind, t)
	k.integrate(h)
	for c in chains():
		c.compute_forces(wind, t)
		c.integrate(h)
	if line != null:
		line.pos[0] = hand_position


## Restrições internas: segmentos, alcance, cabresto, rabiola.
## D-085: passadas extras nas linhas antes da passada normal. Com menos
## subpassos (o jogo usa 2) a linha esticava mais: barriga e "V" perto do
## cabresto. Passadas a mais só nas linhas são baratas.
var extra_sweeps := 0


func solve_internal(h: float) -> void:
	var d := kite.definition
	for k in extra_sweeps:
		if line != null:
			line.pos[0] = hand_position
			line.solve_segments(h)
		if tail != null:
			tail.solve_segments(h)
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


## D-079: linha, rabiola e pipa contra os obstáculos do cenário. A pipa é
## empurrada para fora pelos 4 pontos da armação; numa copa de árvore (atrito
## baixo) ela agarra: quase para, até ser puxada com força.
func solve_obstacles(obs: Obstacles) -> void:
	for c in chains():
		c.solve_obstacles(obs)
	kite_snagged = 0.0
	for c in kite.definition.corners:
		var wp := kite.world_point(c)
		if wp.y > obs.altura_max:
			continue
		var ct := obs.contato(wp)
		if ct.is_empty():
			continue
		_push_kite(c, ct[0], float(ct[1]))
		kite_snagged = maxf(kite_snagged, 1.0 - float(ct[2]))


func end_substep(h: float) -> void:
	for c in chains():
		c.update_velocities(h)
	kite.update_velocities(h)
	if kite_on_ground:
		kite.velocity = Vector3(kite.velocity.x * GROUND_KITE_DAMPING, kite.velocity.y, kite.velocity.z * GROUND_KITE_DAMPING)
		kite.angular_velocity *= GROUND_KITE_DAMPING
	if kite_snagged > 0.0:
		# encostada/agarrada: atrito do telhado ou da copa da árvore
		var fica := 1.0 - 0.6 * kite_snagged
		kite.velocity *= fica
		kite.angular_velocity *= fica


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
