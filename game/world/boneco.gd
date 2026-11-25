extends Node3D
## Boneco do pipeiro (D-057): feito de peças simples (sem modelo externo).
## Fica na laje virado para a pipa; um braço segura a linha (vai até a mão da
## física), o outro a carretilha. Puxando, os braços "abraçam" a linha.
## Só visual: lê a posição da mão e o comando; não mexe na física.

var _quadril: Node3D
var _tronco: Node3D
var _braco_linha: Node3D
var _braco_carretilha: Node3D
var _cabeca: Node3D
var _t := 0.0


## pele, camisa, bermuda: cores; bone: com boné.
func construir(pele: Color, camisa: Color, bermuda: Color, bone := true) -> void:
	for filho in get_children():
		filho.queue_free()
	_quadril = Node3D.new()
	_quadril.position = Vector3(0.0, 0.85, 0.0)
	add_child(_quadril)
	# pernas
	for lado in [-0.11, 0.11]:
		_peca(_quadril, Vector3(lado, -0.22, 0.0), Vector3(0.14, 0.42, 0.16), bermuda)
		_peca(_quadril, Vector3(lado, -0.62, 0.0), Vector3(0.11, 0.42, 0.12), pele)
		_peca(_quadril, Vector3(lado, -0.84, 0.05), Vector3(0.12, 0.06, 0.24), Color(0.12, 0.12, 0.14))  # chinelo
	_tronco = Node3D.new()
	_quadril.add_child(_tronco)
	_peca(_tronco, Vector3(0.0, 0.3, 0.0), Vector3(0.4, 0.58, 0.22), camisa)
	_cabeca = Node3D.new()
	_cabeca.position = Vector3(0.0, 0.72, 0.0)
	_tronco.add_child(_cabeca)
	var cabeca := MeshInstance3D.new()
	var esfera := SphereMesh.new()
	esfera.radius = 0.13
	esfera.height = 0.3
	esfera.radial_segments = 12
	esfera.rings = 8
	cabeca.mesh = esfera
	cabeca.material_override = _material(pele)
	_cabeca.add_child(cabeca)
	if bone:
		_peca(_cabeca, Vector3(0.0, 0.1, 0.0), Vector3(0.27, 0.08, 0.27), camisa.darkened(0.3))
		_peca(_cabeca, Vector3(0.0, 0.08, -0.18), Vector3(0.22, 0.03, 0.14), camisa.darkened(0.3))
	_braco_linha = _braco(Vector3(0.24, 0.55, 0.0), camisa, pele)
	_braco_carretilha = _braco(Vector3(-0.24, 0.55, 0.0), camisa, pele)
	# carretilha (lata de linha) na mão de baixo
	var lata := MeshInstance3D.new()
	var cil := CylinderMesh.new()
	cil.top_radius = 0.07
	cil.bottom_radius = 0.07
	cil.height = 0.12
	cil.radial_segments = 10
	lata.mesh = cil
	lata.material_override = _material(Color(0.75, 0.75, 0.78))
	lata.position = Vector3(0.0, -0.55, 0.0)
	lata.rotation = Vector3(0.0, 0.0, PI * 0.5)
	_braco_carretilha.add_child(lata)


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
	if (alvo - _cabeca.global_position).length() > 0.5:
		_cabeca.look_at(alvo, Vector3.UP, true)
	# braço da linha aponta para a mão da física
	_apontar(_braco_linha, mao)
	# braço da carretilha: perto da barriga; puxando, abraça (vai e volta)
	var abraco := sin(_t * 9.0) * 0.5 * clampf(puxando, 0.0, 1.0)
	_braco_carretilha.rotation = Vector3(-0.9 + abraco, 0.0, 0.35)


func _apontar(braco: Node3D, ponto: Vector3) -> void:
	var de := braco.global_position
	var dir := ponto - de
	if dir.length() < 0.05:
		return
	# o braço é desenhado para baixo (-Y): gira -Y até a direção da mão
	var b := Basis.looking_at(dir.normalized(), Vector3.UP if absf(dir.normalized().y) < 0.98 else Vector3.FORWARD)
	braco.global_basis = b * Basis(Vector3.RIGHT, PI * 0.5)


func _braco(ombro: Vector3, camisa: Color, pele: Color) -> Node3D:
	var pivo := Node3D.new()
	pivo.position = ombro
	_tronco.add_child(pivo)
	_peca(pivo, Vector3(0.0, -0.1, 0.0), Vector3(0.12, 0.2, 0.12), camisa)
	_peca(pivo, Vector3(0.0, -0.36, 0.0), Vector3(0.09, 0.34, 0.09), pele)
	return pivo


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
	var mat := StandardMaterial3D.new()
	mat.albedo_color = cor
	mat.roughness = 0.85
	return mat
