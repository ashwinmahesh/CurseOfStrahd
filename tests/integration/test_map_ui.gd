extends TestCase
## The travel map and the minimap (owner ask 2026-10-06): the map of Barovia is a sharp illustrated sheet with the
## known places on it, zooming and panning without leaving the art; the minimap shows the current location north up
## and keeps the party in its middle; ways out to other regions are marked, and doors into buildings are not; rooms
## behind secret doors stay out of the level view and off the minimap until the door is found; the travel map shows
## only places the party has been, one road from there or heard of, with mist over the rest.

var root: Node


func before_each() -> void:
	GameState.reset()
	for id: String in ["ilse_varga", "tamsin_tealeaf", "hedda_ironvow", "silvain_aster"]:
		var ch := Pregens.build(id, 3)
		ch.finish_long_rest()
		GameState.story.party.append(ch)
	Dice.reseed(4)
	root = null


func after_each() -> void:
	if root != null:
		root.queue_free()
	Compendium.shared().tables["locations"].erase("test_yard")


func _frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame


func test_the_map_art_is_sharp_and_every_place_is_on_it() -> void:
	var art := TravelScreen.MAP_ART as Texture2D
	assert_true(absf(float(art.get_width()) / art.get_height() - TravelScreen.MAP_SIZE.x / TravelScreen.MAP_SIZE.y) < 0.02,
		"the art has the panel's shape, so places land where they're drawn")
	assert_true(art.get_width() >= TravelScreen.MAP_SIZE.x * 2.0, "big enough to zoom in without blurring")
	assert_true(art.get_image().has_mipmaps(), "imported with mipmaps, so it shrinks cleanly when zoomed out")
	for p: Variant in Travel.map_data()["places"]:
		var pos := (p as Dictionary)["pos"] as Array
		for v: Variant in pos:
			assert_between(float(v), 0.05, 0.95, "%s sits inside the valley, clear of the mist at the edge" % (p as Dictionary)["id"])


func test_the_map_opens_on_what_the_party_knows_and_zooms_within_the_art() -> void:
	var st := GameState.story
	st.location = "into_the_mists_road"
	st.visited["into_the_mists_road"] = true
	st.visited["tser_pool"] = true   # Vallaki is one road from Tser Pool, so it's on the map
	var t := TravelScreen.new()
	add_child(t)
	t.open_map(st, "gates_of_barovia", true)
	assert_between(t.zoom, 1.0, TravelScreen.ZOOM_OPEN_MAX, "zoomed in on the known places, never too far")
	var panel := Rect2(Vector2.ZERO, TravelScreen.MAP_SIZE)
	for p in Travel.known(st):
		var at := t.to_panel(Vector2(float((p["pos"] as Array)[0]), float((p["pos"] as Array)[1])))
		assert_true(panel.has_point(at), "%s is in view when the map opens" % p["id"])
	var mid := TravelScreen.MAP_SIZE / 2.0
	t.zoom_at(mid, 50.0)
	assert_eq(t.zoom, TravelScreen.ZOOM_MAX, "zoom stops at the art's own detail")
	t.zoom_at(Vector2(30, 30), 0.001)
	assert_eq(t.zoom, 1.0, "and never shows less than the whole valley")
	assert_eq(t.pan, Vector2.ZERO, "the art always covers the panel")
	var via := t.road_points({"id": "round_the_lake", "via": [[0.2, 0.53]]}, t.to_panel(Vector2(0.32, 0.48)), t.to_panel(Vector2(0.075, 0.48)))
	var bend := t.to_panel(Vector2(0.2, 0.53))
	assert_true(Array(via).any(func(q: Vector2) -> bool: return q.distance_to(bend) < 1.0), "a road with via points goes through them")
	t.select("vallaki")
	await _frames(2)
	var go := t.find_child("SetOut", true, false) as Button
	assert_true(go != null and not go.disabled, "a known road to Vallaki: set out")
	t.queue_free()
	var look := TravelScreen.new()
	add_child(look)
	look.open_map(st, "", false)
	look.select("vallaki")
	await _frames(2)
	go = look.find_child("SetOut", true, false) as Button
	assert_true(go == null or go.disabled, "just looking (M): no setting out")
	look.queue_free()


func test_ways_out_to_other_regions_are_marked_and_doors_are_not() -> void:
	var st := GameState.story
	var village := LocationView.create("village_of_barovia", st, Narrator.new(), Dice.roller, "default")
	add_child(village)
	var by_id := {}
	for e in ExitSigns.ways_out(village):
		by_id[str(e["id"])] = e
	assert_true(bool((by_id["road_east"] as Dictionary)["region"]), "the road east to the gates is a way to another region")
	assert_true(bool((by_id["road_west"] as Dictionary)["region"]), "the road west opens the map")
	assert_false(bool((by_id["road_west"] as Dictionary)["open"]), "shut until the village is done with")
	assert_false(bool((by_id["tavern_door"] as Dictionary)["region"]), "the tavern door is a door, not a road")
	assert_eq((by_id["road_west"] as Dictionary)["dir"], Vector2i(-1, 0), "the west road leads off the west edge")
	assert_eq((by_id["road_east"] as Dictionary)["dir"], Vector2i(1, 0))
	village.queue_free()
	var road := LocationView.create("into_the_mists_road", st, Narrator.new(), Dice.roller, "default")
	add_child(road)
	var outs := ExitSigns.ways_out(road)
	assert_eq(outs.size(), 1)
	assert_true(bool(outs[0]["region"]) and bool(outs[0]["open"]), "the opening road's way into the village is marked")
	assert_eq(str(outs[0]["destination"]), "Village of Barovia", "and names where it goes")
	road.queue_free()
	var abbey := LocationView.create("abbey_of_st_markovia", st, Narrator.new(), Dice.roller, "default")
	add_child(abbey)
	for e in ExitSigns.ways_out(abbey):
		if str(e["id"]) == "garden_door":
			assert_eq(e["dir"], Vector2i.ZERO, "a gate inside the map gets no arrow pointing off an edge")
	abbey.queue_free()


func test_the_minimap_follows_the_party_north_up() -> void:
	var c := Compendium.shared()
	c.tables["locations"]["test_yard"] = {"id": "test_yard", "name": "Test Yard", "region": "test", "summary": "",
		"map": {"rows": ["##########", "#........#", "#...##...#", "#........#", "#.........", "##########"], "outdoors": true,
			"theme": "village"},
		"spawns": {"default": [2, 1]},
		"exits": [{"id": "road", "cell": [9, 4], "to": "travel", "label": "The road"}]}
	GameState.story.location = "test_yard"
	GameState.story.visited["test_yard"] = true
	root = (load("res://scenes/game.tscn") as PackedScene).instantiate()
	add_child(root)
	await _frames(3)
	var view := root.get("view") as LocationView
	var map := (root.get("hud") as ExploreHud).minimap
	assert_true(map.view == view, "the minimap shows the location the party is in")
	assert_eq(map.ways_out.size(), 1)
	assert_true(bool(map.ways_out[0]["region"]), "the road out is marked")
	assert_eq(map.cell_at(map.size / 2.0), view.leader().cell, "the leader is in the middle")
	assert_true(map.to_map(Vector2(5, 0)).y < map.to_map(Vector2(5, 5)).y, "north is up")
	view.walk_to(Vector2i(7, 3))
	for i in 120:
		if not view.busy and view.leader().cell == Vector2i(7, 3):
			break
		await get_tree().process_frame
	for i in 600:
		if map.cell_at(map.size / 2.0) == Vector2i(7, 3):
			break
		await get_tree().process_frame
	assert_eq(view.leader().cell, Vector2i(7, 3))
	assert_eq(map.cell_at(map.size / 2.0), Vector2i(7, 3), "and stays there as the party walks")


func test_a_room_behind_a_secret_door_stays_hidden_until_found() -> void:
	var st := GameState.story
	st.location = "vallaki_wachter_house"
	st.visited["vallaki_wachter_house"] = true
	root = (load("res://scenes/game.tscn") as PackedScene).instantiate()
	add_child(root)
	await _frames(3)
	var view := root.get("view") as LocationView
	var areas := HiddenAreas.of(view)
	var shrine := Vector2i(14, 15)
	assert_true(areas != null and areas.is_hidden(shrine), "the cellar behind the panel is hidden")
	assert_false(areas.is_hidden(Vector2i(10, 9)), "the study in front of it is not")
	assert_false(areas.is_hidden(Vector2i(11, 13)), "nor the panel, which looks like wall")
	assert_true(view.thing_at(shrine).is_empty(), "nothing to hover or click down there yet")
	var prop := view.prop_nodes.get("dark_shrine") as Node3D
	assert_true(prop != null and not prop.visible, "the shrine isn't drawn")
	var map := (root.get("hud") as ExploreHud).minimap
	assert_true(map.cell_at(map.size / 2.0) == view.leader().cell and map.get("_hidden").has(shrine), "or on the minimap")
	(st.loc_state("vallaki_wachter_house")["found"] as Dictionary)["cellar_panel"] = true
	await _frames(30)
	assert_false(areas.is_hidden(shrine), "found: the cellar comes into sight")
	assert_true(prop.visible, "the shrine fades in")
	assert_false(map.get("_hidden").has(shrine), "and onto the minimap")
	assert_false(view.thing_at(shrine).is_empty())


func test_the_map_shows_the_next_stop_and_mist_over_the_rest() -> void:
	var st := GameState.story
	st.location = "into_the_mists_road"
	st.visited["into_the_mists_road"] = true
	var ids := func() -> Array: return Travel.known(st).map(func(p: Dictionary) -> String: return str(p["id"]))
	assert_eq(ids.call(), ["gates_of_barovia", "village_of_barovia"], "at the gates: the gates, and the village one road on")
	st.visited["village_of_barovia"] = true
	assert_true(ids.call().has("svalich_crossroads"), "from the village, the crossroads")
	assert_false(ids.call().has("vallaki"), "Vallaki isn't on the map until the party is one road from it")
	assert_false(ids.call().has("old_bonegrinder"), "a place with a condition waits for it, however close")
	st.set_flag("bonegrinder_rumor", true)
	assert_true(ids.call().has("old_bonegrinder"), "heard of: on the map")
	var t := TravelScreen.new()
	add_child(t)
	t.open_map(st, "village_of_barovia", false)
	assert_true(t.clear_at(Vector2(0.775, 0.51)) > 0.9, "the village is clear")
	assert_true(t.clear_at(Vector2(0.71, 0.52)) > 0.5, "and the road to the crossroads")
	assert_true(t.clear_at(Vector2(0.075, 0.48)) < 0.05, "Krezk is under the mist")
	assert_true(t.clear_at(Vector2(0.411, 0.139)) < 0.05, "and the Amber Temple")
	assert_true(t.clear_at(Vector2(0.695, 0.73)) > 0.9, "the castle on its cliff is seen from everywhere")
	t.queue_free()


## The roads a journey takes read as one line (UI QA, 2026-10-08: "By The lake road west").
func test_the_route_line_reads_as_a_sentence() -> void:
	assert_eq(TravelScreen.route_line(["The lake road west, and the lane up through the vines"] as Array[String]),
		"By the lake road west, and the lane up through the vines")
	assert_eq(TravelScreen.route_line(["Old Svalich Road", "The castle road, climbing south through the dead pines"] as Array[String]),
		"By Old Svalich Road, then the castle road, climbing south through the dead pines")
	assert_eq(TravelScreen.route_line(["By boat to the north shore, then the wolf trail"] as Array[String]),
		"By boat to the north shore, then the wolf trail", "no second By")
	assert_eq(TravelScreen.route_line(["Down the miller's lane", "The river track"] as Array[String]),
		"Down the miller's lane, then the river track")
	for f in DirAccess.get_files_at("res://data/travel"):
		if not f.ends_with(".json"):
			continue
		var text := FileAccess.get_file_as_string("res://data/travel/" + f)
		for m in RegEx.create_from_string("\"name\": \"((?:The|By|Down|Up) [^\"]+)\"").search_all(text):
			var line := TravelScreen.route_line([m.get_string(1)] as Array[String])
			assert_false(line.contains("By The") or line.contains("By By") or line.contains("By Down"), line)
