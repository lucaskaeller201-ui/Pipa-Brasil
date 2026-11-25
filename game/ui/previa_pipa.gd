extends Control
## Desenho 2D de uma pipa do catálogo (D-064): formato pelas medidas do
## pipeiro, estampa e varetas. Usado nas telas de escolha.

const Estilos := preload("res://game/views/estilos_pipa.gd")

var estilo: Dictionary = {}:
	set(v):
		estilo = v
		queue_redraw()


func _draw() -> void:
	if estilo.is_empty():
		return
	var m: Array = estilo["m"]
	var area := size
	var escala := minf((area.y - 10.0) / float(m[0]), (area.x - 10.0) / maxf(float(m[1]), float(m[2])))
	var cx := area.x * 0.5
	var y0 := (area.y - float(m[0]) * escala) * 0.5
	var ys := [0.0, float(m[3]), float(m[3]) + float(m[4]), float(m[0])]
	var ws := [0.0, float(m[1]) * 0.5, float(m[2]) * 0.5, 0.0]
	var tb := float(m[3]) / float(m[0])
	var tc := (float(m[3]) + float(m[4])) / float(m[0])
	var meia := maxf(float(m[1]), float(m[2])) * 0.5
	var aberto := Estilos.aberto(estilo)
	var faixas := [8, 8, 8]
	for fx in range(1 if aberto else 0, 3):
		if float(ys[fx + 1]) - float(ys[fx]) < 0.01:
			continue
		for j in faixas[fx]:
			var ya := lerpf(float(ys[fx]), float(ys[fx + 1]), j / float(faixas[fx]))
			var yb := lerpf(float(ys[fx]), float(ys[fx + 1]), (j + 1) / float(faixas[fx]))
			var wa := lerpf(float(ws[fx]), float(ws[fx + 1]), j / float(faixas[fx]))
			var wb := lerpf(float(ws[fx]), float(ws[fx + 1]), (j + 1) / float(faixas[fx]))
			for i in 14:
				var u0 := lerpf(-1.0, 1.0, i / 14.0)
				var u1 := lerpf(-1.0, 1.0, (i + 1) / 14.0)
				var cxm := (u0 + u1) * 0.25 * (wa + wb)
				var cor := Estilos.cor(estilo, cxm / meia, (ya + yb) * 0.5 / float(m[0]), tb, tc)
				var pts := PackedVector2Array([
					Vector2(cx + u0 * wa * escala, y0 + ya * escala), Vector2(cx + u1 * wa * escala, y0 + ya * escala),
					Vector2(cx + u1 * wb * escala, y0 + yb * escala), Vector2(cx + u0 * wb * escala, y0 + yb * escala)])
				if wa < 0.001:
					pts = PackedVector2Array([pts[0], pts[2], pts[3]])
				elif wb < 0.001:
					pts = PackedVector2Array([pts[0], pts[1], pts[2]])
				draw_colored_polygon(pts, cor)
	var topo := Vector2(cx, y0)
	var ys1: float = y0 + float(ys[1]) * escala
	var ws1: float = float(ws[1]) * escala
	if aberto:
		draw_line(topo, Vector2(cx - ws1, ys1), Color(0.95, 0.95, 0.95), 1.5)
		draw_line(topo, Vector2(cx + ws1, ys1), Color(0.95, 0.95, 0.95), 1.5)
	var marrom := Color(0.35, 0.22, 0.1, 0.8)
	draw_line(topo, Vector2(cx, y0 + float(m[0]) * escala), marrom, 1.5)
	for k in [1, 2]:
		var y: float = y0 + float(ys[k]) * escala
		draw_line(Vector2(cx - float(ws[k]) * escala, y), Vector2(cx + float(ws[k]) * escala, y), marrom, 1.5)
