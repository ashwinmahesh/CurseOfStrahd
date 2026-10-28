extends TestCase
## A road out of town that takes the party to a new area goes straight there (Ashwin, 2026-10-28: "In the overworld, when you
## go to an exit path that takes you to a new area, it should directly take you there instead of opening the map and letting
## you select where to go. Opening the map and clicking somewhere to go can have the existing behavior"). Every place one open
## road from here goes with the way out that faces it best (Travel.exit_places); a road out that is the way to just one place
## sets out for it, one that is the way to none or several still opens the map.

var root: Node
var _saved := {}


func before_each() -> void:
	var c := Compendium.shared()
	_saved = {"travel": (c.tables.get("travel", {}) as Dictionary).duplicate(), "random_encounters": (c.tables.get("random_encounters", {}) as Dictionary).duplicate()}
	GameState.reset()
	for id: String in ["ilse_varga", "tamsin_tealeaf", "hedda_ironvow", "silvain_aster"]:
		var ch := Pregens.build(id, 3)
		ch.finish_long_rest()
		GameState.story.party.append(ch)
	Dice.reseed(2)
	root = null


func after_each() -> void:
	var c := Compendium.shared()
	c.tables["travel"] = _saved["travel"]
	c.tables["random_encounters"] = _saved["random_encounters"]
	for id: String in ["test_hall", "test_town", "test_ambush"]:
		c.tables["locations"].erase(id)
	if root != null:
		root.queue_free()


func _frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame


func _exit(location: String, id: String) -> Dictionary:
	for e: Variant in Compendium.shared().get_entry("locations", location)["exits"]:
		if str((e as Dictionary)["id"]) == id:
			return e as Dictionary
	return {}


## Where the road out `id` of `location` goes, the party having been in `location`.
func _goes(location: String, id: String) -> String:
	GameState.story.visited[location] = true
	return Travel.exit_destination(Compendium.shared().get_entry("locations", location), _exit(location, id), GameState.story)


# --- Which way a road out faces, and which places it is the way to ---------------------------------

func test_a_road_out_faces_the_side_of_the_map_it_is_on() -> void:
	var loc := {"map": {"rows": ["##########", "#........#", "#.........", "#........#", "##########"]}}
	assert_eq(Travel.exit_facing(loc, {"cell": [9, 2]}), Vector2.RIGHT)
	assert_eq(Travel.exit_facing(loc, {"cell": [0, 2]}), Vector2.LEFT)
	assert_eq(Travel.exit_facing(loc, {"cell": [4, 0]}), Vector2.UP)
	assert_eq(Travel.exit_facing(loc, {"cell": [4, 4]}), Vector2.DOWN)
	var rows: Array[String] = ["#".repeat(20)]
	for i in 18:
		rows.append("#" + ".".repeat(18) + "#")
	rows.append("#".repeat(20))
	var big := {"map": {"rows": rows}}
	assert_eq(Travel.exit_facing(big, {"cell": [10, 9]}), Vector2.ZERO, "a door inside the map faces no side")


func test_the_crossroads_four_roads_each_go_straight_to_the_place_they_lead_to() -> void:
	assert_eq(_goes("svalich_crossroads", "road_east"), "village_of_barovia", "east to the village")
	assert_eq(_goes("svalich_crossroads", "road_west"), "tser_pool", "west to Tser Pool")
	assert_eq(_goes("svalich_crossroads", "castle_road"), "castle_ravenloft", "south to the castle")
	assert_eq(_goes("svalich_crossroads", "falls_track"), "tser_falls", "north to the falls")


func test_a_road_that_leads_to_more_than_one_place_is_still_a_choice() -> void:
	var st := GameState.story
	assert_eq(_goes("village_of_barovia", "road_west"), "", "the village's one road out is the way to the Gates and the crossroads both")
	assert_eq(_goes("tser_pool", "road_west"), "", "Vallaki and the knights' road both lie west")
	st.set_quest_stage("the_roadhouse_lantern", "rumored")
	assert_eq(_goes("svalich_crossroads", "road_east"), "", "and the Grey Goose beside the road to the village makes the road east one")
	assert_eq(_goes("svalich_crossroads", "road_west"), "tser_pool", "the other roads are as they were")


func test_a_dead_end_goes_back_the_only_way_it_can() -> void:
	assert_eq(_goes("abbey_of_st_markovia", "abbey_road"), "krezk", "the abbey road down to Krezk")
	assert_eq(_goes("old_bonegrinder_hill", "bonegrinder_track_down"), "", "a road with nowhere known to go is the map's to say")


func test_two_roads_along_one_road_each_go_their_own_way() -> void:
	var st := GameState.story
	st.set_quest_stage("the_waystone", "rumored")
	assert_eq(_goes("krezk_road_waystone", "waystone_road_west"), "krezk")
	assert_eq(_goes("krezk_road_waystone", "waystone_road_east"), "vallaki")


func test_every_open_place_is_the_way_of_some_road_out() -> void:
	# A road that goes straight is only fair if the map isn't the only way to a place: each place one open road away is the
	# way of at least one road out that can be used (the nearest to it), so a choice or a straight road reaches it.
	var st := GameState.story
	var missed: Array[String] = []
	for p: Variant in Travel.map_data()["places"]:
		st.visited[str((p as Dictionary)["location"]).get_slice(":", 0)] = true
	for p: Variant in Travel.map_data()["places"]:
		var pl := p as Dictionary
		var loc := Compendium.shared().get_entry("locations", str(pl["location"]).get_slice(":", 0))
		if loc.is_empty():
			continue
		var exits: Array[Dictionary] = []
		for e: Variant in loc.get("exits", []):
			var ex := e as Dictionary
			if str(ex["to"]) == "travel" and StoryConditions.check(str(ex.get("when", "")), st) and Travel.exit_facing(loc, ex) != Vector2.ZERO:
				exits.append(ex)
		if exits.is_empty():
			continue
		var reached := {}
		for ex in exits:
			for there in Travel.exit_places(loc, ex, st):
				reached[there] = true
		for there in Travel.neighbours(str(pl["id"]), st):
			if not reached.has(there):
				missed.append("%s -> %s" % [pl["id"], there])
	assert_eq(missed, [], "no place is left without a road out that goes there")


# --- Walking onto the road -------------------------------------------------------------------------

func _town() -> void:
	var c := Compendium.shared()
	var hall := {"id": "test_hall", "name": "Test Hall", "region": "test", "summary": "",
		"map": {"rows": ["#######", "#.....#", "#......", "#.....#", "#######"], "outdoors": true}, "spawns": {"default": [2, 2]},
		"exits": [{"id": "road", "cell": [6, 2], "to": "travel", "label": "The road"}]}
	c.tables["locations"]["test_hall"] = hall
	var town := hall.duplicate(true)
	town["id"] = "test_town"
	c.tables["locations"]["test_town"] = town
	c.tables["locations"]["test_ambush"] = {"id": "test_ambush", "name": "A Road", "region": "test", "summary": "",
		"map": {"rows": ["##########", "#........#", "#........#", "#........#", "##########"], "outdoors": true}, "spawns": {"default": [2, 2]}}
	c.tables["travel"] = {"barovia": {"id": "barovia", "name": "Test", "places": [
		{"id": "hall", "name": "Hall", "location": "test_hall", "pos": [0.2, 0.5], "region": "test"},
		{"id": "mid", "name": "Crossroads", "location": "test_ambush", "pos": [0.5, 0.5], "region": "test"},
		{"id": "town", "name": "Town", "location": "test_town", "pos": [0.8, 0.5], "region": "test", "when": "flag.heard_of_town"}],
		"roads": [{"id": "r1", "from": "hall", "to": "mid", "hours": 2, "table": "test_road"},
			{"id": "r2", "from": "mid", "to": "town", "hours": 3},
			{"id": "r3", "from": "hall", "to": "town", "hours": 9}]}}
	c.tables["random_encounters"] = {"test_road": {"id": "test_road", "map": "test_ambush", "chance_day": 0.0, "chance_night": 0.0,
		"entries": [{"weight": 1, "monsters": [{"monster": "wolf", "cell": [7, 2]}], "text": "Wolves."}]}}
	GameState.story.location = "test_hall"
	GameState.story.visited["test_hall"] = true
	root = (load("res://scenes/game.tscn") as PackedScene).instantiate()
	add_child(root)


func _view() -> LocationView:
	return root.get("view") as LocationView


func test_walking_onto_a_road_to_one_place_sets_out_for_it_without_the_map() -> void:
	_town()
	await _frames(3)
	var st := GameState.story
	var start := st.total_minutes()
	_view().walk_to(Vector2i(6, 2))
	for i in 400:
		if _view().loc_id == "test_ambush" or root.get("screen") is TravelScreen:
			break
		await get_tree().process_frame
	assert_false(root.get("screen") is TravelScreen, "no map to choose on")
	assert_eq(_view().loc_id, "test_ambush", "the party is on its way: the next place along the road")
	assert_eq(st.total_minutes() - start, 120, "two hours on the road, as from the map's Set out")


func test_a_road_to_two_places_opens_the_map_as_before() -> void:
	GameState.story.set_flag("heard_of_town", true)
	_town()
	await _frames(3)
	_view().walk_to(Vector2i(6, 2))
	for i in 400:
		if root.get("screen") is TravelScreen:
			break
		await get_tree().process_frame
	var map := root.get("screen") as TravelScreen
	assert_true(map != null, "the road out opens the map")
	if map == null:
		return
	assert_eq(_view().loc_id, "test_hall", "and nobody has set out")
	map.travel_chosen.emit("mid")
	map.queue_free()
	await _frames(6)
	assert_eq(_view().loc_id, "test_ambush", "a place clicked on the map is gone to, as before")
