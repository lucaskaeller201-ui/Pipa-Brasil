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
	if estilo.is_empty():
		for p in [top, bottom, left, right]:
			linhas.surface_add_vertex(p)
	else:
		# vareta central e as duas varetas atravessadas do modelo
		var c := contorno(def, estilo)
		var sup: Vector3 = c[1]
		var inf: Vector3 = c[2]
		for p in [c[0], c[3], Vector3(-sup.x, sup.y, 0.0), sup, Vector3(-inf.x, inf.y, 0.0), inf]:
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


## Vela no formato do modelo (D-045): bico, caixa e rabeta com as medidas
## do pipeiro, na escala do comprimento da pipa da física; estampa por ponto.
func _vela_estampada(st: SurfaceTool, def: KiteDefinition, estilo: Dictionary) -> void:
	var pts := contorno(def, estilo)
	var top: Vector3 = pts[0]
	var sup_d: Vector3 = pts[1]
	var inf_d: Vector3 = pts[2]
	var bottom: Vector3 = pts[3]
	var meia := maxf(sup_d.x, inf_d.x)
	var comprimento := top.y - bottom.y
	var tb := (top.y - sup_d.y) / comprimento
	var tc := (top.y - inf_d.y) / comprimento
	# três faixas: bico (ponta → vareta de cima), caixa, rabeta (→ ponta de baixo)
	var nu := 16
	var nv := 6
	for fx in 3:
		var y0: float
		var y1: float
		var w0: float
		var w1: float
		if fx == 0:
			y0 = top.y
			y1 = sup_d.y
			w0 = 0.0
			w1 = sup_d.x
		elif fx == 1:
			y0 = sup_d.y
			y1 = inf_d.y
			w0 = sup_d.x
			w1 = inf_d.x
		else:
			y0 = inf_d.y
			y1 = bottom.y
			w0 = inf_d.x
			w1 = 0.0
		for j in nv:
			var v0 := float(j) / nv
			var v1 := float(j + 1) / nv
			var ya := lerpf(y0, y1, v0)
			var yb := lerpf(y0, y1, v1)
			var wa := lerpf(w0, w1, v0)
			var wb := lerpf(w0, w1, v1)
			for i in nu:
				var u0 := lerpf(-1.0, 1.0, float(i) / nu)
				var u1 := lerpf(-1.0, 1.0, float(i + 1) / nu)
				var p00 := Vector3(u0 * wa, ya, 0.0)
				var p10 := Vector3(u1 * wa, ya, 0.0)
				var p11 := Vector3(u1 * wb, yb, 0.0)
				var p01 := Vector3(u0 * wb, yb, 0.0)
				var c := (p00 + p10 + p11 + p01) * 0.25
				st.set_color(Estilos.cor(estilo, c.x / meia, (top.y - c.y) / comprimento, tb, tc))
				for p in [p00, p10, p11, p00, p11, p01]:
					st.add_vertex(p)


## Pontos do contorno (lado direito): [ponta de cima, vareta de cima, vareta
## de baixo, ponta de baixo], na escala da pipa da física.
static func contorno(def: KiteDefinition, estilo: Dictionary) -> Array:
	var m: Array = estilo["m"]
	var top := def.corners[0]
	var bottom := def.corners[1]
	var s := (top.y - bottom.y) / float(m[0])
	var sup := Vector3(float(m[1]) * 0.5 * s, top.y - float(m[3]) * s, 0.0)
	var inf := Vector3(float(m[2]) * 0.5 * s, top.y - (float(m[3]) + float(m[4])) * s, 0.0)
	return [Vector3(0.0, top.y, 0.0), sup, inf, Vector3(0.0, bottom.y, 0.0)]
