extends "res://tests/test_case.gd"
## Desenhos das pipas e rabiola de fitinhas (D-043): só visual.

const Estilos := preload("res://game/views/estilos_pipa.gd")
const KiteView := preload("res://game/views/kite_view.gd")
const LinesView := preload("res://game/views/lines_view.gd")


func test_todos_os_desenhos_montam_a_pipa() -> void:
	assert_true(Estilos.ESTILOS.size() >= 18, "vários modelos de pipa")
	for e in Estilos.ESTILOS:
		var estilo: Dictionary = e
		var v: Node3D = KiteView.new()
		v.call("construir", KiteDefinition.pipa_rio(), estilo)
		var vela: MeshInstance3D = v.get_node("Vela")
		assert_not_null(vela, "%s tem vela" % estilo["nome"])
		var tris: int = vela.mesh.surface_get_array_len(0) / 3
		assert_eq(tris, 2 * 16 * 6 * 2, "%s: caixa e rabeta em grade (o bico não tem papel)" % estilo["nome"])
		var m: Array = estilo["m"]
		assert_true(absf(float(m[3]) + float(m[4]) + float(m[5]) - float(m[0])) < 1.0, "%s: medidas somam a vareta central" % estilo["nome"])
		# a estampa usa mais de uma cor na caixa e na rabeta
		var cores := {}
		for i in 39:
			for j in 13:
				var x := -0.95 + 0.05 * i
				var t := 0.35 + 0.05 * j
				cores[Estilos.cor(estilo, x, t, 0.3, 0.65).to_html()] = true
		assert_true(cores.size() >= 2, "%s tem estampa" % estilo["nome"])
		v.free()


func test_rabiola_tem_fitinhas() -> void:
	var l: MeshInstance3D = LinesView.new()
	l.set("camera_position", Vector3(0.0, 0.0, 10.0))
	var pontos := PackedVector3Array()
	for i in 11:
		pontos.append(Vector3(0.0, -0.2 * i, 0.0))
	l.call("desenhar_fitinhas", pontos, [Color.RED, Color.WHITE], 1.0)
	var im: ImmediateMesh = l.mesh
	assert_eq(im.get_surface_count(), 1)
	var vertices: PackedVector3Array = im.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
	assert_eq(vertices.size(), 10 * 2 * 6, "duas fitinhas por pedaço da rabiola")
	l.free()


## D-048: de longe as fitinhas somem (tamanho de verdade) e fica o barbante.
func test_rabiola_de_longe_nao_engrossa() -> void:
	var l: MeshInstance3D = LinesView.new()
	l.set("camera_position", Vector3(0.0, 0.0, 120.0))
	l.set("min_width_per_meter", 0.002)
	var pontos := PackedVector3Array()
	for i in 11:
		pontos.append(Vector3(0.0, -0.2 * i, 0.0))
	l.call("desenhar_fitinhas", pontos, [Color.RED, Color.WHITE], 1.0)
	var im: ImmediateMesh = l.mesh
	var n := 0
	if im.get_surface_count() > 0:
		var vertices: PackedVector3Array = im.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
		n = vertices.size()
	assert_eq(n, 0, "a 120 m as fitinhas não aparecem maiores que a pipa")
	l.free()
