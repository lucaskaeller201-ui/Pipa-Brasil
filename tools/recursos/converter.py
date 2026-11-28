"""Converte os recursos baixados para o jogo (D-098). Roda dentro do Blender:
	blender -b -P tools/recursos/converter.py

- Personagens Rocketbox: FBX + texturas 4K -> GLB com texturas 1K (cabelo e
  cílios com recorte), e uma prévia renderizada para conferir.
- Árvores e arbustos Poly Haven: "cartões" (impostores) — a árvore de verdade
  fotografada de 4 lados com fundo transparente, numa imagem só.
- Coqueiros: GLB leve.
"""
import glob
import json
import math
import os
import shutil
import sys

import bpy
from mathutils import Vector

T = os.path.abspath("trabalho")
SAIDA = os.path.abspath("assets")
PREVIAS = os.path.abspath("previas")
os.makedirs(PREVIAS, exist_ok=True)
relatorio = []


def limpar():
	bpy.ops.wm.read_factory_settings(use_empty=True)


def caixa():
	mn = Vector((1e9, 1e9, 1e9))
	mx = -mn
	for o in bpy.context.scene.objects:
		if o.type != "MESH":
			continue
		for c in o.bound_box:
			w = o.matrix_world @ Vector(c)
			mn = Vector((min(mn.x, w.x), min(mn.y, w.y), min(mn.z, w.z)))
			mx = Vector((max(mx.x, w.x), max(mx.y, w.y), max(mx.z, w.z)))
	return mn, mx


def triangulos():
	n = 0
	for o in bpy.context.scene.objects:
		if o.type == "MESH":
			n += sum(len(p.vertices) - 2 for p in o.data.polygons)
	return n


def render(caminho, frente=Vector((0, -1, 0)), tam=(512, 768), transparente=False, orto=False, amostras=24):
	cena = bpy.context.scene
	cena.render.engine = "CYCLES"
	cena.cycles.device = "CPU"
	cena.cycles.samples = amostras
	cena.render.resolution_x, cena.render.resolution_y = tam
	cena.render.film_transparent = transparente
	cena.render.image_settings.file_format = "PNG"
	cena.render.image_settings.color_mode = "RGBA"
	if cena.world is None:
		cena.world = bpy.data.worlds.new("Mundo")
	cena.world.use_nodes = True
	bg = cena.world.node_tree.nodes.get("Background")
	bg.inputs[0].default_value = (0.55, 0.65, 0.8, 1)
	bg.inputs[1].default_value = 0.8
	mn, mx = caixa()
	centro = (mn + mx) / 2
	alto = mx.z - mn.z
	largo = max(mx.x - mn.x, mx.y - mn.y)
	for o in [o for o in cena.objects if o.type in ("CAMERA", "LIGHT")]:
		bpy.data.objects.remove(o)
	cam = bpy.data.objects.new("Cam", bpy.data.cameras.new("Cam"))
	cena.collection.objects.link(cam)
	cena.camera = cam
	dist = max(alto, largo) * 2.2
	cam.location = centro - frente.normalized() * dist
	cam.rotation_euler = (-frente).to_track_quat("Z", "Y").to_euler()
	if orto:
		cam.data.type = "ORTHO"
		cam.data.ortho_scale = max(alto, largo) * 1.05
	else:
		cam.data.lens = 50 * dist / (max(alto, largo) * 1.4) * 0.9
	sol = bpy.data.objects.new("Sol", bpy.data.lights.new("Sol", "SUN"))
	sol.data.energy = 3.5
	sol.rotation_euler = (math.radians(50), 0, math.radians(30))
	cena.collection.objects.link(sol)
	cena.render.filepath = caminho
	bpy.ops.render.render(write_still=True)


# ---------------- personagens ----------------
def personagem(nome):
	limpar()
	pasta = os.path.join(T, "rocketbox/Assets/Avatars/Adults", nome)
	fbx = os.path.join(pasta, "Export", nome + ".fbx")
	tex = os.path.join(pasta, "Textures")
	bpy.ops.import_scene.fbx(filepath=fbx, use_image_search=False, automatic_bone_orientation=False)
	# texturas: aponta para Textures/ e reduz para 1K
	for img in bpy.data.images:
		base = os.path.basename(img.filepath.replace("\\", "/"))
		cand = os.path.join(tex, base)
		if not os.path.exists(cand):
			alt = [f for f in os.listdir(tex) if os.path.splitext(f)[0].lower() == os.path.splitext(base)[0].lower()]
			cand = os.path.join(tex, alt[0]) if alt else cand
		if os.path.exists(cand):
			img.filepath = cand
			img.reload()
		if img.size[0] > 1024:
			img.scale(1024, 1024)
	# materiais: liga as fotos que o FBX não ligou; opacidade vira recorte
	fotos = {os.path.basename(f).lower(): f for f in glob.glob(os.path.join(tex, "*"))}
	for mat in bpy.data.materials:
		if not mat.use_nodes:
			continue
		nt = mat.node_tree
		bsdf = next((n for n in nt.nodes if n.type == "BSDF_PRINCIPLED"), None)
		if bsdf is None:
			continue
		usadas = [n.image.name.lower() for n in nt.nodes if n.type == "TEX_IMAGE" and n.image]
		for n in nt.nodes:
			if n.type == "TEX_IMAGE" and n.image and "opacity" in n.image.name.lower():
				nt.links.new(n.outputs["Color"], bsdf.inputs["Alpha"])
				mat.blend_method = "CLIP"
		# cor sem textura: procura uma foto pelo nome do material
		if not bsdf.inputs["Base Color"].is_linked:
			chave = mat.name.lower().split(".")[0]
			for k, f in fotos.items():
				if "color" in k and (chave in k or k.split("_")[0] in chave):
					img = bpy.data.images.load(f)
					if img.size[0] > 1024:
						img.scale(1024, 1024)
					no = nt.nodes.new("ShaderNodeTexImage")
					no.image = img
					nt.links.new(no.outputs["Color"], bsdf.inputs["Base Color"])
					break
		if "Specular IOR Level" in bsdf.inputs:
			bsdf.inputs["Specular IOR Level"].default_value = 0.3
		bsdf.inputs["Roughness"].default_value = 0.7
	tris = triangulos()
	mn, mx = caixa()
	saida = os.path.join(SAIDA, "personagens", nome + ".glb")
	os.makedirs(os.path.dirname(saida), exist_ok=True)
	bpy.ops.export_scene.gltf(filepath=saida, export_format="GLB", export_image_format="JPEG", export_jpeg_quality=85,
		export_animations=False, export_apply=False, export_yup=True)
	ossos = [b.name for o in bpy.context.scene.objects if o.type == "ARMATURE" for b in o.data.bones]
	relatorio.append({"tipo": "personagem", "nome": nome, "triangulos": tris, "altura": round(mx.z - mn.z, 3),
		"mb": round(os.path.getsize(saida) / 1e6, 2), "materiais": [m.name for m in bpy.data.materials],
		"ossos_exemplo": [b for b in ossos if any(k in b.lower() for k in ["upperarm", "forearm", "hand", "head", "spine", "toe", "foot", "clavicle"])][:30]})
	render(os.path.join(PREVIAS, "personagem_" + nome + ".png"))


# ---------------- árvores (cartões) ----------------
def arvore(nome):
	limpar()
	pasta = os.path.join(T, "polyhaven", nome)
	bpy.ops.import_scene.gltf(filepath=os.path.join(pasta, nome + ".gltf"))
	tris = triangulos()
	mn, mx = caixa()
	imagens = []
	for k in range(4):
		a = math.radians(k * 90.0)
		f = os.path.join(PREVIAS, "_lado_%s_%d.png" % (nome, k))
		render(f, frente=Vector((math.sin(a), -math.cos(a), 0.0)), tam=(512, 512), transparente=True, orto=True, amostras=32)
		imagens.append(f)
	# junta os 4 lados numa imagem 2048x512
	atlas = bpy.data.images.new("atlas", 2048, 512, alpha=True)
	px = [0.0] * (2048 * 512 * 4)
	for k, f in enumerate(imagens):
		im = bpy.data.images.load(f)
		p = list(im.pixels)
		for y in range(512):
			o = (y * 2048 + k * 512) * 4
			px[o:o + 512 * 4] = p[y * 512 * 4:(y + 1) * 512 * 4]
	atlas.pixels = px
	saida = os.path.join(SAIDA, "vegetacao", nome + "_cartoes.png")
	os.makedirs(os.path.dirname(saida), exist_ok=True)
	atlas.filepath_raw = saida
	atlas.file_format = "PNG"
	atlas.save()
	relatorio.append({"tipo": "arvore", "nome": nome, "triangulos_original": tris, "altura": round(mx.z - mn.z, 2),
		"largura": round(max(mx.x - mn.x, mx.y - mn.y), 2), "mb": round(os.path.getsize(saida) / 1e6, 2)})
	shutil.copy(imagens[0], os.path.join(PREVIAS, "arvore_" + nome + ".png"))


# ---------------- coqueiros ----------------
def coqueiros():
	cand = [f for f in glob.glob(os.path.join(T, "coqueiros", "**", "*"), recursive=True) if f.lower().endswith((".fbx", ".obj", ".dae", ".blend"))]
	relatorio.append({"tipo": "coqueiros_arquivos", "arquivos": [os.path.relpath(f, T) for f in cand]})
	if not cand:
		return
	# os FBX deste pacote são da versão 6100 (o Blender lê só 7100+): usa os OBJ
	objs = sorted(f for f in cand if f.lower().endswith(".obj"))
	relatorio.append({"tipo": "coqueiros_lidos", "arquivos": [os.path.basename(f) for f in objs]})
	limpar()
	for k, f in enumerate(objs):
		bpy.ops.wm.obj_import(filepath=f, forward_axis="NEGATIVE_Z", up_axis="Y")
		for o in bpy.context.selected_objects:
			# o pacote vem em centímetros (2,16 m de altura = 216): ~8,5 m no jogo
			o.scale = (0.04, 0.04, 0.04)
			o.location = (o.location.x * 0.04 + k * 9.0, o.location.y * 0.04, o.location.z * 0.04)
			o.name = os.path.splitext(os.path.basename(f))[0] + "_" + o.name
	f = objs[0] if objs else cand[0]
	for img in bpy.data.images:
		base = os.path.basename(img.filepath.replace("\\", "/"))
		achado = glob.glob(os.path.join(T, "coqueiros", "**", base), recursive=True)
		if achado:
			img.filepath = achado[0]
			img.reload()
		if img.size[0] > 1024:
			img.scale(1024, 1024)
	dif = glob.glob(os.path.join(T, "coqueiros", "**", "diffuse.tga"), recursive=True)
	# os OBJ vêm sem .mtl: um material só, com a textura do pacote, em todos
	palma = bpy.data.materials.new("palma")
	for o in bpy.context.scene.objects:
		if o.type == "MESH":
			o.data.materials.clear()
			o.data.materials.append(palma)
	relatorio.append({"tipo": "coqueiros_textura", "difusa": dif, "materiais": [m.name for m in bpy.data.materials]})
	for mat in [palma]:
		mat.use_nodes = True
		nt = mat.node_tree
		bsdf = next((n for n in nt.nodes if n.type == "BSDF_PRINCIPLED"), None)
		if bsdf is not None and dif:
			for l in list(bsdf.inputs["Base Color"].links) + list(bsdf.inputs["Alpha"].links):
				nt.links.remove(l)
			img = bpy.data.images.load(dif[0])
			if img.size[0] > 1024:
				img.scale(1024, 1024)
			no = nt.nodes.new("ShaderNodeTexImage")
			no.image = img
			nt.links.new(no.outputs["Color"], bsdf.inputs["Base Color"])
			nt.links.new(no.outputs["Alpha"], bsdf.inputs["Alpha"])
		mat.blend_method = "CLIP"
		if bsdf is not None:
			bsdf.inputs["Roughness"].default_value = 0.8
	saida = os.path.join(SAIDA, "vegetacao", "coqueiros.glb")
	bpy.ops.export_scene.gltf(filepath=saida, export_format="GLB", export_image_format="AUTO", export_apply=True, export_yup=True)
	mn, mx = caixa()
	relatorio.append({"tipo": "coqueiros", "fonte": os.path.relpath(f, T), "triangulos": triangulos(), "altura": round(mx.z - mn.z, 2),
		"objetos": [o.name for o in bpy.context.scene.objects if o.type == "MESH"], "mb": round(os.path.getsize(saida) / 1e6, 2)})
	render(os.path.join(PREVIAS, "coqueiros.png"), tam=(768, 512))


for etapa, args in [(personagem, n) for n in ["Male_Adult_01", "Male_Adult_17", "Male_Adult_04", "Male_Adult_16", "Male_Adult_09", "Male_Adult_11", "Male_Adult_20"]] + \
		[(arvore, n) for n in ["island_tree_01", "tree_small_02", "jacaranda_tree"]] + [(coqueiros, None)]:
	try:
		etapa(args) if args is not None else etapa()
	except Exception as e:
		import traceback
		relatorio.append({"erro": str(e), "etapa": etapa.__name__, "args": args, "trace": traceback.format_exc()[-1500:]})
json.dump(relatorio, open(os.path.join(PREVIAS, "relatorio.json"), "w"), indent=1, ensure_ascii=False)
print(json.dumps(relatorio, indent=1, ensure_ascii=False))
