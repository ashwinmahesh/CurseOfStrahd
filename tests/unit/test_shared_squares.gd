extends TestCase
## Cramped rooms (owner, 2026-10-12): a hero may end a move in an ally's space, so heroes can share a square; foes the
## game moves keep to squares of their own, and nobody ends in a foe's space.


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


func test_foes_keep_their_own_squares() -> void:
	var e := TestCombat.open_field()
	var hero := TestCombat.hero(e, "ilse_varga", Vector2i(1, 1), 5)
	var a := TestCombat.foe(e, "zombie", Vector2i(5, 5))
	var b := TestCombat.foe(e, "zombie", Vector2i(6, 5))
	TestCombat.start_with(e, a)
	var reach := e.reachable_for(a)
	assert_true(bool((reach[b.cell] as Dictionary)["occupied"]), "a zombie walks through its fellow but can't stop there")
	assert_true(hero.cell != a.cell)


func test_a_place_where_allies_block_still_blocks() -> void:
	var e := TestCombat.encounter(["#########", "#.......#", "#########"])
	var ilse := TestCombat.hero(e, "ilse_varga", Vector2i(1, 1), 5)
	var silvain := TestCombat.hero(e, "silvain_aster", Vector2i(3, 1), 5)
	TestCombat.foe(e, "zombie", Vector2i(7, 1))
	TestCombat.start_with(e, ilse)
	e.allies_block = true
	assert_false(e.reachable_for(ilse).has(silvain.cell))
