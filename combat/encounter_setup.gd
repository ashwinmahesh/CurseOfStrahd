class_name EncounterSetup
extends RefCounted
## Builds an Encounter from data/encounters/<id>.json (ADR 0007): the grid from the map rows, the party from the
## pregens at the encounter's level after a Long Rest (with spells cast before the fight), and the enemies, numbered when there are
## several of a kind ("Wolf 2"). Monsters use their average Hit Points (the 2024 stat block default).


static func load_id(encounter_id: String, dice: DiceRoller, errors: Array[String] = []) -> Encounter:
	var entry := Compendium.shared().get_entry("encounters", encounter_id)
	if entry.is_empty():
		errors.append("No encounter '%s'" % encounter_id)
		return null
	return from_data(entry, dice, errors)


static func from_data(entry: Dictionary, dice: DiceRoller, errors: Array[String] = []) -> Encounter:
	var map := entry["map"] as Dictionary
	var grid := CombatGrid.from_rows(map["rows"] as Array)
	var e := Encounter.new(grid, dice)
	e.title = str(entry.get("name", ""))
	e.intro = str(entry.get("text", ""))
	e.ambient_light = str(map.get("light", "bright"))
	e.sunlit = bool(map.get("sunlight", false))
	var level := int(entry.get("party_level", 1))
	for p: Variant in entry["party"]:
		var pd := p as Dictionary
		var ch := Pregens.build(str(pd["pregen"]), level, errors)
		if ch == null:
			continue
		ch.finish_long_rest()   # rested and ready: full resources, Heroic Inspiration for Resourceful humans
		var c := e.add(ch, &"party", _cell(pd["cell"]))
		for sp: Variant in pd.get("precast", []):
			e.spells.precast(c, str(sp))
	var counts := {}
	for m: Variant in entry["enemies"]:
		var mid := str((m as Dictionary)["monster"])
		counts[mid] = int(counts.get(mid, 0)) + 1
	var numbered := {}
	for m: Variant in entry["enemies"]:
		var md := m as Dictionary
		var mid := str(md["monster"])
		var data := Compendium.shared().monster_data(mid)
		if data.is_empty():
			errors.append("No monster '%s'" % mid)
			continue
		var mon := Monster.from_data(data)
		if md.has("name"):
			mon.name = str(md["name"])
		elif int(counts[mid]) > 1:
			numbered[mid] = int(numbered.get(mid, 0)) + 1
			mon.name = "%s %d" % [mon.name, numbered[mid]]
		e.add(mon, StringName(str(md.get("side", "enemy"))), _cell(md["cell"]))
	return e


## Familiars come along: a party member whose Find Familiar familiar is still summoned (Character.familiar) starts
## the fight with it beside it, or waiting in its pocket dimension. Nothing is spent: it was cast earlier.
static func bring_familiars(e: Encounter, party: Array[Combatant]) -> void:
	for c in party:
		var ch := c.creature as Character if c.creature is Character else null
		if ch == null or not ch.familiar in ["here", "pocket"] or not ch.knows_spell("find_familiar"):
			continue
		var pocket := ch.familiar == "pocket"
		if e.spells.precast(c, "find_familiar", true) and pocket:
			e.faerun.pocket_familiar(c)


## Creature ids the encounter data marks as surprised.
static func surprised_ids(entry: Dictionary, e: Encounter) -> Array[String]:
	var out: Array[String] = []
	var who := entry.get("surprised", []) as Array
	for c in e.combatants:
		if ("party" in who and c.side == &"party") or ("enemies" in who and c.side == &"enemy"):
			out.append(c.id)
	return out


static func _cell(v: Variant) -> Vector2i:
	var a := v as Array
	return Vector2i(int(a[0]), int(a[1]))
