class_name FaerunFamiliars
extends FaerunCommon
## Familiars in a fight (FaerunFeatures): Arcana Unleashed's familiar feats (Familiar Friend, Elemental, Otherworldly
## and Soothing Familiar) and Find Familiar's own commands (2024 PHB).


## The familiar Find Familiar gave `c` (alive and on the field), or null.
func familiar_of(c: Combatant) -> Combatant:
	if c == null:
		return null
	var e := enc()
	for sid: Variant in e.spells.summoned.get(c.id, []):
		var f := e.get_c(str(sid))
		if f != null and f.is_alive() and f.creature is Monster and bool((f.creature as Monster).data.get("familiar", false)):
			return f
	return null


## The pick `c` made for a benefit of one of its feats, or "".
func _feat_pick(c: Combatant, feat_id: String, benefit_id: String) -> String:
	var ch := _ch(c)
	if ch == null:
		return ""
	for f in ch.feats_taken:
		if str(f["id"]) == feat_id:
			var picks := ch.picks_for("%s.%s" % [str(f["key"]), benefit_id])
			if not picks.is_empty():
				return str(picks[0])
	return ""


## 8 + the spellcasting modifier Familiar Friend casts Find Familiar with + the Proficiency Bonus.
func _familiar_dc(c: Combatant) -> int:
	var ab := _feat_pick(c, "familiar_friend", "faithful_companion_spell")
	var mod := c.creature.ability_mod(StringName(ab)) if Creature.ABILITY_NAMES.has(StringName(ab)) else 0
	return 8 + mod + c.creature.proficiency_bonus()


## Fortified Familiar (twice the character level in Hit Points), the Resistance Elemental or Otherworldly Familiar
## picks, and the Otherworldly familiar's passage through creatures and objects.
func _familiar_feats(c: Combatant, ch: Character, m: Creature) -> void:
	if feat(c, "familiar_friend"):
		var more := 2 * ch.character_level()
		var fx := Effect.new("Fortified Familiar", &"feature", "familiar_friend").with_modifier("hp_max", {"value": more})
		fx.ends = Effect.Ends.NEVER
		m.add_effect(fx)
		m.hp += more
	for fid: String in ["elemental_familiar", "otherworldly_familiar"]:
		if not feat(c, fid):
			continue
		var fx2 := Effect.new(str(Compendium.shared().feat_data(fid).get("name", fid)), &"feature", fid)
		var ty := _feat_pick(c, fid, fid + "_resistance")
		if ty != "":
			fx2.with_modifier("resistance", {"value": ty})
		if fid == "otherworldly_familiar":
			fx2.with_modifier("flag", {"value": "incorporeal_movement"})
			fx2.with_modifier("flag", {"value": "otherworldly_familiar"})
		fx2.ends = Effect.Ends.NEVER
		m.add_effect(fx2)


## Helpful Friend: a check with a skill `c` is proficient in has Advantage while its familiar is within 5 ft, spending
## a use (on its own unless turned Off).
func _helpful_friend(c: Combatant, keys: Array[String]) -> bool:
	var ch := _ch(c)
	if ch == null or not feat(c, "familiar_friend") or ch.resource_left("helpful_friend") <= 0:
		return false
	if str(c.reaction_rules.get("helpful_friend", "auto")) != "auto":
		return false
	var proficient := false
	for k in keys:
		var skill := StringName(k.trim_prefix("check:"))
		if k.begins_with("check:") and Abilities.SKILLS.has(skill) and ch.skill_rank(skill) >= 1:
			proficient = true
	var fam := familiar_of(c)
	if not proficient or fam == null or enc().distance(c, fam) > 5:
		return false
	ch.spend_resource("helpful_friend")
	_log("info", "%s's familiar lends a hand (Helpful Friend)" % c.name(), c)
	return true


## Why Elemental Familiar's burst can't happen now, or "".
func _burst_why(c: Combatant) -> String:
	var e := enc()
	var fam := familiar_of(c)
	var why := e._bonus_check(c)
	if why != "":
		return why
	if fam == null:
		return "No familiar on the field"
	if fam.has_meta("pocket"):
		return "Your familiar is in its pocket dimension"
	if not fam.reaction_available or not fam.can_act():
		return "Your familiar can't use its Reaction"
	if e.distance(c, fam) > 120:
		return "Your familiar is more than 120 ft away"
	return ""


## Elemental Familiar: a Bonus Action command; the familiar spends its Reaction and each other creature within 5 ft of
## it makes a Dexterity save or takes 2d4 of the picked type, a Medium or smaller one also falling Prone.
func _elemental_burst(c: Combatant) -> CombatResult:
	var e := enc()
	var why := _burst_why(c)
	if why != "":
		return CombatResult.fail(why)
	var fam := familiar_of(c)
	c.bonus_available = false
	fam.reaction_available = false
	var ty := _feat_pick(c, "elemental_familiar", "elemental_familiar_resistance")
	if ty == "":
		ty = "fire"
	var dc := _familiar_dc(c)
	var caught: Array[Combatant] = []
	for o in e.combatants:
		if o != fam and o.is_alive() and e.distance(fam, o) <= 5:
			caught.append(o)
	e.events.append({"type": "ability", "source": "feature", "by": fam.id, "key": "elemental_familiar:%s" % ty,
		"targets": caught.map(func(x: Combatant) -> String: return x.id), "cells": []})
	_log("ability", "%s's familiar bursts with %s (Elemental Familiar, Dex DC %d)" % [c.name(), ty.capitalize(), dc], c)
	for o in caught:
		var sv := o.creature.roll_save(e.dice, &"dex", dc, [], [], "Dexterity save vs Elemental Familiar (%s)" % o.name())
		if sv.success:
			_log("info", "%s dodges the burst" % o.name(), o, [sv.describe()])
			continue
		var rolled := e._roll_damage_dice("2d4", false, 0, "Elemental Familiar")
		e.deal_damage(fam, o, [{"amount": int(rolled["total"]), "type": ty}], false, "Elemental Familiar", [sv.describe(), str(rolled["text"])])
		if o.is_alive() and Creature.SIZES.find(o.creature.size) <= Creature.SIZES.find(&"medium") and not o.creature.has_condition(&"prone"):
			o.creature.add_condition(&"prone", "Elemental Familiar")
			_log("condition", "%s is knocked Prone (Elemental Familiar)" % o.name(), o)
			e.events.append({"type": "condition", "id": o.id})
	return CombatResult.new()


## Otherworldly Familiar: ending its turn inside an object puts the familiar back in the last open space it moved
## through (else the nearest one).
func _otherworldly_return(c: Combatant) -> void:
	if not c.creature.has_flag("otherworldly_familiar") or c.has_meta("pocket"):
		return
	var e := enc()
	if not c.footprint().any(func(cell: Vector2i) -> bool: return e.grid.is_solid(cell)):
		return
	var back := Vector2i(-1, -1)
	for i in range(c.approach_path.size() - 1, -1, -1):
		var cell: Vector2i = c.approach_path[i]
		if cell != c.cell and e.spells._room_for(cell, c.size_cells):
			back = cell
			break
	if back.x < 0:
		back = e.spells._free_cell_near(c.cell, c.size_cells)
	var from := c.cell
	c.cell = back
	e.events.append({"type": "teleport", "id": c.id, "from": from, "to": back})
	_log("info", "%s slips back out of the solid object (Otherworldly Familiar)" % c.name(), c)


## Soothing Familiar: you and your allies within 5 ft of your familiar (while it's within 120 ft of you) treat each 1
## or 2 on healing dice as a 3. The lowest a healing die can count as for `t` (0 = as rolled).
func healing_floor(t: Combatant) -> int:
	if t == null:
		return 0
	var e := enc()
	for h in e.combatants:
		if not h.is_alive() or (h != t and not h.allied_with(t)) or not feat(h, "soothing_familiar"):
			continue
		var fam := familiar_of(h)
		if fam != null and fam != t and e.distance(h, fam) <= 120 and e.distance(fam, t) <= 5:
			return 3
	return 0


## Magic actions for the caster of Find Familiar: send the familiar to its pocket dimension, call it back to a space
## within 30 ft, or dismiss it for good.
func _familiar_list(c: Combatant, out: Array[Dictionary]) -> void:
	var fam := familiar_of(c)
	if fam == null:
		return
	var e := enc()
	var aw := _first(e._action_check(c), "Only one Magic action this turn" if c.magic_action_used else "")
	if fam.has_meta("pocket"):
		out.append(_entry("familiar_back", "Call Familiar Back", "%s · within 30 ft" % fam.name(), "action", aw, "point",
			"Magic action: your familiar returns from its pocket dimension to an unoccupied space within 30 ft of you.", 30))
	else:
		out.append(_entry("familiar_away", "Send Familiar Away", "%s · pocket dimension" % fam.name(), "action", aw, "none",
			"Magic action: your familiar steps into a pocket dimension, out of the fight until you call it back."))
	out.append(_entry("familiar_dismiss", "Dismiss Familiar", "%s · for good" % fam.name(), "action", aw, "none",
		"Magic action: your familiar is gone until you cast Find Familiar again."))


func _familiar_command(c: Combatant, id: String, cell: Vector2i) -> CombatResult:
	var e := enc()
	var fam := familiar_of(c)
	if fam == null:
		return CombatResult.fail("No familiar")
	var why := _first(e._action_check(c), "Only one Magic action this turn" if c.magic_action_used else "")
	if why != "":
		return CombatResult.fail(why)
	match id:
		"familiar_away":
			if fam.has_meta("pocket"):
				return CombatResult.fail("Already in its pocket dimension")
			pocket_familiar(c)
			_log("info", "%s sends %s to its pocket dimension" % [c.name(), fam.name()], c)
		"familiar_back":
			if not fam.has_meta("pocket"):
				return CombatResult.fail("Your familiar is already here")
			var to := cell
			if to.x < 0 or e.grid.distance_ft(c.cell, c.size_cells, to, fam.size_cells) > 30 or not e.spells._room_for(to, fam.size_cells):
				if to.x >= 0:
					return CombatResult.fail("Choose an unoccupied space within 30 ft")
				to = e.spells._free_cell_near(c.cell, fam.size_cells)
			for fx2: Effect in fam.creature.effects.duplicate():
				if fx2.name == "Pocket Dimension":
					fam.creature.remove_effect(fx2)
			fam.remove_meta("pocket")
			_ch(c).familiar = "here"
			fam.cell = to
			e.events.append({"type": "teleport", "id": fam.id, "from": to, "to": to})
			_log("info", "%s calls %s back" % [c.name(), fam.name()], c)
		"familiar_dismiss":
			e.spells._dismiss(fam.id)
			_ch(c).familiar = ""
	e.spend_action(c)
	c.magic_action_used = true
	return CombatResult.new()


## Puts `c`'s familiar in its pocket dimension: off the grid, Incapacitated and untouchable until called back.
func pocket_familiar(c: Combatant) -> void:
	var fam := familiar_of(c)
	if fam == null or fam.has_meta("pocket"):
		return
	var fx := Effect.new("Pocket Dimension", &"spell", "find_familiar").with_modifier("flag", {"value": "ethereal"}) \
		.with_modifier("flag", {"value": "pocket_dimension"})
	fx.conditions.append(&"incapacitated")
	fx.ends = Effect.Ends.NEVER
	fam.creature.add_effect(fx)
	fam.set_meta("pocket", [fam.cell.x, fam.cell.y])
	fam.cell = FaerunFeatures.POCKET_CELL
	enc().events.append({"type": "vanish", "id": fam.id})
	if _ch(c) != null:
		_ch(c).familiar = "pocket"


## A familiar that drops to 0 Hit Points is gone until its caster casts Find Familiar again.
func _familiar_lost(dead: Combatant) -> void:
	if not dead.creature is Monster or not bool((dead.creature as Monster).data.get("familiar", false)) or not dead.has_meta("summoner"):
		return
	var owner := _ch(enc().get_c(str(dead.get_meta("summoner"))))
	if owner != null and familiar_of(enc().get_c(str(dead.get_meta("summoner")))) == null:
		owner.familiar = ""
