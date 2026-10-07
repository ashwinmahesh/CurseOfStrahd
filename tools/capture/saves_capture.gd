extends Node
## The saves' own page (ui/screens/saves_screen.gd, lane 16) from a late party, with the golden saves as the list:
## Save Game, the question before writing over a save, Load a Save, the game-over screen and the title's Load. Saves of
## the capture's own only, so the owner's never show or change.
## make capture SCENE=res://tools/capture/saves_capture.tscn NAME=saves FRAMES=30

const LATE := "v2_amber_temple.json"

var root: Node
var _real_dir := ""
var _made: Array[String] = []


func _ready() -> void:
	_real_dir = SaveSystem.save_dir
	SaveSystem.save_dir = "user://capture_saves/%d/" % OS.get_process_id()
	DirAccess.make_dir_recursive_absolute(SaveSystem.save_dir)
	for f in DirAccess.get_files_at(GoldenSaves.DIR):
		if f.ends_with(".json"):
			_copy(f, f.get_basename())
	_copy(LATE, "capture_game")
	SaveSystem.load_slot("capture_game")
	root = (load("res://scenes/game.tscn") as PackedScene).instantiate()
	add_child(root)


func _copy(golden: String, slot: String) -> void:
	var out := FileAccess.open(SaveSystem.slot_path(slot), FileAccess.WRITE)
	out.store_string(FileAccess.get_file_as_string(GoldenSaves.DIR + golden))
	out.close()
	_made.append(slot)


func _shoot(tool: Node, path: String, frames: int = 10) -> void:
	await tool.call("wait_frames", frames)
	tool.call("_shot", path)


func _page() -> SavesScreen:
	var pages := (root.get("screen") as Node).find_children("*", "SavesScreen", true, false)
	return pages.back() as SavesScreen


func capture_shots(tool: Node, out: String) -> void:
	(root.get("hud") as ExploreHud).close_narration()
	root.call("open_screen", "menu", 0)
	var menu := root.get("screen") as PauseMenu
	menu.call("_open_saves", SavesScreen.Mode.SAVE)
	await _shoot(tool, out + "_1_save_page.png")
	var page := _page()
	page.call("_confirm", page.slots()[0])
	await _shoot(tool, out + "_2_overwrite.png")
	root.call("close_screen")
	root.call("open_screen", "menu", 0)
	(root.get("screen") as PauseMenu).call("_open_saves", SavesScreen.Mode.LOAD)
	await _shoot(tool, out + "_3_load_page.png")
	root.call("close_screen")
	if SaveSystem.autosave() == OK:
		_made.append(SaveSystem.AUTOSAVE)
	root.call("open_screen", "game_over", 0)
	await _shoot(tool, out + "_4_game_over.png")
	root.call("close_screen")
	var title := (load("res://scenes/main_menu.tscn") as PackedScene).instantiate()
	add_child(title)
	await tool.call("wait_frames", 4)
	title.call("_show_loads")
	await _shoot(tool, out + "_5_title_load.png")
	title.queue_free()
	for slot in _made:
		SaveSystem.delete_slot(slot)
	DirAccess.remove_absolute(SaveSystem.save_dir)
	SaveSystem.save_dir = _real_dir
