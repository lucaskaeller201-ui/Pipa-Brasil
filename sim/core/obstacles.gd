class_name Obstacles
extends RefCounted
## Obstáculos fixos do cenário (D-079): casas, lajes, telhados, caixas d'água,
## postes, troncos e copas de árvore. A linha, a rabiola e a pipa não
## atravessam: encostam e escorregam por cima (a linha dobra no telhado) ou
## agarram (copa de árvore, atrito alto). GDScript puro, sem nós.
##
## Formas simples: caixa alinhada aos eixos, bola e haste (cápsula). Uma grade
## no plano (células de CELULA m) guarda o que há em cada lugar, e tudo acima
## de `altura_max` é pulado de cara — a maior parte da linha está no alto.
##
## Atrito: fração do movimento ao longo da superfície que sobra em cada
## contato (1 = liso, 0 = gruda).

const CELULA := 8.0

var caixas: Array = []   ## [mín: Vector3, máx: Vector3, atrito]
var bolas: Array = []    ## [centro: Vector3, raio, atrito]
var hastes: Array = []   ## [a: Vector3, b: Vector3, raio, atrito]
## telhados de duas águas: [mín, máx, cumeeira ao longo de x?, altura, meio vão, atrito]
var telhados: Array = []
## D-080: fios dos postes, em pedacinhos retos [a, b]. A linha (segmento a
## segmento, não só nos pontos) enrosca neles: atrito alto, agarra.
var fios: Array = []
var fios_altura_max := -INF
const FIO_RAIO := 0.08
const FIO_ATRITO := 0.15
var altura_max := 0.0
var _grade := {}         ## Vector2i -> Array de [tipo (0 caixa, 1 bola, 2 haste), índice]


func vazio() -> bool:
	return caixas.is_empty() and bolas.is_empty() and hastes.is_empty() and telhados.is_empty() and fios.is_empty()


func add_fio(a: Vector3, b: Vector3) -> void:
	fios.append([a, b])
	fios_altura_max = maxf(fios_altura_max, maxf(a.y, b.y) + 0.5)
	var pad := Vector3.ONE * 1.5   # a linha de um lado pega o fio do outro lado da célula
	_registrar(4, fios.size() - 1, Vector3(minf(a.x, b.x), minf(a.y, b.y), minf(a.z, b.z)) - pad,
		Vector3(maxf(a.x, b.x), maxf(a.y, b.y), maxf(a.z, b.z)) + pad)


## Telhado de duas águas (D-079): `base` é o meio do pé do telhado (em cima
## das paredes); `vao` é a largura que as águas cobrem, `comprimento` vai ao
## longo da cumeeira (eixo x se `ao_longo_x`, senão z).
func add_telhado(base: Vector3, vao: float, altura: float, comprimento: float, ao_longo_x: bool, atrito := 0.5) -> void:
	var meio := Vector3(comprimento * 0.5, 0.0, vao * 0.5) if ao_longo_x else Vector3(vao * 0.5, 0.0, comprimento * 0.5)
	var mn := base - meio
	var mx := base + meio + Vector3(0.0, altura, 0.0)
	telhados.append([mn, mx, ao_longo_x, altura, vao * 0.5, atrito])
	_registrar(3, telhados.size() - 1, mn, mx)


func add_caixa(centro: Vector3, tamanho: Vector3, atrito := 0.6) -> void:
	var mn := centro - tamanho * 0.5
	var mx := centro + tamanho * 0.5
	caixas.append([mn, mx, atrito])
	_registrar(0, caixas.size() - 1, mn, mx)


func add_bola(centro: Vector3, raio: float, atrito := 0.15) -> void:
	bolas.append([centro, raio, atrito])
	_registrar(1, bolas.size() - 1, centro - Vector3.ONE * raio, centro + Vector3.ONE * raio)


func add_haste(a: Vector3, b: Vector3, raio: float, atrito := 0.5) -> void:
	hastes.append([a, b, raio, atrito])
	var r := Vector3.ONE * raio
	_registrar(2, hastes.size() - 1, Vector3(minf(a.x, b.x), minf(a.y, b.y), minf(a.z, b.z)) - r,
		Vector3(maxf(a.x, b.x), maxf(a.y, b.y), maxf(a.z, b.z)) + r)


func _registrar(tipo: int, i: int, mn: Vector3, mx: Vector3) -> void:
	altura_max = maxf(altura_max, mx.y)
	for cx in range(floori(mn.x / CELULA), floori(mx.x / CELULA) + 1):
		for cz in range(floori(mn.z / CELULA), floori(mx.z / CELULA) + 1):
			var k := Vector2i(cx, cz)
			if not _grade.has(k):
				_grade[k] = []
			(_grade[k] as Array).append([tipo, i])


## Contato de um ponto: [normal, profundidade, atrito], ou [] se está fora.
## Se estiver dentro de mais de uma forma, devolve a de maior profundidade.
func contato(p: Vector3) -> Array:
	if p.y > altura_max:
		return []
	var lista = _grade.get(Vector2i(floori(p.x / CELULA), floori(p.z / CELULA)))
	if lista == null:
		return []
	var melhor: Array = []
	var fundo := 0.0
	for item in lista:
		var r: Array = _contato_forma(int(item[0]), int(item[1]), p)
		if not r.is_empty() and float(r[1]) > fundo:
			fundo = float(r[1])
			melhor = r
	return melhor


func _contato_forma(tipo: int, i: int, p: Vector3) -> Array:
	if tipo == 0:
		var c: Array = caixas[i]
		var mn: Vector3 = c[0]
		var mx: Vector3 = c[1]
		if p.x <= mn.x or p.x >= mx.x or p.y <= mn.y or p.y >= mx.y or p.z <= mn.z or p.z >= mx.z:
			return []
		# sai pela face mais perto (a de cima ganha empate: linha apoia no telhado)
		var faces := [[mx.y - p.y, Vector3.UP], [p.x - mn.x, Vector3.LEFT], [mx.x - p.x, Vector3.RIGHT],
			[p.z - mn.z, Vector3.FORWARD], [mx.z - p.z, Vector3.BACK], [p.y - mn.y, Vector3.DOWN]]
		var m: Array = faces[0]
		for f in faces:
			if float(f[0]) < float(m[0]) - 1e-6:
				m = f
		return [m[1], float(m[0]), float(c[2])]
	if tipo == 1:
		var b: Array = bolas[i]
		var d: Vector3 = p - (b[0] as Vector3)
		var dist := d.length()
		if dist >= float(b[1]):
			return []
		var n := d / dist if dist > 1e-6 else Vector3.UP
		return [n, float(b[1]) - dist, float(b[2])]
	if tipo == 3:
		return _contato_telhado(i, p)
	if tipo == 4:
		# ponto (canto da pipa, ponto da linha) encostando no fio
		var fa: Vector3 = fios[i][0]
		var fab: Vector3 = (fios[i][1] as Vector3) - fa
		var ft := clampf((p - fa).dot(fab) / maxf(fab.length_squared(), 1e-9), 0.0, 1.0)
		var fd: Vector3 = p - (fa + fab * ft)
		var fdist := fd.length()
		var r := FIO_RAIO * 2.0
		if fdist >= r:
			return []
		return [fd / fdist if fdist > 1e-6 else Vector3.UP, r - fdist, FIO_ATRITO]
	var hs: Array = hastes[i]
	var a: Vector3 = hs[0]
	var ab: Vector3 = (hs[1] as Vector3) - a
	var t := clampf((p - a).dot(ab) / maxf(ab.length_squared(), 1e-9), 0.0, 1.0)
	var d2: Vector3 = p - (a + ab * t)
	var dist2 := d2.length()
	if dist2 >= float(hs[2]):
		return []
	var n2 := d2 / dist2 if dist2 > 1e-6 else Vector3.UP
	return [n2, float(hs[2]) - dist2, float(hs[3])]


func _contato_telhado(i: int, p: Vector3) -> Array:
	var t: Array = telhados[i]
	var mn: Vector3 = t[0]
	var mx: Vector3 = t[1]
	if p.x <= mn.x or p.x >= mx.x or p.y <= mn.y or p.y >= mx.y or p.z <= mn.z or p.z >= mx.z:
		return []
	var ao_longo_x: bool = t[2]
	var h: float = t[3]
	var meio_vao: float = t[4]
	var centro := (mn + mx) * 0.5
	var lat := (p.z - centro.z) if ao_longo_x else (p.x - centro.x)
	var y_sup := mn.y + h * (1.0 - absf(lat) / meio_vao)
	if p.y >= y_sup:
		return []
	# sai pela água do telhado (perpendicular a ela) ...
	var incl := h / meio_vao
	var s := signf(lat) if absf(lat) > 1e-6 else 1.0
	var n := (Vector3(0.0, 1.0, s * incl) if ao_longo_x else Vector3(s * incl, 1.0, 0.0)).normalized()
	var fundo := (y_sup - p.y) / sqrt(1.0 + incl * incl)
	# ... ou pela ponta (empena), se estiver mais perto
	var ao_longo := (p.x - mn.x if ao_longo_x else p.z - mn.z)
	var ate_fim := (mx.x - p.x if ao_longo_x else mx.z - p.z)
	if ao_longo < fundo:
		return [Vector3.LEFT if ao_longo_x else Vector3.FORWARD, ao_longo, float(t[5])]
	if ate_fim < fundo:
		return [Vector3.RIGHT if ao_longo_x else Vector3.BACK, ate_fim, float(t[5])]
	return [n, fundo, float(t[5])]


## D-080: segmento da linha contra os fios (a linha passa ENTRE dois pontos
## dela por cima do fio). Devolve [ponto no segmento s (0..1), normal,
## profundidade] do contato mais fundo, ou [] se não encosta.
func contato_segmento_fio(a: Vector3, b: Vector3, pa := Vector3.INF, pb := Vector3.INF) -> Array:
	if minf(a.y, b.y) > fios_altura_max:
		return []
	var meio := (a + b) * 0.5
	var lista = _grade.get(Vector2i(floori(meio.x / CELULA), floori(meio.z / CELULA)))
	if lista == null:
		return []
	var melhor: Array = []
	var fundo := 0.0
	for item in lista:
		if int(item[0]) != 4:
			continue
		var f: Array = fios[int(item[1])]
		var r := _mais_perto_segmentos(a, b, f[0], f[1])
		var d: Vector3 = (r[2] as Vector3) - (r[3] as Vector3)
		var n := d.normalized() if d.length() > 1e-6 else Vector3.UP
		# de que lado do fio a linha estava no começo do subpasso: se passou
		# para o outro lado (fio fino, passo de tempo), volta para o de antes
		if pa != Vector3.INF:
			var rp := _mais_perto_segmentos(pa, pb, f[0], f[1])
			var dp: Vector3 = (rp[2] as Vector3) - (rp[3] as Vector3)
			if dp.length() > 1e-6 and dp.length() < 1.0:
				n = dp.normalized()
		var lado := d.dot(n)   # distância do fio, medida para o lado de antes
		if lado < FIO_RAIO and FIO_RAIO - lado > fundo and d.length() < 1.0:
			fundo = FIO_RAIO - lado
			melhor = [float(r[0]), n, fundo]
	return melhor


## Pontos mais perto entre os segmentos p1-q1 e p2-q2: [s, t, c1, c2].
static func _mais_perto_segmentos(p1: Vector3, q1: Vector3, p2: Vector3, q2: Vector3) -> Array:
	var d1 := q1 - p1
	var d2 := q2 - p2
	var r := p1 - p2
	var a := d1.dot(d1)
	var e := d2.dot(d2)
	var f := d2.dot(r)
	var s := 0.0
	var t := 0.0
	if a <= 1e-9 and e <= 1e-9:
		return [0.0, 0.0, p1, p2]
	if a <= 1e-9:
		t = clampf(f / e, 0.0, 1.0)
	else:
		var c := d1.dot(r)
		if e <= 1e-9:
			s = clampf(-c / a, 0.0, 1.0)
		else:
			var b := d1.dot(d2)
			var den := a * e - b * b
			s = clampf((b * f - c * e) / den, 0.0, 1.0) if den > 1e-9 else 0.0
			t = (b * s + f) / e
			if t < 0.0:
				t = 0.0
				s = clampf(-c / a, 0.0, 1.0)
			elif t > 1.0:
				t = 1.0
				s = clampf((b - c) / a, 0.0, 1.0)
	return [s, t, p1 + d1 * s, p2 + d2 * t]


## Partícula de linha/rabiola: empurrada para fora, com atrito ao longo da
## superfície (comparando com onde estava no começo do subpasso).
func resolver(p: Vector3, anterior: Vector3) -> Vector3:
	var c := contato(p)
	if c.is_empty():
		return p
	var n: Vector3 = c[0]
	var s: Vector3 = p + n * float(c[1])
	var d := s - anterior
	var tangente := d - n * d.dot(n)
	var r := s - tangente * (1.0 - float(c[2]))
	# o atrito pode ter levado o ponto para dentro de novo (passando a
	# cumeeira, uma quina): então só empurra para fora, sem atrito
	var c2 := contato(r)
	if not c2.is_empty():
		r += (c2[0] as Vector3) * float(c2[1])
	return r
