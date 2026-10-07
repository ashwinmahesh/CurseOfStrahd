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

var _enc: WeakRef


func _init(encounter: Encounter) -> void:
	_enc = weakref(encounter)


func enc() -> Encounter:
	return _enc.get_ref() as Encounter


func feats() -> CombatFeatures:
	return enc().features


## Runs the offers in `chain` one after another, then `done`. Pauses on each one the player is asked about.
func offer(chain: Array, done: Callable, r: CombatResult) -> CombatResult:
	var e := enc()
	while not chain.is_empty():
		var o := chain.pop_front() as Dictionary
		var reactor := o["reactor"] as Combatant
		if o.has("still") and not (o["still"] as Callable).call():
			continue
		var kind := str(o["kind"])
		var decision := e._reaction_decision(reactor, kind)
		if decision == "never":
			continue
		if decision == "auto":
			(o["use"] as Callable).call()
			if o.has("stop") and (not o.has("stop_if") or (o["stop_if"] as Callable).call()):
				return (o["stop"] as Callable).call() as CombatResult
			continue
		var req := ReactionRequest.new(kind, reactor.id, str(o.get("trigger", "")))
		req.title = str(o["title"])
		req.text = str(o["text"])
		req.cost = str(o.get("cost", "Reaction"))
		req.spends_reaction = bool(o.get("spends_reaction", true))
		req.target_choices.assign(o.get("target_choices", []))
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
			return offer(rest, done, r)
		e.pending = req
		r.pending = req
		return r
	return done.call() as CombatResult


func _react_ok(c: Combatant) -> bool:
	return enc().spells.can_react(c)


# --- Before the attack roll -------------------------------------------------------------------------

## st: the attack's state {c, target, option, sit, ...}; offers add to st["sit"] advantage/disadvantage.
func before_roll(st: Dictionary) -> Array:
	var e := enc()
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
	var c := st["c"] as Combatant
	var t := st["t"] as D20Test
	var ac := int(st["ac"])
	var out: Array = []
	if t.natural_one:
		return out
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
	var c := st["c"] as Combatant
	var target := st["target"] as Combatant
	var t := st["t"] as D20Test
	var ac := int(st["ac"])
	var critical := bool(st["critical"])
	var melee := bool((st["option"] as Dictionary)["melee"])
	var out: Array = []
	e.class_features.after_hit_target(st, miss, out)
	e.ravenloft.after_hit_target(st, miss, out)
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
	for known in (c.creature as Character).known_spells():
		var spell := Compendium.shared().spell_data(str(known["id"]))
		if not spell.has("roll_response") or seen.has(str(spell["id"])):
			continue
		seen[str(spell["id"])] = true
		out.append({"id": str(spell["id"]), "name": str(spell["name"]), "cost": "Reaction and a spell slot"})
	for f in (c.creature as Character).features:
		var response := f.get("roll_response", {}) as Dictionary
		if not f.has("hit_response") and (response.is_empty() or str(response.get("cost", "free")) != "reaction"):
			continue
		if seen.has(str(f["id"])):
			continue
		seen[str(f["id"])] = true
		out.append({"id": str(f["id"]), "name": str(f["name"]), "cost": "Reaction and a feature use"})
	return out

func list_policies(c: Combatant, out: Array[Dictionary]) -> void:
	for policy in configurable_policies(c):
		for mode: String in ["ask", "auto", "never"]:
			out.append({"id": "feat:reaction_policy:%s:%s" % [policy["id"], mode],
				"label": "%s: %s" % [policy["name"], {"ask": "Ask", "auto": "Automatic", "never": "Off"}[mode]],
				"sub": str({"ask": "Ask", "auto": "Automatic", "never": "Off"}[mode]) + (" · selected" if enc()._reaction_decision(c, str(policy["id"])) == mode else ""),
				"cost": "free", "why": enc()._turn_check(c), "targeting": "none", "range": 0,
				"help": "%s. Automatic permits spending whenever eligible. Ask prompts where supported; synchronous rolls/spell hits do not spend until you choose Automatic. Off never spends." % policy["cost"]})

func set_policy(c: Combatant, id: String, mode: String) -> CombatResult:
	if enc()._turn_check(c) != "" or not mode in ["ask", "auto", "never"] \
			or not configurable_policies(c).any(func(p: Dictionary) -> bool: return str(p["id"]) == id):
		return CombatResult.fail("Not an available reaction preference")
	c.reaction_rules[id] = mode
	return CombatResult.new()
