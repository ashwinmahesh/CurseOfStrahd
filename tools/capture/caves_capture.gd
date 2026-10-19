extends Node3D
## Cave QA (I2, the vault's Natural Maps Plan): the cave places built as in the game and shot with the screens hidden, so
## the rock is what shows: whole from the play camera's heading, straight down, and close from each heading at the
## places that matter (SPOTS). Not part of the game.
##   make capture SCENE=res://tools/capture/caves_capture.tscn NAME=caves/after FRAMES=10
## Environment: CV_LOCS=a,b (default the four caves), CV_VIEWS=whole,top,spots (default all three), CV_HOUR=12,
## CV_OFF=1 (the cave look off, for before shots and build times), CV_WINDOW=1 (keep the see-through window), CV_LIGHT=1 (a strong lamp from above, so the
## contour and the rock's shape can be read in a map that is meant to be dark), CV_TIME=n (no shots: build each place n times and
## print the times, the first, which warms the caches, apart),
## CV_AT=x,z,dist,steps,pitch;... (extra shots, each at that square: dist in squares, steps = quarter turns, pitch = degrees
## added to the camera's, negative looks down more), CV_FORCE=a,b (places whose catalog `cave` look is switched on for
## this run, e.g. amber_deep before it is approved).
## Shots: <out>_<loc>_whole.png, _top.png, _<spot>_<heading>.png, _at<n>.png.

const PARTY: Array[String] = ["godrick_pendlebrook", "liriel_dawnsong", "thistle", "ratatoille"]
const CAVES: Array[String] = ["werewolf_den_caves", "ghakis_lair", "amber_deep", "drowned_library"]
## Each place's close shots: name -> [x, z, distance].
const SPOTS := {
	"werewolf_den_caves": {"great": [19, 13, 15.0], "mouth": [19, 25, 12.0], "lair": [19, 5, 12.0],
		"shrine": [34, 13, 12.0], "pen": [5, 5, 10.0], "alcove": [5, 13, 10.0]},
	"ghakis_lair": {"hoard": [22, 6, 15.0], "anchor": [22, 17, 13.0], "larder": [35, 18, 13.0],
		"vents": [8, 17, 13.0], "tunnel": [21, 26, 12.0]},
	"amber_deep": {"eye": [17, 6, 14.0], "hall": [16, 16, 15.0], "archive": [6, 22, 10.0], "stair": [26, 23, 10.0]},
	"drowned_library": {"stacks": [12, 3, 14.0], "flood": [16, 9, 14.0], "foot": [8, 13, 12.0]},
}

var view: LocationView = null


func _ready() -> void:
	InputActions.ensure()


func capture_shots(tool: Node, out: String) -> void:
	var ids: Array[String] = CAVES.duplicate()
	if OS.get_environment("CV_LOCS") != "":
		ids.assign(OS.get_environment("CV_LOCS").split(",", false))
	var views := OS.get_environment("CV_VIEWS").split(",", false)
	if views.is_empty():
		views = PackedStringArray(["whole", "top", "spots"])
	var hour := int(OS.get_environment("CV_HOUR")) if OS.get_environment("CV_HOUR") != "" else 12
	if OS.get_environment("CV_OFF") != "":
		for id: String in ids:
			((SetDressing.catalog()["place_looks"] as Dictionary).get(id, {}) as Dictionary).erase("cave")
	if OS.get_environment("CV_FORCE") != "":
		for id: String in OS.get_environment("CV_FORCE").split(",", false):
			var looks := SetDressing.catalog()["place_looks"] as Dictionary
			var look := (looks.get(id, {}) as Dictionary).duplicate()
			look["cave"] = look.get("cave", true)
			looks[id] = look
	if OS.get_environment("CV_TIME") != "":
		# Each place built n times with the cave look off and on, one after the other so the Mac's load bears on both alike.
		for id in ids:
			var looks := SetDressing.catalog()["place_looks"] as Dictionary
			var look := looks.get(id, {}) as Dictionary
			var kind: Variant = look.get("cave", true)
			var times := {"off": [] as Array[float], "on": [] as Array[float]}
			for i in int(OS.get_environment("CV_TIME")):
				for mode: String in ["off", "on"]:
					if mode == "on":
						look["cave"] = kind
					else:
						look.erase("cave")
					looks[id] = look
					var t0 := Time.get_ticks_usec()
					_build(id, hour)
					(times[mode] as Array[float]).append((Time.get_ticks_usec() - t0) / 1000.0)
					view.queue_free()
					view = null
					await tool.call("wait_frames", 3)
			var summary := ""
			for mode: String in ["off", "on"]:
				var all := (times[mode] as Array[float]).slice(1)   # the first warms the caches (and, on, plans)
				all.sort()
				summary += "%s median %.0f (best %.0f, first %.0f)  " % [mode, all[all.size() / 2], all[0], (times[mode] as Array[float])[0]]
			print("time %s: %s" % [id, summary])
		return
	for id in ids:
		var began := Time.get_ticks_usec()
		_build(id, hour)
		print("cave %s: built in %.0f ms" % [id, (Time.get_ticks_usec() - began) / 1000.0])
		var cave := Caves.of(view.board)
		if cave != null:
			print("cave %s: stages %s, pieces %.0f ms" % [id, cave.stages, cave.build_ms])
			print("cave %s: plan %.0f ms, %d rock squares, in over the floor %.2f, out into the rock %.2f" % [id, cave.plan_ms,
				cave.rock_squares().size(), cave.deepest_intrusion(), cave.widest_swell()])
		else:
			print("cave %s: not a cave (the look is off)" % id)
		if OS.get_environment("CV_DUMP") != "" and cave != null:
			for spec: String in OS.get_environment("CV_DUMP").split(";", false):
				var a := spec.split(",")
				print(cave.describe(Vector2i(int(a[0]), int(a[1]))))
		if OS.get_environment("CV_PROBE") != "" and cave != null:
			# CV_PROBE=x0,z0,x1,z1: the contour field along that line, to see how much rock a wall keeps.
			var q := OS.get_environment("CV_PROBE").split(",")
			var line := ""
			for i in 17:
				var t := float(i) / 16.0
				line += "%.2f " % cave.field_at(lerpf(float(q[0]), float(q[2]), t), lerpf(float(q[1]), float(q[3]), t))
			print("probe %s: %s" % [id, line])
		if OS.get_environment("CV_NAMES") != "":
			var counts := {}
			for n in view.board.get_children():
				var key := str(n.name).replace("@", "").rstrip("0123456789")
				counts[key] = int(counts.get(key, 0)) + 1
			print("names %s: %s" % [id, counts])
		await tool.call("wait_frames", 30)
		var rig := view.rig
		var centre := Vector3(view.grid.width / 2.0, 0, view.grid.depth / 2.0)
		if "whole" in views:
			rig.horizon = 0.0
			rig.distance = maxf(view.grid.width, view.grid.depth) * 1.05
			rig.shot_pitch = 0.0
			rig.global_position = centre
			rig.snap_to_target()
			await tool.call("wait_frames", 12)
			tool.call("_shot", "%s_%s_whole.png" % [out, id])
		if "top" in views:
			rig.horizon = 0.0
			rig.distance = maxf(view.grid.width, view.grid.depth) * 0.9
			rig.shot_pitch = -49.0
			rig.global_position = centre
			rig.snap_to_target()
			await tool.call("wait_frames", 12)
			tool.call("_shot", "%s_%s_top.png" % [out, id])
			rig.shot_pitch = 0.0
		if "spots" in views:
			var spots := SPOTS.get(id, {}) as Dictionary
			for spot: String in spots:
				var s := spots[spot] as Array
				for steps: int in [0, 1, 2, 3]:
					rig.horizon = 0.0
					rig.shot_pitch = 0.0
					rig.distance = float(s[2])
					rig.global_position = view.board.cell_center(Vector2i(int(s[0]), int(s[1])))
					rig.snap_to_target()
					await tool.call("wait_frames", 6)
					tool.call("_shot", "%s_%s_%s_%d.png" % [out, id, spot, steps])
					rig.rotate_step(1)
		if OS.get_environment("CV_AT") != "":
			var n := 0
			for spec: String in OS.get_environment("CV_AT").split(";", false):
				var a := spec.split(",")
				rig.horizon = 0.0
				rig.distance = float(a[2]) if a.size() > 2 else 12.0
				rig.shot_pitch = float(a[4]) if a.size() > 4 else 0.0
				for i in (int(a[3]) if a.size() > 3 else 0):
					rig.rotate_step(1)
				rig.global_position = view.board.cell_center(Vector2i(int(a[0]), int(a[1])))
				rig.snap_to_target()
				await tool.call("wait_frames", 12)
				tool.call("_shot", "%s_%s_at%d.png" % [out, id, n])
				n += 1
				rig.shot_pitch = 0.0
				for i in (int(a[3]) if a.size() > 3 else 0):
					rig.rotate_step(-1)
		view.queue_free()
		view = null
		await tool.call("wait_frames", 2)


func _build(loc_id: String, hour: int) -> void:
	GameState.reset()
	for id: String in PARTY:
		var ch := Pregens.build(id, 3)
		ch.finish_long_rest()
		GameState.story.party.append(ch)
	GameState.story.minute_of_day = hour * 60
	# No fight on arrival (the den's guards), so the camera stays where the shot puts it.
	for flag: String in ["den_guards_cleared", "zuleika_vouched"]:
		GameState.story.set_flag(flag, true)
	view = LocationView.create(loc_id, GameState.story, Narrator.new(), Dice.roller, "default")
	add_child(view)
	view.update_daylight()
	view.atmosphere.settle()
	var rig := view.rig
	rig.follow = null
	rig.zoom_max = maxf(rig.zoom_max, 60.0)
	if OS.get_environment("CV_LIGHT") != "":
		var sun := DirectionalLight3D.new()
		sun.light_energy = 2.2
		sun.rotation_degrees = Vector3(-62, 35, 0)
		sun.shadow_enabled = true
		add_child(sun)
	# No window cut round the party in the walls (SeeThrough), which in a QA shot of the whole map would sit in its middle
	# (CV_WINDOW=1 keeps it).
	if OS.get_environment("CV_WINDOW") == "" and view.has_node("SeeThrough"):
		view.get_node("SeeThrough").free()
		SeeThrough.shut()
	# No screens over the rock.
	for layer: Node in get_tree().root.find_children("*", "CanvasLayer", true, false):
		(layer as CanvasLayer).visible = false
