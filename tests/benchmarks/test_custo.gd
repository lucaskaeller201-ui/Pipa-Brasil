extends "res://tests/test_case.gd"
## Custo de processamento da física. O número aparece no log do CI.
## O limite aqui é largo: o orçamento real será medido no celular.


func test_custo_de_uma_pipa_com_linha_de_30_m() -> void:
	var w := SimWorld.create_flight(WindField.new(5.0, 0.15, 1), KiteDefinition.raia_laboratorio(), 30.0)
	var inicio := Time.get_ticks_usec()
	for i in 1200:  # 10 s simulados
		w.step(1.0 / 120.0)
	var ms_por_segundo := (Time.get_ticks_usec() - inicio) / 1000.0 / 10.0
	print("      [custo] %.1f ms de CPU por segundo simulado (%.1f%% de um núcleo)" % [ms_por_segundo, ms_por_segundo / 10.0])
	assert_true(ms_por_segundo < 500.0, "no servidor do CI, menos de metade de um núcleo")
