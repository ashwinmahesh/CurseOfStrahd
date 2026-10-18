extends TestCase
## The journal's Other tab filed by region on a pad (Ashwin, 2026-10-18; story/quest_regions.gd, docs/ui/controller.md),
## with every quest in the game taken: the D-pad reaches every quest across the region headings, and a press down from a
## row lands on the next row in the list, never on a heading. B going back from the journal is test_pad_screens'.

const LATE := "v2_amber_temple.json"

var root: Node
var nav: PadNav


func before_each() -> void:
	InputActions.ensure()
	nav = PadNav.current
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


## The game, loaded from golden save `f`.
func _game(f: String) -> void:
	DirAccess.make_dir_recursive_absolute(SaveSystem.save_dir)
	var out := FileAccess.open(SaveSystem.slot_path("pad"), FileAccess.WRITE)
	out.store_string(FileAccess.get_file_as_string(GoldenSaves.DIR + f))
	out.close()
	assert_eq(SaveSystem.load_slot("pad"), OK, "%s loads" % f)
	SaveSystem.delete_slot("pad")
	root = (load("res://scenes/game.tscn") as PackedScene).instantiate()
	add_child(root)
	await _frames(5)
	(root.get("hud") as ExploreHud).close_narration()
	await _frames(1)


func _press(button: JoyButton) -> void:
	for down: bool in [true, false]:
		var ev := InputEventJoypadButton.new()
		ev.button_index = button
		ev.pressed = down
		get_viewport().push_input(ev)
	await _frames(2)


func _trigger(axis: JoyAxis) -> void:
	for v: float in [1.0, 0.0]:
		var ev := InputEventJoypadMotion.new()
		ev.axis = axis
		ev.axis_value = v
		get_viewport().push_input(ev)
	await _frames(2)


## The quest rows of the journal's list, top to bottom.
func _rows(n: Node, out: Array[String]) -> void:
	for c in n.get_children():
		if str(c.name).begins_with("Quest_"):
			out.append(str(c.name))
		_rows(c, out)


func test_the_journal_by_region_on_a_pad() -> void:
	await _game(LATE)
	for q: Dictionary in Compendium.shared().all("quests"):
		GameState.story.set_quest_stage(str(q["id"]), str(((q["stages"] as Array)[0] as Dictionary)["id"]))
	root.call("open_screen", "journal", 0)
	await _frames(3)
	var journal := root.get("screen") as JournalScreen
	await _press(JOY_BUTTON_DPAD_DOWN)   # the first press wakes the pad
	if journal.quest_tab != "Other":
		await _trigger(JOY_AXIS_TRIGGER_RIGHT)
	assert_eq(journal.quest_tab, "Other", "RT turns to the other quests")
	await _frames(2)
	var rows: Array[String] = []
	_rows(journal.find_child("QuestList", true, false), rows)
	assert_true(rows.size() > 40, "a long list of side quests (%d)" % rows.size())
	assert_true(journal.find_child("Region_vallaki", true, false) != null, "with a heading for each region")
	# Every choice on the screen is in the D-pad's reach, by PadNav's own neighbour rule.
	var scope := nav.scope_now()
	var start := nav.focus_in(scope)
	assert_true(start != null, "a press put focus on the journal")
	if start == null:
		return
	var list := PadNav.choices(scope)
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
	assert_true(missed.is_empty(), "%d of %d choices out of the D-pad's reach: %s" % [missed.size(), list.size(), ", ".join(missed.slice(0, 12))])
	# Down from a quest lands on the next quest in the list, over any region heading.
	var here := nav.focus_in(scope)
	assert_true(here != null and here.get_parent() != null and str(here.get_parent().name).begins_with("Quest_"), "the pad is on a quest")
	if here == null or here.get_parent() == null:
		return
	var i := rows.find(str(here.get_parent().name))
	assert_true(i >= 0 and i < rows.size() - 1, "and not on the last one")
	if i < 0 or i >= rows.size() - 1:
		return
	await _press(JOY_BUTTON_DPAD_DOWN)
	var next := nav.focus_in(scope)
	assert_true(next != null and next.get_parent() != null, "down lands on a quest")
	if next != null and next.get_parent() != null:
		assert_eq(str(next.get_parent().name), rows[i + 1], "the next quest in the list, over any region heading")
