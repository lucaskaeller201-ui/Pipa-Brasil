extends "res://tests/test_case.gd"
## D-082: quanto custa um passo da física no jogo (7 pipas, cenário com
## obstáculos). No iPhone (WebAssembly, um núcleo) costuma ser 2–3× mais
## lento que no computador do CI. Só mede e imprime; o limite é folgado.

const DT := 1.0 / 120.0


func test_custo_do_passo_da_fisica() -> void:
	var B = load("res://game/world/bairro.gd")
	var raiz := Node3D.new()
	var modo := FreeMode.new(6, 7, true)
	B.criar(raiz, modo.players.size(), 7)
	modo.world.obstacles = B.obstaculos
	for k in roundi(8.0 / DT):
		modo.update(DT)
	var partes := {"total": 0, "sem obstáculos": 0}
	modo.world.medir = true
	var t0 := Time.get_ticks_usec()
	for k in 600:
		modo.update(DT)
	partes["total"] = Time.get_ticks_usec() - t0
	modo.world.medir = false
	var fisica := 0
	for k in modo.world.perfil:
		fisica += int(modo.world.perfil[k])
	for k in modo.world.perfil:
		print("      [desempenho] %s: %.2f ms por passo" % [k, float(modo.world.perfil[k]) / 600.0 / 1000.0])
	print("      [desempenho] fora da física (bots, modo): %.2f ms por passo" % [float(partes["total"] - fisica) / 600.0 / 1000.0])
	var obs = modo.world.obstacles
	modo.world.obstacles = null
	t0 = Time.get_ticks_usec()
	for k in 600:
		modo.update(DT)
	partes["sem obstáculos"] = Time.get_ticks_usec() - t0
	modo.world.obstacles = obs
	var por_passo := float(partes["total"]) / 600.0 / 1000.0
	var sem := float(partes["sem obstáculos"]) / 600.0 / 1000.0
	var particulas := 0
	for f in modo.world.flyers:
		for c in (f as Flyer).chains():
			particulas += (c as ParticleChain).pos.size()
	print("      [desempenho] um passo de física (1/120 s): %.2f ms (sem obstáculos %.2f ms); %d pipas, %d pontos de linha/rabiola" % [por_passo, sem, modo.world.flyers.size(), particulas])
	print("      [desempenho] por segundo de jogo: %.0f ms de física (no celular, uns %.0f–%.0f ms)" % [por_passo * 120.0, por_passo * 240.0, por_passo * 360.0])
	assert_true(por_passo < 20.0, "passo de física razoável")
	raiz.free()
