class_name Spellcasting
extends RefCounted
## Spell slot tables and spell math (2024 PHB "Spells", "Multiclassing").
## - Single-class casters use their class table. A half caster's table equals the full-caster table at
##   half its level rounded up; a third caster's (Eldritch Knight, Arcane Trickster) at a third rounded up.
## - Multiclass casters add full levels, half Paladin/Ranger levels (round up) and a third of EK/AT levels
##   (round down), then read the Multiclass Spellcaster table (the same numbers as the full-caster table).
## - Cantrips upgrade at character levels 5, 11 and 17.

## Slots per spell level (index 0 = level 1) by caster level 1-20 (2024 PHB Multiclass Spellcaster table).
const SLOTS: Array = [
	[2, 0, 0, 0, 0, 0, 0, 0, 0],
	[3, 0, 0, 0, 0, 0, 0, 0, 0],
	[4, 2, 0, 0, 0, 0, 0, 0, 0],
	[4, 3, 0, 0, 0, 0, 0, 0, 0],
	[4, 3, 2, 0, 0, 0, 0, 0, 0],
	[4, 3, 3, 0, 0, 0, 0, 0, 0],
	[4, 3, 3, 1, 0, 0, 0, 0, 0],
	[4, 3, 3, 2, 0, 0, 0, 0, 0],
	[4, 3, 3, 3, 1, 0, 0, 0, 0],
	[4, 3, 3, 3, 2, 0, 0, 0, 0],
	[4, 3, 3, 3, 2, 1, 0, 0, 0],
	[4, 3, 3, 3, 2, 1, 0, 0, 0],
	[4, 3, 3, 3, 2, 1, 1, 0, 0],
	[4, 3, 3, 3, 2, 1, 1, 0, 0],
	[4, 3, 3, 3, 2, 1, 1, 1, 0],
	[4, 3, 3, 3, 2, 1, 1, 1, 0],
	[4, 3, 3, 3, 2, 1, 1, 1, 1],
	[4, 3, 3, 3, 3, 1, 1, 1, 1],
	[4, 3, 3, 3, 3, 2, 1, 1, 1],
	[4, 3, 3, 3, 3, 2, 2, 1, 1],
]

const CANTRIP_TIERS: Array[int] = [5, 11, 17]


static func slots_for_caster_level(caster_level: int) -> Array[int]:
	var out: Array[int] = [0, 0, 0, 0, 0, 0, 0, 0, 0]
	if caster_level <= 0:
		return out
	var row := SLOTS[mini(caster_level, 20) - 1] as Array
	for i in 9:
		out[i] = int(row[i])
	return out


## One class's contribution to the caster level. `alone` = it is the only Spellcasting class.
static func caster_level_for(progression: String, class_level: int, alone: bool) -> int:
	match progression:
		"full":
			return class_level
		"half":
			return ceili(class_level / 2.0)
		"third":
			return ceili(class_level / 3.0) if alone else floori(class_level / 3.0)
	return 0


## Slots for a set of casting classes: [{progression, level}].
static func slots_for(casters: Array[Dictionary]) -> Array[int]:
	var counted: Array[Dictionary] = []
	for c in casters:
		if str(c["progression"]) != "pact":
			counted.append(c)
	var total := 0
	for c in counted:
		total += caster_level_for(str(c["progression"]), int(c["level"]), counted.size() == 1)
	return slots_for_caster_level(total)


static func highest_slot_level(slots: Array[int]) -> int:
	var best := 0
	for i in slots.size():
		if slots[i] > 0:
			best = i + 1
	return best


## Number of extra cantrip dice at a character level (0 at 1-4, 1 at 5-10, 2 at 11-16, 3 at 17+).
static func cantrip_tier(character_level: int) -> int:
	var t := 0
	for lv in CANTRIP_TIERS:
		if character_level >= lv:
			t += 1
	return t


## Damage dice for a damaging spell at a character level (cantrips) or slot level (levelled spells):
## "2d10" for Fire Bolt at level 5, "9d6" for Fireball in a level 4 slot.
static func damage_dice(spell: Dictionary, character_level: int, slot_level: int = 0) -> String:
	var damage := spell.get("damage", []) as Array
	if damage.is_empty():
		return ""
	var base := DiceRoller.parse_expr(str((damage[0] as Dictionary).get("dice", "0")))
	var count := int(base["count"])
	var level := int(spell.get("level", 0))
	if level == 0:
		var scaling := spell.get("cantrip_scaling", {}) as Dictionary
		if scaling.has("damage"):
			count += int(DiceRoller.parse_expr(str(scaling["damage"]))["count"]) * cantrip_tier(character_level)
	elif slot_level > level:
		var up := spell.get("upcast", {}) as Dictionary
		if up.has("damage"):
			count += int(DiceRoller.parse_expr(str(up["damage"]))["count"]) * (slot_level - level)
	return _format(count, int(base["sides"]), int(base["modifier"]))


## Healing dice at a slot level: Cure Wounds "2d8" at level 1, "4d8" at level 2.
static func heal_dice(spell: Dictionary, slot_level: int) -> String:
	var heal := spell.get("heal", {}) as Dictionary
	if not heal.has("dice"):
		return ""
	var base := DiceRoller.parse_expr(str(heal["dice"]))
	var count := int(base["count"])
	var level := int(spell.get("level", 0))
	var up := spell.get("upcast", {}) as Dictionary
	if slot_level > level and up.has("heal"):
		count += int(DiceRoller.parse_expr(str(up["heal"]))["count"]) * (slot_level - level)
	return _format(count, int(base["sides"]), int(base["modifier"]))


static func _format(count: int, sides: int, modifier: int) -> String:
	var s := "%dd%d" % [count, sides] if count > 0 else ""
	if modifier > 0:
		s += "+%d" % modifier if s != "" else str(modifier)
	elif modifier < 0:
		s += str(modifier)
	return s
