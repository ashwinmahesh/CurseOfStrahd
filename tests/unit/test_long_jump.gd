extends TestCase
## Long Jump and Throw (Combat HUD plan, owner pick 2026-10-09: Jump and Throw with arcs): the 2024 Long Jump over
## creatures and rough ground, a foot of movement a foot; everything thrown in one Throw slot.


func test_a_run_up_doubles_the_leap() -> void:
	var e := TestCombat.open_field()
	var ilse := TestCombat.hero(e, "ilse_varga", Vector2i(1, 3), 5)
	TestCombat.foe(e, "zombie", Vector2i(11, 7))
	TestCombat.start_with(e, ilse)
	var strength := ilse.creature.ability_score(&"str")
	assert_eq(e.movement.long_jump_ft(ilse), strength / 2 / 5 * 5, "from standing: half the Strength score")
	assert_true(e.move(ilse, Vector2i(3, 3)).ok, "a 10 ft run-up")
	assert_eq(e.movement.long_jump_ft(ilse), mini(strength / 5 * 5, ilse.movement_left / 5 * 5), "then the full Strength score")


func test_a_leap_clears_a_creature_and_costs_its_feet() -> void:
	var e := TestCombat.open_field()
	var ilse := TestCombat.hero(e, "ilse_varga", Vector2i(1, 3), 5)
	var god := TestCombat.hero(e, "godrick_pendlebrook", Vector2i(4, 3), 5)
	TestCombat.foe(e, "zombie", Vector2i(11, 7))
	TestCombat.start_with(e, ilse)
	assert_true(e.move(ilse, Vector2i(3, 3)).ok, "a 10 ft run-up, right up to Godrick")
	var left := ilse.movement_left
	var cat := ActionCatalog.new(e)
	var jump := cat.find(ilse, "long_jump")
	assert_true(bool(jump["legal"]), str(jump["reason"]))
	assert_true(cat.perform(ilse, jump, [], Vector2(5.5, 3.5)).ok, "over Godrick")
	assert_eq(ilse.cell, Vector2i(5, 3))
	assert_eq(ilse.movement_left, left - 10, "10 ft leapt, 10 ft spent")
	assert_ne(god.cell, ilse.cell)


func test_walls_and_crowded_squares_stop_a_leap() -> void:
	var e := TestCombat.encounter(["........", "...#....", "........"])
	var ilse := TestCombat.hero(e, "ilse_varga", Vector2i(2, 1), 5)
	var z := TestCombat.foe(e, "zombie", Vector2i(6, 2))
	TestCombat.start_with(e, ilse)
	assert_eq(e.movement.leap_why(ilse, Vector2i(4, 1)), "A wall is in the way")
	assert_eq(e.movement.leap_why(ilse, z.cell), "Can't land there")
	ilse.creature.add_condition(&"prone", "test")
	assert_eq(e.movement.long_jump_why(ilse), "Stand up first")


func test_everything_thrown_shares_one_throw_slot() -> void:
	var e := TestCombat.open_field()
	var tam := TestCombat.hero(e, "tamsin_tealeaf", Vector2i(2, 2), 5)
	TestCombat.foe(e, "zombie", Vector2i(9, 2))
	TestCombat.start_with(e, tam)
	var cat := ActionCatalog.new(e)
	var throw := {}
	for s in cat.slots(tam, ActionCatalog.COMMON):
		if str(s["label"]) == "Throw":
			throw = s
	assert_false(throw.is_empty(), "a Throw slot on Common")
	var names := (throw["items"] as Array).map(func(a: Dictionary) -> String: return cat.variant_name(a, "label:Throw"))
	assert_true("Dagger" in names, "the off-hand dagger, thrown")
	assert_false(cat.slots(tam, ActionCatalog.COMMON).any(func(s: Dictionary) -> bool: return str(s["label"]).ends_with("(thrown)")),
		"no thrown attack on its own slot")
	assert_false(cat.find(tam, "long_jump").is_empty(), "and Long Jump is on Common too")
