extends TestCase
## The travel map and the minimap (owner ask 2026-10-06): the map of Barovia is a sharp illustrated sheet with the
## known places on it, zooming and panning without leaving the art; the minimap shows the current location north up
## and keeps the party in its middle; ways out to other regions are marked, and doors into buildings are not.

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
