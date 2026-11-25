extends Control
## Desenho 2D de um carretel de linha (D-064), na cor da linha.

var cor := Color.WHITE:
	set(v):
		cor = v
		queue_redraw()
var grossura := 1.0


func _draw() -> void:
	var c := size * 0.5
	var w := minf(size.x, size.y) * 0.55
	var h := w * (0.9 + 0.2 * grossura)
	var aro := Color(0.85, 0.62, 0.35)
	# corpo de linha enrolada, com listrinhas
	draw_rect(Rect2(c.x - w * 0.5, c.y - h * 0.5, w, h), cor)
	for k in 7:
		var y := c.y - h * 0.5 + h * (k + 0.5) / 7.0
		draw_line(Vector2(c.x - w * 0.5, y), Vector2(c.x + w * 0.5, y), cor.darkened(0.25), 1.0)
	# aros de madeira em cima e embaixo
	draw_rect(Rect2(c.x - w * 0.62, c.y - h * 0.5 - 7.0, w * 1.24, 8.0), aro)
	draw_rect(Rect2(c.x - w * 0.62, c.y + h * 0.5 - 1.0, w * 1.24, 8.0), aro)
	draw_rect(Rect2(c.x - w * 0.62, c.y - h * 0.5 - 7.0, w * 1.24, 8.0), aro.darkened(0.3), false, 1.0)
	draw_rect(Rect2(c.x - w * 0.62, c.y + h * 0.5 - 1.0, w * 1.24, 8.0), aro.darkened(0.3), false, 1.0)
