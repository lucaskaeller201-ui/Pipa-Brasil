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
## Aparar ("manda busca"): quando a linha ou a rabiola de uma pipa avoada
## encosta na linha ou na rabiola de um pipeiro, ela enrosca (uma ligação no
## ponto de contato, presa ao material da linha de quem aparou). Recolhendo,
## o ponto enroscado vem com a linha até a mão: pipa aparada. Se a avoada
## chega ao chão sem ninguém aparar, é pipa perdida.
##
## Nada aqui descreve materiais cortantes reais; "desgaste" e "resistência"
## são grandezas do jogo.

const CONTACT_RADIUS := 0.02   ## m: distância em que duas linhas se tocam
const CONTACT_ITERATIONS := 2  ## passadas do solver de contato por subpasso

var enabled := true
var wear_rate := 1.0           ## desgaste por (N · m/s · s), no ponto de contato
## Eventos desde o último `take_events()`: dicionários com "type" e dados.
var events: Array = []

const CAPTURE_DISTANCE := 3.0  ## m da mão em que a pipa enroscada é considerada aparada

## Enroscos ativos. Cada um: {"avoada": Flyer, "chain": ParticleChain (da
## avoada), "idx": int (partícula enroscada), "catcher": Flyer, "cchain":
## ParticleChain (linha ou rabiola de quem aparou), "m": float (coordenada no
## material de cchain), "captured": bool}
var links: Array = []

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
				_maybe_snag(p[0], p[1], p[2], p[3])
		_solve_links()


## Se uma das cadeias é de uma pipa avoada livre e a outra é a linha ou a
## rabiola de um pipeiro em voo, cria o enrosco no ponto de contato.
func _maybe_snag(ia: int, i: int, ib: int, j: int) -> void:
	for ordem in 2:
		var av_idx := ia if ordem == 0 else ib
		var av_seg := i if ordem == 0 else j
		var ct_idx := ib if ordem == 0 else ia
		var ct_seg := j if ordem == 0 else i
		var av: Flyer = _owners[av_idx]
		var ct: Flyer = _owners[ct_idx]
		if av == null or ct == null or not av.cut or av.caught_by != null or av.lost or ct.cut:
			continue
		var chain: ParticleChain = _chains[av_idx]
		var cchain: ParticleChain = _chains[ct_idx]
		if not (chain == av.trailing_line or chain == av.tail):
			continue
		if not (cchain == ct.line or cchain == ct.tail):
			continue
		var st := LineContact.closest_params(chain.pos[av_seg], chain.pos[av_seg + 1], cchain.pos[ct_seg], cchain.pos[ct_seg + 1])
		var idx := av_seg if st.x < 0.5 else av_seg + 1
		links.append({"avoada": av, "chain": chain, "idx": idx, "catcher": ct, "cchain": cchain,
			"m": cchain.material_coordinate(ct_seg, st.y), "captured": false})
		av.caught_by = ct
		ct.holding += 1
		events.append({"type": "enroscou", "flyer": av.id, "catcher": ct.id,
			"by_tail": cchain == ct.tail})
		return


## Mantém cada ponto enroscado preso ao seu lugar no material da outra linha.
func _solve_links() -> void:
	for l in links:
		var chain: ParticleChain = l["chain"]
		var cchain: ParticleChain = l["cchain"]
		var idx: int = l["idx"]
		var loc := cchain.locate_material(float(l["m"]))
		var seg := int(loc.x)
		var s := loc.y
		var p := cchain.pos[seg].lerp(cchain.pos[seg + 1], s)
		var d := chain.pos[idx] - p
		var dist := d.length()
		if dist < 1e-9:
			continue
		var n := d / dist
		var wq := chain.inv_mass[idx]
		var wp := cchain.inv_mass[seg] * (1.0 - s) * (1.0 - s) + cchain.inv_mass[seg + 1] * s * s
		if wq + wp < 1e-12:
			continue
		var dl := -dist / (wq + wp)
		chain.pos[idx] += n * (wq * dl)
		cchain.pos[seg] -= n * (cchain.inv_mass[seg] * (1.0 - s) * dl)
		cchain.pos[seg + 1] -= n * (cchain.inv_mass[seg + 1] * s * dl)


## Pipa aparada (chegou na mão), pipa perdida (chão) e enroscos desfeitos.
func check_snags(flyers: Array) -> void:
	for l in links.duplicate():
		var av: Flyer = l["avoada"]
		var ct: Flyer = l["catcher"]
		var cchain: ParticleChain = l["cchain"]
		if ct.cut or (cchain != ct.line and cchain != ct.tail):
			# quem aparou teve a linha cortada: a avoada se solta de novo
			links.erase(l)
			av.caught_by = null
			ct.holding = maxi(0, ct.holding - 1)
			continue
		if bool(l["captured"]):
			continue
		var loc := cchain.locate_material(float(l["m"]))
		var p := cchain.pos[int(loc.x)].lerp(cchain.pos[int(loc.x) + 1], loc.y)
		var na_mao := p.distance_to(ct.hand_position) < CAPTURE_DISTANCE
		if cchain == ct.line and float(l["m"]) >= cchain.rest_total() - 0.3:
			na_mao = true
		if na_mao:
			l["captured"] = true
			av.captured = true
			ct.holding = maxi(0, ct.holding - 1)
			ct.catches += 1
			events.append({"type": "aparada", "flyer": av.id, "catcher": ct.id})
	for f in flyers:
		var fl: Flyer = f
		if fl.cut and fl.caught_by == null and not fl.lost and fl.kite_on_ground:
			fl.lost = true
			events.append({"type": "perdida", "flyer": fl.id})


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
