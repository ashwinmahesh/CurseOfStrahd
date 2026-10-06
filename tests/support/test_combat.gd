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


## Starts combat and makes `first` act first by giving it the top Initiative (order is then re-sorted).
static func start_with(e: Encounter, first: Combatant) -> void:
	e.start()
	for c in e.order:
		c.initiative = 1 if c != first else 30
	e.order.sort_custom(func(a: Combatant, b: Combatant) -> bool: return a.initiative > b.initiative)
	e.turn_index = 0
	e._begin_turn()


## Re-seeds the encounter's dice so the next d20 shows `value`.
static func next_d20(e: Encounter, value: int) -> void:
	e.dice.reseed(TestChars.seed_for_d20(value))
