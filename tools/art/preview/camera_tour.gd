extends Node3D
## Art QA for the play camera's free turn and tilt: one spot in one location, shot at the default view, turned to a
## heading that is not a quarter turn, and tilted to the lowest and highest bound of the campaign's range. Not part of
## the game.
##   make capture SCENE=res://tools/art/preview/camera_tour.tscn LOCATION=village_of_barovia NAME=camera FRAMES=20
## Godot args after --: --location=<id> [--hour=12] [--turn=37] (degrees of free turn for the turned shots)

var view: LocationView


func _ready() -> void:
	var loc_id := "village_of_barovia"
	var hour := 12
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--location="):
			loc_id = a.get_slice("=", 1)
		elif a.begins_with("--hour="):
			hour = int(a.get_slice("=", 1))
	InputActions.ensure()
	GameState.reset()
	for id: String in ["godrick_pendlebrook", "liriel_dawnsong", "thistle", "ratatoille"]:
		var ch := Pregens.build(id, 1)
		ch.finish_long_rest()
		GameState.story.party.append(ch)
	GameState.story.minute_of_day = hour * 60
	view = LocationView.create(loc_id, GameState.story, Narrator.new(), Dice.roller, "default")
	add_child(view)


func capture_shots(tool: Node, out: String) -> void:
	var turn := 37.0
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--turn="):
			turn = float(a.get_slice("=", 1))
	var rig := view.rig
	print("camera: free_turn=%s tilt=%s pitch=%s" % [rig.free_turn, rig.tilt_range, rig.pitch_deg])
	await tool.call("wait_frames", 20)
	await _shot(tool, out + "_1_default.png", rig)
	rig.turn_by(turn)
	await _shot(tool, out + "_2_turned.png", rig)
	rig.reset_view()
	rig.tilt_by(-1000.0)
	await _shot(tool, out + "_3_tilt_min.png", rig)
	rig.tilt_by(1000.0)
	await _shot(tool, out + "_4_tilt_max.png", rig)
	rig.turn_by(turn)
	rig.tilt_by(-1000.0)
	await _shot(tool, out + "_5_turned_tilt_min.png", rig)
	rig.reset_view()
	await _shot(tool, out + "_6_reset.png", rig)


func _shot(tool: Node, path: String, rig: CameraRig) -> void:
	rig.snap_to_target()
	await tool.call("wait_frames", 12)
	print("shot %s: heading %.1f pitch %.1f" % [path.get_file(), rad_to_deg(rig.rotation.y), rig.camera.rotation_degrees.x])
	tool.call("_shot", path)
