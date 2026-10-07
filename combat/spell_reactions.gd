class_name SpellReactions
extends RefCounted
## Spells cast as a Reaction in a fight (SpellCaster): Shield, Counterspell, Hellish Rebuke and the like, spells that
## answer a d20 roll (Silvery Barbs), whether a creature can react at all, and releasing a readied spell.

var _enc: WeakRef


func _init(encounter: Encounter) -> void:
	_enc = weakref(encounter)


func enc() -> Encounter:
	return _enc.get_ref() as Encounter


func sp() -> SpellCaster:
	return enc().spells


func _comp() -> Compendium:
	return Compendium.shared()


## Begin a reaction spell without assuming its result (casting disruption can consume only the Reaction).
func begin_reaction_spell(c: Combatant, spell_id: String) -> bool:
	var spells := sp()
	if not can_cast_reaction(c, spell_id):
		return false
	c.reaction_available = false
	if not spells.casting_gate(c):
		return false
	var s := _comp().spell_data(spell_id)
	spells.caster_char(c).expend_slot(_lowest_slot(spells.caster_char(c), int(s["level"])))
	c.cast_slot_spell_this_turn = true
	spells.trigger_ends(c, "cast_spell")
	enc().log.add("spell", "%s casts %s" % [c.name(), s["name"]], c.id)
	return true


## A synchronous D20 resolver cannot pause. Reaction spells require an explicit automatic decision.
func after_failed_d20(roller: Combatant, test: D20Test) -> void:
	var spells := sp()
	if test.success or test.target <= 0 or test.auto_failed:
		return
	for c in enc().living():
		var ch := spells.caster_char(c)
		if ch == null or (c != roller and not c.allied_with(roller)):
			continue
		for known in ch.known_spells():
			if test.success:
				return
			var s := _comp().spell_data(str(known["id"]))
			var response := s.get("roll_response", {}) as Dictionary
			if response.is_empty() or (str(response.get("scope", "self")) == "self" and c != roller):
				continue
			if str(response.get("scope", "self")) == "visible" and (enc().distance(c, roller) > spells.range_ft(s, c) or not enc().can_see(c, roller)):
				continue
			if enc()._reaction_decision(c, str(s["id"])) != "auto" or not begin_reaction_spell(c, str(s["id"])):
				continue
			if response.has("natural"):
				test.set_natural(int(response["natural"]), str(s["name"]))
			else:
				var again := D20Test.roll(enc().dice, test.kind, test.modifier, test.target, 1, 1 if test.disadvantage else 0, str(s["name"]), test.crit_range, test.extra, test.extra_label)
				test.set_natural(again.kept, str(s["name"]))
				test.rolls = again.rolls
				test.advantage = again.advantage
				test.disadvantage = again.disadvantage
			if test.success and response.has("success_temp_hp"):
				roller.creature.add_temp_hp(int(enc().dice.roll_expr(str(response["success_temp_hp"]), str(s["name"]))["total"]), str(s["name"]))
			enc().log.add("save", test.describe(), roller.id)


## Spell attack resolution is synchronous; weapon/monster attacks offer the same response interactively.
func answer_incoming_roll(c: Combatant, test: D20Test, spell_id: String) -> bool:
	if not test.success or not begin_reaction_spell(c, spell_id):
		return false
	var s := _comp().spell_data(spell_id)
	test.set_natural(int((s["roll_response"] as Dictionary)["incoming_natural"]), str(s["name"]))
	return not test.success


func incoming_roll_responses(c: Combatant) -> Array[String]:
	var spells := sp()
	var out: Array[String] = []
	if spells.caster_char(c) == null:
		return out
	for known in spells.caster_char(c).known_spells():
		var id := str(known["id"])
		if not id in out and (_comp().spell_data(id).get("roll_response", {}) as Dictionary).has("incoming_natural") and can_cast_reaction(c, id):
			out.append(id)
	return out


func can_cast_reaction(c: Combatant, spell_id: String) -> bool:
	var spells := sp()
	if spells.caster_char(c) == null or not can_react(c):
		return false
	var ch := spells.caster_char(c)
	if not ch.knows_spell(spell_id):
		return false
	var s := _comp().spell_data(spell_id)
	if str(s.get("automation", "")) == "reference" or c.cast_slot_spell_this_turn or c.creature.has_flag("cant_cast") or spells.specials.high.in_antimagic(c):
		return false
	if bool((s.get("components", {}) as Dictionary).get("v", false)):
		if c.creature.has_flag("speechless"):
			return false
		for cell in c.footprint():
			if spells.zones.silenced(cell):
				return false
	var armor := ch.equipped("armor")
	if not armor.is_empty() and not ch.trained_for(armor):
		return false
	var level := int(s.get("level", 1))
	for l in range(level, 10):
		if ch.slots_left(l) > 0:
			return true
	return false


## Whether `c` can take a Reaction now (it has one, can act, and nothing stops it: Shocking Grasp, Slow).
func can_react(c: Combatant) -> bool:
	return c.reaction_available and c.can_act() and not c.creature.has_flag("no_reactions") and not c.creature.has_flag("slowed") \
		and not enc().has_mark("no_reactions", c.id)


func _lowest_slot(ch: Character, from_level: int) -> int:
	for l in range(from_level, 10):
		if ch.slots_left(l) > 0:
			return l
	return 0


## Shield (2024): +5 AC until the start of your next turn, as a Reaction, with a level 1 slot (the lowest
## available). Also stops Magic Missile.
func cast_shield(c: Combatant) -> bool:
	var spells := sp()
	if not can_cast_reaction(c, "shield"):
		return false
	c.reaction_available = false
	if not spells.casting_gate(c):
		return false
	var ch := spells.caster_char(c)
	var l := _lowest_slot(ch, 1)
	if l > 0:
		ch.expend_slot(l)
	c.cast_slot_spell_this_turn = true
	var e := Effect.new("Shield", &"spell", "shield").with_modifier("ac", {"value": 5})
	e.ends = Effect.Ends.START_OF_TURN
	e.turn_owner_id = c.id
	e.spell_level = maxi(1, l)
	c.creature.add_effect(e)
	enc().log.add("spell", "%s casts Shield (+5 AC until its next turn)" % c.name(), c.id)
	return true


## A reaction spell answering `trigger` (Hellish Rebuke against whoever hurt the caster; Counterspell against a
## caster): the Reaction and the lowest slot are spent, then the spell resolves against the trigger.
func cast_reaction_spell(c: Combatant, spell_id: String, trigger: Combatant) -> CombatResult:
	var spells := sp()
	var e := enc()
	var ch := spells.caster_char(c)
	var s := _comp().spell_data(spell_id)
	var slot := _lowest_slot(ch, int(s.get("level", 1)))
	if slot == 0 or not can_react(c):
		return CombatResult.new()
	c.reaction_available = false
	if not spells.casting_gate(c):
		return CombatResult.new()
	ch.expend_slot(slot)
	c.cast_slot_spell_this_turn = true
	var entry := spells._entry_any(c, spell_id)
	var nums := spells.numbers(c, entry)
	e.log.add("spell", "%s answers with %s (level %d slot)" % [c.name(), s["name"], slot], c.id)
	e.events.append({"type": "spell", "caster": c.id, "spell": spell_id, "cells": [], "targets": [trigger.id]})
	spells.trigger_ends(c, "cast_spell")
	var ctx := {"c": c, "s": s, "slot": slot, "nums": nums, "conc": null, "opts": {}, "choice": "", "point": Vector2.INF}
	var r := CombatResult.new()
	var tgt: Array[Combatant] = [trigger]
	spells._generic(ctx, tgt, [], r)
	e._check_over()
	return r


## Releases a readied spell at `target` (the creature that triggered it) with the Reaction: its slot was spent when
## it was readied. Areas are centred on (or aimed at) the target.
func release_readied(c: Combatant, held: Dictionary, target: Combatant) -> CombatResult:
	var spells := sp()
	var e := enc()
	var conc := held.get("conc") as Concentration
	if conc != null and conc.ended:
		return CombatResult.new()
	var spell_id := str(held["spell"])
	var s := _comp().spell_data(spell_id)
	c.reaction_available = false
	if conc != null:
		conc.ended = true
		if c.creature.concentration == conc:
			c.creature.concentration = null
	var new_conc: Concentration = null
	if bool((s.get("duration", {}) as Dictionary).get("concentration", false)):
		new_conc = c.creature.begin_concentration(spell_id, str(s["name"]))
	var entry := spells._entry_any(c, spell_id)
	var point := e.center_of(target)
	var dir := (point - e.center_of(c)).normalized()
	var cells: Array[Vector2i] = []
	if s.has("area"):
		cells = spells.area_for(c, s, point, dir, int(held["slot"]))
	e.log.add("reaction", "%s releases the readied %s at %s" % [c.name(), s["name"], target.name()], c.id)
	e.events.append({"type": "spell", "caster": c.id, "spell": spell_id, "cells": cells, "targets": [target.id]})
	var ctx := {"c": c, "s": s, "slot": int(held["slot"]), "nums": spells.numbers(c, entry), "conc": new_conc, "opts": {},
		"point": point, "cells": cells, "choice": SpellCaster.choice_of(s, {}), "direction": dir, "cell": target.cell}
	var r := CombatResult.new()
	var tgt: Array[Combatant] = [target]
	spells._resolve(ctx, tgt, cells, r)
	spells.check_tethers()
	spells._finish_concentration(ctx)
	spells.zones.prune()
	e._check_over()
	return r
