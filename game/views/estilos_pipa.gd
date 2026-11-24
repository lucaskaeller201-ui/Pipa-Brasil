extends RefCounted
## Desenhos e cores das pipas (só visual; a física é a mesma). Inspirados nas
## pipas dos vídeos do Lucas: raias e peixinhos com estampas fortes e rabiola
## de fitinhas coloridas. D-043.
##
## Cada estilo: nome, forma ("raia" ou "peixinho"), padrão, cores [A, B, C] e
## cores das fitinhas da rabiola.

const ESTILOS := [
	{"nome": "Raia preta", "forma": "raia", "padrao": "borda",
		"cores": [Color(0.08, 0.08, 0.09), Color(0.95, 0.95, 0.95), Color(0.08, 0.08, 0.09)],
		"fitas": [Color(0.1, 0.1, 0.1), Color(0.95, 0.95, 0.95)]},
	{"nome": "Peixinho laranja", "forma": "peixinho", "padrao": "xadrez",
		"cores": [Color(1.0, 0.45, 0.08), Color(0.12, 0.08, 0.06), Color(1.0, 0.45, 0.08)],
		"fitas": [Color(1.0, 0.5, 0.1), Color(0.1, 0.1, 0.1)]},
	{"nome": "Rosa do olho", "forma": "raia", "padrao": "olho",
		"cores": [Color(1.0, 0.15, 0.75), Color(0.08, 0.08, 0.08), Color(1.0, 1.0, 1.0)],
		"fitas": [Color(1.0, 0.2, 0.8), Color(1.0, 1.0, 1.0)]},
	{"nome": "Verde e amarela", "forma": "raia", "padrao": "losango",
		"cores": [Color(0.05, 0.6, 0.2), Color(1.0, 0.85, 0.05), Color(0.1, 0.2, 0.75)],
		"fitas": [Color(0.1, 0.65, 0.2), Color(1.0, 0.88, 0.1)]},
	{"nome": "Metade azul", "forma": "peixinho", "padrao": "metades",
		"cores": [Color(0.1, 0.35, 0.95), Color(1.0, 1.0, 1.0), Color(0.1, 0.35, 0.95)],
		"fitas": [Color(0.15, 0.4, 1.0), Color(1.0, 1.0, 1.0)]},
	{"nome": "Vermelha cruzada", "forma": "raia", "padrao": "cruz",
		"cores": [Color(0.9, 0.1, 0.1), Color(1.0, 0.85, 0.2), Color(0.9, 0.1, 0.1)],
		"fitas": [Color(0.95, 0.15, 0.1), Color(1.0, 0.85, 0.2)]},
	{"nome": "Roxa listrada", "forma": "peixinho", "padrao": "listras",
		"cores": [Color(0.5, 0.15, 0.85), Color(0.3, 0.95, 0.95), Color(0.5, 0.15, 0.85)],
		"fitas": [Color(0.55, 0.2, 0.9), Color(0.3, 0.95, 0.95)]},
	{"nome": "Branca e vermelha", "forma": "raia", "padrao": "quadrantes",
		"cores": [Color(0.97, 0.97, 0.97), Color(0.9, 0.1, 0.12), Color(0.97, 0.97, 0.97)],
		"fitas": [Color(0.95, 0.1, 0.12), Color(1.0, 1.0, 1.0)]},
]


## Cor do ponto (nx, ny) da vela: nx de -1 (esquerda) a 1 (direita), ny de -1
## (baixo) a 1 (bico); o losango é |nx| + |ny| <= 1.
static func cor(estilo: Dictionary, nx: float, ny: float) -> Color:
	var c: Array = estilo["cores"]
	var a: Color = c[0]
	var b: Color = c[1]
	var k: Color = c[2]
	var r := absf(nx) + absf(ny)
	match String(estilo["padrao"]):
		"borda":
			return b if r > 0.82 else a
		"xadrez":
			var i := floori((nx + 1.0) * 3.0) + floori((ny + 1.0) * 3.0)
			return a if i % 2 == 0 else b
		"olho":
			var d := Vector2(nx, ny * 0.8).length()
			if d < 0.14:
				return a
			if d < 0.3:
				return k
			if d < 0.42:
				return b
			return a
		"losango":
			if Vector2(nx, ny).length() < 0.28:
				return k
			return b if r < 0.68 else a
		"metades":
			return a if nx < 0.0 else b
		"cruz":
			return b if absf(nx) < 0.12 or absf(ny) < 0.1 else a
		"listras":
			return a if int(floor((ny + 1.0) * 4.0)) % 2 == 0 else b
		"quadrantes":
			return a if (nx < 0.0) == (ny < 0.0) else b
	return a
