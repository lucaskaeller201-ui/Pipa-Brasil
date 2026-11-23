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
var rest := PackedFloat64Array()  ## m: comprimento de repouso de cada segmento
var rest_length := 0.0      ## m: comprimento nominal de um segmento
var compliance_per_meter := 0.0  ## m/N por metro de linha
var mass_per_particle := 0.0
var thickness := 0.0        ## m: diâmetro da linha ou largura da rabiola
var drag_coefficient := 1.0
## Combate virtual: desgaste por ponto do material, em faixas de WEAR_BIN
## metros contadas a partir da ponta de fora (lado da pipa). Essa coordenada
## não muda quando a carretilha solta ou enrola linha (isso acontece na mão).
const WEAR_BIN := 0.05
var wear_bins := {}   ## faixa (int) -> desgaste acumulado (float)
var strength := 1.0   ## desgaste em que a linha rompe

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
	rest.resize(segments)
	mass_per_particle = total_mass / segments
	for i in n:
		pos[i] = start.lerp(end, float(i) / segments)
		prev[i] = pos[i]
		vel[i] = Vector3.ZERO
		inv_mass[i] = segments / total_mass
	rest_length = start.distance_to(end) / segments
	for i in segments:
		rest[i] = rest_length
	self.compliance_per_meter = compliance_per_meter
	thickness = p_thickness
	drag_coefficient = p_drag_coefficient


func size() -> int:
	return pos.size()


func rest_total() -> float:
	var total := 0.0
	for r in rest:
		total += r
	return total


## Muda o comprimento da linha no segmento da mão (índice 0), como uma
## carretilha: positivo solta linha, negativo recolhe. Cria ou remove nós
## para manter os segmentos perto do comprimento nominal.
func change_length(delta: float) -> void:
	rest[0] += delta
	while rest[0] > 1.5 * rest_length:
		var a := pos[0]
		var b := pos[1]
		var r0 := rest[0]
		var novo := a.lerp(b, (r0 - rest_length) / r0)
		pos.insert(1, novo)
		prev.insert(1, novo)
		vel.insert(1, vel[1])
		inv_mass.insert(1, 1.0 / mass_per_particle)
		_forces.insert(1, Vector3.ZERO)
		rest[0] = r0 - rest_length
		rest.insert(1, rest_length)
	while rest[0] < 0.3 * rest_length and pos.size() > 3:
		rest[0] += rest[1]
		rest.remove_at(1)
		pos.remove_at(1)
		prev.remove_at(1)
		vel.remove_at(1)
		inv_mass.remove_at(1)
		_forces.remove_at(1)
	rest[0] = maxf(rest[0], 0.05)


## Coordenada no material: distância ao longo da linha, a partir da ponta de
## fora, do ponto no parâmetro s (0..1) do segmento i.
func material_coordinate(i: int, s: float) -> float:
	var total := (1.0 - s) * rest[i]
	for k in range(i + 1, rest.size()):
		total += rest[k]
	return total


## Inverso de material_coordinate: devolve Vector2(segmento, s) do ponto que
## está a `m` metros da ponta de fora. Satura nas pontas.
func locate_material(m: float) -> Vector2:
	var acumulado := 0.0
	for i in range(rest.size() - 1, -1, -1):
		if acumulado + rest[i] >= m:
			return Vector2(i, clampf(1.0 - (m - acumulado) / rest[i], 0.0, 1.0))
		acumulado += rest[i]
	return Vector2(0, 0.0)


func add_wear(i: int, s: float, amount: float) -> void:
	var faixa := floori(material_coordinate(i, s) / WEAR_BIN)
	wear_bins[faixa] = float(wear_bins.get(faixa, 0.0)) + amount


## Maior desgaste num ponto da linha.
func max_wear() -> float:
	var maior := 0.0
	for v in wear_bins.values():
		maior = maxf(maior, float(v))
	return maior


## Segmento onde está o ponto mais desgastado, ou -1 se não há desgaste.
func weakest_segment() -> int:
	if wear_bins.is_empty():
		return -1
	var pior := 0
	var maior := -1.0
	for k in wear_bins:
		if float(wear_bins[k]) > maior:
			maior = float(wear_bins[k])
			pior = int(k)
	var alvo := (pior + 0.5) * WEAR_BIN
	var acumulado := 0.0
	for i in range(rest.size() - 1, -1, -1):
		acumulado += rest[i]
		if acumulado >= alvo:
			return i
	return 0


## Rompe a cadeia no segmento `segment`. O segmento rompido é dividido ao meio
## (um ponto novo em cada pedaço), para nenhum comprimento de linha sumir.
## Esta cadeia fica com o lado da partícula 0 (a mão, na linha de um pipeiro)
## e a cadeia devolvida fica com o resto, com a ponta solta no começo.
func split(segment: int) -> ParticleChain:
	var n := pos.size()
	var corte := clampi(segment, 0, n - 2)
	var meio := pos[corte].lerp(pos[corte + 1], 0.5)
	var vel_meio := vel[corte].lerp(vel[corte + 1], 0.5)
	var metade := rest[corte] * 0.5

	var resto := ParticleChain.new(kind, meio, pos[n - 1], 1, mass_per_particle, compliance_per_meter, thickness, drag_coefficient)
	resto.strength = strength
	resto.rest_length = rest_length
	resto.mass_per_particle = mass_per_particle
	resto.pos = PackedVector3Array([meio]) + pos.slice(corte + 1)
	resto.prev = PackedVector3Array([meio]) + prev.slice(corte + 1)
	resto.vel = PackedVector3Array([vel_meio]) + vel.slice(corte + 1)
	resto.inv_mass = PackedFloat64Array([1.0 / mass_per_particle]) + inv_mass.slice(corte + 1)
	resto.rest = PackedFloat64Array([metade]) + rest.slice(corte + 1)
	resto._forces.resize(resto.pos.size())

	pos = pos.slice(0, corte + 1)
	pos.append(meio)
	prev = prev.slice(0, corte + 1)
	prev.append(meio)
	vel = vel.slice(0, corte + 1)
	vel.append(vel_meio)
	inv_mass = inv_mass.slice(0, corte + 1)
	inv_mass.append(1.0 / mass_per_particle)
	rest = rest.slice(0, corte)
	rest.append(metade)
	_forces.resize(pos.size())
	# Depois da ruptura o desgaste deixa de importar: os dois pedaços recomeçam.
	wear_bins.clear()
	return resto


## Encurta todos os segmentos por um fator (pré-tensão no lançamento).
func scale_rest(factor: float) -> void:
	for i in rest.size():
		rest[i] *= factor
	rest_length *= factor


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
	var alpha_per_meter := compliance_per_meter / (h * h)
	var first_dl := 0.0
	for i in pos.size() - 1:
		var w1 := inv_mass[i]
		var w2 := inv_mass[i + 1]
		var seg_rest := rest[i]
		var wsum := w1 + w2 + alpha_per_meter * seg_rest
		if wsum <= 0.0:
			continue
		var d := pos[i] - pos[i + 1]
		var dist := d.length()
		if dist < 1e-9:
			continue
		var n := d / dist
		var dl := -(dist - seg_rest) / wsum
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
	var limit := 0.0
	for i in range(1, pos.size()):
		limit += rest[i - 1]
		var d := pos[i] - anchor
		var dist := d.length()
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
