class_name SpellCaster
extends RefCounted
## Spells in combat (plan §5.3, docs/contracts/spells.md), driven by each spell's data recipe: casting time and the
## action economy, spell slots (one slot-spell per turn, 2024), free uses from species and feats, Concentration,
## range and line of effect, areas on the grid, cast-time choices (a damage type, a condition, a form), spell
## attacks (with what happens on a hit or a miss), saving throws (damage rolled once for every target, half on a
## success, cover for Dexterity saves, pushes resolved farthest first), healing, Temporary Hit Points, and effects
## with their own durations ("until the end of your next turn"), triggers that end them (attacking, casting,
## taking damage), repeated saves and escape checks. Lingering areas and spell objects live in SpellZones;
## actions a spell keeps granting (Witch Bolt, Spiritual Weapon, Dragon's Breath...) are "sustained" actions here.
## A few spells keep handlers of their own (Magic Missile, Sleep, Command, Sanctuary, Misty Step, Mirror Image...).

## Spells whose combat rules are in code here, beyond the data recipe.
const SPECIAL := ["heat_metal", "eldritch_blast", "sorcerous_burst", "magic_missile", "shield", "sleep", "command", "sanctuary", "spiritual_weapon", "toll_the_dead",
	"spare_the_dying", "chromatic_orb", "sacred_flame", "mage_armor", "aid", "misty_step", "mirror_image", "blink",
	"haste", "dispel_magic", "revivify", "arcane_vigor", "warding_bond", "counterspell", "hellish_rebuke",
	"true_strike", "shillelagh", "enlarge_reduce", "vampiric_touch", "lesser_restoration", "protection_from_poison",
	"expeditious_retreat", "summon_fey", "summon_undead", "goodberry", "jump", "alter_self", "beacon_of_hope",
	"resistance", "blade_ward", "protection_from_evil_and_good", "crown_of_madness", "bestow_curse", "fear",
	"calm_emotions", "fly", "levitate", "gaseous_form", "spider_climb", "animate_dead", "find_familiar", "etherealness", "plane_shift", "remove_curse"]
## Command's words (2024): all five.
const COMMAND_WORDS := ["approach", "drop", "flee", "grovel", "halt"]
## Effect kinds the engine resolves in a fight (anything else is narrative or exploration).
const COMBAT_EFFECTS := ["modifiers", "condition", "temp_hp", "heal", "damage", "push", "pull", "end_condition",
	"summon", "light", "custom"]

var _enc: WeakRef
var zones: SpellZones
var specials: SpellSpecials
## Actions a spell keeps granting while it lasts: {id, spell_id, label, sub, owner_id, caster_id, cost, do, slot,
## target_id, conc: WeakRef, uses_left, opts}. `do`: attack, damage, area, move_object, dash, heal_one, maintain.
var sustained: Array[Dictionary] = []
## Creature ids summoned by a caster: caster id -> [ids].
var summoned: Dictionary = {}


## Spells that call up a creature on a chosen square (combat/summon_blocks.gd).
const SUMMON_SPELLS := ["summon_fey", "summon_undead", "find_steed", "summon_beast", "giant_insect", "summon_aberration",
	"summon_construct", "summon_elemental"]


func _init(encounter: Encounter) -> void:
	_enc = weakref(encounter)
	zones = SpellZones.new(encounter)
	specials = SpellSpecials.new(encounter)


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
		# Mage Hand Legerdemain (Arcane Trickster 3): Mage Hand as a Bonus Action.
		if id == "mage_hand" and CombatFeatures.has_feature(c, "mage_hand_legerdemain"):
			unit = "bonus_action"
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
		return "No effect in a fight (%s)" % _out_of_combat_word(s)
	var ch := c.creature as Character
	var unit := str(entry["casting"])
	if unit == "reaction":
		return "Cast as a Reaction when it triggers"
	if unit in ["minute", "hour"]:
		return "Takes too long to cast in combat (cast it before the fight)"
	var why := economy_block(c, unit)
	if why != "":
		return why
	var comp := s.get("components", {}) as Dictionary
	if bool(comp.get("v", false)) and not (str(s.get("school", "")) == "illusion" and CombatFeatures.has_feature(c, "improved_illusions")):
		if c.creature.has_flag("speechless"):
			return "Can't speak"
		for cell in c.footprint():
			if zones.silenced(cell):
				return "Silence: no Verbal spells here"
	if c.creature.has_flag("cant_cast"):
		return "Can't cast spells in this form"
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
	if str(s["id"]) == "spiritual_weapon" and zones.object_of(c.id, "spiritual_weapon") != null:
		return ""
	return ""


## "" if the action economy lets `c` spend this casting time now.
func economy_block(c: Combatant, unit: String) -> String:
	if unit == "action":
		if not c.action_available:
			return "Action already used"
		if c.magic_action_used:
			return "Only one Magic action this turn (Action Surge's action can't be Magic)"
		if c.creature.has_flag("slowed") and not c.bonus_available:
			return "Slowed: an action or a Bonus Action, not both"
	if unit == "bonus_action":
		if not c.bonus_available:
			return "Bonus Action already used"
		if c.creature.has_flag("slowed") and not c.action_available and not c.surged:
			return "Slowed: an action or a Bonus Action, not both"
	return ""


static func _out_of_combat_word(s: Dictionary) -> String:
	var tags := s.get("tags", []) as Array
	for t: String in ["detection", "communication", "social", "utility"]:
		if t in tags:
			return t
	return "exploration"


## True if the spell does something the combat engine can resolve.
func has_combat_rules(s: Dictionary) -> bool:
	if str(s.get("id", "")) in SPECIAL or str(s.get("id", "")) in SUMMON_SPELLS or str(s.get("id", "")) in SpellSpecials.HANDLED:
		return true
	for k: String in ["attack", "heal", "damage", "temp_hp", "zone", "object", "sustain"]:
		if s.has(k):
			return true
	for fx: Variant in s.get("effects", []):
		if str((fx as Dictionary).get("effect", "")) in COMBAT_EFFECTS:
			return true
	return false


func can_cast_reaction(c: Combatant, spell_id: String) -> bool:
	if not c.creature is Character or not can_react(c):
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
func cast_shield(c: Combatant) -> void:
	var ch := c.creature as Character
	var l := _lowest_slot(ch, 1)
	if l > 0:
		ch.expend_slot(l)
	c.reaction_available = false
	var e := Effect.new("Shield", &"spell", "shield").with_modifier("ac", {"value": 5})
	e.ends = Effect.Ends.START_OF_TURN
	e.turn_owner_id = c.id
	e.spell_level = maxi(1, l)
	c.creature.add_effect(e)
	enc().log.add("spell", "%s casts Shield (+5 AC until its next turn)" % c.name(), c.id)


## A reaction spell answering `trigger` (Hellish Rebuke against whoever hurt the caster; Counterspell against a
## caster): the Reaction and the lowest slot are spent, then the spell resolves against the trigger.
func cast_reaction_spell(c: Combatant, spell_id: String, trigger: Combatant) -> CombatResult:
	var e := enc()
	var ch := c.creature as Character
	var s := _comp().spell_data(spell_id)
	var slot := _lowest_slot(ch, int(s.get("level", 1)))
	if slot == 0 or not can_react(c):
		return CombatResult.new()
	ch.expend_slot(slot)
	c.reaction_available = false
	var entry := _entry_any(c, spell_id)
	var nums := numbers(c, entry)
	e.log.add("spell", "%s answers with %s (level %d slot)" % [c.name(), s["name"], slot], c.id)
	e.events.append({"type": "spell", "caster": c.id, "spell": spell_id, "cells": [], "targets": [trigger.id]})
	trigger_ends(c, "cast_spell")
	var ctx := {"c": c, "s": s, "slot": slot, "nums": nums, "conc": null, "opts": {}, "choice": "", "point": Vector2.INF}
	var r := CombatResult.new()
	var tgt: Array[Combatant] = [trigger]
	_generic(ctx, tgt, [], r)
	e._check_over()
	return r


## Releases a readied spell at `target` (the creature that triggered it) with the Reaction: its slot was spent when
## it was readied. Areas are centred on (or aimed at) the target.
func release_readied(c: Combatant, held: Dictionary, target: Combatant) -> CombatResult:
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
	var entry := _entry_any(c, spell_id)
	var point := e.center_of(target)
	var dir := (point - e.center_of(c)).normalized()
	var cells: Array[Vector2i] = []
	if s.has("area"):
		cells = area_for(c, s, point, dir, int(held["slot"]))
	e.log.add("reaction", "%s releases the readied %s at %s" % [c.name(), s["name"], target.name()], c.id)
	e.events.append({"type": "spell", "caster": c.id, "spell": spell_id, "cells": cells, "targets": [target.id]})
	var ctx := {"c": c, "s": s, "slot": int(held["slot"]), "nums": numbers(c, entry), "conc": new_conc, "opts": {},
		"point": point, "cells": cells, "choice": choice_of(s, {}), "direction": dir, "cell": target.cell}
	var r := CombatResult.new()
	var tgt: Array[Combatant] = [target]
	_resolve(ctx, tgt, cells, r)
	_finish_concentration(ctx)
	zones.prune()
	e._check_over()
	return r


## A spell cast before the fight (Mage Armor, Find Familiar, Animate Dead): its lowest slot is spent and its effect
## applied, with Concentration if it needs it.
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
		slot = _lowest_slot(ch, level)
		if slot == 0:
			return false
		ch.expend_slot(slot)
	var conc: Concentration = null
	if bool((s.get("duration", {}) as Dictionary).get("concentration", false)):
		conc = c.creature.begin_concentration(spell_id, str(s["name"]))
	enc().log.add("spell", "%s cast %s before the fight%s" % [c.name(), s["name"], " (level %d slot)" % slot if slot > 0 else ""], c.id)
	var ctx := {"c": c, "s": s, "slot": slot, "nums": numbers(c, entry), "conc": conc, "opts": {}, "precast": true}
	var r := CombatResult.new()
	match spell_id:
		"find_familiar", "animate_dead":
			_summon(ctx, c.cell, r)
		_:
			apply_effect_entries(ctx, c, s.get("effects", []) as Array, "cast", r)
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
		return {"dc": ch.spell_save_dc(cid), "attack": ch.spell_attack_bonus(cid), "mod": ch.ability_mod(ab), "ability": ab}
	var ab2 := StringName(str(entry.get("ability", "int")))
	if not Creature.ABILITY_NAMES.has(ab2):
		ab2 = &"int"
	var mod := ch.ability_mod(ab2)
	var dc := Breakdown.new("Spell save DC")
	dc.add("Base", 8).add("%s modifier" % Creature.ABILITY_SHORT[ab2], mod).add("Proficiency", ch.proficiency_bonus())
	var atk := Breakdown.new("Spell attack")
	atk.add("%s modifier" % Creature.ABILITY_SHORT[ab2], mod).add("Proficiency", ch.proficiency_bonus())
	return {"dc": dc, "attack": atk, "mod": mod, "ability": ab2}


## Range in feet. A Self-range spell that still targets a creature (Vampiric Touch) reaches as far as a melee
## attack; Touch is 5 ft; cantrips like Spare the Dying grow with level (`cantrip_scaling.range`).
func range_ft(s: Dictionary, caster: Combatant = null) -> int:
	var r := s.get("range", {}) as Dictionary
	match str(r.get("kind", "self")):
		"feet":
			var ft := int(r.get("feet", 0))
			# Spell Sniper: +60 ft for attack-roll spells of 10 ft or more; Improved Illusions: +60 ft for Illusions.
			if caster != null and ft >= 10 and ((s.has("attack") and enc().features.has_feat(caster, "spell_sniper")) \
					or (str(s.get("school", "")) == "illusion" and CombatFeatures.has_feature(caster, "improved_illusions"))):
				ft += 60
			var sc := s.get("cantrip_scaling", {}) as Dictionary
			if sc.has("range_doubles") and caster != null:
				ft *= int(pow(2, Spellcasting.cantrip_tier(caster.creature.character_level())))
			return ft
		"touch":
			return 5
		"self":
			if s.has("attack") and not s.has("area"):
				return 5
			if s.has("object") or s.has("sustain"):
				return int((s.get("object", {}) as Dictionary).get("range", 0))
			return 0
	return 9999


func target_count(s: Dictionary, slot: int) -> int:
	var t := s.get("targets", {}) as Dictionary
	if str(t.get("count", "")) == "any":
		return 99
	var base := int(t.get("count", 1))
	var up := s.get("upcast", {}) as Dictionary
	var extra := maxi(0, slot - int(s.get("level", 0)))
	return base + int(up.get("targets", 0)) * extra + int(up.get("projectiles", 0)) * extra


## The area a spell would cover: cells around the point of origin.
func area_for(c: Combatant, s: Dictionary, point: Vector2, direction: Vector2, slot: int = 0) -> Array[Vector2i]:
	var area := s.get("area", {}) as Dictionary
	if area.is_empty():
		return []
	var shape := str(area["shape"])
	var size := int(area["size"]) + int((s.get("upcast", {}) as Dictionary).get("area", 0)) * maxi(0, slot - int(s.get("level", 0)))
	var g := enc().grid
	var center := enc().center_of(c)
	var self_origin := str((s.get("range", {}) as Dictionary).get("kind", "")) == "self"
	if shape == "emanation" and self_origin:
		return g.area_cells("emanation", size, center, Vector2.RIGHT, 5, c.cell, c.size_cells)
	if shape == "emanation":
		# An Emanation from something placed at the point (Conjure Animals' Large pack, Guardian of Faith): its own
		# squares count too.
		var osz := int(area.get("origin_size", 1))
		var oc := Vector2i(floori(point.x - osz / 2.0 + 0.5), floori(point.y - osz / 2.0 + 0.5)) if osz > 1 else Vector2i(floori(point.x), floori(point.y))
		var em := g.area_cells("emanation", size, Vector2(oc) + Vector2(osz / 2.0, osz / 2.0), Vector2.RIGHT, 5, oc, osz)
		for f in CombatGrid.footprint(oc, osz):
			if g.in_bounds(f) and not f in em:
				em.append(f)
		return em
	if self_origin:
		var dir := direction.normalized() if direction.length() > 0.01 else Vector2(c.facing)
		if dir.length() < 0.01:
			dir = Vector2.RIGHT
		var origin := center + dir * (c.size_cells / 2.0)
		return g.area_cells(shape, size, origin, dir, int(area.get("width", 5)))
	if shape == "cylinder":
		shape = "sphere"
	return g.area_cells(shape, size, point, direction, int(area.get("width", 5)))


func creatures_in(cells: Array[Vector2i]) -> Array[Combatant]:
	var out: Array[Combatant] = []
	for o in enc().living():
		for cell in o.footprint():
			if cell in cells:
				out.append(o)
				break
	return out


## Who an area spell affects among the creatures in it: everyone (default for a point), everyone but the caster
## (default for areas from yourself), or "creatures of your choice" (`area_targets`: enemies / allies).
func _area_victims(c: Combatant, s: Dictionary, cells: Array[Vector2i]) -> Array[Combatant]:
	var self_area := str((s.get("range", {}) as Dictionary).get("kind", "")) == "self"
	var mode := str(s.get("area_targets", "others" if self_area else "all"))
	var out: Array[Combatant] = []
	for v in creatures_in(cells):
		match mode:
			"others":
				if v == c:
					continue
			"enemies":
				if not c.hostile_to(v):
					continue
			"allies":
				if v != c and not c.allied_with(v):
					continue
		out.append(v)
	var cap := int(s.get("area_max_targets", 0))
	if cap > 0 and out.size() > cap:
		out.sort_custom(func(a: Combatant, b: Combatant) -> bool: return enc().distance(c, a) < enc().distance(c, b))
		out.resize(cap)
	return out


## A cast-time choice ("choice": {kind, from}) resolved from opts: the picked value, or the first option.
static func choice_of(s: Dictionary, opts: Dictionary) -> String:
	var ch := s.get("choice", {}) as Dictionary
	if ch.is_empty():
		return ""
	var from := ch.get("from", []) as Array
	var pick := str(opts.get("choice", opts.get("damage_type", opts.get("word", ""))))
	if pick in from.map(func(x: Variant) -> String: return str(x)):
		return pick
	return str(from[0]) if not from.is_empty() else ""


# --- Casting --------------------------------------------------------------------------------------

## Casts `spell_id` at `slot` (0 or the spell's level = lowest). `targets` for targeted spells; `point` (a grid
## point) and `direction` for areas and placed objects. opts: {choice} for a cast-time choice (Chromatic Orb's
## damage type, Command's word, Protection from Energy's type, Enlarge or Reduce...), {free: true} to use a free
## casting, {cell} for where an object or a teleport goes.
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
	var war_magic := bool(opts.get("war_magic", false))
	var meta := (opts.get("metamagic", []) as Array).map(func(x: Variant) -> String: return str(x))
	var meta_why := _metamagic_check(c, _comp().spell_data(spell_id), meta)
	if meta_why != "":
		return CombatResult.fail(meta_why)
	# Quickened Spell turns a one-action spell into a Bonus Action; Subtle Spell needs no voice.
	if "quickened" in meta and str(entry["casting"]) == "action":
		entry["casting"] = "bonus_action"
		var qwhy := economy_block(c, "bonus_action")
		entry["legal"] = qwhy == "" and str(entry["reason"]) in ["", "Action already used", "Only one Magic action this turn (Action Surge's action can't be Magic)"]
		entry["reason"] = qwhy
	if "subtle" in meta and (str(entry["reason"]) == "Can't speak" or str(entry["reason"]).begins_with("Silence")):
		entry["legal"] = true
		entry["reason"] = ""
	if war_magic and str(entry["reason"]) in ["Action already used", ""] and e.features_attack_why(c) == "" and int(_comp().spell_data(spell_id).get("level", 0)) == 0:
		entry["legal"] = true
	if not bool(entry["legal"]):
		return CombatResult.fail(str(entry["reason"]))
	var s := _comp().spell_data(spell_id)
	var ch := c.creature as Character
	var level := int(s.get("level", 0))
	var use_free := bool(entry["free"]) and (bool(opts.get("free", false)) or slot <= level)
	# Divine Intervention: the next Cleric spell of level 5 or lower needs no slot.
	if level > 0 and c.has_meta("free_cleric_spell") and "cleric" in (s.get("classes", []) as Array) and level <= int(c.get_meta("free_cleric_spell")):
		c.remove_meta("free_cleric_spell")
		use_free = true
		ch.set_resource("spell:%s" % spell_id, str(s["name"]), 1, "long", "Divine Intervention")
	if level == 0:
		slot = 0
	elif use_free:
		slot = level
	else:
		slot = maxi(slot, level)
		if ch.slots_left(slot) <= 0:
			return CombatResult.fail("No level %d slots left" % slot)
	var copts := opts.duplicate()
	if "distant" in meta:
		copts["range_mult"] = true
	var check := _check_targets(c, s, slot + (1 if "twinned" in meta else 0), targets, point, copts)
	if str(check["why"]) != "":
		return CombatResult.fail(str(check["why"]))
	var tgt := check["targets"] as Array[Combatant]
	var cell: Vector2i = check["cell"]
	if not meta.is_empty():
		_pay_metamagic(c, meta)
	# Pay for it.
	var unit := str(entry["casting"])
	if war_magic:
		e.use_one_attack(c)
	elif unit == "bonus_action":
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
	trigger_ends(c, "cast_spell")
	for tt in tgt:
		if c.hostile_to(tt) and spell_id != "compelled_duel":
			specials.duel_check_attack(c, tt)
	var nums := numbers(c, entry)
	var conc: Concentration = null
	if bool((s.get("duration", {}) as Dictionary).get("concentration", false)):
		conc = c.creature.begin_concentration(spell_id, str(s["name"]))
		zones.prune()
		_prune_sustained()
	var slot_text := " (level %d slot)" % slot if level > 0 and slot > 0 else (" (free casting)" if use_free else "")
	var choice := choice_of(s, opts)
	e.log.add("spell", "%s casts %s%s%s" % [c.name(), s["name"], slot_text, (": " + choice.capitalize().replace("_", " ")) if choice != "" else ""], c.id, [
		"Spell save DC %d · Spell attack %+d" % [(nums["dc"] as Breakdown).total(), (nums["attack"] as Breakdown).total()]])
	var cells: Array[Vector2i] = []
	if s.has("area"):
		cells = area_for(c, s, point, direction, slot)
	e.events.append({"type": "spell", "caster": c.id, "spell": spell_id, "cells": cells,
		"targets": tgt.map(func(t: Combatant) -> String: return t.id)})
	var ctx := {"c": c, "s": s, "slot": slot, "nums": nums, "conc": conc, "opts": opts, "point": point,
		"cells": cells, "choice": choice, "direction": direction, "cell": cell, "metamagic": meta}
	if "transmuted" in meta and str(opts.get("transmute_to", "")) != "":
		ctx["transmute_to"] = str(opts["transmute_to"])
	if "heightened" in meta:
		ctx["heightened"] = tgt[0].id if not tgt.is_empty() else (_area_victims(c, s, cells)[0].id if not _area_victims(c, s, cells).is_empty() else "")
	if "extended" in meta:
		var s_ext := s.duplicate(true)
		var dd := s_ext.get("duration", {}) as Dictionary
		if dd.has("amount"):
			dd["amount"] = mini(int(dd["amount"]) * 2, 24 * 60 if str(dd.get("kind", "")) == "minutes" else 24)
		ctx["s"] = s_ext
		if conc != null:
			var steady := Effect.new("Extended Spell", &"feature", "extended_spell").with_modifier("advantage", {"on": "concentration"})
			conc.attach(c.creature, steady)
	var r := CombatResult.new()
	if "overchannel" in c.armed and level >= 1 and level <= 5 and s.has("damage"):
		c.armed.erase("overchannel")
		ctx["overchannel"] = true
		_overchannel_cost(c, level)
	_resolve(ctx, tgt, cells, r)
	_finish_concentration(ctx)
	_after_cast_features(ctx, use_free)
	zones.prune()
	e._check_over()
	return e.then(r, func() -> CombatResult: return e.run_reaction_queue(r))


## Overchannel (Evoker 14): the first use per Long Rest is free; each later one deals 2d12 Necrotic per spell level
## (+1d12 per use) to the caster, ignoring Resistance and Immunity.
func _overchannel_cost(c: Combatant, level: int) -> void:
	var uses := int(c.get_meta("overchannel_uses", 0))
	c.set_meta("overchannel_uses", uses + 1)
	if uses == 0:
		return
	var n := (2 + uses - 1) * level
	var rolled := enc()._roll_damage_dice("%dd12" % n, false, 0, "Overchannel")
	c.creature.hp = maxi(0, c.creature.hp - int(rolled["total"]))
	enc().log.add("hit", "Overchannel burns %s for %d Necrotic" % [c.name(), int(rolled["total"])], c.id, [str(rolled["text"])])


## After a spell with a slot: the Abjurer's Arcane Ward (made or recharged by Abjuration spells), the Diviner's
## Expert Divination (a lower slot back after a Divination spell of level 2+).
func _after_cast_features(ctx: Dictionary, free: bool) -> void:
	var c := ctx["c"] as Combatant
	var s := ctx["s"] as Dictionary
	var slot := int(ctx["slot"])
	if slot <= 0 or free or not c.creature is Character:
		return
	var ch := c.creature as Character
	var e := enc()
	if str(s.get("school", "")) == "abjuration" and CombatFeatures.has_feature(c, "arcane_ward"):
		var cap := ch.resource_max("arcane_ward")
		if not c.has_meta("ward_made") and ch.resource_left("arcane_ward") > 0:
			c.set_meta("ward_made", true)
			ch.spend_resource("arcane_ward")
			c.creature.ward_hp = cap
			e.log.add("info", "%s weaves an Arcane Ward (%d Hit Points)" % [c.name(), cap], c.id)
		elif c.has_meta("ward_made"):
			c.creature.ward_hp = mini(cap, c.creature.ward_hp + 2 * slot)
			e.log.add("info", "%s's Arcane Ward strengthens to %d" % [c.name(), c.creature.ward_hp], c.id)
	if str(s.get("school", "")) == "divination" and slot >= 2 and CombatFeatures.has_feature(c, "expert_divination"):
		for l in range(mini(slot - 1, 5), 0, -1):
			if ch.slots_used[l - 1] > 0:
				ch.slots_used[l - 1] -= 1
				e.log.add("info", "%s regains a level %d slot (Expert Divination)" % [c.name(), l], c.id)
				break


## A monster casting from its stat block (combat/monster_actions.gd): the action economy as usual, no slots, the
## stat block's DC and attack bonus in `nums`, at `level`.
func cast_with_numbers(c: Combatant, spell_id: String, level: int, targets: Array, point: Vector2, nums: Dictionary) -> CombatResult:
	var e := enc()
	var s := _comp().spell_data(spell_id)
	var unit := str((s.get("casting_time", {}) as Dictionary).get("unit", "action"))
	var why := economy_block(c, unit)
	if why != "":
		return CombatResult.fail(why)
	var check := _check_targets(c, s, level, targets, point, {})
	if str(check["why"]) != "":
		return CombatResult.fail(str(check["why"]))
	if unit == "bonus_action":
		c.bonus_available = false
	else:
		e.spend_action(c)
		c.magic_action_used = true
	var tgt := check["targets"] as Array[Combatant]
	var conc: Concentration = null
	if bool((s.get("duration", {}) as Dictionary).get("concentration", false)):
		conc = c.creature.begin_concentration(spell_id, str(s["name"]))
	e.log.add("spell", "%s casts %s%s" % [c.name(), s["name"], " (level %d)" % level if level > int(s.get("level", 0)) else ""], c.id)
	var cells: Array[Vector2i] = []
	if s.has("area"):
		var dir := Vector2.ZERO
		if not tgt.is_empty():
			dir = (e.center_of(tgt[0]) - e.center_of(c)).normalized()
		cells = area_for(c, s, point, dir, level)
	e.events.append({"type": "spell", "caster": c.id, "spell": spell_id, "cells": cells, "targets": tgt.map(func(t: Combatant) -> String: return t.id)})
	var ctx := {"c": c, "s": s, "slot": level, "nums": nums, "conc": conc, "opts": {}, "point": point, "cells": cells,
		"choice": choice_of(s, {}), "direction": Vector2.ZERO, "cell": check["cell"]}
	var r := CombatResult.new()
	_resolve(ctx, tgt, cells, r)
	_finish_concentration(ctx)
	zones.prune()
	e._check_over()
	return e.then(r, func() -> CombatResult: return e.run_reaction_queue(r))


## Casts a spell without a slot or the usual action (War God's Blessing, features that cast spells): opts may say
## no_concentration (it lasts its `minutes` instead).
func cast_free(c: Combatant, spell_id: String, targets: Array, point: Vector2, opts: Dictionary = {}) -> CombatResult:
	var e := enc()
	var s := _comp().spell_data(spell_id)
	if s.is_empty():
		return CombatResult.fail("Unknown spell")
	var level := int(s.get("level", 0))
	var check := _check_targets(c, s, level, targets, point, opts)
	if str(check["why"]) != "":
		return CombatResult.fail(str(check["why"]))
	var tgt := check["targets"] as Array[Combatant]
	var conc: Concentration = null
	var s2 := s.duplicate(true)
	if bool((s.get("duration", {}) as Dictionary).get("concentration", false)):
		if bool(opts.get("no_concentration", false)):
			s2["duration"] = {"kind": "minutes", "amount": int(opts.get("minutes", 1))}
		else:
			conc = c.creature.begin_concentration(spell_id, str(s["name"]))
	var entry := _entry_any(c, spell_id)
	if entry.is_empty():
		entry = {"class_id": "cleric" if c.creature is Character and (c.creature as Character).class_level_of("cleric") > 0 else ""}
	var nums := numbers(c, entry)
	e.log.add("spell", "%s casts %s (no slot)" % [c.name(), s["name"]], c.id)
	var cells: Array[Vector2i] = []
	if s.has("area"):
		cells = area_for(c, s2, point, Vector2.ZERO, level)
	e.events.append({"type": "spell", "caster": c.id, "spell": spell_id, "cells": cells, "targets": tgt.map(func(t: Combatant) -> String: return t.id)})
	var ctx := {"c": c, "s": s2, "slot": level, "nums": nums, "conc": conc, "opts": opts, "point": point, "cells": cells,
		"choice": choice_of(s, opts), "direction": Vector2.ZERO, "cell": check["cell"]}
	var r := CombatResult.new()
	_resolve(ctx, tgt, cells, r)
	_finish_concentration(ctx)
	zones.prune()
	e._check_over()
	return r


## Validates targets, range and line of effect. {why, targets: Array[Combatant], cell: Vector2i}
func _check_targets(c: Combatant, s: Dictionary, slot: int, targets: Array, point: Vector2, opts: Dictionary) -> Dictionary:
	var e := enc()
	var tgt: Array[Combatant] = []
	for t: Variant in targets:
		if t is Combatant:
			tgt.append(t as Combatant)
	var out := {"why": "", "targets": tgt, "cell": Vector2i(-1, -1)}
	var rng := range_ft(s, c)
	# Distant Spell: double range, Touch becomes 30 ft.
	if bool(opts.get("range_mult", false)):
		rng = 30 if str((s.get("range", {}) as Dictionary).get("kind", "")) == "touch" else rng * 2
	var id := str(s["id"])
	var tkind := str((s.get("targets", {}) as Dictionary).get("kind", "creature"))
	var placed := s.has("object") or id in ["misty_step", "dimension_door"] or id in SUMMON_SPELLS
	if placed:
		var cell: Vector2i = opts.get("cell", Vector2i(-1, -1))
		if cell.x < 0 and point != Vector2.INF:
			cell = Vector2i(floori(point.x), floori(point.y))
		if cell.x < 0 and not tgt.is_empty():
			cell = _beside(c, tgt[0])
		if cell.x < 0:
			out["why"] = "Choose a square"
			return out
		if not e.grid.in_bounds(cell) or e.grid.is_solid(cell):
			out["why"] = "Can't go there"
			return out
		if e.grid.distance_ft(c.cell, c.size_cells, cell, 1) > rng:
			out["why"] = "That square is out of range (%d ft)" % rng
			return out
		if (id in ["misty_step", "dimension_door", "flaming_sphere"] or id in SUMMON_SPELLS) and e.occupant_at(cell) != null:
			out["why"] = "That square is occupied"
			return out
		if id == "misty_step" and not e.grid.can_see(c.cell, c.size_cells, cell, 1):
			out["why"] = "You must see the square you teleport to"
			return out
		out["cell"] = cell
		return out
	if tkind == "self" and not s.has("area"):
		tgt = [c]
		out["targets"] = tgt
		return out
	if s.has("area") and str((s.get("range", {}) as Dictionary).get("kind", "")) != "self" and not s.has("attack"):
		if point == Vector2.INF:
			out["why"] = "Choose a point"
			return out
		var pc := Vector2i(floori(point.x), floori(point.y))
		if e.grid.distance_ft(c.cell, c.size_cells, pc, 1) > rng:
			out["why"] = "That point is out of range (%d ft)" % rng
		return out
	if s.has("area") and not s.has("attack"):
		return out
	if tgt.is_empty():
		out["why"] = "Choose a target"
		return out
	if tgt.size() > target_count(s, slot) and not id in ["magic_missile", "scorching_ray", "eldritch_blast"]:
		out["why"] = "Too many targets (%d max)" % target_count(s, slot)
		return out
	for t in tgt:
		if id == "revivify":
			if not t.creature.dead:
				out["why"] = "%s isn't dead" % t.name()
				return out
		elif t.creature.dead:
			out["why"] = "%s is dead" % t.name()
			return out
		if e.distance(c, t) > rng:
			out["why"] = "%s is out of range (%d ft)" % [t.name(), rng]
			return out
		if t != c and int(e.cover(c, t)["cover"]) == CombatGrid.Cover.TOTAL:
			out["why"] = "No line of effect to %s" % t.name()
			return out
		var only := str((s.get("targets", {}) as Dictionary).get("creature_type", ""))
		if only == "" and str((s.get("targets", {}) as Dictionary).get("description", "")).contains("Humanoid"):
			only = "humanoid"
		if only != "" and str(t.creature.creature_type) != only:
			out["why"] = "%s only affects %ss" % [s["name"], only.capitalize()]
			return out
		if t != c and specials.sphere_blocks(c, t):
			out["why"] = "A sphere of force stands between you and %s" % t.name()
			return out
		if (s.has("attack") or s.has("damage")) and t != c:
			var sb := sanctuary_blocks(c, t)
			if sb != "":
				out["why"] = sb
				return out
			var charm := e.charm_blocks(c, t)
			if charm != "":
				out["why"] = charm
				return out
	return out


## Concentration with nothing to keep ends at once (a Hold Person everyone saved against); spells that leave an
## area, an object, a summon or a sustained action keep it.
func _finish_concentration(ctx: Dictionary) -> void:
	var conc := ctx["conc"] as Concentration
	if conc == null or conc.ended:
		return
	var c := ctx["c"] as Combatant
	var id := str((ctx["s"] as Dictionary)["id"])
	if conc.effect_count() > 0:
		return
	for o in zones.objects:
		if o.concentration == conc and not o.expired():
			return
	for a in sustained:
		if a["conc"] != null and (a["conc"] as WeakRef).get_ref() == conc:
			return
	if summoned.has(c.id) and not (summoned[c.id] as Array).is_empty():
		return
	if id in ["haste", "fly", "levitate"]:
		return
	conc.end("no one was affected")


func _resolve(ctx: Dictionary, tgt: Array[Combatant], cells: Array[Vector2i], r: CombatResult) -> void:
	var s := ctx["s"] as Dictionary
	var c := ctx["c"] as Combatant
	if specials.resolve(ctx, tgt, cells, r):
		return
	match str(s["id"]):
		"magic_missile":
			_magic_missile(ctx, tgt, r)
			return
		"sleep":
			_sleep(ctx, cells, r)
			return
		"command":
			for t in tgt:
				_command(ctx, t, str(ctx["choice"]) if str(ctx["choice"]) != "" else str((ctx["opts"] as Dictionary).get("word", "grovel")), r)
			return
		"sanctuary":
			_sanctuary(ctx, tgt[0], r)
			return
		"spare_the_dying":
			_spare_the_dying(ctx, tgt[0], r)
			return
		"misty_step":
			_teleport(c, ctx["cell"] as Vector2i, r)
			return
		"revivify":
			_revivify(ctx, tgt[0], r)
			return
		"arcane_vigor":
			_arcane_vigor(ctx, r)
			return
		"dispel_magic":
			_dispel(ctx, tgt[0], r)
			return
		"summon_fey", "summon_undead", "find_steed", "summon_beast", "giant_insect", "summon_aberration", "summon_construct", "summon_elemental":
			_summon(ctx, ctx["cell"] as Vector2i, r)
			return
		"true_strike":
			_true_strike(ctx, tgt[0], r)
			return
		"remove_curse":
			var t0 := tgt[0]
			var gone := 0
			for fx: Effect in t0.creature.effects.duplicate():
				if fx.source_id == "bestow_curse" or fx.modifiers.any(func(m: Modifier) -> bool: return m.text("value").begins_with("curse:")):
					t0.creature.remove_effect(fx)
					gone += 1
			r.lines.append(enc().log.add("spell", "%s: %s" % [s["name"], "%d curse%s lifted from %s" % [gone, "" if gone == 1 else "s", t0.name()] if gone > 0 else "%s bears no curse" % t0.name()], c.id))
			return
		"etherealness", "plane_shift":
			c.creature.dead = true
			enc().events.append({"type": "vanish", "id": c.id})
			r.lines.append(enc().log.add("info", "%s slips away (%s)" % [c.name(), s["name"]], c.id))
			return
		"expeditious_retreat":
			c.movement_left += c.speed()
			enc().log.add("info", "%s Dashes (+%d ft)" % [c.name(), c.speed()], c.id)
	if s.has("object"):
		_place_object(ctx, tgt, r)
		return
	if s.has("zone"):
		_place_zone(ctx, cells, r)
		apply_effect_entries(ctx, c, (s["zone"] as Dictionary).get("caster_effects", []) as Array, "cast", r)
		# The spell resolves as usual and leaves an area behind (Ice Storm's hail on the ground).
		if bool((s["zone"] as Dictionary).get("resolve_on_cast", false)):
			_generic(ctx, tgt, cells, r)
	else:
		_generic(ctx, tgt, cells, r)
	if s.has("sustain"):
		_grant_sustained(ctx, tgt)


func _generic(ctx: Dictionary, tgt: Array[Combatant], cells: Array[Vector2i], r: CombatResult) -> void:
	var c := ctx["c"] as Combatant
	var s := ctx["s"] as Dictionary
	var victims: Array[Combatant] = tgt
	if not cells.is_empty() and not s.has("attack"):
		victims = _area_victims(c, s, cells)
	if s.has("attack"):
		var count := 1
		var dmg := s.get("damage", []) as Array
		if not dmg.is_empty() and str((dmg[0] as Dictionary).get("per", "")) == "ray":
			count = target_count(s, int(ctx["slot"]))
		elif not dmg.is_empty() and str((dmg[0] as Dictionary).get("per", "")) == "beam":
			count = specials.beams(c)
		var shots: Array[Combatant] = []
		if count > 1:
			for i in count:
				shots.append(tgt[i % tgt.size()])
		else:
			shots = tgt
		for t in shots:
			if t.is_alive():
				spell_attack(ctx, t, r)
		return
	if s.has("save"):
		_save_spell(ctx, victims, r)
		return
	if s.has("heal"):
		for t in victims:
			_heal(ctx, t, r)
		for t in victims:
			apply_effect_entries(ctx, t, s.get("effects", []) as Array, "cast", r)
		return
	# A self-targeted spell whose damage comes from a later action (Produce Flame's hurl) doesn't burn the caster.
	var self_held := str((s.get("targets", {}) as Dictionary).get("kind", "")) == "self" and s.has("sustain")
	if s.has("damage") and not self_held:
		var rolled := roll_damage_parts(ctx, s["damage"] as Array, false, null)
		for t in victims:
			enc().deal_damage(c, t, [{"amount": int(rolled["total"]), "type": str(rolled["type"]), "spell": true}], false, str(s["name"]), [str(rolled["text"])])
	for t in victims:
		if s.has("temp_hp"):
			_temp_hp(ctx, t, r)
		apply_effect_entries(ctx, t, s.get("effects", []) as Array, "cast", r)


# --- Damage ---------------------------------------------------------------------------------------

func _damage_dice(ctx: Dictionary, target: Combatant = null) -> String:
	var s := ctx["s"] as Dictionary
	var c := ctx["c"] as Combatant
	var dice := Spellcasting.damage_dice(s, c.creature.character_level(), int(ctx["slot"]))
	if str(s["id"]) == "toll_the_dead" and target != null and target.creature.hp < target.creature.max_hp():
		dice = dice.replace("d8", "d12")
	return dice


func _damage_type(ctx: Dictionary, part: Dictionary = {}) -> String:
	if ctx.has("transmute_to"):
		return str(ctx["transmute_to"])
	var s := ctx["s"] as Dictionary
	var d := part if not part.is_empty() else (s.get("damage", []) as Array)[0] as Dictionary
	if d.has("type"):
		return str(d["type"])
	var types := (d.get("type_choice", []) as Array).map(func(x: Variant) -> String: return str(x))
	var pick := str(ctx.get("choice", ""))
	if pick == "":
		pick = str((ctx["opts"] as Dictionary).get("damage_type", ""))
	return pick if pick in types else str(types[0])


func _damage_bonus(ctx: Dictionary) -> Breakdown:
	var c := ctx["c"] as Combatant
	var s := ctx["s"] as Dictionary
	if not c.creature is Character:
		return Breakdown.new("Damage bonus")
	var ch := c.creature as Character
	var preview := ch.spell_preview(str(s["id"]), int(ctx["slot"]))
	return preview.get("damage_bonus", Breakdown.new("Damage bonus")) as Breakdown


## The spell's first damage entry for one target: {total, text, dice}, with the spell's damage bonuses (Potent
## Spellcasting, Empowered Evocation).
func _roll_spell_damage(ctx: Dictionary, t: Combatant, critical: bool) -> Dictionary:
	var e := enc()
	var dice := _damage_dice(ctx, t)
	var rolled := e._roll_damage_dice(dice, critical, 0, "%s damage" % (ctx["s"] as Dictionary)["name"],
		{"count": maxi(1, (ctx["c"] as Combatant).creature.ability_mod(&"cha")), "at_most": int(DiceRoller.parse_expr(dice)["sides"]) / 2, "source": "Empowered Spell"} \
		if "empowered" in (ctx.get("metamagic", []) as Array) else {})
	var sp := ctx["s"] as Dictionary
	if bool(ctx.get("overchannel", false)):
		var pm := DiceRoller.parse_expr(dice)
		var mx := int(pm["count"]) * int(pm["sides"]) * (2 if critical else 1) + int(pm["modifier"])
		rolled = {"total": mx, "text": "maximum (Overchannel) = %d" % mx}
	var bonus := _damage_bonus(ctx)
	var total := int(rolled["total"]) + bonus.total()
	var text := "%s %s%s: %s" % [(ctx["s"] as Dictionary)["name"], dice, " ×2 (Critical Hit)" if critical else "", rolled["text"]]
	if str(sp["id"]) == "sorcerous_burst":
		var burst := specials.sorcerous_burst_extra(ctx, str(rolled["text"]))
		total += int(burst["total"])
		if str(burst["text"]) != "":
			text += " · " + str(burst["text"])
	if not bonus.parts.is_empty():
		text += " · " + bonus.describe()
	return {"total": maxi(0, total), "text": text, "dice": dice, "rolls": rolled.get("rolls", [])}


## Damage from a list of parts outside the spell's main entry (a zone's damage, Ice Knife's burst, Witch Bolt's
## later bolts), with upcast dice (`upcast` on the part, else the spell's `upcast.damage`) and the caster's
## modifier when `add_mod`. {total, text, type}
func roll_damage_parts(ctx: Dictionary, parts: Array, critical: bool, _t: Combatant) -> Dictionary:
	var e := enc()
	var s := ctx["s"] as Dictionary
	var c := ctx["c"] as Combatant
	var slot := int(ctx["slot"])
	var total := 0
	var texts: Array[String] = []
	var ty := ""
	for p: Variant in parts:
		var part := p as Dictionary
		var base := DiceRoller.parse_expr(str(part.get("dice", "0")))
		var count := int(base["count"])
		var up := str(part.get("upcast", (s.get("upcast", {}) as Dictionary).get("damage", "")))
		if int(s.get("level", 0)) > 0 and slot > int(s.get("level", 0)) and up != "" and bool(part.get("scales", true)):
			count += int(DiceRoller.parse_expr(up)["count"]) * (slot - int(s.get("level", 0)))
		if int(s.get("level", 0)) == 0:
			var sc := s.get("cantrip_scaling", {}) as Dictionary
			if sc.has("damage"):
				count += int(DiceRoller.parse_expr(str(sc["damage"]))["count"]) * Spellcasting.cantrip_tier(c.creature.character_level())
		var dice := Spellcasting._format(count, int(base["sides"]), int(base["modifier"]))
		var rolled := e._roll_damage_dice(dice, critical, 0, "%s damage" % s["name"])
		var sub := int(rolled["total"])
		if bool(part.get("add_mod", false)):
			sub += int((ctx["nums"] as Dictionary).get("mod", 0))
		total += sub
		texts.append("%s %s: %s" % [s["name"], dice, rolled["text"]])
		if ty == "":
			ty = str(part["type"]) if part.has("type") else _damage_type(ctx, part)
	return {"total": maxi(0, total), "text": " · ".join(texts), "type": ty}


# --- Spell attacks --------------------------------------------------------------------------------

## A spell attack roll at `t`: damage on a hit (with Critical Hits), the spell's hit effects, Chromatic Orb's
## leap, Vampiric Touch's drain; half damage on a miss for spells that say so (Melf's Acid Arrow) and for Potent
## Cantrip; Ice Knife's burst either way.
func spell_attack(ctx: Dictionary, t: Combatant, r: CombatResult) -> D20Test:
	var c := ctx["c"] as Combatant
	var s := ctx["s"] as Dictionary
	var e := enc()
	var melee := str(s["attack"]) == "melee"
	var option := {"melee": melee, "profile": WeaponProfile.new(), "kind": "spell"}
	(option["profile"] as WeaponProfile).normal_range = range_ft(s, c)
	var sit := e.attack_situation(c, t, option)
	if str(s["id"]) == "sacred_flame":
		sit["cover_bonus"] = 0
	e._consume_marks(c, t)
	specials.duel_check_attack(c, t)
	trigger_ends(c, "attack_roll")
	var ac := t.creature.ac_value() + int(sit["cover_bonus"])
	var atk := ctx["nums"]["attack"] as Breakdown
	var keys: Array[String] = ["attack", "attack:melee" if melee else "attack:ranged", "attack:spell"]
	var test := c.creature.roll_d20(e.dice, D20Test.Kind.ATTACK_ROLL, atk, ac, keys, sit["advantage"] as Array[String],
		sit["disadvantage"] as Array[String], "%s → %s (%s)" % [c.name(), t.name(), s["name"]])
	t.creature.consume_attacked()
	if not test.success and "seeking" in (ctx.get("metamagic", []) as Array) and not bool(ctx.get("seeking_used", false)):
		ctx["seeking_used"] = true
		test = c.creature.roll_d20(e.dice, D20Test.Kind.ATTACK_ROLL, atk, ac, keys, sit["advantage"] as Array[String],
			sit["disadvantage"] as Array[String], "%s → %s (%s, Seeking Spell reroll)" % [c.name(), t.name(), s["name"]])
	var details: Array[String] = [test.describe(), atk.describe()]
	var hit := test.success
	if hit and e.mirror_image_takes(t, c, test.total):
		hit = false
	e.events.append({"type": "attack", "attacker": c.id, "target": t.id, "hit": hit, "critical": test.critical and hit})
	if not hit:
		r.lines.append(e.log.add("miss", "%s's %s misses %s (%d vs AC %d)" % [c.name(), s["name"], t.name(), test.total, ac], c.id, details))
		var half_on_miss := str(s.get("miss", "")) == "half" or (int(s.get("level", 0)) == 0 and c.creature.has_flag("potent_cantrip"))
		if half_on_miss and s.has("damage"):
			var half := _roll_spell_damage(ctx, t, false)
			var amount := int(half["total"]) / 2
			e.deal_damage(c, t, [{"amount": amount, "type": _damage_type(ctx), "spell": true}], false, str(s["name"]),
				["Half damage on a miss", str(half["text"])])
		apply_effect_entries(ctx, t, s.get("effects", []) as Array, "miss", r)
		_secondary(ctx, t, r)
		return test
	r.hit = true
	var critical := test.critical
	if s.has("damage"):
		var rolled := _roll_spell_damage(ctx, t, critical)
		details.append(str(rolled["text"]))
		var parts: Array = [{"amount": int(rolled["total"]), "type": _damage_type(ctx), "spell": true}]
		# Extra damage on any attack roll that hits (Hunter's Mark, Hex).
		for m in c.creature.modifiers_for(&"extra_damage"):
			if m.text("on", "weapon") != "attack" or (m.data.has("vs") and str(m.data["vs"]) != t.id):
				continue
			var xt := extra_damage_type(c, t, m, _damage_type(ctx))
			if xt == "":
				continue
			var xr := e._roll_damage_dice(m.text("dice", "1d6"), critical, 0, m.source_name)
			parts.append({"amount": int(xr["total"]), "type": xt, "spell": true})
			details.append("%s %s: %s" % [m.source_name, m.text("dice"), xr["text"]])
		var dr := e.deal_damage(c, t, parts, critical, str(s["name"]), details)
		r.damage += dr.final
		if melee:
			e.retaliate(c, t)
		if bool(s.get("drain", false)) and dr.final > 0:
			var healed := c.creature.heal(dr.final / 2, str(s["name"]))
			if healed > 0:
				e.log.add("heal", "%s drains %d Hit Points" % [c.name(), healed], c.id)
				e.events.append({"type": "heal", "id": c.id, "amount": healed})
		if str(s["id"]) == "chromatic_orb":
			_orb_leap(ctx, t, rolled, r)
	if t.is_alive():
		_on_spell_hit(ctx, t, r)
	_secondary(ctx, t, r)
	return test


## The damage type of an `extra_damage` modifier against `t`, or "" if it doesn't apply: `in_zone` limits it to
## targets inside the caster's area of that spell, and `types` lets the attacker pick the best of several each time
## (Conjure Minor Elementals: whichever the target doesn't resist).
func extra_damage_type(c: Combatant, t: Combatant, m: Modifier, fallback: String) -> String:
	if m.data.has("in_zone"):
		var o := zones.object_of(c.id, str(m.data["in_zone"]))
		if o == null or not o.covers(t):
			return ""
	var options := m.data.get("types", []) as Array
	if not options.is_empty():
		var best := str(options[0])
		var best_score := -9
		for ty: Variant in options:
			var tn := StringName(str(ty))
			var score := 0
			if t.creature.immunity_source(tn) != "":
				score = -2
			elif t.creature.resistance_source(tn) != "":
				score = -1
			elif t.creature.vulnerability_source(tn) != "":
				score = 1
			if score > best_score:
				best_score = score
				best = str(ty)
		return best
	return m.text("type", fallback)


## Riders on a hit that need code: everything else is in the spell's effects data (`on: hit`).
func _on_spell_hit(ctx: Dictionary, t: Combatant, r: CombatResult) -> void:
	var c := ctx["c"] as Combatant
	var e := enc()
	match str((ctx["s"] as Dictionary)["id"]):
		"guiding_bolt":
			e.add_mark({"kind": "advantage_against", "target": t.id, "source": "Guiding Bolt",
				"expires_owner": c.id, "expires_phase": "end", "skip": e.own_turn_skip(c), "consume": true})
			return
	apply_effect_entries(ctx, t, (ctx["s"] as Dictionary).get("effects", []) as Array, "hit", r)


## Ice Knife: hit or miss, the target and each creature within 5 ft of it make the burst's save.
func _secondary(ctx: Dictionary, t: Combatant, r: CombatResult) -> void:
	var s := ctx["s"] as Dictionary
	if not s.has("secondary"):
		return
	var sec := s["secondary"] as Dictionary
	var e := enc()
	var cells := e.grid.area_cells("emanation", int(sec.get("radius", 5)), e.center_of(t), Vector2.RIGHT, 5, t.cell, t.size_cells)
	if not bool(sec.get("exclude_target", false)):
		for cell in t.footprint():
			if not cell in cells:
				cells.append(cell)
	e.events.append({"type": "spell", "caster": (ctx["c"] as Combatant).id, "spell": str(s["id"]), "cells": cells, "targets": []})
	var sub := ctx.duplicate()
	var sub_s := s.duplicate()
	sub_s["save"] = sec["save"]
	sub_s["save_success"] = sec.get("save_success", "none")
	sub_s["damage"] = sec["damage"]
	sub_s["effects"] = sec.get("effects", [])
	sub_s.erase("secondary")
	sub_s.erase("attack")
	sub["s"] = sub_s
	var victims := creatures_in(cells)
	_save_spell(sub, victims, r)


## Chromatic Orb (2024): if two or more of the d8s match, the orb leaps to a creature within 30 ft of the last
## one it hit (a new attack roll and damage), up to the slot level in leaps, never the same creature twice.
func _orb_leap(ctx: Dictionary, last: Combatant, rolled: Dictionary, r: CombatResult) -> void:
	var e := enc()
	var c := ctx["c"] as Combatant
	var leaps := int(ctx.get("leaps_left", int(ctx["slot"])))
	var hitlist := ctx.get("orb_hit", [last.id]) as Array
	if leaps <= 0 or not _has_duplicate(rolled):
		return
	var next: Combatant = null
	var best := 1 << 30
	for o in e.hostiles_of(c):
		if o.id in hitlist or o.is_down() or e.grid.distance_ft(last.cell, last.size_cells, o.cell, o.size_cells) > 30:
			continue
		var d := e.distance(c, o)
		if d < best:
			best = d
			next = o
	if next == null:
		return
	e.log.add("spell", "The orb leaps to %s (matching dice)" % next.name(), c.id)
	var sub := ctx.duplicate()
	sub["leaps_left"] = leaps - 1
	hitlist.append(next.id)
	sub["orb_hit"] = hitlist
	spell_attack(sub, next, r)


func _has_duplicate(rolled: Dictionary) -> bool:
	var text := str(rolled.get("text", ""))
	var open := text.find("[")
	var close := text.find("]")
	if open < 0 or close < 0:
		return false
	var seen := {}
	for part in text.substr(open + 1, close - open - 1).split(","):
		var v := part.strip_edges()
		if seen.has(v):
			return true
		seen[v] = true
	return false


# --- Saving throws --------------------------------------------------------------------------------

## Saving-throw spells: damage rolled once for all targets; each target saves (Dexterity saves add cover from
## the point of origin, except Sacred Flame; creature-type Disadvantage like Shatter against Constructs); half
## damage on a success when the spell says so (or for Potent Cantrip); effects on a failure or a success; pushes
## and pulls afterwards, farthest creature first so a pack isn't blocked by its own back row.
func _save_spell(ctx: Dictionary, victims: Array[Combatant], r: CombatResult) -> void:
	var c := ctx["c"] as Combatant
	var s := ctx["s"] as Dictionary
	var e := enc()
	var dc := (ctx["nums"]["dc"] as Breakdown).total()
	var ab := StringName(str(s["save"]))
	var has_damage := s.has("damage") and not (s["damage"] as Array).is_empty()
	var shared := {}
	# Several damage types at once (Ice Storm's Bludgeoning and Cold): each part rolled once, halved on its own.
	var multi: Array[Dictionary] = []
	if has_damage and (s["damage"] as Array).size() > 1:
		for i in (s["damage"] as Array).size():
			var part := (s["damage"] as Array)[i] as Dictionary
			if str(part.get("per", "")) == "turn":
				continue
			var pr := roll_damage_parts(ctx, [part], false, null)
			if i == 0:
				var bonus0 := _damage_bonus(ctx)
				pr["total"] = int(pr["total"]) + bonus0.total()
			multi.append(pr)
	elif has_damage and str(s["id"]) != "toll_the_dead":
		shared = _roll_spell_damage(ctx, null, false)
	var half_on_success := str(s.get("save_success", "none")) == "half" or (int(s.get("level", 0)) == 0 and c.creature.has_flag("potent_cantrip"))
	var pushes: Array[Dictionary] = []
	ctx["push_queue"] = pushes
	for t in victims:
		if not t.is_alive():
			continue
		var bonus_text := ""
		var save_bd := t.creature.save_bonus(ab)
		if ab == &"dex" and str(s["id"]) != "sacred_flame":
			var cov := e.grid.cover_between(c.cell, c.size_cells, t.cell, t.size_cells, e.creature_cells([c, t]))
			var cb := CombatGrid.COVER_BONUS[int(cov["cover"])]
			if cb > 0:
				save_bd.add(CombatGrid.COVER_NAMES[int(cov["cover"])], cb)
				bonus_text = " (cover +%d)" % cb
		var keys := t.creature.save_keys(ab)
		for cond in _conditions_in(s.get("effects", []) as Array, str(ctx.get("choice", ""))):
			keys.append("save_vs:%s" % cond)
		keys.append("save_vs:spell")
		var dis: Array[String] = []
		var adv: Array[String] = []
		if t.creature.has_flag("eldritch_struck:%s" % c.id):
			dis.append("Eldritch Strike")
		if CombatFeatures.has_feature(c, "magical_ambush") and (c.hidden or c.creature.has_condition(&"invisible")):
			dis.append("Magical Ambush")
		if c.creature.has_flag("corona") and e.in_sunlight(t) and c.hostile_to(t) and _damage_type_safe(ctx) in ["fire", "radiant"]:
			dis.append("Corona of Light")
		var sculpted := _sculpted(ctx, t) or _careful(ctx, t)
		if str(ctx.get("heightened", "")) == t.id:
			dis.append("Heightened Spell")
		var vs := s.get("save_disadvantage_for", "") as String
		if vs != "" and str(t.creature.creature_type) == vs:
			dis.append("%s against %s" % [vs.capitalize(), s["name"]])
		if bool(s.get("save_advantage_if_fighting", false)) and c.hostile_to(t):
			adv.append("you're fighting it")
		var min_size := str(s.get("save_advantage_min_size", ""))
		if min_size != "" and Creature.SIZES.find(t.creature.size) >= Creature.SIZES.find(StringName(min_size)):
			adv.append("%s or larger" % min_size.capitalize())
		if str(s["id"]) == "sleep" and t.creature.is_condition_immune(&"exhaustion"):
			r.lines.append(e.log.add("info", "%s doesn't sleep: unaffected" % t.name(), t.id))
			continue
		var willing := bool(s.get("willing_skip_save", false)) and c.allied_with(t)
		# Enthrall: a creature you or your companions are fighting succeeds automatically.
		if bool(s.get("fighting_auto_success", false)) and c.hostile_to(t):
			r.lines.append(e.log.add("info", "%s is too caught up in the fight to be enthralled" % t.name(), t.id))
			continue
		var auto_fail := str(t.creature.creature_type) in (s.get("auto_fail_types", []) as Array)
		if sculpted:
			r.lines.append(e.log.add("info", "%s is sculpted out of %s" % [t.name(), s["name"]], t.id))
			continue
		var test: D20Test = null
		var success := false
		var details: Array[String] = []
		if auto_fail:
			details.append("%s fails automatically (%s)" % [t.name(), str(t.creature.creature_type).capitalize()])
		elif not willing:
			test = t.creature.roll_d20(e.dice, D20Test.Kind.SAVING_THROW, save_bd, dc, keys, adv, dis,
				"%s save vs %s (%s)" % [Creature.ABILITY_NAMES[ab], s["name"], t.name()])
			success = test.success
			details.append(test.describe() + bonus_text)
		else:
			details.append("%s doesn't resist" % t.name())
		if has_damage and not multi.is_empty():
			var parts: Array = []
			for pr in multi:
				var amt := int(pr["total"])
				if success:
					amt = amt / 2 if half_on_success else 0
				if ab == &"dex" and half_on_success and t.creature.has_flag("evasion") and t.can_act():
					amt = 0 if success else int(pr["total"]) / 2
				parts.append({"amount": amt, "type": str(pr["type"]), "spell": true})
				details.append(str(pr["text"]))
			if parts.any(func(x: Dictionary) -> bool: return int(x["amount"]) > 0):
				var drm := e.deal_damage(c, t, parts, false, str(s["name"]), details)
				r.damage += drm.final
			else:
				r.lines.append(e.log.add("info", "%s saves against %s" % [t.name(), s["name"]], t.id, details))
		elif has_damage:
			var rolled := shared if not shared.is_empty() else _roll_spell_damage(ctx, t, false)
			var amount := int(rolled["total"])
			if success:
				amount = amount / 2 if half_on_success else 0
			# Shield Master's Interpose Shield: a Reaction turns a successful Dexterity save's half damage into none.
			if success and ab == &"dex" and half_on_success and e.features.has_feat(t, "shield_master") and e.features.wields_shield(t) and can_react(t) \
					and e._reaction_decision(t, "interpose_shield") != "never":
				t.reaction_available = false
				amount = 0
				details.append("Interpose Shield: no damage")
			# Evasion (Rogue 7): Dexterity saves for half take none on a success, half on a failure.
			if ab == &"dex" and half_on_success and t.creature.has_flag("evasion") and t.can_act():
				amount = 0 if success else amount / 2
			details.append(str(rolled["text"]))
			if amount > 0:
				var dr := e.deal_damage(c, t, [{"amount": amount, "type": _damage_type(ctx), "spell": true}], false, str(s["name"]), details)
				r.damage += dr.final
			else:
				r.lines.append(e.log.add("info", "%s saves against %s" % [t.name(), s["name"]], t.id, details))
		else:
			r.lines.append(e.log.add("info", "%s %s the %s save" % [t.name(), "succeeds on" if success else "fails", s["name"]], t.id, details))
		if t.is_alive():
			apply_effect_entries(ctx, t, s.get("effects", []) as Array, "success" if success else "fail", r)
	ctx.erase("push_queue")
	_run_pushes(ctx, pushes)


## The conditions a spell's effects impose (for saves against them: Dwarven Resilience, Fey Ancestry, Brave).
static func _conditions_in(entries: Array, choice: String) -> Array[String]:
	var out: Array[String] = []
	for raw: Variant in entries:
		var p := (raw as Dictionary).get("params", {}) as Dictionary
		if str((raw as Dictionary).get("effect", "")) == "condition":
			var cond := str(p.get("condition", ""))
			if cond == "choice":
				cond = choice
			if cond != "" and not cond in out:
				out.append(cond)
	return out


func _damage_type_safe(ctx: Dictionary) -> String:
	var s := ctx["s"] as Dictionary
	if (s.get("damage", []) as Array).is_empty():
		return ""
	return _damage_type(ctx)


## Sculpt Spells (Evoker 6): allies the caster chooses (up to 1 + the spell's level) in an Evocation spell's area
## automatically succeed and take no damage.
func _sculpted(ctx: Dictionary, t: Combatant) -> bool:
	var c := ctx["c"] as Combatant
	var s := ctx["s"] as Dictionary
	if t == c or not c.allied_with(t) or str(s.get("school", "")) != "evocation" or not CombatFeatures.has_feature(c, "sculpt_spells"):
		return false
	var used := int(ctx.get("sculpted", 0))
	if used >= 1 + int(s.get("level", 0)):
		return false
	ctx["sculpted"] = used + 1
	return true


## Careful Spell: up to the caster's Charisma modifier allies automatically succeed and take no damage.
func _careful(ctx: Dictionary, t: Combatant) -> bool:
	var c := ctx["c"] as Combatant
	if not "careful" in (ctx.get("metamagic", []) as Array) or t == c or not c.allied_with(t):
		return false
	var used := int(ctx.get("careful_used", 0))
	if used >= maxi(1, c.creature.ability_mod(&"cha")):
		return false
	ctx["careful_used"] = used + 1
	return true


## Metamagic (Sorcerer): costs in Sorcery Points, one option per spell except Empowered and Seeking.
const METAMAGIC_COST := {"careful": 1, "distant": 1, "empowered": 1, "extended": 1, "heightened": 2, "quickened": 2,
	"seeking": 1, "subtle": 1, "transmuted": 1, "twinned": 1}


func _metamagic_check(c: Combatant, s: Dictionary, meta: Array) -> String:
	if meta.is_empty():
		return ""
	if not c.creature is Character:
		return "No Metamagic"
	var ch := c.creature as Character
	var cost := 0
	var main := 0
	for m: String in meta:
		if not METAMAGIC_COST.has(m):
			return "Unknown Metamagic %s" % m
		if not m in metamagic_known(ch):
			return "%s doesn't know %s Spell" % [c.name(), m.capitalize()]
		cost += int(METAMAGIC_COST[m])
		if not m in ["empowered", "seeking"]:
			main += 1
	if main > 1:
		return "Only one Metamagic option per spell (Empowered and Seeking can join another)"
	if "twinned" in meta and int((s.get("upcast", {}) as Dictionary).get("targets", 0)) <= 0:
		return "Twinned Spell needs a spell that can target more creatures at a higher level"
	if "quickened" in meta and str((s.get("casting_time", {}) as Dictionary).get("unit", "")) != "action":
		return "Quickened Spell needs a spell with a casting time of an action"
	if ch.resource_left("sorcery_points") < cost:
		return "Needs %d Sorcery Points" % cost
	return ""


## Metamagic options a character chose (choices of kind "metamagic").
static func metamagic_known(ch: Character) -> Array[String]:
	var out: Array[String] = []
	for c in ch.choice_defs:
		if c.kind == "metamagic":
			for p: Variant in c.picks:
				out.append(str(p))
	return out


func _pay_metamagic(c: Combatant, meta: Array) -> void:
	var cost := 0
	for m: String in meta:
		cost += int(METAMAGIC_COST[m])
	(c.creature as Character).spend_resource("sorcery_points", cost)
	enc().log.add("info", "%s shapes the spell: %s (%d Sorcery Points)" % [c.name(), ", ".join(meta.map(func(x: String) -> String: return x.capitalize())), cost], c.id)


func _run_pushes(ctx: Dictionary, pushes: Array[Dictionary]) -> void:
	if pushes.is_empty():
		return
	var e := enc()
	var c := ctx["c"] as Combatant
	var origin: Vector2 = ctx.get("pull_origin", e.center_of(c))
	pushes.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		var ta := a["target"] as Combatant
		var tb := b["target"] as Combatant
		var da := (e.center_of(ta) - origin).length()
		var db := (e.center_of(tb) - origin).length()
		return da > db if not bool(a["toward"]) else da < db)
	for p in pushes:
		var t := p["target"] as Combatant
		if not t.is_alive():
			continue
		var moved := e.forced_move(t, origin, int(p["feet"]), bool(p["toward"]))
		if moved > 0:
			e.log.add("info", "%s is %s %d ft (%s)" % [t.name(), "pulled" if bool(p["toward"]) else "pushed", moved * 5, (ctx["s"] as Dictionary)["name"]], t.id)
		else:
			e.log.add("info", "%s can't be %s: something's in the way" % [t.name(), "pulled" if bool(p["toward"]) else "pushed"], t.id)


# --- Healing and Temporary Hit Points -------------------------------------------------------------

func _heal(ctx: Dictionary, t: Combatant, r: CombatResult) -> void:
	var c := ctx["c"] as Combatant
	var s := ctx["s"] as Dictionary
	var e := enc()
	if t.creature.has_flag("cant_regain_hp"):
		r.lines.append(e.log.add("info", "%s can't regain Hit Points right now" % t.name(), t.id))
		return
	if t.creature.creature_type in [&"undead", &"construct"] and bool(s.get("living_only", false)):
		r.lines.append(e.log.add("info", "%s has no effect on %s" % [s["name"], t.name()], t.id))
		return
	var dice := Spellcasting.heal_dice(s, int(ctx["slot"]))
	var bonus := Breakdown.new("Healing bonus")
	if c.creature is Character:
		var preview := (c.creature as Character).spell_preview(str(s["id"]), int(ctx["slot"]))
		dice = str(preview.get("heal_dice", ""))
		bonus = preview.get("heal_bonus", Breakdown.new("")) as Breakdown
	elif bool((s.get("heal", {}) as Dictionary).get("add_mod", false)):
		bonus.add("Spellcasting modifier", int((ctx["nums"] as Dictionary).get("mod", 0)))
	var heal_reroll := {"count": 99, "at_most": 1, "source": "Healer"} if e.features.has_feat(c, "healer") else {}
	var rolled := e._roll_damage_dice(dice, false, 0, "%s healing" % s["name"], heal_reroll) if dice != "" else {"total": 0, "text": ""}
	var total := int(rolled["total"])
	if t.creature.has_flag("max_healing_received") and dice != "":
		var p := DiceRoller.parse_expr(dice)
		total = int(p["count"]) * int(p["sides"]) + int(p["modifier"])
		rolled["text"] = "maximum (Beacon of Hope) = %d" % total
	if CombatFeatures.has_feature(c, "supreme_healing") and dice != "":
		var pmax := DiceRoller.parse_expr(dice)
		total = int(pmax["count"]) * int(pmax["sides"]) + int(pmax["modifier"])
	var amount := total + bonus.total() + int((s.get("heal", {}) as Dictionary).get("flat", 0))
	var healed := t.creature.heal(amount, str(s["name"]))
	# Blessed Healer (Life Domain 6): healing another creature with a slot heals you 2 + the slot level.
	if t != c and int(ctx["slot"]) > 0 and CombatFeatures.has_feature(c, "blessed_healer") and not ctx.has("blessed"):
		ctx["blessed"] = true
		var self_heal := c.creature.heal(2 + int(ctx["slot"]), "Blessed Healer")
		if self_heal > 0:
			e.log.add("heal", "%s regains %d Hit Points (Blessed Healer)" % [c.name(), self_heal], c.id)
	r.lines.append(e.log.add("heal", "%s heals %s for %d" % [c.name(), t.name(), healed], c.id,
		["%s %s: %s" % [s["name"], dice, rolled["text"]], bonus.describe()]))
	e.events.append({"type": "heal", "id": t.id, "amount": healed})
	_life_bond(t, healed, int(s.get("level", 0)))


## Life Bond (Find Steed): when the rider regains Hit Points from a spell of level 1+, a steed within 5 ft regains as
## many.
func _life_bond(t: Combatant, healed: int, level: int) -> void:
	if healed <= 0 or level < 1:
		return
	var e := enc()
	for sid: Variant in summoned.get(t.id, []):
		var steed := e.get_c(str(sid))
		if steed == null or not steed.is_alive() or not steed.creature is Monster or not bool((steed.creature as Monster).data.get("steed", false)):
			continue
		if e.distance(t, steed) <= 5:
			var got := steed.creature.heal(healed, "Life Bond")
			if got > 0:
				e.log.add("heal", "%s regains %d Hit Points (Life Bond)" % [steed.name(), got], steed.id)
				e.events.append({"type": "heal", "id": steed.id, "amount": got})


## Temporary Hit Points from the spell's `temp_hp` ({dice, flat, add_mod}) plus `upcast.temp_hp` per slot level.
func _temp_hp(ctx: Dictionary, t: Combatant, r: CombatResult) -> void:
	var s := ctx["s"] as Dictionary
	var e := enc()
	var th := s["temp_hp"] as Dictionary
	var total := int(th.get("flat", 0))
	var text := ""
	if th.has("dice"):
		var rolled := e._roll_damage_dice(str(th["dice"]), false, 0, "%s Temporary Hit Points" % s["name"])
		total += int(rolled["total"])
		text = str(rolled["text"])
	if bool(th.get("add_mod", false)):
		total += int((ctx["nums"] as Dictionary)["mod"])
	total += int((s.get("upcast", {}) as Dictionary).get("temp_hp", 0)) * maxi(0, int(ctx["slot"]) - int(s.get("level", 0)))
	if t.creature.add_temp_hp(total, str(s["name"])):
		r.lines.append(e.log.add("heal", "%s gains %d Temporary Hit Points (%s)" % [t.name(), total, s["name"]], t.id, [text]))
	else:
		r.lines.append(e.log.add("info", "%s keeps its %d Temporary Hit Points (they don't stack)" % [t.name(), t.creature.temp_hp], t.id))


# --- Effects from data ----------------------------------------------------------------------------

## The `on` an effect entry fires on when it doesn't say: hit for attack spells, fail for save spells, cast for
## everything else.
static func default_on(s: Dictionary) -> String:
	if s.has("attack"):
		return "hit"
	if s.has("save"):
		return "fail"
	return "cast"


## Applies the spell's effect entries that fire on `when` (hit, miss, fail, success, cast) to `t`. Each entry may
## set its own duration (`until`), what uses it up (`consume`), what ends it (`ends_on`), a repeated save, an
## escape check, and who it lands on (`target`: self for the caster). Entries that share those settings become one
## Effect; pushes and pulls queue up when a save spell is resolving several creatures.
func apply_effect_entries(ctx: Dictionary, t: Combatant, entries: Array, when: String, r: CombatResult) -> void:
	var c := ctx["c"] as Combatant
	var s := ctx["s"] as Dictionary
	var e := enc()
	var groups := {}
	var order: Array[String] = []
	var choice := str(ctx.get("choice", ""))
	for raw: Variant in entries:
		var fx := raw as Dictionary
		var params := fx.get("params", {}) as Dictionary
		var on := str(params.get("on", default_on(s)))
		if on != when and not (on == "always" and when in ["hit", "miss", "fail", "success", "cast"]):
			continue
		var only_choice := str(params.get("only_choice", ""))
		if only_choice != "" and only_choice != choice:
			continue
		var who := t
		if str(params.get("target", "")) == "self":
			who = c
		# A mark the caster carries against the target (Hunter's Mark, Hex): the effect sits on the caster with
		# `vs: "target"` meaning this target.
		if str(params.get("target", "")) == "caster_vs":
			who = c
			ctx["vs_target"] = t.id
		var kind := str(fx.get("effect", ""))
		match kind:
			"push", "pull":
				var max_size := str(params.get("max_size", "huge"))
				if Creature.SIZES.find(who.creature.size) > Creature.SIZES.find(StringName(max_size)):
					continue
				var p := {"target": who, "feet": int(params.get("feet", 10)), "toward": kind == "pull"}
				if ctx.has("push_queue"):
					(ctx["push_queue"] as Array[Dictionary]).append(p)
				else:
					var pq: Array[Dictionary] = [p]
					_run_pushes(ctx, pq)
				continue
			"temp_hp":
				var sub := ctx.duplicate()
				var s2 := s.duplicate()
				s2["temp_hp"] = params
				sub["s"] = s2
				_temp_hp(sub, who, r)
				continue
			"heal":
				var amount := int(params.get("flat", 0))
				if params.has("dice"):
					amount += int(e._roll_damage_dice(str(params["dice"]), false, 0, str(s["name"]))["total"])
				var healed := who.creature.heal(amount, str(s["name"]))
				if healed > 0:
					r.lines.append(e.log.add("heal", "%s regains %d Hit Points (%s)" % [who.name(), healed, s["name"]], who.id))
					e.events.append({"type": "heal", "id": who.id, "amount": healed})
				continue
			"end_condition":
				_end_condition(ctx, who, params, r)
				continue
			"light":
				_light(ctx, who, params)
				continue
			"damage":
				_delayed_damage(ctx, who, params)
				continue
			"summon":
				continue
			"custom":
				_custom(ctx, who, params, r)
				continue
		var key := JSON.stringify([who.id, params.get("until", "spell"), params.get("consume", ""), params.get("ends_on", []),
			params.get("repeat_save", ""), params.get("escape", ""), params.get("plain", false), params.get("ends_on_damage", false)])
		if not groups.has(key):
			groups[key] = {"who": who, "params": params, "entries": []}
			order.append(key)
		((groups[key] as Dictionary)["entries"] as Array).append(fx)
	var gi := 0
	for key in order:
		var g := groups[key] as Dictionary
		_apply_group(ctx, g["who"] as Combatant, g["params"] as Dictionary, g["entries"] as Array, gi, r)
		gi += 1


func _apply_group(ctx: Dictionary, t: Combatant, params: Dictionary, entries: Array, index: int, r: CombatResult) -> void:
	var c := ctx["c"] as Combatant
	var s := ctx["s"] as Dictionary
	var conc := ctx["conc"] as Concentration
	var slot := int(ctx["slot"])
	var choice := str(ctx.get("choice", ""))
	var e := enc()
	# Plain conditions (Grease's Prone) stay until the usual way of ending them (standing up).
	if bool(params.get("plain", false)):
		for fx: Variant in entries:
			var p := (fx as Dictionary).get("params", {}) as Dictionary
			var cond := str(p.get("condition", ""))
			if cond == "choice":
				cond = choice
			if cond != "" and t.creature.add_condition(StringName(cond), str(s["name"])):
				r.lines.append(e.log.add("condition", "%s is %s (%s)" % [t.name(), cond.capitalize(), s["name"]], t.id))
				e.events.append({"type": "condition", "id": t.id})
				if cond == "prone" and bool(p.get("breaks_concentration", false)) and t.creature.concentration != null:
					t.creature.concentration.end("knocked Prone by %s" % s["name"])
		return
	var fxo := Effect.new(str(s["name"]), &"spell", str(s["id"]))
	fxo.caster_id = c.id
	fxo.spell_level = slot
	fxo.stack_key = "spell:%s:%d" % [s["id"], index]
	_set_duration(fxo, ctx, t, str(params.get("until", "spell")))
	var ctx2 := c.creature.formula_context(slot)
	for raw: Variant in entries:
		var f := raw as Dictionary
		var p := f.get("params", {}) as Dictionary
		match str(f.get("effect", "")):
			"modifiers":
				for md: Variant in p.get("modifiers", []):
					var d := (md as Dictionary).duplicate(true)
					_substitute_choice(d, choice)
					_substitute_casting(d, ctx)
					if str(d.get("vs", "")) == "target":
						d["vs"] = str(ctx.get("vs_target", ""))
					# Extra dice per slot level above the spell's (Conjure Minor Elementals).
					if d.has("upcast_dice") and slot > int(s.get("level", 0)):
						var bd := DiceRoller.parse_expr(str(d.get("dice", "1d4")))
						var ud := DiceRoller.parse_expr(str(d["upcast_dice"]))
						d["dice"] = "%dd%d" % [int(bd["count"]) + int(ud["count"]) * (slot - int(s.get("level", 0))), int(bd["sides"])]
					var v: Variant = d.get("value", 0)
					if v is String and (str(v).contains("slot_level") or str(v).contains("mod:")):
						d["value"] = Formula.evaluate(v, ctx2)
					if str(d.get("value", "")) == "choice":
						continue
					fxo.modifiers.append(Modifier.make(d, str(s["name"]), &"spell", str(s["id"])))
			"condition":
				if str(s["id"]) == "sleep":
					continue
				var cond := str(p.get("condition", ""))
				if cond == "choice" or (p.has("condition_choice") and choice != ""):
					cond = choice if choice != "" else str((p.get("condition_choice", [cond]) as Array)[0])
				fxo.conditions.append(StringName(cond))
	var rs := str(params.get("repeat_save", ""))
	if rs != "":
		fxo.repeat_save = {"ability": str(params.get("repeat_ability", s.get("save", "wis"))), "dc": (ctx["nums"]["dc"] as Breakdown).total(),
			"when": "start" if rs == "start_of_turn" else ("manual" if rs == "manual" else "end"), "on_damage": bool(params.get("repeat_on_damage", false)),
			"damage_advantage": bool(params.get("damage_advantage", false))}
		if params.has("repeat_if"):
			fxo.repeat_save["if"] = str(params["repeat_if"])
		if params.has("repeat_fail_damage"):
			fxo.repeat_save["fail_damage"] = params["repeat_fail_damage"]
	var esc := str(params.get("escape", ""))
	if esc.begins_with("check:"):
		fxo.escape = {"skill": esc.substr(6), "dc": (ctx["nums"]["dc"] as Breakdown).total()}
	for w: Variant in params.get("ends_on", []):
		var word := str(w)
		if word == "damage":
			fxo.ends_on_damage = true
		else:
			fxo.ends_on.append(word)
	if bool(params.get("ends_on_damage", false)):
		fxo.ends_on_damage = true
	match str(params.get("consume", "")):
		"next_save":
			fxo.consume_on = ["save:all"]
		"next_attack":
			fxo.consume_on = ["attack"]
		"next_check":
			fxo.consume_on = ["check:all"]
		"next_attacked":
			fxo.consume_when_attacked = true
	if bool(params.get("wakeable", false)):
		fxo.data["wakeable"] = true
	# Damage at the start of each of the target's turns (Searing Smite, Ensnaring Strike), with the slot's extra dice.
	if params.has("turn_damage"):
		var td := (params["turn_damage"] as Dictionary).duplicate()
		var tb := DiceRoller.parse_expr(str(td.get("dice", "1d6")))
		var tn := int(tb["count"])
		var tup := str((s.get("upcast", {}) as Dictionary).get("damage", ""))
		if tup != "" and slot > int(s.get("level", 0)):
			tn += int(DiceRoller.parse_expr(tup)["count"]) * (slot - int(s.get("level", 0)))
		td["dice"] = "%dd%d" % [tn, int(tb["sides"])]
		fxo.data["turn_damage"] = td
	# Temporary Hit Points at the start of each of its turns (Heroism: the spellcasting modifier).
	if params.has("turn_temp_hp"):
		var th: Variant = params["turn_temp_hp"]
		fxo.data["turn_temp_hp"] = int((ctx["nums"] as Dictionary).get("mod", 0)) if str(th) == "mod" else int(th)
	# Ends once its Temporary Hit Points are gone (Armor of Agathys).
	if bool(params.get("ends_without_temp_hp", false)):
		fxo.data["ends_without_temp_hp"] = true
	# Protection from Evil and Good: no Charmed or Frightened from the warded-against creature types.
	var caster_type := str(c.creature.creature_type)
	for m in t.creature.modifiers_for(&"condition_immunity_by_type"):
		if caster_type in (m.data.get("types", []) as Array):
			for blocked: Variant in m.data.get("conditions", []):
				fxo.conditions.erase(StringName(str(blocked)))
	if fxo.modifiers.is_empty() and fxo.conditions.is_empty():
		return
	for m in fxo.modifiers:
		if m.stat == &"size_step":
			_resize(t, m.number("value"), fxo)
		if m.stat == &"flag" and m.text("value") == "hasted":
			_haste_lethargy(t, fxo)
		if m.stat == &"flag" and m.text("value") == "crowned":
			t.set_meta("crowned_by", c.id)
	if str(s["id"]) == "aid":
		var gain := 5 * (slot - 1) if slot >= 2 else 5
		t.creature.add_effect(fxo)
		t.creature.heal(gain, "Aid")
		r.lines.append(e.log.add("info", "%s's Hit Point maximum rises by %d (Aid)" % [t.name(), gain], t.id))
		return
	var ok := conc.attach(t.creature, fxo) if conc != null else t.creature.add_effect(fxo)
	if ok:
		if fxo.conditions.is_empty():
			r.lines.append(e.log.add("condition", "%s gains %s" % [t.name(), s["name"]], t.id))
		else:
			var what := ", ".join(fxo.conditions.map(func(x: StringName) -> String: return str(x).capitalize()))
			r.lines.append(e.log.add("condition", "%s is %s (%s)" % [t.name(), what, s["name"]], t.id))
		e.events.append({"type": "condition", "id": t.id})
		if StringName("invisible") in fxo.conditions or StringName("incapacitated") in fxo.conditions:
			e.features.end_turning_from(t)


## Casting-time values in a modifier: "spell" as an ability is the caster's spellcasting ability, "tier:a,b,c,d" is
## a die by cantrip tier (Shillelagh), and ":caster" in a flag names the caster (Mind Spike, Bestow Curse).
func _substitute_casting(d: Dictionary, ctx: Dictionary) -> void:
	var c := ctx["c"] as Combatant
	if str(d.get("ability", "")) == "spell":
		d["ability"] = str((ctx["nums"] as Dictionary).get("ability", "int"))
	var die := str(d.get("die", ""))
	if die.begins_with("tier:"):
		var opts := die.substr(5).split(",")
		d["die"] = opts[clampi(Spellcasting.cantrip_tier(c.creature.character_level()), 0, opts.size() - 1)]
	if str(d.get("stat", "")) == "flag" and str(d.get("value", "")).ends_with(":caster"):
		d["value"] = str(d["value"]).replace(":caster", ":" + c.id)
	if str(d.get("damage_type", "")) == "weapon":
		d.erase("damage_type")


## Enlarge/Reduce: one size category up or down while the effect lasts (no growth into a space that's taken).
func _resize(t: Combatant, step: int, fxo: Effect) -> void:
	var e := enc()
	var i := Creature.SIZES.find(t.creature.size)
	var to := clampi(i + step, 0, Creature.SIZES.size() - 1)
	if to == i:
		return
	var new_size := Creature.SIZES[to]
	var cells := CombatGrid.size_cells_for(new_size)
	if cells > t.size_cells:
		for cell in CombatGrid.footprint(t.cell, cells):
			var o := e.occupant_at(cell)
			if e.grid.is_solid(cell) or (o != null and o != t):
				e.log.add("info", "%s has no room to grow" % t.name(), t.id)
				return
	var old := t.creature.size
	t.creature.size = new_size
	t.size_cells = cells
	e.events.append({"type": "resize", "id": t.id})
	fxo.data["on_end"] = {"kind": "resize", "target": t.id, "size": str(old)}
	var weak: WeakRef = weakref(t)
	fxo.on_end = func() -> void:
		var tt := weak.get_ref() as Combatant
		if tt != null:
			tt.creature.size = old
			tt.size_cells = CombatGrid.size_cells_for(old)
			var ee := enc()
			if ee != null:
				ee.events.append({"type": "resize", "id": tt.id})


## Haste ending: the target is Incapacitated with Speed 0 until the end of its next turn.
func _haste_lethargy(t: Combatant, fxo: Effect) -> void:
	fxo.data["on_end"] = {"kind": "lethargy", "target": t.id}
	var weak: WeakRef = weakref(t)
	fxo.on_end = func() -> void:
		var tt := weak.get_ref() as Combatant
		var ee := enc()
		if tt == null or ee == null or tt.creature.dead:
			return
		var lag := Effect.new("Lethargy (Haste ended)", &"spell", "haste_lethargy").with_condition(&"incapacitated").with_modifier("speed_set", {"value": 0})
		lag.ends = Effect.Ends.END_OF_TURN
		lag.turn_owner_id = tt.id
		lag.skip_turn_ends = ee.own_turn_skip(tt)
		tt.creature.add_effect(lag)
		ee.log.add("condition", "%s is overcome by lethargy as Haste ends" % tt.name(), tt.id)
		ee.events.append({"type": "condition", "id": tt.id})


## "choice" placeholders in a modifier become the cast-time pick (Protection from Energy's damage type, Guidance's
## skill as `check:choice`, Enhance Ability's ability).
static func _substitute_choice(d: Dictionary, choice: String) -> void:
	if choice == "":
		return
	for k: String in d.keys():
		var v: Variant = d[k]
		if v is String:
			d[k] = str(v).replace("choice", choice)
		elif v is Array:
			var arr: Array = []
			for x: Variant in v:
				arr.append(str(x).replace("choice", choice) if x is String else x)
			d[k] = arr


## How long an effect lasts: the spell's duration (and Concentration), or its own: caster_turn_start / caster_turn_end
## ("until the start / end of your next turn"), target_turn_start / target_turn_end, this_turn_end (Stinking Cloud's
## "until the end of that turn"), rounds:N.
func _set_duration(fxo: Effect, ctx: Dictionary, t: Combatant, until: String) -> void:
	var c := ctx["c"] as Combatant
	var s := ctx["s"] as Dictionary
	var e := enc()
	match until:
		"caster_turn_start":
			fxo.ends = Effect.Ends.START_OF_TURN
			fxo.turn_owner_id = c.id
		"caster_turn_end":
			fxo.ends = Effect.Ends.END_OF_TURN
			fxo.turn_owner_id = c.id
			fxo.skip_turn_ends = e.own_turn_skip(c)
		"target_turn_start":
			fxo.ends = Effect.Ends.START_OF_TURN
			fxo.turn_owner_id = t.id
		"target_turn_end":
			fxo.ends = Effect.Ends.END_OF_TURN
			fxo.turn_owner_id = t.id
			fxo.skip_turn_ends = e.own_turn_skip(t)
		"this_turn_end":
			fxo.ends = Effect.Ends.END_OF_TURN
			fxo.turn_owner_id = t.id
		"permanent":
			fxo.ends = Effect.Ends.NEVER
		_:
			if until.begins_with("rounds:"):
				fxo.lasting_rounds(int(until.substr(7)), c.id)
			else:
				fxo.lasting(s.get("duration", {}) as Dictionary)
				fxo.turn_owner_id = c.id


## Lesser Restoration, Protection from Poison: ends one of the listed conditions on the target (the cast-time
## choice, or the first it has).
func _end_condition(ctx: Dictionary, t: Combatant, params: Dictionary, r: CombatResult) -> void:
	var e := enc()
	var listed := (params.get("conditions", []) as Array).map(func(x: Variant) -> String: return str(x))
	var pick := str(ctx.get("choice", ""))
	var order: Array[String] = []
	if pick in listed:
		order.append(pick)
	for x: String in listed:
		if not x in order:
			order.append(x)
	for cond in order:
		if t.creature.has_condition(StringName(cond)):
			cure(t, StringName(cond))
			r.lines.append(e.log.add("heal", "%s is no longer %s (%s)" % [t.name(), cond.capitalize(), (ctx["s"] as Dictionary)["name"]], t.id))
			e.events.append({"type": "condition", "id": t.id})
			return
	r.lines.append(e.log.add("info", "%s has nothing for %s to end" % [t.name(), (ctx["s"] as Dictionary)["name"]], t.id))


## Ends a condition however it was given: as a plain condition or by effects.
func cure(t: Combatant, cond: StringName) -> void:
	t.creature.remove_condition(cond)
	for fx: Effect in t.creature.effects.duplicate():
		if cond in fx.conditions:
			if fx.modifiers.is_empty() and fx.conditions.size() == 1:
				t.creature.remove_effect(fx)
			else:
				fx.conditions.erase(cond)
	t.creature._after_conditions_changed()


## Light from a spell on a creature or the caster (Light, Produce Flame, Starry Wisp, Continual Flame, Daylight):
## a FieldObject that carries the light with it for the duration.
func _light(ctx: Dictionary, t: Combatant, params: Dictionary) -> void:
	var c := ctx["c"] as Combatant
	var s := ctx["s"] as Dictionary
	var o := FieldObject.new(FieldObject.Kind.ZONE, str(s["id"]), str(s["name"]))
	o.caster_id = c.id
	o.cell = t.cell
	o.rules = {"light": params.duplicate(), "light_on": "target", "light_target": t.id}
	var d := s.get("duration", {}) as Dictionary
	match str(params.get("until", "")):
		"caster_turn_end", "target_turn_end":
			o.rounds_left = 2
		_:
			match str(d.get("kind", "")):
				"rounds":
					o.rounds_left = int(d.get("amount", 1))
				"minutes":
					o.rounds_left = int(d.get("amount", 1)) * 10
				"instantaneous":
					o.rounds_left = 2
				_:
					o.rounds_left = 100000
	o.keep_with(ctx["conc"] as Concentration)
	zones.add(o, CombatResult.new())


## Damage later (Melf's Acid Arrow: at the end of the target's next turn), with its own upcast dice.
func _delayed_damage(ctx: Dictionary, t: Combatant, params: Dictionary) -> void:
	var c := ctx["c"] as Combatant
	var s := ctx["s"] as Dictionary
	var e := enc()
	var fx := Effect.new("%s (lingering)" % s["name"], &"spell", str(s["id"]))
	fx.caster_id = c.id
	fx.stack_key = "spell:%s:later" % s["id"]
	fx.ends = Effect.Ends.END_OF_TURN
	fx.turn_owner_id = t.id
	fx.skip_turn_ends = e.own_turn_skip(t)
	fx.modifiers.append(Modifier.of("flag", {"value": "lingering_damage"}, str(s["name"]), &"spell"))
	var part := {"dice": str(params.get("dice", "2d4")), "type": str(params.get("type", "acid")), "upcast": str(params.get("upcast", ""))}
	fx.data["on_end"] = {"kind": "delayed_damage", "target": t.id, "caster": c.id, "spell": str(s["id"]), "slot": int(ctx["slot"]), "part": part}
	var ctx_copy := ctx.duplicate()
	var weak_t: WeakRef = weakref(t)
	fx.on_end = func() -> void:
		var tt := weak_t.get_ref() as Combatant
		var ee := enc()
		if tt == null or ee == null or not tt.is_alive() or ee.state != Encounter.State.ACTIVE:
			return
		var rolled := roll_damage_parts(ctx_copy, [part], false, tt)
		ee.deal_damage(ee.get_c(c.id), tt, [{"amount": int(rolled["total"]), "type": str(rolled["type"]), "spell": true}], false,
			str(s["name"]), [str(rolled["text"])])
	t.creature.add_effect(fx)


## Effects that need code of their own.
func _custom(ctx: Dictionary, t: Combatant, params: Dictionary, r: CombatResult) -> void:
	var c := ctx["c"] as Combatant
	var s := ctx["s"] as Dictionary
	var e := enc()
	match str(params.get("id", "")):
		"mirror_image":
			var fx := Effect.new("Mirror Image", &"spell", "mirror_image").lasting(s.get("duration", {}) as Dictionary)
			fx.turn_owner_id = c.id
			fx.caster_id = c.id
			fx.data = {"duplicates": int(params.get("duplicates", 3))}
			fx.modifiers.append(Modifier.of("flag", {"value": "mirror_image"}, "Mirror Image", &"spell"))
			t.creature.add_effect(fx)
			r.lines.append(e.log.add("condition", "Three illusory duplicates surround %s" % t.name(), t.id))
		"dominate":
			specials.dominate(ctx, t)
		"flee_reaction":
			specials.flee_with_reaction(ctx, t, r)
		"revert_shape":
			# Moonbeam: a shape-shifted creature reverts to its true form.
			if e.shapes.is_shaped(t):
				e.shapes.revert(t, s["name"])
			elif t.has_meta("form") and str(t.get_meta("form")) != "humanoid":
				t.set_meta("form", "humanoid")
				r.lines.append(e.log.add("info", "%s is forced back into its true form (%s)" % [t.name(), s["name"]], t.id))
		"goodberry":
			if c.creature is Character:
				(c.creature as Character).add_item("goodberry", int(params.get("count", 10)))
				r.lines.append(e.log.add("info", "%s holds %d Goodberries" % [c.name(), int(params.get("count", 10))], c.id))
		"warding_bond":
			var fx2 := Effect.new("Warding Bond (link)", &"spell", "warding_bond").lasting(s.get("duration", {}) as Dictionary)
			fx2.turn_owner_id = c.id
			fx2.caster_id = c.id
			fx2.stack_key = "spell:warding_bond:link"
			fx2.data = {"caster": c.id, "max_distance": int(params.get("max_distance", 60))}
			fx2.modifiers.append(Modifier.of("flag", {"value": "warding_bond"}, "Warding Bond", &"spell"))
			t.creature.add_effect(fx2)


# --- Special spells -------------------------------------------------------------------------------

## Magic Missile: darts that always hit, 1d4 + 1 Force each, split as the caster chooses. A target that can cast
## Shield may do so when targeted, and then takes no damage from the darts.
func _magic_missile(ctx: Dictionary, tgt: Array[Combatant], r: CombatResult) -> void:
	var c := ctx["c"] as Combatant
	var e := enc()
	var darts := target_count(ctx["s"] as Dictionary, int(ctx["slot"]))
	var seen := {}
	for t in tgt:
		if seen.has(t.id):
			continue
		seen[t.id] = true
		if can_cast_reaction(t, "shield") and not t.creature.effects.any(func(x: Effect) -> bool: return x.source_id == "shield"):
			var decision := e._reaction_decision(t, "shield")
			if decision == "auto":
				cast_shield(t)
	for i in darts:
		var t := tgt[i % tgt.size()]
		if not t.is_alive():
			continue
		if t.creature.effects.any(func(x: Effect) -> bool: return x.source_id == "shield"):
			r.lines.append(e.log.add("miss", "Shield blocks a dart", t.id))
			continue
		var rolled := e._roll_damage_dice("1d4+1", false, 0, "Magic Missile dart")
		var bonus := _damage_bonus(ctx)
		e.deal_damage(c, t, [{"amount": int(rolled["total"]) + (bonus.total() if i == 0 else 0), "type": "force"}], false, "Magic Missile",
			["Dart %d: %s" % [i + 1, rolled["text"]]])


## Sleep (2024): creatures of your choice in the Sphere make a Wisdom save or are Incapacitated until the end of
## their next turn, then repeat the save; a second failure means Unconscious for the duration. Ends on damage or
## when someone shakes them awake. Creatures that don't sleep or are immune to Exhaustion are unaffected.
func _sleep(ctx: Dictionary, cells: Array[Vector2i], r: CombatResult) -> void:
	var c := ctx["c"] as Combatant
	var e := enc()
	var dc := (ctx["nums"]["dc"] as Breakdown).total()
	var conc := ctx["conc"] as Concentration
	for t in creatures_in(cells):
		if t == c or c.allied_with(t):
			continue
		if t.creature.is_condition_immune(&"exhaustion") or t.creature.has_flag("trance") or t.creature.creature_type in [&"undead", &"construct"]:
			r.lines.append(e.log.add("info", "%s doesn't sleep: unaffected" % t.name(), t.id))
			continue
		var test := t.creature.roll_save(e.dice, &"wis", dc, [], [], "Wisdom save vs Sleep (%s)" % t.name())
		if test.success:
			r.lines.append(e.log.add("info", "%s shrugs off Sleep" % t.name(), t.id, [test.describe()]))
			continue
		var fx := Effect.new("Drowsy (Sleep)", &"spell", "sleep").with_condition(&"incapacitated")
		fx.caster_id = c.id
		fx.ends_on_damage = true
		fx.repeat_save = {"ability": "wis", "dc": dc, "then": "sleep_unconscious", "when": "end"}
		fx.stack_key = "sleep:%s" % t.id
		fx.data = {"wakeable": true}
		conc.attach(t.creature, fx)
		r.lines.append(e.log.add("condition", "%s is Incapacitated by Sleep" % t.name(), t.id, [test.describe()]))


## Command (2024): one word; on a failed Wisdom save the target obeys on its next turn. Approach: moves toward you
## by the shortest route and ends its turn within 5 ft. Drop: drops what it holds and ends its turn. Flee: spends
## its turn moving away. Grovel: falls Prone and ends its turn. Halt: doesn't move or act.
func _command(ctx: Dictionary, t: Combatant, word: String, r: CombatResult) -> void:
	var c := ctx["c"] as Combatant
	var e := enc()
	if not word in COMMAND_WORDS:
		word = "grovel"
	var dc := (ctx["nums"]["dc"] as Breakdown).total()
	if t.creature.is_condition_immune(&"charmed"):
		r.lines.append(e.log.add("info", "%s can't be commanded (immune to Charmed)" % t.name(), t.id))
		return
	var test := t.creature.roll_save(e.dice, &"wis", dc, [], [], "Wisdom save vs Command (%s)" % t.name())
	if test.success:
		r.lines.append(e.log.add("info", "%s ignores the command" % t.name(), t.id, [test.describe()]))
		return
	var fx := Effect.new("Commanded: %s" % word.capitalize(), &"spell", "command").with_modifier("flag", {"value": "command_" + word})
	fx.caster_id = c.id
	fx.ends = Effect.Ends.END_OF_TURN
	fx.turn_owner_id = t.id
	fx.stack_key = "spell:command"
	t.creature.add_effect(fx)
	r.lines.append(e.log.add("condition", "%s obeys: %s" % [t.name(), word.capitalize()], t.id, [test.describe()]))


func _sanctuary(ctx: Dictionary, t: Combatant, r: CombatResult) -> void:
	var c := ctx["c"] as Combatant
	var fx := Effect.new("Sanctuary", &"spell", "sanctuary").lasting({"kind": "minutes", "amount": 1})
	fx.caster_id = c.id
	fx.turn_owner_id = c.id
	fx.repeat_save = {"ability": "wis", "dc": (ctx["nums"]["dc"] as Breakdown).total(), "when": "never"}
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


func _spare_the_dying(_ctx: Dictionary, t: Combatant, r: CombatResult) -> void:
	if t.creature.hp > 0 or t.creature.dead:
		r.lines.append(enc().log.add("info", "%s isn't dying" % t.name(), t.id))
		return
	t.creature.stabilize()
	r.lines.append(enc().log.add("heal", "%s is Stable" % t.name(), t.id))


## Misty Step: teleport to an unoccupied square you can see within 30 ft (no Opportunity Attacks).
func _teleport(c: Combatant, cell: Vector2i, r: CombatResult) -> void:
	var e := enc()
	var from := c.cell
	c.cell = cell
	e.events.append({"type": "teleport", "id": c.id, "from": from, "to": cell})
	r.lines.append(e.log.add("move", "%s teleports %d ft" % [c.name(), e.grid.distance_ft(from, c.size_cells, cell, c.size_cells)], c.id))
	zones.on_moved(c, from)


## Revivify: a creature that died within the last minute returns with 1 Hit Point.
func _revivify(ctx: Dictionary, t: Combatant, r: CombatResult) -> void:
	var e := enc()
	var died := int(t.get_meta("died_round", e.round_no)) if t.has_meta("died_round") else e.round_no
	if e.round_no - died > 10:
		r.lines.append(e.log.add("info", "%s has been dead too long for Revivify" % t.name(), t.id))
		return
	if t.creature.creature_type in [&"undead", &"construct"]:
		r.lines.append(e.log.add("info", "Revivify can't restore %s" % t.name(), t.id))
		return
	t.creature.dead = false
	t.creature.death_failures = 0
	t.creature.death_successes = 0
	t.creature.hp = 0
	t.creature.heal(1, str((ctx["s"] as Dictionary)["name"]))
	r.lines.append(e.log.add("heal", "%s returns to life with 1 Hit Point" % t.name(), t.id))
	e.events.append({"type": "heal", "id": t.id, "amount": 1})


## Arcane Vigor: spend up to two unspent Hit Point Dice (+1 per slot level above 2): roll them and heal the total
## plus your spellcasting ability modifier.
func _arcane_vigor(ctx: Dictionary, r: CombatResult) -> void:
	var c := ctx["c"] as Combatant
	var e := enc()
	if not c.creature is Character:
		return
	var ch := c.creature as Character
	var want := 2 + maxi(0, int(ctx["slot"]) - 2)
	var total := 0
	var rolls: Array[String] = []
	var hd := ch.hit_dice()
	var dice: Array = hd.keys()
	dice.sort_custom(func(a: Variant, b: Variant) -> bool: return int(a) > int(b))
	for die: Variant in dice:
		var entry := hd[die] as Dictionary
		var left := int(entry["total"]) - int(entry["spent"])
		while want > 0 and left > 0:
			ch.hit_dice_spent[str(die)] = int(ch.hit_dice_spent.get(str(die), 0)) + 1
			var v := e.dice.roll_one(int(die), "Arcane Vigor (d%s)" % die)
			total += v
			rolls.append("d%s: %d" % [die, v])
			left -= 1
			want -= 1
	if rolls.is_empty():
		r.lines.append(e.log.add("info", "%s has no Hit Point Dice left to spend" % c.name(), c.id))
		return
	var amount := total + int((ctx["nums"] as Dictionary)["mod"])
	var healed := c.creature.heal(amount, "Arcane Vigor")
	r.lines.append(e.log.add("heal", "%s spends %d Hit Point Dice and regains %d Hit Points" % [c.name(), rolls.size(), healed], c.id, rolls))
	e.events.append({"type": "heal", "id": c.id, "amount": healed})


## Dispel Magic: ends spells of the slot level or lower on the target (higher ones need a check, DC 10 + their
## level, with the spellcasting ability), including areas it is the caster of.
func _dispel(ctx: Dictionary, t: Combatant, r: CombatResult) -> void:
	var c := ctx["c"] as Combatant
	var e := enc()
	var slot := int(ctx["slot"])
	var ab := StringName(str((ctx["nums"] as Dictionary).get("ability", "int")))
	var ended: Array[String] = []
	for fx: Effect in t.creature.effects.duplicate():
		if fx.source_kind != &"spell":
			continue
		if fx.spell_level > slot:
			var test := c.creature.roll_check(e.dice, ab, 10 + fx.spell_level)
			if not test.success:
				continue
		t.creature.remove_effect(fx)
		if fx.concentration != null and fx.concentration.source_id == fx.source_id:
			fx.concentration.end("dispelled")
		ended.append(fx.name)
	if t.creature.concentration != null:
		var cid := t.creature.concentration.source_id
		var lvl := int(_comp().spell_data(cid).get("level", 1))
		if lvl <= slot:
			t.creature.concentration.end("dispelled")
			ended.append(_comp().spell_data(cid).get("name", cid))
	zones.prune()
	_prune_sustained()
	r.lines.append(e.log.add("spell", "Dispel Magic on %s: %s" % [t.name(), ", ".join(ended) if not ended.is_empty() else "nothing to end"], c.id))


## True Strike (2024): a weapon attack using the spellcasting ability for attack and damage, Radiant or the
## weapon's type, +1d6 Radiant at level 5 (2d6 at 11, 3d6 at 17).
func _true_strike(ctx: Dictionary, t: Combatant, r: CombatResult) -> void:
	var c := ctx["c"] as Combatant
	var e := enc()
	var best := {}
	for o in e.attack_options(c):
		if str(o["kind"]) == "weapon" and e.attack_legal(c, t, o) == "":
			best = o
			break
	if best.is_empty():
		r.lines.append(e.log.add("info", "True Strike: no weapon can reach %s" % t.name(), c.id))
		return
	var tier := Spellcasting.cantrip_tier(c.creature.character_level())
	var opt := best.duplicate()
	var p := (best["profile"] as WeaponProfile).with_ability(StringName(str((ctx["nums"] as Dictionary)["ability"])), c.creature)
	if str(ctx.get("choice", "")) == "radiant":
		p.damage_type = &"radiant"
	opt["profile"] = p
	var sub := e._resolve_attack(c, t, opt, {"extra_dice": [{"dice": "%dd6" % tier, "type": "radiant", "label": "True Strike"}] if tier > 0 else []})
	r.hit = sub.hit
	r.damage += sub.damage


# --- Spell objects, zones and sustained actions -----------------------------------------------------

## Rebuilds the casting context for something a spell left behind (an area's save DC and damage on later turns).
func context_for_object(o: FieldObject) -> Dictionary:
	var c := enc().get_c(o.caster_id)
	if c == null:
		return {}
	var s := _comp().spell_data(o.spell_id)
	var entry := _entry_any(c, o.spell_id) if c.creature is Character else {}
	var nums := numbers(c, entry) if c.creature is Character else {"dc": Breakdown.new("DC").add("DC", o.save_dc), "attack": Breakdown.new("Attack"), "mod": 0}
	return {"c": c, "s": s, "slot": o.slot, "nums": nums, "conc": o.concentration, "opts": {}, "choice": str(o.rules.get("choice", ""))}


## A lingering area (`zone` data) from the cast's cells.
func _place_zone(ctx: Dictionary, cells: Array[Vector2i], r: CombatResult) -> void:
	var c := ctx["c"] as Combatant
	var s := ctx["s"] as Dictionary
	var z := (s["zone"] as Dictionary).duplicate(true)
	var o := FieldObject.new(FieldObject.Kind.ZONE, str(s["id"]), str(s["name"]))
	o.caster_id = c.id
	o.slot = int(ctx["slot"])
	o.save_dc = (ctx["nums"]["dc"] as Breakdown).total()
	o.cells = cells
	o.cell = c.cell if cells.is_empty() else cells[0]
	# Call Lightning: the storm cloud spreads wider than the first bolt.
	if z.has("storm_radius") and (ctx["point"] as Vector2) != Vector2.INF:
		o.cells = enc().grid.area_cells("sphere", int(z["storm_radius"]), ctx["point"] as Vector2)
	o.origin = ctx["point"] as Vector2 if (ctx["point"] as Vector2) != Vector2.INF else enc().center_of(c)
	o.follows_caster = str((s.get("area", {}) as Dictionary).get("shape", "")) == "emanation" \
		and str((s.get("range", {}) as Dictionary).get("kind", "")) == "self"
	z["size"] = int((s.get("area", {}) as Dictionary).get("size", 5))
	if not z.has("damage") and s.has("damage") and bool(z.get("uses_spell_damage", true)):
		z["damage"] = s["damage"]
	if not z.has("save") and s.has("save"):
		z["save"] = s["save"]
	if not z.has("half") and str(s.get("save_success", "")) == "half":
		z["half"] = true
	if not z.has("effects") and s.has("effects") and not bool(z.get("resolve_on_cast", false)):
		z["effects"] = s["effects"]
	z["choice"] = str(ctx.get("choice", ""))
	if str(z.get("damage_type_choice", "")) != "" and z.has("damage"):
		var parts := (z["damage"] as Array).duplicate(true)
		for p: Variant in parts:
			if not (p as Dictionary).has("type"):
				(p as Dictionary)["type"] = _damage_type(ctx, p as Dictionary)
		z["damage"] = parts
	# Cordon of Arrows: pieces of ammunition, two more per slot level above the spell's.
	if z.has("charges"):
		z["charges"] = int(z["charges"]) + int(z.get("charges_per_slot", 0)) * maxi(0, int(ctx["slot"]) - int(s.get("level", 0)))
	# The squares of what the area spreads from (Conjure Animals' pack).
	var area_d := s.get("area", {}) as Dictionary
	if int(area_d.get("origin_size", 1)) > 1 and (ctx["point"] as Vector2) != Vector2.INF:
		var osz := int(area_d["origin_size"])
		var pt := ctx["point"] as Vector2
		var oc := Vector2i(floori(pt.x - osz / 2.0 + 0.5), floori(pt.y - osz / 2.0 + 0.5))
		z["core_cells"] = CombatGrid.footprint(oc, osz).map(func(x: Vector2i) -> Array: return [x.x, x.y])
		o.cell = oc
	# Wall of Fire: the side that burns, 10 ft deep along the wall (the side `direction` points to).
	if z.has("side_ft") and str(area_d.get("shape", "")) == "wall":
		z["side_cells"] = _wall_side(ctx, cells, int(z["side_ft"]))
	o.rules = z
	if bool(z.get("spare_allies", false)):
		for a in enc().allies_of(c):
			o.spared.append(a.id)
		o.spared.append(c.id)
	var d := s.get("duration", {}) as Dictionary
	o.keep_with(ctx["conc"] as Concentration)
	if ctx["conc"] == null:
		o.rounds_left = int(d.get("amount", 1)) * (10 if str(d.get("kind", "")) == "minutes" else (600 if str(d.get("kind", "")) == "hours" else 1))
	# Lasts until the end of the caster's next turn (Ice Storm's hail): counted down at the end of the caster's turns.
	if z.has("caster_turn_ends"):
		o.rounds_left = -1
	if z.has("rounds") and ctx["conc"] == null:
		o.rounds_left = int(z["rounds"])
	_light_vs_darkness(o, int(ctx["slot"]))
	zones.add(o, r)
	r.lines.append(enc().log.add("spell", "%s fills %d squares" % [s["name"], cells.size()], c.id))


## Squares within `feet` of a wall on one side of it: the side the cast's direction's left-hand normal points to.
func _wall_side(ctx: Dictionary, wall: Array[Vector2i], feet: int) -> Array:
	var e := enc()
	var dir := (ctx["direction"] as Vector2) if ctx.has("direction") and (ctx["direction"] as Vector2).length() > 0.01 else Vector2.RIGHT
	dir = dir.normalized()
	var normal := Vector2(-dir.y, dir.x)
	var origin := ctx["point"] as Vector2
	var out: Array = []
	var depth := feet / float(CombatGrid.FEET)
	for cell in wall:
		for step in range(1, int(depth) + 1):
			var p := Vector2(cell) + Vector2(0.5, 0.5) + normal * step
			var sc := Vector2i(floori(p.x), floori(p.y))
			if e.grid.in_bounds(sc) and not sc in wall and not [sc.x, sc.y] in out and (p - origin).dot(normal) > 0:
				out.append([sc.x, sc.y])
	return out


## Darkness dispels light from spells of level 2 or lower that it overlaps; Daylight dispels Darkness of level 3
## or lower.
func _light_vs_darkness(o: FieldObject, slot: int) -> void:
	if bool(o.rule("darkness", false)):
		for other in zones.live():
			if other.rules.has("light") and int(_comp().spell_data(other.spell_id).get("level", 0)) <= 2:
				for cell in o.cells:
					if str(zones.spell_light(cell)["level"]) != "":
						other.ended = true
						enc().log.add("info", "%s snuffs out %s" % [o.name, other.name], o.caster_id)
						break
	var up_to := int(o.rule("dispels_darkness", 0))
	if up_to > 0:
		for other in zones.live():
			if bool(other.rule("darkness", false)) and other.slot <= maxi(up_to, slot):
				for cell in other.cells:
					if cell in o.cells or o.cells.is_empty():
						other.ended = true
						enc().log.add("info", "%s dispels %s" % [o.name, other.name], o.caster_id)
						break
	zones.prune()


## Spiritual Weapon, Flaming Sphere, Dancing Lights, Mage Hand: an object on a square, kept by Concentration (or
## its duration), with the actions it grants. Spiritual Weapon attacks a creature within 5 ft when it appears.
func _place_object(ctx: Dictionary, tgt: Array[Combatant], r: CombatResult) -> void:
	var c := ctx["c"] as Combatant
	var s := ctx["s"] as Dictionary
	var od := s["object"] as Dictionary
	var kinds := {"weapon": FieldObject.Kind.WEAPON, "sphere": FieldObject.Kind.SPHERE, "lights": FieldObject.Kind.LIGHTS, "hand": FieldObject.Kind.HAND,
		"hound": FieldObject.Kind.HOUND, "vine": FieldObject.Kind.VINE}
	var o := FieldObject.new(kinds.get(str(od.get("kind", "weapon")), FieldObject.Kind.WEAPON), str(s["id"]), str(s["name"]))
	o.caster_id = c.id
	o.slot = int(ctx["slot"])
	o.save_dc = (ctx["nums"]["dc"] as Breakdown).total()
	o.cell = ctx["cell"] as Vector2i
	o.cells = [o.cell]
	o.rules = (od.get("rules", {}) as Dictionary).duplicate(true)
	if s.has("damage") and not o.rules.has("damage") and o.rules.has("save"):
		o.rules["damage"] = s["damage"]
	o.keep_with(ctx["conc"] as Concentration)
	if ctx["conc"] == null:
		o.rounds_left = _duration_rounds(s.get("duration", {}) as Dictionary)
	zones.add(o, r)
	enc().events.append({"type": "summon", "caster": c.id, "cell": o.cell})
	r.lines.append(enc().log.add("spell", "%s appears" % s["name"], c.id))
	if s.has("sustain"):
		_grant_sustained(ctx, tgt)
	if str(od.get("on_appear", "")) == "attack":
		# It strikes a creature within its reach as it appears (Spiritual Weapon 5 ft; Grasping Vine 30 ft): the one
		# chosen, else the nearest enemy.
		var reach := int(od.get("reach", 5))
		var near: Combatant = null
		for t in tgt:
			if enc().grid.distance_ft(o.cell, 1, t.cell, t.size_cells) <= reach:
				near = t
		if near == null and tgt.is_empty():
			var best := 1 << 30
			for h in enc().hostiles_of(c):
				var dh := enc().grid.distance_ft(o.cell, 1, h.cell, h.size_cells)
				if not h.is_down() and dh <= reach and dh < best:
					best = dh
					near = h
		if near != null and near.is_alive():
			ctx["pull_origin"] = Vector2(o.cell) + Vector2(0.5, 0.5)
			spell_attack(ctx, near, r)


## How many rounds a duration lasts (1 minute = 10 rounds).
static func _duration_rounds(d: Dictionary) -> int:
	match str(d.get("kind", "")):
		"rounds":
			return int(d.get("amount", 1))
		"minutes":
			return int(d.get("amount", 1)) * 10
		"hours":
			return int(d.get("amount", 1)) * 600
		"days":
			return int(d.get("amount", 1)) * 14400
	return 10


func weapon_of(c: Combatant) -> FieldObject:
	return zones.object_of(c.id, "spiritual_weapon")


func has_spiritual_weapon(c: Combatant) -> bool:
	return weapon_of(c) != null


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


## The Bonus Action follow-up: move the weapon up to 20 ft to `cell`, then attack a creature within 5 ft of it.
func spiritual_weapon_attack(c: Combatant, target: Combatant, cell: Vector2i) -> CombatResult:
	var a := sustained_for(c, "spiritual_weapon")
	if a.is_empty():
		return CombatResult.fail("No Spiritual Weapon")
	return use_sustained(c, str(a["id"]), [target] if target != null else [], Vector2(cell.x + 0.5, cell.y + 0.5))


func _entry_any(c: Combatant, spell_id: String) -> Dictionary:
	if not c.creature is Character:
		return {}
	for k in (c.creature as Character).known_spells():
		if str(k["id"]) == spell_id:
			return k
	return {}


## Registers the spell's `sustain` actions: what the caster (or, for Dragon's Breath, the target) can keep doing
## while the spell lasts.
func _grant_sustained(ctx: Dictionary, tgt: Array[Combatant]) -> void:
	var c := ctx["c"] as Combatant
	var s := ctx["s"] as Dictionary
	var conc := ctx["conc"] as Concentration
	for raw: Variant in s.get("sustain", []):
		var d := (raw as Dictionary).duplicate(true)
		var owner := c
		if str(d.get("owner", "caster")) == "target" and not tgt.is_empty():
			owner = tgt[0]
		var a := {"id": "%s:%s:%d" % [s["id"], d.get("do", "act"), sustained.size() + randi() % 1000], "spell_id": str(s["id"]),
			"label": str(d.get("label", s["name"])), "owner_id": owner.id, "caster_id": c.id, "cost": str(d.get("cost", "bonus_action")),
			"do": str(d.get("do", "attack")), "slot": int(ctx["slot"]), "target_id": tgt[0].id if not tgt.is_empty() else "",
			"conc": weakref(conc) if conc != null else null, "def": d, "choice": str(ctx.get("choice", "")),
			"rounds_left": -1 if conc != null else 10 * int((s.get("duration", {}) as Dictionary).get("amount", 1)),
			"used_round": -1 if not bool(d.get("not_this_turn", true)) else enc().round_no, "used_turn": enc().turn_index,
			"maintained_round": enc().round_no}
		sustained.append(a)


func _prune_sustained() -> void:
	var keep: Array[Dictionary] = []
	for a in sustained:
		var conc := (a["conc"] as WeakRef).get_ref() as Concentration if a["conc"] != null else null
		if a["conc"] != null and (conc == null or conc.ended):
			continue
		if int(a["rounds_left"]) == 0:
			continue
		if enc().get_c(str(a["owner_id"])) == null or not enc().get_c(str(a["owner_id"])).is_alive():
			continue
		keep.append(a)
	sustained = keep


func sustained_for(c: Combatant, spell_id: String = "") -> Dictionary:
	for a in sustained_actions(c):
		if spell_id == "" or str(a["spell_id"]) == spell_id:
			return a
	return {}


## The sustained actions `c` has now, each with {legal, reason}.
func sustained_actions(c: Combatant) -> Array[Dictionary]:
	_prune_sustained()
	var out: Array[Dictionary] = []
	for a in sustained:
		if str(a["owner_id"]) != c.id:
			continue
		var entry := a.duplicate()
		var why := enc()._turn_check(c)
		if why == "" and not c.can_act():
			why = "%s can't act" % c.name()
		if why == "":
			why = economy_block(c, "action" if str(a["cost"]) in ["action", "magic"] else str(a["cost"]))
		if why == "" and int(a["used_round"]) == enc().round_no and int(a["used_turn"]) == enc().turn_index:
			why = "Not on the turn you cast it"
		if why == "" and bool((a["def"] as Dictionary).get("once_per_turn", false)) and str(a.get("last_turn", "")) == "%d:%d" % [enc().round_no, enc().turn_index]:
			why = "Already used this turn"
		entry["legal"] = why == ""
		entry["reason"] = why
		out.append(entry)
	return out


## Uses a sustained action: Witch Bolt's arc, Spiritual Weapon's strike, Flaming Sphere's roll, Cloud of Daggers'
## move, Produce Flame's hurl, Vampiric Touch's touch, Dragon's Breath's exhale, Expeditious Retreat's Dash,
## Aura of Vitality's healing, Gust of Wind's new direction, Crown of Madness's upkeep.
func use_sustained(c: Combatant, action_id: String, targets: Array = [], point: Vector2 = Vector2.INF,
		direction: Vector2 = Vector2.ZERO) -> CombatResult:
	var a := {}
	for x in sustained_actions(c):
		if str(x["id"]) == action_id:
			a = x
	if a.is_empty():
		return CombatResult.fail("That spell has ended")
	if not bool(a["legal"]):
		return CombatResult.fail(str(a["reason"]))
	var e := enc()
	var caster := e.get_c(str(a["caster_id"]))
	var s := _comp().spell_data(str(a["spell_id"]))
	var d := a["def"] as Dictionary
	var entry := _entry_any(caster, str(a["spell_id"])) if caster != null else {}
	var conc := (a["conc"] as WeakRef).get_ref() as Concentration if a["conc"] != null else null
	var ctx := {"c": c, "s": s, "slot": int(a["slot"]), "nums": numbers(caster, entry) if caster != null else {}, "conc": conc,
		"opts": {}, "choice": str(a["choice"]), "point": point}
	var t: Combatant = targets[0] as Combatant if not targets.is_empty() else null
	var r := CombatResult.new()
	var cost := str(a["cost"])
	# Validate before paying.
	var why := _sustained_check(c, a, d, t, point)
	if why != "":
		return CombatResult.fail(why)
	if cost == "bonus_action":
		c.bonus_available = false
	elif cost in ["action", "magic"]:
		e.spend_action(c)
		if cost == "magic":
			c.magic_action_used = true
	for x in sustained:
		if str(x["id"]) == action_id:
			x["maintained_round"] = e.round_no
			x["last_turn"] = "%d:%d" % [e.round_no, e.turn_index]
	match str(a["do"]):
		"attack":
			var obj := zones.object_of(str(a["caster_id"]), str(a["spell_id"]))
			if obj != null and point != Vector2.INF:
				var cell := Vector2i(floori(point.x), floori(point.y))
				obj.cell = cell
				obj.cells = [cell]
				zones.moved_object(obj, r)
				e.events.append({"type": "summon", "caster": str(a["caster_id"]), "cell": cell})
			if t != null:
				e.log.add("spell", "%s: %s" % [c.name(), a["label"]], c.id)
				if obj != null:
					ctx["pull_origin"] = Vector2(obj.cell) + Vector2(0.5, 0.5)
				var sub_s := s.duplicate()
				if d.has("attack"):
					sub_s["attack"] = d["attack"]
				if d.has("damage"):
					sub_s["damage"] = d["damage"]
				sub_s.erase("secondary")
				var sub := ctx.duplicate()
				sub["s"] = sub_s
				spell_attack(sub, t, r)
		"damage":
			var tt := e.get_c(str(a["target_id"]))
			if tt == null or not tt.is_alive():
				return CombatResult.fail("The target is gone")
			if str(a["spell_id"]) == "heat_metal":
				e.log.add("spell", "%s: %s" % [c.name(), a["label"]], c.id)
				specials.heat_metal(ctx, tt, r)
				zones.prune()
				e._check_over()
				return e.then(r, func() -> CombatResult: return e.run_reaction_queue(r))
			var rolled := roll_damage_parts(ctx, d.get("damage", []) as Array, false, tt)
			e.log.add("spell", "%s: %s" % [c.name(), a["label"]], c.id)
			var dr := e.deal_damage(c, tt, [{"amount": int(rolled["total"]), "type": str(rolled["type"]), "spell": true}], false, str(s["name"]), [str(rolled["text"])])
			r.damage = dr.final
		"area":
			var sub_s2 := s.duplicate()
			for k: String in ["area", "save", "save_success", "damage"]:
				if d.has(k):
					sub_s2[k] = d[k]
			if not bool(d.get("at_point", false)):
				sub_s2["range"] = {"kind": "self"}
			sub_s2.erase("sustain")
			sub_s2.erase("effects")
			sub_s2.erase("zone")
			var sub2 := ctx.duplicate()
			sub2["s"] = sub_s2
			var cells := area_for(c, sub_s2, point, direction, int(a["slot"]))
			e.events.append({"type": "spell", "caster": c.id, "spell": str(s["id"]), "cells": cells, "targets": []})
			e.log.add("spell", "%s: %s" % [c.name(), a["label"]], c.id)
			_save_spell(sub2, _area_victims(c, sub_s2, cells), r)
		"move_object":
			var obj2 := zones.object_of(str(a["caster_id"]), str(a["spell_id"]))
			if obj2 == null:
				return CombatResult.fail("Nothing to move")
			var to := Vector2i(floori(point.x), floori(point.y))
			if obj2.kind == FieldObject.Kind.ZONE:
				var dv := Vector2(to - obj2.cell)
				var moved: Array[Vector2i] = []
				for cl in obj2.cells:
					moved.append(cl + Vector2i(dv))
				obj2.cells = moved
				obj2.cell = to
				if obj2.rules.has("core_cells"):
					obj2.rules["core_cells"] = (obj2.rules["core_cells"] as Array).map(func(x: Variant) -> Array:
						return [int((x as Array)[0]) + int(dv.x), int((x as Array)[1]) + int(dv.y)])
			else:
				obj2.cell = to
				obj2.cells = [to]
			e.log.add("spell", "%s: %s" % [c.name(), a["label"]], c.id)
			zones.moved_object(obj2, r)
			if obj2.kind == FieldObject.Kind.SPHERE:
				var hitc := e.occupant_at(to)
				if hitc == null:
					for n in e.living():
						if e.grid.distance_ft(to, 1, n.cell, n.size_cells) <= 0:
							hitc = n
				if hitc != null:
					var o2ctx := context_for_object(obj2)
					var victims: Array[Combatant] = [hitc]
					var sub3 := o2ctx.duplicate()
					var s3 := (o2ctx["s"] as Dictionary).duplicate()
					s3["save"] = obj2.rules.get("save", "dex")
					s3["save_success"] = "half"
					s3["damage"] = obj2.rules.get("damage", s.get("damage", []))
					s3.erase("effects")
					sub3["s"] = s3
					_save_spell(sub3, victims, r)
		"dash":
			c.movement_left += c.speed()
			e.log.add("info", "%s Dashes (+%d ft, %s)" % [c.name(), c.speed(), s["name"]], c.id)
		"disengage":
			c.disengaged = true
			e.log.add("info", "%s Disengages (%s)" % [c.name(), s["name"]], c.id)
		"compel":
			var dirv := direction if direction.length() > 0.01 else ((point - e.center_of(c)) if point != Vector2.INF else Vector2.ZERO)
			if dirv.length() < 0.01:
				return CombatResult.fail("Choose a direction")
			c.set_meta("compel_dir", [dirv.normalized().x, dirv.normalized().y])
			e.log.add("spell", "%s names a direction: the charmed must go that way (%s)" % [c.name(), s["name"]], c.id)
		"heal_one":
			if t == null:
				t = c
			var rolled2 := e._roll_damage_dice(str((d.get("heal", {}) as Dictionary).get("dice", "2d6")), false, 0, str(s["name"]))
			var amt := int(rolled2["total"])
			if t.creature.has_flag("max_healing_received"):
				var pp := DiceRoller.parse_expr(str((d.get("heal", {}) as Dictionary).get("dice", "2d6")))
				amt = int(pp["count"]) * int(pp["sides"])
			var healed := t.creature.heal(amt, str(s["name"]))
			e.log.add("heal", "%s: %s regains %d Hit Points" % [s["name"], t.name(), healed], c.id, [str(rolled2["text"])])
			e.events.append({"type": "heal", "id": t.id, "amount": healed})
		"aim":
			var zone := zones.object_of(str(a["caster_id"]), str(a["spell_id"]))
			if zone != null and direction.length() > 0.01:
				zone.cells = area_for(c, s, Vector2.INF, direction, int(a["slot"]))
				zones.moved_object(zone, r)
			e.log.add("spell", "%s turns %s" % [c.name(), s["name"]], c.id)
		"move_mark":
			if t == null:
				return CombatResult.fail("Choose a new target")
			for fx: Effect in c.creature.effects:
				if fx.source_id == str(a["spell_id"]):
					for m in fx.modifiers:
						if m.data.has("vs"):
							m.data["vs"] = t.id
			for x in sustained:
				if str(x["id"]) == str(a["id"]):
					x["target_id"] = t.id
			e.log.add("spell", "%s moves %s to %s" % [c.name(), s["name"], t.name()], c.id)
		"maintain":
			e.log.add("spell", "%s keeps %s going" % [c.name(), s["name"]], c.id)
			var victim := e.get_c(str(a["target_id"]))
			if victim != null:
				victim.set_meta("crown_target", str(d.get("victim_of", "")))
	zones.prune()
	e._check_over()
	return e.then(r, func() -> CombatResult: return e.run_reaction_queue(r))


func _sustained_check(c: Combatant, a: Dictionary, d: Dictionary, t: Combatant, point: Vector2) -> String:
	var e := enc()
	var reach := int(d.get("reach", 5))
	match str(a["do"]):
		"attack":
			if t == null:
				return "Choose a target"
			var obj := zones.object_of(str(a["caster_id"]), str(a["spell_id"]))
			if obj != null:
				var to := obj.cell if point == Vector2.INF else Vector2i(floori(point.x), floori(point.y))
				if e.grid.distance_ft(obj.cell, 1, to, 1) > int(d.get("move", 0)):
					return "It moves at most %d ft" % int(d.get("move", 0))
				if e.grid.distance_ft(to, 1, t.cell, t.size_cells) > reach:
					return "Target must be within %d ft of it" % reach
			else:
				var rng := int(d.get("range", 5))
				if e.distance(c, t) > rng:
					return "Out of range (%d ft)" % rng
			if int(e.cover(c, t)["cover"]) == CombatGrid.Cover.TOTAL and obj == null:
				return "No line of effect"
			var sb := sanctuary_blocks(c, t)
			if sb != "":
				return sb
		"damage":
			var tt := e.get_c(str(a["target_id"]))
			if tt == null or not tt.is_alive():
				return "The target is gone"
			if e.distance(c, tt) > int(d.get("range", 60)):
				return "The target is out of range"
			if int(e.cover(c, tt)["cover"]) == CombatGrid.Cover.TOTAL:
				return "The target has Total Cover"
		"move_object":
			var obj2 := zones.object_of(str(a["caster_id"]), str(a["spell_id"]))
			if obj2 == null:
				return "Nothing to move"
			if point == Vector2.INF:
				return "Choose a square"
			var to2 := Vector2i(floori(point.x), floori(point.y))
			if not e.grid.in_bounds(to2) or e.grid.is_solid(to2):
				return "Can't go there"
			if e.grid.distance_ft(obj2.cell, 1, to2, 1) > int(d.get("move", 30)):
				return "It moves at most %d ft" % int(d.get("move", 30))
		"heal_one":
			if t != null and e.distance(c, t) > int(d.get("range", 30)):
				return "Out of the aura"
		"area":
			if bool(d.get("at_point", false)):
				if point == Vector2.INF:
					return "Choose a point"
				var storm := zones.object_of(str(a["caster_id"]), str(a["spell_id"]))
				var within := int(d.get("within_object", 0))
				if storm != null and within > 0 and (point - storm.origin).length() * CombatGrid.FEET > within + 0.01:
					return "The point must be under the storm (%d ft)" % within
		"move_mark":
			var old := e.get_c(str(a["target_id"]))
			if old != null and old.is_alive() and old.creature.hp > 0:
				return "The marked creature is still up"
			if t == null or e.distance(c, t) > int(d.get("range", 90)):
				return "Choose a creature within %d ft" % int(d.get("range", 90))
	return ""


## Sustained spells that end on their own (Witch Bolt when its target is out of range or behind Total Cover) and
## upkeep that lapses (Crown of Madness without its Magic action), checked at the end of the caster's turn.
func _sustained_turn_end(c: Combatant) -> void:
	var e := enc()
	for a: Dictionary in sustained.duplicate():
		if str(a["caster_id"]) != c.id:
			continue
		var d := a["def"] as Dictionary
		if str(a["do"]) == "damage":
			var tt := e.get_c(str(a["target_id"]))
			if tt == null or not tt.is_alive() or e.distance(c, tt) > int(d.get("range", 60)) or int(e.cover(c, tt)["cover"]) == CombatGrid.Cover.TOTAL:
				_end_spell_of(c, str(a["spell_id"]), "the target got away")
		if bool(d.get("upkeep", false)) and int(a["maintained_round"]) != e.round_no:
			_end_spell_of(c, str(a["spell_id"]), "no Magic action to keep it")
		if int(a["rounds_left"]) > 0:
			a["rounds_left"] = int(a["rounds_left"]) - 1
	_prune_sustained()


func _end_spell_of(c: Combatant, spell_id: String, why: String) -> void:
	if c.creature.concentration != null and c.creature.concentration.source_id == spell_id:
		c.creature.concentration.end(why)
		enc().log.add("info", "%s ends (%s)" % [_comp().spell_data(spell_id).get("name", spell_id), why], c.id)
	zones.prune()
	_prune_sustained()


# --- Summons --------------------------------------------------------------------------------------

## Summon Fey / Summon Undead (a spirit whose numbers grow with the slot level, on your side, acting right after
## you), Find Familiar and Animate Dead (cast before the fight). The player controls them; they vanish when the
## spell ends or at 0 Hit Points.
func _summon(ctx: Dictionary, cell: Vector2i, r: CombatResult) -> void:
	var c := ctx["c"] as Combatant
	var s := ctx["s"] as Dictionary
	var e := enc()
	var block := SummonBlocks.for_spell(str(s["id"]), int(ctx["slot"]), str(ctx.get("choice", "")), ctx["nums"] as Dictionary)
	if block.is_empty():
		return
	var m := Monster.from_data(block, e.dice)
	m.name = str(block["name"])
	# A new Otherworldly Steed replaces the old one.
	if bool(block.get("steed", false)):
		for old_id: Variant in summoned.get(c.id, []):
			var old := e.get_c(str(old_id))
			if old != null and old.is_alive() and old.creature is Monster and bool((old.creature as Monster).data.get("steed", false)):
				_dismiss(old.id)
	var size := CombatGrid.size_cells_for(m.size)
	if cell.x < 0 or not _room_for(cell, size):
		cell = _free_cell_near(c.cell, size)
	var sc := e.add(m, &"guest" if c.side == &"party" else c.side, cell)
	sc.controller = c.controller
	sc.set_meta("summoner", c.id)
	sc.set_meta("vanishes", true)
	if not summoned.has(c.id):
		summoned[c.id] = []
	(summoned[c.id] as Array).append(sc.id)
	var conc := ctx["conc"] as Concentration
	if conc != null:
		var marker := Effect.new(str(s["name"]), &"spell", str(s["id"]))
		marker.modifiers.append(Modifier.of("flag", {"value": "summoned"}, str(s["name"]), &"spell"))
		conc.attach(m, marker)
		var sid := sc.id
		marker.data["on_end"] = {"kind": "dismiss", "target": sid}
		marker.on_end = func() -> void: _dismiss(sid)
	if e.state == Encounter.State.ACTIVE:
		e.insert_after(c, sc)
	e.events.append({"type": "summon_creature", "id": sc.id, "cell": cell, "caster": c.id})
	r.lines.append(e.log.add("spell", "%s appears beside %s" % [m.name, c.name()], c.id))


func _revert_shape(creature_id: String, why: String) -> void:
	var e := enc()
	if e == null:
		return
	var c := e.get_c(creature_id)
	if c != null:
		e.shapes.revert(c, why)


func _dismiss(creature_id: String) -> void:
	var e := enc()
	if e == null:
		return
	var sc := e.get_c(creature_id)
	if sc == null or sc.creature.dead:
		return
	sc.creature.dead = true
	e.log.add("info", "%s vanishes" % sc.name(), sc.id)
	e.events.append({"type": "vanish", "id": sc.id})


func _free_cell_near(cell: Vector2i, size: int = 1) -> Vector2i:
	for radius in range(1, 8):
		for dx in range(-radius, radius + 1):
			for dy in range(-radius, radius + 1):
				var c2 := cell + Vector2i(dx, dy)
				if _room_for(c2, size):
					return c2
	return cell


## Whether a creature `size` squares across fits with its corner at `cell`.
func _room_for(cell: Vector2i, size: int) -> bool:
	var e := enc()
	for f in CombatGrid.footprint(cell, size):
		if not e.grid.in_bounds(f) or e.grid.is_solid(f) or e.occupant_at(f) != null:
			return false
	return true


## After a fight is loaded from a save: effects that do something when they end get their hook back (Haste's
## lethargy, Melf's Acid Arrow's later damage, Enlarge/Reduce, a summoned creature vanishing).
func rehook_effects() -> void:
	var e := enc()
	for c in e.combatants:
		for fx: Effect in c.creature.effects:
			var oe := fx.data.get("on_end", {}) as Dictionary
			match str(oe.get("kind", "")):
				"lethargy":
					var tl := e.get_c(str(oe["target"]))
					if tl != null:
						_haste_lethargy(tl, fx)
				"dismiss":
					var sid := str(oe["target"])
					fx.on_end = func() -> void: _dismiss(sid)
				"unbanish":
					var ubid := str(oe["target"])
					var ub_round := int(oe.get("round", 0))
					fx.on_end = func() -> void: specials.unbanish(ubid, ub_round)
				"undominate":
					var udid := str(oe["target"])
					fx.on_end = func() -> void: specials.undominate(udid)
				"revert_shape":
					var shid := str(oe["target"])
					fx.on_end = func() -> void: _revert_shape(shid, str(oe.get("why", "the spell ended")))
				"resize":
					var tr := e.get_c(str(oe["target"]))
					var old := StringName(str(oe["size"]))
					if tr != null:
						var weak: WeakRef = weakref(tr)
						fx.on_end = func() -> void:
							var tt := weak.get_ref() as Combatant
							if tt != null:
								tt.creature.size = old
								tt.size_cells = CombatGrid.size_cells_for(old)
				"delayed_damage":
					var td := e.get_c(str(oe["target"]))
					var caster := e.get_c(str(oe["caster"]))
					if td != null and caster != null:
						var ctx := {"c": caster, "s": _comp().spell_data(str(oe["spell"])), "slot": int(oe["slot"]), "nums": {}, "opts": {}}
						var part := oe["part"] as Dictionary
						var weak_t: WeakRef = weakref(td)
						fx.on_end = func() -> void:
							var tt2 := weak_t.get_ref() as Combatant
							if tt2 == null or not tt2.is_alive():
								return
							var rolled := roll_damage_parts(ctx, [part], false, tt2)
							e.deal_damage(e.get_c(caster.id), tt2, [{"amount": int(rolled["total"]), "type": str(rolled["type"]), "spell": true}], false, str(ctx["s"].get("name", "")), [str(rolled["text"])])


## The spell state a save keeps: lingering areas and objects, sustained actions, summons.
func to_dict() -> Dictionary:
	var objs: Array = []
	for o in zones.live():
		var conc := o.concentration
		objs.append({"kind": int(o.kind), "spell": o.spell_id, "name": o.name, "caster": o.caster_id, "cell": [o.cell.x, o.cell.y],
			"cells": o.cells.map(func(x: Vector2i) -> Array: return [x.x, x.y]), "follows": o.follows_caster, "slot": o.slot,
			"dc": o.save_dc, "rules": o.rules.duplicate(true), "spared": o.spared.duplicate(), "rounds": o.rounds_left,
			"conc": conc.source_id if conc != null else ""})
	var sus: Array = []
	for a in sustained:
		var d := a.duplicate(true)
		var cc := (a["conc"] as WeakRef).get_ref() as Concentration if a["conc"] != null else null
		d["conc"] = cc.source_id if cc != null else ""
		sus.append(d)
	return {"objects": objs, "sustained": sus, "summoned": summoned.duplicate(true)}


func from_dict(d: Dictionary) -> void:
	var e := enc()
	for od: Variant in d.get("objects", []):
		var x := od as Dictionary
		var o := FieldObject.new(int(x["kind"]) as FieldObject.Kind, str(x["spell"]), str(x["name"]))
		o.caster_id = str(x["caster"])
		o.cell = Vector2i(int((x["cell"] as Array)[0]), int((x["cell"] as Array)[1]))
		for cl: Variant in x.get("cells", []):
			o.cells.append(Vector2i(int((cl as Array)[0]), int((cl as Array)[1])))
		o.follows_caster = bool(x.get("follows", false))
		o.slot = int(x.get("slot", 0))
		o.save_dc = int(x.get("dc", 10))
		o.rules = (x.get("rules", {}) as Dictionary).duplicate(true)
		for sp: Variant in x.get("spared", []):
			o.spared.append(str(sp))
		o.rounds_left = int(x.get("rounds", -1))
		var caster := e.get_c(o.caster_id)
		if str(x.get("conc", "")) != "" and caster != null and caster.creature.concentration != null:
			o.keep_with(caster.creature.concentration)
		zones.objects.append(o)
	for ad: Variant in d.get("sustained", []):
		var a := (ad as Dictionary).duplicate(true)
		var caster2 := e.get_c(str(a["caster_id"]))
		a["conc"] = weakref(caster2.creature.concentration) if str(a.get("conc", "")) != "" and caster2 != null and caster2.creature.concentration != null else null
		sustained.append(a)
	summoned = (d.get("summoned", {}) as Dictionary).duplicate(true)
	rehook_effects()
	zones.refresh_auras()


# --- Turn hooks -----------------------------------------------------------------------------------

func turn_start(c: Combatant) -> void:
	var e := enc()
	zones.turn_start(c)
	_prune_sustained()
	_turn_start_effects(c)
	_repeat_saves(c, "start")
	specials.turn_start(c)
	# Bestow Curse (Dodge): a Wisdom save at the start of its turn or it must take the Dodge action.
	if c.creature.has_flag("cursed_dodge") and c.can_act():
		for fx: Effect in c.creature.effects:
			if fx.source_id == "bestow_curse":
				var caster := e.get_c(fx.caster_id)
				var dc := (numbers(caster, _entry_any(caster, "bestow_curse"))["dc"] as Breakdown).total() if caster != null and caster.creature is Character else 13
				var sv := c.creature.roll_save(e.dice, &"wis", dc, [], [], "Wisdom save vs Bestow Curse (%s)" % c.name())
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
		if fx.data.has("turn_temp_hp") and c.creature.hp > 0:
			var amount := int(fx.data["turn_temp_hp"])
			if amount > 0 and c.creature.add_temp_hp(amount, fx.name):
				e.log.add("heal", "%s gains %d Temporary Hit Points (%s)" % [c.name(), amount, fx.name], c.id)


func turn_end(c: Combatant) -> void:
	var e := enc()
	zones.turn_end(c)
	specials.turn_end(c)
	_repeat_saves(c, "end")
	_sustained_turn_end(c)
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


## Kept for callers of the old name: the end-of-turn repeated saves.
func end_of_turn_saves(c: Combatant) -> void:
	_repeat_saves(c, "end")


## Effects with a repeated save at the start or end of the creature's turn (Hold Person, Slow, Fear, Sleep's
## drowsiness, Tasha's Hideous Laughter).
func _repeat_saves(c: Combatant, when: String) -> void:
	var e := enc()
	for fx: Effect in c.creature.effects.duplicate():
		if fx.repeat_save.is_empty() or str(fx.repeat_save.get("when", "end")) != when:
			continue
		if not fx in c.creature.effects:
			continue
		if str(fx.repeat_save.get("if", "")) == "no_sight_of_caster":
			var caster := e.get_c(fx.caster_id)
			if caster != null and e.can_see(c, caster):
				continue
		_repeat_save(c, fx, [])


func _repeat_save(c: Combatant, fx: Effect, adv: Array[String]) -> void:
	var e := enc()
	var ab := StringName(str(fx.repeat_save.get("ability", "wis")))
	var dc := int(fx.repeat_save.get("dc", 10))
	var test := c.creature.roll_save(e.dice, ab, dc, adv, [], "%s save to end %s (%s)" % [Creature.ABILITY_NAMES[ab], fx.name, c.name()])
	var then_kind := str(fx.repeat_save.get("then", ""))
	if test.success:
		c.creature.remove_effect(fx)
		e.log.add("info", "%s shakes off %s" % [c.name(), fx.name], c.id, [test.describe()])
		e.events.append({"type": "condition", "id": c.id})
	elif then_kind == "sleep_unconscious":
		c.creature.remove_effect(fx)
		var deep := Effect.new("Sleep", &"spell", "sleep").with_condition(&"unconscious")
		deep.caster_id = fx.caster_id
		deep.ends_on_damage = true
		deep.stack_key = fx.stack_key
		deep.data = {"wakeable": true}
		if fx.concentration != null:
			fx.concentration.attach(c.creature, deep)
		else:
			c.creature.add_effect(deep)
		e.log.add("condition", "%s falls Unconscious (Sleep)" % c.name(), c.id, [test.describe()])
		e.events.append({"type": "condition", "id": c.id})
	else:
		e.log.add("info", "%s is still affected by %s" % [c.name(), fx.name], c.id, [test.describe()])
		var fd := fx.repeat_save.get("fail_damage", {}) as Dictionary
		if not fd.is_empty():
			var rolled := e._roll_damage_dice(str(fd["dice"]), false, 0, fx.name)
			e.deal_damage(e.get_c(fx.caster_id), c, [{"amount": int(rolled["total"]), "type": str(fd["type"]), "spell": true}], false, fx.name, [str(rolled["text"])])


## After `target` took damage: effects that end when the caster's side hurts it (Charm Person), repeated saves on
## damage (Tasha's Hideous Laughter, with Advantage), Warding Bond's shared damage.
func on_damaged(source: Combatant, target: Combatant, amount: int, parts: Array) -> void:
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
			_repeat_save(target, fx, adv)
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
	zones.on_moved(c, from)
