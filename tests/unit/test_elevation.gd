extends TestCase
## Natural elevation (owner, 2026-10-08; combat/grid.gd): a map's `elevation` rows lay the lie of the land under its
## squares. Between natural squares 5 ft is a gentle slope, 10 ft a steep one (uphill costs as Difficult Terrain) and
## 15 ft or more a cliff (climbed, shoved off, or jumped down with the fall); a built height keeps F4's ledges. Rising
## ground between two creatures hides them, a little rise giving cover; a saved fight keeps it all.


func _no(_c: Vector2i) -> bool:
	return false


func _cost(g: CombatGrid, a: Vector2i, b: Vector2i, mode: int = 0) -> int:
	return g.step_cost(a, b, 1, _no, _no, mode)


func test_the_elevation_rows_raise_natural_ground() -> void:
	var g := CombatGrid.from_rows(["......", "..2..."], ["012abz", "000000"])
	assert_eq(g.height(Vector2i(1, 0)), 5)
	assert_eq(g.height(Vector2i(3, 0)), 50, "'a' is ten steps")
	assert_eq(g.height(Vector2i(5, 0)), 175, "'z' is thirty-five")
	assert_true(g.has_flag(Vector2i(1, 0), CombatGrid.NATURAL))
	assert_eq(g.height(Vector2i(2, 1)), 10, "a digit builds on the ground")
	assert_false(g.has_flag(Vector2i(2, 1), CombatGrid.NATURAL), "and isn't natural")
	assert_true(g.has_relief)


func test_slopes_cost_by_how_steep_they_are() -> void:
	var g := CombatGrid.from_rows(["......"], ["013666"])
	assert_eq(_cost(g, Vector2i(0, 0), Vector2i(1, 0)), 5, "a 5 ft rise: a gentle slope")
	assert_eq(_cost(g, Vector2i(1, 0), Vector2i(2, 0)), 10, "10 ft up: a steep slope, as Difficult Terrain")
	assert_eq(_cost(g, Vector2i(2, 0), Vector2i(1, 0)), 5, "and nothing extra going down")
	assert_eq(_cost(g, Vector2i(2, 0), Vector2i(3, 0)), 35, "15 ft: a cliff, climbed (15 ft and 15 extra)")
	assert_eq(_cost(g, Vector2i(2, 0), Vector2i(3, 0), CombatGrid.MOVE_CLIMB), 20, "with a Climb Speed, no extra")
	assert_false(g.is_cliff(Vector2i(1, 0), Vector2i(2, 0)))
	assert_true(g.is_cliff(Vector2i(2, 0), Vector2i(3, 0)))


func test_a_built_ledge_is_climbed_as_before() -> void:
	var g := CombatGrid.from_rows(["..2..."])
	assert_true(g.is_cliff(Vector2i(1, 0), Vector2i(2, 0)), "10 ft of built height is a ledge")
	assert_eq(_cost(g, Vector2i(1, 0), Vector2i(2, 0)), 25)


func test_a_shove_down_a_steep_slope_slides_but_off_a_cliff_falls() -> void:
	var e := TestCombat.encounter(["......", "......"], 3)
	e.grid.apply_elevation(["222000", "333000"])
	var c := TestCombat.hero(e, "ilse_varga", Vector2i(1, 0))
	var slope := TestCombat.punching_bag(e, Vector2i(2, 0), 200)
	var cliff := TestCombat.punching_bag(e, Vector2i(2, 1), 200)
	TestCombat.start_with(e, c)
	e.movement.forced_move(slope, Vector2(1.5, 0.5), 5)
	assert_eq(slope.cell, Vector2i(3, 0), "pushed down the 10 ft slope")
	assert_eq(slope.creature.hp, 200, "without falling")
	e.movement.forced_move(cliff, Vector2(1.5, 1.5), 5)
	assert_eq(cliff.cell, Vector2i(3, 1), "pushed off the 15 ft cliff")
	assert_true(cliff.creature.hp < 200, "and it falls")


func test_jumping_down_a_cliff_takes_the_fall() -> void:
	var e := TestCombat.encounter(["......"], 3)
	e.grid.apply_elevation(["444000"])
	var c := TestCombat.hero(e, "ilse_varga", Vector2i(2, 0))
	TestCombat.foe(e, "zombie", Vector2i(5, 0))
	TestCombat.start_with(e, c)
	assert_eq(e.movement.jump_down_why(c, Vector2i(1, 0)), "Not a drop")
	var acts: Array = ActionCatalog.new(e).square_actions(c, Vector2i(3, 0)).map(func(a: Dictionary) -> String: return str(a["id"]))
	assert_true(acts.has("act:jump_down:3:0"), "the square below offers the jump")
	var hp := c.creature.hp
	var left := c.movement_left
	var r := e.movement.jump_down(c, Vector2i(3, 0))
	assert_true(r.ok, r.reason)
	assert_eq(c.cell, Vector2i(3, 0))
	assert_eq(c.movement_left, left - 5, "5 ft of movement")
	assert_true(c.creature.hp < hp, "and 2d6 for the 20 ft")


func test_rising_ground_hides_and_covers() -> void:
	var rows: Array[String] = []
	for z in 3:
		rows.append(".........")
	var ridge := CombatGrid.from_rows(rows, ["000030000", "000030000", "000030000"])
	assert_false(ridge.can_see(Vector2i(1, 1), 1, Vector2i(7, 1), 1), "a 15 ft ridge between hides them")
	var rise := CombatGrid.from_rows(rows, ["000010000", "000010000", "000010000"])
	assert_true(rise.can_see(Vector2i(1, 1), 1, Vector2i(7, 1), 1), "over a 5 ft rise, heads show")
	assert_eq(int(rise.cover_between(Vector2i(1, 1), 1, Vector2i(7, 1), 1)["cover"]), CombatGrid.Cover.THREE_QUARTERS)
	var hill := CombatGrid.from_rows(rows, ["000030000", "000030000", "000030000"])
	assert_true(hill.can_see(Vector2i(4, 1), 1, Vector2i(7, 1), 1), "from the top of the ridge, the far side is in sight")


func test_a_saved_fight_keeps_the_lie_of_the_land() -> void:
	var e := TestCombat.encounter(["......"], 3)
	e.grid.apply_elevation(["013666"])
	var c := TestCombat.hero(e, "ilse_varga", Vector2i(0, 0))
	TestCombat.foe(e, "zombie", Vector2i(5, 0))
	TestCombat.start_with(e, c)
	var back := EncounterSnapshot.restore(EncounterSnapshot.capture(e), DiceRoller.new(3))
	assert_eq(back.grid.height(Vector2i(3, 0)), 30)
	assert_true(back.grid.has_flag(Vector2i(2, 0), CombatGrid.NATURAL))
	assert_false(back.grid.is_cliff(Vector2i(1, 0), Vector2i(2, 0)), "still a steep slope, not a ledge")


func test_a_hill_gives_high_ground() -> void:
	var e := TestCombat.encounter([".......", ".......", "......."], 2)
	e.grid.apply_elevation(["2210000", "2210000", "2210000"])
	var archer := TestCombat.hero(e, "thistle", Vector2i(0, 1))
	var foe := TestCombat.punching_bag(e, Vector2i(5, 1), 200)
	TestCombat.start_with(e, archer)
	var bow: Dictionary = {}
	for o in e.attack_options(archer):
		if not bool(o["melee"]) and str(o["kind"]) == "weapon":
			bow = o
	assert_false(bow.is_empty(), "Thistle has a longbow")
	assert_true(e.grid.can_see(archer.cell, 1, foe.cell, 1), "down an open slope")
	assert_eq(int(e.attack_situation(archer, foe, bow)["height_bonus"]), 2, "from 10 ft up the hill (the house rule)")
	assert_eq(int(e.attack_situation(foe, archer, bow)["height_bonus"]), -2, "and up at it")


## A raised prop (a location prop's `stand_ft`: a podium, a platform, a tree climbed into): its squares are stood on
## that high above the ground, climbed onto, jumped down from, high ground and cover like a ledge.
func _podium() -> Dictionary:
	return {"map": {"rows": ["........", "........", "........"]},
		"props": [{"id": "podium", "cell": [3, 0], "span": [2, 3], "kind": "decor", "stand_ft": 10}]}


func test_a_raised_prop_is_climbed_onto_and_jumped_down_from() -> void:
	var g := LocationView.grid_for(_podium())
	assert_eq(g.height(Vector2i(3, 1)), 10, "its squares stand 10 ft up")
	assert_eq(g.height(Vector2i(4, 2)), 10, "all of its span")
	assert_eq(int(g.raised.get(Vector2i(4, 2), 0)), 10, "and the board knows the prop stands there")
	assert_true(g.is_cliff(Vector2i(2, 1), Vector2i(3, 1)), "a ledge to the ground beside it")
	assert_eq(_cost(g, Vector2i(2, 1), Vector2i(3, 1)), 25, "climbed (10 ft and 10 extra)")
	var e := Encounter.new(g, DiceRoller.new(3))
	var c := TestCombat.hero(e, "ilse_varga", Vector2i(3, 1))
	TestCombat.foe(e, "zombie", Vector2i(7, 2))
	TestCombat.start_with(e, c)
	assert_eq(e.movement.jump_down_why(c, Vector2i(2, 1)), "", "down off it, taking the fall")
	var r := e.movement.jump_down(c, Vector2i(2, 1))
	assert_true(r.ok, r.reason)
	assert_eq(c.cell, Vector2i(2, 1))


func test_a_raised_prop_is_high_ground_and_hides_what_is_behind_it() -> void:
	var e := Encounter.new(LocationView.grid_for(_podium()), DiceRoller.new(3))
	var archer := TestCombat.hero(e, "thistle", Vector2i(4, 1))
	var below := TestCombat.punching_bag(e, Vector2i(7, 1), 200)
	TestCombat.start_with(e, archer)
	var bow: Dictionary = {}
	for o in e.attack_options(archer):
		if not bool(o["melee"]) and str(o["kind"]) == "weapon":
			bow = o
	assert_eq(int(e.attack_situation(archer, below, bow)["height_bonus"]), 2, "shooting down from the podium")
	assert_false(e.grid.can_see(Vector2i(0, 1), 1, Vector2i(7, 1), 1), "from the ground, the podium hides the far side")
