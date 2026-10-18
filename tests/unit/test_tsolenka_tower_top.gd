extends TestCase
## The Tsolenka guard tower's upper floors (dungeon expansion P1): a stair niche carved into the guardroom's south wall (the
## ground floor gained that one square and nothing else), the lookout above it and the roof above that, each on a map of its
## own with a mood of its own. The gate's wards are test_tsolenka_gate_wards.gd.


const TOWER := "tsolenka_pass_guard_tower"


const UPPER := "tsolenka_pass_guard_tower_upper"


const ROOF := "tsolenka_pass_guard_tower_roof"

## The tower's ground floor as it was, with the one square carved out of the wall for the stair up (row 10, x 16).


const TOWER_ROWS: Array[String] = [
	"####################",
	"#.....#......#.....#",
	"#..=..#.=..=.#..=..#",
	"#.....#......#.....#",
	"#.....#.=..=.#.....#",
	"#.....#......#.....#",
	"###.#####..#####.###",
	"#..................#",
	"#...=..........=...#",
	"#..................#",
	"########.....###.###",
	"########.....#######",
	"##########.#########"]


func _loc(id: String) -> Dictionary:
	return Compendium.shared().get_entry("locations", id)


func _rows(id: String) -> Array:
	return (_loc(id)["map"] as Dictionary)["rows"] as Array


func _open(id: String, cell: Array) -> bool:
	return str(_rows(id)[int(cell[1])])[int(cell[0])] != "#"


## A data cell ([x, y], read back as floats) as a square.


func _xy(cell: Variant) -> Vector2i:
	return Vector2i(int((cell as Array)[0]), int((cell as Array)[1]))


# --- Extend, never redraw ------------------------------------------------------------------------------


func test_the_ground_floor_only_gained_its_stair() -> void:
	assert_eq(_rows(TOWER), TOWER_ROWS, "the tower's squares are as they were, plus the stair niche")


func test_the_stair_up_is_the_ground_floors_one_new_exit() -> void:
	var exits := _loc(TOWER)["exits"] as Array
	assert_eq(exits.size(), 2, "the way out to the road and the stair up")
	var out := exits[0] as Dictionary
	assert_eq(str(out["id"]), "tower_out", "the old exit stays first and where it was")
	assert_eq(_xy(out["cell"]), Vector2i(10, 12))
	var up := exits[1] as Dictionary
	assert_eq(str(up["to"]), UPPER)
	assert_true(_open(TOWER, up["cell"] as Array), "the stair stands on an open square")
	assert_eq(_xy(up["cell"]), Vector2i(16, 10))
	assert_true("from_above" in (_loc(TOWER)["spawns"] as Dictionary), "and the way back down lands in the guardroom")
	assert_eq(_xy((_loc(TOWER)["spawns"] as Dictionary)["default"]), Vector2i(10, 11), "the default spawn didn't move")


# --- The lookout and the roof --------------------------------------------------------------------------


func test_the_lookout_and_the_roof_join_the_tower_by_stair_and_hatch() -> void:
	var up := {}
	for e: Variant in _loc(TOWER)["exits"]:
		if str((e as Dictionary)["to"]) == UPPER:
			up = e as Dictionary
	assert_true((_loc(UPPER)["spawns"] as Dictionary).has(str(up["spawn"])), "the stair lands on a spawn the lookout has")
	var down := {}
	var hatch_up := {}
	for e: Variant in _loc(UPPER)["exits"]:
		if str((e as Dictionary)["to"]) == TOWER:
			down = e as Dictionary
		elif str((e as Dictionary)["to"]) == ROOF:
			hatch_up = e as Dictionary
	assert_false(down.is_empty(), "the lookout has its stair down")
	assert_false(hatch_up.is_empty(), "and its hatch up")
	assert_true((_loc(TOWER)["spawns"] as Dictionary).has(str(down["spawn"])), "the stair down lands on a spawn the tower has")
	assert_true((_loc(ROOF)["spawns"] as Dictionary).has(str(hatch_up["spawn"])))
	var hatch_down := (_loc(ROOF)["exits"] as Array)[0] as Dictionary
	assert_eq(str(hatch_down["to"]), UPPER)
	assert_true((_loc(UPPER)["spawns"] as Dictionary).has(str(hatch_down["spawn"])))


func test_everything_on_the_new_maps_stands_on_open_ground() -> void:
	for id: String in [UPPER, ROOF]:
		var loc := _loc(id)
		for key: String in ["exits", "props", "containers", "lights", "npcs"]:
			for e: Variant in loc.get(key, []):
				var cell := (e as Dictionary)["cell"] as Array
				var is_wall_piece := str((e as Dictionary).get("model", "")) in ["window_tall", "crest", "relief", "stone_faces"]
				assert_true(is_wall_piece or _open(id, cell), "%s %s at %s" % [id, str((e as Dictionary).get("id", key)), str(cell)])
		for s: Variant in (loc["spawns"] as Dictionary).values():
			assert_true(_open(id, s as Array), "%s's spawn at %s" % [id, str(s)])
		for a: Variant in loc["areas"]:
			for c: Variant in (a as Dictionary)["cells"]:
				assert_true(int((c as Array)[1]) < _rows(id).size() and int((c as Array)[0]) < str(_rows(id)[0]).length(), "%s's area %s is on the map" % [id, str((a as Dictionary)["id"])])


func test_every_new_square_is_walkable_from_its_spawn() -> void:
	for id: String in [UPPER, ROOF]:
		var rows := _rows(id)
		var start := ((_loc(id)["spawns"] as Dictionary)["default"]) as Array
		var seen := {Vector2i(int(start[0]), int(start[1])): true}
		var queue: Array[Vector2i] = [Vector2i(int(start[0]), int(start[1]))]
		while not queue.is_empty():
			var c: Vector2i = queue.pop_front()
			for d: Vector2i in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
				var n: Vector2i = c + d
				if n.y < 0 or n.y >= rows.size() or n.x < 0 or n.x >= str(rows[n.y]).length() or seen.has(n):
					continue
				if str(rows[n.y])[n.x] in "#= ":
					continue
				seen[n] = true
				queue.append(n)
		for e: Variant in _loc(id)["exits"]:
			var cell := (e as Dictionary)["cell"] as Array
			assert_true(seen.has(Vector2i(int(cell[0]), int(cell[1]))), "%s's exit %s is reachable" % [id, str((e as Dictionary)["id"])])


func test_the_new_places_have_moods_of_their_own() -> void:
	var moods := (JSON.parse_string(FileAccess.get_file_as_string("res://art/atmosphere/moods.json")) as Dictionary)["places"] as Dictionary
	for id: String in [UPPER, ROOF]:
		assert_true(moods.has(id), "%s has its own mood entry" % id)
