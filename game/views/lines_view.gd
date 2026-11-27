extends MeshInstance3D
## Desenha cadeias de pontos (linha, rabiola) e setas de força.
## D-086: tudo vai para listas de vértices e sobe de uma vez numa ArrayMesh no
## fim do quadro (uma superfície só) — chamar vértice por vértice era lento
## no celular.
## As cadeias são desenhadas como fitas viradas para a câmera, com uma largura
## mínima na tela: uma linha de 0,6 mm a 50 m continua visível (D-017).

var _am := ArrayMesh.new()
var _tv := PackedVector3Array()   ## triângulos
var _tc := PackedColorArray()
var _lv := PackedVector3Array()   ## segmentos (setas)
var _lc := PackedColorArray()
var _marcado := false
var _material := StandardMaterial3D.new()

## Posição da câmera e largura mínima (m de largura por m de distância).
## Atualizadas pelo laboratório a cada quadro.
var camera_position := Vector3.ZERO
var min_width_per_meter := 0.002


func _init() -> void:
	mesh = _am
	_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_material.vertex_color_use_as_albedo = true
	_material.no_depth_test = false
	_material.cull_mode = BaseMaterial3D.CULL_DISABLED
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF


func limpar() -> void:
	_tv.clear()
	_tc.clear()
	_lv.clear()
	_lc.clear()
	_marcar()


func _marcar() -> void:
	if not _marcado:
		_marcado = true
		_enviar.call_deferred()


## Sobe as listas para a malha (uma vez por quadro).
func _enviar() -> void:
	_marcado = false
	_am.clear_surfaces()
	for par in [[_tv, _tc, Mesh.PRIMITIVE_TRIANGLES], [_lv, _lc, Mesh.PRIMITIVE_LINES]]:
		var v: PackedVector3Array = par[0]
		if v.is_empty():
			continue
		var arr := []
		arr.resize(Mesh.ARRAY_MAX)
		arr[Mesh.ARRAY_VERTEX] = v
		arr[Mesh.ARRAY_COLOR] = par[1]
		_am.add_surface_from_arrays(par[2], arr)
		_am.surface_set_material(_am.get_surface_count() - 1, _material)


func _tri(a: Vector3, b: Vector3, c: Vector3, cor: Color) -> void:
	_tv.append(a)
	_tv.append(b)
	_tv.append(c)
	_tc.append(cor)
	_tc.append(cor)
	_tc.append(cor)


## Desenha a cadeia como fita. `largura` é a largura real (m); a fita nunca fica
## mais fina que `min_width_per_meter` × distância até a câmera.
func desenhar_cadeia(pontos: PackedVector3Array, cor: Color, largura := 0.0006, minimo := 1.0, suave := 4) -> void:
	if pontos.size() < 2:
		return
	# D-073: curva suave passando pelos pontos da física (Catmull-Rom) e fita
	# contínua nas emendas — sem os "V" nos nós. Só desenho: os pontos são os
	# da simulação, nada é mexido nela.
	var p := suavizar(pontos, suave) if suave > 1 else pontos   # D-085: menos pontos nas linhas dos bots
	_marcar()
	var lados := PackedVector3Array()
	lados.resize(p.size())
	for i in p.size():
		var dir := p[mini(i + 1, p.size() - 1)] - p[maxi(i - 1, 0)]
		lados[i] = _lado(p[i], dir if dir.length_squared() > 1e-12 else Vector3.UP, largura, minimo)
	for i in p.size() - 1:
		var a := p[i]
		var b := p[i + 1]
		if (b - a).length_squared() < 1e-12:
			continue
		var la := lados[i]
		var lb := lados[i + 1]
		_tri(a - la, a + la, b + lb, cor)
		_tri(a - la, b + lb, b - lb, cor)


## Pontos intermediários numa curva Catmull-Rom (passa por todos os pontos).
static func suavizar(pontos: PackedVector3Array, por_trecho := 4) -> PackedVector3Array:
	var n := pontos.size()
	if n < 3:
		return pontos
	var saida := PackedVector3Array()
	for i in n - 1:
		var p0 := pontos[maxi(i - 1, 0)]
		var p1 := pontos[i]
		var p2 := pontos[i + 1]
		var p3 := pontos[mini(i + 2, n - 1)]
		for k in por_trecho:
			var t := float(k) / por_trecho
			var t2 := t * t
			var t3 := t2 * t
			saida.append(0.5 * ((2.0 * p1) + (-p0 + p2) * t + (2.0 * p0 - 5.0 * p1 + 4.0 * p2 - p3) * t2 + (-p0 + 3.0 * p1 - 3.0 * p2 + p3) * t3))
	saida.append(pontos[n - 1])
	return saida


func _lado(p: Vector3, dir: Vector3, largura: float, minimo := 1.0) -> Vector3:
	var para_camera := camera_position - p
	var lado := dir.cross(para_camera)
	if lado.length_squared() < 1e-10:
		lado = dir.cross(Vector3.UP)
	var meia := 0.5 * maxf(largura, minimo * min_width_per_meter * para_camera.length())
	return lado.normalized() * meia


## Rabiola de fitinhas (D-043): em cada pedaço da rabiola, duas fitinhas curtas
## amarradas atravessadas, alternando as cores e balançando com o vento.
func desenhar_fitinhas(pontos: PackedVector3Array, cores: Array, tempo: float) -> void:
	if pontos.size() < 2 or cores.is_empty():
		return
	_marcar()
	var k := 0
	for i in range(1, pontos.size()):
		var a := pontos[i - 1]
		var b := pontos[i]
		var dir := b - a
		if dir.length_squared() < 1e-8:
			continue
		dir = dir.normalized()
		for parte in 2:
			var p := a.lerp(b, (parte + 0.5) / 2.0)
			var para_camera := camera_position - p
			var lado := dir.cross(para_camera)
			if lado.length_squared() < 1e-10:
				continue
			lado = lado.normalized()
			# fitinha no tamanho de verdade (D-048): de longe ela some, como na
			# vida real, e fica só o barbante fininho
			var px := min_width_per_meter * 0.5 * para_camera.length()
			var comprimento := 0.05
			var largura := 0.012
			if comprimento < 1.2 * px:
				k += 1
				continue
			var ang := sin(tempo * 11.0 + k * 1.9) * 0.6
			var eixo := lado * cos(ang) + dir * sin(ang)
			var w := dir * (largura * 0.5)
			var cf: Color = cores[k % cores.size()]
			var p1 := p - eixo * comprimento
			var p2 := p + eixo * comprimento
			_tri(p1 - w, p1 + w, p2 + w, cf)
			_tri(p1 - w, p2 + w, p2 - w, cf)
			k += 1


## Desenha várias setas (origem, vetor) numa única superfície.
func desenhar_setas(setas: Array, cores: Array) -> void:
	if setas.is_empty():
		return
	_marcar()
	for i in setas.size():
		var origem: Vector3 = setas[i][0]
		var vetor: Vector3 = setas[i][1]
		var tamanho := vetor.length()
		if tamanho < 0.02:
			continue
		var fim := origem + vetor
		var dir := vetor / tamanho
		var lado := dir.cross(Vector3.UP)
		if lado.length() < 0.1:
			lado = dir.cross(Vector3.RIGHT)
		lado = lado.normalized() * minf(0.15, tamanho * 0.25)
		var recuo := dir * minf(0.3, tamanho * 0.3)
		var cs: Color = cores[i]
		for p in [origem, fim, fim, fim - recuo + lado, fim, fim - recuo - lado]:
			_lv.append(p)
			_lc.append(cs)
