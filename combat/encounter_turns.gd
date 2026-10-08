class_name EncounterTurns
extends RefCounted
## Turns in a fight (Encounter): Initiative and the turn order, each turn's start and end, new rounds and the
## lair's turn, the end of the fight, AI turns, and the action economy's checks (whose turn it is; whether an action, a
## Bonus Action or an attack is left).

var _enc: WeakRef


func _init(encounter: Encounter) -> void:
	_enc = weakref(encounter)


func enc() -> Encounter:
	return _enc.get_ref() as Encounter


## Rolls Initiative (2024: a Dexterity check; surprised creatures roll with Disadvantage; identical monsters share
## one roll) and starts round 1. Ties: higher Dexterity first, then the party.
func start(surprised_ids: Array = []) -> void:
	var e := enc()
	surprised_ids = e.items.surprise_filter(surprised_ids)
	e.faerun.before_initiative()
	var group_rolls := {}
	for c in e.combatants:
		c.surprised = c.id in surprised_ids
		var group := ""
		if c.creature is Monster:
			group = str((c.creature as Monster).data.get("id", ""))
		if group != "" and group_rolls.has(group):
			c.initiative = int(group_rolls[group])
			c.initiative_group = group
			continue
		var dis: Array[String] = []
		if c.surprised:
			dis.append("Surprised")
		var bonus := c.creature.initiative_bonus()
		var init_adv := e.items.initiative_advantage(c)
		init_adv.append_array(e.faerun.initiative_advantage(c))
		var t := c.creature.roll_d20(e.dice, D20Test.Kind.ABILITY_CHECK, bonus, 0, c.creature.initiative_keys(), init_adv, dis,
			"Initiative (%s)" % c.name())
		# Ambush (Battle Master): a Superiority Die on Initiative.
		if e.features.knows_maneuver(c, "ambush") and (c.creature as Character).resource_left("superiority_dice") > 0:
			(c.creature as Character).spend_resource("superiority_dice")
			t.add_bonus(e.dice.roll_one(e.features.superiority_die(c), "Ambush"), "Ambush")
		var item_init := e.items.initiative_bonus(c)
		if item_init > 0:
			t.add_bonus(item_init, "Sword of Kas")
		c.initiative_test = t
		c.initiative = t.total
		if group != "":
			group_rolls[group] = t.total
			c.initiative_group = group
		e.log.add("roll", "%s rolls Initiative: %d" % [c.name(), t.total], c.id, [t.describe(), bonus.describe()])
	e.class_features.initiative_rolled()
	e.ravenloft.initiative_rolled()
	e.faerun.initiative_rolled()
	e.echo_knight.initiative_rolled()
	_order_by_initiative()
	# Portent (Diviner): the two (Greater Portent: three) foreseen d20s for this fight.
	for c in e.combatants:
		if CombatFeatures.has_feature(c, "portent") and c.creature is Character:
			var n := 3 if CombatFeatures.has_feature(c, "greater_portent") else 2
			c.set_meta("portent_rolls", e.dice.roll(20, n, "Portent"))
			e.log.add("info", "%s foresees: %s (Portent)" % [c.name(), str(c.get_meta("portent_rolls"))], c.id)
	e.state = Encounter.State.ACTIVE
	for cc in e.combatants:
		e.class_features.prepare(cc)
	e.items.combat_started()
	e.spells.zones.refresh_auras()
	e.round_no = 1
	e.log.round_no = 1
	e.log.add("turn", "Round 1", "")
	e.events.append({"type": "round", "round": 1})
	e.legendary.combat_started()
	e.turn_index = 0
	# Choices once Initiative is rolled (Tandem Footwork): asked before the first turn, which then begins with the order
	# they settle. A prompt here leaves `pending` set for the view, as any other does.
	var offers := e.class_features.initiative_offers()
	if offers.is_empty():
		_lair_then_begin()
		return
	e.reactions.offer(offers, func() -> CombatResult:
		_order_by_initiative()
		e.turn_index = 0
		return _lair_then_begin(), CombatResult.new())


## The turn order from Initiative: highest first; ties go to higher Dexterity, then the party. Thief's Reflexes (Thief
## 17) adds a second turn in the first round at Initiative − 10.
func _order_by_initiative() -> void:
	var e := enc()
	e.order = e.combatants.duplicate()
	e.order.sort_custom(func(a: Combatant, b: Combatant) -> bool:
		if a.initiative != b.initiative:
			return a.initiative > b.initiative
		var da := a.creature.ability_score(&"dex")
		var db := b.creature.ability_score(&"dex")
		if da != db:
			return da > db
		return a.side == &"party" and b.side != &"party")
	for c: Combatant in e.combatants.duplicate():
		if CombatFeatures.has_feature(c, "thiefs_reflexes"):
			var at := e.order.size()
			for i in e.order.size():
				if e.order[i].initiative < c.initiative - 10:
					at = i
					break
			e.order.insert(at, c)
			c.set_meta("reflex_turn", true)


## Begins the current creature's turn: effects that end, a readied spell let go, the turn's resources, then each part
## of the game that acts as a turn starts. Saves and Reactions there can stop for the player's answer (F6), so the
## parts run one after another (Encounter.each) and the queued reactions run last.
func _begin_turn() -> CombatResult:
	var e := enc()
	var c := e.current()
	if c == null:
		return CombatResult.new()
	for o in e.combatants:
		o.cast_slot_spell_this_turn = false
		o.creature.on_turn_start(c.id)
	e._expire_marks(c.id, "start")
	if c.readied.has("conc"):
		var held := c.readied["conc"] as Concentration
		if held != null and not held.ended:
			held.end("the readied spell wasn't released")
			e.log.add("info", "%s lets the readied spell go" % c.name(), c.id)
	c.reset_turn()
	if c.creature.has_flag("hasted"):
		c.haste_action = true
	e.log.add("turn", "%s's turn" % c.name(), c.id)
	e.events.append({"type": "turn", "id": c.id, "round": e.round_no})
	# Legendary actions come back; Regeneration (before anything else starts this turn); a foe whose time is up leaves.
	e.legendary.turn_start(c)
	if not c.is_alive():
		return CombatResult.new()
	var none := CombatResult.new()
	var steps: Array = [
		func() -> CombatResult: return e.spells.turn_start(c),
		func() -> CombatResult:
			e.feature_actions.turn_start(c)
			return none,
		func() -> CombatResult: return e.class_features.turn_start(c),
		func() -> CombatResult:
			e.ravenloft.turn_start(c)
			e.faerun.turn_start(c)
			e.echo_knight.turn_start(c)
			return none,
		func() -> CombatResult: return e.monster_actions.turn_start(c),
		func() -> CombatResult:
			e.items.turn_start(c)
			e.triggered_features.turn_start(c)
			return none,
	]
	return e.each(steps, func(step: Variant) -> CombatResult: return (step as Callable).call() as CombatResult, func() -> CombatResult:
		_turn_start_flags(c)
		return e.run_reaction_queue(CombatResult.new()))


## The last of a turn's start: Dazed, a dropped weapon picked up, a turn without an action, an AI creature's Death
## Saving Throw.
func _turn_start_flags(c: Combatant) -> void:
	var e := enc()
	if not c.is_alive() or e.current() != c:
		return
	if c.creature.has_flag("dazed"):
		c.bonus_available = false
		e.log.add("info", "%s is Dazed: it can move or act this turn, not both" % c.name(), c.id)
	if c.creature.has_flag("no_action_or_bonus"):
		c.action_available = false
		c.bonus_available = false
		e.log.add("info", "%s can't take an action or a Bonus Action this turn" % c.name(), c.id)
	if e.needs_death_save(c) and not c.is_player_controlled():
		e.death_save(c, false)


## Ends the current creature's turn: end-of-turn effects and repeated saves, then the next creature (and round).
func end_turn() -> CombatResult:
	var e := enc()
	if e.pending != null:
		return CombatResult.fail("Answer the reaction prompt first")
	if e.state != Encounter.State.ACTIVE:
		return CombatResult.fail("Combat is over")
	var c := e.current()
	# A Death Saving Throw and the repeated saves can stop for the choices after their rolls (Heroic Inspiration,
	# Indomitable): the rest of the turn's end waits for the answer.
	if e.needs_death_save(c):
		var ds := e.death_save(c)
		if e.pending != null:
			return e.then(ds, func() -> CombatResult: return _turn_end_effects(c))
		if e.state != Encounter.State.ACTIVE:
			return CombatResult.new()
	return _turn_end_effects(c)


func _turn_end_effects(c: Combatant) -> CombatResult:
	var e := enc()
	if e.state != Encounter.State.ACTIVE:
		return CombatResult.new()
	for o in e.combatants:
		o.creature.on_turn_end(c.id)
	e._expire_marks(c.id, "end")
	c.armed.clear()
	e.feature_actions.turn_end(c)
	return e.then(e.class_features.turn_end(c), func() -> CombatResult: return _turn_end_rest(c))


## The rest of the end of `c`'s turn, once Inspiring Movement (or another Reaction there) is answered.
func _turn_end_rest(c: Combatant) -> CombatResult:
	var e := enc()
	if e.state != Encounter.State.ACTIVE:
		return CombatResult.new()
	e.ravenloft.turn_end(c)
	e.faerun.turn_end(c)
	e.echo_knight.turn_end(c)
	e.monster_actions.turn_end(c)
	e.items.turn_end(c)
	e.triggered_features.turn_end(c)
	return e.then(e.spells.turn_end(c), func() -> CombatResult:
		e.spells.zones.prune()
		_check_over()
		if e.state != Encounter.State.ACTIVE:
			return CombatResult.new()
		# Reactions the turn's end queued (damage from an area): offered before the next turn.
		return e.then(e.run_reaction_queue(CombatResult.new()), func() -> CombatResult:
			_check_over()
			if e.state != Encounter.State.ACTIVE:
				return CombatResult.new()
			# Legendary actions at the end of another creature's turn (not while time is stopped).
			var stopped := c.has_meta("time_stop") and int(c.get_meta("time_stop")) > 0
			var lr := e.legendary.after_turn(c) if not stopped else CombatResult.new()
			if e.pending != null:
				return e.then(lr, func() -> CombatResult: return _next_turn(c))
			return _next_turn(c)))


## After `c`'s turn (and any legendary actions): the next creature, a new round, the lair's turn.
func _next_turn(c: Combatant) -> CombatResult:
	var e := enc()
	_check_over()
	if e.state != Encounter.State.ACTIVE:
		return CombatResult.new()
	# Time Stop: the caster's next turn comes straight away.
	if c.has_meta("time_stop") and int(c.get_meta("time_stop")) > 0 and c.is_alive() and c.can_act():
		c.set_meta("time_stop", int(c.get_meta("time_stop")) - 1)
		e.log.add("turn", "Time is still stopped: another turn for %s" % c.name(), c.id)
		return _begin_turn()
	c.remove_meta("time_stop")
	_advance_index()
	if e.state != Encounter.State.ACTIVE:
		return CombatResult.new()
	return _lair_then_begin()


## Moves `turn_index` to the next living creature, starting a new round past the end of the order (a lair that hasn't
## acted yet this round acts first; called creatures arrive as the new round begins).
func _advance_index() -> void:
	var e := enc()
	for i in e.order.size():
		e.turn_index += 1
		if e.turn_index >= e.order.size():
			e.legendary.round_ending()
			if e.state != Encounter.State.ACTIVE:
				return
			e.turn_index = 0
			e.round_no += 1
			_drop_reflex_turns()
			e.log.round_no = e.round_no
			e.log.add("turn", "Round %d" % e.round_no, "")
			e.events.append({"type": "round", "round": e.round_no})
			e.legendary.round_started()
		if e.current().is_alive() and not e.current().has_meta("left_fight"):
			break


## The lair acts on initiative count 20 (losing ties) before the first creature below 20; then the turn begins.
func _lair_then_begin() -> CombatResult:
	var e := enc()
	if not e.legendary.lair_due():
		return _begin_turn()
	return e.then(e.legendary.lair_turn(), func() -> CombatResult:
		_check_over()
		if e.state != Encounter.State.ACTIVE:
			return CombatResult.new()
		if not e.current().is_alive():
			_advance_index()
			if e.state != Encounter.State.ACTIVE:
				return CombatResult.new()
		return _begin_turn())


## After round 1, Thief's Reflexes' extra turns leave the order.
func _drop_reflex_turns() -> void:
	var e := enc()
	for c in e.combatants:
		if c.has_meta("reflex_turn"):
			c.remove_meta("reflex_turn")
			var first := e.order.find(c)
			var second := e.order.find(c, first + 1)
			if second >= 0:
				e.order.remove_at(second)


func _check_over() -> void:
	var e := enc()
	if e.state != Encounter.State.ACTIVE:
		return
	var party_up := false
	var enemies_up := false
	for c in e.combatants:
		# A creature that fell out of the fight (EncounterMovement.leave_grid) no longer counts for either side, nor one
		# knocked out (it's out until a Short Rest is over).
		if not c.is_alive() or c.creature.hp <= 0 or c.creature.has_flag("spell_object") or c.has_meta("left_fight") \
				or c.creature.has_flag("knocked_out"):
			continue
		if c.side in [&"party", &"guest"]:
			party_up = true
		elif c.side == &"enemy":
			enemies_up = true
	if not enemies_up:
		e.state = Encounter.State.OVER
		e.outcome = "victory"
	elif not party_up:
		e.state = Encounter.State.OVER
		e.outcome = "defeat"
	if e.state == Encounter.State.OVER:
		# The party gathers what it dropped or threw; the foes' weapons left lying are loot.
		e.ground.fight_over()
		# An Antimagic Field doesn't outlast the fight: magic items wake up again.
		for c in e.combatants:
			for who: Creature in [c.creature, e.shapes.original(c)]:
				if who is Character:
					(who as Character).magic_suppressed = false
		e.log.add("info", "Victory!" if e.outcome == "victory" else "The party has fallen.", "")
		e.events.append({"type": "over", "outcome": e.outcome})


## True if something takes this creature's turn out of its controller's hands (Command, Fear, Turn Undead, Crown of
## Madness, Calm Emotions): the AI plays it as the effect demands, even for a party member.
func compelled(c: Combatant) -> bool:
	var e := enc()
	for f: String in ["command_grovel", "command_halt", "command_flee", "command_approach", "command_drop", "fear_flee", "crowned"]:
		if c.creature.has_flag(f):
			return true
	return e.features.fleeing_from(c) != null


## Plays the current creature's turn with the AI if it isn't player-controlled.
func run_ai_turn() -> CombatResult:
	var e := enc()
	var c := e.current()
	if c == null or (c.is_player_controlled() and not compelled(c)):
		return CombatResult.fail("Not an AI turn")
	if not c.can_act() and e.features.fleeing_from(c) == null and not c.creature.has_flag("transfixed"):
		return end_turn()
	return e.then(e.ai.play_turn(c), func() -> CombatResult:
		if e.state == Encounter.State.ACTIVE and e.current() == c:
			return end_turn()
		return CombatResult.new())


## "" if `c` may act now (it's its turn, nothing is waiting, combat is on).
func _turn_check(c: Combatant) -> String:
	var e := enc()
	if e.state != Encounter.State.ACTIVE:
		return "Combat is over"
	if e.pending != null:
		return "Answer the reaction prompt first"
	if e.current() != c:
		return "It isn't %s's turn" % c.name()
	return ""


func _action_check(c: Combatant) -> String:
	var why := _turn_check(c)
	if why != "":
		return why
	if not c.can_act():
		return "%s can't act (%s)" % [c.name(), "down" if c.creature.hp <= 0 else "Incapacitated"]
	if not c.action_available:
		return "Action already used"
	if (c.creature.has_flag("slowed") or c.creature.has_flag("action_or_bonus")) and not c.bonus_available and not c.surged:
		return "An action or a Bonus Action this turn, not both"
	return ""


## "" if `c` could make one attack of the Attack action now (starting it if it hasn't).
func features_attack_why(c: Combatant) -> String:
	var why := _turn_check(c)
	if why != "":
		return why
	if not c.can_act():
		return "Can't act"
	if c.attacks_left <= 0 and not c.action_available:
		return "Action already used"
	return ""


## Uses one attack of the Attack action (starting it if needed): Breath Weapon, Commander's Strike, War Magic.
func use_one_attack(c: Combatant) -> void:
	var e := enc()
	if c.attacks_left > 0:
		c.attacks_left -= 1
	elif c.action_available:
		spend_action(c)
		c.took_attack_action = true
		c.attacks_left = e.attacks_per_action(c) - 1
		e.echo_knight.attack_action_taken(c)


func spend_action(c: Combatant) -> void:
	c.remove_meta("attack_cantrip_used")
	if c.extra_actions > 0:
		c.extra_actions -= 1
		c.attacks_left = 0
	else:
		c.action_available = false


func _bonus_check(c: Combatant) -> String:
	var why := _turn_check(c)
	if why != "":
		return why
	if not c.can_act():
		return "%s can't act" % c.name()
	if not c.bonus_available:
		return "Bonus Action already used"
	if (c.creature.has_flag("slowed") or c.creature.has_flag("action_or_bonus")) and not c.action_available:
		return "An action or a Bonus Action this turn, not both"
	return ""
