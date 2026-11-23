class_name BotDifficulty
extends RefCounted
## Dificuldade do bot: capacidade de EXECUÇÃO (não muda a física).
## Mexe só na percepção (atraso e ruído) e na precisão das decisões.
## A personalidade (estilo de comportamento) é independente e vem na Fase 8.

enum Level { FACIL, NORMAL, DIFICIL, PROFISSIONAL }

var level: Level = Level.NORMAL
var reaction := 0.2         ## s: atraso entre ver e reagir
var noise_deg := 4.0        ## ruído na leitura da posição e do bico (graus)
var noise_tension := 0.25   ## ruído na tensão sentida na mão (N)
var tolerance_deg := 16.0   ## quanto o bico pode estar fora da direção desejada
var lead := 0.08            ## s: quanto o bot antecipa o giro do bico
var decisions_per_second := 15.0


static func create(p_level: Level) -> BotDifficulty:
	var d := BotDifficulty.new()
	d.level = p_level
	match p_level:
		Level.FACIL:
			d._configure(0.30, 6.0, 0.4, 22.0, 0.05, 10.0)
		Level.NORMAL:
			d._configure(0.20, 4.0, 0.25, 16.0, 0.08, 15.0)
		Level.DIFICIL:
			d._configure(0.12, 2.0, 0.1, 12.0, 0.10, 30.0)
		Level.PROFISSIONAL:
			d._configure(0.08, 1.0, 0.05, 9.0, 0.12, 60.0)
	return d


static func level_name(p_level: Level) -> String:
	return ["Fácil", "Normal", "Difícil", "Profissional"][p_level]


func _configure(p_reaction: float, p_noise_deg: float, p_noise_tension: float, p_tolerance: float,
		p_lead: float, p_decisions: float) -> void:
	reaction = p_reaction
	noise_deg = p_noise_deg
	noise_tension = p_noise_tension
	tolerance_deg = p_tolerance
	lead = p_lead
	decisions_per_second = p_decisions
