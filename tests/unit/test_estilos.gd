extends "res://tests/test_case.gd"
## Desenhos das pipas e rabiola de fitinhas (D-043): só visual.

const Estilos := preload("res://game/views/estilos_pipa.gd")
const KiteView := preload("res://game/views/kite_view.gd")
const LinesView := preload("res://game/views/lines_view.gd")


func test_todos_os_desenhos_montam_a_pipa() -> void:
	assert_true(Estilos.ESTILOS.size() >= 40, "muitos modelos de pipa (D-064)")
	for e in Estilos.ESTILOS:
		var estilo: Dictionary = e
		var v: Node3D = KiteView.new()
		v.call("construir", KiteDefinition.pipa_rio(), estilo)
		var vela: MeshInstance3D = v.get_node("Vela")
		assert_not_null(vela, "%s tem vela" % estilo["nome"])
		var tris: int = vela.mesh.surface_get_array_len(0) / 3
		var faixas := 2 if Estilos.aberto(estilo) else 3
		var m0: Array = estilo["m"]
		if float(m0[4]) <= 0.0:
			faixas = 3   # losango: bico e rabeta com papel (a caixa tem altura 0)
		assert_eq(tris, faixas * 16 * 6 * 2, "%s: vela em grade" % estilo["nome"])
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



## D-064: cada pipa do catálogo tem velocidade, força e rabiola, e vira física.
func test_catalogo_tem_dados_e_vira_fisica() -> void:
	for i in Estilos.ESTILOS.size():
		var e: Dictionary = Estilos.ESTILOS[i]
		assert_true(int(e["velocidade"]) > 0 and int(e["forca"]) > 0 and int(e["rabiola"]) >= 0, String(e["nome"]))
		var d := FreeMode.kite_for(i)
		assert_true(d.tail_length >= 1.5 and d.tail_length <= 8.0, "%s: rabiola na física" % e["nome"])
	assert_true(Estilos.LINHAS.size() >= 8, "várias linhas")
	for l in Estilos.LINHAS:
		var nome := String((l as Dictionary)["nome"]).to_lower()
		assert_false(nome.contains("cerol") or nome.contains("chilena"), "linhas fictícias, sem cerol/chilena")
