extends MeshInstance3D
## Desenha cadeias de pontos (linha, rabiola) e setas de força com ImmediateMesh.
## Versão de laboratório: linhas de 1 pixel. A linha bonita (fita com largura
## mínima na tela) vem na Fase 3.

var _im := ImmediateMesh.new()
var _material := StandardMaterial3D.new()


func _init() -> void:
	mesh = _im
	_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_material.vertex_color_use_as_albedo = true
	_material.no_depth_test = false
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF


func limpar() -> void:
	_im.clear_surfaces()


func desenhar_cadeia(pontos: PackedVector3Array, cor: Color) -> void:
	if pontos.size() < 2:
		return
	_im.surface_begin(Mesh.PRIMITIVE_LINE_STRIP, _material)
	_im.surface_set_color(cor)
	for p in pontos:
		_im.surface_add_vertex(p)
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
