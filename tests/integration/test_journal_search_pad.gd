extends TestCase
## The journal's quest search in the real game, on a keyboard and a pad (Ashwin, 2026-10-19): the box and the chips are
## on the page when it opens and say how to get to them; the D-pad reaches every choice, the chips and the way out of an empty
## list among them; Y goes to the box; Esc and B clear what was typed and leave the box before they close the journal (the box
## keeps an Esc to itself unless it is told not to), and the journal closes on the next.

const LATE := "v2_amber_temple.json"

var root: Node
var nav: PadNav


func before_each() -> void:
	InputActions.ensure()
	nav = UiFeel.pad   # the game's own tracker (an autoload's)
	nav.reset()


func after_each() -> void:
	nav.reset()
	get_tree().paused = false
	if root != null:
		root.queue_free()
		root = null
	GameState.reset()
	SaveSystem.current_slot = ""
	await _frames(1)


func _frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame


## The game from golden save `f` with every quest taken, the journal open on its Quests page.
func _journal() -> JournalScreen:
	DirAccess.make_dir_recursive_absolute(SaveSystem.save_dir)
	var out := FileAccess.open(SaveSystem.slot_path("journal_search"), FileAccess.WRITE)
	out.store_string(FileAccess.get_file_as_string(GoldenSaves.DIR + LATE))
	out.close()
	assert_eq(SaveSystem.load_slot("journal_search"), OK)
	SaveSystem.delete_slot("journal_search")
	root = (load("res://scenes/game.tscn") as PackedScene).instantiate()
	add_child(root)
	await _frames(5)
	(root.get("hud") as ExploreHud).close_narration()
	await _frames(1)
	for q: Dictionary in Compendium.shared().all("quests"):
		GameState.story.set_quest_stage(str(q["id"]), str(((q["stages"] as Array)[0] as Dictionary)["id"]))
	root.call("open_screen", "journal", 0)
	await _frames(3)
	return root.get("screen") as JournalScreen


## A key or a pad button through the engine's own input, as a real device sends it.
func _real(ev: InputEvent) -> void:
	Input.parse_input_event(ev)
	Input.flush_buffered_events()
	await _frames(2)


func _key(code: Key) -> void:
	for down: bool in [true, false]:
		var ev := InputEventKey.new()
		ev.keycode = code
		ev.physical_keycode = code
		ev.pressed = down
		await _real(ev)


func _button(b: JoyButton) -> void:
	for down: bool in [true, false]:
		var ev := InputEventJoypadButton.new()
		ev.button_index = b
		ev.pressed = down
		await _real(ev)


## What the pad's neighbour rule cannot reach from the choice in focus.
func _unreached(scope: Node) -> Array[String]:
	var list := PadNav.choices(scope)
	var start := nav.focus_in(scope)
	if start == null:
		return ["nothing has focus"]
	var seen := {start: true}
	var queue: Array[Control] = [start]
	while not queue.is_empty():
		var c: Control = queue.pop_back()
		for d: Vector2i in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
			if d.y == 0 and (c is Range or c.has_method(&"pad_adjust") or c.has_meta(&"pad_adjust")):
				continue
			var n := PadNav.neighbour(c, d, list)
			if n != null and not seen.has(n):
				seen[n] = true
				queue.append(n)
	var missed: Array[String] = []
	for c in list:
		if not seen.has(c):
			missed.append("%s (%s)" % [c.name, c.get_class()])
	return missed


func test_the_box_and_the_chips_are_on_the_page_and_say_how_to_reach_them() -> void:
	var j := await _journal()
	var box := j.find_child("QuestSearch", true, false) as LineEdit
	assert_true(box != null and box.is_visible_in_tree(), "the search box is there when the journal opens")
	assert_eq(box.placeholder_text, "Search quests", "and labelled")
	var screen := j.get_viewport().get_visible_rect()
	assert_true(screen.encloses(Rect2(box.get_global_rect())), "inside the screen")
	for status: String in JournalScreen.STATUS_CHIPS:
		var chip := j.find_child("Chip_" + status, true, false) as Button
		assert_true(chip != null and chip.is_visible_in_tree(), "the %s chip" % status)
		assert_true(screen.encloses(chip.get_global_rect()), "%s is inside the screen" % status)
	var said := false
	for l in j.find_children("*", "Label", true, false):
		if (l as Label).text.contains("to search"):
			said = true
	assert_true(said, "a line says how to get to the box")


func test_every_choice_is_in_the_dpads_reach_with_the_chips_and_with_nothing_found() -> void:
	var j := await _journal()
	await _button(JOY_BUTTON_DPAD_DOWN)   # the first press wakes the pad
	var missed := _unreached(nav.scope_now())
	assert_true(missed.is_empty(), "%d out of the D-pad's reach: %s" % [missed.size(), ", ".join(missed.slice(0, 12))])
	(j.find_child("QuestSearch", true, false) as LineEdit).text = "nothing like this at all"
	j.search = "nothing like this at all"
	j.call("_fill_quests")
	await _frames(2)
	var clear := j.find_child("ClearSearch", true, false) as Button
	assert_true(clear != null, "an empty list offers Clear search")
	nav.focus_on(j.find_child("Chip_all", true, false) as Control)
	missed = _unreached(nav.scope_now())
	assert_true(missed.is_empty(), "with nothing found, %d out of reach: %s" % [missed.size(), ", ".join(missed.slice(0, 12))])
	nav.focus_on(clear)
	await _button(JOY_BUTTON_A)
	assert_eq(j.search, "", "A on it clears the search")
	assert_eq((j.find_child("QuestSearch", true, false) as LineEdit).text, "")


func test_y_goes_to_the_box() -> void:
	var j := await _journal()
	await _button(JOY_BUTTON_DPAD_DOWN)
	await _button(JOY_BUTTON_Y)
	assert_eq(get_viewport().gui_get_focus_owner(), j.find_child("QuestSearch", true, false), "Y puts focus on the search box")


func test_esc_leaves_the_box_before_it_closes_the_journal() -> void:
	var j := await _journal()
	var box := j.find_child("QuestSearch", true, false) as LineEdit
	box.grab_focus()
	box.text = "oat"
	box.text_changed.emit("oat")
	await _frames(1)
	await _key(KEY_ESCAPE)
	assert_true(root.get("screen") == j, "the first Esc stays on the journal")
	assert_eq(j.search, "", "and clears what was typed")
	assert_false(box.has_focus(), "and leaves the box")
	await _key(KEY_ESCAPE)
	assert_true(root.get("screen") == null, "the next Esc closes the journal")


func test_b_leaves_the_box_before_it_closes_the_journal() -> void:
	var j := await _journal()
	await _button(JOY_BUTTON_DPAD_DOWN)
	var box := j.find_child("QuestSearch", true, false) as LineEdit
	box.grab_focus()
	box.text = "oat"
	box.text_changed.emit("oat")
	await _frames(1)
	await _button(JOY_BUTTON_B)
	assert_true(root.get("screen") == j, "the first B stays on the journal")
	assert_eq(j.search, "", "and clears what was typed")
	await _button(JOY_BUTTON_B)
	assert_true(root.get("screen") == null, "the next B closes the journal")
