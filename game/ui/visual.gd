extends RefCounted
## Padrão visual da interface (D-094): paleta, fontes e ícones desenhados
## (nítidos em qualquer tela, sem arquivo de imagem). Todos os botões, pílulas,
## painéis e mensagens usam estas cores e estas formas.

const AZUL := Color(0.05, 0.11, 0.26, 0.86)        ## azul profundo (pílulas e botões)
const AZUL_CLARO := Color(0.16, 0.3, 0.58, 0.95)   ## borda e destaque do azul
const VERDE := Color(0.22, 0.78, 0.2)              ## ações principais
const VERDE_ESCURO := Color(0.08, 0.5, 0.1)
const AMARELO := Color(1.0, 0.8, 0.14)             ## destaques e números
const BRANCO := Color(1.0, 1.0, 1.0)
const GRAFITE := Color(0.1, 0.11, 0.14, 0.86)      ## painéis

static var _fonte_texto: Font
static var _fonte_negrito: Font
static var _fonte_titulo: Font


static func fonte(peso := 600) -> Font:
	if peso >= 700:
		if _fonte_negrito == null:
			_fonte_negrito = _variacao(780)
		return _fonte_negrito
	if _fonte_texto == null:
		_fonte_texto = _variacao(600)
	return _fonte_texto


static func _variacao(peso: int) -> Font:
	var base := load("res://game/assets/fontes/Baloo2.ttf") as FontFile
	if base == null:
		return ThemeDB.fallback_font
	var v := FontVariation.new()
	v.base_font = base
	v.variation_opentype = {TextServerManager.get_primary_interface().name_to_tag("wght"): peso}
	return v


## Fonte grossa do logo e das mensagens de combate (Luckiest Guy).
static func fonte_titulo() -> Font:
	if _fonte_titulo == null:
		_fonte_titulo = load("res://game/assets/fontes/LuckiestGuy-Regular.ttf") as Font
		if _fonte_titulo == null:
			_fonte_titulo = ThemeDB.fallback_font
	return _fonte_titulo


## Pílula (cápsula) de fundo azul profundo com borda fina.
static func pilula(c: CanvasItem, r: Rect2, cor := AZUL, borda := AZUL_CLARO) -> void:
	var sb := StyleBoxFlat.new()
	sb.bg_color = cor
	sb.set_corner_radius_all(int(r.size.y * 0.5))
	sb.border_color = borda
	sb.set_border_width_all(2)
	sb.anti_aliasing = true
	sb.shadow_color = Color(0, 0, 0, 0.25)
	sb.shadow_size = 4
	sb.shadow_offset = Vector2(0, 2)
	c.draw_style_box(sb, r)


static func caixa(raio: int, cor := GRAFITE, borda := AZUL_CLARO) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = cor
	sb.set_corner_radius_all(raio)
	sb.border_color = borda
	sb.set_border_width_all(2)
	sb.anti_aliasing = true
	sb.set_content_margin_all(14)
	return sb


static func texto(c: CanvasItem, pos: Vector2, s: String, tamanho: int, cor := BRANCO, peso := 600, contorno := 0) -> void:
	var f := fonte(peso)
	if contorno > 0:
		c.draw_string_outline(f, pos, s, HORIZONTAL_ALIGNMENT_LEFT, -1, tamanho, contorno, Color(0, 0, 0, 0.75))
	c.draw_string(f, pos, s, HORIZONTAL_ALIGNMENT_LEFT, -1, tamanho, cor)


static func largura(s: String, tamanho: int, peso := 600) -> float:
	return fonte(peso).get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1, tamanho).x


## Ícones desenhados: nome, centro e raio (metade do tamanho).
static func icone(c: CanvasItem, nome: String, p: Vector2, r: float, cor := BRANCO) -> void:
	match nome:
		"camera":
			var corpo := Rect2(p + Vector2(-r * 0.85, -r * 0.5), Vector2(r * 1.7, r * 1.2))
			var sb := StyleBoxFlat.new()
			sb.bg_color = cor
			sb.set_corner_radius_all(int(r * 0.25))
			sb.anti_aliasing = true
			c.draw_style_box(sb, corpo)
			c.draw_rect(Rect2(p + Vector2(-r * 0.35, -r * 0.72), Vector2(r * 0.7, r * 0.3)), cor)
			c.draw_circle(p + Vector2(0, r * 0.1), r * 0.42, AZUL)
			c.draw_circle(p + Vector2(0, r * 0.1), r * 0.27, cor)
		"engrenagem":
			for k in 8:
				var a := k * TAU / 8.0
				var d := Vector2.from_angle(a)
				var o := d.orthogonal()
				c.draw_colored_polygon(PackedVector2Array([p + d * r * 0.55 + o * r * 0.2, p + d * r * 0.95 + o * r * 0.15,
					p + d * r * 0.95 - o * r * 0.15, p + d * r * 0.55 - o * r * 0.2]), cor)
			c.draw_circle(p, r * 0.68, cor)
			c.draw_circle(p, r * 0.3, AZUL)
		"pausa":
			c.draw_rect(Rect2(p + Vector2(-r * 0.5, -r * 0.65), Vector2(r * 0.35, r * 1.3)), cor)
			c.draw_rect(Rect2(p + Vector2(r * 0.15, -r * 0.65), Vector2(r * 0.35, r * 1.3)), cor)
		"play":
			c.draw_colored_polygon(PackedVector2Array([p + Vector2(-r * 0.45, -r * 0.7), p + Vector2(r * 0.7, 0), p + Vector2(-r * 0.45, r * 0.7)]), cor)
		"trofeu":
			var ouro := Color(1.0, 0.78, 0.15)
			var escuro := Color(0.8, 0.5, 0.05)
			c.draw_colored_polygon(PackedVector2Array([p + Vector2(-r * 0.6, -r * 0.8), p + Vector2(r * 0.6, -r * 0.8),
				p + Vector2(r * 0.45, -r * 0.05), p + Vector2(0, r * 0.25), p + Vector2(-r * 0.45, -r * 0.05)]), ouro)
			c.draw_arc(p + Vector2(-r * 0.62, -r * 0.45), r * 0.3, PI * 0.5, PI * 1.5, 12, ouro, r * 0.14)
			c.draw_arc(p + Vector2(r * 0.62, -r * 0.45), r * 0.3, -PI * 0.5, PI * 0.5, 12, ouro, r * 0.14)
			c.draw_rect(Rect2(p + Vector2(-r * 0.1, r * 0.2), Vector2(r * 0.2, r * 0.35)), escuro)
			c.draw_rect(Rect2(p + Vector2(-r * 0.45, r * 0.55), Vector2(r * 0.9, r * 0.25)), ouro)
			c.draw_line(p + Vector2(-r * 0.3, -r * 0.65), p + Vector2(-r * 0.25, -r * 0.2), Color(1, 1, 0.85, 0.8), r * 0.1)
		"coroa":
			var ouro2 := Color(1.0, 0.8, 0.2)
			c.draw_colored_polygon(PackedVector2Array([p + Vector2(-r * 0.8, r * 0.4), p + Vector2(-r * 0.85, -r * 0.45),
				p + Vector2(-r * 0.4, 0), p + Vector2(0, -r * 0.7), p + Vector2(r * 0.4, 0), p + Vector2(r * 0.85, -r * 0.45),
				p + Vector2(r * 0.8, r * 0.4)]), ouro2)
			c.draw_rect(Rect2(p + Vector2(-r * 0.8, r * 0.48), Vector2(r * 1.6, r * 0.25)), Color(0.85, 0.85, 0.95))
		"vento":
			for k in 3:
				var y := (k - 1) * r * 0.5
				var w := r * (1.4 - absf(k - 1) * 0.35)
				c.draw_line(p + Vector2(-r * 0.8, y), p + Vector2(-r * 0.8 + w, y), cor, r * 0.16, true)
				c.draw_arc(p + Vector2(-r * 0.8 + w, y - r * 0.18), r * 0.18, -PI * 0.5, PI * 0.5, 8, cor, r * 0.16, true)
		"carretel":
			c.draw_rect(Rect2(p + Vector2(-r * 0.55, -r * 0.6), Vector2(r * 1.1, r * 1.2)), Color(0.35, 0.65, 1.0))
			for k in 4:
				var y2 := -r * 0.45 + k * r * 0.3
				c.draw_line(p + Vector2(-r * 0.55, y2), p + Vector2(r * 0.55, y2), Color(0.9, 0.95, 1.0, 0.8), r * 0.08)
			c.draw_rect(Rect2(p + Vector2(-r * 0.75, -r * 0.8), Vector2(r * 1.5, r * 0.22)), cor)
			c.draw_rect(Rect2(p + Vector2(-r * 0.75, r * 0.58), Vector2(r * 1.5, r * 0.22)), cor)
		"altura":
			c.draw_colored_polygon(PackedVector2Array([p + Vector2(0, -r * 0.7), p + Vector2(r * 0.65, r * 0.5), p + Vector2(-r * 0.65, r * 0.5)]), cor)
		"pipa":
			var pts := PackedVector2Array([p + Vector2(0, -r), p + Vector2(r * 0.72, -r * 0.2), p + Vector2(0, r * 0.75), p + Vector2(-r * 0.72, -r * 0.2)])
			c.draw_colored_polygon(pts, cor)
			c.draw_line(p + Vector2(0, -r), p + Vector2(0, r * 0.75), Color(0, 0, 0, 0.25), r * 0.06)
			c.draw_line(p + Vector2(-r * 0.72, -r * 0.2), p + Vector2(r * 0.72, -r * 0.2), Color(0, 0, 0, 0.25), r * 0.06)
			c.draw_polyline(PackedVector2Array([p + Vector2(0, r * 0.75), p + Vector2(r * 0.15, r * 1.0), p + Vector2(-r * 0.05, r * 1.2)]), cor, r * 0.07, true)
		"mapa":
			c.draw_circle(p + Vector2(0, -r * 0.2), r * 0.55, Color(0.35, 0.65, 1.0))
			c.draw_colored_polygon(PackedVector2Array([p + Vector2(-r * 0.48, 0), p + Vector2(r * 0.48, 0), p + Vector2(0, r * 0.9)]), Color(0.35, 0.65, 1.0))
			c.draw_circle(p + Vector2(0, -r * 0.2), r * 0.22, AZUL)
		"sol":
			var amarelo := Color(1.0, 0.75, 0.15)
			for k in 8:
				var d2 := Vector2.from_angle(k * TAU / 8.0)
				c.draw_line(p + d2 * r * 0.6, p + d2 * r * 0.95, amarelo, r * 0.14, true)
			c.draw_circle(p, r * 0.45, amarelo)
		"graficos":
			for k in 3:
				var h := r * (0.6 + 0.45 * k)
				c.draw_rect(Rect2(p + Vector2(-r * 0.8 + k * r * 0.58, r * 0.75 - h), Vector2(r * 0.42, h)), Color(0.45, 0.75, 1.0))
		"lab":
			c.draw_colored_polygon(PackedVector2Array([p + Vector2(-r * 0.2, -r * 0.8), p + Vector2(r * 0.2, -r * 0.8), p + Vector2(r * 0.2, -r * 0.2),
				p + Vector2(r * 0.7, r * 0.75), p + Vector2(-r * 0.7, r * 0.75), p + Vector2(-r * 0.2, -r * 0.2)]), cor)
			c.draw_colored_polygon(PackedVector2Array([p + Vector2(-r * 0.42, r * 0.25), p + Vector2(r * 0.42, r * 0.25), p + Vector2(r * 0.6, r * 0.62), p + Vector2(-r * 0.6, r * 0.62)]), Color(0.4, 0.85, 1.0))
		"seta":
			c.draw_colored_polygon(PackedVector2Array([p + Vector2(-r * 0.3, -r * 0.6), p + Vector2(r * 0.35, 0), p + Vector2(-r * 0.3, r * 0.6)]), cor)


## Faixa de pincel atrás das mensagens de combate (bordas irregulares).
static func pincel(c: CanvasItem, centro: Vector2, tam: Vector2, cor: Color, semente := 3) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = semente
	var pts := PackedVector2Array()
	var n := 18
	for i in n + 1:
		var t := float(i) / n
		pts.append(centro + Vector2(lerpf(-tam.x * 0.5, tam.x * 0.5, t), -tam.y * 0.5 + rng.randf_range(-tam.y * 0.12, tam.y * 0.08)))
	pts.append(centro + Vector2(tam.x * 0.5 + tam.y * 0.6, -tam.y * 0.1))
	pts.append(centro + Vector2(tam.x * 0.5 + tam.y * 0.2, tam.y * 0.15))
	for i in n + 1:
		var t2 := 1.0 - float(i) / n
		pts.append(centro + Vector2(lerpf(-tam.x * 0.5, tam.x * 0.5, t2), tam.y * 0.5 + rng.randf_range(-tam.y * 0.08, tam.y * 0.14)))
	pts.append(centro + Vector2(-tam.x * 0.5 - tam.y * 0.7, tam.y * 0.05))
	pts.append(centro + Vector2(-tam.x * 0.5 - tam.y * 0.3, -tam.y * 0.2))
	c.draw_colored_polygon(pts, cor)
	# fios do pincel nas pontas
	for k in 6:
		var y := rng.randf_range(-tam.y * 0.4, tam.y * 0.4)
		var x0 := tam.x * 0.5 + rng.randf_range(0.0, tam.y * 0.4)
		c.draw_line(centro + Vector2(x0, y), centro + Vector2(x0 + rng.randf_range(tam.y * 0.4, tam.y * 1.1), y + rng.randf_range(-6, 6)), cor, rng.randf_range(2.0, 5.0))
		c.draw_line(centro + Vector2(-x0, -y), centro + Vector2(-x0 - rng.randf_range(tam.y * 0.4, tam.y * 1.1), -y + rng.randf_range(-6, 6)), cor, rng.randf_range(2.0, 5.0))
