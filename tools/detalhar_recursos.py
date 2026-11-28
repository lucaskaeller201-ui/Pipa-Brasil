#!/usr/bin/env python3
"""Detalhes dos modelos escolhidos no Sketchfab (D-098): licença, faces,
tamanho dos arquivos para baixar e miniatura grande. Só leitura pública,
sem chave. Saída em pesquisa/detalhes.md e pesquisa/grandes/."""
import json
import os
import urllib.request

UA = {"User-Agent": "pipa-brasil-ci (pesquisa de modelos)"}
ESCOLHIDOS = {
	"maos_fotorrealistas": "cbefd9fe847541dd8192e3281adf1bce",
	"maos_punhos_fp": "c7e8f959c4094be991b02213d4e66c20",
	"maos_bracos_1": "547a45535f0c4fe787948f7a7a6a88db",
	"maos_bracos_2": "260d75af076c42e1a2f2ff9a0c1957da",
	"casa_favela_1": "b9797c38e4e645b39f0cda8c05bebd5f",
	"casa_favela_2": "c87942d7d3ba43648920c7f7cd451afc",
	"casas_antigas_1": "be4a54f622a14f8b8bb8df70046f1dc1",
	"casas_antigas_2": "789cd0b9c4644a01adc3ace61573baf1",
	"favela_modular": "e2b6f532e1fe4f7280890971d78183f4",
	"coqueiro_1": "dc894acc16544bc69630e9a5232cf74c",
	"coqueiro_2": "ced3b31f14f940d0b7480a83e6f8c9c0",
	"personagem_scan": "73e467dfc8a04914bb314a9410077858",
}
os.makedirs("pesquisa/grandes", exist_ok=True)
linhas = ["| Nome | Modelo | Autor | Licença | Faces | Vértices | Arquivo glTF | Arquivo GLB | Link |", "|---|---|---|---|---|---|---|---|---|"]
for nome, uid in ESCOLHIDOS.items():
	try:
		with urllib.request.urlopen(urllib.request.Request("https://api.sketchfab.com/v3/models/" + uid, headers=UA), timeout=60) as r:
			m = json.load(r)
		arq = m.get("archives") or {}
		def tam(k):
			a = arq.get(k) or {}
			return "%.1f MB" % (a["size"] / 1e6) if a.get("size") else "?"
		thumbs = sorted((m.get("thumbnails") or {}).get("images", []), key=lambda t: -t.get("width", 0))
		grande = [t for t in thumbs if t.get("width", 0) <= 1280]
		if grande:
			with urllib.request.urlopen(urllib.request.Request(grande[0]["url"], headers=UA), timeout=60) as r:
				open("pesquisa/grandes/%s.jpg" % nome, "wb").write(r.read())
		linhas.append("| %s | %s | %s | %s | %s | %s | %s | %s | %s |" % (nome, m["name"], m["user"]["username"], (m.get("license") or {}).get("label"), m.get("faceCount"), m.get("vertexCount"), tam("gltf"), tam("glb"), m["viewerUrl"]))
	except Exception as e:
		linhas.append("| %s | erro %s |" % (nome, e))
open("pesquisa/detalhes.md", "w").write("\n".join(linhas) + "\n")
print("\n".join(linhas))
