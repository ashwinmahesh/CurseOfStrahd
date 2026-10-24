extends TestCase
## The road south from the Ivlis crossroads to Castle Ravenloft (held ask of 2026-10-23). The crossroads' `castle_road` exit
## was a Phase 5 placeholder shut with `"when": "false"` until the castle was built, and stayed shut after it was, so no party
## could walk south to it. It is an ordinary road out now, like the castle's own `road_out`.

const CROSSROADS := "svalich_crossroads"
const GATES := "castle_ravenloft_gates"


func _loc(id: String) -> Dictionary:
	return Compendium.shared().get_entry("locations", id)


func _exit(loc_id: String, exit_id: String) -> Dictionary:
	for e: Variant in _loc(loc_id)["exits"]:
		if str((e as Dictionary)["id"]) == exit_id:
			return e as Dictionary
	return {}


func _cell(v: Variant) -> Vector2i:
	return Vector2i(int((v as Array)[0]), int((v as Array)[1]))


## The squares reachable on foot (four ways) from `from`.
func _reach(rows: Array, from: Vector2i) -> Dictionary:
	var seen := {from: true}
	var todo: Array[Vector2i] = [from]
	while not todo.is_empty():
		var c: Vector2i = todo.pop_back()
		for d: Vector2i in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			var n := c + d
			if n.y < 0 or n.y >= rows.size() or n.x < 0 or n.x >= str(rows[n.y]).length() or seen.has(n):
				continue
			if str(rows[n.y])[n.x] in ["#", " ", "w"]:
				continue
			seen[n] = true
			todo.append(n)
	return seen


func test_the_castle_road_is_an_open_exit_to_the_map() -> void:
	var road := _exit(CROSSROADS, "castle_road")
	assert_false(road.is_empty(), "the crossroads has the castle road")
	assert_eq(str(road["to"]), "travel", "it opens the map like the other roads out")
	assert_false(road.has("when"), "with no condition on it")
	assert_false(road.has("locked_text"), "and no barred-way line")
	assert_true(StoryConditions.check(str(road.get("when", "")), StoryState.new()), "so a party with nothing done yet can take it")


func test_the_castle_roads_exit_can_be_walked_to_from_where_the_party_arrives() -> void:
	var loc := _loc(CROSSROADS)
	var rows := (loc["map"] as Dictionary)["rows"] as Array
	var reach := _reach(rows, _cell((loc["spawns"] as Dictionary)["default"]))
	assert_true(reach.has(_cell(_exit(CROSSROADS, "castle_road")["cell"])), "the road's last square is on the walk")


## Standing at the crossroads, the party knows the castle is a road away and the quickest way there is that road alone.
func test_the_map_offers_the_castle_from_the_crossroads() -> void:
	var st := StoryState.new()
	st.visited[CROSSROADS] = true
	var ids: Array[String] = []
	for p: Dictionary in Travel.known(st):
		ids.append(str(p["id"]))
	assert_true("castle_ravenloft" in ids, "Castle Ravenloft is on the map from the crossroads: %s" % [ids])
	var legs := Travel.route("svalich_crossroads", "castle_ravenloft", st)
	assert_eq(legs.size(), 1, "one leg")
	assert_eq(str((legs[0]["road"] as Dictionary)["id"]), "crossroads_to_castle_ravenloft")
	var place := Travel.place("castle_ravenloft")
	assert_eq(str(place["location"]), GATES, "it lands at the castle's gates")
	assert_true((_loc(GATES)["spawns"] as Dictionary).has(str(place["spawn"])), "on a spawn the gates have")


func test_the_castles_own_road_out_is_open_too() -> void:
	for id: String in ["road_out", "road_out_east"]:
		var out := _exit(GATES, id)
		assert_eq(str(out["to"]), "travel")
		assert_true(StoryConditions.check(str(out.get("when", "")), StoryState.new()), "%s is open" % id)
