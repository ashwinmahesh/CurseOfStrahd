extends Node3D
## Close-ups of a place's ground, for the natural maps plan's before and afters (N2 and the lanes that follow it): each place
## built as in the game, the camera put over a square at a distance and heading you give, shot. Not part of the game.
##   make capture SCENE=res://tools/capture/natural_ground.tscn NAME=natural/ground FRAMES=10
## Environment: NG_SHOTS="place:x,z[:distance[:heading]];place:x,z" (distance defaults to 9, heading to 0: the play camera's
## own; -1, 1 and 2 turn it a quarter each), NG_WEATHER=overcast (the world's weather for the whole run), NG_HOUR=12,
## NG_TAG=name (put in the file's name).
## Shots: <out>_<tag>_<place>_<x>_<z>.png

const PARTY: Array[String] = ["godrick_pendlebrook", "liriel_dawnsong", "thistle", "ratatoille"]

var view: LocationView = null


func capture_shots(tool: Node, out: String) -> void:
	InputActions.ensure()
	var weather := OS.get_environment("NG_WEATHER")
	if weather != "":
		var d := Weather.data().duplicate(true)
		var climates := {}
		for c: String in d.get("climates", {}) as Dictionary:
			climates[c] = {weather: 1}
		d["climates"] = climates
		Weather.use(d)
	var hour := int(OS.get_environment("NG_HOUR")) if OS.get_environment("NG_HOUR") != "" else 12
	var tag := OS.get_environment("NG_TAG")
	var built := ""
	for spec in OS.get_environment("NG_SHOTS").split(";", false):
		var parts := spec.split(":")
		var id := parts[0]
		var at := parts[1].split(",")
		var dist := float(parts[2]) if parts.size() > 2 else 9.0
		var heading := int(parts[3]) if parts.size() > 3 else 0
		if built != id:
			if view != null:
				view.queue_free()
				await tool.call("wait_frames", 2)
			_build(id, hour)
			built = id
			await tool.call("wait_frames", 30)
		var rig := view.rig
		rig.follow = null
		rig.horizon = 0.0
		rig.distance = dist
		rig.zoom_min = minf(rig.zoom_min, dist)
		rig.global_position = view.board.cell_center(Vector2i(int(at[0]), int(at[1])))
		rig.snap_to_target()
		for i in absi(heading):
			rig.rotate_step(1 if heading > 0 else -1)
		await tool.call("wait_frames", 20)
		tool.call("_shot", "%s%s_%s_%s_%s.png" % [out, "_" + tag if tag != "" else "", id, at[0], at[1]])
	if view != null:
		view.queue_free()


func _build(loc_id: String, hour: int) -> void:
	if view != null:
		view = null
	GameState.reset()
	for id: String in PARTY:
		var ch := Pregens.build(id, 3)
		ch.finish_long_rest()
		GameState.story.party.append(ch)
	GameState.story.minute_of_day = hour * 60
	view = LocationView.create(loc_id, GameState.story, Narrator.new(), Dice.roller, "default")
	add_child(view)
	view.input_locked = true
	view.update_daylight()
	view.atmosphere.settle()
