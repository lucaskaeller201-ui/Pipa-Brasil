extends "res://tests/test_case.gd"
## Desenhos das pipas e rabiola de fitinhas (D-043): só visual.

const Estilos := preload("res://game/views/estilos_pipa.gd")
const KiteView := preload("res://game/views/kite_view.gd")
const LinesView := preload("res://game/views/lines_view.gd")


func test_todos_os_desenhos_montam_a_pipa() -> void:
	assert_true(Estilos.ESTILOS.size() >= 6, "vários desenhos")
	for e in Estilos.ESTILOS:
		var estilo: Dictionary = e
		var v: Node3D = KiteView.new()
		v.call("construir", KiteDefinition.pipa_rio(), estilo)
		var vela: MeshInstance3D = v.get_node("Vela")
		assert_not_null(vela, "%s tem vela" % estilo["nome"])
		var tris: int = vela.mesh.surface_get_array_len(0) / 3
		assert_true(tris >= 392, "%s: estampa em grade (%d triângulos)" % [estilo["nome"], tris])
		# a estampa usa mais de uma cor
		var cores := {}
		for nx in [-0.6, -0.1, 0.1, 0.6]:
			for ny in [-0.5, 0.0, 0.3, 0.9]:
				cores[Estilos.cor(estilo, nx, ny * (1.0 - absf(nx)))] = true
		assert_true(cores.size() >= 2, "%s tem estampa" % estilo["nome"])
		v.free()


func test_rabiola_tem_fitinhas() -> void:
	var l: MeshInstance3D = LinesView.new()
	l.set("camera_position", Vector3(0.0, 0.0, 30.0))
	var pontos := PackedVector3Array()
	for i in 11:
		pontos.append(Vector3(0.0, -0.2 * i, 0.0))
	l.call("desenhar_fitinhas", pontos, [Color.RED, Color.WHITE], 1.0)
	var im: ImmediateMesh = l.mesh
	assert_eq(im.get_surface_count(), 1)
	assert_eq(im.surface_get_array_len(0), 10 * 3 * 6, "três fitinhas por pedaço da rabiola")
	l.free()
