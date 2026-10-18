class_name Reactions
extends RefCounted
## Reactions and other "when this happens" choices during an attack (2024 PHB), offered in order at each stage of
## the attack: before the roll (Warding Flare, Protection, Lucky against you), after a miss by the attacker (Heroic
## Inspiration, Precision Attack, Guided Strike), after a hit (Shield, Defensive Duelist, Illusory Self), after a
## miss on the target (Riposte), and against the damage (Uncanny Dodge, Parry, Stone's Endurance, Interception,
## Protective Field, Projected Ward). Each offer is {kind, reactor, title, text, cost, use: Callable, stop:
## Callable}: the player is asked (or their per-reaction rule decides), the AI decides for its creatures.
## `use` applies the choice; if the offer has `stop`, using it ends the stage there (Shield turns the hit into a
## miss) and `stop` carries on instead.
##
## A hero with more than one Reaction to pick from gets one prompt listing them all (owner report 2026-10-12: Godrick's
## Protection and Sentinel were only ever asked about one at a time): the ones that can be taken now, and during an
## attack the ones whose trigger comes later in it (Sentinel and Interception need the hit), which keep the Reaction
## for that moment. Skipping keeps the Reaction: a later trigger still asks.

## The kind of the prompt that lists several Reactions (ReactionRequest.kind).
const CHOICE := "reaction_choice"

var _enc: WeakRef


func _init(encounter: Encounter) -> void:
	_enc = weakref(encounter)


func enc() -> Encounter:
	return _enc.get_ref() as Encounter


func feats() -> CombatFeatures:
	return enc().features


## Runs the offers in `chain` one after another, then `done`. Pauses on each one the player is asked about. An offer may
## also be `forced` (no choice: it happens when reached), say `ask: false` (never asked: its rule settles it, as
## D20Responses.sync_allows does), name the `default` rule its creature has until one is set, give a `callout` (a line
## the prompt shows in red: a Critical Hit on Divine Smite's), give `text`, `cost` and
## `target_choices` as Callables (worded when asked, after earlier offers changed the roll), and give `helps`: when it says the offer can't
## change the outcome, the player isn't asked (a reroll that can't reach the DC).
## `st` is the attack's state when the chain is one of an attack's stages: it holds the Reactions kept for later in it
## (`reserved`: reactor id -> kind) and lets a prompt list those (later_options).
func offer(chain: Array, done: Callable, r: CombatResult, st: Dictionary = {}) -> CombatResult:
	var e := enc()
	while not chain.is_empty():
		var o := chain.pop_front() as Dictionary
		var reactor := o["reactor"] as Combatant
		if o.has("still") and not (o["still"] as Callable).call():
			continue
		var kind := str(o["kind"])
		var decision := decide(o, st)
		if decision == "never":
			continue
		if decision == "auto":
			(o["use"] as Callable).call()
			if o.has("stop") and (not o.has("stop_if") or (o["stop_if"] as Callable).call()):
				return (o["stop"] as Callable).call() as CombatResult
			continue
		var group := _asked_with(o, chain, st)
		var later := later_options(st, reactor, group)
		if group.size() + later.size() > 1:
			return _choose(group, later, chain, done, r, st)
		var req := ReactionRequest.new(kind, reactor.id, str(o.get("trigger", "")))
		req.title = str(o["title"])
		req.text = _text(o)
		req.cost = _cost(o)
		req.callout = str(o.get("callout", ""))
		req.spends_reaction = bool(o.get("spends_reaction", true))
		req.target_choices.assign(_own_choices(o))
		req.selected_ids.assign(o.get("selected_ids", []))
		req.min_targets = int(o.get("min_targets", 0))
		req.max_targets = int(o.get("max_targets", 0))
		req.validate_selected = o.get("validate_selected", Callable())
		var request_ref: WeakRef = weakref(req)
		var rest := chain.duplicate()
		req.continuation = func(use: bool) -> CombatResult:
			if use:
				if o.has("select"):
					var request := request_ref.get_ref() as ReactionRequest
					(o["select"] as Callable).call(request.selected_ids)
				(o["use"] as Callable).call()
				if o.has("stop") and (not o.has("stop_if") or (o["stop_if"] as Callable).call()):
					return (o["stop"] as Callable).call() as CombatResult
			return offer(rest, done, r, st)
		e.pending = req
		r.pending = req
		return r
	return done.call() as CombatResult


## Whether an offer spends its creature's Reaction: its cost or title names one (Lucky, Precision Attack and the rerolls
## after a d20 don't).
static func costs_reaction(o: Dictionary) -> bool:
	if not bool(o.get("spends_reaction", true)):
		return false
	return _cost(o).contains("Reaction") or str(o.get("title", "")).begins_with("Reaction:")


static func _text(o: Dictionary) -> String:
	return str((o["text"] as Callable).call()) if o["text"] is Callable else str(o["text"])


static func _cost(o: Dictionary) -> String:
	var cost: Variant = o.get("cost", "Reaction")
	return str((cost as Callable).call()) if cost is Callable else str(cost)


static func _own_choices(o: Dictionary) -> Array:
	var choices: Variant = o.get("target_choices", [])
	return ((choices as Callable).call() if choices is Callable else choices) as Array


## An offer's name on a list: its title without "Reaction: " and the question mark.
static func offer_name(title: String) -> String:
	return title.trim_prefix("Reaction: ").trim_suffix("?")


## `o` (to be asked about) and the offers further down `chain` the same hero would be asked about that spend the same
## Reaction: what one prompt lists. An offer that picks several things at once is asked about by itself, and so is a
## second of the same kind (Protection for each of a spell's rays), after the first.
func _asked_with(o: Dictionary, chain: Array, st: Dictionary) -> Array:
	var reactor := o["reactor"] as Combatant
	var group: Array = [o]
	if not reactor.is_player_controlled() or not costs_reaction(o) or not _one_pick(o):
		return group
	for x: Dictionary in chain:
		if x["reactor"] != reactor or not costs_reaction(x) or not _one_pick(x) or group.any(func(g: Dictionary) -> bool: return g["kind"] == x["kind"]):
			continue
		if (not x.has("still") or (x["still"] as Callable).call()) and decide(x, st) == "ask":
			group.append(x)
	return group


static func _one_pick(o: Dictionary) -> bool:
	return _own_choices(o).is_empty() or int(o.get("max_targets", 0)) == 1


## One prompt for a hero's Reactions: each offer in `group` (one with picks of its own lists each pick: a slot level),
## then the ones `later` in the attack. Picking one now uses it; picking a later one keeps the Reaction for it
## (st.reserved); skipping declines this list and keeps the Reaction.
func _choose(group: Array, later: Array[Dictionary], chain: Array, done: Callable, r: CombatResult, st: Dictionary) -> CombatResult:
	var e := enc()
	var first := group[0] as Dictionary
	var reactor := first["reactor"] as Combatant
	var req := chooser(reactor, str(first.get("trigger", "")))
	for i in group.size():
		var o := group[i] as Dictionary
		var own := _own_choices(o)
		if own.is_empty():
			req.target_choices.append({"id": "now:%d" % i, "label": offer_name(str(o["title"])), "text": _text(o), "cost": _cost(o)})
		for pick: Dictionary in own:
			req.target_choices.append({"id": "now:%d:%s" % [i, pick["id"]], "label": "%s · %s" % [offer_name(str(o["title"])), pick["label"]],
				"text": _text(o), "cost": _cost(o)})
	for l in later:
		req.target_choices.append({"id": "later:" + str(l["kind"]), "label": l["label"], "text": l["text"], "cost": l["cost"]})
	# The first offer's own pick (the slot it would choose) starts selected.
	var preset := first.get("selected_ids", []) as Array
	req.selected_ids.assign(["now:0:%s" % preset[0]] if not _own_choices(first).is_empty() and not preset.is_empty() else [str(req.target_choices[0]["id"])])
	req.validate_selected = func(ids: Array[String]) -> String:
		var bits := ids[0].split(":", true, 2)
		if bits[0] != "now" or bits.size() < 3 or not (group[int(bits[1])] as Dictionary).has("validate_selected"):
			return ""
		var sub: Array[String] = [bits[2]]
		return str(((group[int(bits[1])] as Dictionary)["validate_selected"] as Callable).call(sub))
	var rest := chain.filter(func(x: Dictionary) -> bool: return not group.any(func(g: Dictionary) -> bool: return is_same(g, x)))
	var request_ref: WeakRef = weakref(req)
	req.continuation = func(use: bool) -> CombatResult:
		var request := request_ref.get_ref() as ReactionRequest
		if not use or request == null:
			return offer(rest, done, r, st)
		var bits := request.selected_ids[0].split(":", true, 2)
		if bits[0] == "later":
			var kept := st.get("reserved", {}) as Dictionary
			kept[reactor.id] = bits[1]
			st["reserved"] = kept
			return offer(rest, done, r, st)
		var o := group[int(bits[1])] as Dictionary
		if o.has("select"):
			var sub: Array[String] = []
			if bits.size() > 2:
				sub.append(bits[2])
			(o["select"] as Callable).call(sub)
		(o["use"] as Callable).call()
		if o.has("stop") and (not o.has("stop_if") or (o["stop_if"] as Callable).call()):
			return (o["stop"] as Callable).call() as CombatResult
		return offer(rest, done, r, st)
	e.pending = req
	r.pending = req
	return r


## An empty prompt listing `reactor`'s Reactions, one to pick: the caller adds the choices ({id, label, text, cost}; the
## prompt shows the picked one's text and cost) and the continuation.
func chooser(reactor: Combatant, trigger_id: String) -> ReactionRequest:
	var req := ReactionRequest.new(CHOICE, reactor.id, trigger_id)
	req.title = "%s has a Reaction" % reactor.name()
	req.text = "Pick one to use, or Skip to keep it."
	req.min_targets = 1
	req.max_targets = 1
	return req


## The Reactions `reactor` could take later in the attack `st` (at its `stage`), listed on a prompt beside what it can take
## now (`group`): Sentinel once the attack hits someone else (2024: "immediately after a creature within 5 feet of you
## ... hits a target other than you"), Interception against the damage of a hit beside it, and an attack readied for
## this one. Each is {kind, label, text, cost}; rules set to Off are left out.
func later_options(st: Dictionary, reactor: Combatant, group: Array) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	if not st.has("stage") or not reactor.is_player_controlled() or not costs_reaction(group[0] as Dictionary):
		return out
	var e := enc()
	var c := st["c"] as Combatant
	var target := st["target"] as Combatant
	var stage := str(st["stage"])
	var now := group.map(func(o: Dictionary) -> String: return str(o["kind"]))
	var open := func(kind: String) -> bool: return not kind in now and e._reaction_decision(reactor, kind) != "never"
	if stage != "missed" and reactor != target and reactor.hostile_to(c) and feats().has_feat(reactor, "sentinel") and open.call("sentinel") \
			and e.distance(reactor, c) <= 5 and not e.best_melee_option(reactor, c).is_empty():
		out.append({"kind": "sentinel", "label": "Sentinel, if the attack hits",
			"text": "If %s hits %s, %s makes an Opportunity Attack against it right after (Sentinel). If it misses, the Reaction is kept." % [c.name(), target.name(), reactor.name()],
			"cost": "Reaction, only if it hits"})
	if stage in ["before_roll", "roll", "hit"] and reactor != target and reactor.allied_with(target) and feats().has_feat(reactor, "interception") \
			and open.call("interception") and e.distance(reactor, target) <= 5 and (feats().wields_shield(reactor) or feats().holds_weapon(reactor)):
		out.append({"kind": "interception", "label": "Interception, if the attack hits",
			"text": "If %s hits %s, %s cuts the damage by 1d10 + %d (Interception). If it misses, the Reaction is kept." % [c.name(), target.name(), reactor.name(), reactor.creature.proficiency_bonus()],
			"cost": "Reaction, only if it hits"})
	if reactor.hostile_to(c) and open.call("readied_attack") and e.reaction_queue.any(func(q: Dictionary) -> bool:
			return str(q["kind"]) == "readied_attack" and str(q["reactor"]) == reactor.id and str(q["trigger"]) == c.id):
		var what := str(Compendium.shared().spell_data(str(reactor.readied["spell"])).get("name", "spell")) if reactor.readied.has("spell") else "attack"
		out.append({"kind": "readied_attack", "label": "Readied %s, once the attack is done" % what,
			"text": "%s's readied %s goes off at %s once its attack is done." % [reactor.name(), what, c.name()], "cost": "Reaction"})
	return out


## What happens to an offer that's still open: "auto" (its creature's rule or the AI takes it, or it's `forced`),
## "never", or "ask" (the player is asked). An offer the creature's rule would ask about but that can't change the
## result (`helps`) is "never"; one that answers a roll about to be made (`ask: false`) follows D20Responses.sync_allows.
## In an attack where the hero kept the Reaction for something later (st.reserved), that one is taken when it comes and
## the hero's other Reactions aren't offered.
func decide(o: Dictionary, st: Dictionary = {}) -> String:
	var e := enc()
	var kept := str((st.get("reserved", {}) as Dictionary).get((o["reactor"] as Combatant).id, ""))
	if kept != "" and costs_reaction(o):
		return "auto" if str(o["kind"]) == kept else "never"
	if bool(o.get("forced", false)):
		return "auto"
	var decision := e._reaction_decision(o["reactor"] as Combatant, str(o["kind"]), str(o.get("default", "")))
	# A hero on Automatic is still asked when the spell has several ways to be cast: a slot level or a free casting
	# (Hellish Rebuke, Absorb Elements), and a Counterspell offers its ways the same way (owner, 2026-10-15).
	if decision == "auto" and (o["reactor"] as Combatant).is_player_controlled() and ((o.has("several_ways") and (o["several_ways"] as Callable).call()) or (o.has("ways") and int((o["ways"] as Callable).call()) > 1)):
		decision = "ask"
	if decision == "ask" and not bool(o.get("ask", true)):
		decision = "auto" if e.d20.sync_allows(o) else "never"
	if decision == "ask" and o.has("helps") and not (o["helps"] as Callable).call():
		decision = "never"
	# A hero's Reaction with more than one way to cast it asks even on Automatic (owner, 2026-10-18; Hellish Rebuke's rule).
	if decision == "auto" and bool(o.get("asks_when_several", false)) and (o["reactor"] as Combatant).is_player_controlled() and _own_choices(o).size() > 1:
		decision = "ask"
	return decision


func _react_ok(c: Combatant) -> bool:
	return enc().spells.can_react(c)


# --- Before the attack roll -------------------------------------------------------------------------

## st: the attack's state {c, target, option, sit, ...}; offers add to st["sit"] advantage/disadvantage. Each stage's
## builder notes the stage in st["stage"] for later_options.
func before_roll(st: Dictionary) -> Array:
	var e := enc()
	st["stage"] = "before_roll"
	var c := st["c"] as Combatant
	var target := st["target"] as Combatant
	var out: Array = []
	var dis := (st["sit"] as Dictionary)["disadvantage"] as Array[String]
	for p in e.living():
		if p == c or not p.hostile_to(c) or not p.creature is Character:
			continue
		var ch := p.creature as Character
		# Warding Flare (Light Domain 3): a creature you can see within 30 ft makes an attack roll.
		if CombatFeatures.has_feature(p, "warding_flare") and ch.resource_left("warding_flare") > 0 and _react_ok(p) \
				and e.distance(p, c) <= 30 and e.can_see(p, c):
			var pp := p
			out.append({"kind": "warding_flare", "reactor": p, "trigger": c.id, "title": "Reaction: Warding Flare?",
				"text": "%s attacks %s. A flash of light gives the attack roll Disadvantage." % [c.name(), target.name()],
				"cost": "Reaction and a use of Warding Flare",
				"still": func() -> bool: return _react_ok(pp) and (pp.creature as Character).resource_left("warding_flare") > 0,
				"use": func() -> void:
					pp.reaction_available = false
					(pp.creature as Character).spend_resource("warding_flare")
					dis.append("Warding Flare (%s)" % pp.name())
					e.log.add("reaction", "%s flares with light: Disadvantage on %s's attack" % [pp.name(), c.name()], pp.id)
					if CombatFeatures.has_feature(pp, "improved_warding_flare") and pp.allied_with(target):
						var th := int(e._roll_damage_dice("2d6", false, 0, "Improved Warding Flare")["total"]) + pp.creature.ability_mod(&"wis")
						target.creature.add_temp_hp(th, "Improved Warding Flare")
						e.log.add("heal", "%s gains %d Temporary Hit Points" % [target.name(), th], target.id)})
		# Protection (Fighting Style): a Shield-bearer within 5 ft of the target.
		if p != target and feats().has_feat(p, "protection") and feats().wields_shield(p) and _react_ok(p) \
				and e.distance(p, target) <= 5 and e.can_see(p, c):
			var pr := p
			out.append({"kind": "protection", "reactor": p, "trigger": c.id, "title": "Reaction: Protection?",
				"text": "%s attacks %s beside %s. Interpose the shield: Disadvantage on this attack and on others against %s until %s's next turn." % [c.name(), target.name(), p.name(), target.name(), p.name()],
				"still": func() -> bool: return _react_ok(pr),
				"use": func() -> void:
					pr.reaction_available = false
					dis.append("Protection (%s)" % pr.name())
					e.add_mark({"kind": "disadvantage_against", "target": target.id, "guard": pr.id, "source": "Protection (%s)" % pr.name(),
						"expires_owner": pr.id, "expires_phase": "start"})
					e.log.add("reaction", "%s interposes a shield in front of %s" % [pr.name(), target.name()], pr.id)})
	# Lucky: the target spends a Luck Point to give an attack against it Disadvantage (no Reaction).
	if target.creature is Character and feats().has_feat(target, "lucky") and (target.creature as Character).resource_left("luck_points") > 0:
		out.append({"kind": "lucky", "reactor": target, "trigger": c.id, "title": "Lucky?",
			"text": "%s attacks %s. Spend a Luck Point to give the roll Disadvantage?" % [c.name(), target.name()],
			"cost": "A Luck Point (%d left)" % (target.creature as Character).resource_left("luck_points"),
			"use": func() -> void:
				(target.creature as Character).spend_resource("luck_points")
				dis.append("Lucky (%s)" % target.name())
				e.log.add("info", "%s spends a Luck Point: Disadvantage on the attack" % target.name(), target.id)})
	return out


# --- After the attacker misses ----------------------------------------------------------------------

## Ways to turn the attacker's own miss into a hit: Precision Attack (+ a Superiority Die), Guided Strike (+10, the
## War cleric's Channel Divinity, a Reaction for another's attack), Peerless Aim (Boon of Combat Prowess).
func after_miss_attacker(st: Dictionary) -> Array:
	var e := enc()
	st["stage"] = "roll"
	var c := st["c"] as Combatant
	var t := st["t"] as D20Test
	var ac := int(st["ac"])
	var out: Array = []
	if t.natural_one:
		return out
	out.append_array(e.items.specials.fr.after_miss_offers(st))
	if c.creature is Character:
		var ch := c.creature as Character
		var die := feats().superiority_die(c)
		if die > 0 and feats().knows_maneuver(c, "precision_attack") and ch.resource_left("superiority_dice") > 0 and t.total + die >= ac:
			out.append({"kind": "precision_attack", "reactor": c, "title": "Precision Attack?",
				"text": "%d vs AC %d: a miss. Add a Superiority Die (d%d) to the roll?" % [t.total, ac, die], "cost": "A Superiority Die",
				"still": func() -> bool: return not t.success,
				"use": func() -> void:
					ch.spend_resource("superiority_dice")
					var v := e.dice.roll_one(die, "Precision Attack")
					t.add_bonus(v, "Precision Attack")
					e.log.add("info", "%s uses Precision Attack: +%d" % [c.name(), v], c.id)})
		var pdie := feats().psionic_die(c)
		if pdie > 0 and CombatFeatures.has_feature(c, "soul_blades") and str((st["option"] as Dictionary).get("kind", "")) == "blade" \
				and ch.resource_left("psionic_energy") > 0 and t.total + pdie >= ac:
			out.append({"kind": "homing_strikes", "reactor": c, "title": "Homing Strikes?",
				"text": "%d vs AC %d: a miss. Roll a Psionic Energy Die (d%d) and add it (spent only if it hits)?" % [t.total, ac, pdie], "cost": "A Psionic Energy Die if it hits",
				"still": func() -> bool: return not t.success,
				"use": func() -> void:
					var v := e.dice.roll_one(pdie, "Homing Strikes")
					if t.total + v >= ac:
						ch.spend_resource("psionic_energy")
						t.add_bonus(v, "Homing Strikes")
					e.log.add("info", "%s's blade homes in: +%d" % [c.name(), v], c.id)})
		if CombatFeatures.has_feature(c, "guided_strike") and ch.resource_left("channel_divinity") > 0 and t.total + 10 >= ac:
			out.append({"kind": "guided_strike", "reactor": c, "title": "Guided Strike?",
				"text": "%d vs AC %d: a miss. Channel Divinity for +10?" % [t.total, ac], "cost": "A use of Channel Divinity",
				"still": func() -> bool: return not t.success,
				"use": func() -> void:
					ch.spend_resource("channel_divinity")
					t.add_bonus(10, "Guided Strike")
					e.log.add("info", "%s's god guides the strike: +10" % c.name(), c.id)})
		if feats().has_feat(c, "boon_of_combat_prowess") and ch.resource_left("peerless_aim") > 0:
			out.append({"kind": "peerless_aim", "reactor": c, "title": "Peerless Aim?",
				"text": "%d vs AC %d: a miss. Turn it into a hit?" % [t.total, ac], "cost": "Peerless Aim (once until your next turn)",
				"still": func() -> bool: return not t.success,
				"use": func() -> void:
					ch.spend_resource("peerless_aim")
					t.add_bonus(maxi(0, ac - t.total), "Peerless Aim")})
	# A War cleric within 30 ft can spend its Reaction and Channel Divinity on someone else's miss.
	for p in e.allies_of(c):
		if not p.creature is Character or not CombatFeatures.has_feature(p, "guided_strike"):
			continue
		var pc := p.creature as Character
		if pc.resource_left("channel_divinity") <= 0 or not _react_ok(p) or e.distance(p, c) > 30 or t.total + 10 < ac:
			continue
		var pp := p
		out.append({"kind": "guided_strike", "reactor": p, "trigger": c.id, "title": "Reaction: Guided Strike?",
			"text": "%s misses (%d vs AC %d). %s can spend a Reaction and Channel Divinity for +10." % [c.name(), t.total, ac, p.name()],
			"cost": "Reaction and a use of Channel Divinity",
			"still": func() -> bool: return not t.success and _react_ok(pp),
			"use": func() -> void:
				pp.reaction_available = false
				pc.spend_resource("channel_divinity")
				t.add_bonus(10, "Guided Strike (%s)" % pp.name())
				e.log.add("reaction", "%s guides %s's strike: +10" % [pp.name(), c.name()], pp.id)})
	return out


# --- After a hit, before damage -------------------------------------------------------------------

## Reactions that can turn a hit into a miss: Shield (+5 AC), Defensive Duelist (+PB AC with a Finesse weapon in
## hand, melee attacks), Illusory Self (Illusionist 10). `miss` finishes the attack as a miss.
func after_hit_target(st: Dictionary, miss: Callable) -> Array:
	var e := enc()
	st["stage"] = "hit"
	var c := st["c"] as Combatant
	var target := st["target"] as Combatant
	var t := st["t"] as D20Test
	var ac := int(st["ac"])
	var critical := bool(st["critical"])
	var melee := bool((st["option"] as Dictionary)["melee"])
	var out: Array = []
	e.class_features.after_hit_target(st, miss, out)
	e.ravenloft.after_hit_target(st, miss, out)
	e.faerun.after_hit_target(st, miss, out)
	for sid in e.spells.incoming_roll_responses(target):
		var spell_id := sid
		var name := str(Compendium.shared().spell_data(sid)["name"])
		out.append({"kind": sid, "reactor": target, "trigger": c.id, "title": "Reaction: %s?" % name,
			"text": "Replace the triggering attack's roll with 1.", "cost": "Reaction and a spell slot",
			"still": func() -> bool: return t.success and e.spells.can_cast_reaction(target, spell_id),
			"use": func() -> void:
				e.spells.answer_incoming_roll(target, t, spell_id)
				st["critical"] = t.critical,
			"stop_if": func() -> bool: return not t.success,
			"stop": miss})
	if not critical and t.total < ac + 5 and e.spells.can_cast_reaction(target, "shield"):
		out.append({"kind": "shield", "reactor": target, "trigger": c.id, "title": "Reaction: Shield?",
			"text": "%s hits %s: %d vs AC %d. Shield gives +5 AC until the start of %s's next turn (AC %d), so this attack misses." % [c.name(), target.name(), t.total, ac, target.name(), ac + 5],
			"cost": "Reaction and a level 1 spell slot",
			"use": func() -> void: st["shield_cast"] = e.spells.cast_shield(target),
			"stop_if": func() -> bool: return bool(st.get("shield_cast", false)),
			"stop": func() -> CombatResult:
				st["ac"] = ac + 5
				return miss.call() as CombatResult})
	elif target.is_player_controlled() and e.spells.can_cast_reaction(target, "shield") and e._reaction_decision(target, "shield") != "never":
		# Shield isn't offered against a hit its +5 can't turn aside: the hit's details say so.
		(st["details"] as Array[String]).append("No Shield: %s" % ("a Critical Hit" if critical else "%d beats AC %d even with +5" % [t.total, ac + 5]))
	if melee and target.creature is Character and feats().has_feat(target, "defensive_duelist") and feats().holds_finesse(target) \
			and _react_ok(target) and t.total < ac + target.creature.proficiency_bonus():
		var pb := target.creature.proficiency_bonus()
		out.append({"kind": "defensive_duelist", "reactor": target, "trigger": c.id, "title": "Reaction: Parry (Defensive Duelist)?",
			"text": "%s hits %s: %d vs AC %d. Parrying adds +%d AC against melee attacks until your next turn, so this misses." % [c.name(), target.name(), t.total, ac, pb, ],
			"use": func() -> void:
				target.reaction_available = false
				var fx := Effect.new("Parry (Defensive Duelist)", &"feature", "defensive_duelist").with_modifier("ac", {"value": pb})
				fx.ends = Effect.Ends.START_OF_TURN
				fx.turn_owner_id = target.id
				target.creature.add_effect(fx)
				e.log.add("reaction", "%s parries (+%d AC)" % [target.name(), pb], target.id),
			"stop": func() -> CombatResult:
				st["ac"] = ac + pb
				return miss.call() as CombatResult})
	if target.creature is Character and CombatFeatures.has_feature(target, "illusory_self") and _react_ok(target):
		var ch := target.creature as Character
		var free := ch.resource_left("illusory_self") > 0
		var slot := 0
		if not free:
			for l in range(2, 10):
				if ch.slots_left(l) > 0:
					slot = l
					break
		if free or slot > 0:
			out.append({"kind": "illusory_self", "reactor": target, "trigger": c.id, "title": "Reaction: Illusory Self?",
				"text": "%s hits %s. An illusory duplicate takes the hit instead: the attack misses." % [c.name(), target.name()],
				"cost": "Reaction%s" % (" and a level %d slot" % slot if not free else ""),
				"use": func() -> void:
					target.reaction_available = false
					if free:
						ch.spend_resource("illusory_self")
					else:
						ch.expend_slot(slot)
					e.log.add("reaction", "%s's illusory double takes the blow" % target.name(), target.id),
				"stop": func() -> CombatResult: return miss.call() as CombatResult})
	return out


# --- After a miss against the target -----------------------------------------------------------------

## Riposte (Battle Master): when a creature misses you with a melee attack, a Reaction and a Superiority Die for a
## melee attack back, adding the die to its damage. Runs after the miss is resolved.
func after_miss_target(st: Dictionary) -> Array:
	var e := enc()
	st["stage"] = "missed"
	var c := st["c"] as Combatant
	var target := st["target"] as Combatant
	var out: Array = []
	if not bool((st["option"] as Dictionary)["melee"]) or not target.creature is Character or not c.is_alive():
		return out
	var ch := target.creature as Character
	var die := feats().superiority_die(target)
	if die > 0 and feats().knows_maneuver(target, "riposte") and ch.resource_left("superiority_dice") > 0 and _react_ok(target):
		var opt := e.best_melee_option(target, c)
		if not opt.is_empty() and e.attack_legal(target, c, opt) == "":
			out.append({"kind": "riposte", "reactor": target, "trigger": c.id, "title": "Reaction: Riposte?",
				"text": "%s misses %s. Strike back with a melee attack, adding a Superiority Die (d%d) to the damage?" % [c.name(), target.name(), die],
				"cost": "Reaction and a Superiority Die",
				"use": func() -> void:
					target.reaction_available = false
					ch.spend_resource("superiority_dice")
					e.log.add("reaction", "%s ripostes" % target.name(), target.id)
					st["riposte"] = {"by": target, "option": opt, "die": die}})
	return out


# --- Against the damage -----------------------------------------------------------------------------

## Ways to cut an attack's damage. `parts` is the damage by type (changed in place); `notes` collects log text.
func against_damage(st: Dictionary, parts: Dictionary, notes: Array[String]) -> Array:
	var e := enc()
	st["stage"] = "damage"
	var c := st["c"] as Combatant
	var target := st["target"] as Combatant
	var melee := bool((st["option"] as Dictionary)["melee"])
	var out: Array = []
	var total := func() -> int:
		var n := 0
		for k: String in parts:
			n += int(parts[k])
		return n
	var cut := func(amount: int, why: String) -> void:
		var left := amount
		for k: String in parts:
			var take := mini(left, int(parts[k]))
			parts[k] = int(parts[k]) - take
			left -= take
		notes.append("%s: −%d" % [why, amount - left])
	if int(total.call()) <= 0:
		return out
	e.class_features.against_damage(st, total, cut, out)
	e.ravenloft.against_damage(st, total, cut, out)
	e.items.against_damage(st, total, cut, out)
	if target.creature.has_flag("uncanny_dodge") and _react_ok(target) and e.can_see(target, c):
		out.append({"kind": "uncanny_dodge", "reactor": target, "trigger": c.id, "title": "Reaction: Uncanny Dodge?",
			"text": "%s hits %s for %d damage. Uncanny Dodge halves it (%d)." % [c.name(), target.name(), total.call(), int(total.call()) / 2],
			"still": func() -> bool: return _react_ok(target) and int(total.call()) > 0,
			"use": func() -> void:
				target.reaction_available = false
				for k: String in parts:
					parts[k] = int(parts[k]) / 2
				notes.append("Uncanny Dodge: damage halved")})
	if target.creature is Character:
		var ch := target.creature as Character
		var die := feats().superiority_die(target)
		if melee and die > 0 and feats().knows_maneuver(target, "parry") and ch.resource_left("superiority_dice") > 0:
			var mod := maxi(target.creature.ability_mod(&"str"), target.creature.ability_mod(&"dex"))
			out.append({"kind": "parry", "reactor": target, "trigger": c.id, "title": "Reaction: Parry?",
				"text": "%s hits %s for %d. Parry: reduce it by a Superiority Die (d%d) + %d." % [c.name(), target.name(), total.call(), die, mod],
				"cost": "Reaction and a Superiority Die",
				"still": func() -> bool: return _react_ok(target) and int(total.call()) > 0,
				"use": func() -> void:
					target.reaction_available = false
					ch.spend_resource("superiority_dice")
					cut.call(e.dice.roll_one(die, "Parry") + mod, "Parry")})
		if CombatFeatures.has_feature(target, "stones_endurance") and ch.resource_left("giant_ancestry") > 0:
			out.append({"kind": "stones_endurance", "reactor": target, "trigger": c.id, "title": "Reaction: Stone's Endurance?",
				"text": "%s hits %s for %d. Reduce it by 1d12 + %d (Con)." % [c.name(), target.name(), total.call(), target.creature.ability_mod(&"con")],
				"cost": "Reaction and a use of Giant Ancestry",
				"still": func() -> bool: return _react_ok(target) and int(total.call()) > 0,
				"use": func() -> void:
					target.reaction_available = false
					ch.spend_resource("giant_ancestry")
					cut.call(e.dice.roll_one(12, "Stone's Endurance") + target.creature.ability_mod(&"con"), "Stone's Endurance")})
	for p in e.allies_of(target):
		if not p.creature is Character or not _react_ok(p):
			continue
		var pc := p.creature as Character
		var pp := p
		if feats().has_feat(p, "interception") and e.distance(p, target) <= 5 and (feats().wields_shield(p) or feats().holds_weapon(p)):
			out.append({"kind": "interception", "reactor": p, "trigger": c.id, "title": "Reaction: Interception?",
				"text": "%s hits %s for %d. %s can reduce it by 1d10 + %d." % [c.name(), target.name(), total.call(), p.name(), p.creature.proficiency_bonus()],
				"still": func() -> bool: return _react_ok(pp) and int(total.call()) > 0,
				"use": func() -> void:
					pp.reaction_available = false
					cut.call(e.dice.roll_one(10, "Interception") + pp.creature.proficiency_bonus(), "Interception (%s)" % pp.name())})
		var pdie := feats().psionic_die(p)
		if pdie > 0 and CombatFeatures.has_feature(p, "psionic_power") and pc.subclasses.get("fighter", "") == "psi_warrior" \
				and pc.resource_left("psionic_energy") > 0 and e.distance(p, target) <= 30:
			out.append({"kind": "protective_field", "reactor": p, "trigger": c.id, "title": "Reaction: Protective Field?",
				"text": "%s hits %s for %d. %s can reduce it by a Psionic Energy Die (d%d) + %d." % [c.name(), target.name(), total.call(), p.name(), pdie, maxi(1, p.creature.ability_mod(&"int"))],
				"cost": "Reaction and a Psionic Energy Die",
				"still": func() -> bool: return _react_ok(pp) and int(total.call()) > 0,
				"use": func() -> void:
					pp.reaction_available = false
					pc.spend_resource("psionic_energy")
					cut.call(maxi(1, e.dice.roll_one(pdie, "Protective Field") + pp.creature.ability_mod(&"int")), "Protective Field (%s)" % pp.name())})
	# Projected Ward (Abjurer 6): the Arcane Ward soaks damage to a creature within 30 ft.
	for p2 in e.allies_of(target):
		if p2.creature.ward_hp > 0 and CombatFeatures.has_feature(p2, "projected_ward") and _react_ok(p2) and e.distance(p2, target) <= 30:
			var pw := p2
			out.append({"kind": "projected_ward", "reactor": p2, "trigger": c.id, "title": "Reaction: Projected Ward?",
				"text": "%s hits %s for %d. %s's Arcane Ward (%d Hit Points) can take the damage instead." % [c.name(), target.name(), total.call(), p2.name(), p2.creature.ward_hp],
				"still": func() -> bool: return _react_ok(pw) and pw.creature.ward_hp > 0 and int(total.call()) > 0,
				"use": func() -> void:
					pw.reaction_available = false
					var soak := mini(pw.creature.ward_hp, int(total.call()))
					pw.creature.ward_hp -= soak
					cut.call(soak, "Projected Ward (%s)" % pw.name())})
	var responded: Array = []
	var incoming := func() -> int:
		var packet: Array = []
		for type: String in parts:
			packet.append({"amount": int(parts[type]), "type": type})
		return int(total.call()) if target.creature.preview_damage_parts(packet).final > 0 else 0
	out.append_array(e.damage_responses.offers(target, incoming, cut, responded))
	e.faerun.against_damage(st, parts, incoming, cut, out, responded)
	out.append_array(e.spells.reaction_spells.absorb_offers(target, c, parts, responded))
	st["damage_responses"] = responded
	# Psi Warrior protecting itself.
	if target.creature is Character:
		var tc := target.creature as Character
		var tdie := feats().psionic_die(target)
		if tdie > 0 and tc.subclasses.get("fighter", "") == "psi_warrior" and tc.resource_left("psionic_energy") > 0:
			out.append({"kind": "protective_field", "reactor": target, "trigger": c.id, "title": "Reaction: Protective Field?",
				"text": "%s hits %s for %d. Reduce it by a Psionic Energy Die (d%d) + %d." % [c.name(), target.name(), total.call(), tdie, maxi(1, target.creature.ability_mod(&"int"))],
				"cost": "Reaction and a Psionic Energy Die",
				"still": func() -> bool: return _react_ok(target) and int(total.call()) > 0,
				"use": func() -> void:
					target.reaction_available = false
					tc.spend_resource("psionic_energy")
					cut.call(maxi(1, e.dice.roll_one(tdie, "Protective Field") + target.creature.ability_mod(&"int")), "Protective Field")})
	return out


## Response spells and Reaction-cost feature recipes that also have synchronous trigger paths.
func configurable_policies(c: Combatant) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	if not c.creature is Character:
		return out
	var seen := {}
	# Divine Smite, the 2014 way (CombatFeatures.smite_offers): asked after each melee hit, used on every one, or only
	# when armed on the hotbar.
	if enc().spells.castable(c).any(func(k: Dictionary) -> bool: return str(k["id"]) == CombatFeatures.DIVINE_SMITE):
		seen[CombatFeatures.DIVINE_SMITE] = true
		out.append({"id": CombatFeatures.DIVINE_SMITE, "name": "Divine Smite", "cost": "A spell slot", "modes": ["ask", "auto", "never"], "default": "ask",
			"help": "Ask: after each melee hit you're asked whether to smite. Automatic: every melee hit smites while spell slots last. Off: only when armed on the Spells tab (then every hit that turn)."})
	for known in (c.creature as Character).known_spells():
		var spell := Compendium.shared().spell_data(str(known["id"]))
		# A spell that acts on its own once allowed (Alustriel's Mooncloak's Reaction): Automatic or Off.
		if spell.has("policy") and not seen.has(str(spell["id"])):
			seen[str(spell["id"])] = true
			out.append({"id": str(spell["id"]), "name": str(spell["name"]), "cost": "Your Reaction" + (" and a spell slot" if str(spell["id"]) in ["backlash", "absorb_elements"] else ""),
				"modes": spell.get("policy_modes", ["auto", "never"]), "default": str(spell["policy"])})
			continue
		# Counterspell: asked about when a foe's Counterspell would stop a spell of the party's (SpellCounters).
		if str(spell["id"]) == "counterspell" and not seen.has("counterspell"):
			seen["counterspell"] = true
			out.append({"id": "counterspell", "name": "Counterspell", "cost": "Reaction and a spell slot", "modes": ["ask", "auto", "never"], "default": "ask",
				"help": "When a foe's Counterspell would stop a spell of your side's (or a Counterspell of yours), you can Counterspell it. Ask: you're asked each time. Automatic: you do whenever you can, and are still asked when there's more than one way to pay (which slot, or a free casting). Off: never."})
			continue
		if not spell.has("roll_response") or seen.has(str(spell["id"])):
			continue
		seen[str(spell["id"])] = true
		out.append({"id": str(spell["id"]), "name": str(spell["name"]), "cost": "Reaction and a spell slot"})
	for f in (c.creature as Character).features:
		# A feature that acts on its own (Rallying Cry, Family First, Stand as One): Automatic or Off.
		if f.has("policy") and not seen.has(str(f["id"])):
			seen[str(f["id"])] = true
			out.append({"id": str(f["id"]), "name": str(f["name"]), "cost": str(f.get("policy_cost", "Uses the feature")),
				"modes": f.get("policy_modes", ["auto", "never"]), "default": str(f["policy"])})
			continue
		var response := f.get("roll_response", {}) as Dictionary
		if not f.has("hit_response") and (response.is_empty() or str(response.get("cost", "free")) != "reaction"):
			continue
		if seen.has(str(f["id"])):
			continue
		seen[str(f["id"])] = true
		out.append({"id": str(f["id"]), "name": str(f["name"]), "cost": "Reaction and a feature use"})
	# Guidance before a party member's skill check outside fights (story/guidance_offer.gd): the caster's standing
	# answer to its prompt, kept here with the rest.
	if (c.creature as Character).knows_spell("guidance") and not seen.has("guidance"):
		seen["guidance"] = true
		out.append({"id": "guidance", "name": "Guidance before checks", "cost": "Nothing (a cantrip)", "modes": ["ask", "auto", "never"],
			"default": "ask",
			"help": "Outside fights, before someone in the party makes a skill check (in a conversation, on something in the world, searching, forcing a lock, haggling). Ask: you're asked whether to cast Guidance on them first (+1d4). Automatic: cast whenever you aren't concentrating on another spell, which it would end. Off: never offered."})
	# Knocking Out a Creature (2024): anyone's melee blow can leave a creature Unconscious at 1 Hit Point instead of 0.
	# Repelling Blast (2024: a warlock cantrip's hit "can" push the creature 10 ft): pushing is the default; Off keeps a
	# foe where it stands (owner, 2026-10-12), changeable on any turn. Not a reaction: its toggle sits on the class tab
	# (`class_tab`; Ashwin, 2026-10-13), Grasp of Hadar's beside it.
	if ClassFeatures.knows_invocation(c, "repelling_blast"):
		out.append({"id": "repelling_blast", "name": "Repelling Blast", "cost": "Nothing", "modes": ["auto", "never"], "default": "auto", "class_tab": true,
			"help": "On: a hit with Eldritch Blast (or another damaging Warlock cantrip's attack) pushes a Large or smaller creature 10 ft away from you. Off: no push, for when you'd rather it stayed where it is."})
		seen["repelling_blast"] = true
	# Grasp of Hadar (Ashwin's house rule, 2026-10-13: Repelling Blast's mirror) pulls the creature 10 ft toward you. Beside
	# Repelling Blast it starts Off, and turning either on turns the other off (set_policy; ClassFeatures.blast_rule).
	if ClassFeatures.knows_invocation(c, "grasp_of_hadar"):
		out.append({"id": "grasp_of_hadar", "name": "Grasp of Hadar", "cost": "Nothing", "modes": ["auto", "never"], "class_tab": true,
			"default": ClassFeatures.blast_rule(c, "grasp_of_hadar"),
			"help": "On: a hit with Eldritch Blast (or another damaging Warlock cantrip's attack) pulls a Large or smaller creature 10 ft straight toward you. Off: no pull. With Repelling Blast as well, only one of the two is on at a time."})
		seen["grasp_of_hadar"] = true
	out.append({"id": "knock_out", "name": "Knock Out", "cost": "Nothing", "modes": ["auto", "never"], "default": "never",
		"help": "Automatic: a melee attack that would drop a creature to 0 Hit Points leaves it at 1 and Unconscious instead, until it finishes a Short Rest, regains Hit Points or gets first aid; a foe knocked out can be taken captive once the fight is won. Off: blows land as usual."})
	seen["knock_out"] = true
	# The choices after a D20 Test this creature can make (Indomitable, Heroic Inspiration, Bend Luck...).
	for policy in enc().d20.policies(c):
		if not seen.has(str(policy["id"])):
			seen[str(policy["id"])] = true
			out.append(policy)
	return out

## One entry per mode of each rule (`feat:reaction_policy:<id>:<mode>`); the hotbar folds a rule's modes into one toggle
## slot (ActionCatalog.slots) by `policy`, and `selected` marks the one in force. A rule changes on any turn (`anytime`):
## nothing is spent. A class feature's own switch (`class_tab`) reads On / Off.
func list_policies(c: Combatant, out: Array[Dictionary]) -> void:
	for policy in configurable_policies(c):
		var current := str(c.reaction_rules.get(str(policy["id"]), policy["default"])) if policy.has("default") else enc()._reaction_decision(c, str(policy["id"]))
		var names := {"ask": "Ask", "auto": "On" if bool(policy.get("class_tab", false)) else "Automatic", "never": "Off"}
		for mode: String in policy.get("modes", ["ask", "auto", "never"]):
			out.append({"id": "feat:reaction_policy:%s:%s" % [policy["id"], mode],
				"label": "%s: %s" % [policy["name"], names[mode]],
				"sub": str(names[mode]) + (" · selected" if current == mode else ""),
				"policy": str(policy["id"]), "policy_name": str(policy["name"]), "mode": mode, "mode_label": str(names[mode]),
				"selected": current == mode, "anytime": true, "class_tab": bool(policy.get("class_tab", false)),
				"cost": "free", "why": "", "targeting": "none", "range": 0,
				"help": str(policy["help"]) if policy.has("help") else ("%s. Automatic: it happens whenever it can. Off: never." % policy["cost"]) if policy.has("default") and not "ask" in (policy.get("modes", []) as Array) else \
					("%s. Automatic permits spending whenever eligible. Ask prompts where supported; synchronous rolls/spell hits do not spend until you choose Automatic. Off never spends." % policy["cost"])})

func set_policy(c: Combatant, id: String, mode: String) -> CombatResult:
	if not mode in ["ask", "auto", "never"] \
			or not configurable_policies(c).any(func(p: Dictionary) -> bool: return str(p["id"]) == id and mode in p.get("modes", ["ask", "auto", "never"])):
		return CombatResult.fail("Not an available reaction preference")
	# Repelling Blast and Grasp of Hadar move a creature one way a hit: turning one on turns the other off, and turning one
	# off leaves the other as it was.
	var other := str(ClassFeatures.BLAST_PAIR.get(id, ""))
	if other != "" and ClassFeatures.knows_invocation(c, other):
		c.reaction_rules[other] = "never" if mode == "auto" else ClassFeatures.blast_rule(c, other)
	c.reaction_rules[id] = mode
	return CombatResult.new()
