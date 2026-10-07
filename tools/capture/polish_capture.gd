extends Node
## The polish pass's own shots (docs/plans/ui_polish.md), from a level 3 party: names over everything usable with Alt
## held in the village and the Death House, the "Autosaved" note, and the game-over screen with its way back to the
## last autosave. make capture SCENE=res://tools/capture/polish_capture.tscn NAME=polish FRAMES=30 [POLISH_ONLY=alt,over]

var root: Node
var _only: Array[String] = []


## POLISH_LOOK=classic|modern picks the world's finish for the run (not saved), for before-and-after shots.
var _look := ""


func _ready() -> void:
	for s in OS.get_environment("POLISH_ONLY").split(",", false):
		_only.append(s.strip_edges())
	_look = OS.get_environment("POLISH_LOOK")
	if _look != "":
		Look.set_style(_look, false)
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
	if _wants("perf"):
		# How long the GPU takes per frame in the village and the cellar, for the finish this run uses.
		var vp := get_viewport().get_viewport_rid()
		RenderingServer.viewport_set_measure_render_time(vp, true)
		for where: String in ["village_of_barovia", "death_house_dungeon_1", "tser_pool"]:
			root.call("enter_location", where, "default")
			await tool.call("wait_frames", 60)
			var gpu := 0.0
			var cpu := 0.0
			var t0 := Time.get_ticks_usec()
			for i in 120:
				await tool.call("wait_frames", 1)
				gpu += RenderingServer.viewport_get_measured_render_time_gpu(vp)
				cpu += RenderingServer.viewport_get_measured_render_time_cpu(vp)
			var wall := float(Time.get_ticks_usec() - t0) / 1000.0 / 120.0
			print("perf %s %s: frame %.2f ms (60 fps cap), gpu %.2f ms, cpu %.2f ms" % [_look, where, wall, gpu / 120.0, cpu / 120.0])
		return
	if _wants("look"):
		# The same places in either finish: the village at dusk, Death House's hall, its cellar, the misty road and a
		# fight in the cellar.
		for where: String in ["village_of_barovia", "death_house_ground", "death_house_dungeon_1", "into_the_mists_road", "tser_pool"]:
			root.call("enter_location", where, "default")
			await tool.call("wait_frames", 40)
			hud.close_narration()
			await _shoot(tool, "%s_look_%s_%s.png" % [out, _look, where], 20)
		root.call("enter_location", "death_house_dungeon_1", "default")
		await tool.call("wait_frames", 20)
		(root.get("view") as LocationView).start_encounter("passage_ghouls")
		await _shoot(tool, "%s_look_%s_fight.png" % [out, _look], 200)
		return
	if _wants("hud"):
		# The command bar's keys, Sneak lit, the objective under the time, and two toasts in a row.
		GameState.story.set_quest_stage("death_house", "plea")
		root.call("_command", "sneak")
		hud.toast("Sneaking")
		hud.toast("Thistle found 3 gp")
		await _shoot(tool, out + "_hud.png")
		await tool.call("wait_frames", 140)
		await _shoot(tool, out + "_hud_second_toast.png", 2)
		root.call("_command", "sneak")
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
	if _wants("settings"):
		root.call("open_screen", "menu", 0)
		await _shoot(tool, out + "_menu.png")
		(root.get("screen") as PauseMenu).call("_show_settings")
		await _shoot(tool, out + "_settings.png")
		root.call("close_screen")
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
