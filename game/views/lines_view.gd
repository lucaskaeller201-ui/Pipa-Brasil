extends MeshInstance3D
## Desenha cadeias de pontos (linha, rabiola) e setas de força com ImmediateMesh.
## As cadeias são desenhadas como fitas viradas para a câmera, com uma largura
## mínima na tela: uma linha de 0,6 mm a 50 m continua visível (D-017).

var _im := ImmediateMesh.new()
var _material := StandardMaterial3D.new()

## Posição da câmera e largura mínima (m de largura por m de distância).
## Atualizadas pelo laboratório a cada quadro.
var camera_position := Vector3.ZERO
var min_width_per_meter := 0.002


func _init() -> void:
	mesh = _im
	_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_material.vertex_color_use_as_albedo = true
	_material.no_depth_test = false
	_material.cull_mode = BaseMaterial3D.CULL_DISABLED
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF


func limpar() -> void:
	_im.clear_surfaces()


## Desenha a cadeia como fita. `largura` é a largura real (m); a fita nunca fica
## mais fina que `min_width_per_meter` × distância até a câmera.
func desenhar_cadeia(pontos: PackedVector3Array, cor: Color, largura := 0.0006) -> void:
	if pontos.size() < 2:
		return
	_im.surface_begin(Mesh.PRIMITIVE_TRIANGLES, _material)
	_im.surface_set_color(cor)
	for i in pontos.size() - 1:
		var a := pontos[i]
		var b := pontos[i + 1]
		var dir := b - a
		if dir.length_squared() < 1e-10:
			continue
		var la := _lado(a, dir, largura)
		var lb := _lado(b, dir, largura)
		_im.surface_add_vertex(a - la)
		_im.surface_add_vertex(a + la)
		_im.surface_add_vertex(b + lb)
		_im.surface_add_vertex(a - la)
		_im.surface_add_vertex(b + lb)
		_im.surface_add_vertex(b - lb)
	_im.surface_end()


func _lado(p: Vector3, dir: Vector3, largura: float) -> Vector3:
	var para_camera := camera_position - p
	var lado := dir.cross(para_camera)
	if lado.length_squared() < 1e-10:
		lado = dir.cross(Vector3.UP)
	var meia := 0.5 * maxf(largura, min_width_per_meter * para_camera.length())
	return lado.normalized() * meia


## Rabiola de fitinhas (D-043): em cada pedaço da rabiola, fitinhas curtas
## amarradas atravessadas, alternando as cores e balançando com o vento.
func desenhar_fitinhas(pontos: PackedVector3Array, cores: Array, tempo: float) -> void:
	if pontos.size() < 2 or cores.is_empty():
		return
	_im.surface_begin(Mesh.PRIMITIVE_TRIANGLES, _material)
	var k := 0
	for i in range(1, pontos.size()):
		var a := pontos[i - 1]
		var b := pontos[i]
		var dir := b - a
		if dir.length_squared() < 1e-8:
			continue
		dir = dir.normalized()
		for parte in 3:
			var p := a.lerp(b, (parte + 0.5) / 3.0)
			var para_camera := camera_position - p
			var lado := dir.cross(para_camera)
			if lado.length_squared() < 1e-10:
				continue
			lado = lado.normalized()
			var escala := maxf(1.0, min_width_per_meter * para_camera.length() / 0.025)
			var comprimento := 0.07 * escala
			var largura := 0.03 * escala
			var ang := sin(tempo * 11.0 + k * 1.9) * 0.6
			var eixo := lado * cos(ang) + dir * sin(ang)
			var w := dir * (largura * 0.5)
			_im.surface_set_color(cores[k % cores.size()])
			var p1 := p - eixo * comprimento
			var p2 := p + eixo * comprimento
			for q in [p1 - w, p1 + w, p2 + w, p1 - w, p2 + w, p2 - w]:
				_im.surface_add_vertex(q)
			k += 1
	_im.surface_end()


## Desenha várias setas (origem, vetor) numa única superfície.
func desenhar_setas(setas: Array, cores: Array) -> void:
	if setas.is_empty():
		return
	_im.surface_begin(Mesh.PRIMITIVE_LINES, _material)
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
		_im.surface_set_color(cores[i])
		for p in [origem, fim, fim, fim - recuo + lado, fim, fim - recuo - lado]:
			_im.surface_add_vertex(p)
	_im.surface_end()
