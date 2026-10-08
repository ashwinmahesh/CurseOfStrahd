class_name EncounterDamage
extends RefCounted
## Damage, healing and dying in a fight (Encounter): damage dice (Critical Hits, minimums, rerolls), healing dice,
## dealing damage through a creature's defenses (Concentration, Undead Fortitude, effects that end on damage, death),
## wards that soak damage, Death Saving Throws and stabilizing.

var _enc: WeakRef


func _init(encounter: Encounter) -> void:
	_enc = weakref(encounter)


func enc() -> Encounter:
	return _enc.get_ref() as Encounter


## A Death Saving Throw for a dying character on its turn (2024: 10+ succeeds, three successes stabilize, three
## failures kill, a 20 brings it back with 1 HP). The player rolls it from the HUD; if not, it's rolled at the end
## of the turn. AI-controlled dying creatures roll at the start of their turn. The roll stops for the choices after
## it (Heroic Inspiration...) unless `pausable` is false.
func death_save(c: Combatant, pausable: bool = true) -> CombatResult:
	var e := enc()
	if e.current() != c or c.death_save_rolled:
		return CombatResult.fail("Not now")
	if c.creature.dead or c.creature.hp > 0 or c.creature.stable or not c.creature.uses_death_saves:
		return CombatResult.fail("%s isn't dying" % c.name())
	c.death_save_rolled = true
	var roll := func() -> D20Test: return c.creature.roll_death_save_d20(e.dice)
	var after := func(t: D20Test) -> CombatResult: return _death_save_counted(c, t)
	if pausable:
		return e.d20.then_after(c, roll, after, CombatResult.new())
	return after.call(roll.call() as D20Test) as CombatResult


func _death_save_counted(c: Combatant, t: D20Test) -> CombatResult:
	var e := enc()
	if t == null:
		return CombatResult.fail("No Death Saving Throw needed")
	c.creature.apply_death_save(t)
	var status := "dies" if c.creature.dead else ("is Stable" if c.creature.stable else ("regains 1 Hit Point" if c.creature.hp > 0 else "%d ✓ %d ✗" % [c.creature.death_successes, c.creature.death_failures]))
	e.log.add("roll", "%s makes a Death Saving Throw: %s" % [c.name(), status], c.id, [t.describe()])
	e.events.append({"type": "death_save", "id": c.id, "success": t.success})
	if c.creature.dead:
		e.events.append({"type": "death", "id": c.id})
		e._check_over()
	elif c.creature.hp > 0:
		e.events.append({"type": "heal", "id": c.id, "amount": c.creature.hp})
	return CombatResult.new()


func needs_death_save(c: Combatant) -> bool:
	return c.is_alive() and c.creature.hp <= 0 and c.creature.uses_death_saves and not c.creature.stable and not c.death_save_rolled


## Stabilizing a dying creature within 5 ft (2024): the Help action with a DC 10 Wisdom (Medicine) check, or a
## Utilize action spending a use of a Healer's Kit (no check).
func stabilize(c: Combatant, target: Combatant, use_kit: bool) -> CombatResult:
	var e := enc()
	var why := e._action_check(c)
	if why != "":
		return CombatResult.fail(why)
	if target == null or target.creature.hp > 0 or target.creature.dead or target.creature.stable:
		return CombatResult.fail("Choose a dying creature")
	if e.distance(c, target) > 5:
		return CombatResult.fail("Must be within 5 ft")
	if use_kit and not e.has_kit(c):
		return CombatResult.fail("No Healer's Kit")
	e.spend_action(c)
	if use_kit:
		e.log.add("heal", "%s uses a Healer's Kit: %s is Stable" % [c.name(), target.name()], c.id)
		target.creature.stabilize()
		return CombatResult.new()
	var t := c.creature.roll_check(e.dice, &"medicine", 10)
	if t.success:
		target.creature.stabilize()
		e.log.add("heal", "%s stabilizes %s" % [c.name(), target.name()], c.id, [t.describe()])
		e.faerun.after_stabilize(c)
	else:
		e.log.add("info", "%s can't stop %s's bleeding" % [c.name(), target.name()], c.id, [t.describe()])
	return CombatResult.new()


## Rolls damage dice (doubled on a Critical Hit; dice below `minimum` count as `minimum`).
## {total, text}
func _roll_damage_dice(expr: String, critical: bool, minimum: int, reason: String, reroll: Dictionary = {}) -> Dictionary:
	var e := enc()
	var parsed := DiceRoller.parse_expr(expr)
	var count := int(parsed["count"]) * (2 if critical else 1)
	var total := int(parsed["modifier"])
	var shown: Array[String] = []
	var rerolls_left := int(reroll.get("count", 0))
	if count > 0:
		for roll0 in e.dice.roll(int(parsed["sides"]), count, reason):
			var roll := roll0
			# Tavern Brawler, Piercer: reroll low damage dice (Piercer once per turn).
			if rerolls_left > 0 and roll <= int(reroll.get("at_most", 1)):
				rerolls_left -= 1
				roll = e.dice.roll_one(int(parsed["sides"]), "%s reroll" % reroll.get("source", ""))
				shown.append("%d↻" % roll0)
			var v := roll
			if minimum > 0 and v < minimum:
				v = minimum
				shown.append("%d→%d" % [roll, v])
			else:
				shown.append(str(v))
			total += v
	var text := "[%s]" % ", ".join(shown) if not shown.is_empty() else ""
	if int(parsed["modifier"]) != 0:
		text += " %+d" % int(parsed["modifier"])
	return {"total": total, "text": "%s = %d" % [text.strip_edges(), total]}


## Every die of `expr` at its highest face (Boon of Exquisite Radiance, Boon of Poison Mastery).
func _max_damage_dice(expr: String, critical: bool) -> Dictionary:
	var p := DiceRoller.parse_expr(expr)
	var count := int(p["count"]) * (2 if critical else 1)
	var total := count * int(p["sides"]) + int(p["modifier"])
	return {"total": total, "text": "%dd%d at their maximum = %d" % [count, int(p["sides"]), total]}


## Dice rolled to give `t` Hit Points: Soothing Familiar counts low dice as 3s.
func heal_roll(expr: String, t: Combatant, reason: String, reroll: Dictionary = {}) -> Dictionary:
	return _roll_damage_dice(expr, false, heal_floor(t), reason, reroll)


## The lowest a die rolled to heal `t` counts as (0 = as rolled).
func heal_floor(t: Combatant) -> int:
	var e := enc()
	return e.faerun.healing_floor(t)


## Deals damage through the target's defenses with the Concentration save, Undead Fortitude, effects that end on
## damage, death and the log. Returns the DamageResult.
func deal_damage(source: Combatant, target: Combatant, parts: Array, critical: bool, label: String,
		details: Array = [], log_it: bool = true, responses_resolved: Array = []) -> DamageResult:
	var e := enc()
	target = e.monster_actions.redirect_shared(target)
	# Time Stop ends when the caster affects anyone else.
	if source != null and source != target:
		e.spells.specials.high.time_stop_broken(source, "it affected another creature")
	# Otiluke's Resilient Sphere: nothing passes through the globe either way.
	if source != null and e.spells.specials.sphere_blocks(source, target):
		e.log.add("info", "The sphere of force around %s turns the damage aside" % (target.name() if target.creature.has_flag("sphered") else source.name()), target.id)
		return DamageResult.new()
	parts = e.monster_actions.absorb(target, parts)
	var was_up := not target.is_down()
	if source != null and target.creature.has_flag("cursed_necrotic:%s" % source.id):
		var extra := _roll_damage_dice("1d8", false, 0, "Bestow Curse")
		parts = parts.duplicate()
		parts.append({"amount": int(extra["total"]), "type": "necrotic"})
		details = details.duplicate()
		details.append("Bestow Curse 1d8: %s" % extra["text"])
	if source != null and source.creature.has_flag("siege_monster") and (target.creature.has_flag("spell_object") or target.creature.creature_type == &"object"):
		parts = parts.duplicate(true)
		for part: Dictionary in parts:
			part["amount"] = int(part["amount"]) * 2
		details.append("Siege Monster: double damage to objects")
	parts = e.damage_responses.synchronous(target, parts, details, responses_resolved)
	parts = e.faerun.synchronous_damage(source, target, parts, details, responses_resolved)
	parts = _reduce_by_dice(target, parts, details)
	parts = _bastion(target, parts, details)
	e.feature_actions.adjust_incoming(source, target, parts)
	e.items.adjust_incoming(source, target, parts, label)
	# Mage Slayer: creatures it damages have Disadvantage on the Concentration save.
	var slayer: Effect = null
	if source != null and e.features.has_feat(source, "mage_slayer") and target.creature.concentration != null:
		slayer = Effect.new("Mage Slayer", &"feature", "mage_slayer").with_modifier("disadvantage", {"on": "concentration"})
		target.creature.add_effect(slayer)
	var dr := target.creature.take_damage_parts(parts, critical, e.dice, label)
	if slayer != null:
		target.creature.remove_effect(slayer)
	if source != null and dr.final > 0:
		e.spells.trigger_ends(source, "deal_damage")
	if dr.final > 0:
		for fx: Effect in target.creature.effects.duplicate():
			if fx.ends_on_damage:
				target.creature.remove_effect(fx)
				e.log.add("info", "%s ends on %s (took damage)" % [fx.name, target.name()], target.id)
	# Undead Fortitude (2025 zombie): a Con save (DC 5 + damage) to drop to 1 HP instead, unless Radiant or a crit.
	# On a success it never falls: no death, no "unconscious", just a zombie still standing at 1 Hit Point.
	var fortitude: D20Test = null
	if target.creature.dead and target.creature.has_flag("undead_fortitude") and not critical:
		var radiant := false
		for p: Variant in parts:
			if str((p as Dictionary)["type"]) == "radiant" and int((p as Dictionary)["amount"]) > 0:
				radiant = true
		if not radiant:
			var dc := 5 + dr.final
			var save := target.creature.roll_save(e.dice, &"con", dc, [], [], "Undead Fortitude (%s)" % target.name())
			if save.success:
				target.creature.dead = false
				target.creature.hp = 1
				dr.dropped_to_zero = false
				dr.died = false
				dr.instant_death = false
				fortitude = save
	# A shape (Polymorph, Wild Shape) that runs out: the real creature comes back with what's left.
	e.shapes.after_damage(target)
	# Gift of the Protectors: a party member drops to 1 instead of 0 once per Long Rest.
	if was_up and dr.dropped_to_zero and not target.creature.dead and e.class_features.gift_of_the_protectors(target):
		target.creature.hp = 1
		target.creature.remove_condition(&"unconscious", "0 Hit Points")
		dr.dropped_to_zero = false
	# Death Ward: the first drop to 0 Hit Points (or death outright from damage) leaves it at 1 instead.
	if was_up and (dr.dropped_to_zero or target.creature.dead) and target.creature.has_flag("death_ward"):
		for fxw: Effect in target.creature.effects.duplicate():
			if fxw.modifiers.any(func(m: Modifier) -> bool: return m.stat == &"flag" and m.text("value") == "death_ward"):
				target.creature.remove_effect(fxw)
		target.creature.dead = false
		target.creature.hp = 1
		target.creature.remove_condition(&"unconscious", "0 Hit Points")
		target.creature.death_failures = 0
		dr.dropped_to_zero = false
		dr.died = false
		dr.instant_death = false
		e.log.add("info", "Death Ward holds: %s stays up with 1 Hit Point" % target.name(), target.id)
	# Armor of Agathys ends once its Temporary Hit Points are gone.
	if target.creature.temp_hp <= 0:
		for fxa: Effect in target.creature.effects.duplicate():
			if bool(fxa.data.get("ends_without_temp_hp", false)):
				target.creature.remove_effect(fxa)
				e.log.add("info", "%s ends: no Temporary Hit Points left" % fxa.name, target.id)
	# Bosses (ADR 0014): Regeneration stopped by Radiant, a foe withdrawing at its threshold, Misty Escape at 0.
	var departed := e.legendary.after_damage(target, parts, dr, was_up)
	var text := dr.describe(target.name())
	if log_it:
		var headline := text
		if source != null and source != target:
			headline = "%s hits %s for %d %s damage" % [source.name(), target.name(), dr.final, " + ".join(_types_of(parts))]
		var all_details: Array = details.duplicate()
		all_details.append(text)
		e.log.add("hit", headline, source.id if source != null else "", all_details)
	e.events.append({"type": "damage", "id": target.id, "amount": dr.final, "critical": critical})
	if fortitude != null:
		e.log.add("info", "%s keeps standing at 1 Hit Point (Undead Fortitude)" % target.name(), target.id, [fortitude.describe()])
		e.events.append({"type": "trait", "id": target.id, "name": "Undead Fortitude"})
	if dr.concentration_broken:
		e.log.add("info", "%s loses Concentration" % target.name(), target.id, [dr.concentration_save.describe()])
	if was_up and target.is_down():
		e.class_features.on_drop(source, target)
		if e.rider_of(target) != null:
			e.dismount(e.rider_of(target), true, false)
		if e.mount_of(target) != null:
			var mt := e.mount_of(target)
			target.remove_meta("mounted_on")
			mt.remove_meta("ridden_by")
	if departed:
		pass
	elif target.creature.dead and was_up:
		e.monster_actions.death_burst(target)
		target.set_meta("died_round", e.round_no)
		e.log.add("death", "%s dies" % target.name(), target.id)
		e.events.append({"type": "death", "id": target.id})
		e.ravenloft.on_death(source, target)
		e.faerun.on_death(source, target)
		e.echo_knight.on_death(source, target)
		if target.has_meta("vanishes"):
			e.events.append({"type": "vanish", "id": target.id})
	elif dr.dropped_to_zero and not target.creature.dead and e.monster_actions.lycanthrope(target):
		pass
	elif dr.dropped_to_zero and not target.creature.dead and (e.feature_actions.on_zero(target) or e.ravenloft.on_zero(target, dr.final)):
		e.events.append({"type": "heal", "id": target.id, "amount": 1})
	elif dr.dropped_to_zero and not target.creature.dead:
		e.log.add("death", "%s falls unconscious" % target.name(), target.id)
		e.events.append({"type": "down", "id": target.id})
	if e.grapples.values().has(target.id) and (target.creature.has_flag("no_actions") or target.is_down()):
		e._release_grapples_by(target)
	if target.is_down() or target.creature.has_flag("no_actions"):
		e.features.end_turning_from(target)
	if source != null and source != target and dr.final > 0:
		e.spells.end_sanctuary(source, "dealt damage")
	e.spells.on_damaged(source, target, dr.final, parts)
	e.items.on_damaged(source, target, dr.final, parts)
	if dr.final > 0:
		e.spells.specials.duel_check_damage(source, target)
	# Thought Shield (Great Old One 10): Psychic damage dealt to the warlock hits its source too.
	if source != null and source != target and dr.final > 0 and CombatFeatures.has_feature(target, "thought_shield") and not target.has_meta("reflecting"):
		var psy := 0
		for p: Variant in parts:
			if str((p as Dictionary)["type"]) == "psychic":
				psy += int((p as Dictionary)["amount"])
		if psy > 0:
			target.set_meta("reflecting", true)
			deal_damage(target, source, [{"amount": mini(psy, dr.final), "type": "psychic"}], false, "Thought Shield")
			target.remove_meta("reflecting")
	if dr.final > 0 and target.is_alive():
		e.monster_actions.loathsome_limbs(target, parts)
		e.monster_actions.damage_traits(target, parts)
	if target.is_down():
		e.monster_actions.body_dropped(target)
		e.spells.specials.mid.hand_destroyed(target)
	if dr.final > 0 and source != null and source != target and target.is_alive():
		e.reaction_flow._queue_damage_reactions(source, target)
	e.faerun.after_damage(source, target, dr.final, parts)
	e.echo_knight.after_damage(source, target)
	e.spells.zones.prune()
	e._check_over()
	return dr


## Bastion of Law (Clockwork Sorcery): the ward's d8s soak damage, rolled one at a time until it's gone.
func _bastion(target: Combatant, parts: Array, details: Array) -> Array:
	var e := enc()
	var left := int(target.get_meta("bastion_dice", 0))
	if left <= 0:
		return parts
	var out: Array = []
	for p: Variant in parts:
		out.append((p as Dictionary).duplicate())
	for p2: Variant in out:
		var d := p2 as Dictionary
		while int(d["amount"]) > 0 and left > 0:
			var cut := e.dice.roll_one(8, "Bastion of Law")
			left -= 1
			d["amount"] = maxi(0, int(d["amount"]) - cut)
			details.append("Bastion of Law: −%d" % cut)
	if left <= 0:
		target.remove_meta("bastion_dice")
	else:
		target.set_meta("bastion_dice", left)
	return out


## The Resistance cantrip: damage of the chosen type is reduced by 1d4, once per turn.
func _reduce_by_dice(target: Combatant, parts: Array, details: Array) -> Array:
	var e := enc()
	var mods := target.creature.modifiers_for(&"damage_reduction_die")
	if mods.is_empty():
		return parts
	var turn_key := "%d:%d" % [e.round_no, e.turn_index]
	var out: Array = []
	for p: Variant in parts:
		out.append((p as Dictionary).duplicate())
	for m in mods:
		if bool(m.data.get("once_per_turn", true)) and str(target.get_meta("dr_die_turn", "")) == turn_key:
			break
		for p: Variant in out:
			var d := p as Dictionary
			if str(d["type"]) == m.text("type") and int(d["amount"]) > 0:
				var cut := int(e.dice.roll_expr(m.text("dice", "1d4"), m.source_name)["total"])
				d["amount"] = maxi(0, int(d["amount"]) - cut)
				target.set_meta("dr_die_turn", turn_key)
				details.append("%s: −%d" % [m.source_name, cut])
				break
	return out


static func _types_of(parts: Array) -> Array[String]:
	var out: Array[String] = []
	for p: Variant in parts:
		var d := p as Dictionary
		if int(d["amount"]) > 0:
			out.append(str(d["type"]).capitalize())
	return out
