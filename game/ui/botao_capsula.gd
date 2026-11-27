extends Button
## Botões em cápsula da página inicial (D-095):
## - "jogar": verde, grande, ícone de play e JOGAR (o mais importante da tela);
## - "seletor": azul profundo, ícone, título pequeno + valor, e a setinha ›;
## - "recorde": grafite, troféu, "Meu recorde" + número amarelo.
## Afundam um pouco ao tocar.

const Visual := preload("res://game/ui/visual.gd")

var tipo := "seletor"
var icone_nome := "mapa"
var titulo := ""
var valor := ""
var _apertado := 0.0


func _init(p_tipo := "seletor", p_icone := "mapa", p_titulo := "", p_valor := "") -> void:
	tipo = p_tipo
	icone_nome = p_icone
	titulo = p_titulo
	valor = p_valor
	focus_mode = Control.FOCUS_NONE
	flat = true
	text = ""
	var vazio := StyleBoxEmpty.new()
	for s in ["normal", "hover", "pressed", "focus", "disabled", "hover_pressed"]:
		add_theme_stylebox_override(s, vazio)
	match tipo:
		"jogar":
			custom_minimum_size = Vector2(470.0, 80.0)
		"recorde":
			custom_minimum_size = Vector2(300.0, 66.0)
		_:
			custom_minimum_size = Vector2(176.0, 64.0)
	button_down.connect(func() -> void: _apertado = 1.0)
	add_to_group("botao_livre")


func _process(delta: float) -> void:
	if _apertado > 0.0 and not button_pressed:
		_apertado = maxf(0.0, _apertado - delta * 6.0)
	queue_redraw()


func _capsula(r: Rect2, cor: Color, borda: Color, largura_borda := 2) -> void:
	var sb := StyleBoxFlat.new()
	sb.bg_color = cor
	sb.set_corner_radius_all(int(r.size.y * 0.5))
	sb.border_color = borda
	sb.set_border_width_all(largura_borda)
	sb.anti_aliasing = true
	draw_style_box(sb, r)


func _draw() -> void:
	var k := 1.0 - 0.05 * (1.0 if button_pressed else _apertado)
	var r := Rect2(Vector2.ZERO, size)
	r = r.grow_individual(-size.x * (1.0 - k) * 0.5, -size.y * (1.0 - k) * 0.5, -size.x * (1.0 - k) * 0.5, -size.y * (1.0 - k) * 0.5)
	# sombra
	var sombra := r
	sombra.position.y += 4.0
	_capsula(sombra, Color(0, 0, 0, 0.3), Color(0, 0, 0, 0), 0)
	match tipo:
		"jogar":
			_capsula(r, Visual.VERDE_ESCURO, Color(0.55, 1.0, 0.45, 0.9), 3)
			var cima := Rect2(r.position + Vector2(6.0, 4.0), Vector2(r.size.x - 12.0, r.size.y * 0.55))
			_capsula(cima, Color(0.35, 0.9, 0.3, 0.75), Color(0, 0, 0, 0), 0)
			var meio := Rect2(r.position + Vector2(4.0, r.size.y * 0.35), Vector2(r.size.x - 8.0, r.size.y * 0.55))
			_capsula(meio, Color(0.16, 0.72, 0.16, 0.9), Color(0, 0, 0, 0), 0)
			var f := Visual.fonte_titulo()
			var tam := int(r.size.y * 0.52)
			var w := f.get_string_size("JOGAR", HORIZONTAL_ALIGNMENT_LEFT, -1, tam).x
			var x0 := r.get_center().x - (w + 60.0) * 0.5
			Visual.icone(self, "play", Vector2(x0 + 18.0, r.get_center().y), r.size.y * 0.26, Visual.BRANCO)
			var pos := Vector2(x0 + 60.0, r.get_center().y + tam * 0.36)
			draw_string_outline(f, pos + Vector2(0, 2), "JOGAR", HORIZONTAL_ALIGNMENT_LEFT, -1, tam, 6, Color(0.0, 0.3, 0.05, 0.6))
			draw_string(f, pos, "JOGAR", HORIZONTAL_ALIGNMENT_LEFT, -1, tam, Visual.BRANCO)
		"recorde":
			_capsula(r, Color(0.1, 0.1, 0.13, 0.82), Color(1.0, 0.8, 0.2, 0.5))
			Visual.icone(self, "trofeu", r.position + Vector2(40.0, r.size.y * 0.5), r.size.y * 0.32)
			Visual.texto(self, r.position + Vector2(76.0, r.size.y * 0.42), titulo, 15, Color(0.92, 0.92, 0.95))
			Visual.texto(self, r.position + Vector2(76.0, r.size.y * 0.8), valor, 23, Visual.AMARELO, 780)
			Visual.icone(self, "seta", r.position + Vector2(r.size.x - 26.0, r.size.y * 0.5), 9.0, Color(1, 1, 1, 0.8))
		_:
			_capsula(r, Visual.AZUL, Visual.AZUL_CLARO)
			Visual.icone(self, icone_nome, r.position + Vector2(32.0, r.size.y * 0.5), r.size.y * 0.27)
			Visual.texto(self, r.position + Vector2(60.0, r.size.y * 0.42), titulo, 15, Color(0.9, 0.93, 1.0))
			Visual.texto(self, r.position + Vector2(60.0, r.size.y * 0.78), valor, 18, Visual.BRANCO, 780)
			Visual.icone(self, "seta", r.position + Vector2(r.size.x - 20.0, r.size.y * 0.5), 8.0, Color(1, 1, 1, 0.85))
