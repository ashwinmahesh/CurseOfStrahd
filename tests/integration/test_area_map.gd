extends TestCase
## The map screen's local area view (Ashwin, 2026-10-25: "when you open map there should be a toggle for local area map which
## shows the full area map with exits named (where they go)"): a toggle beside the map of Barovia switches it to the whole
## place the party is in (ui/screens/area_map.gd), drawn from its grid with each way out marked and named by what it is
## and where it goes, and listed beside it. The choice is kept for the next map opened to look.

var root: Node
var _screens: Array[Node] = []
var _views: Array[Node] = []


func before_each() -> void:
	GameState.reset()
	for id: String in ["ilse_varga", "tamsin_tealeaf", "hedda_ironvow", "silvain_aster"]:
		var ch := Pregens.build(id, 3)
		ch.finish_long_rest()
		GameState.story.party.append(ch)
	Dice.reseed(4)
	GameSettings.set_value(TravelScreen.AREA_SETTING, false)
	root = null


func after_each() -> void:
	for n in _screens + _views:
		if is_instance_valid(n):
			n.queue_free()
	_screens.clear()
	_views.clear()
	if root != null:
		root.queue_free()
	GameSettings.set_value(TravelScreen.AREA_SETTING, false)
	Compendium.shared().tables["locations"].erase("test_yard")


func _frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame


func _view(id: String) -> LocationView:
	var st := GameState.story
	st.location = id
	var v := LocationView.create(id, st, Narrator.new(), Dice.roller, "default")
	add_child(v)
	_views.append(v)
	return v


func _screen(v: LocationView, here: String, setting_out: bool) -> TravelScreen:
	var t := TravelScreen.new()
	t.area_view = v
	add_child(t)
	_screens.append(t)
	t.open_map(GameState.story, here, setting_out)
	return t


func _button(n: Node, name: String) -> Button:
	return n.find_child(name, true, false) as Button


# --- What a way out is called ----------------------------------------------------------------------

func test_a_way_out_is_named_by_what_it_is_and_where_it_goes() -> void:
	var door := AreaMap.naming({"label": "Church", "to": "village_church", "destination": "Village Church"})
	assert_eq(str(door["title"]), "Church")
	assert_eq(str(door["goes"]), "Village Church", "a door says where it leads")
	var same := AreaMap.naming({"label": "Blood of the Vine", "to": "blood_of_the_vine", "destination": "Blood of the Vine"})
	assert_eq(str(same["goes"]), "", "nothing more to say when the name already does")
	var road := AreaMap.naming({"label": "The Old Svalich Road, west", "to": "travel", "destination": "Opens the travel map"})
	assert_eq(str(road["goes"]), "The map of Barovia", "a road that opens the travel map says so")


func test_neighbouring_ways_out_of_one_name_are_one() -> void:
	var list: Array[Dictionary] = []
	for e: Array in [["road_out", Vector2i(20, 31)], ["road_out_east", Vector2i(21, 31)], ["gate", Vector2i(5, 5)]]:
		list.append({"id": e[0], "cell": e[1], "label": "The road" if str(e[0]).begins_with("road") else "A gate", "to": "travel",
			"destination": "Opens the travel map", "region": true, "open": true, "dir": Vector2i(0, 1)})
	var groups := AreaMap.group_exits(list)
	assert_eq(groups.size(), 2, "the two squares of the road are one way out")
	assert_eq((groups[0]["cells"] as Array[Vector2i]).size(), 2)
	assert_eq((groups[0]["ids"] as Array[String]).size(), 2)
	list[2]["label"] = "The road"
	assert_eq(AreaMap.group_exits(list).size(), 2, "but not one far away with the same name")


# --- The area drawn --------------------------------------------------------------------------------

func test_the_whole_area_fits_the_panel_with_each_way_out_marked() -> void:
	var v := _view("village_of_barovia")
	var map := AreaMap.new()
	map.custom_minimum_size = TravelScreen.MAP_SIZE
	add_child(map)
	_screens.append(map)
	map.show_area(v)
	var ids: Array[String] = []
	for g in map.exits:
		ids.append(str(g["id"]))
	for want: String in ["church_door", "tavern_door", "road_east", "road_west", "death_house_door"]:
		assert_true(want in ids, "%s is a way out on the map: %s" % [want, ids])
	var panel := Rect2(Vector2.ZERO, TravelScreen.MAP_SIZE)
	var grid := LocationView.grid_for(v.loc)
	assert_true(panel.encloses(Rect2(map.to_panel(Vector2.ZERO), Vector2(grid.width, grid.depth) * map.cell_px())), "the whole place is in view")
	var church := map.exit_named("church_door")
	assert_eq(str(church["goes"]), "Village Church")
	assert_true(bool(church["open"]))
	assert_false(bool(map.exit_named("road_west")["open"]), "shut for now: the village isn't done with")
	assert_eq(str(map.exit_named("road_west")["goes"]), "The map of Barovia")
	assert_eq(map.exit_under(map.exit_at_panel(church)), "church_door", "pointing at its mark finds it")
	assert_eq(map.exit_under(Vector2(5, 5)), "", "and nothing at an empty corner")


func test_the_area_zooms_and_pans_within_its_edges() -> void:
	var v := _view("village_of_barovia")
	var map := AreaMap.new()
	map.custom_minimum_size = TravelScreen.MAP_SIZE
	add_child(map)
	_screens.append(map)
	map.show_area(v)
	var panel := TravelScreen.MAP_SIZE
	var spot := Vector2(500, 300)
	var cell_before := map.cell_at(spot)
	map.zoom_at(spot, 2.0)
	assert_eq(map.zoom, 2.0)
	assert_eq(map.cell_at(spot), cell_before, "zooming keeps the square under the pointer where it is")
	map.zoom_at(spot, 100.0)
	assert_eq(map.zoom, AreaMap.ZOOM_MAX, "zoom stops")
	map.pan = Vector2(9999, 9999)
	map.zoom_at(spot, 1.0)
	assert_true(map.pan.x <= AreaMap.MARGIN.x and map.pan.y <= AreaMap.MARGIN.y, "the area can't be dragged off into the corner")
	map.zoom_at(spot, 0.0001)
	assert_eq(map.zoom, 1.0, "and never less than the whole place")
	var grid := LocationView.grid_for(v.loc)
	var area := Vector2(grid.width, grid.depth) * map.cell_px()
	assert_true(absf(map.pan.x - (panel.x - area.x) / 2.0) < 0.5, "centred again at zoom 1")


func test_the_pad_steps_from_way_out_to_way_out() -> void:
	var v := _view("village_of_barovia")
	var map := AreaMap.new()
	map.custom_minimum_size = TravelScreen.MAP_SIZE
	add_child(map)
	_screens.append(map)
	map.show_area(v)
	assert_true(map.pad_step(Vector2i.RIGHT), "with none lit, the first")
	var first := map.hover
	assert_true(first != "")
	var seen := {first: true}
	for i in 12:
		if map.pad_step(Vector2i.RIGHT) or map.pad_step(Vector2i.DOWN):
			seen[map.hover] = true
	assert_true(seen.size() >= 3, "it goes on to others: %s" % [seen.keys()])
	map.pad_pick()
	assert_eq(map.selected, map.hover, "A picks the one lit")


# --- The toggle on the map screen ------------------------------------------------------------------

func test_the_map_offers_the_local_area_beside_the_valley() -> void:
	var v := _view("village_of_barovia")
	var t := _screen(v, "village_of_barovia", false)
	await _frames(2)
	assert_false(t.area_mode, "it opens on the valley")
	assert_true(_button(t, "Barovia") != null and _button(t, "LocalArea") != null, "with the toggle beside it")
	assert_true((t.get("_map") as Control).visible)
	_button(t, "LocalArea").pressed.emit()
	await _frames(2)
	assert_true(t.area_mode)
	assert_false((t.get("_map") as Control).visible, "the valley gives way")
	var area := t.get("_area") as AreaMap
	assert_true(area.visible and area.exits.size() >= 5, "to the area and its ways out")
	assert_true(t.find_child("WaysOut", true, false) != null, "listed at the side")
	var church := _button(t, "Exit_church_door")
	assert_true(church != null and church.text.contains("Village Church"), "each says where it goes")
	church.mouse_entered.emit()
	assert_eq(area.hover, "church_door", "pointing at the list lights it on the map")
	church.pressed.emit()
	assert_eq(area.selected, "church_door", "and a click picks it")
	assert_true(_button(t, "Exit_road_west").text.contains("shut for now"), "a shut way says so")
	_button(t, "Barovia").pressed.emit()
	await _frames(2)
	assert_false(t.area_mode)
	assert_true((t.get("_map") as Control).visible and not area.visible, "back to the valley")


func test_a_map_opened_to_look_remembers_the_view_and_one_to_set_out_is_the_valley() -> void:
	var v := _view("village_of_barovia")
	var first := _screen(v, "village_of_barovia", false)
	first.set_area_mode(true)
	assert_true(bool(GameSettings.value(TravelScreen.AREA_SETTING, false)), "kept")
	first.queue_free()
	await _frames(2)
	var again := _screen(v, "village_of_barovia", false)
	assert_true(again.area_mode, "the next map opened to look is on the area")
	var setting_out := _screen(v, "village_of_barovia", true)
	assert_false(setting_out.area_mode, "setting out starts on the valley, where the places are")
	setting_out.set_area_mode(true)
	assert_true(setting_out.area_mode, "but the area can still be looked at")
	await _frames(1)
	assert_true(_button(setting_out, "Barovia") != null, "and the valley is one press away")


func test_no_toggle_where_there_is_no_place() -> void:
	var t := TravelScreen.new()
	add_child(t)
	_screens.append(t)
	t.open_map(GameState.story, "gates_of_barovia", false)
	await _frames(1)
	assert_true(_button(t, "LocalArea") == null, "a map with no place under it is only the valley")
	t.set_area_mode(true)
	assert_false(t.area_mode, "and can't be switched")


func test_m_in_a_place_opens_the_map_with_that_place_on_offer() -> void:
	var c := Compendium.shared()
	c.tables["locations"]["test_yard"] = {"id": "test_yard", "name": "Test Yard", "region": "test", "summary": "",
		"map": {"rows": ["##########", "#........#", "#...##...#", "#........#", "#.........", "##########"], "outdoors": true,
			"theme": "village"},
		"spawns": {"default": [2, 1]}, "areas": [{"id": "yard", "name": "The yard", "cells": [[1, 1], [8, 4]]}],
		"exits": [{"id": "road", "cell": [9, 4], "to": "travel", "label": "The road"}]}
	GameState.story.location = "test_yard"
	GameState.story.visited["test_yard"] = true
	root = (load("res://scenes/game.tscn") as PackedScene).instantiate()
	add_child(root)
	await _frames(3)
	root.call("open_travel", false)
	await _frames(2)
	var t := root.get("screen") as TravelScreen
	assert_true(t != null, "the map is open")
	if t == null:
		return
	assert_true(t.area_view == root.get("view"), "of the place the party is in")
	_button(t, "LocalArea").pressed.emit()
	await _frames(2)
	var area := t.get("_area") as AreaMap
	assert_eq(area.exits.size(), 1)
	assert_eq(str(area.exits[0]["label"]), "The road")
	assert_eq(str(area.exits[0]["goes"]), "The map of Barovia")
	root.call("close_screen")
