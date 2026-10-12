extends TestCase
## Low platforms (owner 2026-10-12: "all of our elevated platforms are too big? like the podium in vallaki should just
## be a couple of feet tall"): a `_` square is a dais, a podium, a stage, an altar's step, a porch or a jetty, CombatGrid
## DAIS_FT above the floor. It is a plain step up (no climbing, no high ground), a saved fight keeps it, the mouse finds
## its top, and the places' podiums, stages and altars stand at it while stairs, walks and walls keep their 5 ft steps.


func _none(_c: Vector2i) -> bool:
	return false


func test_a_dais_is_a_couple_of_feet_and_a_plain_step() -> void:
	var g := CombatGrid.from_rows(["._.1"])
	assert_eq(g.height(Vector2i(1, 0)), CombatGrid.DAIS_FT, "a dais stands DAIS_FT above the floor")
	assert_between(CombatGrid.DAIS_FT, 1, 3, "a couple of feet")
	assert_eq(g.step_cost(Vector2i(0, 0), Vector2i(1, 0), 1, _none, _none), 5, "stepping up onto it is no climb")
	assert_eq(g.step_cost(Vector2i(1, 0), Vector2i(0, 0), 1, _none, _none), 5, "nor stepping down")
	assert_eq(g.height(Vector2i(3, 0)), CombatGrid.FEET, "a digit is still a 5 ft step")


func test_a_dais_gives_no_high_ground() -> void:
	var e := TestCombat.encounter(["_......", "_......", "_......"], 2)
	var archer := TestCombat.hero(e, "thistle", Vector2i(0, 1))
	var foe := TestCombat.punching_bag(e, Vector2i(5, 1), 200)
	TestCombat.start_with(e, archer)
	var bow: Dictionary = {}
	for o in e.attack_options(archer):
		if not bool(o["melee"]) and str(o["kind"]) == "weapon":
			bow = o
	assert_false(bow.is_empty(), "Thistle has a longbow")
	assert_eq(int(e.attack_situation(archer, foe, bow)["height_bonus"]), 0, "two feet up is not high ground")


func test_a_saved_fight_keeps_its_daises() -> void:
	var e := TestCombat.encounter(["._1..."], 3)
	var c := TestCombat.hero(e, "ilse_varga", Vector2i(0, 0))
	TestCombat.foe(e, "zombie", Vector2i(5, 0))
	TestCombat.start_with(e, c)
	var back := EncounterSnapshot.restore(EncounterSnapshot.capture(e), DiceRoller.new(3))
	assert_eq(back.grid.height(Vector2i(1, 0)), CombatGrid.DAIS_FT, "the dais comes back at its height")
	assert_eq(back.grid.height(Vector2i(2, 0)), CombatGrid.FEET, "the step beside it at its own")


func test_the_mouse_finds_a_dais() -> void:
	var g := CombatGrid.from_rows(["._"])
	var dais := float(CombatGrid.DAIS_FT) / CombatGrid.FEET
	assert_true(dais in GridPick.planes(), "the dais's height is one of the planes looked at")
	assert_true(GridPick.on_plane(g, Vector2i(1, 0), dais), "its top is found at its height")
	assert_false(GridPick.on_plane(g, Vector2i(0, 0), dais), "the floor beside it isn't")


func test_podiums_stages_and_altars_stand_low() -> void:
	var want := {"vallaki": [Vector2i(24, 12), "the festival podium"], "tser_pool": [Vector2i(29, 16), "the dancers' stage"],
		"village_church": [Vector2i(9, 2), "the altar's dais"], "krezk_pool_of_the_white_sun": [Vector2i(19, 6), "the pavilion"]}
	for loc: String in want:
		var d := Compendium.shared().get_entry("locations", loc) as Dictionary
		var built := LocationView.grid_for(d)
		var c := (want[loc] as Array)[0] as Vector2i
		assert_eq(str((d["map"]["rows"] as Array)[c.y])[c.x], "_", "%s: %s is a low dais" % [loc, (want[loc] as Array)[1]])
		var under := 0
		if (d["map"] as Dictionary).has("elevation"):
			under = maxi(0, CombatGrid.ELEVATION_CHARS.find(str((d["map"]["elevation"] as Array)[c.y])[c.x])) * CombatGrid.FEET
		assert_eq(built.height(c) - under, CombatGrid.DAIS_FT, "%s: %s stands a couple of feet up" % [loc, (want[loc] as Array)[1]])
	var walk := LocationView.grid_for(Compendium.shared().get_entry("locations", "krezk"))
	assert_eq(walk.height(Vector2i(30, 14)), 2 * CombatGrid.FEET, "Krezk's wall walk keeps its height: a real walk on the wall")
