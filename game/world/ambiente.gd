extends RefCounted
## Monta o ambiente de fim de tarde (céu, sol baixo, chão envernizado).
## Versão simples da identidade visual; o ciclo de dia e noite vem na Fase 7.


static func criar_por_do_sol(pai: Node3D) -> void:
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

	var env := Environment.new()
	env.background_mode = Environment.BG_SKY
	env.sky = ceu
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.reflected_light_source = Environment.REFLECTION_SOURCE_SKY
	env.tonemap_mode = Environment.TONE_MAPPER_ACES
	env.glow_enabled = true

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
	sol.rotation_degrees = Vector3(-14.0, 60.0, 0.0)
	pai.add_child(sol)

	var malha := PlaneMesh.new()
	malha.size = Vector2(600.0, 600.0)
	var material := StandardMaterial3D.new()
	material.albedo_color = Color(0.50, 0.36, 0.26)
	material.roughness = 0.25
	var chao := MeshInstance3D.new()
	chao.name = "Chao"
	chao.mesh = malha
	chao.material_override = material
	pai.add_child(chao)

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
