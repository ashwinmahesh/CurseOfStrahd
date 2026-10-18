extends TestCase
## Settings, Game, Attunement: the row is on the Game page, switches the option, clears the Back button below it, and
## the screens that count attunements say so no more once it is on.

var root: Node


func _frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame


func after_each() -> void:
	GameSettings.set_unlimited_attunement(false)
	if root != null:
		root.queue_free()
		root = null
	GameState.reset()
	SaveSystem.current_slot = ""


func _open_game_page() -> Node:
	DirAccess.make_dir_recursive_absolute(SaveSystem.save_dir)
	var out := FileAccess.open(SaveSystem.slot_path("attune"), FileAccess.WRITE)
	out.store_string(FileAccess.get_file_as_string(GoldenSaves.DIR + "v2_amber_temple.json"))
	out.close()
	assert_eq(SaveSystem.load_slot("attune"), OK)
	SaveSystem.delete_slot("attune")
	root = (load("res://scenes/game.tscn") as PackedScene).instantiate()
	add_child(root)
	await _frames(5)
	root.call("open_screen", "menu", 0)
	await _frames(1)
	root.get("screen").call("_show_settings", "Game")
	await _frames(3)
	return root.get("screen") as Node


func _by_text(menu: Node, text: String) -> Control:
	for n in menu.find_children("*", "Control", true, false):
		var c := n as Control
		if c.is_visible_in_tree() and ((c is Button and (c as Button).text.contains(text)) or (c is Label and (c as Label).text == text)):
			return c
	return null


func test_the_game_page_has_the_row_and_it_switches_the_option() -> void:
	var menu := await _open_game_page()
	var row := menu.find_child("Attunement", true, false) as Button
	assert_true(row != null, "an Attunement row on the Game page")
	assert_true(row.text.contains("Three at most"), row.text)
	assert_false(GameSettings.unlimited_attunement())
	row.pressed.emit()
	assert_true(GameSettings.unlimited_attunement(), "one click turns it on")
	assert_true(MagicItems.attunement_off)
	assert_true(row.text.contains("Unlimited"), row.text)
	row.pressed.emit()
	assert_false(GameSettings.unlimited_attunement(), "the next turns it off")
	assert_true(row.has_meta(&"pad_adjust"), "and the pad's left and right turn it, as on every row")


func test_no_row_of_the_game_page_runs_into_another_or_into_back() -> void:
	var menu := await _open_game_page()
	var rows: Array[Control] = []
	for n in menu.find_children("*", "Button", true, false):
		var b := n as Button
		if b.is_visible_in_tree() and b.text.begins_with("‹"):
			rows.append(b)
	var respec: Control = null
	for n in menu.find_children("*", "CheckBox", true, false):
		if (n as Control).is_visible_in_tree():
			respec = n as Control
	assert_true(rows.size() >= 8, "the choice rows are there: %d" % rows.size())
	assert_true(respec != null, "and the respec box")
	var all: Array[Control] = rows.duplicate()
	if respec != null:
		all.append(respec)
	all.sort_custom(func(a: Control, b: Control) -> bool: return a.get_global_rect().position.y < b.get_global_rect().position.y)
	for i in range(1, all.size()):
		assert_true(all[i - 1].get_global_rect().end.y <= all[i].get_global_rect().position.y + 1.0,
			"row %d clears row %d" % [i, i - 1])
	var back := _by_text(menu, "Back")
	assert_true(back != null, "a Back button")
	if back != null and respec != null:
		assert_true(respec.get_global_rect().end.y <= back.get_global_rect().position.y, "the last item clears Back")


func _sheet_says_attunement_is_off() -> bool:
	root.call("open_screen", "sheet", 0)
	await _frames(3)
	var sheet := root.get("screen") as CharacterSheetScreen
	sheet.show_tab("Equipment")
	await _frames(2)
	var found := false
	for n in sheet.find_children("*", "Label", true, false):
		if (n as Label).text.begins_with("Attunement is off"):
			found = true
	root.call("close_screen")
	await _frames(2)
	return found


func test_the_sheet_stops_counting_attunements_once_it_is_off() -> void:
	var menu := await _open_game_page()
	menu.queue_free()
	root.call("close_screen")
	await _frames(2)
	assert_false(await _sheet_says_attunement_is_off(), "by default the sheet counts attunements")
	GameSettings.set_unlimited_attunement(true)
	assert_true(await _sheet_says_attunement_is_off(), "with the option it says attunement is off")
