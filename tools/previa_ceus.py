#!/usr/bin/env python3
"""Folha de prévias dos céus "pure skies" do Poly Haven, para escolher (D-075)."""
import io, json, urllib.request
from PIL import Image, ImageDraw
UA = {"User-Agent": "pipa-brasil-ci"}
def get(u):
	with urllib.request.urlopen(urllib.request.Request(u, headers=UA), timeout=60) as r:
		return r.read()
cat = json.loads(get("https://api.polyhaven.com/assets?t=hdris"))
nomes = sorted(k for k, v in cat.items() if "pure skies" in v.get("categories", []))
print(len(nomes))
W, H, C = 400, 200, 4
folha = Image.new("RGB", (W * C, (H + 18) * ((len(nomes) + C - 1) // C)), "white")
for i, n in enumerate(nomes):
	try:
		im = Image.open(io.BytesIO(get(f"https://cdn.polyhaven.com/asset_img/thumbs/{n}.png?width={W}&height={H}"))).convert("RGB").resize((W, H))
	except Exception as e:
		print("sem prévia", n, e); continue
	x, y = (i % C) * W, (i // C) * (H + 18)
	folha.paste(im, (x, y + 18))
	ImageDraw.Draw(folha).text((x + 3, y + 3), f"{i} {n} {','.join(c for c in cat[n]['categories'] if c not in ('pure skies','skies','outdoor'))}", fill=(0, 0, 0))
folha.save("previa_ceus.png")
