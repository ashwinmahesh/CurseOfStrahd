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
	"sentinel": ["Reaction: Sentinel?", "%s attacks someone beside %s. Make an Opportunity Attack against it?", "Reaction"],
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
	e.log.add("reaction" if req.spends_reaction else "info", "%s %s" % [e.get_c(req.reactor_id).name(), verbs[0] if use else verbs[1]], req.reactor_id)
	var res := req.continuation.call(use) as CombatResult
	req.continuation = Callable()
	res.pending = e.pending
	return res


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
	return false


func _fire_queued(q: Dictionary, reactor: Combatant, trigger: Combatant) -> CombatResult:
	var e := enc()
	if str(q["kind"]).begins_with("rh_"):
		return e.ravenloft.fire_queued(q, reactor, trigger)
	if str(q["kind"]).begins_with("fr_"):
		return e.faerun.fire_queued(q, reactor, trigger)
	match str(q["kind"]):
		"hellish_rebuke":
			return e.spells.cast_reaction_spell(reactor, "hellish_rebuke", trigger)
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


## Offers the queued reactions one by one (asking the player, or the AI deciding), then the queued Cleave attacks,
## then returns `r`. Called while a prompt is still open (a save action that paused), it waits for the answer.
func run_reaction_queue(r: CombatResult) -> CombatResult:
	var e := enc()
	if e.pending != null:
		return e.then(r, func() -> CombatResult: return run_reaction_queue(r))
	while not e.reaction_queue.is_empty():
		var q := e.reaction_queue.pop_front() as Dictionary
		var reactor := e.get_c(str(q["reactor"]))
		var trigger := e.get_c(str(q["trigger"]))
		if reactor == null or trigger == null or not trigger.is_alive() or not _queued_ok(q, reactor):
			continue
		var kind := str(q["kind"])
		var decision := _reaction_decision(reactor, kind)
		if decision == "never":
			continue
		var fire := func() -> CombatResult: return _fire_queued(q, reactor, trigger)
		if decision == "auto":
			var sub := fire.call() as CombatResult
			if e.pending != null:
				return e.then(sub, func() -> CombatResult: return run_reaction_queue(r))
			continue
		var words := e.ravenloft.queued_text(kind) if kind.begins_with("rh_") else (e.faerun.queued_text(kind) if kind.begins_with("fr_") else _QUEUED_TEXT[kind] as Array)
		var req := ReactionRequest.new(kind, reactor.id, trigger.id)
		req.title = str(words[0])
		req.text = str(words[1]) % [trigger.name(), reactor.name()]
		req.cost = str(words[2])
		req.continuation = func(use: bool) -> CombatResult:
			if use:
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
