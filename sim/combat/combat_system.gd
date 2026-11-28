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
const TANGLE_TIME := 0.25      ## s mandando linha em contato para embolar (D-029)
const TANGLE_GAP := 0.3        ## s: encostou há menos que isso ainda conta como "em contato"
const DECEPAR_METROS := 3.0   ## m de linha puxada rápido em contato para decepar (D-044)
const DECEPAR_RAPIDO := 4.5   ## m/s: com o embolo fraco, puxar acima disso vai decepando (D-105; era 3,5)
## D-105: embolo mais firme aguenta puxada mais rápida e mais longa.
const FIRMEZA_RAPIDO := 0.9   ## m/s a mais no limite de decepar por ponto de firmeza
const APERTA_POR_S := 0.6     ## firmeza ganha por segundo mandando linha (girando) com a avoada no aparo
const FIRMEZA_MAX := 4.0      ## firmeza máxima de um embolo
const FIRMEZA_AVISO := 2.0    ## a partir daqui avisa "embolou firme"
## D-105: a avoada desce pela linha de quem aparou (vem um pouco mais rápido
## que a própria pipa): metros de linha por segundo, e fração da puxada.
const DESCE_BASE := 0.5
const DESCE_PUXANDO := 0.4
const FATIAR_METROS := 1.5    ## m puxados rápido (abraçando) em cima da rabiola do rival para fatiá-la (D-056)
const SAIR_APARO := 3.0       ## s tenteando sem parar para a avoada sair do aparo (D-044)
const PERDIDA_CHAO := 5.0     ## s com a pipa no chão até virar perdida (a linha ainda cai)
const CUT_RATE := 5.5          ## m/s de linha puxada acima dos quais o contato decepa
const DECEPAR_GRACE := 4.0     ## s depois do corte em que a avoada não decepa (dá tempo de aparar)
const LARGADA_PRESSAO := 8.0  ## N: pressão (puxada) acima do voo parado que arma a largada
const LINK_SLACK := 0.3        ## m de folga no ponto embolado (pêndulo)

## Enroscos ativos. Cada um: {"avoada": Flyer, "chain": ParticleChain (da
## avoada), "idx": int (partícula enroscada), "catcher": Flyer, "cchain":
## ParticleChain (linha ou rabiola de quem aparou), "m": float (coordenada no
## material de cchain), "captured": bool}
var links: Array = []

## Linhas laçadas (D-027): depois que duas linhas em voo se encostam, ficam
## juntas até uma romper. Cada uma: {"a": Flyer, "b": Flyer, "ma": float,
## "mb": float} (coordenadas no material das linhas, a partir da pipa).
var engagements: Array = []
## Pontos de encontro das linhas laçadas (para a tela mostrar faísca).
var contact_points: PackedVector3Array = PackedVector3Array()

var _pairs: Array = []
## D-086: reaproveitar a lista de pares do subpasso anterior (SimWorld leve)
var reusar_pares := false
const FOLGA_LEVE := 0.5   ## m: folga da lista quando ela vale por um passo inteiro
var _assinatura := PackedInt64Array()
var _tangle := {}              ## [avoada, pipeiro, pedaço] -> embolo em formação
var _clock := 0.0
var _cut_want := {}            ## avoada -> [cadeia, segmento, quem] (neste subpasso)
var _fatia_want := {}          ## pipa em voo -> [rabiola, segmento, quem] (neste subpasso)
var _fatia_acc := {}           ## pipa em voo -> m puxados rápido em cima da rabiola dela
var _fatia_last := {}          ## pipa em voo -> [instante do último contato, rabiola, segmento, quem]
var _cut_acc := {}             ## avoada -> m puxados rápido em contato
var _solta_acc := {}           ## avoada -> s de tenteio de quem aparou
var _chao := {}                ## avoada -> s com a pipa no chão
var _snag_clock := 0.0
var _last_cut := {}            ## avoada -> instante do último decepar
var _pending_cuts: Array = []  ## [avoada, cadeia, segmento, quem decepou]
var _h := 0.0
var _chains: Array = []
var _groups := PackedInt32Array()
var _owners: Array = []
var contacts_last_step := 0
var max_contact_force := 0.0


## Reúne as cadeias de todos os pipeiros (e pedaços soltos) e resolve contatos.
var _leve_proximo := false   ## o SimWorld está no modo leve


func solve(flyers: Array, loose: Array, h: float) -> void:
	if not enabled:
		return
	_h = h
	_clock += h
	_advance_tangles(h)
	_apertar_e_descer(h)
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
	var assinatura := PackedInt64Array()
	for c in _chains:
		assinatura.append((c as ParticleChain).get_instance_id())
		assinatura.append((c as ParticleChain).pos.size())
	if not (reusar_pares and assinatura == _assinatura):
		# no 1º subpasso do modo leve a lista sai com folga para valer o passo todo
		var folga := FOLGA_LEVE if _leve_proximo else 0.0
		_pairs = LineContact.find_pairs(_chains, _groups, CONTACT_RADIUS * 2.0 + folga)
	_assinatura = assinatura
	var lacadas := {}
	for e in engagements:
		var fa: Flyer = e["a"]
		var fb: Flyer = e["b"]
		if fa.line != null and fb.line != null:
			lacadas[Vector2i(fa.line.get_instance_id(), fb.line.get_instance_id())] = e
			lacadas[Vector2i(fb.line.get_instance_id(), fa.line.get_instance_id())] = e
		e["f"] = 0.0
	contacts_last_step = 0
	max_contact_force = 0.0
	for it in CONTACT_ITERATIONS:
		for p in _pairs:
			var a: ParticleChain = _chains[p[0]]
			var b: ParticleChain = _chains[p[2]]
			var laco = lacadas.get(Vector2i(a.get_instance_id(), b.get_instance_id()))
			# Linhas laçadas: o desgaste é calculado no laço (quem corre gasta a outra).
			# Rabiola não corta linha (só enrosca); linhas laçadas gastam no laço.
			var gasta := it == 0 and laco == null and a.kind != ParticleChain.Kind.TAIL and b.kind != ParticleChain.Kind.TAIL
			var force := LineContact.solve_pair(a, p[1], b, p[3], CONTACT_RADIUS, h, wear_rate if gasta else 0.0)
			if laco != null and it == 0:
				laco["f"] = maxf(float(laco["f"]), force)
			if force > 0.0 and it == 0:
				contacts_last_step += 1
				max_contact_force = maxf(max_contact_force, force)
				a.last_contact = _owners[p[2]]
				b.last_contact = _owners[p[0]]
				_maybe_snag(p[0], p[1], p[2], p[3])
				_maybe_engage(p[0], p[1], p[2], p[3])
		_solve_links()
		_solve_engagements(h, wear_rate if it == 0 else 0.0)
	# Puxada rápida com a avoada embolada: o embolo arrebenta.
	for l in links:
		var ct: Flyer = l["catcher"]
		if not bool(l["captured"]) and ct.kite.spin_mode == KiteBody.SpinMode.SPIN_LOCK and ct.line_rate > decepar_rapido(l["avoada"]):
			_cut_want[l["avoada"]] = [l["chain"], maxi(0, int(l["idx"]) - 1), ct]
	# Decepar (D-044): puxar devagar traz para a mão; puxar RÁPIDO e MUITOS
	# metros (DECEPAR_METROS) arrebenta o embolo. Um tranco não decepa.
	for av in _cut_acc.keys():
		if not _cut_want.has(av):
			_cut_acc[av] = float(_cut_acc[av]) - 1.5 * h
			if float(_cut_acc[av]) <= 0.0:
				_cut_acc.erase(av)
	for av in _cut_want:
		var quem: Flyer = (_cut_want[av] as Array)[2]
		_cut_acc[av] = float(_cut_acc.get(av, 0.0)) + quem.line_rate * h
		if float(_cut_acc[av]) >= DECEPAR_METROS * firmeza(av):
			var c: Array = _cut_want[av]
			_pending_cuts.append([av, c[0], c[1], c[2]])
			_cut_acc.erase(av)
	_cut_want.clear()
	# Fatiar a rabiola de quem está em voo (D-056).
	for f in _fatia_want:
		var fw0: Array = _fatia_want[f]
		_fatia_last[f] = [_clock, fw0[0], fw0[1], fw0[2]]
	for f in _fatia_acc.keys():
		if not _fatia_last.has(f) or _clock - float((_fatia_last[f] as Array)[0]) > TANGLE_GAP:
			_fatia_acc[f] = float(_fatia_acc[f]) - 1.5 * h
			if float(_fatia_acc[f]) <= 0.0:
				_fatia_acc.erase(f)
	# contato recente (menos de TANGLE_GAP) e ainda abraçando: vai fatiando
	for f in _fatia_last.keys():
		var fl0: Array = _fatia_last[f]
		var q0: Flyer = fl0[3]
		if _clock - float(fl0[0]) > TANGLE_GAP or q0.cut or q0.kite.spin_mode != KiteBody.SpinMode.SPIN_LOCK or q0.line_rate <= DECEPAR_RAPIDO:
			if _clock - float(fl0[0]) > TANGLE_GAP:
				_fatia_last.erase(f)
			continue
		var fw: Array = [fl0[1], fl0[2], fl0[3]]
		var quem2: Flyer = fw[2]
		_fatia_acc[f] = float(_fatia_acc.get(f, 0.0)) + quem2.line_rate * h
		if float(_fatia_acc[f]) >= FATIAR_METROS:
			_fatia_acc.erase(f)
			_fatia_last.erase(f)
			var dono: Flyer = f
			var rab: ParticleChain = fw[0]
			if rab == dono.tail and rab.size() >= 3 and _clock - float(_last_cut.get(dono, -10.0)) >= 0.5:
				_last_cut[dono] = _clock
				var pedaco := rab.split(clampi(int(fw[1]), 0, rab.size() - 2))
				loose.append(pedaco)
				events.append({"type": "fatiou", "flyer": dono.id, "catcher": quem2.id, "tail": true, "voando": true})
	_fatia_want.clear()
	for c in _pending_cuts:
		var av: Flyer = c[0]
		if _clock - float(_last_cut.get(av, -10.0)) < 0.5 or (c[1] != av.trailing_line and c[1] != av.tail):
			continue
		_last_cut[av] = _clock
		_decepar(av, c[1], int(c[2]), c[3], loose)
	_pending_cuts.clear()


## Aparar (D-029): a linha ou a rabiola de uma avoada encosta na linha ou na
## rabiola de quem está em voo. Só EMBOLA se quem está em voo estiver mandando
## linha (girando) em contato por TANGLE_TIME. Puxando rápido (acima de
## CUT_RATE) em contato, DECEPA o pedaço da avoada no ponto de contato.
func _maybe_snag(ia: int, i: int, ib: int, j: int) -> void:
	for ordem in 2:
		var av_idx := ia if ordem == 0 else ib
		var av_seg := i if ordem == 0 else j
		var ct_idx := ib if ordem == 0 else ia
		var ct_seg := j if ordem == 0 else i
		var av: Flyer = _owners[av_idx]
		var ct: Flyer = _owners[ct_idx]
		var chain: ParticleChain = _chains[av_idx]
		var cchain: ParticleChain = _chains[ct_idx]
		# Fatiar (D-056): passando a linha em cima da RABIOLA de uma pipa em voo,
		# abraçando (puxando forte), a rabiola dela é fatiada — não precisa
		# estar avoada.
		if av != null and ct != null and not av.cut and not ct.cut and chain == av.tail and cchain == ct.line \
				and ct.kite.spin_mode == KiteBody.SpinMode.SPIN_LOCK and ct.line_rate > DECEPAR_RAPIDO:
			_fatia_want[av] = [chain, av_seg, ct]
			continue
		if av == null or ct == null or not av.cut or av.lost or ct.cut:
			continue
		# D-061: já no seu aparo (pela linha), dá para embolar também pela
		# rabiola (e vice-versa) — só não emaranha de novo no mesmo pedaço,
		# nem com outro pipeiro.
		if av.caught_by != null and (av.caught_by != ct or _tem_link(av, chain)):
			continue
		if not (chain == av.trailing_line or chain == av.tail):
			continue
		if not (cchain == ct.line or cchain == ct.tail):
			continue
		if ct.kite.spin_mode == KiteBody.SpinMode.SPIN_LOCK and ct.line_rate > DECEPAR_RAPIDO:
			# abraçando em cima da linha ou da rabiola da avoada: fatia (D-056)
			if av.cut_age > DECEPAR_GRACE:
				_cut_want[av] = [chain, av_seg, ct]
			return
		if not _girando(ct):
			return
		# Encostou mandando linha: o embolo começa (ou continua) a se formar.
		var chave := [av.get_instance_id(), ct.get_instance_id(), chain.get_instance_id()]
		var st := LineContact.closest_params(chain.pos[av_seg], chain.pos[av_seg + 1], cchain.pos[ct_seg], cchain.pos[ct_seg + 1])
		var t: Dictionary = _tangle.get(chave, {"t": 0.0})
		t["last"] = _clock
		t["av"] = av
		t["ct"] = ct
		t["chain"] = chain
		t["idx"] = av_seg if st.x < 0.5 else av_seg + 1
		t["cchain"] = cchain
		t["m"] = cchain.material_coordinate(ct_seg, st.y)
		_tangle[chave] = t
		return


## O embolo cresce enquanto quem aparou segue mandando linha com o contato
## recente (encostou há menos de TANGLE_GAP); senão desfaz devagar.
func _advance_tangles(h: float) -> void:
	for chave in _tangle.keys():
		var t: Dictionary = _tangle[chave]
		var av: Flyer = t["av"]
		var ct: Flyer = t["ct"]
		var ativo := _clock - float(t["last"]) < TANGLE_GAP and _girando(ct)
		t["t"] = float(t["t"]) + (h if ativo else -0.5 * h)
		var chain: ParticleChain = t["chain"]
		if float(t["t"]) <= 0.0 or ct.cut or not av.cut \
				or (av.caught_by != null and (av.caught_by != ct or _tem_link(av, chain))):
			_tangle.erase(chave)
			continue
		var cchain: ParticleChain = t["cchain"]
		if chain != av.trailing_line and chain != av.tail or (cchain != ct.line and cchain != ct.tail):
			_tangle.erase(chave)
			continue
		if float(t["t"]) >= TANGLE_TIME:
			_tangle.erase(chave)
			links.append({"avoada": av, "chain": chain, "idx": clampi(int(t["idx"]), 0, chain.size() - 1),
				"catcher": ct, "cchain": cchain, "m": float(t["m"]), "captured": false, "forca": 1.0})
			av.caught_by = ct
			ct.holding += 1
			events.append({"type": "enroscou", "flyer": av.id, "catcher": ct.id, "by_tail": cchain == ct.tail})


## D-105: firmeza do aparo de uma avoada = soma da firmeza dos seus embolos
## (embolada pela linha e pela rabiola conta os dois). 1 = embolo fraco.
func firmeza(av: Flyer) -> float:
	var f := 0.0
	for l in links:
		if l["avoada"] == av and not bool(l["captured"]):
			f += float(l.get("forca", 1.0))
	return maxf(f, 1.0)


## Velocidade de puxada acima da qual o embolo desta avoada vai decepando.
func decepar_rapido(av: Flyer) -> float:
	return DECEPAR_RAPIDO + FIRMEZA_RAPIDO * (firmeza(av) - 1.0)


## D-105: mandando linha (pipa girando) com a avoada no aparo, o embolo aperta;
## e a avoada desce pela linha até a mão, um pouco mais rápido que a puxada.
func _apertar_e_descer(h: float) -> void:
	for l in links:
		if bool(l["captured"]):
			continue
		var ct: Flyer = l["catcher"]
		var av: Flyer = l["avoada"]
		if ct.cut:
			continue
		if ct.kite.spin_mode == KiteBody.SpinMode.SPIN_GIVE:
			var antes := firmeza(av)
			l["forca"] = minf(float(l.get("forca", 1.0)) + APERTA_POR_S * h, FIRMEZA_MAX)
			if antes < FIRMEZA_AVISO and firmeza(av) >= FIRMEZA_AVISO:
				events.append({"type": "embolo_firme", "flyer": av.id, "catcher": ct.id})
		var cchain: ParticleChain = l["cchain"]
		if cchain == ct.line:
			var puxando := ct.line_rate if ct.kite.spin_mode == KiteBody.SpinMode.SPIN_LOCK else 0.0
			var desce := (DESCE_BASE + DESCE_PUXANDO * puxando) * h
			l["m"] = minf(float(l["m"]) + desce, cchain.rest_total() - 0.1)


## Decepa o pedaço da avoada (linha solta ou rabiola) no segmento indicado:
## a parte de fora cai solta; a avoada continua livre.
func _decepar(av: Flyer, chain: ParticleChain, seg: int, ct: Flyer, loose: Array) -> void:
	if chain.size() < 3:
		return
	for l in links.duplicate():
		if l["avoada"] == av:
			links.erase(l)
			(l["catcher"] as Flyer).holding = maxi(0, (l["catcher"] as Flyer).holding - 1)
	av.caught_by = null
	seg = clampi(seg, 0, chain.size() - 2)
	var pedaco := chain.split(seg)
	if chain == av.trailing_line:
		# a ponta presa à pipa fica com ela; o resto da linha cai
		av.trailing_line = pedaco
		loose.append(chain)
	else:
		loose.append(pedaco)
	events.append({"type": "decepou", "flyer": av.id, "catcher": ct.id, "tail": chain == av.tail})
	events.append({"type": "fatiou", "flyer": av.id, "catcher": ct.id, "tail": chain == av.tail, "voando": false})


## Mantém cada ponto enroscado preso ao seu lugar no material da outra linha.
func _solve_links() -> void:
	for l in links:
		var chain: ParticleChain = l["chain"]
		var cchain: ParticleChain = l["cchain"]
		var ct: Flyer = l["catcher"]
		var av: Flyer = l["avoada"]
		# Ligação que perdeu o sentido (quem aparou foi cortado, a avoada mudou
		# de pedaço): não puxa nada; check_snags desfaz no fim do subpasso.
		if ct.cut or (cchain != ct.line and cchain != ct.tail) or (chain != av.trailing_line and chain != av.tail):
			continue
		var idx: int = l["idx"]
		var loc := cchain.locate_material(float(l["m"]))
		var seg := int(loc.x)
		var s := loc.y
		var p := cchain.pos[seg].lerp(cchain.pos[seg + 1], s)
		var d := chain.pos[idx] - p
		var dist := d.length()
		if dist < LINK_SLACK:
			continue
		var n := d / dist
		var wq := chain.inv_mass[idx]
		var wp := cchain.inv_mass[seg] * (1.0 - s) * (1.0 - s) + cchain.inv_mass[seg + 1] * s * s
		if wq + wp < 1e-12:
			continue
		var dl := -minf(dist - LINK_SLACK, 0.5) / (wq + wp)   # no máximo 0,5 m por passo
		chain.pos[idx] += n * (wq * dl)
		cchain.pos[seg] -= n * (cchain.inv_mass[seg] * (1.0 - s) * dl)
		cchain.pos[seg + 1] -= n * (cchain.inv_mass[seg + 1] * s * dl)


## Pipa aparada (chegou na mão), pipa perdida (chão) e enroscos desfeitos.
func check_snags(flyers: Array) -> void:
	var dt := clampf(_clock - _snag_clock, 0.0, 0.1)
	_snag_clock = _clock
	for f in flyers:
		(f as Flyer).caught_by_tail = false
	var contadas := {}
	for l in links.duplicate():
		if not links.has(l):
			continue   # já solto neste passo (outro embolo da mesma avoada)
		var av: Flyer = l["avoada"]
		var ct: Flyer = l["catcher"]
		var cchain: ParticleChain = l["cchain"]
		if ct.cut or (cchain != ct.line and cchain != ct.tail):
			# quem aparou teve a linha cortada: a avoada se solta de novo
			links.erase(l)
			av.caught_by = null
			ct.holding = maxi(0, ct.holding - 1)
			continue
		if l["chain"] == av.tail:
			av.caught_by_tail = true   # presa (também) pela rabiola: vem rodando
		if bool(l["captured"]):
			continue
		# Sair do aparo (D-044): tenteando sem parar uns 3 s, o embolo solta
		# (todos os embolos da avoada; conta uma vez por avoada, D-061).
		if not contadas.has(av):
			contadas[av] = true
			if ct.tenteio_age < 0.6:
				_solta_acc[av] = float(_solta_acc.get(av, 0.0)) + dt
			else:
				_solta_acc[av] = maxf(0.0, float(_solta_acc.get(av, 0.0)) - 0.5 * dt)
		if float(_solta_acc.get(av, 0.0)) >= SAIR_APARO:
			for l2 in links.duplicate():
				if l2["avoada"] == av:
					links.erase(l2)
			av.caught_by = null
			_solta_acc.erase(av)
			_cut_acc.erase(av)
			events.append({"type": "soltou", "flyer": av.id, "catcher": ct.id})
			continue
		var loc := cchain.locate_material(float(l["m"]))
		var p := cchain.pos[int(loc.x)].lerp(cchain.pos[int(loc.x) + 1], loc.y)
		var na_mao := p.distance_to(ct.hand_position) < CAPTURE_DISTANCE
		if cchain == ct.line and float(l["m"]) >= cchain.rest_total() - 0.3:
			na_mao = true
		if na_mao:
			# D-107: uma aparada é UMA pipa, mesmo embolada pela linha e pela
			# rabiola (dois embolos): conta e avisa uma vez só
			var ja := av.captured
			for l2 in links:
				if l2["avoada"] == av:
					l2["captured"] = true
			av.captured = true
			if not ja:
				ct.catches += 1
				events.append({"type": "aparada", "flyer": av.id, "catcher": ct.id})
	# Enroscos ainda não trazidos, contados de novo (o aviso não fica preso).
	for f in flyers:
		(f as Flyer).holding = 0
	for l in links:
		if not bool(l["captured"]):
			(l["catcher"] as Flyer).holding += 1
	for f in flyers:
		var fl: Flyer = f
		# Pipa no chão ainda pode ser aparada enquanto a linha e a rabiola
		# caem (D-044); só depois de um tempo no chão vira perdida.
		if fl.cut and fl.caught_by == null and not fl.lost and fl.kite_on_ground:
			_chao[fl] = float(_chao.get(fl, 0.0)) + dt
			if float(_chao[fl]) >= PERDIDA_CHAO:
				fl.lost = true
				_chao.erase(fl)
				events.append({"type": "perdida", "flyer": fl.id})


## Verifica rupturas. Chamar uma vez por subpasso, depois de `solve`.
func check_breaks(flyers: Array, loose: Array) -> void:
	if not enabled:
		return
	# Laços: rompe a linha que perdeu a integridade, no ponto de encontro.
	for e in engagements.duplicate():
		var fa: Flyer = e["a"]
		var fb: Flyer = e["b"]
		if fa.cut or fb.cut or not e.has("ia"):
			continue
		var perde: Flyer = null
		var seg := 0
		if float(e.get("wa", 0.0)) >= fa.line.strength and float(e.get("wa", 0.0)) >= float(e.get("wb", 0.0)):
			perde = fa
			seg = int(e["ia"])
		elif float(e.get("wb", 0.0)) >= fb.line.strength:
			perde = fb
			seg = int(e["ib"])
		if perde == null:
			continue
		var autor := fb if perde == fa else fa
		seg = clampi(seg, 0, perde.line.size() - 2)
		var onde := perde.line.pos[seg].lerp(perde.line.pos[seg + 1], 0.5)
		engagements.erase(e)
		perde.cut_line(seg)
		events.append({"type": "ruptura", "flyer": perde.id, "segment": seg, "position": onde, "by": autor.id})
	for f in flyers:
		var fl: Flyer = f
		if fl.cut or fl.line == null:
			continue
		if fl.line.max_wear() >= fl.line.strength:
			var seg := fl.line.weakest_segment()
			var onde := fl.line.pos[seg].lerp(fl.line.pos[seg + 1], 0.5)
			var quem: Flyer = fl.line.last_contact as Flyer
			for e in engagements:
				if e["a"] == fl:
					quem = e["b"]
				elif e["b"] == fl:
					quem = e["a"]
			fl.cut_line(seg)
			events.append({"type": "ruptura", "flyer": fl.id, "segment": seg, "position": onde,
				"by": quem.id if quem != null else -1})
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


## Esquece enroscos que envolvem um pipeiro que saiu do mundo.
func forget(f: Flyer) -> void:
	_cut_acc.erase(f)
	_fatia_acc.erase(f)
	_fatia_last.erase(f)
	_solta_acc.erase(f)
	_chao.erase(f)
	_last_cut.erase(f)
	for e in engagements.duplicate():
		if e["a"] == f or e["b"] == f:
			engagements.erase(e)
	for l in links.duplicate():
		if l["avoada"] == f or l["catcher"] == f:
			links.erase(l)
			if l["catcher"] != f and not bool(l["captured"]):
				(l["catcher"] as Flyer).holding = maxi(0, (l["catcher"] as Flyer).holding - 1)
			if l["avoada"] != f:
				(l["avoada"] as Flyer).caught_by = null


func _maybe_engage(ia: int, i: int, ib: int, j: int) -> void:
	var fa: Flyer = _owners[ia]
	var fb: Flyer = _owners[ib]
	if fa == null or fb == null or fa == fb or fa.cut or fb.cut:
		return
	var a: ParticleChain = _chains[ia]
	var b: ParticleChain = _chains[ib]
	if a != fa.line or b != fb.line:
		return
	for e in engagements:
		if (e["a"] == fa and e["b"] == fb) or (e["a"] == fb and e["b"] == fa):
			return
	var st := LineContact.closest_params(a.pos[i], a.pos[i + 1], b.pos[j], b.pos[j + 1])
	engagements.append({"a": fa, "b": fb, "ma": a.material_coordinate(i, st.x), "mb": b.material_coordinate(j, st.y)})
	events.append({"type": "lacou", "flyer": fa.id, "other": fb.id})


## Acha de novo o ponto de encontro perto do anterior e segura as linhas juntas.
func _solve_engagements(h: float, wear_k: float) -> void:
	contact_points.clear()
	for e in engagements.duplicate():
		var fa: Flyer = e["a"]
		var fb: Flyer = e["b"]
		if fa.cut or fb.cut or fa.line == null or fb.line == null:
			engagements.erase(e)
			continue
		var a := fa.line
		var b := fb.line
		var ia := int(a.locate_material(float(e["ma"])).x)
		var ib := int(b.locate_material(float(e["mb"])).x)
		var melhor := INF
		var bi := ia
		var bj := ib
		var bst := Vector2.ZERO
		for i in range(maxi(0, ia - 3), mini(a.size() - 1, ia + 4)):
			for j in range(maxi(0, ib - 3), mini(b.size() - 1, ib + 4)):
				var st := LineContact.closest_params(a.pos[i], a.pos[i + 1], b.pos[j], b.pos[j + 1])
				var d := a.pos[i].lerp(a.pos[i + 1], st.x).distance_squared_to(b.pos[j].lerp(b.pos[j + 1], st.y))
				if d < melhor:
					melhor = d
					bi = i
					bj = j
					bst = st
		var ma := a.material_coordinate(bi, bst.x)
		var mb := b.material_coordinate(bj, bst.y)
		e["ma"] = ma
		e["mb"] = mb
		var f := LineContact.hold_pair(a, bi, b, bj, CONTACT_RADIUS, h, 0.0) + float(e.get("f", 0.0))
		# A força no ponto de encontro não passa muito da tensão das linhas.
		f = minf(f, 2.0 * (fa.tension + fb.tension) + 1.0)
		if wear_k > 0.0:
			# Relo (D-027): a linha que corre (quem está dando ou puxando linha)
			# gasta a outra; um pouco para as duas sempre.
			# Cada tenteio no relô também serra (D-035).
			var corre_a := fa.line_rate * _largada(fa) + (2.0 if fa.tenteio_age < 0.3 else 0.0)
			var corre_b := fb.line_rate * _largada(fb) + (2.0 if fb.tenteio_age < 0.3 else 0.0)
			var base := 0.15 * (corre_a + corre_b) + 0.05
			# Integridade de cada linha neste laço (não espalha pelo comprimento).
			e["wa"] = float(e.get("wa", 0.0)) + wear_k * f * (corre_b + base) * h
			e["wb"] = float(e.get("wb", 0.0)) + wear_k * f * (corre_a + base) * h
		e["ia"] = bi
		e["ib"] = bj
		contact_points.append(a.pos[bi].lerp(a.pos[bi + 1], bst.x))


## Largada (D-034): puxou (linha com pressão) e soltou de uma vez no relô —
## a linha corre com força e serra a outra: desgaste em dobro.
func _largada(f: Flyer) -> float:
	if f.kite.lunge > 0.0 or (f.kite.spin_mode == KiteBody.SpinMode.SPIN_GIVE and f.tension_memo > LARGADA_PRESSAO and f.line_rate > 1.5):
		return 2.0
	return 1.0


## Girando a pipa para embolar: mandando linha ou tenteando.
func _girando(f: Flyer) -> bool:
	return f.kite.spin_mode == KiteBody.SpinMode.SPIN_GIVE or f.kite.spin_mode == KiteBody.SpinMode.SPIN_KICK or f.tenteio_age < 0.4


## A avoada já tem um embolo neste pedaço (linha solta ou rabiola)?
func _tem_link(av: Flyer, chain: ParticleChain) -> bool:
	for l in links:
		if l["avoada"] == av and l["chain"] == chain:
			return true
	return false
