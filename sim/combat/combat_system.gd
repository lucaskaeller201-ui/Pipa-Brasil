class_name KiteCombatSystem
extends RefCounted
## Combate virtual entre linhas. Extensão do núcleo físico, não um sistema à
## parte: usa as mesmas linhas, pipas e vento do voo normal.
##
## A cada subpasso, encontra os pares de segmentos próximos de pipeiros
## diferentes, resolve o contato (as linhas se dobram uma na outra) e acumula
## um desgaste virtual proporcional à força de contato e ao deslizamento.
## Quando o desgaste de um segmento passa da resistência da linha, ela rompe:
## o pedaço da mão fica com o pipeiro e a pipa sai avoada com o resto.
##
## Nada aqui descreve materiais cortantes reais; "desgaste" e "resistência"
## são grandezas do jogo.

const CONTACT_RADIUS := 0.02   ## m: distância em que duas linhas se tocam
const CONTACT_ITERATIONS := 2  ## passadas do solver de contato por subpasso

var enabled := true
var wear_rate := 1.0           ## desgaste por (N · m/s · s), no ponto de contato
## Eventos desde o último `take_events()`: dicionários com "type" e dados.
var events: Array = []

var _pairs: Array = []
var _chains: Array = []
var _groups := PackedInt32Array()
var _owners: Array = []
var contacts_last_step := 0
var max_contact_force := 0.0


## Reúne as cadeias de todos os pipeiros (e pedaços soltos) e resolve contatos.
func solve(flyers: Array, loose: Array, h: float) -> void:
	if not enabled:
		return
	_chains.clear()
	_owners.clear()
	_groups.clear()
	for f in flyers:
		var fl: Flyer = f
		for c in fl.chains():
			_chains.append(c)
			_owners.append(fl)
			_groups.append(fl.id)
	for c in loose:
		_chains.append(c)
		_owners.append(null)
		_groups.append(-1 - _groups.size())  # pedaços soltos colidem com tudo
	if _chains.size() < 2:
		contacts_last_step = 0
		return
	_pairs = LineContact.find_pairs(_chains, _groups, CONTACT_RADIUS * 2.0)
	contacts_last_step = 0
	max_contact_force = 0.0
	for it in CONTACT_ITERATIONS:
		for p in _pairs:
			var a: ParticleChain = _chains[p[0]]
			var b: ParticleChain = _chains[p[2]]
			var force := LineContact.solve_pair(a, p[1], b, p[3], CONTACT_RADIUS, h, wear_rate if it == 0 else 0.0)
			if force > 0.0 and it == 0:
				contacts_last_step += 1
				max_contact_force = maxf(max_contact_force, force)


## Verifica rupturas. Chamar uma vez por subpasso, depois de `solve`.
func check_breaks(flyers: Array, loose: Array) -> void:
	if not enabled:
		return
	for f in flyers:
		var fl: Flyer = f
		if fl.cut or fl.line == null:
			continue
		if fl.line.max_wear() >= fl.line.strength:
			var seg := fl.line.weakest_segment()
			var onde := fl.line.pos[seg].lerp(fl.line.pos[seg + 1], 0.5)
			fl.cut_line(seg)
			events.append({"type": "ruptura", "flyer": fl.id, "segment": seg, "position": onde})
	# Rabiolas e pedaços soltos também podem romper (menos importante por ora).
	for c in loose.duplicate():
		var ch: ParticleChain = c
		if ch.max_wear() >= ch.strength and ch.pos.size() > 3:
			var seg := ch.weakest_segment()
			var resto := ch.split(seg)
			loose.append(resto)
			events.append({"type": "pedaco", "segment": seg})


func take_events() -> Array:
	var e := events
	events = []
	return e
