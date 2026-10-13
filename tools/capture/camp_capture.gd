extends Node
## The camp (F16, LocationCamp) for captures: made in each place named (the wild, a town, indoors), in the evening
## (Thistle wants a word, so her mark shows), then the morning after the night by the fire, then broken.
## make capture SCENE=res://tools/capture/camp_capture.tscn NAME=camp FRAMES=40 ARGS="--places=road_forest,lake_zarovich"

var root: Node


func _ready() -> void:
	GameState.reset()
	GameSettings.set_value("turn_based", false, false)
	for id: String in ["godrick_pendlebrook", "liriel_dawnsong", "thistle", "ratatoille"]:
		var ch := Pregens.build(id, 4)
		ch.finish_long_rest()
		GameState.story.party.append(ch)
	for id: String in ["wren_featherfoot", "kip_smudgewick"]:
		var ch2 := Pregens.build(id, 4)
		ch2.finish_long_rest()
		GameState.story.bench.append(ch2)
	GameState.story.set_flag("strahd_knelt", "thistle")
	GameState.story.minute_of_day = 20 * 60
	GameState.story.location = _places()[0]
	root = (load("res://scenes/game.tscn") as PackedScene).instantiate()
	add_child(root)


func _places() -> Array[String]:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--places="):
			var out: Array[String] = []
			out.assign(a.substr(9).split(","))
			return out
	return ["road_forest"]


func _shoot(tool: Node, path: String) -> void:
	await tool.call("wait_frames", 12)
	tool.call("_shot", path)


func capture_shots(tool: Node, out: String) -> void:
	var first := true
	for place in _places():
		var st := GameState.story
		st.minute_of_day = 20 * 60
		(st.flags as Dictionary).erase(RestRules.DONE_AT)
		if not first:
			root.call("enter_location", place, "default")
			await tool.call("wait_frames", 90)
		first = false
		var hud := root.get("hud") as ExploreHud
		var view := root.get("view") as LocationView
		hud.close_narration()
		var camp := LocationCamp.pitch(view, root, "safe")
		if camp == null:
			print("camp_capture: no room for a camp at %s" % place)
			continue
		await tool.call("wait_frames", 40)
		hud.close_narration()
		await _shoot(tool, "%s_%s_1_evening.png" % [out, place])
		if place == _places()[0] and camp.people.has("thistle"):
			# Thistle wants a word: the hover hint, her menu, and the talk.
			var cell := ((camp.people["thistle"] as Dictionary)["token"] as CombatToken).combatant.cell
			var at := view.rig.camera.unproject_position(view.board.cell_center(cell) + Vector3(0, 0.6, 0))
			hud.hint(str(view.thing_at(cell).get("label", "")), at + Vector2(10, -40))
			await _shoot(tool, "%s_%s_1b_hint.png" % [out, place])
			hud.hint("", Vector2.ZERO)
			root.call("open_world_menu", cell, at)
			await _shoot(tool, "%s_%s_1c_menu.png" % [out, place])
			(root.get("menu") as ContextMenu).hide()
			view.click(cell)
			for i in 400:
				if root.get("dialogue") != null:
					break
				await tool.call("wait_frames", 1)
			await tool.call("wait_frames", 40)
			var d := root.get("dialogue") as DialogueUI
			if d != null:
				d.call("_advance")
				await tool.call("wait_frames", 20)
			await _shoot(tool, "%s_%s_1d_talk.png" % [out, place])
			if d != null:
				d.queue_free()
				root.set("dialogue", null)
				hud.visible = true
				ModeController.force(ModeController.Mode.EXPLORATION)
			await tool.call("wait_frames", 20)
		view.rig.distance = 20.0
		await _shoot(tool, "%s_%s_2_evening_wide.png" % [out, place])
		view.rig.distance = 13.0
		camp.sleep()
		await tool.call("wait_frames", 150)
		hud.close_narration()
		await _shoot(tool, "%s_%s_3_morning.png" % [out, place])
		camp.strike()
		await tool.call("wait_frames", 30)
		hud.close_narration()
		await _shoot(tool, "%s_%s_4_struck.png" % [out, place])
