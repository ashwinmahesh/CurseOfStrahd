extends TestCase
## Phase 2 exit (plan §9): the arena fight of the four level 3 pregens against Barovian wolves and zombies, loaded
## from data/encounters/arena_wolves_and_zombies.json and played to the end many times over.

const ARENA := "arena_wolves_and_zombies"


func test_arena_loads_from_data() -> void:
	var errors: Array[String] = []
	var e := EncounterSetup.load_id(ARENA, DiceRoller.new(1), errors)
	assert_true(errors.is_empty(), str(errors))
	assert_eq(e.combatants.size(), 13)
	var names := e.combatants.map(func(c: Combatant) -> String: return c.name())
	assert_true("Wolf 1" in names and "Wolf 4" in names and "Zombie 4" in names and "Dire Wolf" in names, str(names))
	var silvain := e.combatants.filter(func(c: Combatant) -> bool: return c.name() == "Silvain Aster")[0] as Combatant
	assert_eq(silvain.creature.ac_value(), 14, "Mage Armor cast before the fight: 13 + Dex 1")
	assert_eq((silvain.creature as Character).slots_left(1), 3)
	for c in e.combatants:
		for cell in c.footprint():
			assert_false(e.grid.is_solid(cell), "%s stands on open floor" % c.name())


func test_arena_fights_finish_with_sensible_results() -> void:
	var wins := 0
	var rounds := 0
	var downs := 0
	var runs := 12
	for seed_value in range(1, runs + 1):
		var e := EncounterSetup.load_id(ARENA, DiceRoller.new(seed_value))
		var res := PartyAutopilot.new(e).run(30)
		assert_ne(str(res["outcome"]), "timeout", "seed %d finished" % seed_value)
		if str(res["outcome"]) == "victory":
			wins += 1
		rounds += int(res["rounds"])
		downs += int(res["downs"])
		for c in e.combatants:
			assert_true(c.creature.hp >= 0 and c.creature.hp <= c.creature.max_hp(), "%s HP in range" % c.name())
		assert_true(e.pending == null)
	print("        arena: %d/%d victories, %.1f rounds on average, %.1f party members dropped per fight" % [wins, runs, rounds / float(runs), downs / float(runs)])
	assert_true(wins >= runs / 2, "the party should usually win (%d/%d)" % [wins, runs])
