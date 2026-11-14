extends Node3D
## Desenha a pipa a partir da definição e acompanha o estado do KiteBody.
## Só leitura: nada aqui altera a física.

var _cabresto: ImmediateMesh


func construir(def: KiteDefinition) -> void:
	for filho in get_children():
		filho.queue_free()

	# Vela: triângulos de cima vermelhos, de baixo amarelos.
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in def.triangles.size():
		var tri := i / 3
		st.set_color(Color(0.90, 0.18, 0.15) if tri < 2 else Color(1.0, 0.82, 0.20))
		st.add_vertex(def.triangles[i])
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
