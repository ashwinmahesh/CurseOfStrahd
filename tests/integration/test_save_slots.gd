extends TestCase
## Save Game picks where the save goes (owner, 2026-10-07: "we should be able to select the slot to save to, or save
## to a new slot"): a new slot, or over one of the player's own saves once they confirm. The saves are a page of their
## own (ui/screens/saves_screen.gd) over the pause menu, the game-over screen and the title, the list scrolls, and
## Back or Escape returns to whatever opened it.

var root: Node
var _real_dir := ""


func before_each() -> void:
	# A folder of this test's own inside the run's, so other test files' saves never show in its lists.
	_real_dir = SaveSystem.save_dir
	SaveSystem.save_dir = _real_dir.path_join("save_slots/")
	DirAccess.make_dir_recursive_absolute(SaveSystem.save_dir)
	SaveSystem.current_slot = ""
	# Saving is refused in a fight; an earlier file in the same run may have left fight mode on.
	ModeController.force(ModeController.Mode.EXPLORATION)
	Compendium.shared().tables["locations"]["test_hall"] = {"id": "test_hall", "name": "Test Hall", "region": "test", "summary": "",
		"map": {"rows": ["#####", "#...#", "#...#", "#####"]}, "spawns": {"default": [1, 1]}, "rest": "safe"}
	GameState.reset()
	for id: String in ["ilse_varga", "tamsin_tealeaf"]:
		var ch := Pregens.build(id, 1)
		ch.finish_long_rest()
		GameState.story.party.append(ch)
	GameState.story.location = "test_hall"
	root = (load("res://scenes/game.tscn") as PackedScene).instantiate()
	add_child(root)
	await _frames(2)


func after_each() -> void:
	get_tree().paused = false
	if root != null:
		root.queue_free()
		root = null
	for f in DirAccess.get_files_at(SaveSystem.save_dir):
		DirAccess.remove_absolute(SaveSystem.save_dir.path_join(f))
	DirAccess.remove_absolute(SaveSystem.save_dir)
	SaveSystem.save_dir = _real_dir
	SaveSystem.current_slot = ""
	GameState.reset()
	(Compendium.shared().tables["locations"] as Dictionary).erase("test_hall")


func _frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame


func _menu() -> PauseMenu:
	root.call("open_screen", "menu", 0)
	await _frames(1)
	return root.get("screen") as PauseMenu


## The button showing `text` under `n` (not one on its way out), or null.
static func _button(n: Node, text: String) -> Button:
	for b in n.find_children("*", "Button", true, false):
		if (b as Button).text == text and not b.is_queued_for_deletion():
			return b as Button
	return null


func _press(n: Node, text: String) -> void:
	var b := _button(n, text)
	assert_true(b != null, "a %s button" % text)
	if b != null:
		assert_false(b.disabled, "%s can be pressed" % text)
		b.pressed.emit()
	await _frames(1)


## The saves page open under `n`, or null.
static func _page(n: Node) -> SavesScreen:
	for p in n.find_children("*", "SavesScreen", true, false):
		if not p.is_queued_for_deletion() and (p as SavesScreen).process_mode != Node.PROCESS_MODE_DISABLED:
			return p as SavesScreen
	return null


## A row's own button ("Save Here" or "Load") for `slot`.
static func _row_button(page: SavesScreen, slot: String) -> Button:
	var row := page.find_child(slot, true, false)
	return row.find_child("Act", true, false) as Button if row != null else null


func _escape() -> void:
	var ev := InputEventAction.new()
	ev.action = &"combat_cancel"
	ev.pressed = true
	get_tree().root.push_input(ev)
	await _frames(1)


## What a save on disk holds.
static func _on_disk(slot: String) -> Dictionary:
	return JSON.parse_string(FileAccess.get_file_as_string(SaveSystem.slot_path(slot))) as Dictionary


func test_save_game_offers_a_new_slot_or_the_players_own_saves() -> void:
	assert_eq(SaveSystem.save("older"), OK)
	assert_eq(SaveSystem.autosave(), OK)
	var menu := await _menu()
	await _press(menu, "Save Game")
	var page := _page(menu)
	assert_true(page != null, "Save Game opens the saves page")
	if page == null:
		return
	assert_eq(page.mode, SavesScreen.Mode.SAVE)
	assert_false((menu.get("_frame") as Control).visible, "the arch hides under it")
	assert_true(_button(page, "New Save") != null, "a new slot")
	var offered: Array = page.slots().map(func(s: Dictionary) -> String: return str(s["slot"]))
	assert_eq(offered, ["older"], "only the player's own saves to save over, never the autosave")
	assert_true(_row_button(page, "older") != null and _row_button(page, "older").text == "Save Here")


func test_a_new_save_keeps_every_other() -> void:
	assert_eq(SaveSystem.save("older"), OK)
	SaveSystem.current_slot = ""
	var menu := await _menu()
	await _press(menu, "Save Game")
	await _press(_page(menu), "New Save")
	assert_eq(SaveSystem.list_slots().size(), 2, "a second save beside the first")
	assert_true(SaveSystem.current_slot not in ["", "older"], "the new slot is the game's own")
	assert_true(_page(menu) == null, "saving closes the page")
	assert_true((menu.get("_frame") as Control).visible, "back on the menu")
	assert_eq((menu.get("_note") as Label).text, "Saved.")
	assert_false(_button(menu, "Load a Save").disabled, "and there's something to load")


func test_saving_over_a_save_asks_first() -> void:
	GameState.story.gold = 10.0
	assert_eq(SaveSystem.save("older"), OK)
	GameState.story.gold = 777.0
	var menu := await _menu()
	await _press(menu, "Save Game")
	var page := _page(menu)
	_row_button(page, "older").pressed.emit()
	await _frames(1)
	assert_true(page.confirm_open(), "Save Here asks first")
	assert_eq(float((_on_disk("older")["story"] as Dictionary)["gold"]), 10.0, "nothing written yet")
	await _press(page, "Cancel")
	assert_false(page.confirm_open(), "Cancel closes the question")
	assert_true(_page(menu) == page, "and keeps the page")
	assert_eq(float((_on_disk("older")["story"] as Dictionary)["gold"]), 10.0, "the save as it was")
	_row_button(page, "older").pressed.emit()
	await _frames(1)
	await _escape()
	assert_false(page.confirm_open(), "Escape closes the question")
	assert_true(_page(menu) == page, "but not the page")
	_row_button(page, "older").pressed.emit()
	await _frames(1)
	await _press(page, "Overwrite")
	assert_eq(float((_on_disk("older")["story"] as Dictionary)["gold"]), 777.0, "written over")
	assert_eq(SaveSystem.list_slots().size(), 1, "no new slot")
	assert_eq(SaveSystem.current_slot, "older", "the game's own slot from now on (F5 saves there)")
	assert_true(_page(menu) == null, "back to the menu")


func test_escape_steps_back_one_page_at_a_time() -> void:
	var menu := await _menu()
	await _press(menu, "Save Game")
	assert_true(_page(menu) != null)
	await _escape()
	assert_true(_page(menu) == null, "Escape closes the saves page")
	assert_true(root.get("screen") == menu, "and leaves the menu open")
	assert_true((menu.get("_frame") as Control).visible)
	await _escape()
	assert_true(root.get("screen") == null, "the next Escape closes the menu")
	await _frames(1)
	var again := await _menu()
	await _press(again, "Save Game")
	await _press(_page(again), "Back")
	assert_true(_page(again) == null and root.get("screen") == again, "Back does the same")
	root.call("close_screen")


func test_load_a_save_lists_every_save_and_loads_one() -> void:
	GameState.story.gold = 42.0
	assert_eq(SaveSystem.save("older"), OK)
	assert_eq(SaveSystem.autosave(), OK)
	GameState.story.gold = 5.0
	var menu := await _menu()
	var went: Array[String] = []
	menu.scene_changer = func(path: String) -> void: went.append(path)
	await _press(menu, "Load a Save")
	var page := _page(menu)
	assert_true(page != null and page.mode == SavesScreen.Mode.LOAD, "Load a Save opens the page to load")
	var offered: Array = page.slots().map(func(s: Dictionary) -> String: return str(s["slot"]))
	assert_true("older" in offered and SaveSystem.AUTOSAVE in offered, "every save, the autosave too: %s" % [offered])
	assert_true(_button(page, "New Save") == null, "nothing to save from here")
	_row_button(page, "older").pressed.emit()
	assert_eq(went, [PauseMenu.GAME_SCENE] as Array[String], "off to the game")
	assert_eq(GameState.story.gold, 42.0, "as saved")
	assert_eq(SaveSystem.current_slot, "older")
	root.call("close_screen")


func test_the_game_over_screen_loads_through_the_page() -> void:
	assert_eq(SaveSystem.save("older"), OK)
	root.call("open_screen", "game_over", 0)
	await _frames(1)
	var over := root.get("screen") as PauseMenu
	assert_true(_button(over, "Quit to Title") != null, "a way out")
	assert_true(_button(over, "Last Autosave") == null, "no autosave to go back to yet")
	root.call("close_screen")
	assert_eq(SaveSystem.autosave(), OK)
	root.call("open_screen", "game_over", 0)
	await _frames(1)
	over = root.get("screen") as PauseMenu
	assert_true(_button(over, "Last Autosave") != null, "back to the last autosave")
	var said := over.find_children("*", "Label", true, false).filter(func(l: Node) -> bool:
		return (l as Label).text.begins_with("The last autosave"))
	assert_eq(said.size(), 1, "the arch says where the last autosave was made")
	await _press(over, "Load a Save")
	var page := _page(over)
	assert_true(page != null and page.mode == SavesScreen.Mode.LOAD)
	await _escape()
	assert_true(_page(over) == null and root.get("screen") == over, "Escape goes back to the fallen party")
	assert_true(_button(over, "Load a Save") != null)
	root.call("close_screen")


func test_the_title_loads_on_a_page_that_scrolls() -> void:
	# More saves than the page has room for.
	assert_eq(SaveSystem.save("first"), OK)
	var text := FileAccess.get_file_as_string(SaveSystem.slot_path("first"))
	for i in 24:
		var f := FileAccess.open(SaveSystem.slot_path("copy_%02d" % i), FileAccess.WRITE)
		f.store_string(text)
		f.close()
	root.queue_free()
	root = null
	var title := (load("res://scenes/main_menu.tscn") as PackedScene).instantiate()
	add_child(title)
	await _frames(2)
	var column := title.get("_box") as VBoxContainer
	var rows_before := column.get_child_count()
	await _press(title, "Load")
	var page := _page(title)
	assert_true(page != null, "Load opens the saves page")
	if page == null:
		title.queue_free()
		return
	await _frames(2)
	assert_eq(column.get_child_count(), rows_before, "the title's column keeps its own buttons")
	assert_false(column.visible, "hidden under the page")
	var scroll := page.find_children("*", "ScrollContainer", true, false)[0] as ScrollContainer
	var bar := scroll.get_v_scroll_bar()
	assert_true(bar.max_value > bar.page + 1.0, "the list is longer than its box, so it scrolls (%s in %s)" % [bar.max_value, bar.page])
	assert_eq(page.slots().size(), 25)
	await _escape()
	assert_true(_page(title) == null, "Escape closes the page")
	assert_eq(str(title.get("_view")), "title", "back on the title")
	assert_true(column.visible, "its column showing again")
	title.queue_free()


func test_new_slots_never_take_an_old_ones_name() -> void:
	var a := SaveSystem.new_slot_name()
	assert_eq(SaveSystem.save(a), OK)
	var b := SaveSystem.new_slot_name()
	assert_ne(a, b, "a second save in the same second gets a name of its own")
	assert_eq(SaveSystem.save(b), OK)
	assert_eq(SaveSystem.list_slots().size(), 2)


func test_files_beside_the_saves_are_not_saves() -> void:
	# N8 keeps achievements.json in the saves folder.
	var f := FileAccess.open(SaveSystem.save_dir.path_join("achievements.json"), FileAccess.WRITE)
	f.store_string(JSON.stringify({"first_victory": "2026-10-07"}))
	f.close()
	assert_eq(SaveSystem.save("real"), OK)
	var listed: Array = SaveSystem.list_slots().map(func(s: Dictionary) -> String: return str(s["slot"]))
	assert_eq(listed, ["real"], "only the save is listed")
