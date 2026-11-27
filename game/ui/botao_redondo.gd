extends Button
## Botão redondo com ícone (D-094): azul profundo, borda clara, afunda ao tocar.
## estilo "alto": o COLOCAR NO ALTO — maior, aro amarelo iluminado, pipa e texto.

const Visual := preload("res://game/ui/visual.gd")

var icone_nome := "engrenagem"
var estilo := "normal"
var legenda := ""
var _apertado := 0.0


func _init(p_icone := "engrenagem", p_estilo := "normal", p_legenda := "") -> void:
	icone_nome = p_icone
	estilo = p_estilo
	legenda = p_legenda
	focus_mode = Control.FOCUS_NONE
	flat = true
	text = ""
	var vazio := StyleBoxEmpty.new()
	for s in ["normal", "hover", "pressed", "focus", "disabled", "hover_pressed"]:
		add_theme_stylebox_override(s, vazio)
	var lado := 150.0 if estilo == "alto" else 62.0
	custom_minimum_size = Vector2(lado, lado)
	size = custom_minimum_size
	button_down.connect(func() -> void: _apertado = 1.0)
	add_to_group("botao_livre")


func _process(delta: float) -> void:
	if _apertado > 0.0 and not button_pressed:
		_apertado = maxf(0.0, _apertado - delta * 6.0)
	queue_redraw()


func _draw() -> void:
	var c := size * 0.5
	var r := minf(size.x, size.y) * 0.5 - 3.0
	var k := 1.0 - 0.08 * (1.0 if button_pressed else _apertado)
	r *= k
	if estilo == "alto":
		# brilho amarelo pulsando em volta
		var t := Time.get_ticks_msec() / 1000.0
		var pulso := 0.5 + 0.5 * sin(t * 3.0)
		for i in 5:
			c_draw_circle(c, r + 2.0 + i * 3.0, Color(1.0, 0.75, 0.1, (0.18 - i * 0.03) * (0.6 + 0.4 * pulso)))
		draw_circle(c, r, Color(0.06, 0.06, 0.1, 0.92))
		draw_arc(c, r - 4.0, 0.0, TAU, 64, Visual.AMARELO, 7.0, true)
		draw_arc(c, r - 4.0, -PI * 0.9, -PI * 0.3, 24, Color(1.0, 0.95, 0.7), 3.0, true)
		Visual.icone(self, "pipa", c + Vector2(0, -r * 0.3), r * 0.28, Visual.BRANCO)
		var linhas := legenda.split("\n")
		var tam := int(r * 0.22)
		for i in linhas.size():
			var w := Visual.largura(linhas[i], tam, 780)
			Visual.texto(self, c + Vector2(-w * 0.5, r * 0.22 + i * tam * 1.05), linhas[i], tam, Visual.BRANCO, 780)
		return
	draw_circle(c + Vector2(0, 2), r, Color(0, 0, 0, 0.25))
	draw_circle(c, r, Visual.AZUL)
	draw_arc(c, r - 1.0, 0.0, TAU, 48, Visual.AZUL_CLARO, 2.0, true)
	Visual.icone(self, icone_nome, c, r * 0.5, Visual.BRANCO)


func c_draw_circle(c: Vector2, r: float, cor: Color) -> void:
	draw_circle(c, r, cor)
