extends RefCounted
## Modelos e desenhos das pipas (D-043, D-045, D-064).
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

## Catálogo (D-064): desenhos originais nossos, inspirados nos TIPOS de pipa;
## velocidade (km/h), força (g) e rabiola (m) mudam o voo (FreeMode.kite_for).
const ESTILOS := [
	{"nome": "Flechinha", "m": [55, 40, 40, 22, 0, 33], "padrao": "estrela",
		"cores": [VERDE, PRETO, AMARELO, BRANCO], "fitas": [VERDE, PRETO], "velocidade": 60, "forca": 52, "rabiola": 4},
	{"nome": "Pipa", "m": [70, 52, 42, 23, 23, 24], "padrao": "listras_v",
		"cores": [PRETO, BRANCO, AZUL, BRANCO], "fitas": [PRETO, BRANCO], "velocidade": 49, "forca": 138, "rabiola": 10},
	{"nome": "Baratinha", "m": [50, 44, 40, 16, 16, 18], "padrao": "x_largo",
		"cores": [PRETO, Color(0.3, 0.3, 0.32), PRETO, BRANCO], "fitas": [PRETO, Color(0.3, 0.3, 0.32)], "velocidade": 55, "forca": 81, "rabiola": 0},
	{"nome": "Batatinha", "m": [55, 46, 44, 15, 22, 18], "padrao": "coracao",
		"cores": [BRANCO, VERMELHO, PRETO, BRANCO], "fitas": [BRANCO, VERMELHO], "velocidade": 57, "forca": 94, "rabiola": 5},
	{"nome": "Volantines", "m": [60, 58, 58, 30, 0, 30], "padrao": "estrela",
		"cores": [PRETO, AMARELO, PRETO, PRETO], "fitas": [PRETO, AMARELO], "velocidade": 53, "forca": 127, "rabiola": 0},
	{"nome": "Murcha", "m": [60, 46, 30, 18, 24, 18], "padrao": "raios",
		"cores": [BRANCO, ROSA, AZUL, BRANCO], "fitas": [BRANCO, ROSA], "velocidade": 52, "forca": 120, "rabiola": 5},
	{"nome": "Patang", "m": [55, 62, 62, 24, 0, 31], "padrao": "x",
		"cores": [Color(0.6, 0.88, 0.95), VERMELHO, BRANCO, Color(0.6, 0.88, 0.95)], "fitas": [Color(0.6, 0.88, 0.95), VERMELHO], "velocidade": 42, "forca": 130, "rabiola": 0},
	{"nome": "Pião Treme", "m": [60, 54, 20, 20, 20, 20], "padrao": "olho",
		"cores": [VERMELHO, PRETO, BRANCO, VERMELHO], "fitas": [VERMELHO, PRETO], "velocidade": 52, "forca": 156, "rabiola": 0},
	{"nome": "Morcego", "m": [55, 60, 50, 14, 18, 23], "padrao": "olhos",
		"cores": [PRETO, BRANCO, PRETO, PRETO], "fitas": [PRETO, BRANCO], "velocidade": 57, "forca": 146, "rabiola": 0},
	{"nome": "Pipa de Praia", "m": [45, 50, 46, 15, 15, 15], "padrao": "olhos",
		"cores": [VERDE, PRETO, BRANCO, VERDE], "fitas": [VERDE, PRETO], "velocidade": 28, "forca": 35, "rabiola": 0},
	{"nome": "Jangada", "m": [60, 56, 56, 30, 0, 30], "padrao": "raios",
		"cores": [Color(1.0, 0.7, 0.85), VERDE, ROSA, Color(1.0, 0.7, 0.85)], "fitas": [Color(1.0, 0.7, 0.85), VERDE], "velocidade": 41, "forca": 143, "rabiola": 0},
	{"nome": "Sputnik", "m": [60, 58, 52, 20, 25, 15], "padrao": "gt",
		"cores": [VERMELHO, AMARELO, Color(1.0, 0.5, 0.08), VERMELHO], "fitas": [VERMELHO, AMARELO], "velocidade": 57, "forca": 120, "rabiola": 0},
	{"nome": "Tukkal", "m": [60, 64, 40, 22, 18, 20], "padrao": "listras_v",
		"cores": [Color(0.08, 0.15, 0.55), BRANCO, PRETO, Color(0.08, 0.15, 0.55)], "fitas": [Color(0.08, 0.15, 0.55), BRANCO], "velocidade": 57, "forca": 153, "rabiola": 0},
	{"nome": "Peixinho", "m": [55, 44, 44, 27, 0, 28], "padrao": "olho",
		"cores": [Color(1.0, 0.55, 0.45), PRETO, Color(1.0, 0.55, 0.45), Color(1.0, 0.55, 0.45)], "fitas": [Color(1.0, 0.55, 0.45), PRETO], "velocidade": 60, "forca": 65, "rabiola": 4},
	{"nome": "GT 70", "m": [70, 53, 35, 28.3, 21.8, 19.9], "padrao": "gt",
		"cores": [VERMELHO, AMARELO, PRETO, BRANCO], "fitas": [VERMELHO, AMARELO], "velocidade": 68, "forca": 42, "rabiola": 4},
	{"nome": "Cacadeira", "m": [60, 48, 46, 17, 24, 19], "padrao": "diagonal",
		"cores": [VERMELHO, AMARELO, VERMELHO, BRANCO], "fitas": [VERMELHO, AMARELO], "velocidade": 52, "forca": 88, "rabiola": 5},
	{"nome": "Curvo", "m": [60, 50, 42, 20, 20, 20], "padrao": "cruz",
		"cores": [PRETO, Color(1.0, 0.5, 0.08), PRETO, BRANCO], "fitas": [PRETO, Color(1.0, 0.5, 0.08)], "velocidade": 47, "forca": 81, "rabiola": 4},
	{"nome": "El Tiro", "m": [55, 48, 8, 12, 20, 23], "padrao": "borda",
		"cores": [PRETO, AMARELO, PRETO, BRANCO], "fitas": [PRETO, AMARELO], "velocidade": 61, "forca": 39, "rabiola": 5},
	{"nome": "Raia", "m": [65, 50, 50, 25, 0, 40], "padrao": "estrela",
		"cores": [AMARELO, Color(0.08, 0.15, 0.55), AMARELO, AMARELO], "fitas": [AMARELO, Color(0.08, 0.15, 0.55)], "velocidade": 41, "forca": 35, "rabiola": 0},
	{"nome": "Bate Palma", "m": [60, 58, 58, 28, 0, 32], "padrao": "borda",
		"cores": [Color(1.0, 0.7, 0.85), ROSA, Color(1.0, 0.7, 0.85), Color(1.0, 0.7, 0.85)], "fitas": [Color(1.0, 0.7, 0.85), ROSA], "velocidade": 47, "forca": 32, "rabiola": 0},
	{"nome": "Naja", "m": [60, 54, 46, 15, 25, 20], "padrao": "v",
		"cores": [PRETO, Color(1.0, 0.5, 0.08), AMARELO, BRANCO], "fitas": [PRETO, Color(1.0, 0.5, 0.08)], "velocidade": 53, "forca": 136, "rabiola": 7},
	{"nome": "Britt 90", "m": [90, 69, 66, 22, 32, 36], "padrao": "v",
		"cores": [PRETO, ROXO, VERDE, AZUL], "fitas": [PRETO, ROXO], "velocidade": 49, "forca": 136, "rabiola": 7},
	{"nome": "Papagaio", "m": [60, 56, 56, 28, 0, 32], "padrao": "raios",
		"cores": [PRETO, Color(1.0, 0.5, 0.08), AZUL, PRETO], "fitas": [PRETO, Color(1.0, 0.5, 0.08)], "velocidade": 50, "forca": 153, "rabiola": 9},
	{"nome": "Raquete", "m": [70, 40, 10, 8, 22, 40], "padrao": "cruz",
		"cores": [BRANCO, VERDE, ROSA, BRANCO], "fitas": [BRANCO, VERDE], "velocidade": 41, "forca": 81, "rabiola": 3},
	{"nome": "Pião Raia", "m": [60, 56, 24, 25, 15, 20], "padrao": "v",
		"cores": [AMARELO, Color(0.08, 0.15, 0.55), AMARELO, AMARELO], "fitas": [AMARELO, Color(0.08, 0.15, 0.55)], "velocidade": 47, "forca": 133, "rabiola": 0},
	{"nome": "Baruel", "m": [60, 56, 56, 12, 30, 18], "padrao": "borda",
		"cores": [AMARELO, Color(0.85, 0.7, 0.05), AMARELO, BRANCO], "fitas": [AMARELO, PRETO], "velocidade": 50, "forca": 133, "rabiola": 10},
	{"nome": "Caixão", "m": [60, 58, 50, 12, 22, 26], "padrao": "metades",
		"cores": [PRETO, Color(0.3, 0.3, 0.32), PRETO, BRANCO], "fitas": [PRETO, Color(0.3, 0.3, 0.32)], "velocidade": 38, "forca": 97, "rabiola": 0},
	{"nome": "Latão 70", "m": [70, 58, 58, 15.8, 39.7, 14.5], "padrao": "grade_larga",
		"cores": [PRETO, BRANCO, PRETO, BRANCO], "fitas": [PRETO, BRANCO], "velocidade": 50, "forca": 153, "rabiola": 2},
	{"nome": "Carrapeta 90", "m": [90, 66, 57, 34.8, 21.1, 34.1], "padrao": "v",
		"cores": [PRETO, BRANCO, VERDE, AZUL], "fitas": [PRETO, BRANCO], "velocidade": 57, "forca": 123, "rabiola": 7},
	{"nome": "Come Rato 50", "m": [50, 39, 36, 15.5, 16, 18.5], "padrao": "olho",
		"cores": [PRETO, AMARELO, VERMELHO, BRANCO], "fitas": [PRETO, AMARELO], "velocidade": 71, "forca": 48, "rabiola": 4},
	{"nome": "Pizza 55", "m": [55, 42, 31, 16, 17, 22], "padrao": "triangulos",
		"cores": [Color(1.0, 0.5, 0.08), BRANCO, AZUL, BRANCO], "fitas": [Color(1.0, 0.5, 0.08), BRANCO], "velocidade": 68, "forca": 48, "rabiola": 3},
	{"nome": "Lápis 62", "m": [62, 46, 44, 15, 21, 26], "padrao": "listras_v",
		"cores": [Color(0.9, 0.05, 0.85), PRETO, BRANCO, BRANCO], "fitas": [Color(0.9, 0.05, 0.85), PRETO], "velocidade": 60, "forca": 104, "rabiola": 10},
	{"nome": "Charuto 70", "m": [70, 49, 43, 20, 26, 24], "padrao": "metades",
		"cores": [Color(0.5, 0.05, 0.15), AMARELO, PRETO, BRANCO], "fitas": [Color(0.5, 0.05, 0.15), AMARELO], "velocidade": 55, "forca": 107, "rabiola": 5},
	{"nome": "Bicão Carioca", "m": [70, 48, 45, 26.5, 19.5, 24], "padrao": "cruz",
		"cores": [Color(0.05, 0.5, 0.2), AMARELO, AZUL, AMARELO], "fitas": [Color(0.05, 0.5, 0.2), AMARELO], "velocidade": 50, "forca": 120, "rabiola": 6},
	{"nome": "Francesinha 45", "m": [45, 34, 29, 14.3, 14.5, 16.2], "padrao": "v_listras",
		"cores": [BRANCO, PRETO, VERMELHO, BRANCO], "fitas": [BRANCO, PRETO], "velocidade": 58, "forca": 55, "rabiola": 5},
	{"nome": "Vanda 70", "m": [70, 50, 46, 24.8, 20.4, 24.8], "padrao": "grade",
		"cores": [Color(0.2, 0.85, 1.0), PRETO, PRETO, BRANCO], "fitas": [Color(0.2, 0.85, 1.0), PRETO], "velocidade": 46, "forca": 110, "rabiola": 4},
	{"nome": "Gigante 70", "m": [70, 60, 56, 15, 25, 30], "padrao": "triangulos",
		"cores": [PRETO, Color(0.8, 0.1, 0.5), AZUL, BRANCO], "fitas": [PRETO, Color(0.8, 0.1, 0.5)], "velocidade": 46, "forca": 136, "rabiola": 10},
	{"nome": "Palito 70", "m": [70, 44, 44, 16, 29, 25], "padrao": "colunas",
		"cores": [PRETO, ROSA, PRETO, BRANCO], "fitas": [PRETO, ROSA], "velocidade": 58, "forca": 58, "rabiola": 5},
	{"nome": "Bicuda 55", "m": [55, 38, 36, 20, 16, 19], "padrao": "blocos",
		"cores": [BRANCO, Color(0.05, 0.5, 0.2), VERDE, BRANCO], "fitas": [BRANCO, Color(0.05, 0.5, 0.2)], "velocidade": 53, "forca": 70, "rabiola": 4},
	{"nome": "Veloster", "m": [55, 56, 56, 22, 0, 33], "padrao": "olhos",
		"cores": [Color(0.3, 1.0, 0.5), AMARELO, PRETO, Color(0.3, 1.0, 0.5)], "fitas": [Color(0.3, 1.0, 0.5), AMARELO], "velocidade": 63, "forca": 97, "rabiola": 0},
	{"nome": "Raião", "m": [70, 66, 66, 35, 0, 35], "padrao": "x",
		"cores": [Color(0.08, 0.15, 0.55), BRANCO, VERMELHO, Color(0.08, 0.15, 0.55)], "fitas": [Color(0.08, 0.15, 0.55), BRANCO], "velocidade": 47, "forca": 133, "rabiola": 5},
	{"nome": "Yonghwe", "m": [60, 58, 58, 25, 0, 35], "padrao": "v",
		"cores": [BRANCO, VERMELHO, PRETO, BRANCO], "fitas": [BRANCO, VERMELHO], "velocidade": 61, "forca": 55, "rabiola": 0},
	{"nome": "Helicóptero", "m": [60, 58, 58, 30, 0, 30], "padrao": "x_largo",
		"cores": [VERMELHO, Color(0.08, 0.15, 0.55), BRANCO, VERMELHO], "fitas": [VERMELHO, Color(0.08, 0.15, 0.55)], "velocidade": 66, "forca": 104, "rabiola": 0},
	{"nome": "Layang", "m": [60, 60, 60, 30, 0, 30], "padrao": "raios",
		"cores": [Color(0.6, 0.88, 0.95), Color(0.08, 0.15, 0.55), Color(1.0, 0.5, 0.08), Color(0.6, 0.88, 0.95)], "fitas": [Color(0.6, 0.88, 0.95), Color(0.08, 0.15, 0.55)], "velocidade": 61, "forca": 39, "rabiola": 0},
	{"nome": "Flechão", "m": [70, 60, 60, 32, 0, 38], "padrao": "quadrantes",
		"cores": [VERMELHO, AZUL, AMARELO, VERDE], "fitas": [VERMELHO, AZUL], "velocidade": 58, "forca": 136, "rabiola": 5},
	{"nome": "Xadrez", "m": [60, 58, 58, 28, 0, 32], "padrao": "xadrez",
		"cores": [BRANCO, PRETO, BRANCO, BRANCO], "fitas": [BRANCO, PRETO], "velocidade": 55, "forca": 97, "rabiola": 0},
	{"nome": "Asa Delta", "m": [50, 70, 10, 10, 25, 15], "padrao": "listras_v",
		"cores": [AZUL, AMARELO, VERMELHO, AZUL], "fitas": [AZUL, AMARELO], "velocidade": 44, "forca": 60, "rabiola": 0},
	{"nome": "Raia Folhão", "m": [60, 58, 58, 28, 0, 32], "padrao": "olho",
		"cores": [Color(0.9, 0.05, 0.85), PRETO, Color(0.9, 0.05, 0.85), Color(0.9, 0.05, 0.85)], "fitas": [Color(0.9, 0.05, 0.85), PRETO], "velocidade": 60, "forca": 120, "rabiola": 0},
]


## Cor de um ponto da vela. X: -1 (esquerda) a 1 (direita), relativo à meia
## largura maior; T: 0 no bico a 1 na ponta de baixo; tb e tc: onde ficam a
## vareta de cima e a de baixo (em T). O bico (acima da vareta de cima) tem a
## cor de topo.
## O bico (acima da vareta de cima) sem papel: pipas de caixa (com as duas
## varetas separadas). Raias e losangos (caixa 0) têm papel no corpo todo.
static func aberto(estilo: Dictionary) -> bool:
	var m: Array = estilo["m"]
	return float(m[4]) > 0.0


static func cor(estilo: Dictionary, x: float, t: float, tb: float, tc: float) -> Color:
	var c: Array = estilo["cores"]
	var a: Color = c[0]
	var b: Color = c[1]
	var k: Color = c[2]
	var topo: Color = c[3]
	if t < tb and aberto(estilo):
		return topo
	if not aberto(estilo):
		tb = 0.0
	var f := (t - tb) / maxf(1.0 - tb, 0.01)      # 0 na vareta de cima, 1 embaixo
	var ax := absf(x)
	var yc := (f - 0.5) * 2.0                      # -1 em cima a 1 embaixo
	match String(estilo["padrao"]):
		"estrela":
			var d4 := sqrt(absf(x)) + sqrt(absf(yc))
			if d4 < 0.55:
				return k
			return b if d4 < 0.95 else a
		"olhos":
			for lado in [-0.38, 0.38]:
				var e := Vector2((x - lado) / 0.26, (yc + 0.15) / 0.36).length()
				if e < 0.5:
					return k
				if e < 1.0:
					return b
			return a
		"xadrez":
			var q := floori((x + 1.0) * 4.0) + floori(f * 8.0)
			return a if q % 2 == 0 else b
		"raios":
			var ang := atan2(yc, x)
			var raio := Vector2(x, yc).length()
			if raio < 0.16:
				return k
			return b if fposmod(ang * 8.0 / PI, 2.0) < 1.0 else a
		"diagonal":
			return a if x + yc * 0.6 < 0.0 else b
		"coracao":
			var hx := absf(x) / 0.55
			var hy := -(yc - 0.1) / 0.55
			var heart := pow(hx * hx + hy * hy - 1.0, 3.0) - hx * hx * hy * hy * hy
			if heart < 0.0:
				return b
			return a
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


## Linhas do jogo (D-064): todas fictícias, sem nada de cerol ou linha chilena
## (regra do projeto). Grossura (4, 10, 24) e cor; resistência, peso e força
## no relô mudam o jogo (FreeMode.apply_line).
const LINHAS := [
	{"nome": "Linha 4 Branca", "cor": Color(0.97, 0.97, 0.95), "resistencia": 0.85, "peso": 0.75, "grossura": 0.75},
	{"nome": "Linha 4 Preta", "cor": Color(0.1, 0.1, 0.1), "resistencia": 0.85, "peso": 0.75, "grossura": 0.75},
	{"nome": "Linha 10 Amarela", "cor": Color(1.0, 0.86, 0.1), "resistencia": 1.0, "peso": 1.0, "grossura": 1.0},
	{"nome": "Linha 10 Verde", "cor": Color(0.3, 1.0, 0.25), "resistencia": 1.0, "peso": 1.0, "grossura": 1.0},
	{"nome": "Linha 10 Rosa", "cor": Color(1.0, 0.25, 0.6), "resistencia": 1.0, "peso": 1.0, "grossura": 1.0},
	{"nome": "Linha 10 Laranja", "cor": Color(1.0, 0.55, 0.1), "resistencia": 1.0, "peso": 1.0, "grossura": 1.0},
	{"nome": "Linha 10 Azul", "cor": Color(0.2, 0.5, 1.0), "resistencia": 1.0, "peso": 1.0, "grossura": 1.0},
	{"nome": "Carretilha Neon", "cor": Color(0.6, 1.0, 0.1), "resistencia": 1.1, "peso": 1.1, "grossura": 1.1},
	{"nome": "Linha 24 Vermelha", "cor": Color(0.9, 0.1, 0.1), "resistencia": 1.3, "peso": 1.5, "grossura": 1.4},
	{"nome": "Linha 24 Roxa", "cor": Color(0.55, 0.2, 0.9), "resistencia": 1.3, "peso": 1.5, "grossura": 1.4},
]
