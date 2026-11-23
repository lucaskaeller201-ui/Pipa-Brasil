class_name BotPerception
extends RefCounted
## BotPerception: o que o pipeiro-bot percebe, e só isso.
##
## Lê do próprio pipeiro (Flyer) apenas o que uma pessoa veria ou sentiria:
## onde a pipa está no céu, para onde o bico aponta, a tensão na mão e quanto
## de linha já soltou. Não lê o vento, a velocidade exata nem nada escondido
## (regra do Adendo de Bots). Tudo chega com o atraso e o ruído da dificuldade.

var difficulty: BotDifficulty
var _rng := RandomNumberGenerator.new()
var _buffer: Array = []  # observações recentes (para o atraso de reação)


func _init(p_difficulty: BotDifficulty, seed := 1) -> void:
	difficulty = p_difficulty
	_rng.seed = seed


## Devolve um Dictionary com t, az, el, nose (graus), tension (N), line (m).
func observe(flyer: Flyer, t: float) -> Dictionary:
	var ceu := flyer.sky_position_deg()
	_buffer.append({
		"t": t, "az": ceu.x, "el": ceu.y, "nose": flyer.nose_angle_deg(),
		"tension": flyer.tension, "line": flyer.line_length(),
	})
	while _buffer.size() > 1 and float(_buffer[1]["t"]) <= t - difficulty.reaction:
		_buffer.pop_front()
	var o: Dictionary = (_buffer[0] as Dictionary).duplicate()
	o["az"] = float(o["az"]) + _rng.randfn(0.0, difficulty.noise_deg)
	o["el"] = float(o["el"]) + _rng.randfn(0.0, difficulty.noise_deg)
	o["nose"] = wrapf(float(o["nose"]) + _rng.randfn(0.0, difficulty.noise_deg * 1.5), -180.0, 180.0)
	o["tension"] = maxf(0.0, float(o["tension"]) + _rng.randfn(0.0, difficulty.noise_tension))
	return o
