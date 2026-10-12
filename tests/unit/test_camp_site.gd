extends TestCase
## Where and how the party makes camp in the wild (story/camp_site.gd, F16): which places, the fire's square, the
## camp's pieces and seats, and who has a word to say by the fire.


func _open_grid(w: int, d: int) -> CombatGrid:
	var rows: Array = []
	for z in d:
		rows.append("#" + ".".repeat(w - 2) + "#" if z > 0 and z < d - 1 else "#".repeat(w))
	return CombatGrid.from_rows(rows)


func test_the_wild_makes_camp_and_towns_and_houses_do_not() -> void:
	assert_true(CampSite.is_wild(Compendium.shared().get_entry("locations", "road_forest")), "a forest road")
	assert_true(CampSite.is_wild(Compendium.shared().get_entry("locations", "lake_zarovich")), "a lake shore")
	assert_true(CampSite.is_wild(Compendium.shared().get_entry("locations", "mount_baratok")), "a mountainside")
	assert_false(CampSite.is_wild(Compendium.shared().get_entry("locations", "village_of_barovia")), "a village")
	assert_false(CampSite.is_wild(Compendium.shared().get_entry("locations", "vallaki_blue_water_inn")), "an inn")
	assert_false(CampSite.is_wild(Compendium.shared().get_entry("locations", "death_house_ground")), "a house")
	assert_false(CampSite.is_wild(Compendium.shared().get_entry("locations", "yester_hill")), "a place that allows no rest")


func test_the_fire_goes_on_open_ground_near_the_party() -> void:
	var g := _open_grid(20, 16)
	var c := CampSite.find_center(g, Vector2i(10, 8), {}, 4)
	assert_true(c.x >= 0, "somewhere to camp in an open field")
	assert_true(g.distance_ft(c, 1, Vector2i(10, 8), 1) <= CampSite.REACH_FT, "within reach: %s" % c)
	for dy in range(-1, 2):
		for dx in range(-1, 2):
			assert_true(CampSite.open_square(g, c + Vector2i(dx, dy), 0, {}), "the fire's ring is clear")


func test_no_camp_where_nothing_is_open() -> void:
	var g := CombatGrid.from_rows(["#####", "#...#", "#####"])
	assert_eq(CampSite.find_center(g, Vector2i(2, 1), {}, 4), Vector2i(-1, -1), "a corridor has no room for a fire")


func test_the_camp_keeps_off_the_places_own_things_and_its_fights() -> void:
	var g := _open_grid(24, 18)
	var loc := {"props": [{"id": "well", "cell": [12, 9]}], "exits": [{"id": "out", "cell": [1, 9], "to": "x"}],
		"areas": [{"id": "ambush", "cells": [[14, 1], [22, 16]]}, {"id": "glade", "cells": [[1, 1], [10, 16]]}],
		"encounters": [{"id": "wolves", "trigger": "enter_area:ambush", "monsters": []}]}
	var taken := CampSite.things_at(loc)
	assert_true(taken.has(Vector2i(12, 9)), "the well's square")
	assert_true(taken.has(Vector2i(1, 9)), "the way out")
	assert_true(taken.has(Vector2i(18, 8)), "an area a fight starts in")
	assert_false(taken.has(Vector2i(5, 8)), "an area with only words to it")
	var c := CampSite.find_center(g, Vector2i(12, 8), taken, 4)
	assert_true(c.x >= 0 and c.x <= 12, "the fire stays out of the ambush: %s" % c)


func test_the_camps_pieces_and_seats() -> void:
	var g := _open_grid(24, 18)
	var c := Vector2i(12, 9)
	var lay := CampSite.layout(g, c, {}, 6, true)
	var models := {}
	for p: Dictionary in lay["props"]:
		models[str(p["model"])] = models.get(str(p["model"]), 0) + 1
		assert_true(bool(p["camp"]), "%s is the camp's" % p["id"])
	assert_eq(int(models.get("campfire", 0)), 1, "one fire")
	assert_eq(int(models.get("stewpot", 0)), 1, "the stew pot")
	assert_eq(int(models.get("bedroll", 0)), 6, "a bedroll each")
	assert_eq(int(models.get("tent", 0)), 1, "a tent at the back")
	assert_eq(lay["cook"], c + CampSite.COOK, "the cook at the pot")
	assert_eq((lay["seats"] as Array).size(), 5, "seats for the other five")
	var used := {}
	for p: Dictionary in lay["props"]:
		var at := Vector2i(int((p["cell"] as Array)[0]), int((p["cell"] as Array)[1]))
		assert_false(used.has(at), "one piece a square: %s" % p["id"])
		used[at] = true
	for s: Vector2i in lay["seats"]:
		assert_false(used.has(s), "nobody sits on a piece")
		assert_true(g.distance_ft(s, 1, c, 1) <= 10, "seats round the fire")


func test_a_cramped_camp_leaves_pieces_out() -> void:
	var g := _open_grid(7, 7)
	var lay := CampSite.layout(g, Vector2i(3, 3), {}, 4, false)
	assert_eq(lay["cook"], Vector2i(-1, -1), "nobody cooks without Ratatouille")
	for p: Dictionary in lay["props"]:
		assert_ne(str(p["model"]), "tent", "no room for the tent")


func test_who_asks_for_a_word_includes_those_waiting_at_camp() -> void:
	var st := StoryState.new()
	st.party.append(Pregens.build("godrick_pendlebrook", 3))
	var thistle := Pregens.build("thistle", 3)
	st.bench.append(thistle)
	st.set_flag("strahd_knelt", "thistle")
	assert_false(CampSite.talks(st, {}).has("thistle"), "away from camp, Thistle isn't here to ask")
	st.camp_company = CampSite.company(st)
	var talks := CampSite.talks(st, {})
	assert_eq(str(talks.get("thistle", "")), "camp/thistle:talk_knelt", "by the fire, she asks: %s" % [talks])
	assert_false(CampSite.talks(st, {"thistle": true}).has("thistle"), "one word each, this evening")
	thistle.dead = true
	assert_true(CampSite.company(st).is_empty(), "the dead aren't by the fire")
