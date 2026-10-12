extends TestCase
## Guests' lines in the running game (owner 2026-10-12; world/exploration/location_walk.gd): a word on the first step
## after a won fight, a remark after a long quiet walk, and never over the Narrator.

var root: Node


func after_each() -> void:
	if root != null:
		root.queue_free()
		root = null


func _frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame


func _boot(location: String, guests: Array[String]) -> LocationView:
	GameState.reset()
	for id: String in ["godrick_pendlebrook", "liriel_dawnsong", "thistle", "wren_featherfoot"]:
		var ch := Pregens.build(id, 6)
		ch.finish_long_rest()
		GameState.story.party.append(ch)
	for g in guests:
		GameState.story.add_guest(g)
	GameState.story.location = location
	GameState.story.minute_of_day = 12 * 60
	Dice.reseed(7)
	root = (load("res://scenes/game.tscn") as PackedScene).instantiate()
	add_child(root)
	await _frames(3)
	return root.get("view") as LocationView


func _played(st: StoryState, guest: String, kind: String) -> int:
	var n := 0
	for k: String in st.flags:
		if k.begins_with("_banter/banter/guest_%s:%s" % [guest, kind]):
			n += 1
	return n


func test_a_word_after_a_won_fight() -> void:
	var v := await _boot("vallaki", ["ismark"])
	var tries := 0
	while _played(v.st, "ismark", "fight_") == 0 and tries < 12:
		v._fight_bark_due = true
		LocationWalk._guest_chatter(v)
		assert_false(v._fight_bark_due, "only the first step after the fight")
		tries += 1
	assert_eq(_played(v.st, "ismark", "fight_"), 1, "now and then, a fight gets a word")


func test_a_remark_after_a_long_quiet_walk() -> void:
	var v := await _boot("vallaki", ["ismark"])
	v._last_bark_step = v._steps
	for i in LocationWalk.IDLE_STEPS - 1:
		LocationWalk._guest_chatter(v)
	assert_eq(_played(v.st, "ismark", "idle_"), 0, "not before the quiet has gone on a while")
	LocationWalk._guest_chatter(v)
	assert_eq(_played(v.st, "ismark", "idle_"), 1)


func test_no_guest_no_chatter() -> void:
	var v := await _boot("vallaki", [])
	v._fight_bark_due = true
	for i in LocationWalk.IDLE_STEPS + 1:
		LocationWalk._guest_chatter(v)
	assert_false(v._fight_bark_due)
	for k: String in v.st.flags:
		assert_false(k.begins_with("_banter/banter/guest_"), "nobody to say it")


func test_banter_waits_for_the_narrator() -> void:
	var v := await _boot("vallaki", ["ismark"])
	var hud: Variant = root.get("hud")
	hud.narrate("The Narrator is still speaking.")
	v.banter.emit([{"name": "Sir Godfrey Gwilym", "text": "Mind the steps.", "narrator": false, "portrait": "sir_godfrey_gwilym",
		"speaker_id": "sir_godfrey_gwilym", "party": false}])
	await _frames(2)
	assert_false((root.get("_banter_waiting") as Array).is_empty(), "it waits")
	hud.close_narration()
	await _frames(2)
	assert_false(hud.narration_showing(), "a moment's quiet first")
	await get_tree().create_timer(1.5).timeout
	await _frames(2)
	assert_true((root.get("_banter_waiting") as Array).is_empty(), "and then it plays")
	assert_true(hud.narration_showing())
	assert_true(str(hud.get("_narr").text).contains("Godfrey: Mind the steps."), "named without his title")
