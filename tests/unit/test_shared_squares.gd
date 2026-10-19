extends TestCase
## Cramped rooms (owner, 2026-10-12): a hero may end a move in an ally's space, so heroes can share a square, and nobody
## ends in a foe's space. Foes share too (owner, 2026-10-19: "Enemies should be able to share the same square"): a foe the
## game moves may end in an allied foe's square while the square's load stays within four (Tiny 1, Small and Medium 2),
## a Large or bigger one never shares, a foe shares only when no square of its own lets it strike, and a refusal says why.


## Hands the turn to `c` (Encounter.start has already ordered the fight).
func _turn_of(e: Encounter, c: Combatant) -> void:
	e.turn_index = e.order.find(c)
	e._begin_turn()


func test_a_hero_can_stop_in_an_allys_square() -> void:
	var e := TestCombat.encounter(["#########", "#.......#", "#########"])
	var ilse := TestCombat.hero(e, "ilse_varga", Vector2i(1, 1), 5)
	var silvain := TestCombat.hero(e, "silvain_aster", Vector2i(3, 1), 5)
	var z := TestCombat.foe(e, "zombie", Vector2i(7, 1))
	TestCombat.start_with(e, ilse)
	var cat := ActionCatalog.new(e)
	assert_true(bool(cat.move_preview(ilse, silvain.cell, cat.move_reach(ilse))["ok"]), "Move here, onto Silvain's square")
	assert_true(e.move(ilse, silvain.cell).ok)
	assert_eq(ilse.cell, silvain.cell, "the two share it")
	assert_false(bool(cat.move_preview(ilse, z.cell, cat.move_reach(ilse))["ok"]), "but never onto the zombie")


func test_a_foe_may_stop_in_an_allied_foes_square() -> void:
	var e := TestCombat.open_field()
	TestCombat.hero(e, "ilse_varga", Vector2i(1, 1), 5)
	var a := TestCombat.foe(e, "zombie", Vector2i(5, 5))
	var b := TestCombat.foe(e, "zombie", Vector2i(6, 5))
	TestCombat.start_with(e, a)
	var reach := e.reachable_for(a)
	assert_false(bool((reach[b.cell] as Dictionary)["occupied"]), "a zombie may stop beside its fellow's square, in it")
	assert_true(e.move(a, b.cell).ok)
	assert_eq(a.cell, b.cell, "the two share it")
	assert_eq(e.movement.occupants_at(b.cell).size(), 2)
	assert_eq(a.movement_left, 15, "5 ft into an ally's space, which isn't Difficult Terrain")


func test_a_square_holds_two_medium_foes_or_four_tiny_ones_or_one_medium_and_two_tiny() -> void:
	var e := TestCombat.open_field()
	TestCombat.hero(e, "ilse_varga", Vector2i(0, 0), 5)
	var spot := Vector2i(5, 5)
	var z1 := TestCombat.foe(e, "zombie", spot)
	var z2 := TestCombat.foe(e, "zombie", spot)
	var z3 := TestCombat.foe(e, "zombie", Vector2i(4, 5))
	TestCombat.start_with(e, z3)
	assert_true(bool((e.reachable_for(z3)[spot] as Dictionary)["occupied"]), "two Medium creatures fill a square")
	var full := e.movement.occupied_why(z3, spot)
	assert_true(full.begins_with("That square is full"), full)
	var r := e.move(z3, spot)
	assert_false(r.ok)
	assert_true(r.reason.begins_with("That square is full"), "the refusal says why: %s" % r.reason)
	assert_true(z1.cell == z2.cell and z3.cell == Vector2i(4, 5))
	# Four Tiny creatures to a square (the book's table), a fifth no.
	var e2 := TestCombat.open_field()
	TestCombat.hero(e2, "ilse_varga", Vector2i(0, 0), 5)
	var rats: Array[Combatant] = []
	for i in 3:
		rats.append(TestCombat.foe(e2, "rat", spot))
	var late := TestCombat.foe(e2, "rat", Vector2i(4, 5))
	var late2 := TestCombat.foe(e2, "rat", Vector2i(3, 5))
	TestCombat.start_with(e2, late)
	assert_false(bool((e2.reachable_for(late)[spot] as Dictionary)["occupied"]), "a fourth rat fits")
	assert_true(e2.move(late, spot).ok)
	_turn_of(e2, late2)
	assert_true(bool((e2.reachable_for(late2)[spot] as Dictionary)["occupied"]), "a fifth doesn't")
	# One Medium and two Tiny: 2 + 1 + 1.
	var e3 := TestCombat.open_field()
	TestCombat.hero(e3, "ilse_varga", Vector2i(0, 0), 5)
	TestCombat.foe(e3, "zombie", spot)
	TestCombat.foe(e3, "rat", spot)
	var third := TestCombat.foe(e3, "rat", Vector2i(4, 5))
	var fourth := TestCombat.foe(e3, "rat", Vector2i(3, 5))
	TestCombat.start_with(e3, third)
	assert_true(e3.move(third, spot).ok, "a second rat fits beside a zombie and a rat")
	_turn_of(e3, fourth)
	assert_true(bool((e3.reachable_for(fourth)[spot] as Dictionary)["occupied"]), "but not a third")


func test_a_large_foe_never_shares() -> void:
	var e := TestCombat.open_field()
	TestCombat.hero(e, "ilse_varga", Vector2i(0, 0), 5)
	var wolf := TestCombat.foe(e, "dire_wolf", Vector2i(6, 3))
	var z := TestCombat.foe(e, "zombie", Vector2i(3, 3))
	var z2 := TestCombat.foe(e, "zombie", Vector2i(9, 3))
	TestCombat.start_with(e, z)
	assert_true(wolf.size_cells > 1, "a dire wolf is Large")
	assert_true(bool((e.reachable_for(z)[wolf.cell] as Dictionary)["occupied"]), "a zombie can't stop in a Large foe's space")
	assert_true(e.movement.occupied_why(z, wolf.cell).contains("too big"), e.movement.occupied_why(z, wolf.cell))
	_turn_of(e, wolf)
	assert_true(bool((e.reachable_for(wolf)[z2.cell] as Dictionary)["occupied"]), "nor a Large one in a zombie's square")
	assert_true(e.movement.occupied_why(wolf, z2.cell).contains("too big"), e.movement.occupied_why(wolf, z2.cell))


func test_nobody_stops_in_an_enemys_square_and_the_refusal_names_whose() -> void:
	var e := TestCombat.encounter(["#########", "#.......#", "#########"])
	var ilse := TestCombat.hero(e, "ilse_varga", Vector2i(1, 1), 5)
	var z := TestCombat.foe(e, "zombie", Vector2i(3, 1))
	TestCombat.start_with(e, ilse)
	var cat := ActionCatalog.new(e)
	var mp := cat.move_preview(ilse, z.cell, cat.move_reach(ilse))
	assert_false(bool(mp["ok"]))
	assert_true(str(mp["reason"]).contains(z.name()) and str(mp["reason"]).contains("enemy"), str(mp["reason"]))
	var r := e.move(ilse, z.cell)
	assert_false(r.ok)
	assert_true(r.reason.contains(z.name()), r.reason)
	_turn_of(e, z)
	var reach := e.reachable_for(z)
	assert_true(not reach.has(ilse.cell) or bool((reach[ilse.cell] as Dictionary)["occupied"]), "a foe doesn't share a hero's square either")


func test_the_party_still_shares_without_a_cap() -> void:
	var e := TestCombat.encounter(["#########", "#.......#", "#########"])
	var a := TestCombat.hero(e, "ilse_varga", Vector2i(1, 1), 5)
	var b := TestCombat.hero(e, "silvain_aster", Vector2i(3, 1), 5)
	var c := TestCombat.hero(e, "hedda_ironvow", Vector2i(3, 1), 5)
	var d := TestCombat.hero(e, "tamsin_tealeaf", Vector2i(3, 1), 5)
	TestCombat.foe(e, "zombie", Vector2i(7, 1))
	TestCombat.start_with(e, a)
	assert_false(bool((e.reachable_for(a)[Vector2i(3, 1)] as Dictionary)["occupied"]), "a fourth hero joins three, no cap")
	assert_true(e.move(a, Vector2i(3, 1)).ok)
	assert_eq(e.movement.occupants_at(Vector2i(3, 1)).size(), 4)
	assert_true(b.cell == c.cell and c.cell == d.cell)


func test_a_place_where_allies_block_stops_foes_sharing_too() -> void:
	var e := TestCombat.open_field()
	TestCombat.hero(e, "ilse_varga", Vector2i(0, 0), 5)
	var a := TestCombat.foe(e, "zombie", Vector2i(5, 5))
	var b := TestCombat.foe(e, "zombie", Vector2i(6, 5))
	TestCombat.start_with(e, a)
	e.allies_block = true
	assert_false(e.reachable_for(a).has(b.cell), "no stopping there, nor walking through")
	assert_true(e.movement.occupied_why(a, b.cell).contains("allies can't share"), e.movement.occupied_why(a, b.cell))


func test_room_checks_count_everyone_in_a_shared_square() -> void:
	var e := TestCombat.open_field()
	TestCombat.hero(e, "ilse_varga", Vector2i(0, 0), 5)
	var spot := Vector2i(5, 5)
	var a := TestCombat.foe(e, "zombie", spot)
	var b := TestCombat.foe(e, "zombie", spot)
	assert_true(e.movement.others_in(spot, a) and e.movement.others_in(spot, b))
	assert_false(e.movement.others_in(Vector2i(2, 2), a))
	assert_false(e.movement.space_available(spot, 1, [a]), "b is still in it")
	assert_true(e.movement.space_available(spot, 1, [a, b]))


func test_a_foe_takes_a_square_of_its_own_before_one_it_must_share() -> void:
	var e := TestCombat.open_field()
	var hero := TestCombat.hero(e, "ilse_varga", Vector2i(8, 3), 5)
	var a := TestCombat.foe(e, "zombie", Vector2i(7, 3))
	var b := TestCombat.foe(e, "zombie", Vector2i(4, 3))
	TestCombat.start_with(e, b)
	var plan := e.ai.plan_turn(b)
	assert_eq(str(plan["kind"]), "attack")
	assert_ne(plan["cell"], a.cell, "free squares round the hero come first")
	assert_true(e.distance(b, hero) > 5)


func test_a_foe_in_a_corridor_shares_a_square_to_reach_its_target() -> void:
	var e := TestCombat.encounter(["#######", "#.....#", "#######"])
	var hero := TestCombat.hero(e, "ilse_varga", Vector2i(5, 1), 5)
	var a := TestCombat.foe(e, "zombie", Vector2i(4, 1))
	var b := TestCombat.foe(e, "zombie", Vector2i(2, 1))
	TestCombat.start_with(e, b)
	var plan := e.ai.plan_turn(b)
	assert_eq(str(plan["kind"]), "attack", "the one square beside the hero is the other zombie's, and it will do")
	assert_eq(plan["cell"], a.cell)
	e.run_ai_turn()
	assert_eq(b.cell, a.cell, "both zombies stand beside her")
	assert_true(e.distance(b, hero) <= 5)


func test_a_place_where_allies_block_still_blocks() -> void:
	var e := TestCombat.encounter(["#########", "#.......#", "#########"])
	var ilse := TestCombat.hero(e, "ilse_varga", Vector2i(1, 1), 5)
	var silvain := TestCombat.hero(e, "silvain_aster", Vector2i(3, 1), 5)
	TestCombat.foe(e, "zombie", Vector2i(7, 1))
	TestCombat.start_with(e, ilse)
	e.allies_block = true
	assert_false(e.reachable_for(ilse).has(silvain.cell))
