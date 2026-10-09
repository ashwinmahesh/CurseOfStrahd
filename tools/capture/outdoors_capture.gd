extends Node3D
## The outdoors lane's before-and-after shots (lane 28, livelier outdoor areas): each outdoor place from the game's
## camera with the party standing in it, the minimap in its corner as the HUD shows it, and the frame's draw calls,
## objects and triangles (and, with OUTDOORS_TIME=1, its frame time uncapped). Not part of the game.
##   make capture SCENE=res://tools/capture/outdoors_capture.tscn NAME=outdoors/before FRAMES=10
## Environment: OUTDOORS_SHOTS=tser_road,tser_tent (default: every shot), OUTDOORS_TIME=1, OUTDOORS_LOCS=krezk,berez
## (instead: each place from its arrival, near and far, to check it against its descriptions), OUTDOORS_WEATHER=overcast
## (the same weather everywhere, so a fog day doesn't hide the place), OUTDOORS_STRIKE=1 (a calm frame, then the frame
## of a close lightning strike).

## Each shot: the place, the hour, where the leader stands (the others beside them), the camera's distance, its
## quarter turns and how far it tilts toward the horizon (CameraRig.horizon, 0 to 1).
const SHOTS := {
	"tser_road": {"loc": "tser_pool", "hour": 15, "at": [22, 24], "zoom": 18.0},
	"tser_camp": {"loc": "tser_pool", "hour": 15, "at": [24, 16], "zoom": 14.0},
	"tser_tent": {"loc": "tser_pool", "hour": 15, "at": [32, 9], "zoom": 14.0},
	"tser_shore": {"loc": "tser_pool", "hour": 15, "at": [15, 9], "zoom": 13.0, "turns": 3},
	"tser_pen": {"loc": "tser_pool", "hour": 15, "at": [14, 17], "zoom": 13.0},
	"tser_dusk": {"loc": "tser_pool", "hour": 19, "at": [24, 16], "zoom": 16.0},
	"tser_far": {"loc": "tser_pool", "hour": 15, "at": [22, 13], "zoom": 30.0, "tilt": 0.6},
}
const PARTY: Array[String] = ["godrick_pendlebrook", "liriel_dawnsong", "thistle", "ratatoille"]
const BESIDE: Array[Vector2i] = [Vector2i.ZERO, Vector2i(1, 0), Vector2i(0, 1), Vector2i(1, 1)]

var view: LocationView = null
var minimap: Minimap = null


func _ready() -> void:
	InputActions.ensure()
	var layer := CanvasLayer.new()
	layer.layer = 10
	add_child(layer)
	minimap = Minimap.new()
	minimap.position = Vector2(1600 - (Minimap.RADIUS + Minimap.RIM) * 2.0 - 16.0, 16.0)
	layer.add_child(minimap)


func capture_shots(tool: Node, out: String) -> void:
	var only := OS.get_environment("OUTDOORS_SHOTS").split(",", false)
	var shots := SHOTS.duplicate()
	if OS.get_environment("OUTDOORS_LOCS") != "":
		shots.clear()
		for loc_id: String in OS.get_environment("OUTDOORS_LOCS").split(",", false):
			shots[loc_id + "_near"] = {"loc": loc_id, "hour": 15, "zoom": 16.0}
			shots[loc_id + "_far"] = {"loc": loc_id, "hour": 15, "zoom": 30.0, "tilt": 0.6}
	for id: String in shots:
		if not only.is_empty() and not id in only:
			continue
		_build(shots[id] as Dictionary)
		await tool.call("wait_frames", 45)
		var rid := get_viewport().get_viewport_rid()
		print("outdoors %s: %d draw calls, %d objects, %d primitives" % [id,
			RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME),
			RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_OBJECTS_IN_FRAME),
			RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_PRIMITIVES_IN_FRAME)])
		if OS.get_environment("OUTDOORS_TIME") != "":
			DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
			Engine.max_fps = 0
			RenderingServer.viewport_set_measure_render_time(rid, true)
			await tool.call("wait_frames", 20)
			var t0 := Time.get_ticks_usec()
			await tool.call("wait_frames", 120)
			var ms := float(Time.get_ticks_usec() - t0) / 1000.0 / 120.0
			Engine.max_fps = 60
			DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_ENABLED)
			print("outdoors %s: %.2f ms a frame uncapped (%d fps)" % [id, ms, int(1000.0 / ms)])
			await tool.call("wait_frames", 10)
		if OS.get_environment("OUTDOORS_STRIKE") != "":
			# A lightning strike (lane 28): the calm frame, then the frame the bolt comes down and the flash lights it.
			tool.call("_shot", "%s_%s_calm.png" % [out, id])
			view.atmosphere.strike(true)
			await tool.call("wait_frames", 2)
			tool.call("_shot", "%s_%s_strike.png" % [out, id])
			continue
		tool.call("_shot", "%s_%s.png" % [out, id])


func _build(shot: Dictionary) -> void:
	if OS.get_environment("OUTDOORS_WEATHER") != "":
		var d := Weather.data().duplicate(true)
		for c: String in d["climates"]:
			d["climates"][c] = {OS.get_environment("OUTDOORS_WEATHER"): 1}
		Weather.use(d)
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
	var spawn := "default"
	if shot.has("at"):
		var at := shot["at"] as Array
		st.location = loc_id
		st.visited[loc_id] = true
		for d in BESIDE:
			st.positions.append(Vector2i(int(at[0]), int(at[1])) + d)
		spawn = ""
	view = LocationView.create(loc_id, st, Narrator.new(), Dice.roller, spawn)
	add_child(view)
	view.update_daylight()
	view.atmosphere.settle()
	var zoom := float(shot.get("zoom", 14.0))
	view.rig.zoom_max = maxf(view.rig.zoom_max, zoom)
	view.rig.distance = zoom
	view.rig.rotate_step(int(shot.get("turns", 0)))
	view.rig.horizon = float(shot.get("tilt", 0.0))
	view.rig.snap_to_target()
	minimap.show_location(view)
