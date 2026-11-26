#!/usr/bin/env python3
"""Baixa céus de foto (HDRI CC0, Poly Haven) para cada hora do dia (D-075).

Roda no GitHub Actions. Para cada hora tenta os nomes da lista; se nenhum
existir, escolhe pelo catálogo (categoria "pure skies" + a da hora). Baixa
o HDR 2k, acha o sol na foto (o ponto mais forte) e mede a cor do horizonte
e o brilho do céu, e grava tudo em assets/ceus/ceus.json — o jogo alinha a
luz do sol com o sol da foto e acerta a exposição.
"""
import json
import math
import os
import urllib.request

import cv2  # pip install opencv-python-headless (no workflow)
import numpy as np

API = "https://api.polyhaven.com"
PASTA = os.path.join(os.path.dirname(__file__), "..", "assets", "ceus")
UA = {"User-Agent": "pipa-brasil-ci (jogo gratuito; ceus CC0)"}

HORAS = {
	"manha": (["kloofendal_48d_partly_cloudy_puresky", "qwantani_morning_puresky", "kloofendal_overcast_puresky"], "morning-afternoon"),
	# escolhidos olhando a folha de prévias (tools/previa_ceus.py): nuvens de
	# verdade ao meio-dia e um pôr do sol dourado com nuvens
	"meio_dia": (["sunflowers_puresky", "kloppenheim_05_puresky", "qwantani_noon_puresky"], "midday"),
	"por_do_sol": (["kloppenheim_06_puresky", "wasteland_clouds_puresky", "qwantani_sunset_puresky"], "sunrise-sunset"),
}


def j(u):
	with urllib.request.urlopen(urllib.request.Request(u, headers=UA), timeout=60) as r:
		return json.load(r)


def baixar(url, destino):
	with urllib.request.urlopen(urllib.request.Request(url, headers=UA), timeout=300) as r:
		dados = r.read()
	with open(destino, "wb") as f:
		f.write(dados)
	return len(dados)


def medir(caminho):
	img = cv2.imread(caminho, cv2.IMREAD_ANYDEPTH | cv2.IMREAD_COLOR)[:, :, ::-1].astype(np.float32)  # RGB linear
	h, w, _ = img.shape
	lum = img @ np.array([0.2126, 0.7152, 0.0722], np.float32)
	borr = cv2.GaussianBlur(lum, (0, 0), 3)
	y, x = np.unravel_index(np.argmax(borr[: h // 2]), borr[: h // 2].shape)
	# equiretangular: u=0..1 → azimute; v=0 topo, 0.5 horizonte
	azim = (x + 0.5) / w * 360.0
	elev = 90.0 - (y + 0.5) / h * 180.0
	# brilho do céu sem o sol (mediana do hemisfério de cima) e cor do horizonte
	ceu = img[: int(h * 0.45)].reshape(-1, 3)
	mediana = float(np.median(ceu @ np.array([0.2126, 0.7152, 0.0722], np.float32)))
	faixa = img[int(h * 0.47): int(h * 0.5)].reshape(-1, 3)
	hor = np.median(faixa, axis=0)
	hor = hor / max(hor.max(), 1e-6)
	topo = np.median(img[: int(h * 0.12)].reshape(-1, 3), axis=0)
	topo = topo / max(topo.max(), 1e-6)
	return {"sol_azimute": float(azim), "sol_elevacao": float(elev), "mediana_ceu": mediana,
		"horizonte": [float(c) for c in hor], "topo": [float(c) for c in topo]}


def main():
	os.makedirs(PASTA, exist_ok=True)
	catalogo = j(f"{API}/assets?t=hdris")
	saida = {}
	creditos = ["# Céus (D-075)", "", "Fotos de céu (HDRI) do Poly Haven (https://polyhaven.com), licença CC0.", "",
		"| Hora | Céu | Autor(es) |", "| --- | --- | --- |"]
	for hora, (nomes, categoria) in HORAS.items():
		extra = sorted(k for k, v in catalogo.items()
			if "pure skies" in v.get("categories", []) and categoria in v.get("categories", []))
		escolhido = None
		for nome in nomes + extra:
			if nome in catalogo:
				escolhido = nome
				break
		if escolhido is None:
			print(f"FALHOU {hora}")
			continue
		arq = j(f"{API}/files/{escolhido}")
		url = arq["hdri"]["2k"]["hdr"]["url"]
		destino = os.path.join(PASTA, f"{hora}.hdr")
		tam = baixar(url, destino)
		m = medir(destino)
		m["nome"] = escolhido
		saida[hora] = m
		autores = ", ".join(j(f"{API}/info/{escolhido}").get("authors", {}).keys())
		creditos.append(f"| {hora} | [{escolhido}](https://polyhaven.com/a/{escolhido}) | {autores} |")
		print(f"{hora}: {escolhido} ({tam // 1024} KB) sol az {m['sol_azimute']:.0f}° el {m['sol_elevacao']:.0f}°, céu {m['mediana_ceu']:.2f}")
	with open(os.path.join(PASTA, "ceus.json"), "w") as f:
		json.dump(saida, f, indent=1)
	with open(os.path.join(PASTA, "CREDITOS.md"), "w") as f:
		f.write("\n".join(creditos) + "\n")


if __name__ == "__main__":
	main()
