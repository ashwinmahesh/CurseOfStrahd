extends Node
## The region variety lane's shots (the vault's "Region Variety Plan.md"): one place from every region of the valley
## from the game's camera, with the party standing in it, so the regions can be judged side by side and against each
## other. With REGION_BEFORE each shot is taken twice in the same run, first with the look data in that folder (the
## files from before a change), then with the game's own, so a pair differs only in the data. Not part of the game.
##   make capture SCENE=res://tools/capture/region_capture.tscn NAME=region-variety/r FRAMES=10
## Environment (each for this run only):
## - REGION_SHOTS=woods,lake: which shots (default every one).
## - REGION_HOURS=12,18: the hours each shot is taken at (default 12).
## - REGION_ZOOM=16: the camera's distance (default each shot's own, else 16).
## - REGION_BEFORE=/abs/dir: a folder holding the "before" moods.json, flora.json, vistas.json and catalog.json (any
##   of them; a missing one keeps the game's). Shots are then named <out>_<shot>_<hour>_before.png and _after.png.
## - REGION_WEATHER=rain: the world's weather for every shot (default the new game's own).
## - REGION_PLACES=ghakis_lair,amber_deep: shoot these places (at their own spawn) instead of the region shots.
## - REGION_TILT=1: the camera tilted to the horizon (the ridges and landmarks past the edge), a shot each quarter turn
##   (<shot>_<hour>_t0 ... _t3).

## Each shot: the region's place, where the party stands (empty: the place's own spawn) and optionally the camera's
## distance and quarter turns.
const SHOTS := {
	"mists": {"loc": "into_the_mists_road", "cells": [[12, 15], [13, 15], [12, 16], [13, 14]]},
	"woods": {"loc": "road_forest"},
	"village": {"loc": "village_of_barovia"},
	"bonegrinder": {"loc": "old_bonegrinder_hill"},
	"tser_pool": {"loc": "tser_pool"},
	"falls": {"loc": "tser_falls"},
	"crossroads": {"loc": "svalich_crossroads"},
	"vallaki": {"loc": "vallaki"},
	"lake": {"loc": "lake_zarovich", "zoom": 18.0},
	"winery": {"loc": "wizard_of_wines"},
	"yester": {"loc": "yester_hill"},
	"krezk": {"loc": "krezk"},
	"krezk_square": {"loc": "krezk", "cells": [[16, 14], [17, 14], [16, 15], [17, 15]]},
	"white_sun": {"loc": "krezk_pool_of_the_white_sun"},
	"abbey": {"loc": "abbey_of_st_markovia"},
	"argynvostholt": {"loc": "argynvostholt"},
	"den": {"loc": "werewolf_den"},
	"berez": {"loc": "berez"},
	"moor": {"loc": "barrow_moor"},
	"baratok": {"loc": "mount_baratok"},
	"ghakis": {"loc": "ghakis_shoulder"},
	"tsolenka": {"loc": "tsolenka_pass"},
	"amber": {"loc": "amber_temple_entrance"},
	"castle": {"loc": "castle_ravenloft_gates", "zoom": 18.0},
}
const PARTY: Array[String] = ["godrick_pendlebrook", "liriel_dawnsong", "thistle", "ratatoille"]
## The look data a "before" folder can stand in for, by file name.
const LOOK_FILES: Array[String] = ["moods.json", "flora.json", "vistas.json", "catalog.json"]

var view: LocationView = null


func _ready() -> void:
	InputActions.ensure()
	var weather := OS.get_environment("REGION_WEATHER")
	if weather != "":
		# Every climate has only that weather, for this run.
		var d := Weather.data().duplicate(true)
		var climates := {}
		for c: String in d.get("climates", {}) as Dictionary:
			climates[c] = {weather: 1}
		d["climates"] = climates
		Weather.use(d)


func capture_shots(tool: Node, out: String) -> void:
	var only := OS.get_environment("REGION_SHOTS").split(",", false)
	var hours := OS.get_environment("REGION_HOURS").split(",", false)
	if hours.is_empty():
		hours = PackedStringArray(["12"])
	var before := OS.get_environment("REGION_BEFORE")
	var shots := SHOTS.duplicate()
	var places := OS.get_environment("REGION_PLACES").split(",", false)
	if not places.is_empty():
		shots = {}
		for p: String in places:
			shots[p] = {"loc": p}
	for id: String in shots:
		if not only.is_empty() and not id in only:
			continue
		for h: String in hours:
			var name := "%s_%s_%02d" % [out, id, int(h)]
			if before != "":
				_use_look(before)
				await _shoot(tool, shots[id] as Dictionary, int(h), name + "_before.png")
				_use_look("")
				await _shoot(tool, shots[id] as Dictionary, int(h), name + "_after.png")
			else:
				_use_look("")
				await _shoot(tool, shots[id] as Dictionary, int(h), name + ".png")


func _shoot(tool: Node, shot: Dictionary, hour: int, path: String) -> void:
	_build(shot, hour)
	await tool.call("wait_frames", 45)
	print("region %s: mood %s, plants %s" % [path.get_file(), view.atmosphere.mood_id,
		Flora.set_for(view.atmosphere.mood_id)])
	if OS.get_environment("REGION_TILT") == "":
		tool.call("_shot", path)
		return
	# Looking out to the horizon, all the way round.
	view.rig.distance = view.rig.zoom_max
	view.rig.horizon = 1.0
	for turn in 4:
		view.rig.snap_to_target()
		await tool.call("wait_frames", 20)
		tool.call("_shot", path.trim_suffix(".png") + "_t%d.png" % turn)
		view.rig.rotate_step(1)


## The look data the next place is built with: the files in `dir` where it has them, else the game's own (an empty
## `dir`). The places already built are forgotten, so nothing is drawn from a build with the other data.
func _use_look(dir: String) -> void:
	var data := {}
	for f: String in LOOK_FILES:
		var p := dir.path_join(f)
		if dir != "" and FileAccess.file_exists(p):
			data[f] = JSON.parse_string(FileAccess.get_file_as_string(p)) as Dictionary
	Atmosphere._moods = data.get("moods.json", {}) as Dictionary
	Flora._config = data.get("flora.json", {}) as Dictionary
	Vista._config = data.get("vistas.json", {}) as Dictionary
	SetDressing._catalog = data.get("catalog.json", {}) as Dictionary
	AtmosphereLand._kept.clear()
	AtmosphereLand._kept_order.clear()
	GroundRelief._kept.clear()
	GroundRelief._kept_order.clear()


func _build(shot: Dictionary, hour: int) -> void:
	if view != null:
		view.queue_free()
		view = null
	GameState.reset()
	for pid: String in PARTY:
		var ch := Pregens.build(pid, 3)
		ch.finish_long_rest()
		GameState.story.party.append(ch)
	var st := GameState.story
	st.minute_of_day = hour * 60
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
	var zoom := float(OS.get_environment("REGION_ZOOM")) if OS.get_environment("REGION_ZOOM") != "" \
		else float(shot.get("zoom", 16.0))
	view.rig.zoom_max = maxf(view.rig.zoom_max, zoom)
	view.rig.distance = zoom
	view.rig.rotate_step(int(shot.get("turns", 0)))
	view.rig.snap_to_target()
