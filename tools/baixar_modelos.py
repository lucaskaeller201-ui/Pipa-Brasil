#!/usr/bin/env python3
"""Baixa modelos 3D CC0 do Poly Haven em glTF 1k (D-068).

Roda no GitHub Actions (workflow texturas.yml). Escolhidos por serem leves
(poucos milhares de triângulos) e combinarem com uma laje/rua brasileira.
Salva em assets/modelos/<nome>/ com as texturas, e escreve CREDITOS.md.
"""
import json
import os
import urllib.request

API = "https://api.polyhaven.com"
PASTA = os.path.join(os.path.dirname(__file__), "..", "assets", "modelos")
UA = {"User-Agent": "pipa-brasil-ci (jogo gratuito; modelos CC0)"}

MODELOS = [
	"plastic_monobloc_chair_01",  # cadeira de plástico da laje
	"plastic_crate_02",           # engradado
	"Barrel_02",                  # tambor/bombona
	"shrub_03",                   # arbusto
	"fern_02",                    # samambaia
	"potted_plant_04",            # vaso
	"planter_pot_clay",           # vaso de barro
	"rollershutter_door",         # porta de enrolar (comércio)
	"utility_box_01",             # caixa de luz
	"trashbag",                   # saco de lixo
	"street_lamp_02",             # luminária de rua
]


def j(u):
	with urllib.request.urlopen(urllib.request.Request(u, headers=UA), timeout=60) as r:
		return json.load(r)


def baixar(url, destino):
	os.makedirs(os.path.dirname(destino), exist_ok=True)
	with urllib.request.urlopen(urllib.request.Request(url, headers=UA), timeout=180) as r:
		dados = r.read()
	with open(destino, "wb") as f:
		f.write(dados)
	return len(dados)


def main():
	linhas = ["# Modelos 3D (D-068)", "", "Modelos do Poly Haven (https://polyhaven.com), licença CC0 (domínio público).", "",
		"| Modelo | Triângulos | Autor(es) |", "| --- | --- | --- |"]
	for nome in MODELOS:
		try:
			arq = j(f"{API}/files/{nome}")
			g = arq["gltf"]["1k"]["gltf"]
			pasta = os.path.join(PASTA, nome)
			total = baixar(g["url"], os.path.join(pasta, f"{nome}.gltf"))
			for rel, inc in g.get("include", {}).items():
				total += baixar(inc["url"], os.path.join(pasta, rel))
			# Folhas usam recorte (alphaMode MASK), mas o JPG não tem
			# transparência: baixa a cor em PNG e aponta o glTF para ela.
			caminho = os.path.join(pasta, f"{nome}.gltf")
			with open(caminho) as f:
				gltf = json.load(f)
			if any(m.get("alphaMode") == "MASK" for m in gltf.get("materials", [])):
				for chave in arq:
					if chave.lower() in ("diffuse", "diff"):
						png = arq[chave]["1k"]["png"]["url"]
						rel_png = f"textures/{nome}_diff_1k.png"
						total += baixar(png, os.path.join(pasta, rel_png))
						for im in gltf.get("images", []):
							if im.get("uri", "").endswith("_diff_1k.jpg"):
								im["uri"] = rel_png
						with open(caminho, "w") as f:
							json.dump(gltf, f, indent=1)
						os.remove(os.path.join(pasta, f"textures/{nome}_diff_1k.jpg"))
						print(f"  {nome}: folhas com transparência (PNG)")
			info = j(f"{API}/info/{nome}")
			autores = ", ".join(info.get("authors", {}).keys())
			linhas.append(f"| [{nome}](https://polyhaven.com/a/{nome}) | {info.get('polycount', '?')} | {autores} |")
			print(f"{nome}: {total // 1024} KB, arquivos: {list(g.get('include', {}).keys())}")
		except Exception as e:  # noqa: BLE001
			print(f"FALHOU {nome}: {e}")
	with open(os.path.join(PASTA, "CREDITOS.md"), "w") as f:
		f.write("\n".join(linhas) + "\n")


if __name__ == "__main__":
	main()
