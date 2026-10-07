extends Node
## The world look's before-and-after shots (the light and shaders lane, Improvement Ideas W1 to W18): the same places
## from the game's camera with the party standing in them, each with its frame time, so a change to the light,
## the materials or the screen pass can be judged side by side and against the frame budget. Not part of the game.
## The frame time is measured uncapped (no vsync, no frame cap) over two seconds' worth of frames: the window is drawn
## off screen, where Godot's own GPU timer reads zero, so the time a frame takes end to end stands in for it.
##   make capture SCENE=res://tools/capture/look_capture.tscn NAME=look/before FRAMES=10
## Environment: LOOK_SHOTS=village_dusk,castle_hall (default: every shot), LOOK_STYLE=classic|modern and
## LOOK_GRAPHICS=low|medium|high (this run only), LOOK_OFF=msaa,pcss,lamps,filter,splits,ssr (turn one thing off to see
## what it costs), LOOK_AA=msaa2|fxaa|smaa (another anti-aliasing in its place). LOOK_BENCH=1 times each part of
## the renderer in turn instead (_bench), and LOOK_BENCH=presets the graphics presets, several rounds over, since
## other work on the machine makes one reading noisy.

## Each shot: the place, the hour, where the party stands (empty: the place's own spawn) and the camera.
const SHOTS := {
	"village_dusk": {"loc": "village_of_barovia", "hour": 18},
	"village_night": {"loc": "village_of_barovia", "hour": 23},
	"death_house_hall": {"loc": "death_house_ground", "cells": [[13, 8], [14, 8], [13, 9], [14, 9]]},
	"road_day": {"loc": "into_the_mists_road", "hour": 12, "cells": [[12, 15], [13, 15], [12, 16], [13, 14]]},
	"road_dusk": {"loc": "into_the_mists_road", "hour": 18, "cells": [[12, 15], [13, 15], [12, 16], [13, 14]]},
	"castle_hall": {"loc": "castle_ravenloft_main_floor", "cells": [[25, 8], [26, 8], [25, 9], [26, 9]]},
	"tser_pool": {"loc": "tser_pool", "hour": 18},
}
const PARTY: Array[String] = ["godrick_pendlebrook", "liriel_dawnsong", "thistle", "ratatoille"]

var view: LocationView = null


func _ready() -> void:
	InputActions.ensure()
	var style := OS.get_environment("LOOK_STYLE")
	if style != "":
		Look.set_style(style, false)
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
		if OS.get_environment("LOOK_BENCH") == "presets":
			await _bench_presets(tool, id)
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
		print("look %s %s: %.2f ms a frame uncapped (%d fps)" % [Look.style(), id, ms, int(1000.0 / ms)])
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


## Times the graphics presets, and High without MSAA, the same way: round after round, with the mean, the median and
## where the quickest quarter of frames ends.
func _bench_presets(tool: Node, id: String) -> void:
	var was := Graphics.preset()
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	Engine.max_fps = 0
	var parts: Array[String] = ["high", "high_no_msaa", "medium", "low"]
	var times := {}
	for p in parts:
		times[p] = []
	for round_ in 6:
		for p in parts:
			Graphics.set_preset("high" if p == "high_no_msaa" else p, false)
			if p == "high_no_msaa":
				get_viewport().msaa_3d = Viewport.MSAA_DISABLED
			view.atmosphere.call("_update_lamp_shadows")
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
	Graphics.set_preset(was, false)
	Engine.max_fps = 60
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_ENABLED)
