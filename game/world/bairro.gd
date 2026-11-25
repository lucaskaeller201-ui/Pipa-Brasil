extends RefCounted
## Cenário do bairro (D-057): lajes de onde se solta pipa, casas com reboco ou
## tijolo aparente, janelas e portas (shader), caixas d'água, antenas, varais,
## árvores e coqueiros, postes com fios nas ruas e o morro com casinhas ao
## fundo. Tudo gerado por código, sem modelos externos (custo zero).
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
	Color(0.62, 0.58, 0.55), Color(0.98, 0.85, 0.35),
]
## Ruas (as mesmas do shader do chão): [xmin, xmax, zmin, zmax].
const RUAS := [Vector4(-1000.0, 1000.0, 26.0, 34.0), Vector4(-1000.0, 1000.0, -62.0, -54.0),
	Vector4(-60.0, -52.0, -1000.0, 1000.0), Vector4(62.0, 70.0, -1000.0, 1000.0)]

## Na praia a rua de baixo vira a avenida da orla (D-063).
const RUAS_PRAIA := [Vector4(-1000.0, 1000.0, 26.0, 34.0), Vector4(-1000.0, 1000.0, -29.0, -21.0),
	Vector4(-60.0, -52.0, -21.0, 1000.0), Vector4(62.0, 70.0, -21.0, 1000.0)]
const MAPAS := ["bairro", "praia"]
const NOMES_MAPAS := {"bairro": "Bairro", "praia": "Praia"}

static var _mats := {}
static var _ruas: Array = RUAS


static func criar(pai: Node3D, lajes := 2, semente := 7, mapa := "bairro") -> void:
	_mats.clear()
	_mat_folha.clear()
	_mat_telha = null
	var praia := mapa == "praia"
	_ruas = RUAS_PRAIA if praia else RUAS
	var rng := RandomNumberGenerator.new()
	rng.seed = semente
	var raiz := Node3D.new()
	raiz.name = "Bairro"
	pai.add_child(raiz)
	for i in mini(lajes, LAJES.size()):
		_laje(raiz, LAJES[i], CORES_LAJE[i], rng, i == 0)
	# Casas em quadras, fora das ruas e do espaço das lajes.
	var feitas := 0
	var tentativas := 0
	while feitas < 85 and tentativas < 600:
		tentativas += 1
		var x := rng.randf_range(-100.0, 110.0)
		var z := rng.randf_range(-16.0, 75.0) if praia else rng.randf_range(-120.0, 70.0)
		var largura := rng.randf_range(5.0, 9.0)
		var fundo := rng.randf_range(6.0, 11.0)
		if _perto_de_laje(x, z, lajes) or _na_rua(x, z, largura, fundo):
			continue
		var andares := rng.randi_range(3, 8) if praia and z > 36.0 else rng.randi_range(1, 3)
		var altura := andares * 3.0 - rng.randf_range(0.0, 0.3)
		var cor: Color = CORES_PAREDE[rng.randi() % CORES_PAREDE.size()]
		_casa(raiz, Vector3(x, 0.0, z), Vector3(largura, altura, fundo), cor, rng.randf() < 0.3, rng)
		feitas += 1
	# Árvores e coqueiros nas calçadas.
	for k in 26:
		var r: Vector4 = _ruas[k % _ruas.size()]
		var ao_longo_x := r.x < -500.0
		var t := rng.randf_range(-90.0, 100.0)
		var lado := r.z - 2.4 if rng.randf() < 0.5 else r.w + 2.4
		if not ao_longo_x:
			lado = r.x - 2.4 if rng.randf() < 0.5 else r.y + 2.4
		var pos := Vector3(t, 0.0, lado) if ao_longo_x else Vector3(lado, 0.0, t)
		if praia and pos.z < -19.0:
			continue   # na praia, da avenida para o mar só o que é da orla
		if rng.randf() < 0.35:
			_coqueiro(raiz, pos, rng)
		else:
			_arvore(raiz, pos, rng)
	# Postes com fios na rua da frente.
	var topo_anterior := Vector3.INF
	for x in range(-90, 111, 20):
		var topo := _poste(raiz, Vector3(float(x), 0.0, 25.0))
		if topo_anterior != Vector3.INF:
			_fio(raiz, topo_anterior, topo)
		topo_anterior = topo
	if praia:
		_orla(raiz, rng)
		_morros_verdes(raiz)
	else:
		_morro(raiz)


static func _perto_de_laje(x: float, z: float, lajes: int) -> bool:
	for k in mini(lajes, LAJES.size()):
		var l: Vector3 = LAJES[k]
		if absf(x - l.x) < 10.0 and absf(z - l.z) < 11.0:
			return true
	return false


static func _na_rua(x: float, z: float, largura: float, fundo: float) -> bool:
	for r in _ruas:
		var rr: Vector4 = r
		if x + largura * 0.5 > rr.x - 2.0 and x - largura * 0.5 < rr.y + 2.0 and z + fundo * 0.5 > rr.z - 2.0 and z - fundo * 0.5 < rr.w + 2.0:
			return true
	return false


static func _material_parede(cor: Color, tijolo: bool) -> ShaderMaterial:
	var chave := "%s|%s" % [cor.to_html(), tijolo]
	if _mats.has(chave):
		return _mats[chave]
	var m := ShaderMaterial.new()
	m.shader = load("res://game/world/shaders/parede.gdshader")
	m.set_shader_parameter("cor", cor)
	m.set_shader_parameter("tijolo", 1.0 if tijolo else 0.0)
	m.set_shader_parameter("semente", float(_mats.size()) * 1.7)
	_mats[chave] = m
	return m


static func _casa(pai: Node3D, base: Vector3, tamanho: Vector3, cor: Color, tijolo: bool, rng: RandomNumberGenerator) -> void:
	var corpo := _caixa(pai, base + Vector3(0.0, tamanho.y * 0.5, 0.0), tamanho, cor, 0.9)
	corpo.material_override = _material_parede(cor, tijolo)
	var topo := base + Vector3(0.0, tamanho.y, 0.0)
	# D-065: parte das casas com telhado de telha de barro (menos "caixote")
	if tamanho.y < 7.0 and rng.randf() < 0.45:
		_telhado(pai, topo, tamanho, rng)
		return
	# mureta da laje em algumas casas
	if rng.randf() < 0.5:
		var mc := cor.darkened(0.08)
		for lado in [Vector3(0.0, 0.0, tamanho.z * 0.5), Vector3(0.0, 0.0, -tamanho.z * 0.5)]:
			_caixa(pai, topo + Vector3(0.0, 0.4, 0.0) + lado, Vector3(tamanho.x, 0.8, 0.12), mc, 0.9)
		for lado in [Vector3(tamanho.x * 0.5, 0.0, 0.0), Vector3(-tamanho.x * 0.5, 0.0, 0.0)]:
			_caixa(pai, topo + Vector3(0.0, 0.4, 0.0) + lado, Vector3(0.12, 0.8, tamanho.z), mc, 0.9)
	# ferragem saindo da laje (casa "em obra"), comum no bairro
	if tijolo and rng.randf() < 0.5:
		for k in 4:
			var px := (-0.5 if k % 2 == 0 else 0.5) * (tamanho.x - 0.4)
			var pz := (-0.5 if k < 2 else 0.5) * (tamanho.z - 0.4)
			_caixa(pai, topo + Vector3(px, 0.5, pz), Vector3(0.04, 1.0, 0.04), Color(0.35, 0.2, 0.15), 0.6)
	if rng.randf() < 0.5:
		_caixa_dagua(pai, topo + Vector3(rng.randf_range(-1.5, 1.5), 0.0, rng.randf_range(-2.0, 2.0)))
	if rng.randf() < 0.3:
		_antena(pai, topo + Vector3(-tamanho.x * 0.3, 0.0, 0.0))
	if rng.randf() < 0.25:
		_varal(pai, topo + Vector3(0.0, 0.0, tamanho.z * 0.2), tamanho.x * 0.7, rng)


static var _mat_telha: ShaderMaterial


static func _telhado(pai: Node3D, topo: Vector3, tamanho: Vector3, rng: RandomNumberGenerator) -> void:
	if _mat_telha == null:
		_mat_telha = ShaderMaterial.new()
		_mat_telha.shader = load("res://game/world/shaders/telha.gdshader")
	var m := MeshInstance3D.new()
	var prisma := PrismMesh.new()
	var ao_longo_x := tamanho.x >= tamanho.z
	var vao := tamanho.z if ao_longo_x else tamanho.x
	var comp := tamanho.x if ao_longo_x else tamanho.z
	prisma.size = Vector3(vao + 0.6, vao * rng.randf_range(0.28, 0.4), comp + 0.6)
	m.mesh = prisma
	m.material_override = _mat_telha
	m.position = topo + Vector3(0.0, prisma.size.y * 0.5, 0.0)
	if ao_longo_x:
		m.rotation.y = PI * 0.5
	pai.add_child(m)


static func _laje(pai: Node3D, base: Vector3, cor_parede: Color, rng: RandomNumberGenerator, sua := false) -> void:
	var h := ALTURA_LAJE
	var corpo := _caixa(pai, base + Vector3(0.0, h * 0.5 - 0.1, 0.0), Vector3(8.0, h - 0.2, 8.0), cor_parede, 0.9)
	corpo.material_override = _material_parede(cor_parede, false)
	# Piso de cerâmica avermelhada, pouco rugosa (brilho do sol baixo).
	# Piso de cerâmica com verniz leve: brilha com o sol, sem ofuscar (D-063).
	var piso := _caixa(pai, base + Vector3(0.0, h - 0.05, 0.0), Vector3(8.2, 0.1, 8.2), Color(0.62, 0.27, 0.18), 0.32)
	(piso.material_override as StandardMaterial3D).metallic_specular = 0.6
	# Mureta. Na SUA laje a da frente (para onde a pipa vai) é baixinha, para
	# não tapar a pipa quando você afunda (D-060).
	for lado in [Vector3(0, 0, 4.0), Vector3(0, 0, -4.0)]:
		var alta := 0.25 if (sua and lado.z < 0.0) else 0.9
		_caixa(pai, base + Vector3(0.0, h + alta * 0.5, 0.0) + lado, Vector3(8.2, alta, 0.15), cor_parede.darkened(0.1), 0.9)
	for lado in [Vector3(4.0, 0, 0), Vector3(-4.0, 0, 0)]:
		_caixa(pai, base + Vector3(0.0, h + 0.45, 0.0) + lado, Vector3(0.15, 0.9, 8.2), cor_parede.darkened(0.1), 0.9)
	_caixa_dagua(pai, base + Vector3(-2.8, h, 2.8))
	if rng.randf() < 0.6:
		_varal(pai, base + Vector3(0.0, h, 3.0), 5.0, rng)


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


static func _cilindro(pai: Node3D, base: Vector3, raio_baixo: float, raio_topo: float, altura: float, cor: Color, lados := 10) -> MeshInstance3D:
	var m := MeshInstance3D.new()
	var malha := CylinderMesh.new()
	malha.top_radius = raio_topo
	malha.bottom_radius = raio_baixo
	malha.height = altura
	malha.radial_segments = lados
	malha.rings = 1
	m.mesh = malha
	var mat := StandardMaterial3D.new()
	mat.albedo_color = cor
	mat.roughness = 0.8
	m.material_override = mat
	m.position = base + Vector3(0.0, altura * 0.5, 0.0)
	pai.add_child(m)
	return m


static func _caixa_dagua(pai: Node3D, base: Vector3) -> void:
	# caixa d'água azul com a tampa mais clara
	_cilindro(pai, base, 0.6, 0.68, 0.95, Color(0.12, 0.38, 0.85), 14)
	_cilindro(pai, base + Vector3(0.0, 0.95, 0.0), 0.7, 0.45, 0.18, Color(0.25, 0.5, 0.95), 14)


static func _antena(pai: Node3D, base: Vector3) -> void:
	_caixa(pai, base + Vector3(0.0, 1.2, 0.0), Vector3(0.05, 2.4, 0.05), Color(0.7, 0.7, 0.7), 0.4)
	_caixa(pai, base + Vector3(0.0, 2.2, 0.0), Vector3(1.2, 0.04, 0.04), Color(0.7, 0.7, 0.7), 0.4)
	_caixa(pai, base + Vector3(0.0, 1.9, 0.0), Vector3(0.9, 0.04, 0.04), Color(0.7, 0.7, 0.7), 0.4)


static func _varal(pai: Node3D, base: Vector3, largura: float, rng: RandomNumberGenerator) -> void:
	var a := base + Vector3(-largura * 0.5, 0.0, 0.0)
	var b := base + Vector3(largura * 0.5, 0.0, 0.0)
	_caixa(pai, a + Vector3(0.0, 0.9, 0.0), Vector3(0.05, 1.8, 0.05), Color(0.6, 0.6, 0.6), 0.5)
	_caixa(pai, b + Vector3(0.0, 0.9, 0.0), Vector3(0.05, 1.8, 0.05), Color(0.6, 0.6, 0.6), 0.5)
	_caixa(pai, base + Vector3(0.0, 1.75, 0.0), Vector3(largura, 0.015, 0.015), Color(0.9, 0.9, 0.9), 0.5)
	var cores := [Color(0.9, 0.2, 0.2), Color(0.2, 0.4, 0.9), Color(1.0, 1.0, 1.0), Color(1.0, 0.8, 0.1), Color(0.2, 0.7, 0.3)]
	var x := -largura * 0.5 + 0.4
	while x < largura * 0.5 - 0.4:
		var w := rng.randf_range(0.35, 0.7)
		var h := rng.randf_range(0.4, 0.75)
		_caixa(pai, base + Vector3(x + w * 0.5, 1.75 - h * 0.5, 0.0), Vector3(w, h, 0.02), cores[rng.randi() % cores.size()], 0.9)
		x += w + rng.randf_range(0.1, 0.5)


static var _mat_folha: Array = []
static var _mat_palha: ShaderMaterial
static var _mat_tronco: StandardMaterial3D


static func _materiais_arvore() -> void:
	if not _mat_folha.is_empty():
		return
	var sh: Shader = load("res://game/world/shaders/folhagem.gdshader")
	for par in [[Color(0.09, 0.24, 0.07), Color(0.33, 0.52, 0.15)], [Color(0.12, 0.28, 0.06), Color(0.45, 0.58, 0.18)],
			[Color(0.07, 0.2, 0.09), Color(0.26, 0.46, 0.2)]]:
		var m := ShaderMaterial.new()
		m.shader = sh
		m.set_shader_parameter("verde_escuro", par[0])
		m.set_shader_parameter("verde_claro", par[1])
		_mat_folha.append(m)
	_mat_palha = ShaderMaterial.new()
	_mat_palha.shader = load("res://game/world/shaders/palha.gdshader")
	_mat_palha.set_shader_parameter("comprimento", 3.0)
	_mat_tronco = StandardMaterial3D.new()
	_mat_tronco.albedo_color = Color(0.33, 0.24, 0.17)
	_mat_tronco.roughness = 0.95


## Árvore (D-065): tronco que afina, galhos, e uma copa feita de várias bolas
## de folhagem furadas por ruído (parece um monte de folhas), balançando.
static func _arvore(pai: Node3D, base: Vector3, rng: RandomNumberGenerator) -> void:
	_materiais_arvore()
	var altura := rng.randf_range(3.2, 5.2)
	var tronco := _cilindro(pai, base, 0.2, 0.11, altura, Color(0.33, 0.24, 0.17), 10)
	tronco.material_override = _mat_tronco
	var mat_f: ShaderMaterial = _mat_folha[rng.randi() % _mat_folha.size()]
	var topo := base + Vector3(0.0, altura, 0.0)
	# galhos abrindo para os lados
	for k in 3:
		var ang := TAU * k / 3.0 + rng.randf() * 0.8
		var galho := MeshInstance3D.new()
		var cil := CylinderMesh.new()
		cil.top_radius = 0.04
		cil.bottom_radius = 0.08
		cil.height = 1.5
		cil.radial_segments = 6
		cil.rings = 1
		galho.mesh = cil
		galho.material_override = _mat_tronco
		galho.position = topo + Vector3(sin(ang) * 0.45, -0.3, cos(ang) * 0.45)
		galho.rotation = Vector3(0.0, ang, 0.0)
		galho.rotate_object_local(Vector3.RIGHT, 0.8)
		pai.add_child(galho)
	# copa: bolas de folhagem
	var raio := rng.randf_range(1.6, 2.3)
	for k in 6:
		var m := MeshInstance3D.new()
		var bola := SphereMesh.new()
		var r := raio * rng.randf_range(0.55, 0.85)
		bola.radius = r
		bola.height = r * 1.7
		bola.radial_segments = 14
		bola.rings = 8
		m.mesh = bola
		m.material_override = mat_f
		var ang2 := rng.randf() * TAU
		var d := raio * rng.randf_range(0.2, 0.6) if k > 0 else 0.0
		m.position = topo + Vector3(sin(ang2) * d, rng.randf_range(-0.2, 0.9) + (0.5 if k == 0 else 0.0), cos(ang2) * d)
		pai.add_child(m)


## Coqueiro (D-065): tronco curvado em gomos e folhas de palha que vergam.
static func _coqueiro(pai: Node3D, base: Vector3, rng: RandomNumberGenerator) -> void:
	_materiais_arvore()
	var altura := rng.randf_range(6.0, 9.0)
	var inclina := Vector3(rng.randf_range(-0.6, 0.6), 0.0, rng.randf_range(-0.6, 0.6))
	var gomos := 6
	var anterior := base
	for k in gomos:
		var t := (k + 1.0) / gomos
		var p := base + Vector3(0.0, altura * t, 0.0) + inclina * t * t
		var seg := MeshInstance3D.new()
		var cil := CylinderMesh.new()
		cil.top_radius = lerpf(0.2, 0.13, t)
		cil.bottom_radius = lerpf(0.2, 0.13, t - 1.0 / gomos) + 0.015
		cil.height = anterior.distance_to(p)
		cil.radial_segments = 9
		cil.rings = 1
		seg.mesh = cil
		var mat := StandardMaterial3D.new()
		mat.albedo_color = Color(0.5, 0.41, 0.3).darkened(0.08 * float(k % 2))
		mat.roughness = 0.95
		seg.material_override = mat
		seg.position = (anterior + p) * 0.5
		var dir := (p - anterior).normalized()
		if absf(dir.dot(Vector3.UP)) < 0.999:
			seg.basis = Basis(Vector3.UP.cross(dir).normalized(), Vector3.UP.angle_to(dir))
		pai.add_child(seg)
		anterior = p
	var topo := anterior
	for k in 9:
		var ang := TAU * k / 9.0 + rng.randf() * 0.25
		var folha := MeshInstance3D.new()
		var plano := PlaneMesh.new()
		plano.size = Vector2(0.9, 3.0)
		plano.subdivide_depth = 10
		plano.orientation = PlaneMesh.FACE_Y
		folha.mesh = plano
		folha.material_override = _mat_palha
		folha.position = topo + Vector3(sin(ang), 0.15, cos(ang)) * 1.45
		folha.rotation = Vector3(-0.25 + rng.randf() * 0.3, ang, 0.0)
		pai.add_child(folha)
	# cocos
	for k in 3:
		var coco := MeshInstance3D.new()
		var b := SphereMesh.new()
		b.radius = 0.13
		b.height = 0.26
		b.radial_segments = 8
		b.rings = 4
		coco.mesh = b
		var mc := StandardMaterial3D.new()
		mc.albedo_color = Color(0.32, 0.4, 0.12)
		coco.material_override = mc
		coco.position = topo + Vector3(sin(k * 2.1) * 0.22, -0.25, cos(k * 2.1) * 0.22)
		pai.add_child(coco)


static func _poste(pai: Node3D, base: Vector3) -> Vector3:
	_cilindro(pai, base, 0.16, 0.11, 9.0, Color(0.62, 0.62, 0.6), 8)
	_caixa(pai, base + Vector3(0.0, 8.6, 0.0), Vector3(1.6, 0.1, 0.1), Color(0.55, 0.55, 0.52), 0.8)
	# luminária
	_caixa(pai, base + Vector3(0.0, 8.2, 0.9), Vector3(0.25, 0.12, 0.6), Color(0.3, 0.3, 0.3), 0.6)
	return base + Vector3(0.0, 8.55, 0.0)


## Fio entre dois postes, com a barriga do peso.
static func _fio(pai: Node3D, a: Vector3, b: Vector3) -> void:
	var im := ImmediateMesh.new()
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.05, 0.05, 0.05)
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	for desvio in [-0.7, 0.7]:
		im.surface_begin(Mesh.PRIMITIVE_LINE_STRIP, mat)
		for k in 13:
			var t := k / 12.0
			var p := a.lerp(b, t) + Vector3(desvio, -1.1 * 4.0 * t * (1.0 - t), 0.0)
			im.surface_add_vertex(p)
		im.surface_end()
	var m := MeshInstance3D.new()
	m.mesh = im
	m.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	pai.add_child(m)


## Morros com casinhas ao fundo (para onde o vento leva as pipas).
static func _morro(pai: Node3D) -> void:
	var mat := ShaderMaterial.new()
	mat.shader = load("res://game/world/shaders/morro.gdshader")
	# [x, z, raio, altura]: longe e baixos, uma serra no horizonte
	for d in [Vector4(-260.0, -520.0, 170.0, 55.0), Vector4(-40.0, -600.0, 230.0, 80.0), Vector4(200.0, -540.0, 190.0, 60.0),
			Vector4(420.0, -480.0, 160.0, 45.0), Vector4(-460.0, -450.0, 150.0, 40.0)]:
		var m := MeshInstance3D.new()
		var malha := SphereMesh.new()
		malha.radius = d.z
		malha.height = d.w * 2.0
		malha.radial_segments = 24
		malha.rings = 12
		m.mesh = malha
		m.material_override = mat
		m.position = Vector3(d.x, 0.0, d.y)
		m.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		pai.add_child(m)


## Orla da praia (D-063): coqueiros no calçadão, quiosques, guarda-sóis
## coloridos na areia e postes da avenida.
static func _orla(pai: Node3D, rng: RandomNumberGenerator) -> void:
	for x in range(-150, 151, 14):
		_coqueiro(pai, Vector3(float(x) + rng.randf_range(-2.0, 2.0), 0.0, -31.0), rng)
	for x in range(-140, 141, 45):
		_quiosque(pai, Vector3(float(x) + 7.0, 0.0, -34.0), rng)
	var cores := [Color(0.95, 0.2, 0.2), Color(1.0, 0.85, 0.1), Color(0.15, 0.45, 0.95), Color(0.2, 0.75, 0.35), Color(1.0, 0.5, 0.1)]
	for k in 40:
		var p := Vector3(rng.randf_range(-150.0, 150.0), 0.0, rng.randf_range(-78.0, -42.0))
		_guarda_sol(pai, p, cores[rng.randi() % cores.size()])
	var anterior := Vector3.INF
	for x in range(-120, 121, 24):
		var topo := _poste(pai, Vector3(float(x), 0.0, -20.0))
		if anterior != Vector3.INF:
			_fio(pai, anterior, topo)
		anterior = topo


static func _quiosque(pai: Node3D, base: Vector3, rng: RandomNumberGenerator) -> void:
	_caixa(pai, base + Vector3(0.0, 1.2, 0.0), Vector3(3.0, 2.4, 2.4), Color(0.95, 0.95, 0.92), 0.6)
	var telhado := MeshInstance3D.new()
	var cone := CylinderMesh.new()
	cone.top_radius = 0.1
	cone.bottom_radius = 2.4
	cone.height = 1.0
	cone.radial_segments = 4
	telhado.mesh = cone
	var mat := StandardMaterial3D.new()
	mat.albedo_color = [Color(0.1, 0.5, 0.3), Color(0.85, 0.3, 0.2), Color(0.2, 0.4, 0.8)][rng.randi() % 3]
	mat.roughness = 0.7
	telhado.material_override = mat
	telhado.position = base + Vector3(0.0, 2.9, 0.0)
	telhado.rotation.y = PI * 0.25
	pai.add_child(telhado)


static func _guarda_sol(pai: Node3D, base: Vector3, cor: Color) -> void:
	_cilindro(pai, base, 0.03, 0.03, 2.1, Color(0.9, 0.9, 0.9), 5)
	var m := MeshInstance3D.new()
	var cone := CylinderMesh.new()
	cone.top_radius = 0.05
	cone.bottom_radius = 1.2
	cone.height = 0.45
	cone.radial_segments = 10
	m.mesh = cone
	var mat := StandardMaterial3D.new()
	mat.albedo_color = cor
	mat.roughness = 0.8
	m.material_override = mat
	m.position = base + Vector3(0.0, 2.1, 0.0)
	pai.add_child(m)


## Morros verdes saindo do mar (como os do Rio), dos dois lados da praia.
static func _morros_verdes(pai: Node3D) -> void:
	var mat := ShaderMaterial.new()
	mat.shader = load("res://game/world/shaders/morro.gdshader")
	mat.set_shader_parameter("topo_verde", -60.0)
	for d in [Vector4(-330.0, -420.0, 90.0, 150.0), Vector4(-250.0, -470.0, 60.0, 90.0),
			Vector4(320.0, -450.0, 110.0, 120.0), Vector4(40.0, -900.0, 260.0, 70.0)]:
		var m := MeshInstance3D.new()
		var malha := SphereMesh.new()
		malha.radius = d.z
		malha.height = d.w * 2.0
		malha.radial_segments = 24
		malha.rings = 12
		m.mesh = malha
		m.material_override = mat
		m.position = Vector3(d.x, 0.0, d.y)
		m.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		pai.add_child(m)
