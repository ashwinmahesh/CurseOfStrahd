extends Node
## The world look's before-and-after shots (the light and shaders lane, Improvement Ideas W1 to W18): the same places
## from the game's camera with the party standing in them, each with its frame time, so a change to the light,
## the materials or the screen pass can be judged side by side and against the frame budget. Not part of the game.
## The frame time is measured uncapped (no vsync, no frame cap) over two seconds' worth of frames: the window is drawn
## off screen, where Godot's own GPU timer reads zero, so the time a frame takes end to end stands in for it.
##   make capture SCENE=res://tools/capture/look_capture.tscn NAME=look/before FRAMES=10
## Environment (each for this run only):
## - LOOK_SHOTS=village_dusk,castle_hall: which shots (default every one).
## - LOOK_STYLE=classic|modern, LOOK_GRAPHICS=low|medium|high: the finish and the graphics preset.
## - LOOK_METER=1: the F3 frame meter shown.
## - LOOK_OFF=msaa,pcss,lamps,filter,splits,ssr: turn things off to see what they cost.
## - LOOK_AA=msaa2|fxaa|smaa: another anti-aliasing in place of the preset's.
## - LOOK_OUTLINE=off|silhouette|full: the world's ink lines.
## - LOOK_FADE=1: the 3D pieces near the party faded, as when they stand in front of it.
## - LOOK_TILT=1: the camera looking out to the horizon (the sky and what lies past the map).
## - LOOK_BENCH=1 times each part of the renderer in turn instead of shooting (_bench), LOOK_BENCH=presets the graphics
##   presets, several rounds over, since other work on the machine makes one reading noisy; LOOK_BENCH=pairs what one
##   change saves, switching it on and off in quick turns (_bench_pairs), the steadiest under load.

## Each shot: the place, the hour, where the party stands (empty: the place's own spawn) and, optionally, a square
## it walks to before the shot.
const SHOTS := {
	"village_dusk": {"loc": "village_of_barovia", "hour": 18},
	"village_night": {"loc": "village_of_barovia", "hour": 23},
	"death_house_hall": {"loc": "death_house_ground", "cells": [[13, 8], [14, 8], [13, 9], [14, 9]]},
	"road_day": {"loc": "into_the_mists_road", "hour": 12, "cells": [[12, 15], [13, 15], [12, 16], [13, 14]]},
	"road_dusk": {"loc": "into_the_mists_road", "hour": 18, "cells": [[12, 15], [13, 15], [12, 16], [13, 14]]},
	"castle_hall": {"loc": "castle_ravenloft_main_floor", "cells": [[25, 8], [26, 8], [25, 9], [26, 9]]},
	"tser_pool": {"loc": "tser_pool", "hour": 18},
	"death_house_den": {"loc": "death_house_ground", "cells": [[4, 5], [5, 5], [4, 6], [5, 6]]},
	"tavern": {"loc": "blood_of_the_vine"},
	"lake_dusk": {"loc": "lake_zarovich", "hour": 18, "cells": [[16, 10], [17, 10], [16, 11], [17, 11]]},
	"lake_night": {"loc": "lake_zarovich", "hour": 23, "cells": [[16, 10], [17, 10], [16, 11], [17, 11]]},
	"tser_pool_water": {"loc": "tser_pool", "hour": 23, "cells": [[15, 9], [16, 9], [15, 10], [16, 10]]},
	"berez_night": {"loc": "berez", "hour": 23, "cells": [[24, 6], [25, 6], [24, 7], [25, 5]]},
	"vallaki_rain": {"loc": "vallaki", "hour": 18},
	"castle_gates_storm": {"loc": "castle_ravenloft_gates", "hour": 23, "cells": [[19, 30], [20, 30], [19, 29], [20, 29]]},
	"krezk_snow": {"loc": "krezk", "hour": 12, "cells": [[14, 7], [15, 7], [14, 8], [15, 8]]},
	"abbey_snow": {"loc": "abbey_of_st_markovia", "hour": 12, "walk": [8, 20], "zoom": 9},
	"baratok_snow_walk": {"loc": "mount_baratok", "hour": 12, "walk": [17, 18], "zoom": 9},
	"berez_mud_walk": {"loc": "berez", "hour": 12, "cells": [[2, 5], [2, 6], [3, 5], [3, 6]], "walk": [8, 6], "zoom": 8},
	"village_mud_walk": {"loc": "village_of_barovia", "hour": 18, "cells": [[14, 27], [15, 27], [14, 28], [15, 28]],
		"walk": [14, 22], "zoom": 8},
	"castle_dining": {"loc": "castle_ravenloft_main_floor", "cells": [[7, 10], [8, 10], [7, 11], [8, 11]]},
}
const PARTY: Array[String] = ["godrick_pendlebrook", "liriel_dawnsong", "thistle", "ratatoille"]

var view: LocationView = null


func _ready() -> void:
	InputActions.ensure()
	var style := OS.get_environment("LOOK_STYLE")
	if style != "":
		Look.set_style(style, false)
	if OS.get_environment("LOOK_METER") != "":
		GameSettings.set_value("frame_meter", true, false)
	var graphics := OS.get_environment("LOOK_GRAPHICS")
	if graphics != "":
		Graphics.set_preset(graphics, false)


func capture_shots(tool: Node, out: String) -> void:
	var only := OS.get_environment("LOOK_SHOTS").split(",", false)
	for id: String in SHOTS:
		if not only.is_empty() and not id in only:
			continue
		var shot := SHOTS[id] as Dictionary
		_build(shot)
		await tool.call("wait_frames", 45)
		if shot.has("walk"):
			# Walk the party somewhere first (footprints, a trail through the weather).
			var to := shot["walk"] as Array
			var from := view.leader().cell
			var walked := view.walk_to(Vector2i(int(to[0]), int(to[1])))
			await tool.call("wait_frames", 240)
			print("look %s: walked %s from %s to %s, %d footprints" % [id, walked, from, view.leader().cell,
				view.atmosphere._prints.size()])
			# Look back along the way they came.
			view.rig.follow = null
			view.rig.global_position = (view.board.cell_center(from) + view.board.cell_center(view.leader().cell)) / 2.0
			view.rig.snap_to_target()
		if shot.has("zoom"):
			view.rig.distance = float(shot["zoom"])
			await tool.call("wait_frames", 30)
		if OS.get_environment("LOOK_BENCH") == "presets":
			await _bench_presets(tool, id)
			continue
		if OS.get_environment("LOOK_BENCH") == "pairs":
			await _bench_pairs(tool, id)
			continue
		if OS.get_environment("LOOK_BENCH") != "":
			await _bench(tool, id)
			continue
		DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
		Engine.max_fps = 0
		await tool.call("wait_frames", 20)
		var t0 := Time.get_ticks_usec()
		await tool.call("wait_frames", 120)
		var ms := float(Time.get_ticks_usec() - t0) / 1000.0 / 120.0
		Engine.max_fps = 60
		DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_ENABLED)
		var calls := RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME)
		print("look %s %s: %.2f ms a frame uncapped (%d fps), %d draw calls, %d lights" % [Look.style(), id, ms,
			int(1000.0 / ms), calls, view.find_children("*", "OmniLight3D", true, false).size()])
		await tool.call("wait_frames", 10)
		tool.call("_shot", "%s_%s.png" % [out, id])


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
	view.rig.snap_to_target()
	var post := (view.post.mesh as QuadMesh).material as ShaderMaterial
	match OS.get_environment("LOOK_OUTLINE"):
		"off":
			post.set_shader_parameter("outlines", false)
		"silhouette":
			post.set_shader_parameter("outline_creases", false)
			post.set_shader_parameter("outline_strength", 0.55)
		"full":
			post.set_shader_parameter("outlines", true)
			post.set_shader_parameter("outline_creases", true)
			post.set_shader_parameter("outline_strength", 1.0)
	if OS.get_environment("LOOK_FADE") != "":
		# Every 3D piece within five squares of the party fades as if it stood in front of them (the post chain's
		# fade check).
		var focus := view.rig.global_position
		for t in view.board.mesh_occluders:
			if is_instance_valid(t) and t.global_position.distance_to(focus) < 5.0:
				t.set_meta("fade", 0.72)
				ModelPiece.set_fade(t, 0.72)
		view.set_process(false)
	if OS.get_environment("LOOK_TILT") != "":
		# Looking out to the horizon: the camera tilted all the way past its farthest zoom (CameraRig.horizon).
		view.rig.distance = view.rig.zoom_max
		view.rig.horizon = 1.0
		view.rig.snap_to_target()
	if OS.get_environment("LOOK_SDFGI") != "":
		var env := view.atmosphere.env
		env.sdfgi_enabled = true
		env.sdfgi_use_occlusion = true
		env.sdfgi_cascades = 4
		env.sdfgi_min_cell_size = 0.2
		env.sdfgi_bounce_feedback = 0.5
		env.sdfgi_energy = 1.0
		env.ssil_enabled = false
	if OS.get_environment("LOOK_WET") != "":
		RenderingServer.global_shader_parameter_set(&"world_wet", float(OS.get_environment("LOOK_WET")))
	var off := OS.get_environment("LOOK_OFF").split(",", false)
	if "msaa" in off:
		get_viewport().msaa_3d = Viewport.MSAA_DISABLED
	match OS.get_environment("LOOK_AA"):
		"msaa2":
			get_viewport().msaa_3d = Viewport.MSAA_2X
		"fxaa":
			get_viewport().screen_space_aa = Viewport.SCREEN_SPACE_AA_FXAA
		"smaa":
			get_viewport().screen_space_aa = Viewport.SCREEN_SPACE_AA_SMAA
	if "pcss" in off:
		view.atmosphere.sun.light_angular_distance = 0.0
	if "filter" in off:
		RenderingServer.directional_soft_shadow_filter_set_quality(RenderingServer.SHADOW_QUALITY_SOFT_LOW)
		RenderingServer.positional_soft_shadow_filter_set_quality(RenderingServer.SHADOW_QUALITY_SOFT_LOW)
	if "post" in off:
		view.post.visible = false
	if "weather" in off and view.atmosphere.weather != null:
		for w in view.atmosphere.weather.follow:
			w.visible = false
	if "vista" in off:
		for v in view.find_children("Vista*", "Node3D", true, false):
			(v as Node3D).visible = false
	if "sky" in off:
		view.atmosphere.set_process(false)
		post.set_shader_parameter("sky_on", false)
	if "ssr" in off:
		view.atmosphere.env.ssr_enabled = false
	if "splits" in off:
		view.atmosphere.sun.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_2_SPLITS
	if "lamps" in off:
		for l in view.find_children("*", "OmniLight3D", true, false):
			l.set_meta("no_shadow", true)
			(l as OmniLight3D).shadow_enabled = false


## Times the place with each part of the renderer on its own over a bare base (no anti-aliasing, no lamp shadows, the
## sun in two splits and unsoftened), round after round, and prints the quickest quarter of each part's frames: the
## cost of the part is its time less the base's.
func _bench(tool: Node, id: String) -> void:
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	Engine.max_fps = 0
	var vp := get_viewport()
	var sun := view.atmosphere.sun
	var lights := view.find_children("*", "OmniLight3D", true, false)
	var parts: Array[String] = ["base", "msaa4", "msaa2", "smaa", "fxaa", "sun_splits4", "sun_pcss", "filter_high",
		"lamps", "all"]
	var times := {}
	for p in parts:
		times[p] = []
	for round_ in 4:
		for p in parts:
			vp.msaa_3d = Viewport.MSAA_DISABLED
			if p in ["msaa4", "all"]:
				vp.msaa_3d = Viewport.MSAA_4X
			elif p == "msaa2":
				vp.msaa_3d = Viewport.MSAA_2X
			vp.screen_space_aa = Viewport.SCREEN_SPACE_AA_DISABLED
			if p in ["smaa", "all"]:
				vp.screen_space_aa = Viewport.SCREEN_SPACE_AA_SMAA
			elif p == "fxaa":
				vp.screen_space_aa = Viewport.SCREEN_SPACE_AA_FXAA
			var four := p in ["sun_splits4", "all"]
			sun.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_4_SPLITS if four \
				else DirectionalLight3D.SHADOW_PARALLEL_2_SPLITS
			sun.light_angular_distance = Atmosphere.SUN_SIZE if p in ["sun_pcss", "all"] else 0.0
			var q := RenderingServer.SHADOW_QUALITY_SOFT_HIGH if p in ["filter_high", "all"] \
				else RenderingServer.SHADOW_QUALITY_SOFT_LOW
			RenderingServer.directional_soft_shadow_filter_set_quality(q)
			RenderingServer.positional_soft_shadow_filter_set_quality(q)
			for l in lights:
				if p in ["lamps", "all"]:
					l.remove_meta("no_shadow")
				else:
					l.set_meta("no_shadow", true)
					(l as OmniLight3D).shadow_enabled = false
			view.atmosphere.call("_update_lamp_shadows")
			await tool.call("wait_frames", 15)
			var last := Time.get_ticks_usec()
			for i in 40:
				await tool.call("wait_frames", 1)
				var now := Time.get_ticks_usec()
				(times[p] as Array).append(float(now - last) / 1000.0)
				last = now
	for p in parts:
		var t := times[p] as Array
		t.sort()
		var quick := t.slice(0, t.size() / 4)
		var sum := 0.0
		for v: float in quick:
			sum += v
		print("bench %s %s: %.2f ms (median %.2f)" % [id, p, sum / quick.size(), float(t[t.size() / 2])])
	Engine.max_fps = 60
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_ENABLED)


## Times the graphics presets, and High with one setting at a time stepped down to Medium's, the same way: round after
## round, with the mean, the median and where the quickest quarter of frames ends.
func _bench_presets(tool: Node, id: String) -> void:
	var was := Graphics.preset()
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	Engine.max_fps = 0
	# High, then High with one setting at Medium's (or off), then Medium and Low.
	var med := Graphics.SPECS["medium"] as Dictionary
	var less := {"high": {}, "hash_noise": {}, "-msaa": {"msaa": Viewport.MSAA_DISABLED},
		"msaa2": {"msaa": Viewport.MSAA_2X}, "-splits2": {"sun_splits": 2}, "-dof_low": {"dof": med["dof"]},
		"-ao": {"ao": med["ao"], "ao_half": true},
		"-bounce": {"bounce": -1}, "-filter": {"filter": med["filter"]}, "-lamp_soft": {"lamp_soft": false},
		"-sun_soft": {"sun_soft": false}, "-lamps6": {"lamp_shadows": 6, "lamp_atlas": 4096}, "-haze48": {"haze": 48},
		"-ssr32": {"reflections": 32}, "-sway": {"swaying": 0}, "medium": {}, "low": {}}
	var parts: Array[String] = []
	for k: String in less:
		parts.append(k)
	var times := {}
	for p in parts:
		times[p] = []
	for round_ in 5:
		for p in parts:
			Graphics.overrides = less[p] as Dictionary
			Graphics.set_preset(p if p in Graphics.PRESETS else "high", false)
			var post := (view.post.mesh as QuadMesh).material as ShaderMaterial
			post.set_shader_parameter("fast_noise", p != "hash_noise")
			await tool.call("wait_frames", 20)
			var last := Time.get_ticks_usec()
			for i in 60:
				await tool.call("wait_frames", 1)
				var now := Time.get_ticks_usec()
				(times[p] as Array).append(float(now - last) / 1000.0)
				last = now
	for p in parts:
		var t := times[p] as Array
		var sum := 0.0
		for v: float in t:
			sum += v
		t.sort()
		print("presets %s %s: mean %.2f ms, median %.2f, quickest quarter from %.2f" % [id, p, sum / t.size(),
			float(t[t.size() / 2]), float(t[t.size() / 4])])
	Graphics.overrides = {}
	Graphics.set_preset(was, false)
	Engine.max_fps = 60
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_ENABLED)


## What each change saves on the High preset, steady under load: the change is switched on and off every 16 frames,
## ten times, the first 4 frames after each switch dropped; the saving is the median over the turns of the frame time
## with it on less with it off.
func _bench_pairs(tool: Node, id: String) -> void:
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	Engine.max_fps = 0
	var post := (view.post.mesh as QuadMesh).material as ShaderMaterial
	var floors: Array[MeshInstance3D] = []
	for n in view.board.get_children():
		var mi := n as MeshInstance3D
		if mi != null and mi.cast_shadow == GeometryInstance3D.SHADOW_CASTING_SETTING_OFF and mi.mesh is BoxMesh:
			floors.append(mi)
	var sun := view.atmosphere.sun
	var vp := get_viewport()
	# [name, on, off]: what to set for the change on, and for it off.
	var env := view.atmosphere.env
	var changes: Array[Array] = [
		["SDFGI (vs SSIL)", func() -> void:
			env.sdfgi_enabled = true
			env.ssil_enabled = false,
			func() -> void:
				env.sdfgi_enabled = false
				env.ssil_enabled = Graphics.bounce()],
		["texture noise (vs hashed)", func() -> void: post.set_shader_parameter("fast_noise", true),
			func() -> void: post.set_shader_parameter("fast_noise", false)],
		["flat floors cast no shadow", func() -> void:
			for f in floors:
				f.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF,
			func() -> void:
				for f in floors:
					f.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON],
		["sun in 2 splits (vs 4)", func() -> void: sun.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_2_SPLITS,
			func() -> void: sun.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_4_SPLITS],
		["MSAA 2x (vs 4x)", func() -> void: vp.msaa_3d = Viewport.MSAA_2X, func() -> void: vp.msaa_3d = Viewport.MSAA_4X],
		["no MSAA (vs 4x)", func() -> void: vp.msaa_3d = Viewport.MSAA_DISABLED,
			func() -> void: vp.msaa_3d = Viewport.MSAA_4X],
		["no sun shadows", func() -> void: sun.shadow_enabled = false, func() -> void: sun.shadow_enabled = true],
	]
	for c: Array in changes:
		var on := c[1] as Callable
		var off := c[2] as Callable
		var savings: Array[float] = []
		var with_on := 0.0
		for turn in 10:
			var times := [0.0, 0.0]
			for side in 2:
				(off if side == 0 else on).call()
				await tool.call("wait_frames", 4)
				var t0 := Time.get_ticks_usec()
				await tool.call("wait_frames", 12)
				times[side] = float(Time.get_ticks_usec() - t0) / 1000.0 / 12.0
			savings.append(float(times[0]) - float(times[1]))
			with_on += float(times[1])
		off.call()
		savings.sort()
		print("pairs %s %s: saves %.2f ms (median of 10; with it %.1f ms a frame)" % [id, c[0],
			savings[savings.size() / 2], with_on / 10.0])
	Engine.max_fps = 60
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_ENABLED)
