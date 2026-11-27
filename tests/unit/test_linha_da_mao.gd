extends "res://tests/test_case.gd"
## D-088: a linha de uma pipa que saiu da mão (5 m) e subiu dando linha tem
## que ter segmentos de tamanho normal (~1,25 m), como a de uma pipa que já
## nasceu no alto — não o dobro de pontos.

const DT := 1.0 / 120.0


func test_linha_solta_da_mao_igual_a_do_alto() -> void:
	# a sua pipa sai da mão (5 m) e sobe pela física, como no jogo
	var modo := FreeMode.new(1, 3, false)
	modo.put_you_on_hand()
	modo.launch_you(5, 2, true)
	var f: Flyer = modo.you()
	var r := 0
	var t := 0.0
	while r == 0 and t < 35.0:
		r = modo.subir(DT)
		modo.update(DT)
		t += DT
	print("      [linha da mão] subiu: r=%d, %.1f s, linha %.1f m, %d pontos" % [r, t, f.line_length(), f.line.size()])
	# depois dá linha até uns 40 m
	t = 0.0
	while f.line_length() < 40.0 and t < 40.0 and modo.world.is_finite_state():
		f.input.haul_speed = -2.0
		modo.update(DT)
		t += DT
	f.input.haul_speed = 0.0
	print("      [linha da mão] %.0f m com %d pontos" % [f.line_length(), f.line.size()])
	# antes (0,6 m por segmento) seriam ~68 pontos; do alto, 32
	assert_true(f.line.size() <= ceili(f.line_length() / SimWorld.TARGET_SEGMENT_LENGTH) + 8, "segmentos de tamanho normal")
	assert_true(modo.world.is_finite_state())
