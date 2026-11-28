extends "res://tests/test_case.gd"
## D-104: a braçada do Lucas no iPhone chega aos pulos (um quadro com o dedo
## andando o dobro, outro parado; o dedo sobe entre uma braçada e outra). A
## puxada que vai para a física tem que sair lisa, e dar linha só corre com a
## pipa puxando (sem linha frouxa sobrando: a barriga).

const Livre := preload("res://game/match/livre.gd")


func test_bracadas_aos_pulos_viram_puxada_lisa() -> void:
	var dt := 1.0 / 60.0
	var e := Vector3.ZERO
	var lo := INF
	var hi := -INF
	var soma := 0.0
	var n := 0
	for k in 180:   # 3 s
		var t := k * dt
		var no_ciclo := fmod(t, 0.2)
		var dedo := 0.0
		if no_ciclo < 0.12:   # 0,12 s puxando, 0,08 s voltando o dedo
			dedo = 12.0 if k % 2 == 0 else 0.0   # toques fora do ritmo: média 6 m/s
		e = Livre.suavizar_puxada(e, dedo, dt)
		var p := e.y
		if t > 0.5:
			lo = minf(lo, p)
			hi = maxf(hi, p)
			soma += p
			n += 1
	var media := soma / n
	print("      [puxada lisa] mín %.2f · média %.2f · máx %.2f m/s" % [lo, media, hi])
	assert_true(lo > 0.55 * media, "sem queda no meio da braçada (mín %.2f, média %.2f)" % [lo, media])
	assert_true(hi < 1.6 * media, "sem pico (máx %.2f, média %.2f)" % [hi, media])
	assert_true(media > 3.0, "a puxada não fica lenta (%.2f m/s)" % media)


## D-106: parou de abraçar, as mãos e a pipa param na hora (0,15 s, o tempo
## da volta do dedo entre braçadas).
func test_parou_de_puxar_a_puxada_para_na_hora() -> void:
	var e := Vector3(6.0, 6.0, 0.0)
	var parou := -1
	for k in 60:
		e = Livre.suavizar_puxada(e, 0.0, 1.0 / 60.0)
		if e.y == 0.0 and parou < 0:
			parou = k + 1
	print("      [parou de abraçar] a puxada parou em %.2f s" % (parou / 60.0))
	assert_true(parou > 0 and parou <= 11, "para em até 0,18 s (%.2f s)" % (parou / 60.0))


func test_mandar_linha_corta_a_puxada_na_hora() -> void:
	assert_eq(Livre.suavizar_puxada(Vector3(6.0, 6.0, 0.0), -2.0, 1.0 / 60.0).y, 0.0)


func test_dar_linha_so_corre_com_a_pipa_puxando() -> void:
	var h := 1.0 / 180.0
	var entrada := PilotInput.new()
	entrada.haul_speed = -3.0
	var frouxa := Pilot.new()
	var d0 := frouxa.update(h, 0.0, entrada, Vector3(0, 0.5, -1).normalized(), 0.0, 30.0)
	var firme := Pilot.new()
	var d1 := firme.update(h, 0.0, entrada, Vector3(0, 0.5, -1).normalized(), 3.0, 30.0)
	assert_near(d0, 0.0, 1e-6, "linha frouxa: não sai linha sobrando")
	assert_near(d1, 3.0 * h, 1e-6, "com pressão: sai no ritmo do dedo")
	entrada.haul_speed = 3.0
	var puxa := Pilot.new()
	assert_near(puxa.update(h, 0.0, entrada, Vector3(0, 0.5, -1).normalized(), 0.0, 30.0), -3.0 * h, 1e-6, "puxar não muda")
