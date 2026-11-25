extends RefCounted
## Monta o ambiente de fim de tarde (céu, sol baixo, chão envernizado).
## Versão simples da identidade visual; o ciclo de dia e noite vem na Fase 7.


static func criar_por_do_sol(pai: Node3D, com_marcos := true) -> void:
	# Céu por shader (D-057): degradê de fim de tarde, sol e nuvens que andam.
	var ceu_material := ShaderMaterial.new()
	ceu_material.shader = load("res://game/world/shaders/ceu.gdshader")

	var ceu := Sky.new()
	ceu.sky_material = ceu_material

	var env := Environment.new()
	env.background_mode = Environment.BG_SKY
	env.sky = ceu
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.reflected_light_source = Environment.REFLECTION_SOURCE_SKY
	env.tonemap_mode = Environment.TONE_MAPPER_ACES
	env.glow_enabled = true
	env.ambient_light_energy = 0.9
	# Névoa leve de fim de tarde: o bairro some no horizonte (profundidade).
	env.fog_enabled = true
	env.fog_light_color = Color(0.95, 0.66, 0.45)
	env.fog_density = 0.0035
	env.fog_sky_affect = 0.0

	var mundo := WorldEnvironment.new()
	mundo.name = "Ambiente"
	mundo.environment = env
	pai.add_child(mundo)

	# Sol baixo, de lado e um pouco atrás do pipeiro: ilumina a face da pipa.
	# (Com o sol bem à frente, a pipa vira silhueta escura contra o céu; esse
	# efeito de cinema fica para a direção de arte da Fase 7.)
	var sol := DirectionalLight3D.new()
	sol.name = "Sol"
	sol.light_color = Color(1.0, 0.74, 0.42)
	sol.light_energy = 1.4
	sol.shadow_enabled = true
	sol.directional_shadow_max_distance = 90.0
	sol.rotation_degrees = Vector3(-14.0, 60.0, 0.0)
	pai.add_child(sol)

	var malha := PlaneMesh.new()
	malha.size = Vector2(600.0, 600.0)
	# Chão com ruas, calçadas e terra (D-057).
	var material := ShaderMaterial.new()
	material.shader = load("res://game/world/shaders/chao.gdshader")
	var chao := MeshInstance3D.new()
	chao.name = "Chao"
	chao.mesh = malha
	chao.material_override = material
	pai.add_child(chao)

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
