extends Node
## The saves' own page (ui/screens/saves_screen.gd, lane 16) from a late party, with the golden saves as the list:
## the recap on loading (Q3), Save Game, the questions before writing over or deleting a save, Load a Save with its Backups and
## Chapters tabs, the game-over screen and the title's Load. Saves of the capture's own only, so the owner's never show
## or change.
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
	# The recap a game saved a while ago opens with (Q3): this one was loaded from a golden save hours old. The
	# auto-player's saves hold no quests or companions' memories, so it is given two of each to show.
	var st := GameState.story
	for q: String in ["find_the_sunsword", "the_amber_temple"]:
		st.set_quest_stage(q, str(((Compendium.shared().get_entry("quests", q)["stages"] as Array)[0] as Dictionary)["id"]))
		st.advance_minutes(10)
	Approval.change(st, "thistle", 2, "You talked a grieving ghost into resting")
	Recap.always = true
	Recap.show_on(root)
	Recap.always = false
	await _shoot(tool, out + "_0_recap.png")
	(root.get("hud") as ExploreHud).close_narration()
	# Saves with pictures (Q9): a few places, each saved as a player would, one with a note; how long the picture takes.
	for at: Array in [["village_of_barovia", "The square at dusk"], ["vallaki", ""], ["krezk", "Before the Abbey"]]:
		root.call("enter_location", str(at[0]), "default")
		await tool.call("wait_frames", 40)
		(root.get("hud") as ExploreHud).close_narration()
		await tool.call("wait_frames", 2)
		var t0 := Time.get_ticks_usec()
		SaveSystem.call("_grab")
		print("saves capture: a picture took %.1f ms at %s" % [(Time.get_ticks_usec() - t0) / 1000.0, get_viewport().get_texture().get_size()])
		var slot := "cap_" + str(at[0])
		SaveSystem.save(slot, str(at[1]) if str(at[1]) != "" else null)
		_made.append(slot)
	root.call("open_screen", "menu", 0)
	var menu := root.get("screen") as PauseMenu
	menu.call("_open_saves", SavesScreen.Mode.SAVE)
	var page := _page()
	(page.find_children("Note", "LineEdit", true, false)[0] as LineEdit).text = "Before the castle gates"
	await _shoot(tool, out + "_1_save_page.png")
	page.call("_confirm", page.slots()[0])
	await _shoot(tool, out + "_2_overwrite.png")
	page.call("_confirm_delete", page.slots()[1])
	await _shoot(tool, out + "_2b_delete.png")
	root.call("close_screen")
	SaveSystem.back_up_for_build("capture_build")
	root.call("open_screen", "menu", 0)
	(root.get("screen") as PauseMenu).call("_open_saves", SavesScreen.Mode.LOAD)
	await _shoot(tool, out + "_3_load_page.png")
	(_page().find_child("Backups", true, false) as Button).pressed.emit()
	await _shoot(tool, out + "_3b_backups.png")
	(_page().find_child("Chapters", true, false) as Button).pressed.emit()
	await _shoot(tool, out + "_3c_chapters.png")
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
	for b in SaveSystem.backups():
		SaveSystem.call("_remove_dir", SaveSystem.backups_dir().path_join(b))
	SaveSystem.call("_remove_dir", SaveSystem.backups_dir())
	DirAccess.remove_absolute(SaveSystem.save_dir)
	SaveSystem.save_dir = _real_dir
