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
			st.set_uv(Vector2(def.triangles[i].x, -def.triangles[i].y))
			st.add_vertex(def.triangles[i])
	else:
		_vela_estampada(st, def, estilo)
	st.generate_normals()
	st.generate_tangents()
	# D-075: papel de seda (fibra, amassado, luz atravessando, varetas por dentro)
	var vela_material := ShaderMaterial.new()
	vela_material.shader = load("res://game/world/shaders/seda.gdshader")
	var y_sup := def.corners[2].y
	var y_inf := def.corners[2].y - 0.15
	if not estilo.is_empty():
		var cc := contorno(def, estilo)
		y_sup = (cc[1] as Vector3).y
		y_inf = (cc[2] as Vector3).y
	vela_material.set_shader_parameter("vareta_sup_y", y_sup)
	vela_material.set_shader_parameter("vareta_inf_y", y_inf)
	var vela := MeshInstance3D.new()
	vela.name = "Vela"
	vela.mesh = st.commit()
	vela.material_override = vela_material
	# a pipa não faz sombra em si mesma (senão a luz não atravessa o papel)
	vela.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(vela)
	_varetas(def, estilo)

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
		# (as varetas agora são de bambu com volume: _varetas)
		pass
		# linha do bico: da ponta da vareta central às pontas da vareta de cima
		if Estilos.aberto(estilo):
			linhas.surface_set_color(Color(0.95, 0.95, 0.95))
			for p in [c[0], sup, c[0], Vector3(-sup.x, sup.y, 0.0)]:
				linhas.surface_add_vertex(p)
		linhas.surface_set_color(Color(0.35, 0.22, 0.10))
	linhas.surface_set_color(Color(0.95, 0.95, 0.95))
	var meio_espinha := Vector3(0.0, -0.2, 0.0)
	for p in [top, def.tow_point, def.tow_point, meio_espinha]:
		linhas.surface_add_vertex(p)
	linhas.surface_end()
	# D-091: o cabresto com volume (barbante), para aparecer de perto
	var cab := SurfaceTool.new()
	cab.begin(Mesh.PRIMITIVE_TRIANGLES)
	cab.set_color(Color(0.96, 0.94, 0.88))
	_tubo(cab, top + Vector3(0.0, -0.02, 0.0), def.tow_point, 0.0011)
	_tubo(cab, meio_espinha, def.tow_point, 0.0011)
	cab.generate_normals()
	var cab_mat := StandardMaterial3D.new()
	cab_mat.vertex_color_use_as_albedo = true
	cab_mat.roughness = 0.9
	var cab_no := MeshInstance3D.new()
	cab_no.name = "Cabresto"
	cab_no.mesh = cab.commit()
	cab_no.material_override = cab_mat
	cab_no.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(cab_no)
	var estrutura := MeshInstance3D.new()
	estrutura.name = "Estrutura"
	estrutura.mesh = linhas
	add_child(estrutura)
	_cabresto = linhas


## Tubo fino de a até b (barbante do cabresto).
static func _tubo(st: SurfaceTool, a: Vector3, b: Vector3, r: float) -> void:
	var d := (b - a).normalized()
	var u := d.cross(Vector3.UP if absf(d.y) < 0.9 else Vector3.RIGHT).normalized() * r
	var v := d.cross(u).normalized() * r
	var anel := [u, v, -u, -v]
	for q in 4:
		var p: Vector3 = anel[q]
		var w: Vector3 = anel[(q + 1) % 4]
		for x in [a + p, b + p, b + w, a + p, b + w, a + w]:
			st.add_vertex(x)


## Varetas de bambu de verdade (finas, com volume), atrás do papel (D-075).
func _varetas(def: KiteDefinition, estilo: Dictionary) -> void:
	var pares: Array = []
	if estilo.is_empty():
		pares = [[def.corners[0], def.corners[1]], [def.corners[2], def.corners[3]]]
	else:
		var c := contorno(def, estilo)
		var sup: Vector3 = c[1]
		var inf: Vector3 = c[2]
		pares = [[c[0], c[3]], [Vector3(-sup.x, sup.y, 0.0), sup], [Vector3(-inf.x, inf.y, 0.0), inf]]
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	st.set_color(Color(0.72, 0.58, 0.36))
	var r := 0.0028
	for par in pares:
		var a: Vector3 = par[0]
		var b: Vector3 = par[1]
		# vareta atravessada verga um pouco (como na pipa de verdade)
		var passos := 6
		for k in passos:
			var t0 := float(k) / passos
			var t1 := float(k + 1) / passos
			var p0 := a.lerp(b, t0)
			var p1 := a.lerp(b, t1)
			# D-091: as varetas ficam atrás do papel (o cabresto sai pela frente,
			# virada para o pipeiro), e a vareta atravessada enverga para trás
			# (a envergadura): as pontas vão para trás do meio
			p0.z = -0.004
			p1.z = -0.004
			if absf(a.y - b.y) < 0.01:
				p0.z -= p0.x * p0.x * 0.45
				p1.z -= p1.x * p1.x * 0.45
			var d := (p1 - p0).normalized()
			var lado := d.cross(Vector3.BACK).normalized() * r
			var cima := Vector3.BACK * r
			var anel := [lado, cima, -lado, -cima]
			for q in 4:
				var u: Vector3 = anel[q]
				var w: Vector3 = anel[(q + 1) % 4]
				for v in [p0 + u, p1 + u, p1 + w, p0 + u, p1 + w, p0 + w]:
					st.add_vertex(v)
	st.generate_normals()
	var mat := StandardMaterial3D.new()
	mat.vertex_color_use_as_albedo = true
	mat.roughness = 0.6
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	var m := MeshInstance3D.new()
	m.name = "Varetas"
	m.mesh = st.commit()
	m.material_override = mat
	m.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(m)


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
	# O bico (acima da vareta de cima) não tem papel: só a linha que vai da
	# ponta às pontas da vareta (D-047). A vela começa na vareta de cima.
	var primeira := 1 if Estilos.aberto(estilo) else 0
	for fx in range(primeira, 3):
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
					st.set_uv(Vector2(p.x, -p.y))
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
