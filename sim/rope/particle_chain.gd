class_name ParticleChain
extends RefCounted
## RopePhysics / TailPhysics: cadeia de partículas com XPBD.
##
## Usada para a linha (arrasto de cilindro, só a componente perpendicular do
## vento) e para a rabiola (arrasto de fita, em todas as direções).
## Cada segmento é uma restrição de distância com complacência (a linha estica
## um pouco sob tensão, como o náilon).

enum Kind { LINE, TAIL }

const GRAVITY := Vector3(0.0, -9.81, 0.0)
const RHO := 1.2
const GROUND_FRICTION := 0.5  ## fração do deslizamento mantida ao tocar o chão

var kind: Kind = Kind.LINE
var pos := PackedVector3Array()
var prev := PackedVector3Array()
var vel := PackedVector3Array()
var inv_mass := PackedFloat64Array()
var rest_length := 0.0      ## m por segmento
var compliance := 0.0       ## m/N por segmento
var thickness := 0.0        ## m: diâmetro da linha ou largura da rabiola
var drag_coefficient := 1.0

var _forces := PackedVector3Array()


func _init(p_kind: Kind, start: Vector3, end: Vector3, segments: int, total_mass: float,
		compliance_per_meter: float, p_thickness: float, p_drag_coefficient: float) -> void:
	kind = p_kind
	var n := segments + 1
	pos.resize(n)
	prev.resize(n)
	vel.resize(n)
	inv_mass.resize(n)
	_forces.resize(n)
	for i in n:
		pos[i] = start.lerp(end, float(i) / segments)
		prev[i] = pos[i]
		vel[i] = Vector3.ZERO
		inv_mass[i] = segments / total_mass
	rest_length = start.distance_to(end) / segments
	compliance = compliance_per_meter * rest_length
	thickness = p_thickness
	drag_coefficient = p_drag_coefficient


func size() -> int:
	return pos.size()


func rest_total() -> float:
	return rest_length * (pos.size() - 1)


func current_length() -> float:
	var total := 0.0
	for i in pos.size() - 1:
		total += pos[i].distance_to(pos[i + 1])
	return total


## Gravidade + arrasto do vento, distribuídos nas partículas.
func compute_forces(wind: WindField, t: float) -> void:
	var n := pos.size()
	for i in n:
		_forces[i] = GRAVITY / inv_mass[i] if inv_mass[i] > 0.0 else Vector3.ZERO
	for i in n - 1:
		var a := pos[i]
		var b := pos[i + 1]
		var seg := b - a
		var seg_len := seg.length()
		if seg_len < 1e-6:
			continue
		var e := seg / seg_len
		var mid := (a + b) * 0.5
		var vrel := wind.sample(mid, t) - (vel[i] + vel[i + 1]) * 0.5
		var fd: Vector3
		if kind == Kind.LINE:
			var vn := vrel - e * vrel.dot(e)
			fd = vn * (0.5 * RHO * drag_coefficient * thickness * seg_len * vn.length())
		else:
			fd = vrel * (0.5 * RHO * drag_coefficient * thickness * seg_len * vrel.length())
		_forces[i] += fd * 0.5
		_forces[i + 1] += fd * 0.5


func integrate(h: float) -> void:
	for i in pos.size():
		prev[i] = pos[i]
		var w := inv_mass[i]
		if w <= 0.0:
			continue
		vel[i] += _forces[i] * (h * w)
		pos[i] += vel[i] * h


## Uma passada de Gauss-Seidel nas restrições de distância.
## Devolve o multiplicador do primeiro segmento (útil para medir tensão).
func solve_segments(h: float) -> float:
	var alpha_tilde := compliance / (h * h)
	var first_dl := 0.0
	for i in pos.size() - 1:
		var w1 := inv_mass[i]
		var w2 := inv_mass[i + 1]
		var wsum := w1 + w2 + alpha_tilde
		if wsum <= 0.0:
			continue
		var d := pos[i] - pos[i + 1]
		var dist := d.length()
		if dist < 1e-9:
			continue
		var n := d / dist
		var dl := -(dist - rest_length) / wsum
		pos[i] += n * (w1 * dl)
		pos[i + 1] -= n * (w2 * dl)
		if i == 0:
			first_dl = dl
	return first_dl


## Restrição de alcance máximo a partir da partícula 0 (presa na mão):
## nenhuma partícula fica mais longe da mão do que o comprimento de linha até
## ela. Deixa a linha praticamente inextensível com custo baixo.
func solve_max_reach() -> void:
	var anchor := pos[0]
	for i in range(1, pos.size()):
		var d := pos[i] - anchor
		var dist := d.length()
		var limit := i * rest_length
		if dist > limit:
			pos[i] = anchor + d * (limit / dist)


func solve_ground() -> void:
	for i in pos.size():
		var p := pos[i]
		if p.y < 0.0:
			var q := prev[i]
			pos[i] = Vector3(q.x + (p.x - q.x) * GROUND_FRICTION, 0.0, q.z + (p.z - q.z) * GROUND_FRICTION)


func update_velocities(h: float) -> void:
	for i in pos.size():
		vel[i] = (pos[i] - prev[i]) / h


func max_speed() -> float:
	var m := 0.0
	for v in vel:
		m = maxf(m, v.length())
	return m
