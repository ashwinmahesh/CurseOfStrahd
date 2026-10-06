extends Node3D
## Art QA tour of one location's set dressing (docs/art/set_dressing.md): the location built as in the game, then
## an overview and close shots around its doors, props and containers. Not part of the game.
##   make capture SCENE=res://tools/art/preview/location_tour.tscn LOCATION=death_house_ground NAME=tour FRAMES=20
## Godot args after --: --location=<id> [--hour=12] [--shots=8] [--yaw=<camera steps>] [--lit] (brighter ambient, to
## check placement in dark interiors) [--at=x,z;x,z] (close shots of these squares) [--spots=x,z;x,z] (the same)
## [--party=x,z] (the party, with its lantern, stands there instead of at the spawn) [--dist=11] (how far the
## close shots are)

var view: LocationView
var _spots: Array[Vector3] = []


func _ready() -> void:
	var loc_id := "into_the_mists_road"
	var hour := 12
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--location="):
			loc_id = a.get_slice("=", 1)
		elif a.begins_with("--hour="):
			hour = int(a.get_slice("=", 1))
	InputActions.ensure()
	GameState.reset()
	for id: String in ["ilse_varga", "tamsin_tealeaf", "hedda_ironvow", "silvain_aster"]:
		var ch := Pregens.build(id, 1)
		ch.finish_long_rest()
		GameState.story.party.append(ch)
	GameState.story.minute_of_day = hour * 60
	var spawn := "default"
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--party="):
			var at := Vector2i(int(a.get_slice("=", 1).get_slice(",", 0)), int(a.get_slice("=", 1).get_slice(",", 1)))
			GameState.story.location = loc_id
			GameState.story.positions.clear()
			for i in GameState.story.party.size():
				GameState.story.positions.append(at + [Vector2i.ZERO, Vector2i(1, 0), Vector2i(0, 1), Vector2i(1, 1)][i % 4])
			spawn = ""
	view = LocationView.create(loc_id, GameState.story, Narrator.new(), Dice.roller, spawn)
	add_child(view)
	# --spots=x,z;x,z: close shots of these squares instead.
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--spots="):
			for pair in a.get_slice("=", 1).split(";", false):
				var xz := pair.split(",")
				_spots.append(view.board.cell_center(Vector2i(int(xz[0]), int(xz[1]))))
	if not _spots.is_empty():
		return
	# Spots worth a close look: clusters of doors, props and containers (one shot per cluster).
	for key: String in ["doors", "props", "containers"]:
		for t: Variant in view.loc.get(key, []):
			var c := LocationView._cell((t as Dictionary)["cell"])
			var p := view.board.cell_center(c)
			var near := false
			for s in _spots:
				if s.distance_to(p) < 5.0:
					near = true
			if not near:
				_spots.append(p)
	# --at=x,z;x,z: close shots of these squares instead.
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--at="):
			_spots.clear()
			for xz: String in a.get_slice("=", 1).split(";"):
				_spots.append(view.board.cell_center(Vector2i(int(xz.get_slice(",", 0)), int(xz.get_slice(",", 1)))))


func capture_shots(tool: Node, out: String) -> void:
	var shots := 8
	var yaw := 0
	var dist := 11.0
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--shots="):
			shots = int(a.get_slice("=", 1))
		elif a.begins_with("--yaw="):
			yaw = int(a.get_slice("=", 1))
		elif a.begins_with("--dist="):
			dist = float(a.get_slice("=", 1))
	var rig := view.rig
	rig.follow = null
	var lamp: OmniLight3D = null
	if "--lit" in OS.get_cmdline_user_args():
		var env := view.get("_env") as Environment
		env.ambient_light_energy = 2.2
		lamp = OmniLight3D.new()
		lamp.light_color = Look.color("bone")
		lamp.omni_range = 14.0
		lamp.light_energy = 2.0
		rig.add_child(lamp)
		lamp.position = Vector3(0, 4, 0)
	rig.rotate_step(yaw)
	rig.zoom_max = 40.0
	rig.distance = maxf(view.grid.width, view.grid.depth) * 1.05
	rig.global_position = Vector3(view.grid.width / 2.0, 0, view.grid.depth / 2.0)
	rig.snap_to_target()
	await tool.call("wait_frames", 20)
	tool.call("_shot", out + "_overview.png")
	rig.distance = dist
	for i in mini(shots, _spots.size()):
		rig.global_position = _spots[i]
		rig.snap_to_target()
		await tool.call("wait_frames", 12)
		tool.call("_shot", out + "_%d.png" % (i + 1))
