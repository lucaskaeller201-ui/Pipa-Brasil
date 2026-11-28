extends "res://tests/test_case.gd"
## Fase 2: os comandos do pipeiro mudam a física (mão e carretilha), não animações.
## Raia com rabiola, vento de 5 m/s, linha de 30 m, voo já estabilizado.
## Faixas calibradas no protótipo (tools/prototipo/sim_prototipo_fase2.py).

const DT := 1.0 / 120.0


func _voo_estavel() -> SimWorld:
	var w := SimWorld.create_flight(WindField.new(5.0), KiteDefinition.raia_laboratorio(), 30.0, 30.0, 0.0, 4, true)
	_rodar(w, 15.0)
	return w


## Roda com a entrada atual; devolve [tensão máx, tensão mín, tensão média, velocidade máx da pipa].
func _rodar(w: SimWorld, segundos: float) -> Array:
	var tmax := 0.0
	var tmin := INF
	var tsoma := 0.0
	var vmax := 0.0
	var n := roundi(segundos / DT)
	for i in n:
		w.step(DT)
		tmax = maxf(tmax, w.tension)
		tmin = minf(tmin, w.tension)
		tsoma += w.tension
		vmax = maxf(vmax, w.kite.velocity.length())
	return [tmax, tmin, tsoma / n, vmax]


func test_voo_com_piloto_parado_continua_estavel() -> void:
	var w := _voo_estavel()
	var e0 := w.elevation_deg()
	var r := _rodar(w, 3.0)
	print("      [piloto parado] elevação %.1f°, tensão %.2f N" % [e0, r[2]])
	assert_true(e0 > 42.0 and e0 < 56.0)
	assert_true(r[3] < 0.5, "a pipa fica parada no céu")


func test_puxao_aumenta_tensao_e_velocidade() -> void:
	var w := _voo_estavel()
	var e0 := w.elevation_deg()
	w.trigger(Pilot.Impulse.PUXAO)
	var r := _rodar(w, 1.5)
	print("      [puxão] tensão máx %.2f N, velocidade máx %.2f m/s, elevação %.1f° → %.1f°" % [r[0], r[3], e0, w.elevation_deg()])
	assert_true(r[0] > 6.0, "pico de tensão")
	assert_true(r[3] > 3.0, "a pipa arranca")
	assert_true(w.elevation_deg() > e0 - 0.5, "não derruba a pipa")


func test_arrancao_e_mais_forte_que_o_puxao() -> void:
	var a := _voo_estavel()
	a.trigger(Pilot.Impulse.PUXAO)
	var ra := _rodar(a, 1.5)
	var b := _voo_estavel()
	b.trigger(Pilot.Impulse.ARRANCAO)
	var rb := _rodar(b, 1.5)
	print("      [arrancão] tensão máx %.2f N (puxão %.2f), velocidade máx %.2f m/s (puxão %.2f)" % [rb[0], ra[0], rb[3], ra[3]])
	assert_true(rb[0] > ra[0] * 1.2)
	assert_true(rb[3] > ra[3])


func test_desbicar_da_folga_e_depois_puxa() -> void:
	var w := _voo_estavel()
	w.trigger(Pilot.Impulse.DESBICAR)
	var r := _rodar(w, 1.5)
	print("      [desbicar] tensão mín %.2f N, máx %.2f N" % [r[1], r[0]])
	assert_true(r[1] < 0.5, "a linha fica frouxa")
	assert_true(r[0] > 6.0, "e depois vem o puxão")


func test_dar_linha_solta_linha_com_freio() -> void:
	var w := _voo_estavel()
	var l0 := w.line_length()
	var e0 := w.elevation_deg()
	w.input.pay_out = true
	_rodar(w, 3.0)
	var ganho := w.line_length() - l0
	print("      [dar linha 3 s] +%.1f m, elevação %.1f° → %.1f°" % [ganho, e0, w.elevation_deg()])
	assert_true(ganho > 3.0 and ganho < 9.0, "no máximo 2 m/s")
	assert_true(w.elevation_deg() < e0, "a pipa se afasta e desce")


func test_largar_solta_mais_que_dar_linha() -> void:
	var a := _voo_estavel()
	var la := a.line_length()
	a.input.pay_out = true
	_rodar(a, 3.0)
	var b := _voo_estavel()
	var lb := b.line_length()
	b.input.free_spool = true
	var r := _rodar(b, 3.0)
	print("      [largar 3 s] +%.1f m (dar linha: +%.1f m), tensão média %.2f N" % [b.line_length() - lb, a.line_length() - la, r[2]])
	assert_true(b.line_length() - lb > a.line_length() - la)
	assert_true(r[2] < 1.0, "carretilha livre: quase sem tensão")


func test_recolher_enrola_linha_e_a_pipa_sobe() -> void:
	var w := _voo_estavel()
	var l0 := w.line_length()
	var e0 := w.elevation_deg()
	w.input.reel_in = true
	_rodar(w, 3.0)
	var perda := l0 - w.line_length()
	print("      [recolher 3 s] −%.1f m, elevação %.1f° → %.1f°" % [perda, e0, w.elevation_deg()])
	assert_true(perda > 3.0 and perda < 4.0, "1,2 m/s")
	assert_true(w.elevation_deg() > e0 + 3.0)


func test_afrouxar_reduz_e_puxar_aumenta_a_tensao() -> void:
	var a := _voo_estavel()
	var t0 := a.tension
	a.input.slack = 1.0
	var ra := _rodar(a, 1.0)
	var b := _voo_estavel()
	var e0 := b.elevation_deg()
	b.input.pull = 1.0
	var rb := _rodar(b, 1.0)
	print("      [afrouxar] tensão média %.2f N · [puxar] %.2f N (antes %.2f N)" % [ra[2], rb[2], t0])
	assert_true(ra[2] < t0 * 0.9)
	assert_true(rb[2] > t0 * 1.15)
	assert_true(b.elevation_deg() > e0, "puxando, a pipa sobe")


func test_linha_nunca_fica_menor_que_o_minimo() -> void:
	var w := SimWorld.create_flight(WindField.new(5.0), KiteDefinition.raia_laboratorio(), 8.0, 30.0, 0.0, 4, true)
	w.input.reel_in = true
	_rodar(w, 5.0)
	assert_true(w.line_length() >= Pilot.MIN_LINE - 0.01, "comprimento %.2f m" % w.line_length())
	assert_true(w.is_finite_state())


func test_comprimento_variavel_mantem_os_nos_consistentes() -> void:
	var w := _voo_estavel()
	w.input.free_spool = true
	_rodar(w, 2.0)
	w.input.clear()
	w.input.reel_in = true
	_rodar(w, 4.0)
	var c := w.line
	assert_eq(c.pos.size(), c.rest.size() + 1)
	assert_eq(c.pos.size(), c.inv_mass.size())
	assert_near(c.rest_total(), w.line_length(), 1e-6)
	for i in c.rest.size():
		assert_true(c.rest[i] > 0.04 and c.rest[i] < c.rest_length * 1.51, "segmento %d: %.3f m" % [i, c.rest[i]])


## Gesto de deslizar para baixo: a mão puxa linha no ritmo do dedo.
func test_puxar_linha_com_a_mao_encurta_e_acelera() -> void:
	var w := _voo_estavel()
	var l0 := w.line_length()
	w.input.haul_speed = 3.0
	var r := _rodar(w, 1.0)
	w.input.clear()
	print("      [puxar com a mão 3 m/s, 1 s] linha %.1f → %.1f m, tensão máx %.2f N, velocidade máx %.1f m/s" % [l0, w.line_length(), r[0], r[3]])
	assert_near(l0 - w.line_length(), 3.0, 0.1, "recolheu 3 m em 1 s")
	assert_true(r[3] > 2.0, "a pipa ganha velocidade")


## Gesto de deslizar para cima: dá linha no ritmo do dedo enquanto a pipa
## puxa (D-104: com a linha frouxa ela não sai sobrando).
func test_dar_linha_com_a_mao_alonga() -> void:
	var w := _voo_estavel()
	var l0 := w.line_length()
	w.input.haul_speed = -2.0
	var r := _rodar(w, 2.0)
	w.input.clear()
	print("      [dar linha 2 m/s, 2 s] linha %.1f → %.1f m, tensão máx %.2f N" % [l0, w.line_length(), r[0]])
	assert_true(w.line_length() - l0 > 2.0, "a pipa levou linha (%.1f m)" % (w.line_length() - l0))
	assert_true(w.line_length() - l0 <= 4.0 + 0.05, "nunca mais que o dedo deu")
	w.input.haul_speed = -50.0
	_rodar(w, 1.0)
	assert_true(w.line_length() - l0 <= 4.0 + Pilot.HAUL_MAX_SPEED + 0.1, "a mão tem velocidade máxima")
	assert_true(w.is_finite_state())
