extends RefCounted
## Modelos e desenhos das pipas (D-043, D-045). Só visual: todas voam com a
## mesma física por enquanto.
##
## Formatos com as medidas de pipeiros (em cm): vareta central, vareta de cima
## (superior), vareta de baixo (inferior), bico (da ponta até a vareta de
## cima), caixa (entre as varetas) e rabeta (da vareta de baixo até o fim).
## Fontes: tabelas da Voar Pipas e da Escola de Pipeiros (escoladepipeiros.
## blogspot.com, "Pipas e medidas"), enviadas pelo Lucas.
## Estampas inspiradas nos moldes; cores: [fundo, cor 2, cor 3, topo].

const PRETO := Color(0.07, 0.07, 0.08)
const BRANCO := Color(0.97, 0.97, 0.97)
const VERMELHO := Color(0.9, 0.1, 0.12)
const AMARELO := Color(1.0, 0.86, 0.1)
const AZUL := Color(0.45, 0.75, 1.0)
const VERDE := Color(0.55, 0.95, 0.2)
const ROXO := Color(0.55, 0.1, 0.85)
const ROSA := Color(1.0, 0.1, 0.55)
const LILAS := Color(1.0, 0.6, 1.0)

const ESTILOS := [
	{"nome": "GT 70", "m": [70, 53, 35, 28.3, 21.8, 19.9], "padrao": "gt",
		"cores": [VERMELHO, AMARELO, PRETO, BRANCO], "fitas": [VERMELHO, AMARELO]},
	{"nome": "Pizza 55", "m": [55, 42, 31, 16, 17, 22], "padrao": "olho",
		"cores": [Color(1.0, 0.5, 0.05), PRETO, BRANCO, AMARELO], "fitas": [Color(1.0, 0.5, 0.05), PRETO]},
	{"nome": "Come Rato 50", "m": [50, 39, 36, 15.5, 16, 18.5], "padrao": "x",
		"cores": [PRETO, AMARELO, VERMELHO, BRANCO], "fitas": [PRETO, AMARELO]},
	{"nome": "Mucha Mucha 70", "m": [70, 54, 52, 18, 24, 28], "padrao": "listras_v",
		"cores": [ROSA, BRANCO, PRETO, BRANCO], "fitas": [ROSA, BRANCO]},
	{"nome": "Carrapeta 90", "m": [90, 66, 57, 34.8, 21.1, 34.1], "padrao": "v",
		"cores": [PRETO, BRANCO, VERDE, AZUL], "fitas": [PRETO, VERDE]},
	{"nome": "Britt 90", "m": [90, 69, 66, 22, 32, 36], "padrao": "v",
		"cores": [PRETO, ROXO, VERDE, AZUL], "fitas": [ROXO, VERDE]},
	{"nome": "Charutinho 55", "m": [55, 42, 36, 14.9, 24, 16.1], "padrao": "x",
		"cores": [AMARELO, AZUL, VERMELHO, BRANCO], "fitas": [AMARELO, AZUL]},
	{"nome": "Palito 70", "m": [70, 44, 44, 16, 29, 25], "padrao": "colunas",
		"cores": [PRETO, ROSA, PRETO, BRANCO], "fitas": [ROSA, PRETO]},
	{"nome": "Bicuda 55", "m": [55, 38, 36, 20, 16, 19], "padrao": "blocos",
		"cores": [BRANCO, Color(0.1, 0.6, 0.15), VERDE, BRANCO], "fitas": [VERDE, BRANCO]},
	{"nome": "Gigante 1,50 m", "m": [150, 102, 97, 50, 51, 49], "padrao": "x",
		"cores": [PRETO, BRANCO, VERMELHO, BRANCO], "fitas": [PRETO, BRANCO]},
	{"nome": "Vanda 70", "m": [70, 50, 46, 24.8, 20.4, 24.8], "padrao": "grade",
		"cores": [Color(0.2, 0.85, 1.0), PRETO, PRETO, BRANCO], "fitas": [Color(0.2, 0.85, 1.0), PRETO]},
	{"nome": "Gigante 70", "m": [70, 60, 56, 15, 25, 30], "padrao": "triangulos",
		"cores": [PRETO, Color(0.8, 0.1, 0.5), AZUL, BRANCO], "fitas": [Color(0.8, 0.1, 0.5), PRETO]},
	{"nome": "Latão 70", "m": [70, 58, 58, 15.8, 39.7, 14.5], "padrao": "grade_larga",
		"cores": [PRETO, BRANCO, PRETO, BRANCO], "fitas": [PRETO, BRANCO]},
	{"nome": "Pipa 70 (xis)", "m": [70, 60, 50, 21.5, 19, 29.5], "padrao": "x_largo",
		"cores": [PRETO, BRANCO, PRETO, BRANCO], "fitas": [PRETO, BRANCO]},
	{"nome": "Francesinha 45", "m": [45, 34, 29, 14.3, 14.5, 16.2], "padrao": "v_listras",
		"cores": [BRANCO, PRETO, VERMELHO, BRANCO], "fitas": [PRETO, VERMELHO]},
	{"nome": "Lápis 62", "m": [62, 46, 44, 15, 21, 26], "padrao": "listras_v",
		"cores": [Color(0.9, 0.05, 0.9), PRETO, BRANCO, BRANCO], "fitas": [Color(0.9, 0.05, 0.9), BRANCO]},
	{"nome": "Charuto 70", "m": [70, 49, 43, 20, 26, 24], "padrao": "metades",
		"cores": [Color(0.5, 0.05, 0.15), AMARELO, PRETO, BRANCO], "fitas": [Color(0.5, 0.05, 0.15), AMARELO]},
	{"nome": "Carrapeta Rio 60", "m": [60, 46, 31, 22, 21.5, 16.5], "padrao": "borda",
		"cores": [Color(0.1, 0.35, 0.95), BRANCO, BRANCO, AMARELO], "fitas": [Color(0.1, 0.35, 0.95), BRANCO]},
	{"nome": "Batata 66", "m": [66, 54, 52, 21, 15, 30], "padrao": "quadrantes",
		"cores": [BRANCO, VERMELHO, BRANCO, VERMELHO], "fitas": [VERMELHO, BRANCO]},
	{"nome": "Bicão Carioca 70", "m": [70, 48, 45, 26.5, 19.5, 24], "padrao": "cruz",
		"cores": [Color(0.05, 0.6, 0.2), AMARELO, AZUL, AMARELO], "fitas": [Color(0.05, 0.6, 0.2), AMARELO]},
]


## Cor de um ponto da vela. X: -1 (esquerda) a 1 (direita), relativo à meia
## largura maior; T: 0 no bico a 1 na ponta de baixo; tb e tc: onde ficam a
## vareta de cima e a de baixo (em T). O bico (acima da vareta de cima) tem a
## cor de topo.
static func cor(estilo: Dictionary, x: float, t: float, tb: float, tc: float) -> Color:
	var c: Array = estilo["cores"]
	var a: Color = c[0]
	var b: Color = c[1]
	var k: Color = c[2]
	var topo: Color = c[3]
	if t < tb:
		return topo
	var f := (t - tb) / maxf(1.0 - tb, 0.01)      # 0 na vareta de cima, 1 embaixo
	var ax := absf(x)
	match String(estilo["padrao"]):
		"gt":
			var s := ax + f * 0.55
			if s < 0.35:
				return AMARELO
			if s < 0.47:
				return BRANCO
			if s < 0.6:
				return b if b != AMARELO else PRETO
			if s < 0.68:
				return BRANCO
			return a
		"v":
			# V grandes encaixados (Carrapeta, Britt)
			var d := absf(ax - 0.75 * (1.0 - f))
			if d < 0.09:
				return b
			if absf(ax - 0.45 * (1.0 - f)) < 0.1 and f < 0.85:
				return k
			return a
		"v_listras":
			var d2 := fposmod(ax + f * 0.9, 0.36)
			if Vector2(x, (f - 0.4) * 1.4).length() < 0.12:
				return k
			return b if d2 < 0.14 else a
		"x", "x_largo":
			var largura := 0.12 if String(estilo["padrao"]) == "x" else 0.2
			var yy := (f - 0.45) * 1.6
			if absf(x) + absf(yy) < 0.18:
				return k
			return b if absf(x - yy) < largura or absf(x + yy) < largura else a
		"olho":
			var dd := Vector2(x, (f - 0.35) * 1.5).length()
			if dd < 0.12:
				return a
			if dd < 0.26:
				return k
			if dd < 0.38:
				return b
			return a
		"listras_v":
			var i := floori((x + 1.0) * 5.0)
			if i % 3 == 0:
				return b
			if i % 3 == 1:
				return k
			return a
		"colunas":
			if f > 0.62 or ax < 0.28:
				return a
			return b
		"blocos":
			if ax < 0.22:
				return b if fposmod(f, 0.35) < 0.24 else a
			if f < 0.18 or f > 0.82:
				return k
			return a
		"grade":
			var gx := fposmod(x * 4.5, 1.0)
			var gy := fposmod(f * 7.0, 1.0)
			return b if gx < 0.18 or gy < 0.18 else a
		"grade_larga":
			return b if absf(ax - 0.4) < 0.12 or absf(f - 0.3) < 0.08 or absf(f - 0.62) < 0.08 else a
		"triangulos":
			var tri := ax + (1.0 - f) * 0.0 - (0.95 - f) * 0.9
			if tri > 0.0 and tri < 0.1:
				return b
			if ax < (0.7 - f) * 0.55 and f < 0.7:
				return k
			return a
		"metades":
			return a if x < 0.0 else b
		"borda":
			return b if ax > 0.82 or f > 0.85 else a
		"quadrantes":
			return a if (x < 0.0) == (f < 0.5) else b
		"cruz":
			return b if ax < 0.12 or absf(f - 0.35) < 0.08 else a
	return a
