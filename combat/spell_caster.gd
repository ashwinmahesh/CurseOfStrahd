class_name SpellCaster
extends RefCounted
## Spells in combat (plan §5.3), driven by the spell data: casting time and the action economy, spell slots
## (one slot-spell per turn, 2024), free uses from species and feats, Concentration, range and line of effect,
## areas of effect on the grid, spell attacks, saving throws (damage rolled once for every target, half on a
## success, Dexterity saves get cover), healing with Disciple of Life, buffs as Effects, and conditions with
## repeated saves. A few spells need their own rules (Magic Missile, Shield, Sleep, Command, Sanctuary, Spiritual
## Weapon, Toll the Dead, Thunderwave, Guiding Bolt, Shocking Grasp); everything else is generic.

## Spells whose combat rules are implemented, beyond what the generic data path covers.
const SPECIAL := ["magic_missile", "shield", "sleep", "command", "sanctuary", "spiritual_weapon", "toll_the_dead",
	"thunderwave", "guiding_bolt", "shocking_grasp", "aid", "spare_the_dying", "chromatic_orb", "sacred_flame",
	"ray_of_frost", "chill_touch", "mage_armor"]
const COMMAND_WORDS := ["grovel", "halt", "flee"]

var _enc: WeakRef
## Spectral weapons from Spiritual Weapon: caster id -> {cell: Vector2i, slot: int}
var spirit_weapons: Dictionary = {}


func _init(encounter: Encounter) -> void:
	_enc = weakref(encounter)


func enc() -> Encounter:
	return _enc.get_ref() as Encounter


func _comp() -> Compendium:
	return Compendium.shared()


# --- What can be cast -----------------------------------------------------------------------------

## Every spell `c` knows with whether it can cast it now and why not:
## {id, name, level, class_id, ability, free: bool, casting: action|bonus_action|reaction, legal, reason}
func castable(c: Combatant) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	if not c.creature is Character:
		return out
	var ch := c.creature as Character
	var seen := {}
	for k in ch.known_spells():
		var id := str(k["id"])
		if seen.has(id):
			continue
		seen[id] = true
		var s := _comp().spell_data(id)
		if s.is_empty():
			continue
		var level := int(s.get("level", 0))
		var unit := str((s.get("casting_time", {}) as Dictionary).get("unit", "action"))
		var entry := {"id": id, "name": str(s["name"]), "level": level, "class_id": str(k.get("class_id", "")),
			"ability": str(k.get("ability", "")), "free": false, "casting": unit, "legal": true, "reason": ""}
		var res_id := "spell:%s" % id
		if str(k["kind"]) == "granted" and ch.resource_left(res_id) > 0:
			entry["free"] = true
		var why := _why_not(c, s, entry)
		if why != "":
			entry["legal"] = false
			entry["reason"] = why
		out.append(entry)
	out.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return int(a["level"]) < int(b["level"]) or (int(a["level"]) == int(b["level"]) and str(a["name"]) < str(b["name"])))
	return out


func _why_not(c: Combatant, s: Dictionary, entry: Dictionary) -> String:
	if not has_combat_rules(s):
		return "No effect in this fight yet"
	var ch := c.creature as Character
	var unit := str(entry["casting"])
	if unit == "reaction":
		return "Cast as a Reaction when it triggers"
	if unit in ["minute", "hour"]:
		return "Takes too long to cast in combat"
	if unit == "action" and not c.action_available:
		return "Action already used"
	if unit == "action" and c.magic_action_used:
		return "Only one Magic action this turn (Action Surge's action can't be Magic)"
	if unit == "bonus_action" and not c.bonus_available:
		return "Bonus Action already used"
	if c.creature.has_flag("speechless") and bool((s.get("components", {}) as Dictionary).get("v", false)):
		return "Can't speak"
	var armor := ch.equipped("armor")
	if not armor.is_empty() and not ch.has_armor_training(str((armor["armor"] as Dictionary)["kind"])):
		return "Wearing armor without training"
	var level := int(s.get("level", 0))
	if level > 0 and not bool(entry["free"]):
		if c.cast_slot_spell_this_turn:
			return "Already cast a spell with a slot this turn"
		var any := false
		for l in range(level, 10):
			if ch.slots_left(l) > 0:
				any = true
		if not any:
			return "No spell slots of level %d or higher left" % level
	return ""


## True if the spell does something the combat engine can resolve.
func has_combat_rules(s: Dictionary) -> bool:
	if str(s.get("id", "")) in SPECIAL:
		return true
	return s.has("attack") or s.has("save") or s.has("heal") or s.has("damage") or not (s.get("effects", []) as Array).is_empty()


func can_cast_reaction(c: Combatant, spell_id: String) -> bool:
	if not c.creature is Character or not c.reaction_available or not c.can_act():
		return false
	var ch := c.creature as Character
	if not ch.knows_spell(spell_id):
		return false
	var s := _comp().spell_data(spell_id)
	var level := int(s.get("level", 1))
	for l in range(level, 10):
		if ch.slots_left(l) > 0:
			return true
	return false


## Shield (2024): +5 AC until the start of your next turn, as a Reaction, with a level 1 slot (the lowest
## available).
func cast_shield(c: Combatant) -> void:
	var ch := c.creature as Character
	for l in range(1, 10):
		if ch.slots_left(l) > 0:
			ch.expend_slot(l)
			break
	c.reaction_available = false
	var e := Effect.new("Shield", &"spell", "shield").with_modifier("ac", {"value": 5})
	e.ends = Effect.Ends.START_OF_TURN
	e.turn_owner_id = c.id
	c.creature.add_effect(e)
	enc().log.add("spell", "%s casts Shield (+5 AC until its next turn)" % c.name(), c.id)


## A long-lasting spell cast before the fight (Mage Armor): its lowest slot is spent and its effect applied.
func precast(c: Combatant, spell_id: String) -> bool:
	if not c.creature is Character:
		return false
	var ch := c.creature as Character
	var s := _comp().spell_data(spell_id)
	var entry := _entry_any(c, spell_id)
	if s.is_empty() or entry.is_empty():
		return false
	var level := int(s.get("level", 0))
	var slot := 0
	if level > 0:
		for l in range(level, 10):
			if ch.slots_left(l) > 0:
				slot = l
				break
		if slot == 0:
			return false
		ch.expend_slot(slot)
	var conc: Concentration = null
	if bool((s.get("duration", {}) as Dictionary).get("concentration", false)):
		conc = c.creature.begin_concentration(spell_id, str(s["name"]))
	enc().log.add("spell", "%s cast %s before the fight%s" % [c.name(), s["name"], " (level %d slot)" % slot if slot > 0 else ""], c.id)
	var ctx := {"c": c, "s": s, "slot": slot, "nums": numbers(c, entry), "conc": conc, "opts": {}}
	_apply_effects(ctx, c, CombatResult.new())
	return true


# --- Casting numbers ------------------------------------------------------------------------------

func _entry(c: Combatant, spell_id: String) -> Dictionary:
	for e in castable(c):
		if str(e["id"]) == spell_id:
			return e
	return {}


## {dc: Breakdown, attack: Breakdown, mod: int}
func numbers(c: Combatant, entry: Dictionary) -> Dictionary:
	var ch := c.creature as Character
	var cid := str(entry.get("class_id", ""))
	if cid != "" and not ch.spellcasting_entry(cid).is_empty():
		var ab := StringName(str(ch.spellcasting_entry(cid)["ability"]))
		return {"dc": ch.spell_save_dc(cid), "attack": ch.spell_attack_bonus(cid), "mod": ch.ability_mod(ab)}
	var ab2 := StringName(str(entry.get("ability", "int")))
	if not Creature.ABILITY_NAMES.has(ab2):
		ab2 = &"int"
	var mod := ch.ability_mod(ab2)
	var dc := Breakdown.new("Spell save DC")
	dc.add("Base", 8).add("%s modifier" % Creature.ABILITY_SHORT[ab2], mod).add("Proficiency", ch.proficiency_bonus())
	var atk := Breakdown.new("Spell attack")
	atk.add("%s modifier" % Creature.ABILITY_SHORT[ab2], mod).add("Proficiency", ch.proficiency_bonus())
	return {"dc": dc, "attack": atk, "mod": mod}


func range_ft(s: Dictionary) -> int:
	var r := s.get("range", {}) as Dictionary
	match str(r.get("kind", "self")):
		"feet":
			return int(r.get("feet", 0))
		"touch":
			return 5
		"self":
			return 0
	return 9999


func target_count(s: Dictionary, slot: int) -> int:
	var base := int((s.get("targets", {}) as Dictionary).get("count", 1))
	var up := s.get("upcast", {}) as Dictionary
	var extra := maxi(0, slot - int(s.get("level", 0)))
	return base + int(up.get("targets", 0)) * extra + int(up.get("projectiles", 0)) * extra


## The area a spell would cover: cells and the point of origin.
func area_for(c: Combatant, s: Dictionary, point: Vector2, direction: Vector2) -> Array[Vector2i]:
	var area := s.get("area", {}) as Dictionary
	if area.is_empty():
		return []
	var shape := str(area["shape"])
	var size := int(area["size"])
	var g := enc().grid
	var center := Vector2(c.cell.x + c.size_cells / 2.0, c.cell.y + c.size_cells / 2.0)
	var self_origin := str((s.get("range", {}) as Dictionary).get("kind", "")) == "self"
	if shape == "emanation":
		return g.area_cells("emanation", size, center, Vector2.RIGHT, 5, c.cell, c.size_cells)
	if self_origin:
		var dir := direction.normalized() if direction.length() > 0.01 else Vector2(c.facing)
		if dir.length() < 0.01:
			dir = Vector2.RIGHT
		var origin := center + dir * (c.size_cells / 2.0)
		return g.area_cells(shape, size, origin, dir, int(area.get("width", 5)))
	return g.area_cells(shape, size, point, direction, int(area.get("width", 5)))


func creatures_in(cells: Array[Vector2i]) -> Array[Combatant]:
	var out: Array[Combatant] = []
	for o in enc().living():
		for cell in o.footprint():
			if cell in cells:
				out.append(o)
				break
	return out


# --- Casting --------------------------------------------------------------------------------------

## Casts `spell_id` at `slot` (0 or the spell's level = lowest). `targets` for targeted spells; `point` (a grid
## point) and `direction` for areas. opts: {word} for Command, {damage_type} for Chromatic Orb, {free: true} to use
## a free casting, {cell} for Spiritual Weapon's position.
func cast(c: Combatant, spell_id: String, slot: int, targets: Array = [], point: Vector2 = Vector2.INF,
		direction: Vector2 = Vector2.ZERO, opts: Dictionary = {}) -> CombatResult:
	var e := enc()
	var why := e._turn_check(c)
	if why != "":
		return CombatResult.fail(why)
	if not c.can_act():
		return CombatResult.fail("%s can't act" % c.name())
	var entry := _entry(c, spell_id)
	if entry.is_empty():
		return CombatResult.fail("%s doesn't know that spell" % c.name())
	if not bool(entry["legal"]):
		return CombatResult.fail(str(entry["reason"]))
	var s := _comp().spell_data(spell_id)
	var ch := c.creature as Character
	var level := int(s.get("level", 0))
	var use_free := bool(entry["free"]) and (bool(opts.get("free", false)) or slot <= level)
	if level == 0:
		slot = 0
	elif use_free:
		slot = level
	else:
		slot = maxi(slot, level)
		if ch.slots_left(slot) <= 0:
			return CombatResult.fail("No level %d slots left" % slot)
	# Targets, range and line of effect.
	var tgt: Array[Combatant] = []
	for t: Variant in targets:
		if t is Combatant:
			tgt.append(t as Combatant)
	var rng := range_ft(s)
	var has_area := s.has("area")
	var tkind := str((s.get("targets", {}) as Dictionary).get("kind", "creature"))
	if not has_area and tkind != "self" and spell_id != "spiritual_weapon":
		if tgt.is_empty():
			return CombatResult.fail("Choose a target")
		if tgt.size() > target_count(s, slot) and not spell_id in ["magic_missile", "scorching_ray"]:
			return CombatResult.fail("Too many targets (%d max)" % target_count(s, slot))
		for t in tgt:
			if e.distance(c, t) > rng:
				return CombatResult.fail("%s is out of range (%d ft)" % [t.name(), rng])
			if t != c and int(e.cover(c, t)["cover"]) == CombatGrid.Cover.TOTAL:
				return CombatResult.fail("No line of effect to %s" % t.name())
	if has_area and str((s.get("range", {}) as Dictionary).get("kind", "")) != "self":
		if point == Vector2.INF:
			return CombatResult.fail("Choose a point")
		var pc := Vector2i(floori(point.x), floori(point.y))
		if e.grid.distance_ft(c.cell, c.size_cells, pc, 1) > rng:
			return CombatResult.fail("That point is out of range (%d ft)" % rng)
	if str((s.get("targets", {}) as Dictionary).get("description", "")).contains("Humanoid"):
		for t in tgt:
			if str(t.creature.creature_type) != "humanoid":
				return CombatResult.fail("%s only affects Humanoids" % s["name"])
	if s.has("attack") or s.has("damage"):
		for t in tgt:
			if t != c:
				var sb := sanctuary_blocks(c, t)
				if sb != "":
					return CombatResult.fail(sb)
	# Pay for it.
	var unit := str(entry["casting"])
	if unit == "bonus_action":
		c.bonus_available = false
	else:
		e.spend_action(c)
		c.magic_action_used = true
	if level > 0:
		if use_free:
			ch.spend_resource("spell:%s" % spell_id)
		else:
			ch.expend_slot(slot)
			c.cast_slot_spell_this_turn = true
	if c.hidden and bool((s.get("components", {}) as Dictionary).get("v", false)):
		e.reveal(c, "cast a spell aloud")
	end_sanctuary(c, "cast a spell")
	var nums := numbers(c, entry)
	var conc: Concentration = null
	if bool((s.get("duration", {}) as Dictionary).get("concentration", false)):
		conc = c.creature.begin_concentration(spell_id, str(s["name"]))
	var slot_text := " (level %d slot)" % slot if level > 0 and slot > 0 else (" (free casting)" if use_free else "")
	e.log.add("spell", "%s casts %s%s" % [c.name(), s["name"], slot_text], c.id, [
		"Spell save DC %d · Spell attack %+d" % [(nums["dc"] as Breakdown).total(), (nums["attack"] as Breakdown).total()]])
	var cells: Array[Vector2i] = []
	if has_area:
		cells = area_for(c, s, point, direction)
	e.events.append({"type": "spell", "caster": c.id, "spell": spell_id, "cells": cells,
		"targets": tgt.map(func(t: Combatant) -> String: return t.id)})
	var ctx := {"c": c, "s": s, "slot": slot, "nums": nums, "conc": conc, "opts": opts, "point": point, "cells": cells}
	var r := CombatResult.new()
	match spell_id:
		"magic_missile":
			_magic_missile(ctx, tgt, r)
		"sleep":
			_sleep(ctx, cells, r)
		"command":
			for t in tgt:
				_command(ctx, t, str(opts.get("word", "grovel")), r)
		"sanctuary":
			_sanctuary(ctx, tgt[0], r)
			return r
		"spiritual_weapon":
			_spiritual_weapon_cast(ctx, tgt, opts, r)
		"spare_the_dying":
			_spare_the_dying(ctx, tgt[0], r)
		_:
			_generic(ctx, tgt, cells, r)
	if conc != null and conc.effect_count() == 0 and spell_id not in ["spiritual_weapon"]:
		conc.end("no one was affected")
	e._check_over()
	return r


func _generic(ctx: Dictionary, tgt: Array[Combatant], cells: Array[Vector2i], r: CombatResult) -> void:
	var c := ctx["c"] as Combatant
	var s := ctx["s"] as Dictionary
	var e := enc()
	var victims: Array[Combatant] = tgt
	if not cells.is_empty():
		victims = creatures_in(cells)
		if str((s.get("area", {}) as Dictionary).get("shape", "")) == "emanation" or (s.get("range", {}) as Dictionary).get("kind", "") == "self":
			victims = victims.filter(func(v: Combatant) -> bool: return v != c)
	if s.has("attack"):
		var count := target_count(ctx["s"] as Dictionary, int(ctx["slot"])) if (s.get("damage", []) as Array).size() > 0 and str(((s["damage"] as Array)[0] as Dictionary).get("per", "")) == "ray" else 1
		var shots: Array[Combatant] = []
		if count > 1:
			for i in count:
				shots.append(tgt[i % tgt.size()])
		else:
			shots = tgt
		for t in shots:
			if t.is_alive():
				_spell_attack(ctx, t, r)
		return
	if s.has("save"):
		_save_spell(ctx, victims, r)
		return
	if s.has("heal"):
		for t in victims:
			_heal(ctx, t, r)
		return
	for t in victims:
		_apply_effects(ctx, t, r)


func _damage_dice(ctx: Dictionary, target: Combatant = null) -> String:
	var s := ctx["s"] as Dictionary
	var c := ctx["c"] as Combatant
	var dice := Spellcasting.damage_dice(s, c.creature.character_level(), int(ctx["slot"]))
	if str(s["id"]) == "toll_the_dead" and target != null and target.creature.hp < target.creature.max_hp():
		dice = dice.replace("d8", "d12")
	return dice


func _damage_type(ctx: Dictionary) -> String:
	var s := ctx["s"] as Dictionary
	var d := (s.get("damage", []) as Array)[0] as Dictionary
	if d.has("type"):
		return str(d["type"])
	var choice := str((ctx["opts"] as Dictionary).get("damage_type", ""))
	var types := d.get("type_choice", []) as Array
	return choice if choice in types else str(types[0])


func _damage_bonus(ctx: Dictionary) -> Breakdown:
	var c := ctx["c"] as Combatant
	var s := ctx["s"] as Dictionary
	var ch := c.creature as Character
	var preview := ch.spell_preview(str(s["id"]), int(ctx["slot"]))
	return preview.get("damage_bonus", Breakdown.new("Damage bonus")) as Breakdown


func _spell_attack(ctx: Dictionary, t: Combatant, r: CombatResult) -> void:
	var c := ctx["c"] as Combatant
	var s := ctx["s"] as Dictionary
	var e := enc()
	var melee := str(s["attack"]) == "melee"
	var option := {"melee": melee, "profile": WeaponProfile.new()}
	(option["profile"] as WeaponProfile).normal_range = range_ft(s)
	var sit := e.attack_situation(c, t, option)
	if str(s["id"]) == "sacred_flame":
		sit["cover_bonus"] = 0
	e._consume_marks(c, t)
	var ac := t.creature.ac_value() + int(sit["cover_bonus"])
	var atk := ctx["nums"]["attack"] as Breakdown
	var keys: Array[String] = ["attack", "attack:melee" if melee else "attack:ranged"]
	var test := c.creature.roll_d20(e.dice, D20Test.Kind.ATTACK_ROLL, atk, ac, sit["advantage"] as Array[String],
		sit["disadvantage"] as Array[String], keys, "%s → %s (%s)" % [c.name(), t.name(), s["name"]])
	var details: Array[String] = [test.describe(), atk.describe()]
	if not test.success:
		r.lines.append(e.log.add("miss", "%s's %s misses %s (%d vs AC %d)" % [c.name(), s["name"], t.name(), test.total, ac], c.id, details))
		if int(s.get("level", 0)) == 0 and c.creature.has_flag("potent_cantrip") and s.has("damage"):
			var half := _roll_spell_damage(ctx, t, false)
			var amount := int(half["total"]) / 2
			e.deal_damage(c, t, [{"amount": amount, "type": _damage_type(ctx)}], false, str(s["name"]),
				["Potent Cantrip: half damage on a miss", str(half["text"])])
		return
	r.hit = true
	if s.has("damage"):
		var rolled := _roll_spell_damage(ctx, t, test.critical)
		details.append(str(rolled["text"]))
		e.deal_damage(c, t, [{"amount": int(rolled["total"]), "type": _damage_type(ctx)}], test.critical, str(s["name"]), details)
	_on_spell_hit(ctx, t, r)


## {total, text} for one target, with the spell's damage bonuses (Potent Spellcasting, Empowered Evocation).
func _roll_spell_damage(ctx: Dictionary, t: Combatant, critical: bool) -> Dictionary:
	var e := enc()
	var dice := _damage_dice(ctx, t)
	var rolled := e._roll_damage_dice(dice, critical, 0, "%s damage" % (ctx["s"] as Dictionary)["name"])
	var bonus := _damage_bonus(ctx)
	var total := int(rolled["total"]) + bonus.total()
	var text := "%s %s%s: %s" % [(ctx["s"] as Dictionary)["name"], dice, " ×2 (Critical Hit)" if critical else "", rolled["text"]]
	if not bonus.parts.is_empty():
		text += " · " + bonus.describe()
	return {"total": maxi(0, total), "text": text}


func _on_spell_hit(ctx: Dictionary, t: Combatant, r: CombatResult) -> void:
	var c := ctx["c"] as Combatant
	var e := enc()
	match str((ctx["s"] as Dictionary)["id"]):
		"guiding_bolt":
			e.add_mark({"kind": "advantage_against", "target": t.id, "source": "Guiding Bolt",
				"expires_owner": c.id, "expires_phase": "end", "skip": e.own_turn_skip(c), "consume": true})
		"shocking_grasp":
			e.add_mark({"kind": "no_reactions", "target": t.id, "source": "Shocking Grasp",
				"expires_owner": t.id, "expires_phase": "start"})
		"ray_of_frost":
			var fx := Effect.new("Ray of Frost", &"spell", "ray_of_frost").with_modifier("speed", {"value": -10})
			fx.ends = Effect.Ends.START_OF_TURN
			fx.turn_owner_id = c.id
			t.creature.add_effect(fx)
		"chill_touch":
			var fx2 := Effect.new("Chill Touch", &"spell", "chill_touch").with_modifier("flag", {"value": "cant_regain_hp"})
			fx2.ends = Effect.Ends.END_OF_TURN
			fx2.turn_owner_id = c.id
			fx2.skip_turn_ends = e.own_turn_skip(c)
			t.creature.add_effect(fx2)
		_:
			_apply_effects(ctx, t, r)


## Saving-throw spells: damage rolled once for all targets; each target saves (Dexterity saves add cover from
## the point of origin, except Sacred Flame); half damage on a success when the spell says so (or for Potent
## Cantrip); conditions and effects on a failure.
func _save_spell(ctx: Dictionary, victims: Array[Combatant], r: CombatResult) -> void:
	var c := ctx["c"] as Combatant
	var s := ctx["s"] as Dictionary
	var e := enc()
	var dc := (ctx["nums"]["dc"] as Breakdown).total()
	var ab := StringName(str(s["save"]))
	var has_damage := s.has("damage") and not (s["damage"] as Array).is_empty()
	var shared := {}
	if has_damage and str(s["id"]) != "toll_the_dead":
		shared = _roll_spell_damage(ctx, null, false)
	var half_on_success := str(s.get("save_success", "none")) == "half" or (int(s.get("level", 0)) == 0 and c.creature.has_flag("potent_cantrip"))
	for t in victims:
		if not t.is_alive():
			continue
		var extra_keys: Array[String] = []
		var bonus_text := ""
		var save_bd := t.creature.save_bonus(ab)
		if ab == &"dex" and str(s["id"]) != "sacred_flame":
			var cov := e.grid.cover_between(c.cell, c.size_cells, t.cell, t.size_cells, e.creature_cells([c, t]))
			var cb := CombatGrid.COVER_BONUS[int(cov["cover"])]
			if cb > 0:
				save_bd.add(CombatGrid.COVER_NAMES[int(cov["cover"])], cb)
				bonus_text = " (cover +%d)" % cb
		var keys := t.creature.save_keys(ab)
		keys.append_array(extra_keys)
		if str(s["id"]) == "sleep" and t.creature.is_condition_immune(&"exhaustion"):
			r.lines.append(e.log.add("info", "%s doesn't sleep: unaffected" % t.name(), t.id))
			continue
		var test := t.creature.roll_d20(e.dice, D20Test.Kind.SAVING_THROW, save_bd, dc, keys, [], [],
			"%s save vs %s (%s)" % [Creature.ABILITY_NAMES[ab], s["name"], t.name()])
		var details: Array[String] = [test.describe() + bonus_text]
		if has_damage:
			var rolled := shared if not shared.is_empty() else _roll_spell_damage(ctx, t, false)
			var amount := int(rolled["total"])
			if test.success:
				amount = amount / 2 if half_on_success else 0
			details.append(str(rolled["text"]))
			if amount > 0:
				e.deal_damage(c, t, [{"amount": amount, "type": _damage_type(ctx)}], false, str(s["name"]), details)
			else:
				r.lines.append(e.log.add("info", "%s saves against %s" % [t.name(), s["name"]], t.id, details))
		else:
			r.lines.append(e.log.add("info", "%s %s the %s save" % [t.name(), "succeeds on" if test.success else "fails", s["name"]], t.id, details))
		if not test.success and t.is_alive():
			if str(s["id"]) == "thunderwave":
				var moved := e.forced_move(t, c.cell, 10)
				if moved > 0:
					e.log.add("info", "%s is pushed %d ft" % [t.name(), moved * 5], t.id)
			_apply_effects(ctx, t, r)


func _heal(ctx: Dictionary, t: Combatant, r: CombatResult) -> void:
	var c := ctx["c"] as Combatant
	var s := ctx["s"] as Dictionary
	var e := enc()
	if t.creature.has_flag("cant_regain_hp"):
		r.lines.append(e.log.add("info", "%s can't regain Hit Points right now" % t.name(), t.id))
		return
	var ch := c.creature as Character
	var preview := ch.spell_preview(str(s["id"]), int(ctx["slot"]))
	var dice := str(preview.get("heal_dice", ""))
	var bonus := preview.get("heal_bonus", Breakdown.new("")) as Breakdown
	var rolled := e._roll_damage_dice(dice, false, 0, "%s healing" % s["name"]) if dice != "" else {"total": 0, "text": ""}
	var amount := int(rolled["total"]) + bonus.total() + int((s.get("heal", {}) as Dictionary).get("flat", 0))
	var healed := t.creature.heal(amount, str(s["name"]))
	r.lines.append(e.log.add("heal", "%s heals %s for %d" % [c.name(), t.name(), healed], c.id,
		["%s %s: %s" % [s["name"], dice, rolled["text"]], bonus.describe()]))
	e.events.append({"type": "heal", "id": t.id, "amount": healed})


## Buffs and debuffs from the spell's effects data, as Effects tied to Concentration when the spell needs it.
func _apply_effects(ctx: Dictionary, t: Combatant, r: CombatResult) -> void:
	var c := ctx["c"] as Combatant
	var s := ctx["s"] as Dictionary
	var conc := ctx["conc"] as Concentration
	var slot := int(ctx["slot"])
	var fx_list := s.get("effects", []) as Array
	if fx_list.is_empty():
		return
	var e := Effect.new(str(s["name"]), &"spell", str(s["id"]))
	e.caster_id = c.id
	e.lasting(s.get("duration", {}) as Dictionary)
	e.turn_owner_id = c.id
	var ctx2 := c.creature.formula_context(slot)
	for fx: Variant in fx_list:
		var f := fx as Dictionary
		var params := f.get("params", {}) as Dictionary
		match str(f.get("effect", "")):
			"modifiers":
				for md: Variant in params.get("modifiers", []):
					var d := (md as Dictionary).duplicate(true)
					var v: Variant = d.get("value", 0)
					if v is String and str(v).contains("slot_level"):
						d["value"] = Formula.evaluate(v, ctx2)
					var m := Modifier.make(d, str(s["name"]), &"spell", str(s["id"]))
					e.modifiers.append(m)
			"condition":
				if str(s["id"]) in ["sleep"]:
					continue
				e.conditions.append(StringName(str(params.get("condition", ""))))
				if str(params.get("repeat_save", "")) == "end_of_turn":
					e.repeat_save = {"ability": str(s.get("save", "wis")), "dc": (ctx["nums"]["dc"] as Breakdown).total()}
	if e.modifiers.is_empty() and e.conditions.is_empty():
		return
	if str(s["id"]) == "aid":
		var gain := 5 * (slot - 1) if slot >= 2 else 5
		if conc == null:
			t.creature.add_effect(e)
		else:
			conc.attach(t.creature, e)
		t.creature.heal(gain, "Aid")
		r.lines.append(enc().log.add("info", "%s's Hit Point maximum rises by %d (Aid)" % [t.name(), gain], t.id))
		return
	var ok := conc.attach(t.creature, e) if conc != null else t.creature.add_effect(e)
	if ok:
		if e.conditions.is_empty():
			r.lines.append(enc().log.add("condition", "%s gains %s" % [t.name(), s["name"]], t.id))
		else:
			var what := ", ".join(e.conditions.map(func(x: StringName) -> String: return str(x).capitalize()))
			r.lines.append(enc().log.add("condition", "%s is %s (%s)" % [t.name(), what, s["name"]], t.id))
		enc().events.append({"type": "condition", "id": t.id})


# --- Special spells -------------------------------------------------------------------------------

## Magic Missile: darts that always hit, 1d4 + 1 Force each, split as the caster chooses.
func _magic_missile(ctx: Dictionary, tgt: Array[Combatant], r: CombatResult) -> void:
	var c := ctx["c"] as Combatant
	var e := enc()
	var darts := target_count(ctx["s"] as Dictionary, int(ctx["slot"]))
	for i in darts:
		var t := tgt[i % tgt.size()]
		if not t.is_alive():
			continue
		if t.creature.effects.any(func(x: Effect) -> bool: return x.source_id == "shield"):
			r.lines.append(e.log.add("miss", "Shield blocks a dart", t.id))
			continue
		var rolled := e._roll_damage_dice("1d4+1", false, 0, "Magic Missile dart")
		e.deal_damage(c, t, [{"amount": int(rolled["total"]), "type": "force"}], false, "Magic Missile",
			["Dart %d: %s" % [i + 1, rolled["text"]]])


## Sleep (2024): Wisdom save or Incapacitated until the end of its next turn, then repeat the save; a second
## failure means Unconscious for the duration. Ends on damage. Creatures immune to Exhaustion are unaffected.
func _sleep(ctx: Dictionary, cells: Array[Vector2i], r: CombatResult) -> void:
	var c := ctx["c"] as Combatant
	var e := enc()
	var dc := (ctx["nums"]["dc"] as Breakdown).total()
	var conc := ctx["conc"] as Concentration
	for t in creatures_in(cells):
		if t == c or c.allied_with(t):
			continue
		if t.creature.is_condition_immune(&"exhaustion") or t.creature.has_flag("trance"):
			r.lines.append(e.log.add("info", "%s doesn't sleep: unaffected" % t.name(), t.id))
			continue
		var test := t.creature.roll_save(e.dice, &"wis", dc, [], [], "Wisdom save vs Sleep (%s)" % t.name())
		if test.success:
			r.lines.append(e.log.add("info", "%s shrugs off Sleep" % t.name(), t.id, [test.describe()]))
			continue
		var fx := Effect.new("Drowsy (Sleep)", &"spell", "sleep").with_condition(&"incapacitated")
		fx.caster_id = c.id
		fx.ends_on_damage = true
		fx.repeat_save = {"ability": "wis", "dc": dc, "then": "sleep_unconscious"}
		fx.stack_key = "sleep:%s" % t.id
		conc.attach(t.creature, fx)
		r.lines.append(e.log.add("condition", "%s is Incapacitated by Sleep" % t.name(), t.id, [test.describe()]))


## Command (2024): one word; on a failed Wisdom save the target obeys on its next turn. Grovel: falls Prone and
## ends its turn. Halt: doesn't move or act. Flee: spends its turn moving away. (Approach and Drop: later.)
func _command(ctx: Dictionary, t: Combatant, word: String, r: CombatResult) -> void:
	var c := ctx["c"] as Combatant
	var e := enc()
	var dc := (ctx["nums"]["dc"] as Breakdown).total()
	var test := t.creature.roll_save(e.dice, &"wis", dc, [], [], "Wisdom save vs Command (%s)" % t.name())
	if test.success:
		r.lines.append(e.log.add("info", "%s ignores the command" % t.name(), t.id, [test.describe()]))
		return
	var fx := Effect.new("Commanded: %s" % word.capitalize(), &"spell", "command").with_modifier("flag", {"value": "command_" + word})
	fx.caster_id = c.id
	fx.ends = Effect.Ends.END_OF_TURN
	fx.turn_owner_id = t.id
	t.creature.add_effect(fx)
	r.lines.append(e.log.add("condition", "%s obeys: %s" % [t.name(), word.capitalize()], t.id, [test.describe()]))


func _sanctuary(ctx: Dictionary, t: Combatant, r: CombatResult) -> void:
	var c := ctx["c"] as Combatant
	var fx := Effect.new("Sanctuary", &"spell", "sanctuary").lasting({"kind": "minutes", "amount": 1})
	fx.caster_id = c.id
	fx.turn_owner_id = c.id
	fx.repeat_save = {"ability": "wis", "dc": (ctx["nums"]["dc"] as Breakdown).total()}
	t.creature.add_effect(fx)
	r.lines.append(enc().log.add("condition", "%s is warded by Sanctuary" % t.name(), t.id))


## Sanctuary ends when the warded creature attacks, casts a spell or deals damage.
func end_sanctuary(t: Combatant, why: String) -> void:
	for fx: Effect in t.creature.effects.duplicate():
		if fx.source_id == "sanctuary":
			t.creature.remove_effect(fx)
			enc().log.add("info", "%s's Sanctuary ends (%s)" % [t.name(), why], t.id)


## Sanctuary check when `attacker` targets `target` with an attack roll or a damaging spell: "" if it may go ahead,
## otherwise why not. A failed save holds for the rest of the attacker's turn (it must pick someone else).
func sanctuary_blocks(attacker: Combatant, target: Combatant) -> String:
	var e := enc()
	for m in e.marks:
		if str(m["kind"]) == "sanctuary_failed" and str(m["attacker"]) == attacker.id and str(m["target"]) == target.id:
			return "Sanctuary: %s can't bring itself to target %s this turn" % [attacker.name(), target.name()]
	for fx: Effect in target.creature.effects:
		if fx.source_id == "sanctuary" and attacker.hostile_to(target):
			var dc := int(fx.repeat_save.get("dc", 13))
			var test := attacker.creature.roll_save(e.dice, &"wis", dc, [], [], "Wisdom save vs Sanctuary (%s)" % attacker.name())
			if test.success:
				e.log.add("info", "%s pushes past %s's Sanctuary" % [attacker.name(), target.name()], attacker.id, [test.describe()])
				return ""
			e.add_mark({"kind": "sanctuary_failed", "attacker": attacker.id, "target": target.id,
				"source": "Sanctuary", "expires_owner": e.current().id if e.current() != null else attacker.id, "expires_phase": "end"})
			e.log.add("info", "%s can't bring itself to attack %s (Sanctuary)" % [attacker.name(), target.name()], attacker.id, [test.describe()])
			return "Sanctuary: choose another target"
	return ""


func _spare_the_dying(ctx: Dictionary, t: Combatant, r: CombatResult) -> void:
	if t.creature.hp > 0 or t.creature.dead:
		r.lines.append(enc().log.add("info", "%s isn't dying" % t.name(), t.id))
		return
	t.creature.stabilize()
	r.lines.append(enc().log.add("heal", "%s is Stable" % t.name(), t.id))


## Spiritual Weapon (2024): a spectral weapon within 60 ft; when cast, a melee spell attack against a creature
## within 5 ft of it (1d8 + spellcasting modifier Force); later, a Bonus Action moves it 20 ft and attacks again.
func _spiritual_weapon_cast(ctx: Dictionary, tgt: Array[Combatant], opts: Dictionary, r: CombatResult) -> void:
	var c := ctx["c"] as Combatant
	var cell: Vector2i = opts.get("cell", _beside(c, tgt[0]) if not tgt.is_empty() else c.cell)
	spirit_weapons[c.id] = {"cell": cell, "slot": int(ctx["slot"])}
	var conc := ctx["conc"] as Concentration
	var marker := Effect.new("Spiritual Weapon", &"spell", "spiritual_weapon")
	marker.caster_id = c.id
	marker.modifiers.append(Modifier.of("flag", {"value": "spiritual_weapon"}, "Spiritual Weapon", &"spell"))
	conc.attach(c.creature, marker)
	enc().events.append({"type": "summon", "caster": c.id, "cell": cell})
	if not tgt.is_empty() and enc().grid.distance_ft(cell, 1, tgt[0].cell, tgt[0].size_cells) <= 5:
		_spell_attack(ctx, tgt[0], r)


## A free square next to `t`, the one closest to `c` (where a summoned weapon appears).
func _beside(c: Combatant, t: Combatant) -> Vector2i:
	var best := t.cell
	var best_d := 1 << 30
	for dx in range(-1, t.size_cells + 1):
		for dy in range(-1, t.size_cells + 1):
			var cell := t.cell + Vector2i(dx, dy)
			if cell in t.footprint() or not enc().grid.in_bounds(cell) or enc().grid.is_solid(cell):
				continue
			if enc().occupant_at(cell) != null:
				continue
			var d := enc().grid.distance_ft(c.cell, c.size_cells, cell, 1)
			if d < best_d:
				best_d = d
				best = cell
	return best


func has_spiritual_weapon(c: Combatant) -> bool:
	return spirit_weapons.has(c.id) and c.creature.has_flag("spiritual_weapon")


## The Bonus Action follow-up: move the weapon up to 20 ft to `cell`, then attack a creature within 5 ft of it.
func spiritual_weapon_attack(c: Combatant, target: Combatant, cell: Vector2i) -> CombatResult:
	var e := enc()
	var why := e._bonus_check(c)
	if why != "":
		return CombatResult.fail(why)
	if not has_spiritual_weapon(c):
		return CombatResult.fail("No Spiritual Weapon")
	var w := spirit_weapons[c.id] as Dictionary
	if e.grid.distance_ft(w["cell"] as Vector2i, 1, cell, 1) > 20:
		return CombatResult.fail("The weapon moves at most 20 ft")
	if e.grid.distance_ft(cell, 1, target.cell, target.size_cells) > 5:
		return CombatResult.fail("Target must be within 5 ft of the weapon")
	c.bonus_available = false
	w["cell"] = cell
	e.events.append({"type": "summon", "caster": c.id, "cell": cell})
	var s := _comp().spell_data("spiritual_weapon")
	var entry := _entry_any(c, "spiritual_weapon")
	var ctx := {"c": c, "s": s, "slot": int(w["slot"]), "nums": numbers(c, entry), "conc": null, "opts": {}}
	var r := CombatResult.new()
	_spell_attack(ctx, target, r)
	return r


func _entry_any(c: Combatant, spell_id: String) -> Dictionary:
	for k in (c.creature as Character).known_spells():
		if str(k["id"]) == spell_id:
			return k
	return {}


# --- Turn hooks -----------------------------------------------------------------------------------

## Effects with a repeated save at the end of the creature's turn (Hold Person; Sleep's drowsiness).
func end_of_turn_saves(c: Combatant) -> void:
	var e := enc()
	for fx: Effect in c.creature.effects.duplicate():
		if fx.repeat_save.is_empty() or fx.source_id == "sanctuary":
			continue
		var ab := StringName(str(fx.repeat_save.get("ability", "wis")))
		var dc := int(fx.repeat_save.get("dc", 10))
		var test := c.creature.roll_save(e.dice, ab, dc, [], [], "%s save to end %s (%s)" % [Creature.ABILITY_NAMES[ab], fx.name, c.name()])
		var then_kind := str(fx.repeat_save.get("then", ""))
		if test.success:
			c.creature.remove_effect(fx)
			e.log.add("info", "%s shakes off %s" % [c.name(), fx.name], c.id, [test.describe()])
		elif then_kind == "sleep_unconscious":
			c.creature.remove_effect(fx)
			var deep := Effect.new("Sleep", &"spell", "sleep").with_condition(&"unconscious")
			deep.caster_id = fx.caster_id
			deep.ends_on_damage = true
			deep.stack_key = fx.stack_key
			if fx.concentration != null:
				fx.concentration.attach(c.creature, deep)
			else:
				c.creature.add_effect(deep)
			e.log.add("condition", "%s falls Unconscious (Sleep)" % c.name(), c.id, [test.describe()])
		else:
			e.log.add("info", "%s is still affected by %s" % [c.name(), fx.name], c.id, [test.describe()])


## Areas creatures walk into (Spirit Guardians, Web): later phases. Hook kept so movement calls it.
func on_enter_cell(_c: Combatant) -> void:
	pass
