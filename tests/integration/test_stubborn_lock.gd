extends TestCase
## The stubborn lock (world/exploration/location_locks.gd, narrative/narrator/death_house.dialogue): the fifth failed
## try at one lock, once a playthrough, the Narrator notes the lock has begun to enjoy itself, and when it finally
## gives, it gives with dignity. The count is kept per lock in the location's state (saved), forcing counts as a try
## like picking, and none of it plays inside the Death House.

const LOC := {
	"id": "test_stubborn", "name": "Test Cellar", "region": "test", "summary": "A fixture.",
	"map": {"rows": [
		"#############",
		"#...........#",
		"#...........#",
		"####.###.####",
		"#...#...#...#",
		"#############"], "light": "dim"},
	"spawns": {"default": [2, 2]},
	"doors": [{"id": "first", "cell": [4, 3], "locked": true, "lock_dc": 60, "label": "the first door"},
		{"id": "second", "cell": [8, 3], "locked": true, "lock_dc": 60, "label": "the second door"}],
	"containers": [{"id": "strongbox", "cell": [11, 1], "label": "Strongbox", "locked": true, "lock_dc": 60, "gold": 3}],
}

var st: StoryState
var view: LocationView
var said: Array[String] = []


func before_each() -> void:
	Compendium.shared().tables["locations"]["test_stubborn"] = LOC.duplicate(true)
	GameState.reset()
	for id: String in ["ilse_varga", "tamsin_tealeaf", "hedda_ironvow", "silvain_aster"]:
		var ch := Pregens.build(id, 3)
		ch.finish_long_rest()
		GameState.story.party.append(ch)
	st = GameState.story
	st.location = "test_stubborn"
	Dice.reseed(4)
	said = []
	view = LocationView.create("test_stubborn", st, Narrator.new(1), Dice.roller, "default")
	view.narration.connect(func(t: String) -> void: said.append(t))
	add_child(view)
	await get_tree().process_frame


func after_each() -> void:
	if is_instance_valid(view):
		view.queue_free()
	await get_tree().process_frame
	(Compendium.shared().tables["locations"] as Dictionary).erase("test_stubborn")


func _spec(id: String) -> Dictionary:
	for d: Variant in view.loc["doors"]:
		if str((d as Dictionary)["id"]) == id:
			return d as Dictionary
	for c: Variant in view.loc["containers"]:
		if str((c as Dictionary)["id"]) == id:
			return c as Dictionary
	return {}


## One try at forcing the lock; the lines the Narrator said meanwhile.
func _try(id: String) -> Array[String]:
	said.clear()
	LocationLocks._unlock(view, _spec(id), "force")
	return said.duplicate()


func _fails(id: String) -> int:
	return int((st.loc_state("test_stubborn").get("lock_fails", {}) as Dictionary).get(id, 0))


func test_four_failures_are_only_a_lock_that_holds() -> void:
	for i in 4:
		assert_eq(_try("first"), ["It holds."] as Array[String], "try %d" % (i + 1))
	assert_eq(_fails("first"), 4, "counted")
	assert_false(st.get_flag("eggs_lock_stubborn", false), "not yet")


func test_the_fifth_failure_gets_the_stubborn_line_once() -> void:
	for i in 4:
		_try("first")
	var fifth := _try("first")
	assert_eq(fifth.size(), 1, "one line, not two: %s" % [fifth])
	assert_ne(fifth[0], "It holds.", "the stubborn line takes the place of the plain one")
	assert_true(fifth[0].length() > 40, fifth[0])
	assert_true(bool(st.get_flag("eggs_lock_stubborn", false)), "a flag for the achievement")
	assert_eq(_try("first"), ["It holds."] as Array[String], "the sixth try is only a lock that holds")


func test_once_a_playthrough_not_once_a_lock() -> void:
	for i in 5:
		_try("first")
	for i in 4:
		_try("second")
	assert_eq(_try("second"), ["It holds."] as Array[String], "a second lock's fifth try: the Narrator has spoken already")
	assert_eq(_fails("second"), 5, "though it is counted")


func test_every_lock_keeps_its_own_count() -> void:
	for i in 3:
		_try("first")
		_try("second")
	_try("strongbox")
	assert_eq(_fails("first"), 3)
	assert_eq(_fails("second"), 3)
	assert_eq(_fails("strongbox"), 1, "a chest's lock counts the same way")
	assert_false(st.get_flag("eggs_lock_stubborn", false), "no lock has had five")


func test_the_count_is_saved() -> void:
	for i in 3:
		_try("first")
	var back := StoryState.from_dict(JSON.parse_string(JSON.stringify(st.to_dict())) as Dictionary)
	assert_eq(int((back.loc_state("test_stubborn")["lock_fails"] as Dictionary)["first"]), 3, "survives a save and a load")
	view.st = back
	_try("first")
	assert_eq(int((back.loc_state("test_stubborn")["lock_fails"] as Dictionary)["first"]), 4, "and carries on from there")


func test_when_it_finally_gives_it_gives_with_dignity() -> void:
	for i in 5:
		_try("first")
	(_spec("first"))["lock_dc"] = 1   # now any hand will do
	var line := _try("first")
	assert_eq(line.size(), 1, "one line: %s" % [line])
	assert_true(line[0].length() > 40, line[0])
	assert_true(bool(st.get_flag("eggs_lock_gave", false)), "a flag for the achievement")
	assert_eq(str((st.loc_state("test_stubborn")["doors"] as Dictionary)["first"]), "unlocked", "it did give")
	assert_eq(_fails("first"), 0, "and the count is let go")


func test_a_lock_that_gives_early_says_nothing() -> void:
	for i in 2:
		_try("first")
	(_spec("first"))["lock_dc"] = 1
	assert_eq(_try("first"), [] as Array[String], "no line for an ordinary success outside the house")
	assert_false(st.get_flag("eggs_lock_gave", false))


func test_the_dignified_line_is_once_a_playthrough_too() -> void:
	for i in 5:
		_try("first")
	(_spec("first"))["lock_dc"] = 1
	_try("first")
	for i in 5:
		_try("second")
	(_spec("second"))["lock_dc"] = 1
	assert_eq(_try("second"), [] as Array[String], "the second stubborn lock gives without a word")


func test_inside_the_death_house_the_lock_only_holds() -> void:
	st.visited["death_house_ground"] = true
	for i in 6:
		var lines := _try("first")
		assert_eq(lines.size(), 1, "try %d: %s" % [i + 1, lines])
		assert_true(lines[0].contains("laughter"), "the house's own plain line, never the stubborn one: %s" % lines[0])
	assert_eq(_fails("first"), 6, "still counted")
	# Out of the house, the first lock to take a fifth try speaks: the Death House didn't use the line up.
	st.set_flag("death_house_completed")
	for i in 4:
		_try("second")
	var fifth := _try("second")
	assert_eq(fifth.size(), 1, str(fifth))
	assert_ne(fifth[0], "It holds.")
	assert_false(fifth[0].contains("laughter"))
