extends Node3D
## The natural maps audit (owner 2026-10-19: "Audit EVERYTHING and make our maps look more natural (not just like a
## battle grid)"; the vault's Natural Maps Plan): every location, or the ones named, built as in the game and shot three
## ways: whole from above, from the play camera at the party's spawn, and tilted to the horizon there. Not part of the
## game.
##   make capture SCENE=res://tools/capture/natural_audit.tscn NAME=natural/before FRAMES=10
## Environment: NA_LOCS=a,b (default every location with a map), NA_SHOTS=whole,play,tilt (default all three),
## NA_HOUR=12, NA_WEATHER=overcast (the world's weather for the whole run; default the new game's own), NA_AT=x,z (the
## play and tilt shots look at this square instead of the spawn; with one place only).
## Shots: <out>_<loc>_whole.png, _play.png, _tilt.png.

const PARTY: Array[String] = ["godrick_pendlebrook", "liriel_dawnsong", "thistle", "ratatoille"]

var view: LocationView = null


func _ready() -> void:
	InputActions.ensure()
	var weather := OS.get_environment("NA_WEATHER")
	if weather != "":
		# Every climate has only that weather, for this run.
		var d := Weather.data().duplicate(true)
		var climates := {}
		for c: String in d.get("climates", {}) as Dictionary:
			climates[c] = {weather: 1}
		d["climates"] = climates
		Weather.use(d)


## Every location with a map, in id order.
static func locations() -> Array[String]:
	var out: Array[String] = []
	for id: String in Compendium.shared().tables["locations"] as Dictionary:
		if (Compendium.shared().get_entry("locations", id) as Dictionary).has("map"):
			out.append(id)
	out.sort()
	return out


func capture_shots(tool: Node, out: String) -> void:
	var ids := locations()
	if OS.get_environment("NA_LOCS") != "":
		ids.assign(OS.get_environment("NA_LOCS").split(",", false))
	var shots := OS.get_environment("NA_SHOTS").split(",", false)
	if shots.is_empty():
		shots = PackedStringArray(["whole", "play", "tilt"])
	var hour := int(OS.get_environment("NA_HOUR")) if OS.get_environment("NA_HOUR") != "" else 12
	for id in ids:
		_build(id, hour)
		await tool.call("wait_frames", 30)
		var rig := view.rig
		var at := view.board.cell_center(_spawn())
		if OS.get_environment("NA_AT") != "":
			var a := OS.get_environment("NA_AT").split(",")
			at = view.board.cell_center(Vector2i(int(a[0]), int(a[1])))
		if "whole" in shots:
			rig.horizon = 0.0
			rig.distance = maxf(view.grid.width, view.grid.depth) * 1.05
			rig.global_position = Vector3(view.grid.width / 2.0, 0, view.grid.depth / 2.0)
			rig.snap_to_target()
			await tool.call("wait_frames", 12)
			tool.call("_shot", "%s_%s_whole.png" % [out, id])
		if "play" in shots:
			rig.horizon = 0.0
			rig.distance = 16.0
			rig.global_position = at
			rig.snap_to_target()
			await tool.call("wait_frames", 12)
			tool.call("_shot", "%s_%s_play.png" % [out, id])
		if "tilt" in shots:
			rig.horizon = 1.0
			rig.distance = 22.0
			rig.global_position = at
			rig.snap_to_target()
			await tool.call("wait_frames", 12)
			tool.call("_shot", "%s_%s_tilt.png" % [out, id])
		view.queue_free()
		view = null
		await tool.call("wait_frames", 2)


## Where the party stands on arrival: the leader's square.
func _spawn() -> Vector2i:
	if view.leader() != null:
		return view.leader().cell
	return Vector2i(view.grid.width / 2, view.grid.depth / 2)


func _build(loc_id: String, hour: int) -> void:
	GameState.reset()
	for id: String in PARTY:
		var ch := Pregens.build(id, 3)
		ch.finish_long_rest()
		GameState.story.party.append(ch)
	GameState.story.minute_of_day = hour * 60
	view = LocationView.create(loc_id, GameState.story, Narrator.new(), Dice.roller, "default")
	add_child(view)
	view.update_daylight()
	view.atmosphere.settle()
	var rig := view.rig
	rig.follow = null
	rig.zoom_max = maxf(rig.zoom_max, 60.0)
