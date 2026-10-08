extends TestCase
## Wait (owner, 2026-10-08): H or the bar's Wait button opens a screen to pass 1 to 24 hours. The clock moves and the
## world with it (the daylight, the day's schedule, spells running down); nothing heals or comes back, as waiting isn't
## resting. It can't be done with foes in sight or in a fight, and says why; Back leaves the clock alone.

const HALL := {
	"id": "test_wait_hall", "name": "Test Hall", "region": "test", "summary": "A fixture.",
	"map": {"rows": [
		"##########",
		"#........#",
		"#........#",
		"#........#",
		"##########"], "light": "dim"},
	"spawns": {"default": [2, 2]},
	"encounters": [{"id": "rat", "trigger": "manual", "monsters": [{"monster": "rat", "cell": [8, 3]}]}],
}

var root: Node


func before_each() -> void:
	Compendium.shared().tables["locations"]["test_wait_hall"] = HALL.duplicate(true)
	GameState.reset()
	for id: String in ["godrick_pendlebrook", "liriel_dawnsong"]:
		var ch := TestChars.pregen(id, 3)
		ch.finish_long_rest()
		GameState.story.party.append(ch)
	GameState.story.location = "test_wait_hall"
	root = (load("res://scenes/game.tscn") as PackedScene).instantiate()
	add_child(root)
	await _frames(4)


func after_each() -> void:
	get_tree().paused = false
	(Compendium.shared().tables["locations"] as Dictionary).erase("test_wait_hall")
	if root != null:
		root.queue_free()
		root = null
	GameState.reset()


func _frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame


func _key(code: Key) -> InputEventKey:
	var k := InputEventKey.new()
	k.physical_keycode = code
	k.keycode = code
	k.pressed = true
	return k


func test_h_opens_it_and_waiting_moves_the_clock_but_heals_nothing() -> void:
	var st := GameState.story
	var godrick := st.party[0]
	godrick.hp = 5
	if godrick.resource_max("lay_on_hands") > 0:
		godrick.spend_resource("lay_on_hands")
	var lay := godrick.resource_left("lay_on_hands")
	var liriel := st.party[1]
	liriel.expend_slot(1)
	var slots := liriel.slots_left(1)
	var before := st.total_minutes()
	root._unhandled_input(_key(KEY_H))
	await _frames(2)
	var w := root.get("screen") as WaitScreen
	assert_true(w != null, "H opens the Wait screen")
	assert_eq(w.blocked, "", "nothing stops a wait here")
	w._unhandled_input(_key(KEY_RIGHT))
	w._unhandled_input(_key(KEY_RIGHT))
	assert_eq(w.hours, 3, "Right adds an hour")
	w.set_hours(40)
	assert_eq(w.hours, WaitScreen.MAX_HOURS, "24 hours at most")
	w.set_hours(0)
	assert_eq(w.hours, WaitScreen.MIN_HOURS, "an hour at least")
	w.set_hours(6)
	w.wait()
	w.wait()   # a second press before the screen is gone does nothing
	await _frames(2)
	assert_eq(st.total_minutes() - before, 6 * 60, "six hours pass, once")
	assert_true(root.get("screen") == null, "back to exploring")
	assert_eq(godrick.hp, 5, "waiting heals no one")
	assert_eq(godrick.resource_left("lay_on_hands"), lay, "and brings back no features")
	assert_eq(liriel.slots_left(1), slots, "or spell slots")


func test_back_leaves_the_clock_alone() -> void:
	var st := GameState.story
	var before := st.total_minutes()
	root.call("open_screen", "wait", 0)
	await _frames(1)
	var w := root.get("screen") as WaitScreen
	(w.find_children("Back", "Button", true, false)[0] as Button).pressed.emit()
	await _frames(2)
	assert_true(root.get("screen") == null, "Back closes it")
	assert_eq(st.total_minutes(), before)


func test_spells_run_out_while_you_wait() -> void:
	var st := GameState.story
	st.active_spells["test_ward"] = {"until": st.total_minutes() + 60}
	assert_true(st.spell_active("test_ward"))
	root.call("open_screen", "wait", 0)
	await _frames(1)
	var w := root.get("screen") as WaitScreen
	w.set_hours(2)
	w.wait()
	await _frames(1)
	assert_false(st.spell_active("test_ward"), "an hour-long spell is over after two")


func test_not_with_foes_in_sight_or_in_a_fight() -> void:
	var view := root.get("view") as LocationView
	var st := GameState.story
	assert_true(view.start_encounter("rat"), "a fight starts")
	await _frames(3)
	assert_eq(WaitScreen.why_not(root, st), "Not in the middle of a fight.")
	view.combat_view.finished.emit("victory")
	await _frames(3)
	assert_eq(WaitScreen.why_not(root, st), "", "after the fight, waiting is fine again")
	var before := st.total_minutes()
	# A foe waiting in sight: LocationStealth's waiting list, with a figure (it has been seen).
	var foe := Combatant.new(Monster.from_data(Compendium.shared().monster_data("rat")), &"enemy", Vector2i(6, 2))
	var figure := Node3D.new()
	view.add_child(figure)
	view.waiting.append({"encounter": "rat", "foe": foe, "token": figure, "low": [], "facing": Vector2.LEFT})
	assert_eq(LocationStealth.nearest_waiting(view), "rat")
	var why := WaitScreen.why_not(root, st)
	assert_true(why.begins_with("Not with foes in sight"), why)
	root.call("open_screen", "wait", 0)
	await _frames(1)
	var w := root.get("screen") as WaitScreen
	assert_eq(w.blocked, why, "the screen says why")
	assert_true(w.find_children("Wait", "Button", true, false).is_empty(), "and offers only Back")
	w.wait()
	assert_eq(st.total_minutes(), before, "nothing passes")
	root.call("close_screen")
	view.waiting.clear()
	figure.queue_free()


func test_the_clock_after_reads_like_the_hud() -> void:
	var st := StoryState.new()
	st.day = 2
	st.minute_of_day = 20 * 60 + 30
	assert_eq(WaitScreen.clock_after(st, 1), "Day 2 · 21:30 (night)")
	assert_eq(WaitScreen.clock_after(st, 12), "Day 3 · 08:30 (day)")
	assert_eq(WaitScreen.clock_after(st, 24), "Day 3 · 20:30 (night)")
