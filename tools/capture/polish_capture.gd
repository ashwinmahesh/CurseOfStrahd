extends Node
## The polish pass's own shots (docs/plans/ui_polish.md), from a level 3 party: names over everything usable with Alt
## held in the village and the Death House, the "Autosaved" note, and the game-over screen with its way back to the
## last autosave. make capture SCENE=res://tools/capture/polish_capture.tscn NAME=polish FRAMES=30 [POLISH_ONLY=alt,over]

var root: Node
var _only: Array[String] = []


func _ready() -> void:
	for s in OS.get_environment("POLISH_ONLY").split(",", false):
		_only.append(s.strip_edges())
	GameState.reset()
	for id: String in ["godrick_pendlebrook", "liriel_dawnsong", "thistle", "ratatoille"]:
		var ch := Pregens.build(id, 3)
		ch.finish_long_rest()
		GameState.story.party.append(ch)
	GameState.story.location = "village_of_barovia"
	root = (load("res://scenes/game.tscn") as PackedScene).instantiate()
	add_child(root)


func _wants(what: String) -> bool:
	return _only.is_empty() or what in _only


func _shoot(tool: Node, path: String, frames: int = 10) -> void:
	await tool.call("wait_frames", frames)
	tool.call("_shot", path)


func capture_shots(tool: Node, out: String) -> void:
	var hud := root.get("hud") as ExploreHud
	hud.close_narration()
	if _wants("alt"):
		hud.thing_labels.pinned = true
		await _shoot(tool, out + "_alt_village.png")
		for where: String in ["death_house_ground", "death_house_dungeon_1"]:
			root.call("enter_location", where, "default")
			await tool.call("wait_frames", 20)
			hud.close_narration()
			await _shoot(tool, out + "_alt_%s.png" % where)
		hud.thing_labels.pinned = false
	if _wants("saved"):
		hud.saved_note()
		await _shoot(tool, out + "_autosaved.png", 4)
	if _wants("over"):
		# Saves of the capture's own, so the owner's never show (or change).
		var real := SaveSystem.save_dir
		SaveSystem.save_dir = "user://capture_saves/%d/" % OS.get_process_id()
		SaveSystem.save("capture_game")
		SaveSystem.autosave()
		root.call("open_screen", "game_over", 0)
		await _shoot(tool, out + "_game_over.png")
		root.call("close_screen")
		for slot: String in ["capture_game", SaveSystem.AUTOSAVE]:
			SaveSystem.delete_slot(slot)
		DirAccess.remove_absolute(SaveSystem.save_dir)
		SaveSystem.save_dir = real
