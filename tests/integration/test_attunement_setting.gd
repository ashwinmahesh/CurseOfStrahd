extends TestCase
## Settings, Game, Attunement: the row is on the Game page and switches the option, and the screens that count
## attunements say so no more once it is on. (The page's scrolling is test_settings_scroll.)

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


func test_the_packs_attuned_filter_lists_worn_items_once_attunement_is_off() -> void:
	var ch := TestChars.pregen("ilse_varga", 5)
	ch.add_item("ring_of_protection")
	ch.add_item("cloak_of_protection")
	ch.attune("ring_of_protection")
	ch.wear("ring_of_protection")
	ch.wear("cloak_of_protection")
	var ring := ch.entry_of("ring_of_protection")
	var cloak := ch.entry_of("cloak_of_protection")
	assert_true(InventoryScreen.is_attuned(ch, ring), "attuned and worn")
	assert_false(InventoryScreen.is_attuned(ch, cloak), "worn, but never attuned: it does nothing")
	GameSettings.set_unlimited_attunement(true)
	assert_true(InventoryScreen.is_attuned(ch, ring), "worn and working")
	assert_true(InventoryScreen.is_attuned(ch, cloak), "every worn item that would have needed attuning is listed")
	ch.unequip_item("cloak_of_protection")
	assert_false(InventoryScreen.is_attuned(ch, cloak), "in the pack, it works for no one")
	ch.unequip_item("ring_of_protection")
	assert_false(InventoryScreen.is_attuned(ch, ring), "an old attunement alone doesn't list it once attunement is off")


## A hero of the party with the Belt of Dwarvenkind worn and `held` other attunements already used (the Belt is not one).
func _belt_wearer(held: Array[String]) -> Character:
	var ch := GameState.story.party[1]
	ch.attuned.clear()
	for id in held:
		ch.add_item(id)
		assert_true(ch.attune(id), id)
	ch.add_item("belt_of_dwarvenkind")
	assert_true(ch.wear("belt_of_dwarvenkind"))
	return ch


func _note_of(menu: Node) -> String:
	return str((menu.get("_note") as Label).text)


func test_switching_names_what_it_started_and_what_it_could_not_keep() -> void:
	var menu := await _open_game_page()
	var ch := _belt_wearer(["ring_of_protection", "amulet_of_health", "headband_of_intellect"])   # all three places taken
	var con := ch.ability_score(&"con")
	var row := menu.find_child("Attunement", true, false) as Button
	row.pressed.emit()
	assert_true(GameSettings.unlimited_attunement())
	assert_true(_note_of(menu).contains("Belt of Dwarvenkind"), "the note names what began to work: %s" % _note_of(menu))
	assert_true(ch.ability_score(&"con") > con, "and it works at once")
	row.pressed.emit()
	assert_false(GameSettings.unlimited_attunement())
	assert_true(_note_of(menu).contains("Belt of Dwarvenkind") and _note_of(menu).contains("Idle again"),
		"going back, the one that no longer fits is named: %s" % _note_of(menu))
	assert_false(ch.attuned_to("belt_of_dwarvenkind"))


func test_going_back_attunes_what_works_while_there_is_room() -> void:
	var menu := await _open_game_page()
	var ch := _belt_wearer(["ring_of_protection"])
	var row := menu.find_child("Attunement", true, false) as Button
	row.pressed.emit()
	row.pressed.emit()
	assert_true("belt_of_dwarvenkind" in ch.attuned, "attuned on the way back, so it keeps working")
	assert_true(_note_of(menu).begins_with("Three at most: attuned"), _note_of(menu))
	assert_true(_note_of(menu).length() <= 96, "and it fits the note's two lines")


func test_the_pack_says_a_worn_item_is_not_attuned() -> void:
	var menu := await _open_game_page()
	var ch := _belt_wearer(["ring_of_protection"])
	menu.queue_free()
	root.call("close_screen")
	await _frames(2)
	for tag: String in ["book", "unlimited"]:
		if tag == "unlimited":
			GameSettings.set_unlimited_attunement(true)
		root.call("open_screen", "inventory", 1)
		await _frames(3)
		var found := false
		for n in (root.get("screen") as Node).find_children("*", "Label", true, false):
			if (n as Label).text == "Not attuned" and (n as Control).is_visible_in_tree():
				found = true
		assert_eq(found, tag == "book", "%s: the Not attuned tag shows for the idle Belt only under the book's rule" % tag)
		root.call("close_screen")
		await _frames(2)
	assert_true(ch.idle_for_attunement(ch.entry_of("belt_of_dwarvenkind")) == false, "unlimited: not idle")
