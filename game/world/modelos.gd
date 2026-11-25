extends RefCounted
## Modelos 3D CC0 do Poly Haven (D-068), baixados pelo GitHub Actions
## (tools/baixar_modelos.py) para assets/modelos. Se faltarem, o cenário
## continua com as peças feitas por código.

const PASTA := "res://assets/modelos/"

static var _cenas := {}
static var _malhas := {}


static func existe(nome: String) -> bool:
	return ResourceLoader.exists(PASTA + nome + "/" + nome + ".gltf")


static func _cena(nome: String) -> PackedScene:
	if not _cenas.has(nome):
		_cenas[nome] = load(PASTA + nome + "/" + nome + ".gltf")
	return _cenas[nome]


## A malha de uma variante (ex.: "fern_02_a"); vários modelos trazem 2 a 4
## variantes lado a lado no mesmo arquivo.
static func malha(nome: String, variante: String) -> Mesh:
	var chave := nome + "/" + variante
	if _malhas.has(chave):
		return _malhas[chave]
	var m: Mesh = null
	if existe(nome):
		var raiz := _cena(nome).instantiate()
		var achado := raiz.find_child(variante, true, false) as MeshInstance3D
		if achado != null:
			m = achado.mesh
		raiz.free()
	_malhas[chave] = m
	return m


## Põe o modelo inteiro (todas as peças) no cenário. Devolve null se faltar.
static func por(pai: Node3D, nome: String, posicao: Vector3, giro_y := 0.0, escala := 1.0) -> Node3D:
	if not existe(nome):
		return null
	var no := _cena(nome).instantiate() as Node3D
	no.position = posicao
	no.rotation.y = giro_y
	no.scale = Vector3.ONE * escala
	pai.add_child(no)
	return no


## Põe só uma variante (uma malha), com escala livre.
static func por_variante(pai: Node3D, nome: String, variante: String, posicao: Vector3, giro_y := 0.0, escala := Vector3.ONE) -> MeshInstance3D:
	var m := malha(nome, variante)
	if m == null:
		return null
	var mi := MeshInstance3D.new()
	mi.mesh = m
	mi.position = posicao
	mi.rotation.y = giro_y
	mi.scale = escala
	pai.add_child(mi)
	return mi
