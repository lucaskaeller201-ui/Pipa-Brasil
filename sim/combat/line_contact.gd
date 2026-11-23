class_name LineContact
extends RefCounted
## Contato entre segmentos de cadeias diferentes (linha × linha, linha × rabiola).
##
## Cada par de segmentos mais perto que `radius` vira uma restrição de contato
## (XPBD): as linhas se empurram, dobram uma na outra e deslizam. Para linhas
## finas e rápidas não "pularem" uma pela outra entre dois subpassos, há uma
## detecção de travessia: se o lado relativo dos dois segmentos inverteu desde
## a posição anterior, a correção empurra de volta para o lado de origem.
##
## A grade espacial (broad phase) evita testar todos os pares.

const CELL := 2.0  ## m: tamanho da célula da grade (maior que um segmento)

## Parâmetros s, t em [0, 1] dos pontos mais próximos dos segmentos p1q1 e p2q2.
static func closest_params(p1: Vector3, q1: Vector3, p2: Vector3, q2: Vector3) -> Vector2:
	var d1 := q1 - p1
	var d2 := q2 - p2
	var r := p1 - p2
	var a := d1.dot(d1)
	var e := d2.dot(d2)
	var f := d2.dot(r)
	if a < 1e-12 and e < 1e-12:
		return Vector2.ZERO
	if a < 1e-12:
		return Vector2(0.0, clampf(f / e, 0.0, 1.0))
	var c := d1.dot(r)
	if e < 1e-12:
		return Vector2(clampf(-c / a, 0.0, 1.0), 0.0)
	var b := d1.dot(d2)
	var den := a * e - b * b
	var s := clampf((b * f - c * e) / den, 0.0, 1.0) if den > 1e-12 else 0.0
	var t := (b * s + f) / e
	if t < 0.0:
		t = 0.0
		s = clampf(-c / a, 0.0, 1.0)
	elif t > 1.0:
		t = 1.0
		s = clampf((b - c) / a, 0.0, 1.0)
	return Vector2(s, t)


## Resolve o contato entre o segmento i de A e o segmento j de B.
## Devolve a força de contato (N) ou 0 se não houve contato. Se wear_k > 0,
## acumula desgaste virtual proporcional à força e ao deslizamento, no ponto
## do material de cada linha onde o contato está (veja D-015).
static func solve_pair(a: ParticleChain, i: int, b: ParticleChain, j: int, radius: float, h: float, wear_k: float) -> float:
	var p1 := a.pos[i]
	var q1 := a.pos[i + 1]
	var p2 := b.pos[j]
	var q2 := b.pos[j + 1]
	var st := closest_params(p1, q1, p2, q2)
	var s := st.x
	var t := st.y
	var ca := p1.lerp(q1, s)
	var cb := p2.lerp(q2, t)
	var d := ca - cb
	var dist := d.length()
	var n := Vector3.ZERO
	var crossed := false
	var nx := (q1 - p1).cross(q2 - p2)
	var nx_len := nx.length()
	if nx_len > 1e-9 and s > 1e-3 and s < 0.999 and t > 1e-3 and t < 0.999:
		nx /= nx_len
		var pa0 := a.prev[i].lerp(a.prev[i + 1], s)
		var pb0 := b.prev[j].lerp(b.prev[j + 1], t)
		var sd0 := (pa0 - pb0).dot(nx)
		var sd1 := d.dot(nx)
		if sd0 * sd1 < 0.0 and absf(sd0) > 1e-6:
			crossed = true
			var sinal := 1.0 if sd0 > 0.0 else -1.0
			n = nx * sinal
			dist = sd1 * sinal  # negativo: atravessou
	if not crossed:
		if dist >= radius:
			return 0.0
		if dist > 1e-9:
			n = d / dist
		elif nx_len > 1e-9:
			n = nx / nx_len
		else:
			n = Vector3.UP
	var wa := a.inv_mass[i] * (1.0 - s) * (1.0 - s) + a.inv_mass[i + 1] * s * s
	var wb := b.inv_mass[j] * (1.0 - t) * (1.0 - t) + b.inv_mass[j + 1] * t * t
	var wsum := wa + wb
	if wsum < 1e-12:
		return 0.0
	var dl := -(dist - radius) / wsum
	a.pos[i] += n * (a.inv_mass[i] * (1.0 - s) * dl)
	a.pos[i + 1] += n * (a.inv_mass[i + 1] * s * dl)
	b.pos[j] -= n * (b.inv_mass[j] * (1.0 - t) * dl)
	b.pos[j + 1] -= n * (b.inv_mass[j + 1] * t * dl)
	var force := dl / (h * h)
	if wear_k > 0.0:
		var va := a.vel[i].lerp(a.vel[i + 1], s)
		var vb := b.vel[j].lerp(b.vel[j + 1], t)
		var vrel := va - vb
		var slide := (vrel - n * vrel.dot(n)).length()
		var desgaste := wear_k * force * slide * h
		a.add_wear(i, s, desgaste)
		b.add_wear(j, t, desgaste)
	return force


## Verdadeiro se os segmentos cruzaram um pelo outro entre `prev` e `pos`
## (usado pelos testes para detectar travessias que o solver não impediu).
static func crossed_between(a: ParticleChain, i: int, b: ParticleChain, j: int) -> bool:
	var p1 := a.pos[i]
	var q1 := a.pos[i + 1]
	var p2 := b.pos[j]
	var q2 := b.pos[j + 1]
	var st := closest_params(p1, q1, p2, q2)
	var s := st.x
	var t := st.y
	if not (s > 1e-3 and s < 0.999 and t > 1e-3 and t < 0.999):
		return false
	var nx := (q1 - p1).cross(q2 - p2)
	if nx.length() < 1e-9:
		return false
	nx = nx.normalized()
	var sd0 := (a.prev[i].lerp(a.prev[i + 1], s) - b.prev[j].lerp(b.prev[j + 1], t)).dot(nx)
	var sd1 := (p1.lerp(q1, s) - p2.lerp(q2, t)).dot(nx)
	return sd0 * sd1 < 0.0 and absf(sd0) > 1e-4 and absf(sd1) > 1e-4


## Broad phase: grade espacial. Devolve pares [índice da cadeia A, seg i,
## índice da cadeia B, seg j] de cadeias com `group` diferente cujos
## segmentos (caixas envolventes, com margem) se tocam.
static func find_pairs(chains: Array, groups: PackedInt32Array, margin: float) -> Array:
	var grid := {}
	var pairs: Array = []
	var seen := {}
	for ci in chains.size():
		var c: ParticleChain = chains[ci]
		for i in c.pos.size() - 1:
			var lo := c.pos[i].min(c.pos[i + 1]) - Vector3.ONE * margin
			var hi := c.pos[i].max(c.pos[i + 1]) + Vector3.ONE * margin
			var cx0 := floori(lo.x / CELL)
			var cy0 := floori(lo.y / CELL)
			var cz0 := floori(lo.z / CELL)
			var cx1 := floori(hi.x / CELL)
			var cy1 := floori(hi.y / CELL)
			var cz1 := floori(hi.z / CELL)
			var key_seg := ci * 100000 + i
			for x in range(cx0, cx1 + 1):
				for y in range(cy0, cy1 + 1):
					for z in range(cz0, cz1 + 1):
						var key := Vector3i(x, y, z)
						if grid.has(key):
							var cell: Array = grid[key]
							for other in cell:
								var oc: int = other / 100000
								if groups[oc] == groups[ci]:
									continue
								var pk := key_seg * 1000000 + other
								if seen.has(pk):
									continue
								seen[pk] = true
								var oi: int = other % 100000
								pairs.append([oc, oi, ci, i])
							cell.append(key_seg)
						else:
							grid[key] = [key_seg]
	return pairs
