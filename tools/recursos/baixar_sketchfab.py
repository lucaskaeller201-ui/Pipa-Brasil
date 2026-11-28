#!/usr/bin/env python3
"""Baixa do Sketchfab os modelos aprovados (D-098) — só roda no GitHub
Actions e só se o segredo SKETCHFAB_API_TOKEN existir.

Segurança: a chave é lida da variável de ambiente e usada só no cabeçalho
da requisição; nunca é impressa, salva em arquivo ou passada adiante. Os
links de download devolvidos pelo Sketchfab são temporários e também não
são impressos. Só modelos CC BY/CC0 da lista abaixo, conferidos de novo.
"""
import io
import json
import os
import urllib.request
import zipfile

TOKEN = os.environ.get("SKETCHFAB_API_TOKEN", "")
MODELOS = {
	"maos_a": "cbefd9fe847541dd8192e3281adf1bce",          # Hands model rigged — nikita887H — CC BY
	"casa_favela_1": "b9797c38e4e645b39f0cda8c05bebd5f",   # Favela brasileira — iagoDev — CC BY
	"casa_favela_2": "c87942d7d3ba43648920c7f7cd451afc",   # Favela brasileira 2 — iagoDev — CC BY
	"casas_antigas_1": "be4a54f622a14f8b8bb8df70046f1dc1", # Pack of old houses — iagoDev — CC BY
	"casas_antigas_2": "789cd0b9c4644a01adc3ace61573baf1", # Pack of old houses 2 — iagoDev — CC BY
	"favela_modular": "e2b6f532e1fe4f7280890971d78183f4",  # Modular Slums — alexferrart3D — CC BY
	"coqueiro_1": "dc894acc16544bc69630e9a5232cf74c",      # Realistic Palm Tree Low Poly — hamzaunity3d — CC BY
	"coqueiro_2": "ced3b31f14f940d0b7480a83e6f8c9c0",      # Palm Tree Realistic — 00amza — CC BY
}
LICENCAS_OK = ("CC Attribution", "CC0 Public Domain")


def api(url, autenticar=False):
	cab = {"User-Agent": "pipa-brasil-ci"}
	if autenticar:
		cab["Authorization"] = "Token " + TOKEN
	with urllib.request.urlopen(urllib.request.Request(url, headers=cab), timeout=120) as r:
		return r.read()


if not TOKEN:
	print("Sem chave: nada a fazer.")
	raise SystemExit(0)
creditos = []
for nome, uid in MODELOS.items():
	info = json.loads(api("https://api.sketchfab.com/v3/models/" + uid))
	lic = (info.get("license") or {}).get("label", "")
	if lic not in LICENCAS_OK:
		print(nome, "pulado: licença", lic)
		continue
	try:
		links = json.loads(api("https://api.sketchfab.com/v3/models/%s/download" % uid, autenticar=True))
		dados = api(links["gltf"]["url"])
		pasta = os.path.join("trabalho", "sketchfab", nome)
		zipfile.ZipFile(io.BytesIO(dados)).extractall(pasta)
		creditos.append("| %s | %s | %s | %s |" % (info["name"], info["user"]["username"], lic, info["viewerUrl"]))
		print(nome, "baixado (%d KB)" % (len(dados) // 1024))
	except Exception as e:
		print(nome, "erro ao baixar:", type(e).__name__)
open(os.path.join("trabalho", "sketchfab_creditos.md"), "w").write("| Modelo | Autor | Licença | Link |\n|---|---|---|---|\n" + "\n".join(creditos) + "\n")
