class_name SpellTurns
extends RefCounted
## What spells do as a fight goes on (SpellCaster): effects at the start and end of a turn, a creature taking damage
## (Concentration aside, Warding Bond), triggers that end a spell, entering a square, and tethers that break with
## distance.

var _enc: WeakRef


func _init(encounter: Encounter) -> void:
	_enc = weakref(encounter)


func enc() -> Encounter:
	return _enc.get_ref() as Encounter


func sp() -> SpellCaster:
	return enc().spells


func _comp() -> Compendium:
	return Compendium.shared()


func turn_start(c: Combatant) -> void:
	var spells := sp()
	var e := enc()
	spells.zones.turn_start(c)
	spells.specials.high.tick_suppressed(c.id, true)
	if c.has_meta("vanish_round") and enc().round_no >= int(c.get_meta("vanish_round")):
		spells._dismiss(c.id)
	spells.specials.high.caster_turn_start(c)
	spells.specials.high.creature_turn_start(c)
	spells.specials.mid.panic_turn(c)
	spells.specials.mid.ai_turn(c)
	spells._prune_sustained()
	_turn_start_effects(c)
	spells.saves._repeat_saves(c, "start")
	spells.specials.turn_start(c)
	# Bestow Curse (Dodge): a Wisdom save at the start of its turn or it must take the Dodge action.
	if c.creature.has_flag("cursed_dodge") and c.can_act():
		for fx: Effect in c.creature.effects:
			if fx.source_id == "bestow_curse":
				var caster := e.get_c(fx.caster_id)
				var dc := (spells.numbers(caster, spells._entry_any(caster, "bestow_curse"))["dc"] as Breakdown).total() if caster != null and caster.creature is Character else 13
				var sv := c.creature.roll_save(e.dice, &"wis", dc, [], [], "Wisdom save vs Bestow Curse (%s)" % c.name(), SpellCaster.spell_save_keys(fx.caster_id))
				if not sv.success:
					e.spend_action(c)
					var dg := Effect.new("Dodging", &"effect", "dodge").with_modifier("attacked_with", {"value": "disadvantage"}).with_modifier("advantage", {"on": "save:dex"})
					dg.ends = Effect.Ends.START_OF_TURN
					dg.turn_owner_id = c.id
					dg.ends_when_incapacitated = true
					c.creature.add_effect(dg)
					e.log.add("info", "%s cowers and takes the Dodge action (Bestow Curse)" % c.name(), c.id, [sv.describe()])
				break
	# Blink: back from the Ethereal Plane.
	if c.has_meta("ethereal"):
		c.remove_meta("ethereal")
		c.creature.remove_effects_named("Blinked away")
		e.log.add("info", "%s blinks back" % c.name(), c.id)
		e.events.append({"type": "condition", "id": c.id})


## Effects that act at the start of their bearer's turn: burning and thorns (`turn_damage`), Heroism's Temporary Hit
## Points (`turn_temp_hp`).
func _turn_start_effects(c: Combatant) -> void:
	var e := enc()
	for fx: Effect in c.creature.effects.duplicate():
		if not fx in c.creature.effects or not c.is_alive():
			continue
		var td := fx.data.get("turn_damage", {}) as Dictionary
		if not td.is_empty() and str(td.get("when", "start")) == "start":
			var rolled := e._roll_damage_dice(str(td["dice"]), false, 0, fx.name)
			e.deal_damage(e.get_c(fx.caster_id), c, [{"amount": int(rolled["total"]), "type": str(td.get("type", "fire")), "spell": true}], false, fx.name, [str(rolled["text"])])
		# Regenerate: 1 Hit Point at the start of each turn.
		if fx.data.has("turn_heal") and not c.creature.has_flag("cant_regain_hp"):
			var hg := c.creature.heal(int(fx.data["turn_heal"]), fx.name)
			if hg > 0:
				c.creature.remove_condition(&"unconscious", "0 Hit Points")
				e.log.add("heal", "%s regains %d Hit Point (%s)" % [c.name(), hg, fx.name], c.id)
		if fx.data.has("turn_temp_hp") and c.creature.hp > 0:
			var amount := int(fx.data["turn_temp_hp"])
			if amount > 0 and c.creature.add_temp_hp(amount, fx.name):
				e.log.add("heal", "%s gains %d Temporary Hit Points (%s)" % [c.name(), amount, fx.name], c.id)


func turn_end(c: Combatant) -> void:
	var spells := sp()
	var e := enc()
	spells.zones.turn_end(c)
	spells.specials.high.caster_turn_end(c)
	spells.specials.high.prism_turn_end(c)
	spells.specials.high.tick_suppressed(c.id, false)
	spells.specials.turn_end(c)
	spells.saves._repeat_saves(c, "end")
	spells.sustain._sustained_turn_end(c)
	if c.creature.has_flag("blink") and c.can_act():
		var roll := int(e.dice.roll(6, 1, "Blink")[0])
		if roll >= 4:
			c.set_meta("ethereal", true)
			var fx := Effect.new("Blinked away", &"spell", "blink").with_modifier("flag", {"value": "ethereal"})
			fx.ends = Effect.Ends.START_OF_TURN
			fx.turn_owner_id = c.id
			c.creature.add_effect(fx)
			e.log.add("info", "%s blinks onto the Ethereal Plane (d6: %d)" % [c.name(), roll], c.id)
			e.events.append({"type": "condition", "id": c.id})
		else:
			e.log.add("info", "%s stays put (Blink d6: %d)" % [c.name(), roll], c.id)


## After `target` took damage: effects that end when the caster's side hurts it (Charm Person), repeated saves on
## damage (Tasha's Hideous Laughter, with Advantage), Warding Bond's shared damage.
func on_damaged(source: Combatant, target: Combatant, amount: int, parts: Array) -> void:
	var spells := sp()
	var e := enc()
	if amount <= 0:
		return
	for fx: Effect in target.creature.effects.duplicate():
		if not fx in target.creature.effects:
			continue
		if "damaged_by_caster_side" in fx.ends_on and source != null:
			var caster := e.get_c(fx.caster_id)
			if caster != null and (source == caster or source.allied_with(caster)):
				target.creature.remove_effect(fx)
				e.log.add("info", "%s ends: %s was hurt by the caster's side" % [fx.name, target.name()], target.id)
				continue
		if bool(fx.repeat_save.get("on_damage", false)) and target.is_alive() and target.creature.hp > 0:
			var adv: Array[String] = []
			if bool(fx.repeat_save.get("damage_advantage", false)):
				adv.append("took damage")
			spells._repeat_save(target, fx, adv)
		if fx.source_id == "warding_bond" and fx.stack_key == "spell:warding_bond:link":
			var warder := e.get_c(str(fx.data.get("caster", "")))
			if warder != null and warder.is_alive() and warder != target:
				var share := e.deal_damage(null, warder, [{"amount": amount, "type": str((parts[0] as Dictionary).get("type", "force")) if not parts.is_empty() else "force"}], false, "Warding Bond",
					["%s shares %s's pain" % [warder.name(), target.name()]])
				if warder.creature.hp <= 0:
					_end_warding(target)
				if share == null:
					pass


func _end_warding(t: Combatant) -> void:
	for fx: Effect in t.creature.effects.duplicate():
		if fx.source_id == "warding_bond":
			t.creature.remove_effect(fx)


## Removes effects on `c` that end when it does `what` (attack_roll, deal_damage, cast_spell): Invisibility.
func trigger_ends(c: Combatant, what: String) -> void:
	var gone := false
	for fx: Effect in c.creature.effects.duplicate():
		if what in fx.ends_on:
			c.creature.remove_effect(fx)
			enc().log.add("info", "%s ends (%s)" % [fx.name, what.replace("_", " ")], c.id)
			gone = true
	if gone:
		enc().events.append({"type": "condition", "id": c.id})


## Areas creatures walk into: SpellZones triggers and auras.
func on_enter_cell(c: Combatant, from: Vector2i = Vector2i(-9999, -9999)) -> void:
	var spells := sp()
	spells.zones.on_moved(c, from)


func can_see_or_hear(observer: Combatant, source: Combatant) -> bool:
	var spells := sp()
	return enc().can_see(observer, source) or (not observer.creature.has_condition(&"deafened") \
		and not spells.zones.silenced(observer.cell) and not spells.zones.silenced(source.cell))


func check_tethers() -> void:
	var spells := sp()
	var e := enc()
	for target in e.combatants:
		for fx: Effect in target.creature.effects.duplicate():
			var tether := fx.data.get("tether", {}) as Dictionary
			if tether.is_empty():
				continue
			var caster := e.get_c(fx.caster_id)
			if caster == null or e.distance(caster, target) > int(tether.get("range", 9999)) \
					or (bool(tether.get("perceive_caster", false)) and not can_see_or_hear(target, caster)):
				target.creature.remove_effect(fx)
	for a: Dictionary in spells.sustained.duplicate():
		var d := a["def"] as Dictionary
		if not bool(d.get("tether", false)):
			continue
		var c := e.get_c(str(a["caster_id"]))
		var t := e.get_c(str(a["target_id"]))
		if c != null and (t == null or not t.is_alive() or e.distance(c, t) > int(d.get("range", 60)) or int(e.cover(c, t)["cover"]) == CombatGrid.Cover.TOTAL):
			spells._end_spell_of(c, str(a["spell_id"]), "the target got away")
