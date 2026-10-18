extends TestCase
## The chapel-side stair to the crypts is bricked up (Dungeon Expansion Plan C1, hand-off 2; the book walls it and Strahd's
## mist is the only thing the masonry was never meant to stop). Both ends keep their squares and their spawns (rule 2) but
## the way is barred for good, with a chink in the masonry beside each; the way down to the crypts is the larders' long stair.

const MAIN := "castle_ravenloft_main_floor"
const CATS := "castle_ravenloft_catacombs"


func _loc(id: String) -> Dictionary:
	return Compendium.shared().get_entry("locations", id)


func _exit(loc_id: String, exit_id: String) -> Dictionary:
	for e: Variant in _loc(loc_id)["exits"]:
		if str((e as Dictionary)["id"]) == exit_id:
			return e as Dictionary
	return {}


func _prop(loc_id: String, id: String) -> Dictionary:
	for p: Variant in _loc(loc_id)["props"]:
		if str((p as Dictionary)["id"]) == id:
			return p as Dictionary
	return {}


## The exits a party could take from `from` to reach `to` now (a fresh story: nothing set), as the story bot finds them.
func _route(from: String, to: String) -> Array[String]:
	var st := StoryState.new()
	var prev := {from: ""}
	var how := {}
	var queue: Array[String] = [from]
	while not queue.is_empty():
		var here: String = queue.pop_front()
		for e: Variant in _loc(here).get("exits", []):
			var ed := e as Dictionary
			var there := str(ed["to"])
			if there == "travel" or prev.has(there) or not StoryConditions.check(str(ed.get("when", "")), st):
				continue
			prev[there] = here
			how[there] = str(ed["id"])
			queue.append(there)
	var out: Array[String] = []
	var at := to
	while at != from and prev.has(at):
		out.push_front(str(how[at]))
		at = str(prev[at])
	return out


func test_both_ends_are_bricked_up_but_keep_their_squares() -> void:
	var top := _exit(MAIN, "crypt_stairs_down")
	var foot := _exit(CATS, "cat_stairs_to_main_floor")
	assert_eq(Vector2i(int((top["cell"] as Array)[0]), int((top["cell"] as Array)[1])), Vector2i(44, 23), "the top of the stair is where it was")
	assert_eq(Vector2i(int((foot["cell"] as Array)[0]), int((foot["cell"] as Array)[1])), Vector2i(3, 1), "so is the foot")
	assert_eq(str(top["spawn"]), "from_gates", "and the spawns it named")
	assert_eq(str(foot["spawn"]), "from_catacombs")
	var st := StoryState.new()
	for e: Dictionary in [top, foot]:
		assert_true(str(e.get("when", "")) != "", "%s has a condition" % e["id"])
		assert_false(StoryConditions.check(str(e["when"]), st), "%s never holds" % e["id"])
		assert_true(str(e.get("locked_text", "")).length() > 20, "%s says why" % e["id"])
	# Nothing the story sets opens it: every flag at once.
	for f: String in ["strahd_in_coffin", "strahd_destroyed", "castle_dinner", "heart_of_sorrow_shattered"]:
		st.set_flag(f, true)
	assert_false(StoryConditions.check(str(top["when"]), st), "even with Strahd in his coffin")


func test_the_way_down_is_the_larders() -> void:
	var down := _route(MAIN, CATS)
	assert_eq(down, ["servants_stairs_down", "larders_long_stair"] as Array[String], "from the main floor: the servants' stairs, then the long stair")
	var up := _route(CATS, MAIN)
	assert_eq(up, ["cat_stairs_to_larders", "larders_stair_up"] as Array[String], "and back up the same way")
	assert_eq((_exit("castle_ravenloft_larders", "larders_long_stair")["to"]), CATS)


func test_a_chink_on_each_side_and_the_mist_in_it() -> void:
	for pair: Array in [[MAIN, "crypt_stair_chink"], [CATS, "cat_stair_chink"]]:
		var p := _prop(pair[0], pair[1])
		assert_false(p.is_empty(), "%s has %s" % [pair[0], pair[1]])
		assert_eq(str(p["kind"]), "examine")
		var rows := _loc(pair[0])["map"]["rows"] as Array
		var c := p["cell"] as Array
		assert_eq(str(rows[int(c[1])])[int(c[0])], ".", "%s stands on floor" % pair[1])
	var text := FileAccess.get_file_as_string("res://narrative/narrator/castle_ravenloft_gates.dialogue")
	assert_true(text.contains("~ examine:crypt_stair_chink") and text.contains("[flag.strahd_in_coffin]"), "the main floor's chink has its mist")
	var cats := FileAccess.get_file_as_string("res://narrative/narrator/castle_ravenloft_catacombs.dialogue")
	assert_true(cats.contains("~ examine:cat_stair_chink"), "so has the catacombs'")
