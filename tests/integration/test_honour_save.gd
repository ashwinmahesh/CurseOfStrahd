extends TestCase
## Honour's one save (F1, combat/difficulty.gd's one_save; SaveSystem's Honour part): an Honour run keeps one save, its
## own slot, which the autosaves, the start of each fight, Save Game and F5 all write over. A wipe ends the Honour run:
## the game and its save carry on in Tactician, for good (lane 22's pick).

var root: Node
var _real_dir := ""


func before_each() -> void:
	_real_dir = SaveSystem.save_dir
	SaveSystem.save_dir = _real_dir.path_join("honour/")
	DirAccess.make_dir_recursive_absolute(SaveSystem.save_dir)
	SaveSystem.current_slot = ""
	ModeController.force(ModeController.Mode.EXPLORATION)
	Compendium.shared().tables["locations"]["test_hall"] = {"id": "test_hall", "name": "Test Hall", "region": "test", "summary": "",
		"map": {"rows": ["#####", "#...#", "#...#", "#####"]}, "spawns": {"default": [1, 1]}, "rest": "safe"}
	GameState.reset()
	for id: String in ["ilse_varga", "tamsin_tealeaf"]:
		var ch := Pregens.build(id, 1)
		ch.finish_long_rest()
		GameState.story.party.append(ch)
	GameState.story.location = "test_hall"
	GameState.story.options["difficulty"] = "honour"
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
	ModeController.force(ModeController.Mode.EXPLORATION)
	(Compendium.shared().tables["locations"] as Dictionary).erase("test_hall")


func _frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame


static func _button(n: Node, text: String) -> Button:
	for b in n.find_children("*", "Button", true, false):
		if (b as Button).text == text and not b.is_queued_for_deletion():
			return b as Button
	return null


static func _on_disk(slot: String) -> Dictionary:
	return JSON.parse_string(FileAccess.get_file_as_string(SaveSystem.slot_path(slot))) as Dictionary


static func _slots() -> Array:
	return SaveSystem.list_slots().map(func(s: Dictionary) -> String: return str(s["slot"]))


func test_an_honour_run_keeps_one_save() -> void:
	assert_true(SaveSystem.honour())
	assert_eq(SaveSystem.autosave(), OK)
	var slot := SaveSystem.current_slot
	assert_true(slot != "" and not SaveSystem.is_beside(slot), "the first autosave makes the run's own slot")
	GameState.story.gold = 55.0
	assert_eq(SaveSystem.autosave(), OK)
	assert_eq(SaveSystem.quick_save(), OK)
	assert_eq(_slots(), [slot], "autosaves and F5 all write over the one save: %s" % [_slots()])
	assert_eq(float((_on_disk(slot)["story"] as Dictionary)["gold"]), 55.0)
	assert_eq(str(SaveSystem.describe(slot)["mode"]), "Honour", "the lists say it's an Honour run")


func test_a_fight_is_kept_as_it_starts() -> void:
	assert_eq(SaveSystem.autosave(), OK)
	var slot := SaveSystem.current_slot
	GameState.combat_snapshot = {"location": "test_hall", "encounter": "rat", "data": {"round": 1}}
	assert_eq(SaveSystem.save_round(), OK)
	assert_false(SaveSystem.has_slot(SaveSystem.ROUND_START), "no round-start save beside it")
	assert_eq(int(((_on_disk(slot)["combat"] as Dictionary)["data"] as Dictionary)["round"]), 1, "the fight's start is the save")
	GameState.combat_snapshot = {"location": "test_hall", "encounter": "rat", "data": {"round": 3}}
	assert_eq(SaveSystem.save_round(), OK)
	assert_eq(int(((_on_disk(slot)["combat"] as Dictionary)["data"] as Dictionary)["round"]), 1,
		"later rounds leave it at the start: leaving mid-fight comes back to the start, never past it")
	GameState.combat_snapshot = {}


func test_save_game_writes_over_the_one_save() -> void:
	assert_eq(SaveSystem.save("other_game"), OK)   # another playthrough's save, made before this one
	SaveSystem.current_slot = ""
	assert_eq(SaveSystem.autosave(), OK)
	var slot := SaveSystem.current_slot
	root.call("open_screen", "menu", 0)
	await _frames(1)
	var menu := root.get("screen") as PauseMenu
	_button(menu, "Save Game").pressed.emit()
	await _frames(1)
	var page := menu.find_children("*", "SavesScreen", true, false)[0] as SavesScreen
	assert_false(_button(page, "New Save").visible, "no second save")
	assert_eq(page.slots().map(func(s: Dictionary) -> String: return str(s["slot"])), [slot], "only the run's own save")
	(page.find_child(slot, true, false).find_child("Act", true, false) as Button).pressed.emit()
	assert_false(page.confirm_open(), "saving over its own one save asks nothing")
	assert_eq(SaveSystem.current_slot, slot)
	await _frames(1)
	# The page closed with the save (and may be freed by now): only the menu is left.
	assert_true(menu.find_children("*", "SavesScreen", true, false).all(func(p: Node) -> bool:
		return p.is_queued_for_deletion() or (p as CanvasLayer).process_mode == Node.PROCESS_MODE_DISABLED), "back on the menu")
	root.call("close_screen")


func test_a_wipe_carries_on_in_tactician() -> void:
	assert_eq(SaveSystem.autosave(), OK)
	var slot := SaveSystem.current_slot
	root.call("open_screen", "game_over", 0)
	await _frames(1)
	var over := root.get("screen") as PauseMenu
	assert_eq(str(GameState.story.options["difficulty"]), "tactician", "the run is no longer Honour")
	assert_eq(str(((_on_disk(slot)["story"] as Dictionary)["options"] as Dictionary)["difficulty"]), "tactician",
		"nor its save, whatever the player does next")
	assert_true(_button(over, "Last Autosave") == null, "an Honour run has no autosaves of its own")
	var went: Array[String] = []
	over.scene_changer = func(path: String) -> void: went.append(path)
	var carry := _button(over, "Carry On")
	assert_true(carry != null, "the way on")
	if carry != null:
		carry.pressed.emit()
	assert_eq(went, [PauseMenu.GAME_SCENE] as Array[String])
	assert_false(SaveSystem.honour(), "carried on in Tactician")
	root.call("close_screen")
	assert_eq(SaveSystem.autosave(), OK)
	assert_true(SaveSystem.has_slot(SaveSystem.AUTOSAVE), "and saving is as ever now")
