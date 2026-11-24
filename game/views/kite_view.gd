extends Node3D
## Desenha a pipa a partir da definição e acompanha o estado do KiteBody.
## Só leitura: nada aqui altera a física.

const Estilos := preload("res://game/views/estilos_pipa.gd")

var _cabresto: ImmediateMesh


## `estilo` (de estilos_pipa.gd) muda só o desenho: forma e estampa (D-043).
func construir(def: KiteDefinition, estilo := {}) -> void:
	for filho in get_children():
		filho.queue_free()

	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	if estilo.is_empty():
		# Vela: triângulos de cima vermelhos, de baixo amarelos.
		for i in def.triangles.size():
			var tri := i / 3
			st.set_color(Color(0.90, 0.18, 0.15) if tri < 2 else Color(1.0, 0.82, 0.20))
			st.add_vertex(def.triangles[i])
	else:
		_vela_estampada(st, def, estilo)
	st.generate_normals()
	var vela_material := StandardMaterial3D.new()
	vela_material.vertex_color_use_as_albedo = true
	vela_material.cull_mode = BaseMaterial3D.CULL_DISABLED
	vela_material.roughness = 0.8
	var vela := MeshInstance3D.new()
	vela.name = "Vela"
	vela.mesh = st.commit()
	vela.material_override = vela_material
	add_child(vela)

	# Varetas e cabresto.
	var linhas := ImmediateMesh.new()
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.vertex_color_use_as_albedo = true
	var top := def.corners[0]
	var bottom := def.corners[1]
	var left := def.corners[2]
	var right := def.corners[3]
	linhas.surface_begin(Mesh.PRIMITIVE_LINES, material)
	linhas.surface_set_color(Color(0.35, 0.22, 0.10))
	for p in [top, bottom, left, right]:
		linhas.surface_add_vertex(p)
	linhas.surface_set_color(Color(0.95, 0.95, 0.95))
	var meio_espinha := Vector3(0.0, -0.2, 0.0)
	for p in [top, def.tow_point, def.tow_point, meio_espinha]:
		linhas.surface_add_vertex(p)
	linhas.surface_end()
	var estrutura := MeshInstance3D.new()
	estrutura.name = "Estrutura"
	estrutura.mesh = linhas
	add_child(estrutura)
	_cabresto = linhas


func atualizar(kite: KiteBody) -> void:
	transform = Transform3D(Basis(kite.rotation), kite.position)


## Vela em grade (estampa por ponto) e, no peixinho, o rabo de peixe embaixo.
func _vela_estampada(st: SurfaceTool, def: KiteDefinition, estilo: Dictionary) -> void:
	var top := def.corners[0]
	var bottom := def.corners[1]
	var left := def.corners[2]
	var right := def.corners[3]
	var cy := left.y
	var meia := maxf(absf(right.x), absf(left.x))
	var n := 14
	for i in n:
		for j in n:
			var s0 := float(i) / n
			var s1 := float(i + 1) / n
			var t0 := float(j) / n
			var t1 := float(j + 1) / n
			var p00 := _bilinear(left, top, right, bottom, s0, t0)
			var p10 := _bilinear(left, top, right, bottom, s1, t0)
			var p11 := _bilinear(left, top, right, bottom, s1, t1)
			var p01 := _bilinear(left, top, right, bottom, s0, t1)
			var c := (p00 + p10 + p11 + p01) * 0.25
			var nx := c.x / meia
			var ny := (c.y - cy) / (top.y - cy) if c.y >= cy else (c.y - cy) / (cy - bottom.y)
			st.set_color(Estilos.cor(estilo, nx, ny))
			for p in [p00, p10, p11, p00, p11, p01]:
				st.add_vertex(p)
	if String(estilo["forma"]) == "peixinho":
		var cores: Array = estilo["cores"]
		var h := cy - bottom.y
		st.set_color(cores[2])
		var b := bottom
		for lado in [-1.0, 1.0]:
			st.add_vertex(b)
			st.add_vertex(b + Vector3(lado * meia * 0.45, -h * 0.45, 0.0))
			st.add_vertex(b + Vector3(lado * meia * 0.12, -h * 0.2, 0.0))


static func _bilinear(l: Vector3, t: Vector3, r: Vector3, b: Vector3, s: float, u: float) -> Vector3:
	return l * ((1.0 - s) * (1.0 - u)) + t * (s * (1.0 - u)) + r * (s * u) + b * ((1.0 - s) * u)
