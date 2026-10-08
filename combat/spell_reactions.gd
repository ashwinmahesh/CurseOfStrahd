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


## Reaction spells that answer a failed d20 roll (Reweave Fate: the roll again with Advantage; Moment of Prescience: a
## 20), settled now: only when the creature's rule for the spell is Automatic.
func after_failed_d20(roller: Combatant, test: D20Test) -> void:
	var out: Array = []
	d20_offers(roller, test, out)
	enc().d20.run_now(out)


## The same as offers (D20Responses): asked about where the roll can pause.
func d20_offers(roller: Combatant, test: D20Test, out: Array) -> void:
	var spells := sp()
	var e := enc()
	if test.target <= 0 or test.auto_failed:
		return
	for c in e.living():
		var ch := spells.caster_char(c)
		if ch == null or (c != roller and not c.allied_with(roller)):
			continue
		for known in ch.known_spells():
			var s := _comp().spell_data(str(known["id"]))
			var response := s.get("roll_response", {}) as Dictionary
			if response.is_empty() or (str(response.get("scope", "self")) == "self" and c != roller):
				continue
			var visible := str(response.get("scope", "self")) == "visible"
			var caster := c
			var sid := str(s["id"])
			var sname := str(s["name"])
			out.append({"kind": sid, "reactor": c, "trigger": roller.id, "sync": "decision", "title": "Reaction: %s?" % sname,
				"text": func() -> String: return "%s. %s %s?" % [D20Responses.line(roller, test), caster.name() + " can cast " + sname if caster != roller else "Cast " + sname,
					"so the roll is a 20" if response.has("natural") else "so it's rolled again with Advantage"],
				"cost": "Reaction and a spell slot",
				"still": func() -> bool: return not test.success and can_cast_reaction(caster, sid) \
					and (not visible or (e.distance(caster, roller) <= spells.range_ft(s, caster) and e.can_see(caster, roller))),
				"helps": func() -> bool: return D20Responses.could_reach(test, int(response.get("natural", 20))),
				"use": func() -> void:
					if not begin_reaction_spell(caster, sid):
						return
					if response.has("natural"):
						test.set_natural(int(response["natural"]), sname)
					else:
						test.reroll(e.dice, sname, true)
					if test.success and response.has("success_temp_hp"):
						roller.creature.add_temp_hp(int(e.dice.roll_expr(str(response["success_temp_hp"]), sname)["total"]), sname)
					e.log.add("save", test.describe(), roller.id)})


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
	return e.then(spells._generic(ctx, tgt, [], r, true), func() -> CombatResult:
		e._check_over()
		return r)


## War Caster's Reactive Spell (2024): with the Reaction, instead of an Opportunity Attack, a spell with a casting time
## of an action aimed at `target` alone (every dart or ray of a spell that has several), spending its lowest slot.
func cast_reactive_spell(c: Combatant, spell_id: String, target: Combatant) -> CombatResult:
	var spells := sp()
	var e := enc()
	var s := _comp().spell_data(spell_id)
	var level := int(s.get("level", 0))
	var ch := spells.caster_char(c)
	var slot := 0
	if level > 0:
		slot = _lowest_slot(ch, level) if ch != null else 0
		if slot == 0:
			return CombatResult.new()
	if not can_react(c):
		return CombatResult.new()
	c.reaction_available = false
	if not spells.casting_gate(c):
		return CombatResult.new()
	if slot > 0:
		ch.expend_slot(slot)
		c.cast_slot_spell_this_turn = true
	var conc: Concentration = null
	if bool((s.get("duration", {}) as Dictionary).get("concentration", false)):
		conc = c.creature.begin_concentration(spell_id, str(s["name"]))
	var entry := spells._entry_any(c, spell_id)
	e.log.add("spell", "%s answers with %s (War Caster%s)" % [c.name(), s["name"], ", level %d slot" % slot if slot > 0 else ""], c.id)
	e.events.append({"type": "spell", "caster": c.id, "spell": spell_id, "cells": [], "targets": [target.id]})
	spells.trigger_ends(c, "cast_spell")
	var ctx := {"c": c, "s": s, "slot": maxi(slot, level), "nums": spells.numbers(c, entry), "conc": conc, "opts": {}, "point": e.center_of(target),
		"cells": [], "choice": SpellCaster.choice_of(s, {}), "direction": (e.center_of(target) - e.center_of(c)).normalized(), "cell": target.cell}
	var r := CombatResult.new()
	var tgt: Array[Combatant] = [target]
	var count := int((s.get("targets", {}) as Dictionary).get("count", 1))
	if count > 1 and (spell_id in ["magic_missile", "scorching_ray"] or bool(s.get("repeat_targets", false))):
		for i in count - 1:
			tgt.append(target)
	return e.then(spells._resolve(ctx, tgt, [], r, true), func() -> CombatResult:
		spells.check_tethers()
		spells._finish_concentration(ctx)
		spells.zones.prune()
		e._check_over()
		return r)


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
	return e.then(spells._resolve(ctx, tgt, cells, r, true), func() -> CombatResult:
		spells.check_tethers()
		spells._finish_concentration(ctx)
		spells.zones.prune()
		e._check_over()
		return r)
