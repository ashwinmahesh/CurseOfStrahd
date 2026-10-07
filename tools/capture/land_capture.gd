extends Node
## The land lane's before-and-after shots (Improvement Ideas W9, W11, W13): outdoor places from the game's camera with
## the party standing in them, so the trees and plants, the shape of the ground and the vistas past the map's edge can
## be judged side by side, each with its frame time. Not part of the game.
##   make capture SCENE=res://tools/capture/land_capture.tscn NAME=land/before FRAMES=10
## Environment: LAND_SHOTS=road_day,woods (default: every shot), LAND_STYLE=classic|modern (this run only),
## LAND_ZOOM=22 (every shot from this far out), LAND_TIME=1 (also time each shot uncapped), LAND_RAW=1 (without the
## screen pass: no outlines, mist, land fade or grade, to see the plants' own colours), LAND_BENCH=1 (time the
## place with each group of plants hidden in turn, round after round, instead of shooting it), LAND_NO_FLORA=1 (the
## Modern look without its trees and plants: the old trees, for before-and-after pairs), LAND_NO_RELIEF=1 (without
## the shaped ground), LAND_CLAY=1 (the shaped ground in plain clay), LAND_NO_DOF=1 (no depth of field, to judge the
## vistas without the far blur), LAND_GIF=n (n frames a
## tenth of a second apart, numbered, to show the wind).
## The road and village shots stand the party where the light lane's look_capture does, so frames compare across lanes.

## Each shot: the place, the hour, where the party stands (empty: the place's own spawn), and optionally the camera's
## distance (7 to 30 in play), its quarter turns, how far it tilts toward the horizon past its farthest zoom (`tilt`, 0
## to 1, CameraRig.horizon) and a point to look at instead of the party (`look`, x and z).
const SHOTS := {
	"road_day": {"loc": "into_the_mists_road", "hour": 12, "cells": [[12, 15], [13, 15], [12, 16], [13, 14]]},
	"road_dusk": {"loc": "into_the_mists_road", "hour": 18, "cells": [[12, 15], [13, 15], [12, 16], [13, 14]]},
	"road_far": {"loc": "into_the_mists_road", "hour": 12, "cells": [[12, 15], [13, 15], [12, 16], [13, 14]],
		"zoom": 22.0},
	"road_exit": {"loc": "into_the_mists_road", "hour": 12, "cells": [[2, 15], [3, 15], [2, 16], [3, 14]], "zoom": 16.0,
		"turns": 1},
	"crossroads_exit": {"loc": "svalich_crossroads", "hour": 12, "cells": [[3, 12], [4, 12], [3, 13], [4, 11]],
		"zoom": 16.0, "turns": 1},
	"road_overview": {"loc": "into_the_mists_road", "hour": 12, "cells": [[2, 15], [3, 15], [2, 16], [3, 14]],
		"zoom": 26.0},
	"road_ruts": {"loc": "into_the_mists_road", "hour": 12, "cells": [[2, 15], [3, 15], [2, 16], [3, 14]],
		"zoom": 8.0, "look": [-4.0, 15.5]},
	"crossroads_dusk": {"loc": "svalich_crossroads", "hour": 18, "zoom": 11.0},
	"village_tilt": {"loc": "village_of_barovia", "hour": 12, "zoom": 30.0, "tilt": 1.0, "face": "castle"},
	"village_tilt_dusk": {"loc": "village_of_barovia", "hour": 18, "zoom": 30.0, "tilt": 1.0, "face": "castle"},
	"road_tilt": {"loc": "into_the_mists_road", "hour": 12, "cells": [[12, 15], [13, 15], [12, 16], [13, 14]],
		"zoom": 30.0, "tilt": 1.0, "face": "castle"},
	"crossroads_tilt": {"loc": "svalich_crossroads", "hour": 16, "zoom": 30.0, "tilt": 1.0},
	"vallaki_tilt": {"loc": "vallaki", "hour": 12, "zoom": 30.0, "tilt": 1.0},
	"krezk_tilt": {"loc": "krezk", "hour": 12, "zoom": 30.0, "tilt": 1.0},
	"village_untilted": {"loc": "village_of_barovia", "hour": 12, "zoom": 30.0, "tilt": 0.0, "face": "castle"},
	"road_untilted": {"loc": "into_the_mists_road", "hour": 12, "cells": [[12, 15], [13, 15], [12, 16], [13, 14]],
		"zoom": 30.0, "tilt": 0.0, "face": "castle"},
	"lake_tilt": {"loc": "lake_zarovich", "hour": 12, "zoom": 30.0, "tilt": 1.0},
	"tilt_half": {"loc": "village_of_barovia", "hour": 12, "zoom": 30.0, "tilt": 0.5, "turns": 1},
	"road_fade": {"loc": "into_the_mists_road", "hour": 12, "cells": [[15, 17], [14, 17], [15, 16], [14, 16]]},
	"village_dusk": {"loc": "village_of_barovia", "hour": 18},
	"village_far": {"loc": "village_of_barovia", "hour": 12, "zoom": 22.0},
	"woods": {"loc": "road_forest", "hour": 12},
	"crossroads": {"loc": "svalich_crossroads", "hour": 16},
	"tser_pool": {"loc": "tser_pool", "hour": 18},
	"krezk": {"loc": "krezk", "hour": 12},
	"berez": {"loc": "berez", "hour": 16},
	"lake": {"loc": "lake_zarovich", "hour": 12, "zoom": 18.0},
	"vallaki": {"loc": "vallaki", "hour": 12},
	"gates": {"loc": "castle_ravenloft_gates", "hour": 18, "zoom": 18.0},
}
const PARTY: Array[String] = ["godrick_pendlebrook", "liriel_dawnsong", "thistle", "ratatoille"]

var view: LocationView = null


func _ready() -> void:
	InputActions.ensure()
	var style := OS.get_environment("LAND_STYLE")
	if style != "":
		Look.set_style(style, false)
	Flora.off = OS.get_environment("LAND_NO_FLORA") != ""
	GroundRelief.off = OS.get_environment("LAND_NO_RELIEF") != ""


func capture_shots(tool: Node, out: String) -> void:
	var only := OS.get_environment("LAND_SHOTS").split(",", false)
	for id: String in SHOTS:
		if not only.is_empty() and not id in only:
			continue
		var shot := SHOTS[id] as Dictionary
		_build(shot)
		await tool.call("wait_frames", 45)
		if OS.get_environment("LAND_BENCH") != "":
			await _bench(tool, id)
			continue
		if OS.get_environment("LAND_TIME") != "":
			DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
			Engine.max_fps = 0
			await tool.call("wait_frames", 20)
			var t0 := Time.get_ticks_usec()
			await tool.call("wait_frames", 120)
			var ms := float(Time.get_ticks_usec() - t0) / 1000.0 / 120.0
			Engine.max_fps = 60
			DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_ENABLED)
			print("land %s %s: %.2f ms a frame uncapped (%d fps)" % [Look.style(), id, ms, int(1000.0 / ms)])
			await tool.call("wait_frames", 10)
		tool.call("_shot", "%s_%s.png" % [out, id])
		for f in int(OS.get_environment("LAND_GIF")) if OS.get_environment("LAND_GIF") != "" else 0:
			await tool.call("wait_frames", 6)
			tool.call("_shot", "%s_%s_%02d.png" % [out, id, f])


func _build(shot: Dictionary) -> void:
	if view != null:
		view.queue_free()
		view = null
	GameState.reset()
	for pid: String in PARTY:
		var ch := Pregens.build(pid, 3)
		ch.finish_long_rest()
		GameState.story.party.append(ch)
	var st := GameState.story
	st.minute_of_day = int(shot.get("hour", 12)) * 60
	var loc_id := str(shot["loc"])
	var cells := shot.get("cells", []) as Array
	if not cells.is_empty():
		# Saved positions in the place itself put the party where the shot wants them.
		st.location = loc_id
		st.visited[loc_id] = true
		for c: Array in cells:
			st.positions.append(Vector2i(int(c[0]), int(c[1])))
	view = LocationView.create(loc_id, st, Narrator.new(), Dice.roller, "" if not cells.is_empty() else "default")
	add_child(view)
	view.update_daylight()
	view.atmosphere.settle()
	var zoom := float(OS.get_environment("LAND_ZOOM")) if OS.get_environment("LAND_ZOOM") != "" \
		else float(shot.get("zoom", 13.0))
	view.rig.zoom_max = maxf(view.rig.zoom_max, zoom)
	view.rig.distance = zoom
	view.rig.rotate_step(int(shot.get("turns", 0)))
	view.rig.horizon = float(shot.get("tilt", 0.0))
	view.rig.snap_to_target()
	if str(shot.get("face", "")) == "castle":
		_face_castle(loc_id)
	if shot.has("look"):
		var at := shot["look"] as Array
		view.rig.follow = null
		view.rig.global_position = Vector3(float(at[0]), 0.0, float(at[1]))
	if OS.get_environment("LAND_RAW") != "":
		view.post.visible = false
	if OS.get_environment("LAND_NO_DOF") != "" and view.rig.camera.attributes is CameraAttributesPractical:
		(view.rig.camera.attributes as CameraAttributesPractical).dof_blur_far_enabled = false
	if OS.get_environment("LAND_CLAY") != "" and view.atmosphere.land != null:
		# The shaped ground in plain clay, to see its shape without the texture.
		var clay := Look.cel("stone")
		for pattern: String in ["Walked*", "Banks"]:
			for n in view.atmosphere.land.root.find_children(pattern, "MeshInstance3D", true, false):
				(n as MeshInstance3D).material_override = clay


## Times the place with each group of the land's plants hidden in turn, over several rounds, and prints the quickest
## quarter of each: what a group costs is the frame time it saves when hidden.
func _bench(tool: Node, id: String) -> void:
	var land := view.atmosphere.land
	if land == null:
		return
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	Engine.max_fps = 0
	RenderingServer.viewport_set_measure_render_time(get_viewport().get_viewport_rid(), true)
	var groups := {"all": [], "no_ground": ["Plants_", "MapPlants_"], "no_far_trees": ["FarTrees_"],
		"no_trees": ["Trees_", "FarTrees_"], "no_near": ["Plant_"], "bare": [""]}
	var times := {}
	for g: String in groups:
		times[g] = []
	var tri := 0
	for n in land.root.find_children("*", "MultiMeshInstance3D", true, false):
		var mm := (n as MultiMeshInstance3D).multimesh
		var faces := mm.mesh.get_faces().size() / 3 if mm.mesh != null else 0
		tri += faces * mm.instance_count
	print("bench %s: %d plant nodes, %d triangles in multimeshes" % [id, land.root.get_child_count(), tri])
	var per := {}
	for n in land.root.find_children("*", "MultiMeshInstance3D", true, false):
		var mm := (n as MultiMeshInstance3D).multimesh
		var key := (n.name as String).get_slice("_", 0) + ":" + mm.mesh.resource_name
		per[key] = int(per.get(key, 0)) + mm.instance_count
	print("bench %s copies: %s" % [id, per])
	for round_ in 4:
		for g: String in groups:
			for n in land.root.get_children():
				var hide := false
				for pre: String in groups[g] as Array:
					if (n.name as String).begins_with(pre):
						hide = true
				(n as Node3D).visible = not hide
			await tool.call("wait_frames", 15)
			if round_ == 0:
				print("bench %s %s: gpu %.2f ms cpu %.2f ms, %d primitives, %d draw calls, %d objects in the frame" % [id, g,
					RenderingServer.viewport_get_measured_render_time_gpu(get_viewport().get_viewport_rid()),
					RenderingServer.viewport_get_measured_render_time_cpu(get_viewport().get_viewport_rid()),
					RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_PRIMITIVES_IN_FRAME),
					RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME),
					RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_OBJECTS_IN_FRAME)])
			var last := Time.get_ticks_usec()
			for i in 40:
				await tool.call("wait_frames", 1)
				var now := Time.get_ticks_usec()
				(times[g] as Array).append(float(now - last) / 1000.0)
				last = now
	for g: String in groups:
		var t := times[g] as Array
		t.sort()
		var quick := t.slice(0, t.size() / 4)
		var sum := 0.0
		for v: float in quick:
			sum += v
		print("bench %s %s: %.2f ms (median %.2f)" % [id, g, sum / quick.size(), float(t[t.size() / 2])])
	for n in land.root.get_children():
		(n as Node3D).visible = true
	Engine.max_fps = 60
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_ENABLED)


## Turns the camera the quarter turns that best face Castle Ravenloft from this place (Vista's travel positions).
func _face_castle(loc_id: String) -> void:
	var here: Variant = Vista.place_at(loc_id)
	var castle := (Vista.config().get("castle", {}) as Dictionary).get("at", [0.5, 0.5]) as Array
	if here == null:
		return
	var want := (Vector2(float(castle[0]), float(castle[1])) - (here as Vector2)).normalized()
	var best := 0
	var best_dot := -2.0
	for k in 4:
		var fwd := view.rig.ground_basis()[0]
		var d := Vector2(fwd.x, fwd.z).dot(want)
		if d > best_dot:
			best_dot = d
			best = k
		view.rig.rotate_step(1)
		view.rig.snap_to_target()
	view.rig.rotate_step(best)
	view.rig.snap_to_target()
