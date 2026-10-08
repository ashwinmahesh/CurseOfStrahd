class_name TestCombat
extends RefCounted
## Builders for combat tests: an encounter on a small map, monsters by id, and a seeded d20 for the next roll.


static func encounter(rows: Array, seed_value: int = 1) -> Encounter:
	return Encounter.new(CombatGrid.from_rows(rows), DiceRoller.new(seed_value))


## An open 12 x 8 floor.
static func open_field(seed_value: int = 1) -> Encounter:
	var rows: Array[String] = []
	for z in 8:
		rows.append("............")
	return encounter(rows, seed_value)


static func monster(id: String) -> Monster:
	return Monster.from_data(Compendium.shared().monster_data(id))


## Adds a pregen at `level` to the party side.
static func hero(e: Encounter, id: String, cell: Vector2i, level: int = 3) -> Combatant:
	return e.add(TestChars.pregen(id, level), &"party", cell)


static func foe(e: Encounter, id: String, cell: Vector2i) -> Combatant:
	return e.add(monster(id), &"enemy", cell)


## Starts combat and makes `first` act first by giving it the top Initiative (order is then re-sorted). A choice offered
## as Initiative is rolled (Tandem Footwork) is declined, as the test didn't ask for it; one offered once a turn has
## begun (Uncanny Metabolism's slot recovery) stays for the test to answer.
static func start_with(e: Encounter, first: Combatant) -> void:
	e.start()
	while e.pending != null and not e.events.any(func(ev: Variant) -> bool: return str((ev as Dictionary).get("type", "")) == "turn"):
		e.answer_reaction(false)
	for c in e.order:
		c.initiative = 1 if c != first else 30
	e.order.sort_custom(func(a: Combatant, b: Combatant) -> bool: return a.initiative > b.initiative)
	e.turn_index = 0
	e._begin_turn()


## Re-seeds the encounter's dice so the next d20 shows `value`.
static func next_d20(e: Encounter, value: int) -> void:
	e.dice.reseed(TestChars.seed_for_d20(value))


## A pregen that also knows `spell_ids` (added to its first spellcasting entry's prepared list), for testing spells
## no pregen has.
static func caster_with(e: Encounter, spell_ids: Array, cell: Vector2i, level: int = 9, id: String = "silvain_aster") -> Combatant:
	var ch := TestChars.pregen(id, level)
	var entry := ch.spellcasting[0] as Dictionary
	var prepared := entry["prepared"] as Array
	for s: Variant in spell_ids:
		if not str(s) in prepared:
			prepared.append(str(s))
	return e.add(ch, &"party", cell)


## A level 7 wizard (a level 4 slot: the class data reaches level 7) that also knows `spell_ids`, for level 4 spells.
static func high_caster(e: Encounter, spell_ids: Array, cell: Vector2i) -> Combatant:
	var ch := TestChars.custom("wizard", "human", 7)
	var entry := ch.spellcasting[0] as Dictionary
	var prepared := entry["prepared"] as Array
	for s: Variant in spell_ids:
		if not str(s) in prepared:
			prepared.append(str(s))
	return e.add(ch, &"party", cell)


## A feeble foe for spell tests: every save and AC as low as they go, plenty of Hit Points.
static func punching_bag(e: Encounter, cell: Vector2i, hp: int = 80, kind: String = "humanoid") -> Combatant:
	var m := TestChars.dummy(hp, false, {"type": kind, "ac": 1,
		"abilities": {"str": 1, "dex": 1, "con": 1, "int": 1, "wis": 1, "cha": 1}})
	return e.add(m, &"enemy", cell)
