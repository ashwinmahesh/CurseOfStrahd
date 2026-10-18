extends TestCase
## Armor its wearer has no training with shuts their spells (2024 Armor Training; owner report 2026-10-18: Liriel in Plate
## Armor +1). The inventory says so in its note the moment the armor goes on, however it goes on: the right-click menu and
## double-click, the card's Wear button, a drag onto the armor slot. Armor they are trained for says nothing.

const PLATE := "armor_plus_1__plate_armor"

var root: Node


func before_each() -> void:
	Compendium.shared().tables["locations"]["untrained_inn"] = {"id": "untrained_inn", "name": "Inn", "region": "test", "summary": "",
		"map": {"rows": ["#####", "#...#", "#...#", "#####"]}, "spawns": {"default": [1, 1]}, "rest": "safe"}
	GameState.reset()
	for id: String in ["godrick_pendlebrook", "liriel_dawnsong"]:
		var ch := TestChars.pregen(id, 5)
		ch.finish_long_rest()
		GameState.story.party.append(ch)
	GameState.story.location = "untrained_inn"
	root = (load("res://scenes/game.tscn") as PackedScene).instantiate()
	add_child(root)
	await get_tree().process_frame


func after_each() -> void:
	(Compendium.shared().tables["locations"] as Dictionary).erase("untrained_inn")
	if root != null:
		root.queue_free()
		root = null
	GameState.reset()


func _frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame


func _open(i: int) -> InventoryScreen:
	root.call("open_screen", "inventory", i)
	await _frames(2)
	return root.get("screen") as InventoryScreen


func _note(inv: InventoryScreen) -> String:
	return str(inv.get("_note"))


func _wear_action(inv: InventoryScreen, ch: Character) -> Dictionary:
	for a in inv.actions_for(ch.entry_of(PLATE)):
		if str(a["label"]).begins_with("Wear"):
			return a
	return {}


func test_the_static_warning_names_the_kind_and_the_armor_only_for_the_untrained() -> void:
	var liriel := GameState.story.party[1]
	var godrick := GameState.story.party[0]
	var warning := InventoryScreen.untrained_warning(liriel, PLATE)
	var armor_name := Compendium.shared().display_name("items", PLATE)
	assert_true(warning.contains("Liriel") and warning.contains("heavy armor") and warning.contains(armor_name), warning)
	assert_true(warning.contains("no spells"), "it says what it costs: %s" % warning)
	assert_eq(InventoryScreen.untrained_warning(godrick, PLATE), "", "a Paladin is trained in Heavy armor")
	assert_eq(InventoryScreen.untrained_warning(liriel, "breastplate"), "", "a Cleric is trained in Medium armor")
	assert_eq(InventoryScreen.untrained_warning(liriel, "longsword"), "", "a weapon is not armor")


func test_wearing_it_from_the_menu_says_so() -> void:
	var liriel := GameState.story.party[1]
	liriel.add_item(PLATE)
	var inv := await _open(1)
	var act := _wear_action(inv, liriel)
	assert_false(act.is_empty(), "the menu offers to wear it")
	(act["call"] as Callable).call()
	await _frames(1)
	assert_eq(liriel.held_id("armor"), PLATE, "it is on")
	assert_true(_note(inv).contains("no training") and _note(inv).contains("no spells"), "the note says what it costs: %s" % _note(inv))
	assert_eq(str(inv.get("_note_colour")), "flame", "as a warning")


func test_wearing_it_from_the_cards_wear_button_says_so() -> void:
	var liriel := GameState.story.party[1]
	liriel.add_item(PLATE)
	var inv := await _open(1)
	inv.selected = PLATE
	inv.call("_draw")
	await _frames(1)
	var wear: Button = null
	for b in inv.find_children("*", "Button", true, false):
		if (b as Button).text == "Wear" and (b as Button).is_visible_in_tree() and not b.is_queued_for_deletion():
			wear = b as Button
	assert_true(wear != null, "the card has a Wear button")
	if wear == null:
		return
	wear.pressed.emit()
	await _frames(1)
	assert_eq(liriel.held_id("armor"), PLATE, "it is on")
	assert_true(_note(inv).contains("no training"), _note(inv))


func test_dragging_it_onto_the_armor_slot_says_so_and_trained_armor_does_not() -> void:
	var liriel := GameState.story.party[1]
	liriel.add_item(PLATE)
	liriel.add_item("breastplate")
	var inv := await _open(1)
	inv.call("_drop_on_slot", {"id": PLATE, "from": "pack", "entry": liriel.entry_of(PLATE)}, "armor", liriel.equipped("armor"))
	assert_eq(liriel.held_id("armor"), PLATE, "dropped on the slot, it is on")
	assert_true(_note(inv).contains("no training"), "the drop says so, not just 'Armor: ...': %s" % _note(inv))
	inv.call("_drop_on_slot", {"id": "breastplate", "from": "pack", "entry": liriel.entry_of("breastplate")}, "armor", liriel.equipped("armor"))
	assert_eq(liriel.held_id("armor"), "breastplate", "the breastplate replaces it")
	assert_false(_note(inv).contains("no training"), "and armor she is trained for says nothing of the kind: %s" % _note(inv))
	assert_true(liriel.armor_cast_blocker() == "", "so she can cast again")
