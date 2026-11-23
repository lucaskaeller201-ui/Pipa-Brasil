extends "res://tests/test_case.gd"
## Fase 5: partida melhor de 3, com bots nos dois lados (a mesma lógica que a
## tela usa, sem a parte visual).

const Setup := preload("res://game/modes/match_setup.gd")
const DT := 1.0 / 120.0


func _factory(semente: int) -> Callable:
	return func(m: MatchRules.Mode, linha: float) -> SimWorld:
		return Setup.create_world(m, linha, semente)


## Roda a partida com dois bots; devolve as regras ao final.
func _jogar(semente: int, limite_s := 420.0) -> MatchRules:
	var regras := MatchRules.new(_factory(semente), ["Bot A", "Bot B"])
	var bots := [BotPilot.new(BotDifficulty.create(BotDifficulty.Level.DIFICIL), semente),
		BotPilot.new(BotDifficulty.create(BotDifficulty.Level.NORMAL), semente + 1)]
	var mundo_atual: SimWorld = null
	var t := 0.0
	while regras.state != MatchRules.State.MATCH_OVER and t < limite_s:
		if regras.world != mundo_atual:
			mundo_atual = regras.world
			for k in 2:
				(bots[k] as BotPilot).line_target = Setup.bot_line_target(regras.mode())
		for k in 2:
			var eu: Flyer = regras.world.flyers[k]
			var outro: Flyer = regras.world.flyers[1 - k]
			if not eu.cut:
				(bots[k] as BotPilot).target_azimuth = Setup.bot_target_azimuth(regras.mode(), eu, outro)
				(bots[k] as BotPilot).update(eu, regras.world.time)
		regras.world.step(DT)
		regras.update(DT)
		for msg in regras.take_messages():
			print("      [partida %d · %5.1f s] %s" % [semente, t, msg])
		t += DT
	return regras


func test_partida_entre_bots_termina_com_vencedor() -> void:
	var regras := _jogar(1)
	assert_eq(regras.state, MatchRules.State.MATCH_OVER, "a partida termina")
	assert_true(regras.match_winner == 0 or regras.match_winner == 1)
	assert_eq(regras.score[regras.match_winner], 2, "quem vence fez 2 pontos")
	assert_true(regras.score[1 - regras.match_winner] <= 1)
	assert_true(regras.round_index == 1 or regras.round_index == 2, "2 ou 3 jogos")
	assert_true(regras.world.is_finite_state())


func test_suba_a_pipa_os_bots_dao_linha_e_alguem_chega_la() -> void:
	var regras := MatchRules.new(_factory(2), ["A", "B"])
	assert_eq(regras.mode(), MatchRules.Mode.SUBA)
	assert_near(regras.world.flyers[0].line_length(), 8.0, 0.5, "começa com linha curta")
	var bots := [BotPilot.new(BotDifficulty.create(BotDifficulty.Level.DIFICIL), 2),
		BotPilot.new(BotDifficulty.create(BotDifficulty.Level.DIFICIL), 3)]
	for k in 2:
		(bots[k] as BotPilot).line_target = Setup.bot_line_target(MatchRules.Mode.SUBA)
	var t := 0.0
	while regras.state != MatchRules.State.ROUND_OVER and regras.state != MatchRules.State.MATCH_OVER and t < 100.0:
		for k in 2:
			(bots[k] as BotPilot).update(regras.world.flyers[k], regras.world.time)
		regras.world.step(DT)
		regras.update(DT)
		t += DT
	var alturas := [regras.altitude(0), regras.altitude(1)]
	print("      [suba a pipa] terminou em %.1f s; alturas %.1f m e %.1f m; linhas %.1f m e %.1f m" % [
		t, alturas[0], alturas[1], regras.world.flyers[0].line_length(), regras.world.flyers[1].line_length()])
	assert_true(regras.last_round_winner >= 0, "o jogo 1 teve vencedor")
	assert_true(maxf(alturas[0], alturas[1]) >= MatchRules.ALTURA_SUBA - 1.0, "alguém chegou a 30 m")
	assert_true(regras.world.flyers[0].line_length() > 30.0, "o bot deu linha para subir")


func test_sem_corte_nao_desgasta_e_valendo_corte_desgasta() -> void:
	var regras := MatchRules.new(_factory(3), ["A", "B"])
	assert_eq(regras.world.combat.wear_rate, 0.0, "jogo 1: sem desgaste")
	regras.round_index = 2
	regras._start_round()
	assert_eq(regras.mode(), MatchRules.Mode.VALENDO_CORTE)
	assert_eq(regras.world.combat.wear_rate, MatchRules.WEAR_RATE, "jogo 3: valendo corte")
	assert_near(regras.world.flyers[0].hand_position.y, 6.0 + 1.2, 0.3, "o pipeiro está em cima da laje")
