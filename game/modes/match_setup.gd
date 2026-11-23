extends RefCounted
## Monta o mundo de cada jogo da partida: duas lajes, duas raias sem rabiola,
## vento de fim de tarde com turbulência. Usado pela cena e pelos testes.

const Bairro := preload("res://game/world/bairro.gd")

const APELIDOS := ["Tião do Morro", "Biel Rabiola", "Nando Carretilha", "Dudu Desbica", "Kiko da Esquina", "Lelo Relo"]


static func create_world(mode: MatchRules.Mode, line_length: float, semente: int) -> SimWorld:
	var w := SimWorld.new()
	w.wind = WindField.new(5.0, 0.15, semente)
	var elevacao := 45.0 if line_length < 15.0 else 30.0
	var laje := Vector3(0.0, Bairro.ALTURA_LAJE, 0.0)
	w.add_flyer(KiteDefinition.raia_sem_rabiola(), laje, line_length, elevacao, 0.0, true, 3.0)
	w.add_flyer(KiteDefinition.raia_sem_rabiola(), laje + Bairro.LAJE_RIVAL, line_length, elevacao, 0.0, true, 3.0)
	return w


## Quanta linha o bot procura ter em cada jogo.
static func bot_line_target(mode: MatchRules.Mode) -> float:
	match mode:
		MatchRules.Mode.SUBA:
			return 45.0
		MatchRules.Mode.MAIS_ALTA:
			return 80.0
		_:
			return 30.0


## Para onde o bot mira: no jogo valendo corte, vai atrás da pipa do outro.
static func bot_target_azimuth(mode: MatchRules.Mode, me: Flyer, other: Flyer) -> float:
	if mode != MatchRules.Mode.VALENDO_CORTE or other.cut:
		return 0.0
	var alvo := other.kite.position - me.hand_position
	return rad_to_deg(atan2(alvo.x, -alvo.z))
