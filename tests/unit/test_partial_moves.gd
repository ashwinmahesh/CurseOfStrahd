extends TestCase
## A square further than the movement left (owner, 2026-10-12: "just move as close as we can with the movement we have"):
## the walk goes as far along the way as it can, with the usual path rules, and the preview shows where it stops.


func test_a_square_too_far_walks_as_far_as_the_movement_goes() -> void:
	var e := TestCombat.encounter(["................", "................", "................"])
	var ilse := TestCombat.hero(e, "ilse_varga", Vector2i(1, 1), 5)
	TestCombat.foe(e, "zombie", Vector2i(15, 2))
	TestCombat.start_with(e, ilse)
	var cat := ActionCatalog.new(e)
	var far := Vector2i(13, 1)
	var mp := cat.move_preview(ilse, far, cat.move_reach(ilse))
	assert_true(bool(mp["ok"]), "no Can't reach")
	assert_true(bool(mp["partial"]))
	assert_eq(mp["dest"], Vector2i(7, 1), "30 ft along the way")
	assert_eq(int(mp["left"]), 0)
	assert_true(e.move(ilse, far).ok, "the move goes ahead")
	assert_eq(ilse.cell, Vector2i(7, 1))
	assert_eq(ilse.movement_left, 0)
	assert_eq(cat.square_actions(ilse, Vector2i(12, 1), cat.move_reach(ilse))[0]["enabled"], false, "nothing left to walk")


func test_the_partial_walk_keeps_the_path_rules() -> void:
	# Difficult terrain doubles the cost on the way, so the walk stops sooner; a walled-off square can't be walked toward.
	var e := TestCombat.encounter(["...~~...........", "...~~...........", "...~~...........", "#######.........", "...#............"])
	var ilse := TestCombat.hero(e, "ilse_varga", Vector2i(1, 1), 5)
	TestCombat.foe(e, "zombie", Vector2i(15, 1))
	TestCombat.start_with(e, ilse)
	var cat := ActionCatalog.new(e)
	var mp := cat.move_preview(ilse, Vector2i(10, 1), cat.move_reach(ilse))
	assert_true(bool(mp["partial"]))
	assert_eq(int(mp["cost"]), 30, "the 30 ft left, the rough ground counted double")
	assert_eq(mp["dest"], Vector2i(5, 1), "slowed by the rough ground")
	assert_true(str(cat.square_actions(ilse, Vector2i(10, 1), cat.move_reach(ilse))[0]["label"]).begins_with("Move toward here"))
	var sealed := cat.move_preview(ilse, Vector2i(1, 3), cat.move_reach(ilse))
	assert_false(bool(sealed["ok"]), "behind the wall: %s" % sealed["reason"])
