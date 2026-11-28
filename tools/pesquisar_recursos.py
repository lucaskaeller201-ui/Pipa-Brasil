#!/usr/bin/env python3
"""Pesquisa de recursos 3D gratuitos (D-097). Roda no GitHub Actions.

Busca no Sketchfab (só CC0 e baixáveis; a busca é pública, sem login), no
Poly Haven (API pública) e confere arquivos CC0 do Quaternius no OpenGameArt.
Salva uma tabela (resultado.md) e as miniaturas, para avaliar antes de usar.
Nada é colocado no jogo por este script.
"""
import json
import os
import urllib.parse
import urllib.request

SAIDA = "pesquisa"
UA = {"User-Agent": "pipa-brasil-ci (pesquisa de modelos CC0)"}
os.makedirs(os.path.join(SAIDA, "miniaturas"), exist_ok=True)

BUSCAS = {
	"maos": ["realistic hand rigged", "first person arms rigged", "hands fps"],
	"personagens": ["realistic man rigged", "young man casual rigged", "brazilian boy", "character male t-shirt shorts rigged"],
	"casas": ["favela", "brazilian house", "slum house", "low poly house realistic", "rooftop water tank"],
	"vegetacao": ["palm tree", "tropical tree", "banana tree", "tree low poly realistic", "bush"],
}


def pegar(url):
	with urllib.request.urlopen(urllib.request.Request(url, headers=UA), timeout=60) as r:
		return r.read()


def miniatura(nome, url):
	try:
		dados = pegar(url)
		caminho = os.path.join(SAIDA, "miniaturas", nome + ".jpg")
		with open(caminho, "wb") as f:
			f.write(dados)
		return caminho
	except Exception as e:
		return "erro: %s" % e


linhas = ["# Pesquisa de recursos (D-097)", ""]
dados_json = {}

# --- Sketchfab: busca pública, só CC0 e baixáveis ---
for grupo, termos in BUSCAS.items():
	linhas += ["## Sketchfab — %s" % grupo, "", "| # | Modelo | Autor | Faces | Animações | Licença | Link |", "|---|---|---|---|---|---|---|"]
	vistos = set()
	n = 0
	for termo in termos:
		q = urllib.parse.urlencode({"type": "models", "q": termo, "license": "cc0", "downloadable": "true", "sort_by": "-likeCount", "count": 12})
		try:
			res = json.loads(pegar("https://api.sketchfab.com/v3/search?" + q))
		except Exception as e:
			linhas.append("| erro | %s | %s |  |  |  |  |" % (termo, e))
			continue
		for m in res.get("results", []):
			if m["uid"] in vistos:
				continue
			vistos.add(m["uid"])
			n += 1
			lic = (m.get("license") or {}).get("label", "?")
			thumbs = sorted((m.get("thumbnails") or {}).get("images", []), key=lambda t: abs(t.get("width", 0) - 640))
			nome_arq = "%s_%02d_%s" % (grupo, n, m["uid"][:8])
			if thumbs:
				miniatura(nome_arq, thumbs[0]["url"])
			linhas.append("| %s | %s | %s | %s | %s | %s | %s |" % (nome_arq, m["name"].replace("|", "/"), m["user"]["username"], m.get("faceCount"), m.get("animationCount"), lic, m["viewerUrl"]))
			dados_json.setdefault(grupo, []).append({"arq": nome_arq, "uid": m["uid"], "nome": m["name"], "faces": m.get("faceCount"), "animacoes": m.get("animationCount"), "licenca": lic, "url": m["viewerUrl"], "termo": termo})
			if n >= 24:
				break
		if n >= 24:
			break
	linhas.append("")

# --- Poly Haven: modelos de natureza e construção ---
try:
	todos = json.loads(pegar("https://api.polyhaven.com/assets?t=models"))
	linhas += ["## Poly Haven — modelos (natureza, construção)", "", "| id | nome | categorias |", "|---|---|---|"]
	for k, v in sorted(todos.items()):
		cats = v.get("categories", [])
		if any(c in cats for c in ["nature", "plants", "trees", "building", "architecture", "outdoor", "urban", "street"]):
			linhas.append("| %s | %s | %s |" % (k, v.get("name"), ", ".join(cats)))
			if v.get("thumbnail_url"):
				miniatura("polyhaven_" + k, v["thumbnail_url"])
	linhas.append("")
except Exception as e:
	linhas.append("Poly Haven: erro %s" % e)

# --- OpenGameArt: arquivos CC0 do Quaternius (animações) ---
for pagina in ["https://opengameart.org/content/universal-animation-library", "https://opengameart.org/content/universal-animation-library-2"]:
	try:
		html = pegar(pagina).decode("utf-8", "ignore")
		arqs = [p.split('"')[0] for p in html.split('href="')[1:] if ".zip" in p.split('"')[0]]
		linhas.append("OpenGameArt %s: %s" % (pagina, ", ".join(sorted(set(arqs)))))
	except Exception as e:
		linhas.append("OpenGameArt %s: erro %s" % (pagina, e))

with open(os.path.join(SAIDA, "resultado.md"), "w") as f:
	f.write("\n".join(linhas) + "\n")
with open(os.path.join(SAIDA, "resultado.json"), "w") as f:
	json.dump(dados_json, f, indent=1, ensure_ascii=False)
print("\n".join(linhas))
