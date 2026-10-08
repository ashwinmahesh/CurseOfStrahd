extends TestCase
## Owner request (2026-10-08): right-click a Spell Scroll in the inventory and Cast it (Find Familiar was his example).
## The menu offers "Cast <spell>" to a reader who can, greyed with the reason for one who can't, and double-clicking
## never uses a scroll up.

var root: Node


func before_each() -> void:
	Compendium.shared().tables["locations"]["scroll_inn"] = {"id": "scroll_inn", "name": "Scroll Inn", "region": "test",
		"summary": "", "map": {"rows": ["#####", "#...#", "#...#", "#####"]}, "spawns": {"default": [1, 1]}, "rest": "safe"}
	GameState.reset()
	for id: String in ["silvain_aster", "ilse_varga"]:
		var ch := Pregens.build(id, 3)
		ch.finish_long_rest()
		GameState.story.party.append(ch)
	GameState.story.location = "scroll_inn"
	root = (load("res://scenes/game.tscn") as PackedScene).instantiate()
	add_child(root)
	await get_tree().process_frame


func after_each() -> void:
	Compendium.shared().tables["locations"].erase("scroll_inn")
	if root != null:
		root.queue_free()
		root = null


func _frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame


func _open(i: int) -> InventoryScreen:
	root.call("open_screen", "inventory", i)
	await _frames(2)
	return root.get("screen") as InventoryScreen


func _cast(acts: Array[Dictionary]) -> Dictionary:
	for a in acts:
		if str(a["label"]) == "Cast Find Familiar":
			return a
	return {}


func test_a_wizard_casts_a_scroll_from_the_right_click_menu() -> void:
	var wiz := GameState.story.party[0]
	wiz.familiar = ""
	wiz.add_item("spell_scroll__find_familiar")
	var inv := await _open(0)
	var cast := _cast(inv.actions_for(wiz.entry_of("spell_scroll__find_familiar")))
	assert_false(cast.is_empty(), "the menu offers Cast Find Familiar")
	assert_false(bool(cast.get("disabled", false)), str(cast.get("tooltip", "")))
	inv._activate(wiz.entry_of("spell_scroll__find_familiar"))
	assert_true(wiz.carries("spell_scroll__find_familiar"), "double-clicking doesn't use it up")
	(cast["call"] as Callable).call()
	await _frames(1)
	assert_false(wiz.carries("spell_scroll__find_familiar"), "read and gone")
	assert_eq(wiz.familiar, "here")


func test_a_fighter_sees_why_not() -> void:
	var fighter := GameState.story.party[1]
	fighter.add_item("spell_scroll__find_familiar")
	var inv := await _open(1)
	var cast := _cast(inv.actions_for(fighter.entry_of("spell_scroll__find_familiar")))
	assert_false(cast.is_empty(), "offered, greyed")
	assert_true(bool(cast.get("disabled", false)))
	assert_eq(str(cast.get("tooltip", "")), "Not on your class's spell list")


## The scroll's spell reaches the place the party stands in, as a cast from the character sheet does
## (LocationView.apply_spell_effect): Detect Magic names what's near, Find Familiar shows the familiar.
func test_a_scroll_cast_from_the_inventory_reaches_the_world() -> void:
	var wiz := GameState.story.party[0]
	wiz.add_item("spell_scroll__detect_magic")
	var view := root.get("view") as LocationView
	var said: Array[String] = []
	view.narration.connect(func(text: String) -> void: said.append(text))
	var inv := await _open(0)
	var cast: Dictionary = {}
	for a in inv.actions_for(wiz.entry_of("spell_scroll__detect_magic")):
		if str(a["label"]) == "Cast Detect Magic":
			cast = a
	assert_false(cast.is_empty(), "Cast Detect Magic is offered")
	(cast["call"] as Callable).call()
	await _frames(1)
	assert_true(said.any(func(s: String) -> bool: return s.begins_with("Magic within 30 ft")), str(said))
