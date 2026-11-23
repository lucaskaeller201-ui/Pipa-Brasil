extends RefCounted
## Cenário provisório da Fase 5: duas lajes num bairro, no fim da tarde.
## Tudo gerado por código (caixas e cilindros), sem modelos externos. Serve para
## dar escala e identidade; o cenário de verdade (Blender, texturas) vem na Fase 7.
## Só visual: a física ainda não colide com casas (o chão da física é y = 0).

const ALTURA_LAJE := 6.0
## Lajes de onde se solta pipa (a primeira é a sua). O vento sopra para -Z.
const LAJES := [Vector3(0.0, 0.0, 0.0), Vector3(16.0, 0.0, -4.0), Vector3(-16.0, 0.0, -2.0),
	Vector3(30.0, 0.0, 6.0), Vector3(-30.0, 0.0, 8.0), Vector3(8.0, 0.0, 18.0),
	Vector3(-8.0, 0.0, 20.0), Vector3(44.0, 0.0, -6.0)]
const CORES_LAJE := [Color(0.93, 0.78, 0.55), Color(0.55, 0.70, 0.80), Color(0.85, 0.45, 0.35),
	Color(0.70, 0.80, 0.55), Color(0.95, 0.92, 0.85), Color(0.80, 0.62, 0.75),
	Color(0.62, 0.58, 0.55), Color(0.93, 0.78, 0.55)]

const CORES_PAREDE := [
	Color(0.93, 0.78, 0.55), Color(0.85, 0.45, 0.35), Color(0.55, 0.70, 0.80),
	Color(0.95, 0.92, 0.85), Color(0.70, 0.80, 0.55), Color(0.80, 0.62, 0.75),
	Color(0.62, 0.58, 0.55),
]


static func criar(pai: Node3D, lajes := 2, semente := 7) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = semente
	for i in mini(lajes, LAJES.size()):
		_laje(pai, LAJES[i], CORES_LAJE[i])
	# Casas em volta, deixando livre o corredor do vento à frente das lajes.
	for i in 70:
		var x := rng.randf_range(-70.0, 80.0)
		var z := rng.randf_range(-90.0, 40.0)
		var perto := false
		for i in mini(lajes, LAJES.size()):
			var l: Vector3 = LAJES[i]
			if absf(x - l.x) < 9.0 and absf(z - l.z) < 10.0:
				perto = true
		if perto:
			continue  # espaço das lajes
		var largura := rng.randf_range(5.0, 9.0)
		var fundo := rng.randf_range(6.0, 11.0)
		var altura := rng.randf_range(3.0, 9.5)
		var cor: Color = CORES_PAREDE[rng.randi() % CORES_PAREDE.size()]
		_caixa(pai, Vector3(x, altura * 0.5, z), Vector3(largura, altura, fundo), cor, 0.9)
		if rng.randf() < 0.45:
			_caixa_dagua(pai, Vector3(x + rng.randf_range(-1.5, 1.5), altura, z + rng.randf_range(-2.0, 2.0)))
		if rng.randf() < 0.25:
			_antena(pai, Vector3(x - largura * 0.3, altura, z))
	# Postes e fios na rua da frente.
	for x in range(-60, 81, 20):
		_poste(pai, Vector3(x, 0.0, 16.0))


static func _laje(pai: Node3D, base: Vector3, cor_parede: Color) -> void:
	var h := ALTURA_LAJE
	_caixa(pai, base + Vector3(0.0, h * 0.5 - 0.1, 0.0), Vector3(8.0, h - 0.2, 8.0), cor_parede, 0.9)
	# Piso envernizado: cerâmica avermelhada, pouco rugosa (brilho do sol baixo).
	var piso := _caixa(pai, base + Vector3(0.0, h - 0.05, 0.0), Vector3(8.2, 0.1, 8.2), Color(0.62, 0.27, 0.18), 0.14)
	(piso.material_override as StandardMaterial3D).metallic_specular = 0.7
	# Mureta.
	for lado in [Vector3(0, 0, 4.0), Vector3(0, 0, -4.0)]:
		_caixa(pai, base + Vector3(0.0, h + 0.45, 0.0) + lado, Vector3(8.2, 0.9, 0.15), cor_parede.darkened(0.1), 0.9)
	for lado in [Vector3(4.0, 0, 0), Vector3(-4.0, 0, 0)]:
		_caixa(pai, base + Vector3(0.0, h + 0.45, 0.0) + lado, Vector3(0.15, 0.9, 8.2), cor_parede.darkened(0.1), 0.9)
	_caixa_dagua(pai, base + Vector3(-2.8, h, 2.8))


static func _caixa(pai: Node3D, centro: Vector3, tamanho: Vector3, cor: Color, rugosidade: float) -> MeshInstance3D:
	var m := MeshInstance3D.new()
	var malha := BoxMesh.new()
	malha.size = tamanho
	m.mesh = malha
	var mat := StandardMaterial3D.new()
	mat.albedo_color = cor
	mat.roughness = rugosidade
	m.material_override = mat
	m.position = centro
	pai.add_child(m)
	return m


static func _caixa_dagua(pai: Node3D, base: Vector3) -> void:
	var m := MeshInstance3D.new()
	var malha := CylinderMesh.new()
	malha.top_radius = 0.65
	malha.bottom_radius = 0.6
	malha.height = 1.0
	m.mesh = malha
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.20, 0.45, 0.85)
	mat.roughness = 0.5
	m.material_override = mat
	m.position = base + Vector3(0.0, 0.5, 0.0)
	pai.add_child(m)


static func _antena(pai: Node3D, base: Vector3) -> void:
	_caixa(pai, base + Vector3(0.0, 1.2, 0.0), Vector3(0.05, 2.4, 0.05), Color(0.7, 0.7, 0.7), 0.4)
	_caixa(pai, base + Vector3(0.0, 2.2, 0.0), Vector3(1.2, 0.04, 0.04), Color(0.7, 0.7, 0.7), 0.4)


static func _poste(pai: Node3D, base: Vector3) -> void:
	_caixa(pai, base + Vector3(0.0, 4.5, 0.0), Vector3(0.25, 9.0, 0.25), Color(0.6, 0.6, 0.58), 0.9)
