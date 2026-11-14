extends Node3D
## Tela de teste da Fase 0.
##
## Não contém física nenhuma: serve só para confirmar que o projeto abre,
## renderiza no aparelho e mostra versão, renderizador e FPS. A pipa no céu é
## um objeto parado, apenas decorativo; a pipa de verdade nasce na Fase 1.

const BuildInfo := preload("res://game/main/build_info.gd")

var _info: Label


func _ready() -> void:
	_criar_ambiente()
	_criar_sol()
	_criar_chao()
	_criar_pipa_decorativa()
	_criar_camera()
	_criar_interface()


func _process(_delta: float) -> void:
	if _info != null:
		_info.text = texto_info()


func texto_info() -> String:
	var versao: String = ProjectSettings.get_setting("application/config/version", "?")
	return "PIPA BRASIL · Fase 0 (tela de teste)\nVersão %s · build %s\nRenderizador: %s · %s\nFPS: %d" % [
		versao,
		BuildInfo.COMMIT,
		RenderingServer.get_current_rendering_method(),
		OS.get_name(),
		Engine.get_frames_per_second(),
	]


func _criar_ambiente() -> void:
	var ceu_material := ProceduralSkyMaterial.new()
	ceu_material.sky_top_color = Color(0.20, 0.30, 0.55)
	ceu_material.sky_horizon_color = Color(1.00, 0.62, 0.30)
	ceu_material.sky_curve = 0.12
	ceu_material.ground_horizon_color = Color(0.85, 0.52, 0.28)
	ceu_material.ground_bottom_color = Color(0.18, 0.11, 0.08)
	ceu_material.sun_angle_max = 25.0
	ceu_material.sun_curve = 0.1

	var ceu := Sky.new()
	ceu.sky_material = ceu_material

	var ambiente := Environment.new()
	ambiente.background_mode = Environment.BG_SKY
	ambiente.sky = ceu
	ambiente.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	ambiente.reflected_light_source = Environment.REFLECTION_SOURCE_SKY
	ambiente.tonemap_mode = Environment.TONE_MAPPER_ACES
	ambiente.glow_enabled = true

	var mundo := WorldEnvironment.new()
	mundo.name = "Ambiente"
	mundo.environment = ambiente
	add_child(mundo)


func _criar_sol() -> void:
	# Sol baixo, quase no horizonte, à frente da câmera: fim de tarde dourado.
	var sol := DirectionalLight3D.new()
	sol.name = "Sol"
	sol.light_color = Color(1.0, 0.74, 0.42)
	sol.light_energy = 1.3
	sol.shadow_enabled = true
	sol.rotation_degrees = Vector3(-7.0, 170.0, 0.0)
	add_child(sol)


func _criar_chao() -> void:
	# Piso liso e pouco rugoso, prévia do acabamento envernizado.
	var malha := PlaneMesh.new()
	malha.size = Vector2(400.0, 400.0)

	var material := StandardMaterial3D.new()
	material.albedo_color = Color(0.50, 0.36, 0.26)
	material.roughness = 0.22
	material.metallic = 0.0

	var chao := MeshInstance3D.new()
	chao.name = "Chao"
	chao.mesh = malha
	chao.material_override = material
	add_child(chao)


func _criar_pipa_decorativa() -> void:
	# Losango simples gerado por código. Parado: decoração, não física.
	var topo := Vector3(0.0, 0.45, 0.0)
	var base := Vector3(0.0, -0.55, 0.0)
	var esquerda := Vector3(-0.38, 0.05, 0.0)
	var direita := Vector3(0.38, 0.05, 0.0)

	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for v in [topo, direita, base, topo, base, esquerda]:
		st.add_vertex(v)
	st.generate_normals()

	var material := StandardMaterial3D.new()
	material.albedo_color = Color(0.90, 0.20, 0.17)
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	material.roughness = 0.8

	var pipa := MeshInstance3D.new()
	pipa.name = "PipaDecorativa"
	pipa.mesh = st.commit()
	pipa.material_override = material
	pipa.position = Vector3(3.0, 14.0, -30.0)
	pipa.rotation_degrees = Vector3(-20.0, 10.0, 8.0)
	pipa.scale = Vector3.ONE * 2.0
	add_child(pipa)


func _criar_camera() -> void:
	var camera := Camera3D.new()
	camera.name = "Camera"
	camera.position = Vector3(0.0, 1.6, 0.0)
	camera.rotation_degrees = Vector3(12.0, 0.0, 0.0)
	camera.fov = 70.0
	camera.current = true
	add_child(camera)


func _criar_interface() -> void:
	var camada := CanvasLayer.new()
	camada.name = "Interface"
	add_child(camada)

	_info = Label.new()
	_info.name = "Info"
	_info.position = Vector2(24.0, 24.0)
	_info.add_theme_font_size_override("font_size", 26)
	_info.add_theme_color_override("font_color", Color.WHITE)
	_info.add_theme_color_override("font_outline_color", Color(0.0, 0.0, 0.0, 0.8))
	_info.add_theme_constant_override("outline_size", 6)
	_info.text = texto_info()
	camada.add_child(_info)
