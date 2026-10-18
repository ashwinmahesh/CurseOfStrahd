extends TestCase
## Where and how the party makes camp (story/camp_site.gd, F16): which places, the fire's square, the camp's pieces and
## seats, and who has a word to say by the fire.


func _open_grid(w: int, d: int) -> CombatGrid:
	var rows: Array = []
	for z in d:
		rows.append("#" + ".".repeat(w - 2) + "#" if z > 0 and z < d - 1 else "#".repeat(w))
	return CombatGrid.from_rows(rows)


func _loc(id: String) -> Dictionary:
	return Compendium.shared().get_entry("locations", id)


func test_camp_is_made_wherever_the_places_own_rest_is_risky() -> void:
	for id: String in ["road_forest", "lake_zarovich", "mount_baratok", "village_of_barovia", "vallaki",
			"death_house_ground", "burgomaster_mansion", "castle_ravenloft_catacombs", "argynvostholt_hall"]:
		assert_true(CampSite.makes_camp(_loc(id)), "%s makes camp" % id)
	# A safe place keeps the rest screen: the inns, the Krezkovs' house, the Mad Mage's hut, the tower, the winery,
	# Tser Pool's camp and the Pool of the White Sun.
	for id: String in ["vallaki_blue_water_inn", "blood_of_the_vine", "wizard_of_wines_winery", "krezk_burgomaster_house",
			"mount_baratok_hut", "van_richtens_tower_interior", "tser_pool", "krezk_pool_of_the_white_sun"]:
		assert_false(CampSite.makes_camp(_loc(id)), "%s is safe: the rest screen" % id)
	assert_false(CampSite.makes_camp(_loc("yester_hill_gulthias_tree")), "a place that allows no rest")


func test_where_a_camp_is() -> void:
	assert_eq(CampSite.setting(_loc("road_forest")), CampSite.WILD, "a forest road")
	assert_eq(CampSite.setting(_loc("lake_zarovich")), CampSite.WILD, "a lake shore")
	assert_eq(CampSite.setting(_loc("village_of_barovia")), CampSite.TOWN, "a village street")
	assert_eq(CampSite.setting(_loc("vallaki")), CampSite.TOWN, "Vallaki")
	assert_eq(CampSite.setting(_loc("death_house_ground")), CampSite.INDOORS, "a house")
	assert_eq(CampSite.setting(_loc("castle_ravenloft_catacombs")), CampSite.INDOORS, "a dungeon")
	assert_eq(CampSite.keys_for("camp:pitch", CampSite.INDOORS), ["camp:pitch:indoors", "camp:pitch"] as Array[String])
	assert_eq(CampSite.idle_keys("thistle", false, CampSite.TOWN),
		["camp:thistle:town", "camp:thistle", "camp:someone:town", "camp:someone"] as Array[String])
	assert_eq(CampSite.idle_keys("ireena", true), ["camp:guest:ireena:wild", "camp:guest:ireena", "camp:guest:wild", "camp:guest"] as Array[String])


func test_the_fire_goes_on_open_ground_near_the_party() -> void:
	var g := _open_grid(20, 16)
	var c := CampSite.find_center(g, Vector2i(10, 8), {}, 4)
	assert_true(c.x >= 0, "somewhere to camp in an open field")
	assert_true(g.distance_ft(c, 1, Vector2i(10, 8), 1) <= CampSite.REACH_FT, "within reach: %s" % c)
	for dy in range(-1, 2):
		for dx in range(-1, 2):
			assert_true(CampSite.open_square(g, c + Vector2i(dx, dy), 0, {}), "the fire's ring is clear")


func test_no_camp_where_no_square_will_take_a_fire() -> void:
	var g := CombatGrid.from_rows(["#####", "#~~~#", "#####"])
	assert_eq(CampSite.find_center(g, Vector2i(2, 1), {}, 4), Vector2i(-1, -1), "rubble everywhere: no fire")
	var g2 := CombatGrid.from_rows(["#####", "#...#", "#####"])
	var all := {Vector2i(1, 1): true, Vector2i(2, 1): true, Vector2i(3, 1): true}
	assert_eq(CampSite.find_center(g2, Vector2i(2, 1), all, 4), Vector2i(-1, -1), "every square is the place's own")


func test_a_cramped_place_makes_a_smaller_camp() -> void:
	var g := CombatGrid.from_rows(["###########", "#.........#", "###########"])
	var c := CampSite.find_center(g, Vector2i(1, 1), {}, 5)
	assert_true(c.x >= 1 and c.y == 1, "a fire in the passage: %s" % c)
	var lay := CampSite.layout(g, c, {}, 5, false, false)
	var seats := lay["seats"] as Array
	assert_eq(seats.size(), 5, "everyone has somewhere to sit or stand: %s" % [seats])
	var used := {}
	for p: Dictionary in lay["props"]:
		used[Vector2i(int((p["cell"] as Array)[0]), int((p["cell"] as Array)[1]))] = true
	assert_true(used.has(c), "the fire")
	for s: Vector2i in seats:
		assert_true(g.flags(s) & CombatGrid.WALL == 0, "nobody in a wall: %s" % s)
		assert_false(used.has(s), "nobody on the fire, on a piece or on someone else: %s" % s)
		used[s] = true


func test_with_no_room_near_the_party_the_camp_goes_further_off() -> void:
	# A passage from the party's end of it to a hall well beyond 40 ft away.
	var rows: Array = []
	for z in 11:
		var row := ""
		for x in 30:
			var hall := x >= 19 and x <= 28 and z >= 1 and z <= 9
			row += "." if hall or (z == 5 and x >= 1 and x <= 18) else "#"
		rows.append(row)
	var g := CombatGrid.from_rows(rows)
	var c := CampSite.find_center(g, Vector2i(1, 5), {}, 4)
	assert_true(c.x >= 19, "the fire goes in the hall, beyond the passage: %s" % c)
	for dy in range(-1, 2):
		for dx in range(-1, 2):
			assert_true(CampSite.open_square(g, c + Vector2i(dx, dy), 0, {}), "a whole camp there")


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


func test_no_tent_indoors() -> void:
	var g := _open_grid(24, 18)
	var lay := CampSite.layout(g, Vector2i(12, 9), {}, 4, true, false)
	var models: Array[String] = []
	for p: Dictionary in lay["props"]:
		models.append(str(p["model"]))
	assert_false("tent" in models, "no tent under a roof: %s" % [models])
	assert_true("campfire" in models and "stewpot" in models and "woodpile" in models and "bedroll" in models, "the rest as ever")


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


func test_companions_retired_from_the_roster_never_come_to_the_fire() -> void:
	var st := StoryState.new()
	st.party.append(Pregens.build("godrick_pendlebrook", 3))
	st.bench.append(Pregens.build("tamsin_tealeaf", 3))   # one of the original four, kept for old saves only
	st.bench.append(Pregens.build("kip_smudgewick", 3))
	var ids := CampSite.company(st).map(func(ch: Character) -> String: return ch.id)
	assert_eq(ids, ["kip_smudgewick"], "Kip comes to the fire; Tamsin, retired, doesn't")


func test_night_visitors_fit_the_place() -> void:
	assert_eq(CampSite.land_of("svalich_road"), "forest", "the wild goes by the region")
	assert_eq(CampSite.land_of("svalich_road", CampSite.TOWN), "town", "a town's streets have their own")
	assert_eq(CampSite.land_of("castle_ravenloft", CampSite.INDOORS), "indoors", "and so does a roof")
	for where: String in [CampSite.TOWN, CampSite.INDOORS]:
		for level in range(1, StoryState.LEVEL_CAP + 1):
			var groups := CampSite.groups_for("village_of_barovia", level, where)
			assert_false(groups.is_empty(), "something comes for a level %d camp %s" % [level, where])
			for g: Dictionary in groups:
				if where == CampSite.INDOORS:
					assert_false("wolf" in g["monsters"] or "dire_wolf" in g["monsters"], "no wolf pack inside a house: %s" % g["id"])


## A story ally travelling with the party asks for a word like a companion does (docs/story/camp.md): the talk's
## condition names `guest:<npc>`, and the camp seats her by her creature's id.
const GUEST_TALKS := """
~ talk_first
if guest:ireena
Ireena: A first word.
endif

~ talk_second
if guest:ireena
Ireena: A second.
endif
"""


func _with_ireena() -> StoryState:
	var st := StoryState.new()
	st.party.append(Pregens.build("godrick_pendlebrook", 3))
	st.party.append(Pregens.build("thistle", 3))
	assert_true(st.add_guest("ireena"), "Ireena joins")
	return st


func test_a_guest_is_named_by_the_talks_condition() -> void:
	var st := StoryState.new()
	st.party.append(Pregens.build("godrick_pendlebrook", 3))
	assert_true(CampTalk.who_asks("guest:ireena", st).is_empty(), "Ireena isn't along, so nobody asks")
	assert_eq(CampTalk.label_for("guest:ireena", st), "Someone wants a word")
	assert_true(st.add_guest("ireena"))
	var who := CampTalk.who_asks("guest:ireena and flag.ireena_met", st)
	assert_eq(str(who["id"]), "guest_ireena", "the camp seats a guest by her creature's id (LocationCamp.people)")
	assert_eq(str(who["id"]), st.guests[0].id)
	assert_eq(CampTalk.label_for("guest:ireena", st), "Ireena wants a word", "by her first name")
	st.remove_guest("ireena")
	assert_true(CampTalk.who_asks("guest:ireena", st).is_empty(), "sent home, she asks no more")


func test_the_first_one_a_condition_names_who_is_here_asks() -> void:
	var st := _with_ireena()
	assert_eq(str(CampTalk.who_asks("name:thistle and guest:ireena", st)["id"]), "thistle", "the one named first")
	assert_eq(str(CampTalk.who_asks("guest:ireena and name:thistle", st)["id"]), "guest_ireena", "so write the asker first")
	assert_eq(str(CampTalk.who_asks("name:kip_smudgewick or guest:ireena", st)["id"]), "guest_ireena", "one who isn't here is passed over")
	assert_eq(str(CampTalk.who_asks("guest:ismark and name:thistle", st)["id"]), "thistle", "so is a guest who isn't along")
	assert_eq(CampTalk.label_for("name:thistle and guest:ireena", st), "Thistle wants a word")


func test_a_talk_naming_a_guest_is_offered_while_she_is_along() -> void:
	var df := DialogueFile.parse(GUEST_TALKS, "test/camp_guest")
	assert_true(df.errors.is_empty(), "the fixture parses: %s" % [df.errors])
	DialogueFile.register(df)
	var st := StoryState.new()
	st.party.append(Pregens.build("godrick_pendlebrook", 3))
	assert_true(CampTalk.offered(df, st).is_empty(), "no Ireena, no word")
	assert_eq(CampSite.asker(st, "test/camp_guest:talk_first"), "", "nobody here to ask it")
	assert_true(st.add_guest("ireena"))
	var talk := CampTalk.offered(df, st)
	assert_eq(str(talk["ref"]), "test/camp_guest:talk_first")
	assert_eq(str(talk["label"]), "Ireena wants a word")
	assert_eq(CampSite.asker(st, str(talk["ref"])), "guest_ireena", "she is the one to walk up to")
	CampTalk.mark(st, str(talk["ref"]))
	assert_eq(str(CampTalk.offered(df, st)["ref"]), "test/camp_guest:talk_second", "a talk plays once; the next waits its turn")
	CampTalk.mark(st, "test/camp_guest:talk_second")
	assert_true(CampTalk.offered(df, st).is_empty(), "and when they have all been had, she has nothing more to say")
