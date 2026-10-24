extends TestCase
## Argynvostholt's third floor and roof (Dungeon Expansion Plan A3 and A4; the book's Q25, Q27, Q28, Q33, Q35 to Q38 and
## Q41 to Q49): a stair up from the upper floor's landing, the cold hallway whose phantom knights come out against anyone
## who isn't of the Order, the dragon's audience hall with its throne turned to the windows, four knights at rest round the
## table, the vault behind a hidden door, and the roof with its gargoyle, its ballistas and a second door into the beacon
## tower.

const THIRD := "argynvostholt_third"
const ROOF := "argynvostholt_roof"


func _loc(id: String) -> Dictionary:
	return Compendium.shared().get_entry("locations", id) as Dictionary


func _exit(loc_id: String, exit_id: String) -> Dictionary:
	for e: Variant in _loc(loc_id).get("exits", []):
		if str((e as Dictionary)["id"]) == exit_id:
			return e as Dictionary
	return {}


func _at(loc_id: String, cell: Array) -> String:
	return str((_loc(loc_id)["map"]["rows"] as Array)[int(cell[1])])[int(cell[0])]


## Each new way joins two places both ways, and lands on a square a party can stand on.
func test_the_stairs_and_doors_join_up() -> void:
	for way: Array in [["argynvostholt_upper", "stairs_up_third", THIRD], [THIRD, "stairs_down_upper", "argynvostholt_upper"],
			[THIRD, "stairs_up_roof", ROOF], [ROOF, "roof_hatch_down", THIRD], [ROOF, "beacon_roof_door", "argynvostholt_beacon"],
			["argynvostholt_beacon", "roof_door", ROOF]]:
		var e := _exit(str(way[0]), str(way[1]))
		assert_false(e.is_empty(), "%s has the way %s" % [way[0], way[1]])
		if e.is_empty():
			continue
		assert_eq(str(e["to"]), str(way[2]), "%s leads to %s" % [way[1], way[2]])
		var spawn := ((_loc(str(way[2]))["spawns"] as Dictionary).get(str(e["spawn"]), []) as Array)
		assert_eq(spawn.size(), 2, "%s lands on %s's spawn %s" % [way[1], way[2], e["spawn"]])
		if spawn.size() == 2:
			assert_true(_at(str(way[2]), spawn) in [".", "1", "2", "3", "4", "~"], "on open ground: %s" % [spawn])


## The hallway's knights come out against a party that isn't of the Order, at every level, and never against one that has
## the oath, Godfrey's word or Godfrey; nor once they're beaten, or once the Order has chosen.
func test_the_hallway_spares_the_order() -> void:
	var versions := (_loc(THIRD)["encounters"] as Array).filter(func(e: Variant) -> bool: return str((e as Dictionary)["id"]) == "trapped_hall")
	assert_eq(versions.size(), 3, "levels 8, 7 and below")
	for v: Variant in versions:
		var e := v as Dictionary
		assert_eq(str(e["trigger"]), "enter_area:holt_trapped_hall", "it starts in the cold hallway")
		assert_eq(str(e["flag"]), "trapped_hall_cleared", "and is remembered")
		var kinds := (e["monsters"] as Array).map(func(m: Variant) -> String: return str((m as Dictionary)["monster"]))
		assert_true(kinds.all(func(k: String) -> bool: return k == "phantom_warrior"), "phantom knights only")
	var st := StoryState.new()
	var ch := Pregens.build("hedda_ironvow", 6)
	st.party.append(ch)
	var gate := str((versions[2] as Dictionary)["when"])
	assert_true(StoryConditions.check(gate, st), "a stranger is set on")
	for spare: String in ["order_oath_learned", "godfrey_remembers", "trapped_hall_cleared"]:
		st.set_flag(spare, true)
		assert_false(StoryConditions.check(gate, st), "not once %s" % spare)
		st.flags.erase(spare)
	st.set_flag("order_fate", "rest")
	assert_false(StoryConditions.check(gate, st), "nor once the Order has chosen")


## The hallway is the only way up from the stair: the fight's area lies across it.
func test_the_hallway_lies_across_the_way_up() -> void:
	var rows := _loc(THIRD)["map"]["rows"] as Array
	var area := {}
	for a: Variant in _loc(THIRD)["areas"]:
		if str((a as Dictionary)["id"]) == "holt_trapped_hall":
			area = a as Dictionary
	var c0 := (area["cells"] as Array)[0] as Array
	var c1 := (area["cells"] as Array)[1] as Array
	var blocked := {}
	for y in range(int(c0[1]), int(c1[1]) + 1):
		for x in range(int(c0[0]), int(c1[0]) + 1):
			blocked[Vector2i(x, y)] = true
	assert_false(_walkable(rows, Vector2i(19, 21), Vector2i(20, 14), blocked), "no way round it")
	assert_true(_walkable(rows, Vector2i(19, 21), Vector2i(20, 14), {}), "and the way through it is open")


## A walk over open floor from `a` to `b`, four ways round, not through `blocked`. Door squares are open floor.
func _walkable(rows: Array, a: Vector2i, b: Vector2i, blocked: Dictionary) -> bool:
	var seen := {a: true}
	var todo: Array[Vector2i] = [a]
	while not todo.is_empty():
		var c: Vector2i = todo.pop_back()
		if c == b:
			return true
		for d: Vector2i in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			var n := c + d
			if n.y < 0 or n.y >= rows.size() or n.x < 0 or n.x >= str(rows[n.y]).length() or seen.has(n) or blocked.has(n):
				continue
			if str(rows[n.y])[n.x] in [".", "~"]:
				seen[n] = true
				todo.append(n)
	return false


## The vault is reached only through its hidden door.
func test_the_vault_is_behind_a_hidden_door() -> void:
	var door := {}
	for d: Variant in _loc(THIRD)["doors"]:
		if str((d as Dictionary)["id"]) == "holt_vault_door":
			door = d as Dictionary
	assert_true(int(door.get("secret_dc", 0)) > 0, "the door is hidden")
	var rows := _loc(THIRD)["map"]["rows"] as Array
	var c := door["cell"] as Array
	assert_false(_walkable(rows, Vector2i(19, 21), Vector2i(9, 9), {Vector2i(int(c[0]), int(c[1])): true}), "no other way in")
	assert_true(_walkable(rows, Vector2i(19, 21), Vector2i(9, 9), {}), "and through it the vault is there")


## The throne faces the windows, away from the hall's doors; nobody sits on it (Vladimir keeps his table downstairs).
func test_the_throne_faces_the_windows() -> void:
	var throne := (_loc(THIRD)["props"] as Array).filter(func(p: Variant) -> bool: return str((p as Dictionary)["id"]) == "holt_dragon_throne")
	assert_eq(throne.size(), 1, "the throne")
	assert_eq(str((throne[0] as Dictionary).get("facing", "")), "north", "facing the windows")
	for n: Variant in _loc(THIRD).get("npcs", []):
		assert_false(str((n as Dictionary)["npc"]) == "vladimir_horngaard", "Vladimir isn't up here")


## Four knights wait at the round table while the Order waits; they answer, and once the Order has chosen they say what
## the knights at Vladimir's table say.
func test_the_knights_wait_at_the_round_table() -> void:
	var knights := (_loc(THIRD)["npcs"] as Array).filter(func(n: Variant) -> bool: return str((n as Dictionary)["dialogue"]) == "argynvostholt/knights:round_table")
	assert_eq(knights.size(), 4, "four at the table")
	GameState.reset()
	var lines := _lines("argynvostholt/knights:round_table")
	assert_true(lines.any(func(t: String) -> bool: return t.contains("We wait on the word")), "waiting for orders")
	GameState.story.set_flag("order_fate", "ride")
	lines = _lines("argynvostholt/knights:round_table")
	assert_true(lines.any(func(t: String) -> bool: return t.contains("We march when you march")), "and marching once the Order rides")


func _lines(ref: String) -> Array[String]:
	var out: Array[String] = []
	var r := DialogueRunner.new(GameState.story, DiceRoller.new(3))
	assert_true(r.start(ref), "starts " + ref)
	var b := r.next()
	for i in 12:
		if str(b["kind"]) == "line":
			out.append(str(b.get("text", "")))
		if str(b["kind"]) in ["end", "options"]:
			break
		b = r.next()
	return out
