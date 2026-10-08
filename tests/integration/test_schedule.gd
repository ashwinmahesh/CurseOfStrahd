extends TestCase
## Things on a clock (F2): Schedule's events come round on their day and hour, once however long the wait, set their
## flags wherever the party is and play only where it is; people keep their `hours` (Vallaki's market empties at dusk
## and the lamplighter comes out); the Baron's watch fills the stocks at eight and empties them at the evening bell;
## and the Festival of the Blazing Sun begins at noon.

var root: Node


func before_each() -> void:
	Schedule.use([] as Array[Dictionary])
	GameState.reset()
	for id: String in ["ilse_varga", "tamsin_tealeaf"]:
		var ch := Pregens.build(id, 4)
		ch.finish_long_rest()
		GameState.story.party.append(ch)


func after_each() -> void:
	if root != null and is_instance_valid(root):
		root.queue_free()
	Schedule.use([] as Array[Dictionary])


func _frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame


func _view() -> LocationView:
	return root.get("view") as LocationView


func _at(location: String, day: int, hour: int, minute: int = 0) -> void:
	var st := GameState.story
	st.location = location
	st.day = day
	st.minute_of_day = hour * 60 + minute
	st.set_flag("vallaki_arrived")
	root = (load("res://scenes/game.tscn") as PackedScene).instantiate()
	add_child(root)
	await _frames(3)
	(root.get("hud") as ExploreHud).close_narration()


func _here(npc_id: String) -> bool:
	return _view().npc_tokens.has(npc_id)


func test_an_event_comes_round_on_its_days() -> void:
	var e := {"id": "x", "hour": 8, "every_days": 3, "first_day": 2}
	var day := 24 * 60
	assert_eq(Schedule.last_time(e, 0, day + 8 * 60), day + 8 * 60, "day 2 at eight")
	assert_eq(Schedule.last_time(e, day + 8 * 60, 3 * day + 23 * 60), -1, "not days 3 or 4")
	assert_eq(Schedule.last_time(e, 0, 9 * day), 7 * day + 8 * 60, "the latest of days 2, 5 and 8")
	assert_eq(Schedule.last_time({"id": "y", "hour": 20}, 0, 19 * 60), -1, "not before its hour")


func test_events_set_their_flags_anywhere_and_play_only_here() -> void:
	var st := StoryState.new()
	st.minute_of_day = 9 * 60
	Schedule.use([{"id": "bell", "hour": 10, "location": "vallaki", "set": {"test_bell": true}, "narration": "A bell."},
		{"id": "show", "hour": 11, "location": "vallaki", "here_only": true, "set": {"test_show": true}, "narration": "A show."},
		{"id": "once", "hour": 9, "minute": 30, "once": true, "set": {"test_once": 1}}] as Array[Dictionary])
	Schedule.memory(st)
	st.advance_minutes(150)   # 11:30, away in Krezk
	assert_true(Schedule.catch_up(st, "krezk").is_empty(), "nothing plays where the party isn't")
	assert_true(bool(st.get_flag("test_bell")), "the bell rang all the same")
	assert_false(bool(st.get_flag("test_show")), "a here-only event waits for the party")
	assert_eq(Schedule.times(st, "once"), 1)
	st.advance_minutes(3 * 24 * 60)   # three days on, in Vallaki at 11:30
	var plays := Schedule.catch_up(st, "vallaki")
	assert_eq(Schedule.times(st, "bell"), 2, "a long wait rings the bell once, not three times")
	assert_eq(Schedule.times(st, "once"), 1, "a once event never comes again")
	assert_eq(plays.size(), 1, "the show plays fresh; the bell rang two hours ago (got %s)" % [plays])
	assert_eq(str((plays[0]["event"] as Dictionary)["id"]), "show")


func test_vallaki_townsfolk_keep_their_hours() -> void:
	Schedule.use([] as Array[Dictionary])
	await _at("vallaki", 1, 17, 40)
	assert_true(_here("vallaki_goodwife"), "Marta is out on her round before six")
	assert_false(_here("vallaki_lamplighter"), "no lamps yet")
	GameState.story.advance_minutes(90)   # 19:10
	await _frames(3)
	assert_false(_here("vallaki_goodwife"), "she has gone in at dusk")
	assert_true(_here("vallaki_lamplighter"), "the lamplighter is out")


func test_the_watch_fills_the_stocks_at_eight_and_empties_them_at_the_bell() -> void:
	Schedule.use([] as Array[Dictionary])
	await _at("vallaki", 2, 7, 40)
	assert_false(_here("vallaki_grumbler"))
	var said: Array[String] = []
	_view().narration.connect(func(text: String) -> void: said.append(text))
	GameState.story.advance_minutes(30)   # 8:10 on day 2
	await _frames(3)
	assert_true(bool(GameState.story.get_flag("vallaki_stocks_grumbler")))
	assert_true(_here("vallaki_grumbler"), "Anton is in the stocks")
	assert_true(said.any(func(t: String) -> bool: return t.contains("insufficient cheer")), "the party sees it happen: %s" % [said])
	GameState.story.advance_minutes(12 * 60)   # 20:10
	await _frames(3)
	assert_false(_here("vallaki_grumbler"), "let out at the evening bell")


func test_the_festival_begins_at_noon() -> void:
	Schedule.use([] as Array[Dictionary])
	GameState.story.set_flag("baron_met")
	await _at("vallaki", 3, 9)
	root.call("start_dialogue", "vallaki/festival:at_noon", "vallaki_herald")
	await _frames(2)
	var d := root.get("dialogue") as DialogueUI
	for i in 6:
		if not d.options_shown.is_empty():
			break
		d.call("_advance")
		await _frames(1)
	assert_false(bool(GameState.story.get_flag("festival_begun")), "not at nine in the morning")
	d.call("_choose", 0)   # We'll wait for noon.
	await _frames(1)
	for i in 10:
		if root.get("dialogue") == null:
			break
		(root.get("dialogue") as DialogueUI).call("_advance")
		await _frames(1)
	assert_true(bool(GameState.story.get_flag("festival_begun")), "the festival began")
	assert_eq(GameState.story.minute_of_day, 12 * 60, "at noon")
