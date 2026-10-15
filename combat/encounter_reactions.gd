class_name EncounterReactions
extends RefCounted
## How reactions run in a fight (Encounter): whether a creature reacts (the player's rule for it, or the AI), the
## player's answer to a prompt, and the reactions and Cleave attacks that wait until the current attack or spell is done
## (Hellish Rebuke, Sentinel).

var _enc: WeakRef


func _init(encounter: Encounter) -> void:
	_enc = weakref(encounter)


func enc() -> Encounter:
	return _enc.get_ref() as Encounter


## Prompt text for the queued reactions: [title, text naming the trigger and then the reactor, what it costs].
const _QUEUED_TEXT := {
	"hellish_rebuke": ["Reaction: Hellish Rebuke?", "%s hurt %s. Answer with Hellish Rebuke: a Dex save or Fire damage.", "Reaction and a spell slot"],
	"storms_thunder": ["Reaction: Storm's Thunder?", "%s hurt %s. Answer with 1d8 Thunder damage.", "Reaction and a use of Giant Ancestry"],
	"sentinel": ["Reaction: Sentinel?", "%s, beside %s, hits someone else. Make an Opportunity Attack against it?", "Reaction"],
	"retaliation": ["Reaction: Retaliation?", "%s hurt %s. Strike back with a melee attack?", "Reaction"],
	"misty_escape": ["Reaction: Misty Escape?", "%s hurt %s. Vanish with Misty Step (Steps of the Fey or a slot)?", "Reaction and a use of Steps of the Fey"],
	"fount_of_moonlight": ["Reaction: Fount of Moonlight?", "%s hurt %s. Flare moonlight at it: a Constitution save or Blinded?", "Reaction"],
	"berserk_lashing": ["Reaction: Berserk Lashing?", "%s hurt %s. Lash out with a Slam at a random creature within 5 ft?", "Reaction"],
}


## What a creature does with a Reaction opportunity: AI creatures always take Opportunity Attacks; players
## follow their per-reaction rule (plan §5.3), default "ask" (or `fallback`, a feature's own starting rule).
func _reaction_decision(reactor: Combatant, kind: String, fallback: String = "") -> String:
	var e := enc()
	if not reactor.is_player_controlled():
		return "auto" if e.ai.wants_reaction(reactor, kind) else "never"
	return str(reactor.reaction_rules.get(kind, fallback if fallback != "" else e.default_player_reaction))


## Answers the pending reaction prompt and continues whatever was paused.
func answer_reaction(use: bool) -> CombatResult:
	var e := enc()
	if e.pending == null:
		return CombatResult.fail("No reaction is waiting")
	var req := e.pending
	if use:
		var reason := req.selection_error()
		if reason != "":
			var invalid := CombatResult.fail(reason)
			invalid.pending = req
			return invalid
	e.pending = null
	var verbs := ["uses its Reaction", "holds its Reaction"]
	if req.kind == "heroic_inspiration":
		verbs = ["spends Heroic Inspiration", "keeps Heroic Inspiration"]
	elif not req.spends_reaction:
		verbs = ["confirms " + req.title, "declines " + req.title]
	elif req.kind == Reactions.CHOICE and use and req.selected_ids[0].begins_with("later:"):
		verbs[0] = "keeps its Reaction for %s" % str(req.choice(req.selected_ids[0]).get("label", "later"))
	e.log.add("reaction" if req.spends_reaction else "info", "%s %s" % [e.get_c(req.reactor_id).name(), verbs[0] if use else verbs[1]], req.reactor_id)
	var res := req.continuation.call(use) as CombatResult
	req.continuation = Callable()
	req.validate_selected = Callable()
	res.pending = e.pending
	return res


## Hellish Rebuke's prompt (owner report 2026-10-12: a level 6 warlock's looked like a 1st-level cast): the damage at
## each slot level `reactor` could spend, picked on the prompt, the lowest first; a warlock's one pact level is named.
## A free casting left (a tiefling's, once a Long Rest) is a pick too ("free"), first unless it waits for the pact slots
## (SpellReactions.free_first).
func _rebuke_levels(req: ReactionRequest, reactor: Combatant) -> void:
	var e := enc()
	var ch := reactor.creature as Character
	if ch == null:
		return
	var levels := SpellReactions.slot_levels(ch, 1)
	var rs := e.spells.reaction_spells
	var free_at := rs.free_level(reactor, "hellish_rebuke") if rs.free_casting(reactor, "hellish_rebuke") else 0
	if levels.is_empty() and free_at == 0:
		return
	var pact := int(ch.pact_magic()["level"])
	if levels.is_empty():
		req.cost = "Reaction and its free casting (no spell slot)"
		req.text += " At level %d: %dd10 Fire, half on a save." % [free_at, free_at + 1]
		return
	if levels.size() == 1 and free_at == 0:
		req.cost = "Reaction and a level %d spell slot%s" % [levels[0], " (Pact Magic)" if levels[0] == pact else ""]
		req.text += " At level %d: %dd10 Fire, half on a save." % [levels[0], levels[0] + 1]
		return
	req.cost = "Reaction and the casting you choose" if free_at > 0 else "Reaction and the spell slot you choose"
	for l in levels:
		req.target_choices.append({"id": str(l), "label": "Level %d slot%s · %dd10 Fire" % [l, " (Pact Magic)" if l == pact else "", l + 1]})
	if free_at > 0:
		var free := {"id": "free", "label": "Free casting, no slot · %dd10 Fire" % (free_at + 1)}
		if rs.free_first(reactor, "hellish_rebuke"):
			req.target_choices.push_front(free)
		else:
			req.target_choices.append(free)
	req.selected_ids.assign([str(req.target_choices[0]["id"])])
	req.min_targets = 1
	req.max_targets = 1


## Reactions to being damaged (Hellish Rebuke, Storm's Thunder) wait until the attack or spell that caused them has
## finished.
func _queue_damage_reactions(source: Combatant, target: Combatant) -> void:
	var e := enc()
	e.ravenloft.queue_damage_reactions(source, target)
	e.faerun.queue_damage_reactions(source, target)
	# Berserk Lashing (Clay Construct Spirit): a Slam at a random creature within 5 ft whenever it takes damage.
	if target.creature is Monster and e.monster_actions.has_trait(target, "berserk_lashing") and e.spells.can_react(target) and target.creature.hp > 0:
		e.reaction_queue.append({"kind": "berserk_lashing", "reactor": target.id, "trigger": source.id})
		return
	if not target.creature is Character or target.creature.hp <= 0 or e.distance(target, source) > 60 or not e.can_see(target, source):
		return
	# Retaliation (Berserker 10): a melee attack back at a creature within 5 ft that hurt you.
	if CombatFeatures.has_feature(target, "retaliation") and e.spells.can_react(target) and e.distance(target, source) <= 5 and not e.best_melee_option(target, source).is_empty():
		e.reaction_queue.append({"kind": "retaliation", "reactor": target.id, "trigger": source.id})
		return
	var cfr := e.class_features.damage_reaction(source, target)
	if not cfr.is_empty():
		e.reaction_queue.append(cfr)
		return
	if target.creature.has_flag("fount_of_moonlight") and e.spells.can_react(target):
		e.reaction_queue.append({"kind": "fount_of_moonlight", "reactor": target.id, "trigger": source.id})
		return
	for q in e.reaction_queue:
		if str(q["reactor"]) == target.id:
			return
	if e.spells.can_cast_reaction(target, "hellish_rebuke"):
		e.reaction_queue.append({"kind": "hellish_rebuke", "reactor": target.id, "trigger": source.id})
	elif CombatFeatures.has_feature(target, "storms_thunder") and (target.creature as Character).resource_left("giant_ancestry") > 0 and e.spells.can_react(target):
		e.reaction_queue.append({"kind": "storms_thunder", "reactor": target.id, "trigger": source.id})


## Sentinel's Guardian: a creature within 5 ft of a Sentinel hits someone else: an Opportunity Attack against it.
func _queue_sentinels(attacker: Combatant, target: Combatant) -> void:
	var e := enc()
	for p in e.hostiles_of(attacker):
		if p == target or not e.features.has_feat(p, "sentinel") or not e.spells.can_react(p) or e.distance(p, attacker) > 5:
			continue
		e.reaction_queue.append({"kind": "sentinel", "reactor": p.id, "trigger": attacker.id})


## A Ready action waiting for an enemy's attack or spell (EncounterActions.READY_TRIGGERS): `actor` just made one, so
## each hostile creature readied for `on` ("attack" or "spell") gets its Reaction once that's done.
func _queue_readied(actor: Combatant, on: String) -> void:
	var e := enc()
	for p in e.hostiles_of(actor):
		if p.readied.is_empty() or str(p.readied.get("trigger", "approach")) != on:
			continue
		if e.reaction_queue.any(func(q: Dictionary) -> bool: return str(q["kind"]) == "readied_attack" and str(q["reactor"]) == p.id):
			continue
		e.reaction_queue.append({"kind": "readied_attack", "reactor": p.id, "trigger": actor.id, "on": on})


## How far a readied attack or spell reaches: the spell's range, or the attack's reach (melee) or normal range.
func readied_reach(p: Combatant) -> int:
	var e := enc()
	if p.readied.has("spell"):
		return e.spells.range_ft(Compendium.shared().spell_data(str(p.readied["spell"])), p)
	var option := e.option_by_id(p, str(p.readied.get("option", "")))
	if option.is_empty():
		return -1
	var prof := option["profile"] as WeaponProfile
	return prof.reach if bool(option["melee"]) else prof.normal_range


## The prompt for a queued readied attack or spell: [title, text (trigger's name, then the reactor's), cost].
func _readied_words(q: Dictionary, reactor: Combatant) -> Array:
	var what := "attack"
	if reactor.readied.has("spell"):
		what = str(Compendium.shared().spell_data(str(reactor.readied["spell"])).get("name", "spell"))
	var did := "attacks" if str(q.get("on", "")) == "attack" else "casts a spell"
	return ["Readied %s?" % ("spell" if reactor.readied.has("spell") else "attack"),
		"%%s %s. %%s readied %s for that: use the Reaction now?" % [did, what if reactor.readied.has("spell") else "an attack"], "Reaction"]


## A readied spell going off (owner's default 2026-10-12): the creatures it can be aimed at now, the one that set it
## off first and picked, as the prompt's one choice; the prompt names the spell. Nothing changes for a readied attack.
func readied_targets(req: ReactionRequest, reactor: Combatant, trigger: Combatant) -> void:
	if not reactor.readied.has("spell"):
		return
	var e := enc()
	var s := Compendium.shared().spell_data(str(reactor.readied["spell"]))
	var slot := int(reactor.readied.get("slot", 0))
	req.title = "Readied %s?" % s.get("name", "spell")
	req.text = "%s set off %s's readied %s: release it now with the Reaction? Pick who it's aimed at." % [trigger.name(), reactor.name(), s.get("name", "spell")]
	var picks: Array[Combatant] = [trigger]
	for o in e.living():
		if o == trigger or o == reactor or o.is_down() or not e.can_see(reactor, o) or e.distance(reactor, o) > readied_reach(reactor):
			continue
		var at := e.center_of(o) if s.has("area") else Vector2.INF
		var aimed: Array = [] if s.has("area") else [o]
		if str(e.spells._check_targets(reactor, s, slot, aimed, at, {})["why"]) == "":
			picks.append(o)
	if picks.size() < 2:
		return
	for o in picks:
		req.target_choices.append({"id": o.id, "label": "%s · %d ft%s" % [o.name(), e.distance(reactor, o), " (set it off)" if o == trigger else ""]})
	req.selected_ids.assign([trigger.id])
	req.min_targets = 1
	req.max_targets = 1


## The creature a readied spell's prompt was aimed at, or `fallback` (the one that set it off).
func readied_aim(req: ReactionRequest, fallback: Combatant) -> Combatant:
	var e := enc()
	var picked := e.get_c(req.selected_ids[0]) if not req.selected_ids.is_empty() else null
	return picked if picked != null and picked.is_alive() else fallback


func _queued_ok(q: Dictionary, reactor: Combatant) -> bool:
	var e := enc()
	if str(q["kind"]).begins_with("rh_"):
		return e.ravenloft.queued_ok(q, reactor)
	if str(q["kind"]).begins_with("fr_"):
		return e.faerun.queued_ok(q, reactor)
	match str(q["kind"]):
		"hellish_rebuke":
			return e.spells.can_cast_reaction(reactor, "hellish_rebuke")
		"storms_thunder":
			return e.spells.can_react(reactor) and (reactor.creature as Character).resource_left("giant_ancestry") > 0
		"sentinel":
			return e.spells.can_react(reactor) and not e.best_melee_option(reactor, null).is_empty()
		"berserk_lashing":
			return e.spells.can_react(reactor) and reactor.creature.hp > 0
		"fount_of_moonlight":
			return e.spells.can_react(reactor) and reactor.creature.has_flag("fount_of_moonlight")
		"misty_escape":
			return e.spells.can_react(reactor) and reactor.creature.hp > 0
		"retaliation":
			return e.spells.can_react(reactor) and reactor.creature.hp > 0 and e.get_c(str(q["trigger"])) != null and e.distance(reactor, e.get_c(str(q["trigger"]))) <= 5
		"readied_attack":
			var foe := e.get_c(str(q["trigger"]))
			var held := reactor.readied.get("conc") as Concentration
			return not reactor.readied.is_empty() and str(reactor.readied.get("trigger", "approach")) == str(q.get("on", "")) \
				and (held == null or not held.ended) and e.spells.can_react(reactor) and foe != null and not foe.is_down() \
				and e.can_see(reactor, foe) and e.distance(reactor, foe) <= readied_reach(reactor)
	return false


func _fire_queued(q: Dictionary, reactor: Combatant, trigger: Combatant) -> CombatResult:
	var e := enc()
	if str(q["kind"]).begins_with("rh_"):
		return e.ravenloft.fire_queued(q, reactor, trigger)
	if str(q["kind"]).begins_with("fr_"):
		return e.faerun.fire_queued(q, reactor, trigger)
	match str(q["kind"]):
		"hellish_rebuke":
			return e.spells.cast_reaction_spell(reactor, "hellish_rebuke", trigger, int(q.get("slot", 0)))
		"storms_thunder":
			reactor.reaction_available = false
			(reactor.creature as Character).spend_resource("giant_ancestry")
			var rolled := e._roll_damage_dice("1d8", false, 0, "Storm's Thunder")
			e.deal_damage(reactor, trigger, [{"amount": int(rolled["total"]), "type": "thunder"}], false, "Storm's Thunder", [str(rolled["text"])])
			return CombatResult.new()
		"sentinel":
			if e.distance(reactor, trigger) > reactor.reach_ft():
				return CombatResult.new()
			return e._opportunity_attack(reactor, trigger)
		"misty_escape":
			return e.class_features.misty_escape(reactor, trigger)
		"retaliation":
			return e._opportunity_attack(reactor, trigger)
		"readied_attack":
			var aim := e.get_c(str(q.get("aim", ""))) if q.has("aim") else null
			return e.attacks._readied_attack(reactor, aim if aim != null and aim.is_alive() else trigger)
		"fount_of_moonlight":
			reactor.reaction_available = false
			var dc := (e.spells.numbers(reactor, e.spells._entry_any(reactor, "fount_of_moonlight"))["dc"] as Breakdown).total()
			var sv := trigger.creature.roll_save(e.dice, &"con", dc, [], [], "Constitution save vs Fount of Moonlight (%s)" % trigger.name())
			if sv.success:
				e.log.add("info", "%s shrugs off the flare of moonlight" % trigger.name(), trigger.id, [sv.describe()])
			else:
				var fx := Effect.new("Blinded (Fount of Moonlight)", &"spell", "fount_of_moonlight").with_condition(&"blinded")
				fx.caster_id = reactor.id
				fx.ends = Effect.Ends.END_OF_TURN
				fx.turn_owner_id = reactor.id
				fx.skip_turn_ends = e.own_turn_skip(reactor)
				trigger.creature.add_effect(fx)
				e.log.add("condition", "%s is Blinded by moonlight" % trigger.name(), trigger.id, [sv.describe()])
				e.events.append({"type": "condition", "id": trigger.id})
			return CombatResult.new()
		"berserk_lashing":
			var near: Array[Combatant] = []
			for o in e.living():
				if o != reactor and not o.is_down() and e.distance(reactor, o) <= 5:
					near.append(o)
			reactor.reaction_available = false
			if near.is_empty():
				e.log.add("info", "%s lashes out at no one" % reactor.name(), reactor.id)
				return CombatResult.new()
			var victim := near[e.dice.roll_one(near.size(), "Berserk Lashing target") - 1]
			e.log.add("info", "%s lashes out in a frenzy at %s (Berserk Lashing)" % [reactor.name(), victim.name()], reactor.id)
			return e._resolve_attack(reactor, victim, e.option_by_id(reactor, "monster:slam"), {"reaction": true})
	return CombatResult.new()


## A queued Reaction's prompt: its words (the trigger's name, then the reactor's), Hellish Rebuke's slot levels or a
## readied spell's aim as its picks.
func _queued_request(q: Dictionary, reactor: Combatant, trigger: Combatant) -> ReactionRequest:
	var e := enc()
	var kind := str(q["kind"])
	var words: Array = _readied_words(q, reactor) if kind == "readied_attack" else (e.ravenloft.queued_text(kind) if kind.begins_with("rh_") \
		else (e.faerun.queued_text(kind) if kind.begins_with("fr_") else _QUEUED_TEXT[kind] as Array))
	var req := ReactionRequest.new(kind, reactor.id, trigger.id)
	req.title = str(words[0])
	req.text = str(words[1]) % [trigger.name(), reactor.name()]
	req.cost = str(words[2])
	if kind == "hellish_rebuke":
		_rebuke_levels(req, reactor)
	if kind == "readied_attack":
		readied_targets(req, reactor, trigger)
	return req


## What the prompt picked for queued Reaction `q` (`picked`: its selected ids): Hellish Rebuke's slot, a readied spell's aim.
func _queued_pick(q: Dictionary, picked: Array[String], trigger: Combatant) -> void:
	var e := enc()
	if not picked.is_empty() and str(q["kind"]) == "hellish_rebuke":
		q["slot"] = -1 if picked[0] == "free" else int(picked[0])
	if str(q["kind"]) == "readied_attack":
		var aim := e.get_c(picked[0]) if not picked.is_empty() else null
		q["aim"] = aim.id if aim != null and aim.is_alive() else trigger.id


## A queued Reaction's fate: the one a hero kept their Reaction for in the attack that queued it is taken, their others
## aren't (`plan`, keep_reserved); otherwise the creature's rule, or the AI.
## A hero's Hellish Rebuke on Automatic is still asked about when there is more than one way to cast it (owner,
## 2026-10-15: a pact slot or the free casting, which is level 1: he saw 9 damage, not the 6d10 he expected).
func _queued_decision(q: Dictionary, reactor: Combatant) -> String:
	var plan := str(q.get("plan", ""))
	if plan in ["auto", "never"]:
		return plan
	var decision := _reaction_decision(reactor, str(q["kind"]))
	if decision == "auto" and str(q["kind"]) == "hellish_rebuke" and reactor.is_player_controlled() and _rebuke_ways(reactor) > 1:
		return "ask"
	return decision


## How many ways `reactor` could pay for Hellish Rebuke now: each slot level and a free casting left.
func _rebuke_ways(reactor: Combatant) -> int:
	var ch := reactor.creature as Character
	if ch == null:
		return 0
	return SpellReactions.slot_levels(ch, 1).size() + (1 if enc().spells.reaction_spells.free_casting(reactor, "hellish_rebuke") else 0)


## In an attack (its state `st`) where heroes kept their Reaction for something later on a prompt listing their
## Reactions (st.reserved): their Reactions waiting in the queue for it are settled, the kept one taken.
func keep_reserved(st: Dictionary) -> void:
	var e := enc()
	var kept := st.get("reserved", {}) as Dictionary
	if kept.is_empty():
		return
	var attacker := st["c"] as Combatant
	for q: Dictionary in e.reaction_queue:
		if not q.has("offers") and kept.has(str(q["reactor"])) and str(q["trigger"]) == attacker.id:
			q["plan"] = "auto" if str(q["kind"]) == str(kept[str(q["reactor"])]) else "never"


## The other queued Reactions `reactor` (a hero) would be asked about now, besides `first`: listed on one prompt with it.
## One of each kind.
func _queued_mates(first: Dictionary, reactor: Combatant) -> Array[Dictionary]:
	var e := enc()
	var out: Array[Dictionary] = []
	if not reactor.is_player_controlled():
		return out
	for q: Dictionary in e.reaction_queue:
		if q.has("offers") or str(q["reactor"]) != reactor.id or q["kind"] == first["kind"] or out.any(func(m: Dictionary) -> bool: return m["kind"] == q["kind"]):
			continue
		var trigger := e.get_c(str(q["trigger"]))
		if trigger != null and trigger.is_alive() and _queued_ok(q, reactor) and _queued_decision(q, reactor) == "ask":
			out.append(q)
	return out


## One prompt for a hero's queued Reactions (`group`, the first already taken off the queue): each one, or each of its
## picks (a slot level, an aim). The others leave the queue with it: picking one takes it, skipping keeps the Reaction.
func _choose_queued(group: Array[Dictionary], reactor: Combatant, r: CombatResult) -> CombatResult:
	var e := enc()
	var req := e.reactions.chooser(reactor, str(group[0]["trigger"]))
	for i in group.size():
		var q := group[i]
		if i > 0:
			e.reaction_queue.erase(q)
		var one := _queued_request(q, reactor, e.get_c(str(q["trigger"])))
		var name := Reactions.offer_name(one.title)
		if one.target_choices.is_empty():
			req.target_choices.append({"id": "now:%d" % i, "label": name, "text": one.text, "cost": one.cost})
		for pick in one.target_choices:
			req.target_choices.append({"id": "now:%d:%s" % [i, pick["id"]], "label": "%s · %s" % [name, pick["label"]], "text": one.text, "cost": one.cost})
	req.selected_ids.assign([str(req.target_choices[0]["id"])])
	var asked_ref: WeakRef = weakref(req)
	req.continuation = func(use: bool) -> CombatResult:
		var asked := asked_ref.get_ref() as ReactionRequest
		if not use or asked == null:
			return run_reaction_queue(r)
		var bits := asked.selected_ids[0].split(":", true, 2)
		var q := group[int(bits[1])]
		var trigger := e.get_c(str(q["trigger"]))
		var picked: Array[String] = []
		if bits.size() > 2:
			picked.append(bits[2])
		_queued_pick(q, picked, trigger)
		return e.then(_fire_queued(q, reactor, trigger), func() -> CombatResult: return run_reaction_queue(r))
	e.pending = req
	r.pending = req
	return r


## Offers the queued reactions one by one (asking the player, or the AI deciding), then the queued Cleave attacks,
## then returns `r`. Called while a prompt is still open (a save action that paused), it waits for the answer. A hero
## with several waiting is asked about them on one prompt.
func run_reaction_queue(r: CombatResult) -> CombatResult:
	var e := enc()
	if e.pending != null:
		return e.then(r, func() -> CombatResult: return run_reaction_queue(r))
	while not e.reaction_queue.is_empty():
		var q := e.reaction_queue.pop_front() as Dictionary
		# A roll's choices that waited for this moment (a Concentration save): asked in turn, then the roll is settled.
		if q.has("offers"):
			var settle := q["settle"] as Callable
			# Once the fight is over nobody is asked: each choice follows its rule.
			if e.state != Encounter.State.ACTIVE:
				e.d20.run_now(q["offers"] as Array)
				settle.call()
				continue
			return e.reactions.offer((q["offers"] as Array).duplicate(), func() -> CombatResult:
				settle.call()
				return run_reaction_queue(r), r)
		var reactor := e.get_c(str(q["reactor"]))
		var trigger := e.get_c(str(q["trigger"]))
		if reactor == null or trigger == null or not trigger.is_alive() or not _queued_ok(q, reactor):
			continue
		var decision := _queued_decision(q, reactor)
		if decision == "never":
			continue
		var fire := func() -> CombatResult: return _fire_queued(q, reactor, trigger)
		if decision == "auto":
			var sub := fire.call() as CombatResult
			if e.pending != null:
				return e.then(sub, func() -> CombatResult: return run_reaction_queue(r))
			continue
		var mates := _queued_mates(q, reactor)
		if not mates.is_empty():
			mates.push_front(q)
			return _choose_queued(mates, reactor, r)
		var req := _queued_request(q, reactor, trigger)
		var asked_ref: WeakRef = weakref(req)   # the request holds this Callable: no cycle back to it
		req.continuation = func(use: bool) -> CombatResult:
			var asked := asked_ref.get_ref() as ReactionRequest
			if use:
				if asked != null:
					_queued_pick(q, asked.selected_ids, trigger)
				return e.then(fire.call() as CombatResult, func() -> CombatResult: return run_reaction_queue(r))
			return run_reaction_queue(r)
		e.pending = req
		r.pending = req
		return r
	while not e.cleave_queue.is_empty():
		var cq := e.cleave_queue.pop_front() as Dictionary
		var cc := cq["c"] as Combatant
		var ct := cq["target"] as Combatant
		if ct.is_alive() and not ct.is_down() and (cc.can_act() or bool(cq.get("redirected", false))):
			# Instinctive Charm passes its own options (the redirected attack keeps its modifiers).
			var sub2 := e._resolve_attack(cc, ct, cq["option"] as Dictionary, cq.get("opts", {"cleave": true, "no_mod": true}) as Dictionary)
			if e.pending != null:
				return e.then(sub2, func() -> CombatResult: return run_reaction_queue(r))
	return r
