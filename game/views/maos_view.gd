extends Node3D
## Mãos em primeira pessoa (D-089): duas mãos humanas (modelos CC0 com unhas,
## pele realista e esqueleto) presas à câmera, que seguem o que a física está
## fazendo — a mão da frente é a mão da linha do pipeiro (Pilot.arm_offset:
## recua quando puxa, avança quando afrouxa), os dedos apertam com a tensão,
## e cada comando tem um movimento próprio:
## - puxando: braçada, uma mão depois da outra, dedos fechados;
## - mandando: dedos abertos deixando a linha correr, a outra mão alimenta;
## - desbicando/tenteando: estalo rápido do pulso (para o lado do toque).
## Na largada (pipa na mão): amarrar no cabresto, levar até a beira, erguer e
## soltar. A animação só mostra o que a física faz; não comanda nada.

const MODELO_D := preload("res://game/assets/maos/Hand_Nails_R.gltf")
const MODELO_E := preload("res://game/assets/maos/Hand_Nails_L.gltf")
const SHADER := preload("res://game/views/shaders/mao.gdshader")
const SHADER_LINHA := preload("res://game/views/shaders/mao_linha.gdshader")
const POSES := ["default_pose", "pinch_tight", "pinch_large", "pinch_flat", "grip", "hold", "cup", "grip_3"]
const FOV_MAOS := 58.0   ## campo de visão das mãos durante o voo (a câmera dá zoom na pipa)

var _mao := {}           ## "d"/"e" -> {raiz, esqueleto, poses, ossos}
var _material: ShaderMaterial
var _material_braco: ShaderMaterial
var _linha_mat: ShaderMaterial
var _linha_malha := ImmediateMesh.new()
var _linha_no: MeshInstance3D
var _escala := 1.0       ## tan(fov da câmera / 2) / tan(fov das mãos / 2)
var _t := 0.0
var _fase_bracada := 0.0
var _fase_alimenta := 0.0
var _atual := {}         ## "d"/"e" -> Transform3D suavizado
var _pesos := {}         ## "d"/"e" -> {pose: peso} suavizado
var cor_linha := Color(0.95, 0.95, 0.95)
var folga_linha := 0.03  ## m de barriga da linha entre as mãos
var _mao_frente := "d"   ## a mão que segura a linha que vai para a pipa
var _bracada := false    ## puxando: a linha sai da mão que está mais à frente (sem salto)
var _rapido := false     ## braçada: segue a mão sem atraso
var pronto := false


## tom: 0 = pele clara, 1 = escura (mistura das duas fotos de pele).
func preparar(tom := 0.45) -> void:
	_material = ShaderMaterial.new()
	_material.shader = SHADER
	_material.set_shader_parameter("pele_clara", load("res://game/assets/maos/caucasian_realistic_baseColor.png"))
	_material.set_shader_parameter("pele_escura", load("res://game/assets/maos/african_realistic_baseColor.png"))
	_material.set_shader_parameter("relevo", load("res://game/assets/maos/hands_normal.png"))
	_material.set_shader_parameter("orm", load("res://game/assets/maos/hands_occlusionRoughnessMetallic.png"))
	_material.set_shader_parameter("tom", tom)
	_material.set_shader_parameter("tinta", Color(0.8, 0.7, 0.62))
	_material_braco = _material.duplicate() as ShaderMaterial
	_material_braco.set_shader_parameter("braco", true)
	_material_braco.set_shader_parameter("cor_braco", Color(0.7, 0.5, 0.4).lerp(Color(0.36, 0.24, 0.18), tom))
	for lado in ["d", "e"]:
		var cena: PackedScene = MODELO_D if lado == "d" else MODELO_E
		var raiz := Node3D.new()
		raiz.name = "Mao_" + lado
		add_child(raiz)
		var m := cena.instantiate()
		raiz.add_child(m)
		var esq: Skeleton3D = null
		for n in m.find_children("*", "Skeleton3D", true, false):
			esq = n
		for n in m.find_children("*", "MeshInstance3D", true, false):
			var mi := n as MeshInstance3D
			mi.material_override = _material
			mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			mi.extra_cull_margin = 4.0
		# antebraço (a camiseta é de manga curta). D-090: cápsula comprida, que
		# começa por dentro do pulso (esconde o corte do modelo da mão) e vai
		# até fora da tela; margem de recorte grande, porque o campo de visão
		# das mãos põe o braço na tela num lugar diferente de onde a câmera
		# acha que ele está (no iPhone ele sumia).
		var braco := MeshInstance3D.new()
		var cap := CapsuleMesh.new()
		cap.radius = 0.034
		cap.height = 0.62
		cap.radial_segments = 20
		cap.rings = 6
		braco.mesh = cap
		braco.material_override = _material_braco
		braco.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		braco.extra_cull_margin = 4.0
		# a cápsula (eixo Y) vai do pulso para trás (+Z da mão), um pouco para baixo.
		# D-091: na medida da abertura do pulso do modelo (medida nos vértices:
		# centro x ∓3,8 mm, y −2,4 mm; meia largura 24 mm de lado, 32 mm de
		# polegar a mindinho) — antes ficava torto e aparecia o corte.
		var giro := Basis(Vector3.RIGHT, deg_to_rad(90.0 + 6.0))
		var centro := Vector3(-0.0038 if lado == "d" else 0.0038, -0.0024, 0.0)
		braco.transform = Transform3D(giro * Basis.from_scale(Vector3(0.78, 1.0, 1.0)), centro + giro * Vector3(0.0, 0.31 - 0.03, 0.0))
		raiz.add_child(braco)
		var poses := {}
		var suf := "R" if lado == "d" else "L"
		for p in POSES:
			poses[p] = _ler_pose("res://game/assets/maos/poses/%s_%s.res" % [p, suf], esq)
		var ossos := {}
		if esq != null:
			for nome in ["Thumb_Tip", "Index_Intermediate", "Index_Tip", "Middle_Proximal", "Wrist"]:
				ossos[nome] = esq.find_bone("%s_%s" % [nome, suf])
		_mao[lado] = {"raiz": raiz, "esqueleto": esq, "poses": poses, "ossos": ossos}
		_atual[lado] = Transform3D.IDENTITY
		_pesos[lado] = {"pinch_tight": 1.0}
	_linha_mat = ShaderMaterial.new()
	_linha_mat.shader = SHADER_LINHA
	_linha_no = MeshInstance3D.new()
	_linha_no.name = "LinhaNasMaos"
	_linha_no.mesh = _linha_malha
	_linha_no.material_override = _linha_mat
	_linha_no.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_linha_no.extra_cull_margin = 4.0
	add_child(_linha_no)
	pronto = true


## Rotação de cada osso numa pose (o primeiro quadro da animação da pose).
func _ler_pose(caminho: String, esq: Skeleton3D) -> Dictionary:
	var out := {}
	if esq == null or not ResourceLoader.exists(caminho):
		return out
	var a := load(caminho) as Animation
	if a == null:
		return out
	for i in a.get_track_count():
		var osso := esq.find_bone(String(a.track_get_path(i).get_concatenated_subnames()))
		if osso < 0:
			continue
		match a.track_get_type(i):
			Animation.TYPE_ROTATION_3D:
				out[osso] = a.rotation_track_interpolate(i, 0.0)
			Animation.TYPE_VALUE:
				var v: Variant = a.value_track_interpolate(i, 0.0)
				if v is Quaternion:
					out[osso] = v
	return out


func _aplicar_pesos(lado: String) -> void:
	var m: Dictionary = _mao[lado]
	var esq: Skeleton3D = m["esqueleto"]
	if esq == null:
		return
	var pesos: Dictionary = _pesos[lado]
	var acum := {}
	var soma := 0.0
	for p in pesos:
		var w: float = pesos[p]
		if w <= 0.001:
			continue
		var pose: Dictionary = m["poses"].get(p, {})
		soma += w
		for osso in pose:
			var q: Quaternion = pose[osso]
			if acum.has(osso):
				acum[osso] = (acum[osso] as Quaternion).slerp(q, w / soma)
			else:
				acum[osso] = q
	for osso in acum:
		esq.set_bone_pose_rotation(osso, acum[osso])


func _rumo_pesos(lado: String, alvo: Dictionary, k: float) -> void:
	var p: Dictionary = _pesos[lado]
	for nome in POSES:
		var a: float = p.get(nome, 0.0)
		var b: float = alvo.get(nome, 0.0)
		p[nome] = lerpf(a, b, k)


static func _rot(pitch: float, yaw: float, roll: float) -> Basis:
	return Basis.from_euler(Vector3(deg_to_rad(pitch), deg_to_rad(yaw), deg_to_rad(roll)), EULER_ORDER_YXZ)


## estado:
##   modo: "voo" | "mao" | "amarrar" | "andar" | "erguer"
##   arm (m, Pilot.arm_offset), tensao (N), haul (m/s, + puxa), desbico (s desde o
##   último toque), lado (±1), puxao (bool), fase (0..1 da fase da largada),
##   pipa (Vector3, centro da pipa na mão em coordenadas da câmera)
func atualizar(cam: Camera3D, estado: Dictionary, delta: float) -> void:
	if not pronto:
		return
	_t += delta
	var modo: String = estado.get("modo", "voo")
	_escala = 1.0
	if modo == "voo":
		_escala = tan(deg_to_rad(cam.fov) * 0.5) / tan(deg_to_rad(FOV_MAOS) * 0.5)
	for mat in [_material, _material_braco, _linha_mat]:
		mat.set_shader_parameter("escala_vm", _escala)
	var alvo := {}
	var poses := {}
	var flick := 0.0
	_mao_frente = "d"
	_rapido = false
	_bracada = false
	var lado_toque: float = estado.get("lado", 1.0)
	var respira := sin(_t * 1.7) * 0.004
	if modo == "voo":
		var arm: float = estado.get("arm", 0.0)
		var tens := clampf(float(estado.get("tensao", 0.0)) / 12.0, 0.0, 1.0)
		var haul: float = estado.get("haul", 0.0)
		var forca := clampf(absf(haul) / 4.0, 0.0, 1.0)
		var d := Vector3(0.14, -0.17 + respira + arm * 0.08, -0.5 - arm * 0.3)
		var e := Vector3(-0.13, -0.2 + respira * 0.7, -0.45)
		var rd := Vector3(22.0 + tens * 6.0, 9.0, -14.0)
		var re := Vector3(8.0, -12.0, 18.0)
		var pd := {"pinch_tight": 1.0 - tens * 0.6, "grip": tens * 0.6}
		var pe := {"hold": 1.0}
		folga_linha = lerpf(0.03, 0.01, tens)
		if haul > 0.2 or bool(estado.get("puxao", false)):
			# PUXANDO (D-092): braçada de verdade, no ritmo da puxada — uma mão
			# fechada puxa da frente até perto do corpo enquanto a outra, aberta,
			# passa por fora e vai pegar a linha lá na frente; depois trocam.
			# D-093: no ritmo da linha que entra — cada meia braçada recolhe
			# ~0,6 m; a mão que puxa desce liso, na velocidade da linha
			# D-104: mais rápido (cada meia braçada ~0,45 m de linha)
			var ritmo := clampf(maxf(haul, 0.0) / 0.9, 1.6, 4.6)   # braçadas de cada mão por segundo
			if bool(estado.get("puxao", false)):
				ritmo = 4.6
				forca = 1.0
			_fase_bracada += delta * ritmo
			_rapido = true
			_bracada = true
			var amp := 0.6 + 0.4 * forca
			# as duas mãos ficam na tela: pega lá em cima, puxa até embaixo
			var ponta := {"d": Vector3(0.025, 0.0, -0.56), "e": Vector3(-0.025, -0.005, -0.56)}
			var corpo := {"d": Vector3(0.08, -0.19, -0.38), "e": Vector3(-0.08, -0.195, -0.38)}
			var res := {}
			for lado in ["d", "e"]:
				var s := fmod(_fase_bracada + (0.0 if lado == "d" else 0.5), 1.0)
				var sinal := 1.0 if lado == "d" else -1.0
				var f: Vector3 = ponta[lado]
				var c: Vector3 = f.lerp(corpo[lado], amp)
				var pos: Vector3
				var pitch: float
				var pose: Dictionary
				if s < 0.5:
					# fechada, puxando liso (velocidade constante, sem tranco)
					var k := s / 0.5
					pos = f.lerp(c, k)
					pitch = lerpf(28.0, -12.0, k)
					pose = {"grip": 1.0}
				else:
					# aberta, voltando por fora da outra mão
					var k := smoothstep(0.0, 1.0, (s - 0.5) / 0.5)
					var arco := sin(k * PI)
					pos = c.lerp(f, k) + Vector3(0.05 * sinal, 0.02, 0.03) * arco
					pitch = lerpf(-12.0, 28.0, k)
					pose = {"pinch_large": 0.7, "default_pose": 0.3}
				res[lado] = [pos, pitch, pose]
			d = res["d"][0]
			e = res["e"][0]
			_mao_frente = "d" if d.z < e.z else "e"
			rd = Vector3(res["d"][1], 9.0, -14.0)
			re = Vector3(res["e"][1], -12.0, 18.0)
			pd = res["d"][2]
			pe = res["e"][2]
			folga_linha = 0.012
		elif haul < -0.2:
			# MANDANDO: dedos abertos, a linha corre; a outra mão alimenta
			_fase_alimenta += delta * (0.6 + 1.2 * forca)
			var s := fmod(_fase_alimenta, 1.0)
			var vai := 0.5 - 0.5 * cos(s * TAU)
			d += Vector3(0.0, 0.015 * forca, -0.05 * forca) + Vector3(sin(_t * 47.0), cos(_t * 39.0), 0.0) * 0.0015 * forca
			e += Vector3(0.03 * vai, 0.05 * vai, -0.09 * vai) * (0.5 + 0.5 * forca)
			rd += Vector3(10.0 * forca, 0.0, -4.0)
			re += Vector3(15.0 * vai, 0.0, 0.0)
			pd = {"pinch_large": 0.7 + 0.3 * forca, "pinch_tight": 0.3 - 0.3 * forca}
			pe = {"pinch_large": vai, "hold": 1.0 - vai}
			folga_linha = 0.03 + 0.03 * forca
		var desde: float = estado.get("desbico", 99.0)
		if desde < 0.24:
			# DESBICANDO / TENTEANDO: estalo rápido do pulso para o lado do toque
			var k := desde / 0.24
			flick = sin(k * PI) * (1.0 - k * 0.3)
			pd = {"grip": maxf(0.5, flick), "pinch_tight": 1.0 - maxf(0.5, flick)}
		alvo["d"] = Transform3D(_rot(rd.x, rd.y, rd.z), d)
		alvo["e"] = Transform3D(_rot(re.x, re.y, re.z), e)
		poses["d"] = pd
		poses["e"] = pe
	else:
		var pipa: Vector3 = estado.get("pipa", Vector3(0.0, -0.35, -0.5))
		var fase: float = estado.get("fase", 0.0)
		match modo:
			"amarrar":
				# D-091: a pipa de frente para os olhos; a mão esquerda segura a
				# vareta do meio embaixo, a direita dá as voltas da linha no cabresto
				var w := _t * TAU * 1.8
				var tp: Transform3D = estado.get("pipa_t", Transform3D(Basis.IDENTITY, pipa))
				var cab: Vector3 = estado.get("cabresto", pipa)
				# orientação das mãos no referencial do corpo (dedos para a frente,
				# braço vindo de baixo), não no da câmera, que olha para baixo
				var corpo: Basis = estado.get("corpo", Basis.IDENTITY)
				var embaixo := tp * Vector3(0.0, -0.2, 0.035)
				alvo["e"] = Transform3D(corpo * _rot(-25.0, -20.0, 60.0), embaixo + corpo * Vector3(-0.02, 0.0, 0.03))
				var volta := tp.basis * Vector3(cos(w), sin(w), 0.0) * 0.022
				alvo["d"] = Transform3D(corpo * _rot(-30.0 + sin(w) * 15.0, 25.0, -45.0 + cos(w) * 20.0),
					cab + corpo * Vector3(0.03, -0.02, 0.06) + volta)
				var aperta := 0.5 + 0.5 * sin(w)
				poses["d"] = {"pinch_tight": aperta, "pinch_large": 1.0 - aperta}
				poses["e"] = {"grip": 1.0}
			"andar", "erguer":
				# segurando a pipa pelos lados; erguendo, sobe e solta no fim
				var abre := smoothstep(0.75, 1.0, fase) if modo == "erguer" else 0.0
				alvo["e"] = Transform3D(_rot(70.0, -10.0, 35.0 - 40.0 * abre), pipa + Vector3(-0.17 - 0.1 * abre, -0.08, 0.06))
				alvo["d"] = Transform3D(_rot(70.0, 10.0, -35.0 + 40.0 * abre), pipa + Vector3(0.17 + 0.1 * abre, -0.08, 0.06))
				poses["d"] = {"grip": 1.0 - abre, "default_pose": abre}
				poses["e"] = {"grip": 1.0 - abre, "default_pose": abre}
			_:
				# pipa ainda na mão, escolhendo: mãos baixas e soltas
				alvo["d"] = Transform3D(_rot(10.0, 10.0, -10.0), Vector3(0.17, -0.21 + respira, -0.4))
				alvo["e"] = Transform3D(_rot(10.0, -10.0, 10.0), Vector3(-0.17, -0.23 + respira, -0.38))
				poses["d"] = {"hold": 1.0}
				poses["e"] = {"hold": 1.0}
	var k_pos := 1.0 - exp(-(45.0 if _rapido else 16.0) * delta)
	var k_ded := 1.0 - exp(-(40.0 if _rapido else 14.0) * delta)
	for lado in ["d", "e"]:
		_atual[lado] = (_atual[lado] as Transform3D).interpolate_with(alvo[lado], k_pos)
		var t: Transform3D = _atual[lado]
		if lado == "d" and flick > 0.0:
			# o estalo vai por cima da suavização (é rápido)
			t.basis = t.basis * _rot(-38.0 * flick, 0.0, 22.0 * flick * lado_toque)
			t.origin += Vector3(0.012 * lado_toque, 0.01, 0.045) * flick
		elif lado == "e" and flick > 0.0:
			t.origin += Vector3(0.0, 0.0, 0.015) * flick
		(_mao[lado]["raiz"] as Node3D).transform = t
		_rumo_pesos(lado, poses[lado], k_ded)
		_aplicar_pesos(lado)
	_desenhar_linha()


## Onde a linha passa na mão (entre o polegar e o indicador), em coordenadas da câmera.
func ponto_mao(lado := "d") -> Vector3:
	if not pronto:
		return Vector3(0.15, -0.15, -0.4)
	var m: Dictionary = _mao[lado]
	var esq: Skeleton3D = m["esqueleto"]
	var raiz: Node3D = m["raiz"]
	if esq == null:
		return raiz.position
	var a := int(m["ossos"].get("Thumb_Tip", -1))
	var b := int(m["ossos"].get("Index_Intermediate", -1))
	if a < 0 or b < 0:
		return raiz.position
	var pa := esq.global_transform * esq.get_bone_global_pose(a).origin
	var pb := esq.global_transform * esq.get_bone_global_pose(b).origin
	return to_local(pa.lerp(pb, 0.5))


## Ponto do mundo que aparece na tela exatamente onde a linha sai da mão da
## frente: daí a linha da física segue até a pipa.
## Por onde a linha da pipa sai das mãos. Na braçada, da mão que está mais à
## frente, passando de uma para a outra aos poucos quando elas se cruzam (antes
## pulava de mão: a linha parecia dar trancos).
func ponto_saida() -> Vector3:
	var pd := ponto_mao("d")
	if not _bracada:
		return pd
	var pe := ponto_mao("e")
	var w := smoothstep(-0.05, 0.05, pd.z - pe.z)   # 0 = direita na frente, 1 = esquerda
	return pd.lerp(pe, w)


func ponto_linha_no_mundo(cam: Camera3D, profundidade := 1.5) -> Vector3:
	var p := ponto_saida()
	var q := Vector3(p.x * _escala, p.y * _escala, p.z)
	if q.z > -0.01:
		return cam.global_transform * q
	return cam.global_transform * (q * (profundidade / -q.z))


func _desenhar_linha() -> void:
	_linha_malha.clear_surfaces()
	# da saída (mão da frente) até a outra mão
	var d := ponto_saida()
	var e := ponto_mao("e")
	if _bracada and ponto_mao("e").z < ponto_mao("d").z:
		e = ponto_mao("d")
	var pts: Array[Vector3] = []
	# da mão da frente até a de trás, com barriga
	for i in 9:
		var s := i / 8.0
		pts.append(d.lerp(e, s) + Vector3(0.0, -4.0 * s * (1.0 - s) * folga_linha, 0.0))
	# da mão de trás para baixo (o resto da linha, no chão da laje)
	pts.append(e + Vector3(0.03, -0.25, 0.12))
	pts.append(e + Vector3(0.05, -0.6, 0.3))
	_linha_malha.surface_begin(Mesh.PRIMITIVE_TRIANGLES)
	_linha_malha.surface_set_color(cor_linha)
	var largura := 0.0009
	for i in pts.size() - 1:
		var a := pts[i]
		var b := pts[i + 1]
		var dir := (b - a).normalized()
		var lado := dir.cross((a + b) * -0.5).normalized() * largura
		_linha_malha.surface_add_vertex(a - lado)
		_linha_malha.surface_add_vertex(a + lado)
		_linha_malha.surface_add_vertex(b + lado)
		_linha_malha.surface_add_vertex(a - lado)
		_linha_malha.surface_add_vertex(b + lado)
		_linha_malha.surface_add_vertex(b - lado)
	_linha_malha.surface_end()
