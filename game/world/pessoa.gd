extends Node3D
## Pipeiro de verdade (D-099): personagens Microsoft Rocketbox (licença MIT),
## convertidos no GitHub pelo tools/recursos/converter.py. Mesma interface do
## Boneco (construir/atualizar), então a partida usa um ou outro sem mudar
## nada na física: o braço da linha vai até a mão da física com IK de dois
## ossos e o outro braço fica na barriga (abraçando a linha ao puxar).
##
## Se os modelos não estiverem no jogo, `disponivel()` devolve false e a
## partida continua com o Boneco antigo.

const MODELOS := ["Male_Adult_01", "Male_Adult_17", "Male_Adult_04", "Male_Adult_16", "Male_Adult_09", "Male_Adult_11", "Male_Adult_20"]
const PASTA := "res://assets/personagens/"

var _modelo: Node3D
var _esq: Skeleton3D
var _ossos := {}          # nome curto -> índice do osso
var _repouso := {}        # índice -> Quaternion de repouso (local)
var _t := 0.0
var _inclinar := 0.0
var _abraco := 0.0
var _olhar := Vector3.ZERO
var _bone_no: Node3D


static func disponivel() -> bool:
	return ResourceLoader.exists(PASTA + MODELOS[0] + ".glb")


## i: número do participante (escolhe o personagem); bone: boné na cabeça;
## cor: cor do boné.
func construir_pessoa(i: int, bone: bool, cor: Color) -> void:
	for filho in get_children():
		filho.queue_free()
	var cena := load(PASTA + MODELOS[i % MODELOS.size()] + ".glb") as PackedScene
	if cena == null:
		return
	_modelo = cena.instantiate() as Node3D
	# o glTF olha para +Z; o pipeiro do jogo olha para -Z (como o Boneco)
	_modelo.rotation.y = PI
	add_child(_modelo)
	var achados := _modelo.find_children("*", "Skeleton3D", true, false)
	if achados.is_empty():
		return
	_esq = achados[0] as Skeleton3D
	for chave in {"ombro_d": "r upperarm", "cot_d": "r forearm", "mao_d": "r hand",
			"ombro_e": "l upperarm", "cot_e": "l forearm", "mao_e": "l hand",
			"cabeca": "head", "coluna": "spine1", "coluna2": "spine2",
			"clav_d": "r clavicle", "clav_e": "l clavicle"}.items():
		_ossos[chave[0]] = _achar_osso(chave[1])
	for b in _esq.get_bone_count():
		_repouso[b] = _esq.get_bone_pose_rotation(b)
	if bone and _ossos["cabeca"] >= 0:
		_por_bone(cor)


## Compatível com a chamada do Boneco (cores viram a escolha do personagem).
func construir(_pele: Color, camisa: Color, _bermuda: Color, bone := true) -> void:
	construir_pessoa(int(absf(camisa.h) * 97.0) % MODELOS.size(), bone, camisa.darkened(0.35))


func _achar_osso(parte: String) -> int:
	for b in _esq.get_bone_count():
		var n := _esq.get_bone_name(b).to_lower()
		if n.ends_with(parte) and not n.contains("nub"):
			return b
	return -1


## Pose global do osso no espaço do esqueleto, calculada pela cadeia de poses
## locais (não depende do cache do Skeleton3D, que só atualiza no fim do quadro).
func _global(b: int) -> Transform3D:
	var t := _esq.get_bone_pose(b)
	var p := _esq.get_bone_parent(b)
	while p >= 0:
		t = _esq.get_bone_pose(p) * t
		p = _esq.get_bone_parent(p)
	return t


func _global_pai(b: int) -> Transform3D:
	var p := _esq.get_bone_parent(b)
	return _global(p) if p >= 0 else Transform3D.IDENTITY


## Gira o osso b (no espaço do esqueleto) pela rotação q.
func _girar(b: int, q: Quaternion) -> void:
	var g := _global(b)
	var nova := Basis(q) * g.basis.orthonormalized()
	var local := _global_pai(b).basis.orthonormalized().inverse() * nova
	_esq.set_bone_pose_rotation(b, local.get_rotation_quaternion())


static func _de_para(a: Vector3, b: Vector3) -> Quaternion:
	if a.length_squared() < 1e-10 or b.length_squared() < 1e-10:
		return Quaternion.IDENTITY
	return Quaternion(a.normalized(), b.normalized())


## IK de dois ossos no espaço do esqueleto: alvo e polo (para onde o cotovelo
## aponta) já convertidos.
func _ik(ombro: int, cot: int, mao: int, alvo: Vector3, polo: Vector3) -> float:
	var a := _global(ombro).origin
	var b := _global(cot).origin
	var c := _global(mao).origin
	var l1 := a.distance_to(b)
	var l2 := b.distance_to(c)
	var para := alvo - a
	var d0 := para.length()
	if d0 < 1e-4:
		return 0.0
	var dir := para / d0
	var d := clampf(d0, absf(l1 - l2) + 1e-3, l1 + l2 - 1e-3)
	var x := (l1 * l1 - l2 * l2 + d * d) / (2.0 * d)
	var h := sqrt(maxf(l1 * l1 - x * x, 0.0))
	var lado := (polo - a) - dir * (polo - a).dot(dir)
	if lado.length_squared() < 1e-8:
		lado = dir.cross(Vector3.RIGHT)
	var cotovelo := a + dir * x + lado.normalized() * h
	_girar(ombro, _de_para(b - a, cotovelo - a))
	var b2 := _global(cot).origin
	var c2 := _global(mao).origin
	_girar(cot, _de_para(c2 - b2, a + dir * d - b2))
	return d0 - (l1 + l2)   # > 0: longe demais


func _por_bone(cor: Color) -> void:
	var cab := _ossos["cabeca"] as int
	var presa := BoneAttachment3D.new()
	presa.bone_idx = cab
	_esq.add_child(presa)
	# posição no repouso: no alto da cabeça, aba para a frente
	var g := _global(cab)
	var em_modelo := _modelo.global_transform.affine_inverse() * _esq.global_transform
	var cima := (em_modelo.basis.inverse() * Vector3.UP).normalized()
	var frente := (em_modelo.basis.inverse() * Vector3.BACK).normalized()   # o glTF olha para +Z
	var escala := (_esq.global_basis.get_scale().x)
	var u := 1.0 / maxf(escala, 1e-6)
	var mat := StandardMaterial3D.new()
	mat.albedo_color = cor
	mat.roughness = 0.85
	_bone_no = Node3D.new()
	presa.add_child(_bone_no)
	var copa := MeshInstance3D.new()
	var esf := SphereMesh.new()
	esf.radius = 0.108
	esf.height = 0.216
	esf.is_hemisphere = true
	esf.radial_segments = 20
	esf.rings = 8
	copa.mesh = esf
	copa.material_override = mat
	var aba := MeshInstance3D.new()
	var cil := CylinderMesh.new()
	cil.top_radius = 0.08
	cil.bottom_radius = 0.08
	cil.height = 0.01
	cil.radial_segments = 20
	aba.mesh = cil
	aba.material_override = mat
	aba.scale = Vector3(1.1, 1.0, 0.85)
	aba.position = Vector3(0.0, 0.0, 0.12)
	copa.add_child(aba)
	copa.scale = Vector3.ONE * u
	_bone_no.add_child(copa)
	# copa no espaço do esqueleto: topo da cabeça
	var base := Basis(Quaternion(Vector3.UP, cima))
	base = Basis(_de_para(base * Vector3.BACK, frente)) * base
	var t_esq := Transform3D(base, g.origin + cima * 0.12 * u + frente * 0.01 * u)
	_bone_no.transform = g.affine_inverse() * t_esq
	copa.rotation.x = -0.08


## mao: onde está a mão da física; alvo: a pipa; puxando: 0..1.
func atualizar(mao: Vector3, alvo: Vector3, puxando: float, delta: float) -> void:
	if _esq == null or not is_inside_tree():
		return
	_t += delta
	var para := alvo - global_position
	para.y = 0.0
	if para.length_squared() > 0.01:
		rotation.y = lerp_angle(rotation.y, atan2(-para.x, -para.z), 1.0 - exp(-6.0 * delta))
	for b in _repouso:
		_esq.set_bone_pose_rotation(b, _repouso[b])
	var inv := _esq.global_transform.affine_inverse()
	var ib := inv.basis
	var frente := -global_basis.z
	var direita := global_basis.x
	# corpo debruça um pouco (dando linha longe) e balança ao puxar
	var p := clampf(puxando, 0.0, 1.0)
	if _ossos["coluna"] >= 0:
		var ang := _inclinar + 0.08 * p + sin(_t * 1.7) * 0.012
		_girar(_ossos["coluna"], Quaternion((ib * direita).normalized(), -ang))
	# braço da linha (direito) até a mão da física
	var ombro_d := global_transform * Vector3(0.18, 1.42, 0.0)
	var polo_d := ombro_d + Vector3.DOWN * 0.6 + direita * 0.35 - frente * 0.1
	var falta := 0.0
	if _ossos["ombro_d"] >= 0:
		falta = _ik(_ossos["ombro_d"], _ossos["cot_d"], _ossos["mao_d"], inv * mao, inv * polo_d)
	_inclinar = clampf(_inclinar + (0.06 if falta > 0.0 else -0.03) * clampf(absf(falta) * 40.0, 0.05, 1.0), 0.0, 0.5)
	# outra mão na barriga; puxando, abraça (vai e volta rápido)
	_abraco = lerpf(_abraco, p, 1.0 - exp(-8.0 * delta))
	var vai := sin(_t * 9.0) * 0.16 * _abraco
	var barriga := global_transform * Vector3(-0.05, 1.05 + vai * 0.4, -0.28 - vai)
	var polo_e := global_transform * Vector3(-0.6, 0.7, 0.1)
	if _ossos["ombro_e"] >= 0:
		_ik(_ossos["ombro_e"], _ossos["cot_e"], _ossos["mao_e"], inv * barriga, inv * polo_e)
	# cabeça olha para a pipa (limitada)
	var cab := _ossos["cabeca"] as int
	if cab >= 0:
		var g := _esq.global_transform * _global(cab).origin
		var olho := (alvo - g)
		if olho.length() > 0.5:
			var quer := olho.normalized()
			var plano := Vector3(quer.x, 0.0, quer.z)
			if plano.length() < 0.2:
				plano = frente
			# guinada limitada a ±60°, inclinação a -30°..+60°
			var yaw := clampf(frente.signed_angle_to(plano.normalized(), Vector3.UP), -1.05, 1.05)
			var pitch := clampf(atan2(quer.y, Vector3(quer.x, 0.0, quer.z).length()), -0.5, 1.05)
			var dir_cab := (Basis(Vector3.UP, yaw) * Basis(direita, pitch)) * frente
			_olhar = dir_cab if _olhar == Vector3.ZERO else _olhar.slerp(dir_cab, 1.0 - exp(-8.0 * delta))
			_girar(cab, _de_para(ib * frente, ib * _olhar))
