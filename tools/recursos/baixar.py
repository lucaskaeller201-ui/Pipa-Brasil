#!/usr/bin/env python3
"""Baixa os recursos gratuitos aprovados (D-098). Roda no GitHub Actions.

- Personagens Microsoft Rocketbox (licença MIT), só os escolhidos.
- Árvores e arbustos do Poly Haven (CC0), glTF 1k.
- Coqueiros CC0 do OpenGameArt (Yughues).
Tudo vai para trabalho/ (não entra no repositório); o converter.py (Blender)
prepara as versões leves que entram no jogo.
"""
import json
import os
import shutil
import subprocess
import urllib.request

UA = {"User-Agent": "pipa-brasil-ci (recursos gratuitos)"}
T = "trabalho"
os.makedirs(T, exist_ok=True)

PERSONAGENS = ["Male_Adult_01", "Male_Adult_17", "Male_Adult_04", "Male_Adult_16", "Male_Adult_09", "Male_Adult_11", "Male_Adult_20"]
ARVORES = ["island_tree_01", "tree_small_02", "jacaranda_tree"]


def pegar(url, destino):
	os.makedirs(os.path.dirname(destino) or ".", exist_ok=True)
	with urllib.request.urlopen(urllib.request.Request(url, headers=UA), timeout=300) as r:
		open(destino, "wb").write(r.read())


# --- Rocketbox (git esparso: só as pastas dos escolhidos) ---
rb = os.path.join(T, "rocketbox")
if not os.path.exists(rb):
	subprocess.run(["git", "clone", "-q", "--depth", "1", "--filter=blob:none", "--sparse", "https://github.com/microsoft/Microsoft-Rocketbox", rb], check=True)
	subprocess.run(["git", "-C", rb, "sparse-checkout", "set"] + ["Assets/Avatars/Adults/" + p for p in PERSONAGENS] + ["LICENSE"], check=True)
for p in PERSONAGENS:
	pasta = os.path.join(rb, "Assets/Avatars/Adults", p)
	print(p, sorted(os.listdir(pasta)), sorted(os.listdir(os.path.join(pasta, "Textures"))))

# --- Poly Haven ---
for nome in ARVORES:
	arq = json.load(urllib.request.urlopen(urllib.request.Request("https://api.polyhaven.com/files/" + nome, headers=UA), timeout=60))
	g = arq["gltf"]["1k"]["gltf"]
	pasta = os.path.join(T, "polyhaven", nome)
	pegar(g["url"], os.path.join(pasta, nome + ".gltf"))
	for rel, inc in g.get("include", {}).items():
		pegar(inc["url"], os.path.join(pasta, rel))
	print("poly haven", nome, "ok")

# --- Coqueiros CC0 (Yughues, OpenGameArt) ---
try:
	pegar("https://opengameart.org/sites/default/files/PACK%20V3.7z", os.path.join(T, "coqueiros.7z"))
	subprocess.run(["7z", "x", "-y", "-o" + os.path.join(T, "coqueiros"), os.path.join(T, "coqueiros.7z")], check=True, stdout=subprocess.DEVNULL)
	for raiz, _, arqs in os.walk(os.path.join(T, "coqueiros")):
		for a in arqs:
			print("coqueiro:", os.path.join(raiz, a))
	print(open(os.path.join(T, "coqueiros", "readme.txt"), errors="replace").read()[:1500])
except Exception as e:
	print("coqueiros: erro", e)
