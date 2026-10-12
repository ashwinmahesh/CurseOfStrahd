extends TestCase
## A click on a foe with a melee weapon in hand (owner, 2026-10-12: "use the melee weapon by default and automatically
## walk the character to the target (avoiding opportunity attacks if possible using the same amount of movement)").


func _field() -> Encounter:
	return TestCombat.encounter(["................", "................", "................", "................", "................"])


func test_a_foe_out_of_reach_is_walked_up_to() -> void:
	var e := _field()
	var ilse := TestCombat.hero(e, "ilse_varga", Vector2i(1, 2), 5)
	var z := TestCombat.foe(e, "zombie", Vector2i(5, 2))
	TestCombat.start_with(e, ilse)
	ilse.movement_left = 30
	var cat := ActionCatalog.new(e)
	var ma := cat.melee_approach(ilse, z, cat.move_reach(ilse))
	assert_true(bool(ma["ok"]), "the zombie is 20 ft off, within the 30 ft left")
	assert_true(bool(ma["walk"]))
	assert_eq(str((ma["action"] as Dictionary)["id"]), "attack:weapon:greatsword", "the greatsword in hand")
	assert_eq(int(ma["cost"]), 15, "the nearest square beside it")
	assert_eq(int(ma["left"]), 15)
	assert_eq(e.grid.distance_ft(ma["dest"] as Vector2i, 1, z.cell, 1), 5, "beside the zombie")
	assert_true(bool((ma["preview"] as Dictionary)["legal"]), "the odds read from beside it")
	assert_true(e.move(ilse, ma["dest"] as Vector2i).ok)
	assert_eq(cat.target_why(ilse, ma["action"] as Dictionary, z), "", "and from there the swing lands")


func test_in_reach_already_no_walk() -> void:
	var e := _field()
	var ilse := TestCombat.hero(e, "ilse_varga", Vector2i(1, 2), 5)
	var z := TestCombat.foe(e, "zombie", Vector2i(2, 2))
	TestCombat.start_with(e, ilse)
	var cat := ActionCatalog.new(e)
	var ma := cat.melee_approach(ilse, z, cat.move_reach(ilse))
	assert_true(bool(ma["ok"]))
	assert_false(bool(ma["walk"]))
	assert_eq(ma["dest"], ilse.cell)


func test_no_walk_with_a_bow_in_hand_or_a_foe_too_far() -> void:
	var e := _field()
	var ilse := TestCombat.hero(e, "ilse_varga", Vector2i(1, 2), 5)
	var z := TestCombat.foe(e, "zombie", Vector2i(5, 2))
	var far := TestCombat.foe(e, "zombie", Vector2i(15, 2))
	TestCombat.start_with(e, ilse)
	ilse.movement_left = 30
	var cat := ActionCatalog.new(e)
	assert_false(bool(cat.melee_approach(ilse, far, cat.move_reach(ilse))["ok"]), "70 ft off: nothing to walk up to")
	(ilse.creature as Character).swap_weapon_sets()
	assert_eq((ilse.creature as Character).held_id("main_hand"), "shortbow")
	assert_false(bool(cat.melee_approach(ilse, z, cat.move_reach(ilse))["ok"]), "a bow in the main hand shoots from here")


func test_the_walk_takes_the_way_round_a_foe_when_it_costs_the_same() -> void:
	# Straight along row 2 passes through the zombie's reach and out again; row 3 costs the same and doesn't.
	var e := _field()
	var ilse := TestCombat.hero(e, "ilse_varga", Vector2i(0, 2), 5)
	var z := TestCombat.foe(e, "zombie", Vector2i(3, 1))
	TestCombat.start_with(e, ilse)
	ilse.movement_left = 30
	var cat := ActionCatalog.new(e)
	var reach := cat.move_reach(ilse)
	assert_true(e.movement.provocations(ilse, CombatGrid.path_to(reach, Vector2i(6, 2))) > 0, "the search's own way passes it")
	var mp := cat.move_preview(ilse, Vector2i(6, 2), reach)
	assert_true(bool(mp["ok"]))
	assert_eq(int(mp["cost"]), 30, "no longer than the cheapest way")
	assert_eq(e.movement.provocations(ilse, mp["path"] as Array[Vector2i]), 0, "round the zombie's reach: %s" % str(mp["path"]))
	for w: String in mp["warnings"]:
		assert_false(w.contains("Opportunity"), w)
	var hp := ilse.creature.hp
	assert_true(e.move(ilse, Vector2i(6, 2)).ok)
	assert_eq(ilse.cell, Vector2i(6, 2))
	assert_true(z.reaction_available, "the zombie never got its swing")
	assert_eq(ilse.creature.hp, hp)


func test_no_way_round_still_provokes() -> void:
	# A corridor past the zombie's alcove: every way through leaves its reach, and the preview says so.
	var e := TestCombat.encounter(["###.####", "........", "########"])
	var ilse := TestCombat.hero(e, "ilse_varga", Vector2i(0, 1), 5)
	TestCombat.foe(e, "zombie", Vector2i(3, 0))
	TestCombat.start_with(e, ilse)
	ilse.movement_left = 35
	var cat := ActionCatalog.new(e)
	var mp := cat.move_preview(ilse, Vector2i(7, 1), cat.move_reach(ilse))
	assert_true(bool(mp["ok"]))
	var warned := false
	for w: String in mp["warnings"]:
		warned = warned or w.contains("Opportunity")
	assert_true(warned, "the Opportunity Attack is still flagged")
