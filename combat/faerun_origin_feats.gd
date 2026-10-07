class_name FaerunOriginFeats
extends FaerunCommon
## Heroes of Faerûn's origin feats in a fight (FaerunFeatures): Cult of the Dragon Initiate's Dragon's Terror, Emerald
## Enclave Fledgling, Harper Agent and Arcane Undertaker's help, Arcane Artist and Arcane Overload after a spell, Lords'
## Alliance Agent, Spellfire Spark and Zhentarim Ruffian on hits and damage, Family First and Rallying Cry at
## Initiative, and Tyro of the Gauntlet.


func _terror_dc(c: Combatant) -> int:
	return 8 + c.creature.ability_mod(&"wis") + c.creature.proficiency_bonus()


func _dragons_terror(c: Combatant, t: Combatant, bonus: bool = false) -> CombatResult:
	var e := enc()
	if t == null or t == c or e.distance(c, t) > 30 or not e.can_see(c, t):
		return CombatResult.fail("Choose a creature you can see within 30 ft")
	if c.magic_action_used and not bonus:
		return CombatResult.fail("Only one Magic action this turn")
	if c.id in (t.get_meta("dragons_terror_immune", []) as Array):
		return CombatResult.fail("%s has already shaken off your Dragon's Terror" % t.name())
	var why := e._bonus_check(c) if bonus else e._action_check(c)
	if why != "":
		return CombatResult.fail(why)
	if bonus:
		c.bonus_available = false
		c.remove_meta("dragonscarred_turn")
	else:
		e.spend_action(c)
		c.magic_action_used = true
	var sv := t.creature.roll_save(e.dice, &"wis", _terror_dc(c), [], [], "Wisdom save vs Dragon's Terror (%s)" % t.name(),
		["save_vs:frightened", "save_vs:magic"])
	if sv.success:
		_log("info", "%s stands firm against %s's Dragon's Terror" % [t.name(), c.name()], t, [sv.describe()])
		_terror_immune(c, t)
		return CombatResult.new()
	var fx := Effect.new("Dragon's Terror", &"feature", "dragons_terror").with_condition(&"frightened")
	fx.caster_id = c.id
	fx.ends = Effect.Ends.END_OF_TURN
	fx.turn_owner_id = c.id
	fx.skip_turn_ends = e.own_turn_skip(c)
	# Bound by id, not by a closure over the combatants, so a fear still running at the end of a fight frees cleanly.
	fx.on_end = _terror_ended.bind(c.id, t.id)
	if t.creature.add_effect(fx):
		_log("condition", "%s is Frightened of %s (Dragon's Terror)" % [t.name(), c.name()], t, [sv.describe()])
		e.events.append({"type": "condition", "id": t.id})
	else:
		_terror_immune(c, t)
	return CombatResult.new()


func _terror_ended(caster_id: String, target_id: String) -> void:
	var e := enc()
	if e == null:
		return
	var c := e.get_c(caster_id)
	var t := e.get_c(target_id)
	if c != null and t != null:
		_terror_immune(c, t)


func _terror_immune(c: Combatant, t: Combatant) -> void:
	var immune := (t.get_meta("dragons_terror_immune", []) as Array).duplicate()
	if not c.id in immune:
		immune.append(c.id)
	t.set_meta("dragons_terror_immune", immune)


## Inspired by Fear: a creature just became Frightened of a holder (any feature or spell, the holder as its source).
func effect_added(cr: Creature, fx: Effect) -> void:
	var fr := faerun()
	# Boon of the Bright Sun: the light goes out when its bearer is Incapacitated.
	var bearer := enc().get_c(cr.id)
	if bearer != null and fr.boons._sun_of(bearer) != null and not bearer.can_act():
		fr.boons._sun_of(bearer).ended = true
		_log("info", "%s's sunlight fades" % bearer.name(), bearer)
	if not &"frightened" in fx.conditions or fx.caster_id == "" or fx.caster_id == cr.id:
		return
	var c := enc().get_c(fx.caster_id)
	var ch := _ch(c)
	if ch == null or not feat(c, "cult_of_the_dragon_initiate") or ch.heroic_inspiration or ch.resource_left("inspired_by_fear") <= 0:
		return
	ch.spend_resource("inspired_by_fear")
	_inspire(c, c, "Inspired by Fear")


## How far Help can reach its enemy: 30 ft for a Harper Agent the enemy can see or hear (Distracting Melody).
func help_reach(c: Combatant, enemy: Combatant) -> int:
	if feat(c, "harper_agent") and enemy != null and enc().spells.can_see_or_hear(enemy, c):
		return 30
	return 5


func after_help(c: Combatant, enemy: Combatant) -> void:
	if feat(c, "emerald_enclave_fledgling"):
		c.set_meta("tag_team_window", _turn_key())
	# Harper Teamwork: the distracted enemy also has Disadvantage on its next save before the helper's next turn.
	if feat(c, "harper_teamwork") and enemy != null:
		var fx := Effect.new("Harper Teamwork", &"feature", "harper_teamwork").with_modifier("disadvantage", {"on": "save:all"})
		fx.caster_id = c.id
		fx.ends = Effect.Ends.START_OF_TURN
		fx.turn_owner_id = c.id
		fx.consume_on = ["save:all"]
		enemy.creature.add_effect(fx)


func _tag_team(c: Combatant, t: Combatant) -> CombatResult:
	var e := enc()
	if str(c.get_meta("tag_team_window", "")) != _turn_key():
		return CombatResult.fail("Take the Help action first")
	if t == null or t == c or not c.allied_with(t) or e.distance(c, t) > 5 or not t.can_act():
		return CombatResult.fail("Choose a willing ally within 5 ft who isn't Incapacitated")
	if not e.space_available(t.cell, c.size_cells, [c, t]) or not e.space_available(c.cell, t.size_cells, [c, t]):
		return CombatResult.fail("You can't fit in each other's spaces")
	c.remove_meta("tag_team_window")
	var a := c.cell
	var b := t.cell
	c.cell = b
	t.cell = a
	c.clear_run()
	t.clear_run()
	e.events.append({"type": "move", "id": c.id, "from": a, "to": b, "forced": false})
	e.events.append({"type": "move", "id": t.id, "from": b, "to": a, "forced": false})
	e.spells.zones.on_moved(c, a)
	e.spells.zones.on_moved(t, b)
	_log("move", "%s and %s trade places (Tag Team)" % [c.name(), t.name()], c)
	return CombatResult.new()


## Understanding of Death: Heroic Inspiration after Help stabilizes a dying creature.
func after_stabilize(c: Combatant) -> void:
	var ch := _ch(c)
	if ch == null or not feat(c, "arcane_undertaker") or ch.heroic_inspiration or ch.resource_left("understanding_of_death") <= 0:
		return
	ch.spend_resource("understanding_of_death")
	_inspire(c, c, "Understanding of Death")


func after_cast(c: Combatant, s: Dictionary, slot: int, free: bool = false, ctx: Dictionary = {}) -> void:
	var fr := faerun()
	var ch := _ch(c)
	if ch == null:
		return
	var school := str(s.get("school", ""))
	c.remove_meta("erupting_live")
	fr.boons._revelry(c, s)
	fr.subclasses._subclass_after_cast(c, ch, s, slot, free, ctx)
	if feat(c, "arcane_artist") and school == "illusion" and ch.resource_left("arcane_artist") > 0:
		c.set_meta("arcane_artist_window", _turn_key())
	# The rest need a spell slot spent on a levelled spell.
	if free or slot <= 0 or int(s.get("level", 0)) <= 0:
		return
	if school == "abjuration" and feat(c, "abjuration_adept"):
		_abjuration_ward(c, slot)
	if school == "divination" and feat(c, "divination_adept") and ch.resource_left("divination_adept") < ch.resource_max("divination_adept"):
		ch.restore_resource("divination_adept", 1)
		_log("info", "%s's Divination Adept is ready again" % c.name(), c)
	if school == "necromancy" and feat(c, "necromancy_adept") and allowed(c, "necromancy_adept_benefit") and c.creature.hp < c.creature.max_hp():
		var rolled := _spend_hit_dice(ch, 2, "Necromancy Adept", fr.healing_floor(c))
		if rolled > 0:
			var got := c.creature.heal(rolled + slot, "Necromancy Adept")
			_log("heal", "%s draws on its own life force: +%d Hit Points (Necromancy Adept)" % [c.name(), got], c)
			enc().events.append({"type": "heal", "id": c.id, "amount": got})
	if feat(c, "spell_subterfuge") and str((s.get("casting_time", {}) as Dictionary).get("unit", "")) == "action" and ch.resource_left("shrouding_spells") > 0:
		c.set_meta("shrouding_window", _turn_key())
	# Simbul's Synostodweomer: up to the slot's level in Hit Dice back as healing, while hurt.
	if c.creature.has_flag("synostodweomer") and c.creature.hp < c.creature.max_hp():
		var mod := 0
		for fx: Effect in c.creature.effects:
			if fx.source_id == "simbuls_synostodweomer":
				mod = fr.spell_code._caster_mod(fx.caster_id, "simbuls_synostodweomer")
		var rolled := _spend_hit_dice(ch, slot, "Simbul's Synostodweomer", fr.healing_floor(c))
		if rolled > 0:
			var got := c.creature.heal(rolled + mod, "Simbul's Synostodweomer")
			_log("heal", "%s draws healing from its own spell: +%d Hit Points (Simbul's Synostodweomer)" % [c.name(), got], c)
			enc().events.append({"type": "heal", "id": c.id, "amount": got})


## Abjuration Adept: twice the slot level in Temporary Hit Points for the most hurt of the caster and its allies
## within 30 ft that it can see.
func _abjuration_ward(c: Combatant, slot: int) -> void:
	var e := enc()
	var best := c
	for a in e.allies_of(c):
		if not a.is_alive() or a.creature.hp <= 0 or e.distance(c, a) > 30 or not e.can_see(c, a):
			continue
		if float(a.creature.hp) / maxf(1.0, a.creature.max_hp()) < float(best.creature.hp) / maxf(1.0, best.creature.max_hp()):
			best = a
	if best.creature.add_temp_hp(2 * slot, "Abjuration Adept"):
		_log("heal", "%s gains %d Temporary Hit Points (Abjuration Adept)" % [best.name(), 2 * slot], best)


## Rolls up to `n` unused Hit Dice (largest first), spending them; their total, without the Constitution modifier.
func _spend_hit_dice(ch: Character, n: int, label: String, min_die: int = 0) -> int:
	var total := 0
	for i in n:
		var pool := ch.hit_dice()
		var best := 0
		for die: String in pool:
			var entry := pool[die] as Dictionary
			if int(entry["spent"]) < int(entry["total"]) and int(die) > best:
				best = int(die)
		if best == 0:
			break
		ch.hit_dice_spent[str(best)] = int(ch.hit_dice_spent.get(str(best), 0)) + 1
		total += maxi(enc().dice.roll_one(best, label), min_die)
	return total


func _feat_dc(c: Combatant, feat_id: String) -> int:
	return 8 + _increased_mod(c, feat_id) + c.creature.proficiency_bonus()


## The modifier of the ability a general feat increased (the feat's own pick).
func _increased_mod(c: Combatant, feat_id: String) -> int:
	var ch := _ch(c)
	if ch == null:
		return 0
	for f in ch.feats_taken:
		if str(f["id"]) == feat_id:
			var picks := ch.picks_for("%s.abilities" % str(f["key"]))
			if not picks.is_empty():
				return c.creature.ability_mod(StringName(picks[0]))
	return 0


## Arcane Overload: once armed this turn, an Evocation spell's damage roll gains the Proficiency Bonus. Evocation
## Adept (an Evocation spell) and Spellfire Adept (a spell dealing Radiant): once per turn, up to two Hit Dice.
func spell_damage_bonus(ctx: Dictionary, bonus: Breakdown) -> int:
	var fr := faerun()
	var c := ctx["c"] as Combatant
	var ch := _ch(c)
	if ch == null:
		return 0
	var s := ctx["s"] as Dictionary
	var total := 0
	# Boon of Bloodshed: a spell attack is an attack too.
	if s.has("attack"):
		for d in fr.boons._bloodshed_dice(c, enc().spells._damage_type_safe(ctx)):
			bonus.add("Boon of Bloodshed", int(d["dice"]))
			total += int(d["dice"])
	for pair: Array in [["evocation_adept", "evocation_adept_benefit", "Evocation Adept"], ["spellfire_adept", "spellfire_adept_benefit", "Spellfire Adept"]]:
		if not feat(c, str(pair[0])) or not allowed(c, str(pair[1])):
			continue
		var fits := str(s.get("school", "")) == "evocation" if str(pair[0]) == "evocation_adept" \
			else (s.get("damage", []) as Array).any(func(d: Variant) -> bool: return str((d as Dictionary).get("type", "")) == "radiant")
		if not fits or not _once_per_turn(c, str(pair[0]) + "_turn"):
			continue
		var hd := _spend_hit_dice(ch, 2, str(pair[2]))
		if hd > 0:
			bonus.add("%s (Hit Dice)" % pair[2], hd)
			total += hd
	return total + _overload(c, ch, s, bonus)


func _overload(c: Combatant, ch: Character, s: Dictionary, bonus: Breakdown) -> int:
	if str(c.get_meta("arcane_overload_armed", "")) != _turn_key():
		return 0
	if str(s.get("school", "")) != "evocation" or ch.resource_left("arcane_overload") <= 0:
		return 0
	ch.spend_resource("arcane_overload")
	c.remove_meta("arcane_overload_armed")
	var pb := ch.proficiency_bonus()
	bonus.add("Arcane Overload", pb)
	return pb


## Inspiring Strike: once per turn, a Critical Hit on a creature inspires an ally within 30 ft who sees or hears you.
func after_hit(c: Combatant, target: Combatant, critical: bool, st: Dictionary = {}) -> void:
	var fr := faerun()
	if target != null and st.has("smite_ctx") and str(((st["smite_ctx"] as Dictionary)["s"] as Dictionary).get("id", "")) == "divine_smite":
		fr.subclasses._elemental_smite(c, target)
	if target != null and str(c.get_meta("flustering_armed", "")) == _turn_key() and _ch(c).resource_left("flustering_strike") > 0:
		fr.general._flustering_strike(c, target)
	if not critical or target == null or not feat(c, "lords_alliance_agent"):
		return
	var e := enc()
	var who := _uninspired_allies(c, 30, func(a: Combatant) -> bool: return e.spells.can_see_or_hear(a, c))
	if who.is_empty() or not _once_per_turn(c, "inspiring_strike_turn"):
		return
	_inspire(c, who[0], "Inspiring Strike")


## Reassert Honor: an enemy the holder can see hurts an ally beside it; the holder's next attack on that enemy has
## Advantage until the end of its next turn.
func after_damage(source: Combatant, target: Combatant, amount: int, parts: Array = []) -> void:
	var fr := faerun()
	var e := enc()
	if source == null or amount <= 0 or source == target:
		return
	# Erupting Spellpower: each creature the spell damages falls Prone.
	if bool(source.get_meta("erupting_live", false)) and parts.any(func(p: Variant) -> bool: return bool((p as Dictionary).get("spell", false))) \
			and target.is_alive() and not target.creature.has_condition(&"prone"):
		target.creature.add_condition(&"prone", "Erupting Spellpower")
		_log("condition", "%s is knocked Prone (Boon of Erupting Spellpower)" % target.name(), target)
		e.events.append({"type": "condition", "id": target.id})
	# Spirit Lantern: an enemy dying in a lantern's light gives it a fragment.
	if target.creature.dead or target.creature.hp <= 0:
		fr.spell_code._lantern_catch(target)
	# Dragonscarred: damage dealt on its own turn opens Dragon's Terror as a Bonus Action.
	if e.current() == source and feat(source, "dragonscarred"):
		source.set_meta("dragonscarred_turn", _turn_key())
	# Cold Caster: once per turn, a hit dealing Cold takes 1d4 off the target's next save before the caster's next
	# turn ends.
	var hit := str(e.hit_context.get("attacker", "")) == source.id and str(e.hit_context.get("target", "")) == target.id
	if hit and feat(source, "cold_caster") and parts.any(func(p: Variant) -> bool: return str((p as Dictionary).get("type", "")) == "cold" and int((p as Dictionary).get("amount", 0)) > 0) \
			and _once_per_turn(source, "cold_caster_turn"):
		var fx := Effect.new("Frostbite (Cold Caster)", &"feature", "cold_caster").with_modifier("penalty_die", {"dice": "1d4", "on": ["save:all"]})
		fx.caster_id = source.id
		fx.ends = Effect.Ends.END_OF_TURN
		fx.turn_owner_id = source.id
		fx.skip_turn_ends = e.own_turn_skip(source)
		fx.consume_on = ["save:all"]
		target.creature.add_effect(fx)
		_log("info", "%s is chilled: −1d4 on its next save (Cold Caster)" % target.name(), target)
	for h in e.combatants:
		if h == target or not h.is_alive() or not feat(h, "lords_alliance_agent") or not h.allied_with(target):
			continue
		if not h.hostile_to(source) or e.distance(h, target) > 5 or not e.can_see(h, source):
			continue
		e.add_mark({"kind": "advantage_against", "target": source.id, "attacker": h.id, "source": "Reassert Honor",
			"expires_owner": h.id, "expires_phase": "end", "skip": e.own_turn_skip(h), "consume": true})
		_log("info", "%s will make %s answer for that (Reassert Honor: Advantage on the next attack)" % [h.name(), source.name()], h)


## Magic Absorption (Spellfire Spark): once per turn, 1d4 off damage from a spell or a magical monster action while
## not Incapacitated.
func adjust_incoming(_source: Combatant, target: Combatant, parts: Array) -> void:
	if not feat(target, "spellfire_spark") or not target.can_act():
		return
	var spell_part: Dictionary = {}
	for p: Variant in parts:
		var part := p as Dictionary
		if (bool(part.get("spell", false)) or bool(part.get("magic", false))) and int(part["amount"]) > 0:
			spell_part = p as Dictionary
			break
	if spell_part.is_empty() or not _once_per_turn(target, "magic_absorption_turn"):
		return
	var cut := enc().dice.roll_one(4, "Magic Absorption")
	spell_part["amount"] = maxi(0, int(spell_part["amount"]) - cut)
	_log("info", "%s soaks up %d of the spell's damage (Magic Absorption)" % [target.name(), cut], target)


## Exploit Opening: an Opportunity Attack's damage dice are rolled twice, keeping the better roll.
func exploit_opening(c: Combatant, opts: Dictionary) -> bool:
	return bool(opts.get("opportunity", false)) and feat(c, "zhentarim_ruffian")


## Before anyone rolls: a Zhentarim Ruffian may spend Heroic Inspiration for its side's Advantage on Initiative.
func before_initiative() -> void:
	var fr := faerun()
	fr._family_first.clear()
	for b in enc().combatants:
		var bc := _ch(b)
		if bc != null and feat(b, "boon_of_erupting_spellpower"):
			bc.restore_resource("erupting_spellpower", 1)
	for c in enc().combatants:
		var ch := _ch(c)
		if ch == null or not ch.heroic_inspiration or not feat(c, "zhentarim_ruffian") or not allowed(c, "family_first"):
			continue
		if fr._family_first.has(str(c.side)):
			continue
		ch.heroic_inspiration = false
		fr._family_first[str(c.side)] = c.name()
		_log("info", "%s spends Heroic Inspiration: the whole side rolls Initiative with Advantage (Family First)" % c.name(), c)


func initiative_advantage(c: Combatant) -> Array[String]:
	var fr := faerun()
	var out: Array[String] = []
	for side: String in fr._family_first:
		var holder := str(fr._family_first[side])
		if side == str(c.side) or (side == "party" and c.side == &"guest") or (side == "guest" and c.side == &"party"):
			out.append("Family First (%s)" % holder)
	return out


## Rallying Cry (Purple Dragon Rook): on rolling Initiative, Heroic Inspiration for up to Proficiency Bonus allies
## within 30 ft that the Rook can see. Once per Long Rest.
func initiative_rolled() -> void:
	var e := enc()
	for c in e.combatants:
		var ch := _ch(c)
		if ch == null or not feat(c, "purple_dragon_rook") or not c.can_act() or ch.resource_left("rook_rallying_cry") <= 0:
			continue
		if not allowed(c, "rook_rallying_cry"):
			continue
		var who := _uninspired_allies(c, 30, func(a: Combatant) -> bool: return e.can_see(c, a))
		if who.is_empty():
			continue
		ch.spend_resource("rook_rallying_cry")
		_log("info", "%s raises a rallying cry" % c.name(), c)
		for a: Combatant in who.slice(0, ch.proficiency_bonus()):
			_inspire(c, a, "Rallying Cry")


## Stand as One: a holder within 5 ft of `target` (not itself) spends its Reaction so the push or pull fails.
func blocks_forced_move(target: Combatant) -> bool:
	var e := enc()
	if not target.can_act():
		return false
	for h in e.combatants:
		if h == target or not feat(h, "tyro_of_the_gauntlet") or not h.allied_with(target) or e.distance(h, target) > 5:
			continue
		if not e.spells.can_react(h) or not allowed(h, "stand_as_one"):
			continue
		h.reaction_available = false
		_log("reaction", "%s braces %s: no push or pull (Stand as One)" % [h.name(), target.name()], h)
		return true
	return false


## Gauntlet Vigilant: after taking the Ready action, the next attack against the holder before its next turn
## starts has Disadvantage.
func after_ready(c: Combatant) -> void:
	if not feat(c, "tyro_of_the_gauntlet"):
		return
	var fx := Effect.new("Gauntlet Vigilant", &"feature", "gauntlet_vigilant").with_modifier("attacked_with", {"value": "disadvantage"})
	fx.caster_id = c.id
	fx.ends = Effect.Ends.START_OF_TURN
	fx.turn_owner_id = c.id
	fx.consume_when_attacked = true
	c.creature.add_effect(fx)
	_log("info", "%s stays on guard (Gauntlet Vigilant)" % c.name(), c)
