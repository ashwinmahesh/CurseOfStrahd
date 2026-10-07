extends Node3D
## Art QA for a place's atmosphere (docs/art/atmosphere.md): the location built as in the game, seen from the game's
## camera over one square at each time of day, with the GPU's frame time. Not part of the game.
##   make capture SCENE=res://tools/art/preview/atmosphere_preview.tscn LOCATION=village_of_barovia NAME=atmo FRAMES=20
## Godot args after --: --location=<id> [--at=x,z] (default: the spawn) [--times=day,dusk,night,dawn]
## [--distance=13] [--yaw=<camera steps>] [--overview] [--set=<post uniform>:<value>,...] (try a value)
## [--no-ao] [--uncapped] (no vsync) [--compare] (also time and shoot it with the atmosphere's extras off)

var view: LocationView
var _at := Vector2i(-1, -1)


func _ready() -> void:
	var loc_id := "into_the_mists_road"
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--location="):
			loc_id = a.get_slice("=", 1)
		elif a.begins_with("--at="):
			var xz := a.get_slice("=", 1)
			_at = Vector2i(int(xz.get_slice(",", 0)), int(xz.get_slice(",", 1)))
	InputActions.ensure()
	GameState.reset()
	for id: String in ["godrick_pendlebrook", "liriel_dawnsong", "thistle", "ratatoille"]:
		var ch := Pregens.build(id, 1)
		ch.finish_long_rest()
		GameState.story.party.append(ch)
	GameState.story.minute_of_day = 12 * 60
	view = LocationView.create(loc_id, GameState.story, Narrator.new(), Dice.roller, "default")
	add_child(view)
	if "--uncapped" in OS.get_cmdline_user_args():
		# The frame time then says how heavy the place is (with the display awake: caffeinate -du make capture ...).
		DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
		Engine.max_fps = 0


func capture_shots(tool: Node, out: String) -> void:
	var times := ["day", "dusk", "night", "dawn"]
	var distance := 13.0
	var yaw := 0
	var overview := false
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--times="):
			times = Array(a.get_slice("=", 1).split(","))
		elif a.begins_with("--distance="):
			distance = float(a.get_slice("=", 1))
		elif a.begins_with("--yaw="):
			yaw = int(a.get_slice("=", 1))
		elif a == "--overview":
			overview = true
	var rig := view.rig
	rig.follow = null
	rig.rotate_step(yaw)
	rig.zoom_max = 60.0
	if overview:
		rig.distance = maxf(view.grid.width, view.grid.depth) * 1.05
		rig.global_position = Vector3(view.grid.width / 2.0, 0, view.grid.depth / 2.0)
	else:
		rig.distance = distance
		if _at.x >= 0:
			rig.global_position = view.board.cell_center(_at)
		elif not view.members.is_empty():
			rig.global_position = (view.tokens[view.members[0].id] as Node3D).global_position
	rig.snap_to_target()
	var hours := {"day": 12, "dusk": 18, "night": 23, "dawn": 6}
	for t: String in times:
		GameState.story.minute_of_day = int(hours.get(t, 12)) * 60
		view.update_daylight()
		view.atmosphere.settle()
		for a in OS.get_cmdline_user_args():
			if a == "--no-ao":
				view.atmosphere.env.ssao_enabled = false
			if a.begins_with("--set="):
				for kv: String in a.get_slice("=", 1).split(","):
					view.atmosphere.debug_set(kv.get_slice(":", 0), float(kv.get_slice(":", 1)))
		await tool.call("wait_frames", 40)
		var t0 := Time.get_ticks_usec()
		await tool.call("wait_frames", 120)
		var ms := (Time.get_ticks_usec() - t0) / 120000.0
		print("atmosphere %s %s: %.2f ms per frame (%d fps)" % [view.loc_id, t, ms, int(1000.0 / ms)])
		tool.call("_shot", out + "_%s.png" % t)
		if "--compare" in OS.get_cmdline_user_args():
			view.atmosphere.debug_bare(true)
			await tool.call("wait_frames", 20)
			t0 = Time.get_ticks_usec()
			await tool.call("wait_frames", 120)
			var bare := (Time.get_ticks_usec() - t0) / 120000.0
			print("  without the atmosphere: %.2f ms per frame (%d fps)" % [bare, int(1000.0 / bare)])
			tool.call("_shot", out + "_%s_bare.png" % t)
			view.atmosphere.debug_bare(false)
