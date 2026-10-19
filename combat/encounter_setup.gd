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
	var grid := CombatGrid.from_rows(map["rows"] as Array, map.get("elevation", []) as Array)
	grid.drop_ft = int(map.get("drop_ft", 0))
	grid.ceiling_ft = int(map.get("ceiling_ft", 0))
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
		if ch == null or not ch.familiar in ["here", "pocket"]:
			continue
		var pocket := ch.familiar == "pocket"
		# A familiar stays until it drops to 0 Hit Points or is dismissed (2024), so one called from a scroll, or before
		# the spell left its caster's book, comes too (owner report 2026-10-12: Ratatouille's owl sat out his fights).
		var came := e.spells.precast(c, "find_familiar", true) if ch.knows_spell("find_familiar") else e.spells.summons.bring_familiar(c)
		if came and pocket:
			e.faerun.pocket_familiar(c)


## Otherworldly Steeds come along too: a party member whose Find Steed steed is still with them (Character.steed)
## starts the fight with it beside them, of the type and level it was called with. Nothing is spent; a steed whose
## caster has died is gone (2024).
static func bring_steeds(e: Encounter, party: Array[Combatant]) -> void:
	for c in party:
		var ch := c.creature as Character if c.creature is Character else null
		if ch == null or ch.steed.is_empty():
			continue
		if ch.dead:
			ch.steed = {}
			continue
		e.spells.summons.bring_steed(c)


## The familiar Find Familiar gives `c` (the form a fight's casting makes): an imp for a Pact of the Chain warlock, a
## skeleton for a Necromancy Familiar, else an owl. Monster data, for the familiar that follows the party around.
static func familiar_data(c: Combatant) -> Dictionary:
	var form := ""
	if ClassFeatures.knows_invocation(c, "pact_of_the_chain"):
		form = "imp"
	if CombatFeatures.has_feature(c, "necromancy_familiar"):
		form = "skeleton"
	return SummonBlocks.for_spell("find_familiar", 1, form, {})


## What a fight leaves on a creature once it's over (owner report 2026-10-12: Restrained stayed on the party panel after
## the fight): holds (a web, a net, a grapple, an area's grasp: the fight that made them is gone) and effects that last
## only rounds or until a turn. Curses, exhaustion and anything that lasts minutes, hours or until a rest stay.
static func clear_fight_effects(cr: Creature) -> void:
	for fx: Effect in cr.effects.duplicate():
		var holds := &"restrained" in fx.conditions or &"grappled" in fx.conditions
		if fx.ends in [Effect.Ends.ROUNDS, Effect.Ends.START_OF_TURN, Effect.Ends.END_OF_TURN] or holds \
				or not fx.escape.is_empty() or fx.stack_key.begins_with("zone:"):
			cr.remove_effect(fx)
	cr.remove_condition(&"grappled")
	cr.remove_condition(&"restrained")
	# The fallen-over get up: there's no turn left to spend standing, and a rider's Prone (an air elemental's Whirlwind)
	# has no end of its own.
	if cr.hp > 0 and not cr.dead:
		cr.end_condition(&"prone")


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
