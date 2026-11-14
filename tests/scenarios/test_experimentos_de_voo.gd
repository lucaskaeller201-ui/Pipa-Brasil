extends "res://tests/test_case.gd"
## Experimentos de voo da Fase 1 (raia de laboratório, linha de 30 m).
##
## As faixas numéricas vêm do protótipo calibrado (tools/prototipo) e do
## documento de análise. Cada experimento imprime o resumo do voo, para
## acompanhar a evolução da física no log do CI.

const Runner := preload("res://tests/helpers/flight_runner.gd")


func _voo(vento: float, turbulencia := 0.0, semente := 1, definicao: KiteDefinition = null,
		linha := 30.0, azimute := 0.0, subpassos := 4) -> SimWorld:
	var d := definicao if definicao != null else KiteDefinition.raia_laboratorio()
	return SimWorld.create_flight(WindField.new(vento, turbulencia, semente), d, linha, 30.0, azimute, subpassos)


func _log(nome: String, r: Dictionary) -> void:
	print("      [%s] %s" % [nome, Runner.describe(r)])


func test_sem_vento_a_pipa_cai_e_a_linha_deita_sem_tremer() -> void:
	var w := _voo(0.0)
	Runner.run(w, 15.0)
	print("      [sem vento] pipa y %.2f m, vel pipa %.3f m/s, vel máx linha %.3f m/s" % [
		w.kite.position.y, w.kite.velocity.length(), w.line.max_speed()])
	assert_true(w.kite.position.y < 0.6, "a pipa chegou ao chão")
	assert_true(w.kite.velocity.length() < 0.1, "a pipa parou")
	assert_true(w.line.max_speed() < 0.3, "a linha parou de se mexer")


func test_voo_estavel_com_vento_de_5_m_s() -> void:
	var r := Runner.run(_voo(5.0), 25.0, 18.0)
	_log("vento 5 m/s", r)
	assert_true(r["finite"])
	assert_true(r["elev_mean"] > 42.0 and r["elev_mean"] < 56.0, "elevação entre 42° e 56°")
	assert_true(r["elev_std"] < 1.0, "sem oscilação crescente")
	assert_true(r["max_lateral"] < 1.0, "fica no centro da janela de vento")
	assert_true(r["aoa_mean"] > 18.0 and r["aoa_mean"] < 30.0, "ângulo de ataque típico de pipa")
	assert_true(r["tension_mean"] > 2.0 and r["tension_mean"] < 4.0, "tensão de pipa pequena")


func test_tensao_cresce_com_o_quadrado_do_vento() -> void:
	var t3: float = Runner.run(_voo(3.0), 25.0, 18.0)["tension_mean"]
	var t5: float = Runner.run(_voo(5.0), 25.0, 18.0)["tension_mean"]
	var t8: float = Runner.run(_voo(8.0), 25.0, 18.0)["tension_mean"]
	print("      [tensão × vento] 3 m/s: %.2f N · 5 m/s: %.2f N · 8 m/s: %.2f N" % [t3, t5, t8])
	assert_true(t3 < t5 and t5 < t8, "mais vento, mais tensão")
	assert_true(t8 / t5 > 1.8 and t8 / t5 < 3.3, "8/5: %.2f (v² daria 2,56)" % (t8 / t5))
	assert_true(t5 / t3 > 1.8 and t5 / t3 < 3.3, "5/3: %.2f (v² daria 2,78)" % (t5 / t3))


func test_resultado_nao_depende_do_tamanho_do_passo() -> void:
	var a := Runner.run(_voo(5.0, 0.0, 1, null, 30.0, 0.0, 4), 25.0, 18.0)
	var b := Runner.run(_voo(5.0, 0.0, 1, null, 30.0, 0.0, 8), 25.0, 18.0)
	print("      [passo] 4 subpassos: %.2f° %.3f N · 8 subpassos: %.2f° %.3f N" % [
		a["elev_mean"], a["tension_mean"], b["elev_mean"], b["tension_mean"]])
	assert_near(a["elev_mean"], b["elev_mean"], 0.5)
	assert_near(a["tension_mean"], b["tension_mean"], b["tension_mean"] * 0.03)


func test_rabiola_estabiliza_a_raia() -> void:
	var com := Runner.run(_voo(5.0, 0.15), 30.0, 5.0)
	var d_sem := KiteDefinition.raia_laboratorio()
	d_sem.tail_enabled = false
	var sem := Runner.run(_voo(5.0, 0.15, 1, d_sem), 30.0, 5.0)
	_log("com rabiola", com)
	_log("sem rabiola", sem)
	assert_true(com["elev_min"] > 30.0, "com rabiola continua no alto")
	assert_true(sem["elev_min"] < 10.0, "sem rabiola a raia perde o controle e cai")


func test_turbulencia_nao_derruba_a_pipa_com_rabiola() -> void:
	var r := Runner.run(_voo(5.0, 0.15, 2), 40.0, 10.0)
	_log("turbulência", r)
	assert_true(r["finite"])
	assert_true(r["elev_min"] > 30.0)
	assert_true(r["max_lateral"] < 8.0)


func test_pipa_volta_para_o_centro_da_janela() -> void:
	var w := _voo(5.0, 0.0, 1, null, 30.0, 35.0)
	var inicio := absf(w.lateral_offset())
	var r := Runner.run(w, 30.0)
	print("      [retorno ao centro] desvio inicial %.1f m, final %.2f m" % [inicio, absf(r["final_lateral"])])
	assert_true(inicio > 10.0)
	assert_true(absf(r["final_lateral"]) < 1.5)


func test_cabresto_mais_perto_do_bico_reduz_o_angulo_de_ataque() -> void:
	var d1 := KiteDefinition.raia_laboratorio()
	d1.tow_point.y = 0.08
	var d2 := KiteDefinition.raia_laboratorio()
	d2.tow_point.y = 0.14
	var r1 := Runner.run(_voo(5.0, 0.0, 1, d1), 25.0, 18.0)
	var r2 := Runner.run(_voo(5.0, 0.0, 1, d2), 25.0, 18.0)
	_log("cabresto y=0,08", r1)
	_log("cabresto y=0,14", r2)
	assert_true(r1["aoa_mean"] > r2["aoa_mean"] + 3.0, "mais perto do bico: ângulo menor")
	assert_true(r1["elev_mean"] < r2["elev_mean"], "e a pipa sobe mais")


func test_rajada_forte_sem_explosao_numerica() -> void:
	var w := _voo(3.0)
	w.wind.set_gust(10.0, 12.0)
	var r := Runner.run(w, 20.0)
	_log("rajada 3→12 m/s", r)
	assert_true(r["finite"], "nada de NaN ou infinito")
	assert_true(r["max_speed"] < 30.0, "velocidade dentro do físico")
	assert_true(r["max_stretch"] < 1.05, "linha estica menos de 5%")
	assert_true(r["elev_final"] > 35.0, "e a pipa continua voando")


func test_linha_de_100_m_so_estica_o_que_o_nailon_esticaria() -> void:
	# O náilon estica de verdade (T/EA, cerca de 1,5% aqui). O teste mede o
	# excesso, que seria erro numérico: a linha parecendo um elástico.
	var r := Runner.run(_voo(8.0, 0.0, 1, null, 100.0), 30.0, 20.0)
	_log("linha 100 m, vento 8 m/s", r)
	assert_true(r["max_excess_stretch"] < 0.012, "excesso de estiramento menor que 1,2%")


func test_mesma_entrada_mesmo_resultado() -> void:
	var a := _voo(5.0, 0.15, 3)
	var b := _voo(5.0, 0.15, 3)
	Runner.run(a, 5.0)
	Runner.run(b, 5.0)
	assert_eq(a.kite.position, b.kite.position, "simulação determinística")
	assert_eq(a.line.pos[5], b.line.pos[5])
