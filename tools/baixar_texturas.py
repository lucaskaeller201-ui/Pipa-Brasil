#!/usr/bin/env python3
"""Baixa texturas fotográficas CC0 do Poly Haven (D-067).

Roda no GitHub Actions (workflow texturas.yml), que tem internet. Para cada
"vaga" tenta os nomes da lista; se nenhum existir, procura no catálogo um
nome com a palavra-chave. Salva cor e relevo (normal) em 1k JPG em
assets/texturas/<vaga>_cor.jpg e <vaga>_normal.jpg e escreve CREDITOS.md.
Licença CC0: uso livre, sem custo (regra de custo zero do projeto).
"""
import json
import os
import sys
import urllib.request

API = "https://api.polyhaven.com"
PASTA = os.path.join(os.path.dirname(__file__), "..", "assets", "texturas")
UA = {"User-Agent": "pipa-brasil-ci (jogo gratuito; texturas CC0)"}

VAGAS = {
	"asfalto": (["asphalt_02", "asphalt_01", "asphalt_track", "asphalt_pit_lane"], "asphalt"),
	"concreto": (["concrete_floor_02", "concrete_floor_worn_001", "concrete_pavement", "concrete_floor_01"], "concrete_floor"),
	"terra": (["brown_mud_leaves_01", "dirt", "dry_ground_01", "brown_mud"], "dirt"),
	"grama": (["aerial_grass_rock", "grass_path_2", "forest_ground_04", "leafy_grass"], "grass"),
	"areia": (["coast_sand_01", "coast_sand_02", "sand_01", "aerial_beach_01"], "sand"),
	"reboco": (["plastered_wall", "concrete_wall_008", "painted_plaster_wall"], "plaster"),
	"tijolo": (["red_brick_03", "red_brick", "brick_wall_02", "red_bricks_04"], "brick"),
	"telha": (["roof_tiles_14", "clay_roof_tiles", "clay_roof_tiles_02", "roof_07"], "roof"),
	"casca": (["bark_willow", "pine_bark", "bark_brown_02", "tree_bark_03"], "bark"),
	# D-080: piso de cerâmica das lajes e tecido da roupa do boneco
	"piso": (["floor_tiles_06", "floor_tiles_08", "terracotta_tiles", "red_floor_tiles", "floor_tiles_02"], "tiles"),
	"tecido": (["cotton_jersey", "fabric_pattern_05", "denim_fabric", "fabric_pattern_07", "jersey_fabric"], "fabric"),
}


def pegar_json(url):
	with urllib.request.urlopen(urllib.request.Request(url, headers=UA), timeout=60) as r:
		return json.load(r)


def baixar(url, destino):
	with urllib.request.urlopen(urllib.request.Request(url, headers=UA), timeout=120) as r:
		dados = r.read()
	with open(destino, "wb") as f:
		f.write(dados)
	return len(dados)


def mapa(arquivos, nomes):
	for chave in arquivos:
		if chave.lower() in nomes:
			try:
				return arquivos[chave]["1k"]["jpg"]["url"]
			except (KeyError, TypeError):
				pass
	return None


def main():
	os.makedirs(PASTA, exist_ok=True)
	catalogo = None
	creditos = ["# Texturas (D-067)", "", "Fotos de materiais do Poly Haven (https://polyhaven.com), licença CC0",
		"(domínio público: uso livre e gratuito, sem exigência de crédito — damos crédito mesmo assim).", "",
		"| Vaga | Textura | Autor(es) |", "| --- | --- | --- |"]
	falhas = 0
	for vaga, (nomes, palavra) in VAGAS.items():
		candidatos = list(nomes)
		escolhido = None
		arquivos = None
		while candidatos and escolhido is None:
			nome = candidatos.pop(0)
			try:
				arquivos = pegar_json(f"{API}/files/{nome}")
				if mapa(arquivos, ("diffuse", "diff")):
					escolhido = nome
			except Exception as e:  # noqa: BLE001
				print(f"  {vaga}: {nome} não serviu ({e})")
			if escolhido is None and not candidatos:
				if catalogo is None:
					catalogo = pegar_json(f"{API}/assets?t=textures")
				extra = sorted(k for k in catalogo if palavra in k)
				candidatos = [k for k in extra if k not in nomes][:5]
				nomes = nomes + candidatos
				if not candidatos:
					break
		if escolhido is None:
			print(f"FALHOU: nenhuma textura para {vaga}")
			falhas += 1
			continue
		cor = mapa(arquivos, ("diffuse", "diff"))
		normal = mapa(arquivos, ("nor_gl",))
		t1 = baixar(cor, os.path.join(PASTA, f"{vaga}_cor.jpg"))
		t2 = baixar(normal, os.path.join(PASTA, f"{vaga}_normal.jpg")) if normal else 0
		try:
			autores = ", ".join(pegar_json(f"{API}/info/{escolhido}").get("authors", {}).keys())
		except Exception:  # noqa: BLE001
			autores = "?"
		creditos.append(f"| {vaga} | [{escolhido}](https://polyhaven.com/a/{escolhido}) | {autores} |")
		print(f"{vaga}: {escolhido} ({t1 // 1024} KB + {t2 // 1024} KB)")
	with open(os.path.join(PASTA, "CREDITOS.md"), "w") as f:
		f.write("\n".join(creditos) + "\n")
	sys.exit(1 if falhas > 3 else 0)


if __name__ == "__main__":
	main()
