extends RefCounted
## Monta o ambiente de fim de tarde (céu, sol baixo, chão envernizado).
## Versão simples da identidade visual; o ciclo de dia e noite vem na Fase 7.


## Horas do dia (D-063): cores do céu, do sol e da névoa.
const HORAS := {
	"manha": {"nome": "Manhã", "topo": Color(0.22, 0.47, 0.86), "horizonte": Color(0.78, 0.86, 0.95),
		"baixo": Color(0.5, 0.55, 0.6), "nuvens": 0.42, "sol_cor": Color(1.0, 0.94, 0.84), "sol_forca": 1.05,
		"sol_rot": Vector3(-32.0, 75.0, 0.0), "nevoa": Color(0.62, 0.72, 0.85), "nevoa_d": 0.0012, "ambiente": 0.45, "brilho": false},
	"meio_dia": {"nome": "Meio-dia", "topo": Color(0.12, 0.36, 0.82), "horizonte": Color(0.66, 0.8, 0.95),
		"baixo": Color(0.5, 0.55, 0.6), "nuvens": 0.38, "sol_cor": Color(1.0, 0.98, 0.94), "sol_forca": 1.1,
		"sol_rot": Vector3(-62.0, 50.0, 0.0), "nevoa": Color(0.6, 0.72, 0.88), "nevoa_d": 0.001, "ambiente": 0.4, "brilho": false},
	"por_do_sol": {"nome": "Pôr do sol", "topo": Color(0.13, 0.24, 0.52), "horizonte": Color(1.0, 0.58, 0.28),
		"baixo": Color(0.32, 0.22, 0.16), "nuvens": 0.5, "sol_cor": Color(1.0, 0.74, 0.42), "sol_forca": 1.4,
		"sol_rot": Vector3(-14.0, 60.0, 0.0), "nevoa": Color(0.95, 0.66, 0.45), "nevoa_d": 0.0035, "ambiente": 0.9},
}
const ORDEM_HORAS := ["manha", "meio_dia", "por_do_sol"]


static func criar_por_do_sol(pai: Node3D, com_marcos := true) -> void:
	criar(pai, "por_do_sol", "bairro", com_marcos)


## Céu, sol, névoa e chão para a hora e o mapa ("bairro" ou "praia").
static func criar(pai: Node3D, hora := "por_do_sol", mapa := "bairro", com_marcos := false) -> void:
	var h: Dictionary = HORAS.get(hora, HORAS["por_do_sol"])
	# Céu por shader (D-057): degradê, sol e nuvens que andam.
	var ceu_material := ShaderMaterial.new()
	ceu_material.shader = load("res://game/world/shaders/ceu.gdshader")
	ceu_material.set_shader_parameter("topo", h["topo"])
	ceu_material.set_shader_parameter("horizonte", h["horizonte"])
	ceu_material.set_shader_parameter("baixo", h["baixo"])
	ceu_material.set_shader_parameter("cobertura", h["nuvens"])

	var ceu := Sky.new()
	ceu.sky_material = ceu_material

	var env := Environment.new()
	env.background_mode = Environment.BG_SKY
	env.sky = ceu
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.reflected_light_source = Environment.REFLECTION_SOURCE_SKY
	env.tonemap_mode = Environment.TONE_MAPPER_ACES
	# Brilho (glow) só no pôr do sol: de dia ele estourava as cores claras.
	env.glow_enabled = bool(h.get("brilho", true))
	env.ambient_light_energy = float(h["ambiente"])
	env.ambient_light_sky_contribution = 0.7
	env.tonemap_exposure = 0.95
	# Névoa leve: a cidade some no horizonte (profundidade).
	env.fog_enabled = true
	env.fog_light_color = h["nevoa"]
	env.fog_density = float(h["nevoa_d"])
	env.fog_sky_affect = 0.0

	var mundo := WorldEnvironment.new()
	mundo.name = "Ambiente"
	mundo.environment = env
	pai.add_child(mundo)

	# Sol de lado e um pouco atrás do pipeiro: ilumina a face da pipa.
	var sol := DirectionalLight3D.new()
	sol.name = "Sol"
	sol.light_color = h["sol_cor"]
	sol.light_energy = float(h["sol_forca"])
	sol.shadow_enabled = true
	sol.directional_shadow_max_distance = 90.0
	sol.rotation_degrees = h["sol_rot"]
	pai.add_child(sol)

	var malha := PlaneMesh.new()
	malha.size = Vector2(1600.0, 1600.0)
	# Chão com ruas, calçadas e terra (D-057); na praia, calçadão e areia.
	var material := ShaderMaterial.new()
	material.shader = load("res://game/world/shaders/chao.gdshader")
	if mapa == "praia":
		material.set_shader_parameter("praia", 1.0)
		material.set_shader_parameter("rua_x2", Vector4(-1000.0, 1000.0, -29.0, -21.0))  # avenida da orla
		material.set_shader_parameter("rua_z1", Vector4(-60.0, -52.0, -21.0, 1000.0))
		material.set_shader_parameter("rua_z2", Vector4(62.0, 70.0, -21.0, 1000.0))
	var chao := MeshInstance3D.new()
	chao.name = "Chao"
	chao.mesh = malha
	chao.material_override = material
	pai.add_child(chao)
	if mapa == "praia":
		# o mar, do fim da areia até o horizonte
		var agua := MeshInstance3D.new()
		agua.name = "Mar"
		var plano := PlaneMesh.new()
		plano.size = Vector2(3000.0, 1500.0)
		agua.mesh = plano
		agua.position = Vector3(0.0, 0.04, -95.0 - 750.0)
		var mat_agua := ShaderMaterial.new()
		mat_agua.shader = load("res://game/world/shaders/agua.gdshader")
		agua.material_override = mat_agua
		agua.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		pai.add_child(agua)

	if not com_marcos:
		return
	# Postes de referência a cada 10 m, para dar noção de distância e altura.
	var marcos := Node3D.new()
	marcos.name = "Marcos"
	var poste := BoxMesh.new()
	poste.size = Vector3(0.15, 3.0, 0.15)
	var cor_poste := StandardMaterial3D.new()
	cor_poste.albedo_color = Color(0.85, 0.85, 0.80)
	for z in range(-10, -110, -10):
		for x in [-15.0, 15.0]:
			var m := MeshInstance3D.new()
			m.mesh = poste
			m.material_override = cor_poste
			m.position = Vector3(x, 1.5, z)
			marcos.add_child(m)
	pai.add_child(marcos)
