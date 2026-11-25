#!/usr/bin/env python3
"""Lista os modelos 3D CC0 do Poly Haven com número de triângulos (D-068).
Só para escolher quais baixar; roda no GitHub Actions."""
import json
import urllib.request

UA = {"User-Agent": "pipa-brasil-ci"}
def j(u):
	with urllib.request.urlopen(urllib.request.Request(u, headers=UA), timeout=60) as r:
		return json.load(r)

todos = j("https://api.polyhaven.com/assets?t=models")
for nome, info in sorted(todos.items()):
	print(f"MODELO {nome} | {info.get('polycount', '?')} | {','.join(info.get('categories', []))} | {','.join(info.get('tags', [])[:6])}")
