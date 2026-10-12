extends Node
## The wiki's screenshots in one off-screen run (make wiki-shots): tools/wiki/build_wiki.py --shot-list writes the list,
## and this plays the story game (scenes/game.tscn) through it. For each place: the party arriving, then the whole place
## from above; for each quest: the conversation that starts it, at its first choice; and the travel map. A shot whose
## file is already there is skipped, so a run that stops can be started again and carry on.
##   make capture SCENE=res://tools/wiki/wiki_shots.tscn NAME=wiki ARGS="--list=/abs/list.json --dir=/abs/folder"
## Each entry: {name, kind: explore|overview|dialogue|map, location, spawn, hour, flags: {id: value}, dialogue: "file:node",
## npc}. Saves and settings are the capture tool's own (tools/capture/capture.gd), never the owner's.

var game: Node = null
var _here := ""      ## the place entered last and the time it was entered at, "" once a shot has moved the camera


func capture_shots(tool: Node, _out: String) -> void:
	var list_path := ""
	var dir := ""
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--list="):
			list_path = a.get_slice("=", 1)
		elif a.begins_with("--dir="):
			dir = a.get_slice("=", 1)
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(list_path))
	if not parsed is Array or dir == "":
		printerr("wiki_shots: needs --list=<json> and --dir=<folder>")
		return
	DirAccess.make_dir_recursive_absolute(dir)
	game = (load("res://scenes/game.tscn") as PackedScene).instantiate()
	add_child(game)
	await tool.call("wait_frames", 90)
	var made := 0
	for v: Variant in parsed as Array:
		var shot := v as Dictionary
		var path := dir.path_join(str(shot.get("name", "shot")) + ".png")
		if FileAccess.file_exists(path):
			continue
		var kind := str(shot.get("kind", "explore"))
		if kind == "map":
			# Every place known, from a place on the map, so the whole valley shows.
			for p: Variant in Travel.map_data().get("places", []) as Array:
				GameState.story.visited[str((p as Dictionary)["location"]).get_slice(":", 0)] = true
			await _enter(tool, shot)
			game.call("open_travel", true)
			await tool.call("wait_frames", 30)
			tool.call("_shot", path)
			game.call("close_screen")
			made += 1
			continue
		await _enter(tool, shot)
		var view := game.get("view") as LocationView
		if view == null:
			printerr("wiki_shots: no view for ", shot.get("location", ""))
			continue
		var hud := game.get("hud") as ExploreHud
		hud.close_narration()   # the party's banter on arriving
		await tool.call("wait_frames", 10)
		if kind == "overview":
			hud.visible = false
			var rig := view.rig
			rig.follow = null
			rig.zoom_max = 60.0
			rig.distance = maxf(view.grid.width, view.grid.depth) * 1.05
			rig.global_position = Vector3(view.grid.width / 2.0, 0, view.grid.depth / 2.0)
			rig.snap_to_target()
			await tool.call("wait_frames", 30)
			tool.call("_shot", path)
			hud.visible = true
			_here = ""
		elif kind == "dialogue":
			var dlg := await _talk(tool, str(shot.get("dialogue", "")), str(shot.get("npc", "")))
			if dlg == null and str(shot.get("fallback", "")) != "":
				# The quest's own node ran out before a choice: the person's usual conversation instead.
				dlg = await _talk(tool, str(shot["fallback"]), str(shot.get("npc", "")))
			if dlg != null:
				tool.call("_shot", path)
				dlg.queue_free()
				game.set("dialogue", null)
				(game.get("hud") as ExploreHud).visible = true
				ModeController.force(ModeController.Mode.EXPLORATION)
			else:
				print("wiki_shots: ", shot.get("name", ""), " ended before a choice; no shot")
			_here = ""
		else:
			tool.call("_shot", path)
		made += 1
	print("wiki_shots: %d shots made" % made)


## A conversation from `ref`, played to its first choice; the dialogue screen, or null if it ended first.
func _talk(tool: Node, ref: String, npc: String) -> DialogueUI:
	game.call("start_dialogue", ref, npc)
	for i in 40:
		var d := game.get("dialogue") as DialogueUI
		if d == null or not d.options_shown.is_empty():
			break
		d.call("_advance")
		await tool.call("wait_frames", 3)
	await tool.call("wait_frames", 40)
	return game.get("dialogue") as DialogueUI


## Into the shot's place at its hour with its flags set, unless the party is already there as it should be.
func _enter(tool: Node, shot: Dictionary) -> void:
	var st := GameState.story
	var flags := shot.get("flags", {}) as Dictionary
	for k: String in flags:
		st.set_flag(k, flags[k])
	var hour := int(shot.get("hour", 11))
	var key := "%s@%d" % [str(shot.get("location", "")), hour]
	if key == _here and flags.is_empty():
		return
	st.minute_of_day = hour * 60
	var loc := Compendium.shared().get_entry("locations", str(shot.get("location", "")))
	game.set("_card_region", str(loc.get("region", "")))   # no loading card over the shot
	game.call("enter_location", str(shot.get("location", "")), str(shot.get("spawn", "default")))
	await tool.call("wait_frames", int(shot.get("settle", 150)))
	_here = key
