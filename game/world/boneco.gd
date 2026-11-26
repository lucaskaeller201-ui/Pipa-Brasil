extends Node3D
## Boneco do pipeiro (D-057, D-069): corpo de formas suaves feitas por código
## (sem modelo externo, porque não há boneco realista CC0 que dê para baixar
## automaticamente). Tronco, pernas e braços são "torneados" por seções
## (ombro largo, cintura, quadril, panturrilha, joelho), braço com cotovelo
## que dobra (IK de dois ossos) para a mão chegar na linha, rosto com nariz,
## orelhas, sobrancelhas, olhos; camiseta com manga, bermuda e chinelo.
## Fica na laje virado para a pipa; um braço segura a linha (vai até a mão da
## física), o outro a carretilha. Puxando, os braços "abraçam" a linha.
## Só visual: lê a posição da mão e o comando; não mexe na física.

const BRACO := 0.29       # ombro → cotovelo (m)
const ANTEBRACO := 0.27   # cotovelo → meio da mão (m)

var _quadril: Node3D
var _tronco: Node3D
var _braco_linha: Node3D
var _braco_carretilha: Node3D
var _cabeca: Node3D
var _t := 0.0
var _mats := {}


## pele, camisa, bermuda: cores; bone: com boné.
func construir(pele: Color, camisa: Color, bermuda: Color, bone := true) -> void:
	for filho in get_children():
		filho.queue_free()
	_mats.clear()
	var cabelo_cor := Color(0.07, 0.05, 0.04)
	_quadril = Node3D.new()
	_quadril.position = Vector3(0.0, 0.92, 0.0)
	add_child(_quadril)
	# pernas: coxa, joelho, panturrilha, tornozelo
	for lado in [-0.1, 0.1]:
		var perna := _torneado([[-0.86, 0.035, 0.04], [-0.8, 0.042, 0.045], [-0.62, 0.058, 0.06], [-0.48, 0.048, 0.05],
			[-0.3, 0.07, 0.072], [-0.08, 0.085, 0.088], [0.02, 0.08, 0.08]], pele, 14)
		perna.position = Vector3(lado, 0.0, 0.0)
		_quadril.add_child(perna)
		# bermuda (um pouco mais larga, até acima do joelho)
		var bermuda_m := _torneado([[-0.42, 0.075, 0.08], [-0.25, 0.088, 0.09], [-0.05, 0.1, 0.1], [0.06, 0.1, 0.1]], bermuda, 14)
		bermuda_m.position = Vector3(lado, 0.0, 0.0)
		_quadril.add_child(bermuda_m)
		# pé e chinelo de dedo
		_oval(_quadril, Vector3(lado, -0.87, -0.06), Vector3(0.045, 0.03, 0.11), pele)
		var chinelo := _peca(_quadril, Vector3(lado, -0.9, -0.06), Vector3(0.1, 0.015, 0.25), Color(0.1, 0.35, 0.75))
		chinelo.scale = Vector3.ONE
		_peca(_quadril, Vector3(lado, -0.875, -0.1), Vector3(0.08, 0.012, 0.012), Color(0.95, 0.95, 0.95))  # tira
	# cós da bermuda
	_quadril.add_child(_anel(0.0, 0.17, 0.11, 0.05, bermuda.darkened(0.2)))
	_tronco = Node3D.new()
	_quadril.add_child(_tronco)
	# tronco torneado: quadril, cintura, peito, ombros (camiseta)
	var torso := _torneado([[0.0, 0.17, 0.11], [0.12, 0.155, 0.1], [0.28, 0.18, 0.115], [0.4, 0.2, 0.115],
		[0.47, 0.19, 0.1], [0.52, 0.1, 0.075], [0.54, 0.06, 0.06]], camisa, 20)
	_tronco.add_child(torso)
	# gola e pescoço
	_tronco.add_child(_anel(0.52, 0.072, 0.066, 0.025, camisa.darkened(0.15)))
	var pescoco := _torneado([[0.5, 0.05, 0.052], [0.62, 0.046, 0.05]], pele, 12)
	_tronco.add_child(pescoco)
	# número nas costas (time do bairro)
	_peca(_tronco, Vector3(0.0, 0.33, 0.118), Vector3(0.12, 0.14, 0.006), camisa.lightened(0.55))
	# cabeça
	_cabeca = Node3D.new()
	_cabeca.position = Vector3(0.0, 0.7, 0.0)
	_tronco.add_child(_cabeca)
	_oval(_cabeca, Vector3(0.0, 0.0, 0.0), Vector3(0.095, 0.118, 0.108), pele)          # crânio
	_oval(_cabeca, Vector3(0.0, -0.06, -0.03), Vector3(0.075, 0.06, 0.075), pele)       # queixo/maxilar
	_oval(_cabeca, Vector3(0.0, -0.005, -0.112), Vector3(0.017, 0.032, 0.022), pele.darkened(0.04))   # nariz
	for lado in [-1.0, 1.0]:
		_oval(_cabeca, Vector3(lado * 0.094, -0.005, 0.0), Vector3(0.014, 0.03, 0.022), pele.darkened(0.06))   # orelha
		_oval(_cabeca, Vector3(lado * 0.035, 0.022, -0.094), Vector3(0.017, 0.011, 0.008), Color(0.95, 0.95, 0.93))   # olho
		_oval(_cabeca, Vector3(lado * 0.035, 0.022, -0.1), Vector3(0.008, 0.008, 0.004), Color(0.1, 0.06, 0.04))      # íris
		var sobr := _peca(_cabeca, Vector3(lado * 0.036, 0.045, -0.1), Vector3(0.032, 0.007, 0.01), cabelo_cor)
		sobr.rotation.z = -lado * 0.12
	_peca(_cabeca, Vector3(0.0, -0.052, -0.098), Vector3(0.032, 0.006, 0.006), pele.darkened(0.25))   # boca
	# cabelo curto (uma calota um pouco maior que a cabeça)
	var cabelo := _oval(_cabeca, Vector3(0.0, 0.022, 0.01), Vector3(0.1, 0.105, 0.108), cabelo_cor, true)
	cabelo.visible = not bone
	if bone:
		_oval(_cabeca, Vector3(0.0, 0.035, 0.008), Vector3(0.104, 0.1, 0.112), camisa.darkened(0.35), true)
		var aba := MeshInstance3D.new()
		var cil := CylinderMesh.new()
		cil.top_radius = 0.075
		cil.bottom_radius = 0.075
		cil.height = 0.01
		cil.radial_segments = 20
		aba.mesh = cil
		aba.material_override = _material(camisa.darkened(0.45))
		aba.position = Vector3(0.0, 0.05, -0.13)
		aba.scale = Vector3(1.1, 1.0, 0.85)
		aba.rotation.x = 0.12
		_cabeca.add_child(aba)
	else:
		_oval(_cabeca, Vector3(0.0, 0.0, 0.03), Vector3(0.098, 0.09, 0.09), cabelo_cor)   # nuca
	_braco_linha = _braco(Vector3(0.2, 0.45, 0.0), camisa, pele)
	_braco_carretilha = _braco(Vector3(-0.2, 0.45, 0.0), camisa, pele)
	# carretilha (lata de linha) na mão de baixo
	var lata := MeshInstance3D.new()
	var lc := CylinderMesh.new()
	lc.top_radius = 0.07
	lc.bottom_radius = 0.07
	lc.height = 0.12
	lc.radial_segments = 16
	lata.mesh = lc
	var mlata := _material(Color(0.78, 0.78, 0.8))
	mlata.metallic = 0.8
	mlata.roughness = 0.35
	lata.material_override = mlata
	lata.position = Vector3(0.0, -ANTEBRACO, 0.0)
	lata.rotation = Vector3(0.0, 0.0, PI * 0.5)
	(_braco_carretilha.get_node("Cotovelo") as Node3D).add_child(lata)


## mao: onde está a mão da física (a linha sai dali); alvo: a pipa;
## puxando: o jogador está puxando (velocidade da linha > 0).
func atualizar(mao: Vector3, alvo: Vector3, puxando: float, delta: float) -> void:
	if _quadril == null:
		return
	_t += delta
	# vira o corpo para a pipa (só em volta do eixo vertical)
	var para := alvo - global_position
	para.y = 0.0
	if para.length_squared() > 0.01:
		var guinada := atan2(-para.x, -para.z)
		rotation.y = lerp_angle(rotation.y, guinada, 1.0 - exp(-6.0 * delta))
	# respiração / balanço leve
	_tronco.rotation.x = -0.08 * clampf(puxando, 0.0, 1.0) + sin(_t * 1.7) * 0.015
	if is_inside_tree() and (alvo - _cabeca.global_position).length() > 0.5:
		_cabeca.look_at(alvo, Vector3.UP)
		_cabeca.rotation.x = clampf(_cabeca.rotation.x, -0.5, 0.9)
	# braço da linha: a mão vai até a mão da física (cotovelo dobra)
	if is_inside_tree():
		_alcancar(_braco_linha, mao)
	# braço da carretilha: perto da barriga; puxando, abraça (vai e volta)
	var abraco := sin(_t * 9.0) * 0.5 * clampf(puxando, 0.0, 1.0)
	# (girar +X leva a mão para a frente: o boneco olha para -Z)
	_braco_carretilha.rotation = Vector3(0.35 + abraco, 0.0, 0.22)
	(_braco_carretilha.get_node("Cotovelo") as Node3D).rotation = Vector3(1.4, 0.0, 0.0)


## IK de dois ossos: aponta o braço para o alvo e dobra o cotovelo para a
## distância certa (cotovelo para baixo e para fora, como gente).
func _alcancar(braco: Node3D, ponto: Vector3) -> void:
	var de := braco.global_position
	var dir := ponto - de
	var d := dir.length()
	if d < 0.05:
		return
	var n := dir / d
	var dd := clampf(d, 0.12, BRACO + ANTEBRACO - 0.002)
	var cos_ombro := clampf((BRACO * BRACO + dd * dd - ANTEBRACO * ANTEBRACO) / (2.0 * BRACO * dd), -1.0, 1.0)
	var cos_cot := clampf((BRACO * BRACO + ANTEBRACO * ANTEBRACO - dd * dd) / (2.0 * BRACO * ANTEBRACO), -1.0, 1.0)
	var a_ombro := acos(cos_ombro)
	var dobra := PI - acos(cos_cot)
	# o braço é desenhado para baixo (-Y): gira -Y até a direção da mão
	var b := Basis.looking_at(n, Vector3.UP if absf(n.y) < 0.98 else Vector3.FORWARD)
	# -a_ombro abaixa o cotovelo; +dobra traz o antebraço de volta ao alvo
	braco.global_basis = b * Basis(Vector3.RIGHT, PI * 0.5) * Basis(Vector3.RIGHT, -a_ombro)
	(braco.get_node("Cotovelo") as Node3D).rotation = Vector3(dobra, 0.0, 0.0)


func _braco(ombro: Vector3, camisa: Color, pele: Color) -> Node3D:
	var pivo := Node3D.new()
	pivo.position = ombro
	_tronco.add_child(pivo)
	_oval(pivo, Vector3(0.0, -0.02, 0.0), Vector3(0.075, 0.07, 0.07), camisa)   # ombro
	pivo.add_child(_torneado([[-BRACO, 0.038, 0.04], [-0.18, 0.046, 0.048], [-0.04, 0.055, 0.055]], pele, 12))
	pivo.add_child(_torneado([[-0.15, 0.06, 0.06], [-0.02, 0.07, 0.068]], camisa, 14))   # manga
	var cot := Node3D.new()
	cot.name = "Cotovelo"
	cot.position = Vector3(0.0, -BRACO, 0.0)
	pivo.add_child(cot)
	cot.add_child(_torneado([[-ANTEBRACO + 0.04, 0.028, 0.032], [-0.12, 0.04, 0.044], [0.01, 0.038, 0.04]], pele, 12))
	# mão: palma + polegar
	_oval(cot, Vector3(0.0, -ANTEBRACO, 0.0), Vector3(0.035, 0.05, 0.022), pele)
	var polegar := _oval(cot, Vector3(0.025, -ANTEBRACO + 0.02, -0.012), Vector3(0.012, 0.03, 0.012), pele)
	polegar.rotation.z = 0.5
	return pivo


## Forma "torneada": anéis elípticos [y, raio_x, raio_z] ligados, com tampas.
func _torneado(secoes: Array, cor: Color, lados := 16) -> MeshInstance3D:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	st.set_smooth_group(0)
	var aneis: Array = []
	for s in secoes:
		var anel: Array = []
		for k in lados:
			var a := TAU * k / lados
			anel.append(Vector3(cos(a) * float(s[1]), float(s[0]), sin(a) * float(s[2])))
		aneis.append(anel)
	for i in aneis.size() - 1:
		for k in lados:
			var k2 := (k + 1) % lados
			var a: Vector3 = aneis[i][k]
			var b: Vector3 = aneis[i][k2]
			var c: Vector3 = aneis[i + 1][k]
			var d: Vector3 = aneis[i + 1][k2]
			for v in [a, c, b, b, c, d]:
				st.add_vertex(v)
	# tampas
	for ponta in [0, aneis.size() - 1]:
		var centro := Vector3(0.0, float(secoes[ponta][0]), 0.0)
		for k in lados:
			var a: Vector3 = aneis[ponta][k]
			var b: Vector3 = aneis[ponta][(k + 1) % lados]
			if ponta == 0:
				for v in [centro, a, b]:
					st.add_vertex(v)
			else:
				for v in [centro, b, a]:
					st.add_vertex(v)
	st.generate_normals()
	var m := MeshInstance3D.new()
	m.mesh = st.commit()
	m.material_override = _material(cor)
	return m


func _anel(y: float, rx: float, rz: float, altura: float, cor: Color) -> MeshInstance3D:
	return _torneado([[y - altura * 0.5, rx, rz], [y + altura * 0.5, rx, rz]], cor, 20)


func _oval(pai: Node3D, centro: Vector3, raios: Vector3, cor: Color, meia := false) -> MeshInstance3D:
	var m := MeshInstance3D.new()
	var e := SphereMesh.new()
	e.radius = 1.0
	e.height = 1.0 if meia else 2.0
	e.is_hemisphere = meia
	e.radial_segments = 20
	e.rings = 10
	m.mesh = e
	m.material_override = _material(cor)
	m.position = centro
	m.scale = raios
	pai.add_child(m)
	return m


func _peca(pai: Node3D, centro: Vector3, tamanho: Vector3, cor: Color) -> MeshInstance3D:
	var m := MeshInstance3D.new()
	var caixa := BoxMesh.new()
	caixa.size = tamanho
	m.mesh = caixa
	m.material_override = _material(cor)
	m.position = centro
	pai.add_child(m)
	return m


func _material(cor: Color) -> StandardMaterial3D:
	var chave := cor.to_html()
	if _mats.has(chave):
		return _mats[chave]
	var mat := StandardMaterial3D.new()
	mat.albedo_color = cor
	mat.roughness = 0.8
	# luz de contorno suave: dá volume de pele/tecido sob o sol
	mat.rim_enabled = true
	mat.rim = 0.25
	mat.rim_tint = 0.6
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	_mats[chave] = mat
	return mat
