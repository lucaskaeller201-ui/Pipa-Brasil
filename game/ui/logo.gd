extends Control
## Logo PIPA BRASIL da página inicial (D-095): letras grossas (Luckiest Guy),
## PIPA branca e BRASIL amarela com contorno escuro, pinceladas verde e amarela
## embaixo, a pipa colorida com a linha, e o "Solta · Tenteia · Apára · Briga".

const Visual := preload("res://game/ui/visual.gd")


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	custom_minimum_size = Vector2(560.0, 270.0)
	size = custom_minimum_size


func _process(_delta: float) -> void:
	queue_redraw()


func _letras(texto: String, pos: Vector2, tam: int, cor: Color, cor_sombra: Color) -> void:
	var f := Visual.fonte_titulo()
	draw_string_outline(f, pos + Vector2(5, 7), texto, HORIZONTAL_ALIGNMENT_LEFT, -1, tam, 18, Color(0.02, 0.04, 0.12, 0.55))
	draw_string_outline(f, pos, texto, HORIZONTAL_ALIGNMENT_LEFT, -1, tam, 16, Color(0.03, 0.06, 0.16))
	draw_string(f, pos + Vector2(0, 4), texto, HORIZONTAL_ALIGNMENT_LEFT, -1, tam, cor_sombra)
	draw_string(f, pos, texto, HORIZONTAL_ALIGNMENT_LEFT, -1, tam, cor)


func _draw() -> void:
	var t := Time.get_ticks_msec() / 1000.0
	draw_set_transform(Vector2(20.0, 0.0), -0.07, Vector2.ONE)
	# pinceladas embaixo de BRASIL
	Visual.pincel(self, Vector2(250.0, 200.0), Vector2(330.0, 26.0), Color(0.1, 0.62, 0.22, 0.95), 11)
	Visual.pincel(self, Vector2(262.0, 214.0), Vector2(250.0, 12.0), Color(1.0, 0.82, 0.12, 0.95), 5)
	_letras("PIPA", Vector2(40.0, 108.0), 104, Visual.BRANCO, Color(0.78, 0.84, 0.95))
	_letras("BRASIL", Vector2(84.0, 196.0), 104, Color(1.0, 0.82, 0.1), Color(1.0, 0.55, 0.05))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	# a pipa colorida, balançando no vento, com a linha fazendo curva
	var ang := sin(t * 1.5) * 0.12
	var b := Transform2D(ang - 0.35, Vector2(450.0, 62.0) + Vector2(sin(t * 0.9) * 4.0, cos(t * 1.2) * 3.0))
	var topo := b * Vector2(0.0, -56.0)
	var dir := b * Vector2(44.0, -4.0)
	var baixo := b * Vector2(0.0, 58.0)
	var esq := b * Vector2(-44.0, -4.0)
	var meio := b * Vector2(0.0, -4.0)
	draw_colored_polygon(PackedVector2Array([topo, dir, baixo, esq]), Color(0.03, 0.06, 0.16))
	var k := 0.86
	var tk := meio + (topo - meio) * k
	var dk := meio + (dir - meio) * k
	var bk := meio + (baixo - meio) * k
	var ek := meio + (esq - meio) * k
	draw_colored_polygon(PackedVector2Array([tk, dk, meio]), Color(1.0, 0.82, 0.12))
	draw_colored_polygon(PackedVector2Array([tk, meio, ek]), Color(0.92, 0.15, 0.55))
	draw_colored_polygon(PackedVector2Array([ek, meio, bk]), Color(0.2, 0.55, 0.95))
	draw_colored_polygon(PackedVector2Array([dk, bk, meio]), Color(0.2, 0.75, 0.3))
	draw_line(tk, bk, Color(1, 1, 1, 0.5), 2.0)
	draw_line(ek, dk, Color(1, 1, 1, 0.5), 2.0)
	# linha: sai da pipa e faz uma volta
	var pts := PackedVector2Array()
	for i in 24:
		var s := i / 23.0
		pts.append(baixo + Vector2(-40.0 * s + 60.0 * sin(s * PI * 1.6), 70.0 * s - 30.0 * sin(s * PI)) + Vector2(sin(t * 2.0 + s * 4.0) * 2.0, 0.0))
	draw_polyline(pts, Color(1, 1, 1, 0.9), 2.5, true)
	# slogan
	var slogan := "Solta · Tenteia · Apára · Briga"
	var f := Visual.fonte(780)
	draw_set_transform(Vector2(70.0, 252.0), -0.04, Vector2.ONE)
	draw_string_outline(f, Vector2.ZERO, slogan, HORIZONTAL_ALIGNMENT_LEFT, -1, 28, 9, Color(0.03, 0.06, 0.16))
	draw_string(f, Vector2.ZERO, slogan, HORIZONTAL_ALIGNMENT_LEFT, -1, 28, Visual.BRANCO)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
