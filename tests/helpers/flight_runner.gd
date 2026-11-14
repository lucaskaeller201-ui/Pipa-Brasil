extends RefCounted
## Roda um SimWorld por um tempo e resume o voo. Usado pelos experimentos.

const DT := 1.0 / 120.0  ## mesmo passo fixo do jogo (physics_ticks_per_second)


## Simula `seconds` segundos e devolve estatísticas calculadas a partir de
## `stats_from` segundos (para ignorar a decolagem).
static func run(world: SimWorld, seconds: float, stats_from := 0.0) -> Dictionary:
	var elev: Array[float] = []
	var aoa: Array[float] = []
	var tension: Array[float] = []
	var max_lateral := 0.0
	var max_stretch := 0.0
	var max_excess := 0.0
	var max_speed := 0.0
	var min_elev := INF
	var finite := true
	var steps := roundi(seconds / DT)
	for i in steps:
		world.step(DT)
		if not world.is_finite_state():
			finite = false
			break
		max_speed = maxf(max_speed, world.kite.velocity.length())
		var stretch := world.line_stretch()
		max_stretch = maxf(max_stretch, stretch)
		if world.time >= stats_from:
			# Quanto a linha estica além do que o náilon esticaria com essa tensão.
			max_excess = maxf(max_excess, stretch - 1.0 - world.tension / SimWorld.LINE_STIFFNESS)
			var e := world.elevation_deg()
			elev.append(e)
			aoa.append(world.kite.last_aoa_deg)
			tension.append(world.tension)
			min_elev = minf(min_elev, e)
			max_lateral = maxf(max_lateral, absf(world.lateral_offset()))
	return {
		"finite": finite,
		"elev_mean": _mean(elev),
		"elev_std": _std(elev),
		"elev_min": min_elev,
		"elev_final": world.elevation_deg() if finite else NAN,
		"aoa_mean": _mean(aoa),
		"tension_mean": _mean(tension),
		"max_lateral": max_lateral,
		"max_stretch": max_stretch,
		"max_excess_stretch": max_excess,
		"max_speed": max_speed,
		"final_lateral": world.lateral_offset() if finite else NAN,
	}


static func describe(r: Dictionary) -> String:
	return "elevação %.1f° (±%.2f, mín %.1f) · ataque %.1f° · tensão %.2f N · lateral máx %.2f m · estiramento máx %.4f (excesso %.4f) · vel máx %.2f m/s" % [
		r["elev_mean"], r["elev_std"], r["elev_min"], r["aoa_mean"], r["tension_mean"],
		r["max_lateral"], r["max_stretch"], r["max_excess_stretch"], r["max_speed"]]


static func _mean(a: Array[float]) -> float:
	if a.is_empty():
		return NAN
	var s := 0.0
	for x in a:
		s += x
	return s / a.size()


static func _std(a: Array[float]) -> float:
	if a.is_empty():
		return NAN
	var m := _mean(a)
	var s := 0.0
	for x in a:
		s += (x - m) * (x - m)
	return sqrt(s / a.size())
