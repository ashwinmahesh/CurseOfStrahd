extends Node3D
## Crags QA (the vault's Natural Maps Plan, N5): the places with crags shot from the play camera at the party's spawn
## from each of the four headings, tilted to the horizon and whole, as natural_audit does for the default heading, and a
## table of the squares that matter (exits, spawns, finds, fights) whose view from the play camera a crag blocks at each
## heading, against what the old rock columns blocked. Not part of the game.
##   make capture SCENE=res://tools/capture/crags_views.tscn NAME=crags/x FRAMES=10
## Environment: CV_LOCS=a,b (default the places with crags), CV_YAWS=0,1,2,3 (rotate steps: 0 from the SW, 1 from the
## SE, 2 from the NE, 3 from the NW), CV_SHOTS=play,tilt,whole (default all three), CV_HOUR=12, CV_AT=x,z (the play and
## tilt shots look at this square instead of the spawn; with one place only), CV_NOSHOTS=1 (only the table),
## CV_NOCLIFFS=1 (the cliffs and drops as the board drew them before CliffFace), CV_AIM=1 (each place's play and tilt shots look at its AIMS square, where the rock stands, instead of the spawn),
## CV_DIST=16 (the play shots' camera distance; 8 for a close look at a foot), CV_WEATHER=overcast (the world's weather for the whole run, as natural_audit's NA_WEATHER does), CV_BEFORE=1 (the
## places drawn with their old rock columns, and the quarry and camp with their old stone yard walls, for the before
## shots), CV_TIME=n (builds each place n times first and
## prints the median build time: view and board, as the game builds a place on arrival).
## Shots: <out>_<loc>_y<yaw>_play.png, _tilt.png, _whole.png (one per place).

const PARTY: Array[String] = ["godrick_pendlebrook", "liriel_dawnsong", "thistle", "ratatoille"]
## The places with crags (catalog place_looks `rock_shape`).
const PLACES: Array[String] = ["mount_baratok", "mount_baratok_trail", "tsolenka_pass", "werewolf_den",
	"castle_ravenloft_gates", "amber_temple_road", "ghakis_quarry", "amber_road_camp"]
## The old rock columns' average height, and at the map's edge.
const COLUMN := 2.2
const COLUMN_EDGE := 3.2
## How tall a token stands, and how far the camera sits when the table looks from it.
const HEAD := 1.0
const PLAY_DISTANCE := 16.0
## Where the rock stands in each place: the square CV_AIM looks at.
const AIMS := {"mount_baratok": Vector2i(18, 9), "mount_baratok_trail": Vector2i(22, 12), "tsolenka_pass": Vector2i(33, 13),
	"werewolf_den": Vector2i(21, 4), "amber_temple_road": Vector2i(10, 3), "ghakis_quarry": Vector2i(5, 3),
	"amber_road_camp": Vector2i(12, 3), "castle_ravenloft_gates": Vector2i(3, 22),
	"mountain_pass": Vector2i(8, 9), "road_ravine": Vector2i(10, 8), "frozen_tarn": Vector2i(12, 5),
	"van_richtens_tower": Vector2i(20, 12), "lake_inlet": Vector2i(16, 10), "lake_zarovich": Vector2i(15, 10), "tser_pool": Vector2i(16, 10),
	"krezk_pool_of_the_white_sun": Vector2i(10, 8), "road_ravine_w": Vector2i(10, 9),
	"lake_zarovich_trail": Vector2i(15, 12), "old_bonegrinder_track": Vector2i(15, 4), "yester_hill": Vector2i(12, 11)}


var view: LocationView = null


func _ready() -> void:
	InputActions.ensure()
	var weather := OS.get_environment("CV_WEATHER") if OS.get_environment("CV_WEATHER") != "" else "overcast"
	# Every climate has only that weather, for this run.
	var d := Weather.data().duplicate(true)
	var climates := {}
	for c: String in d.get("climates", {}) as Dictionary:
		climates[c] = {weather: 1}
	d["climates"] = climates
	Weather.use(d)
	CliffFace.off = OS.get_environment("CV_NOCLIFFS") != ""
	if OS.get_environment("CV_BEFORE") != "":
		# The catalog is read once and kept: take `rock_shape` out of its place looks and the columns come back.
		for id: String in (SetDressing.catalog().get("place_looks", {}) as Dictionary).keys():
			if id in ["ghakis_quarry", "amber_road_camp"]:
				(SetDressing.catalog()["place_looks"] as Dictionary).erase(id)
			else:
				((SetDressing.catalog()["place_looks"] as Dictionary)[id] as Dictionary).erase("rock_shape")


func capture_shots(tool: Node, out: String) -> void:
	var ids: Array[String] = PLACES.duplicate()
	if OS.get_environment("CV_LOCS") != "":
		ids.assign(OS.get_environment("CV_LOCS").split(",", false))
	var shots := OS.get_environment("CV_SHOTS").split(",", false)
	if shots.is_empty():
		shots = PackedStringArray(["play", "tilt", "whole"])
	var yaws: Array[int] = []
	for y in (OS.get_environment("CV_YAWS") if OS.get_environment("CV_YAWS") != "" else "0,1,2,3").split(",", false):
		yaws.append(int(y))
	var hour := int(OS.get_environment("CV_HOUR")) if OS.get_environment("CV_HOUR") != "" else 12
	for id in ids:
		var runs := int(OS.get_environment("CV_TIME")) if OS.get_environment("CV_TIME") != "" else 0
		if runs > 0:
			var ms: Array[float] = []
			for r in runs:
				var t0 := Time.get_ticks_usec()
				_build(id, hour)
				ms.append((Time.get_ticks_usec() - t0) / 1000.0)
				if r == runs - 1 and view.board.cliffs != null:
					CliffFace._kept.clear()   # a cold plan, not the kept one
					var tc := Time.get_ticks_usec()
					var cf := CliffFace.plan(view.board)
					var tp := Time.get_ticks_usec()
					var made := 0
					for z in view.grid.depth:
						for x in view.grid.width:
							var c := Vector2i(x, z)
							if cf.ground_mesh(c) != null:
								made += 1
							if cf.rock_mesh(c) != null:
								made += 1
					var tm := Time.get_ticks_usec()
					print("CLIFFS_PLAN %s: plan %.0f ms (%s), %d sides, %d meshes %.0f ms" % [id, (tp - tc) / 1000.0, CliffFace.plan_ms, cf.side_count(), made, (tm - tp) / 1000.0])
				if r == runs - 1 and view.board.crags != null:
					var look := (SetDressing.catalog().get("place_looks", {}) as Dictionary).get(id, {}) as Dictionary
					Crags._kept.clear()   # a cold plan, not the kept one
					var t1 := Time.get_ticks_usec()
					var k := Crags.plan(view.board, view.board.crags.cells, look)
					var t2 := Time.get_ticks_usec()
					var mat := StandardMaterial3D.new()
					for c: Vector2i in k.cells:
						k.piece(c, mat).free()
					var t3 := Time.get_ticks_usec()
					# What the land past the edge asks of the rock (N8): every corner of the land, as AtmosphereLand._terrain does.
					var reach := int(AtmosphereLand.REACH)
					var t4 := Time.get_ticks_usec()
					var asked := 0
					for j in view.grid.depth + 2 * reach + 1:
						for i in view.grid.width + 2 * reach + 1:
							k.beyond_edge(Vector2(i - reach, j - reach))
							asked += 1
					var t5 := Time.get_ticks_usec()
					print("CRAGS_BEYOND %s: %d corners asked %.0f ms (%s)" % [id, asked, (t5 - t4) / 1000.0, view.atmosphere.land.build_ms])
					print("CRAGS_PLAN %s: plan %.0f ms (%s), %d pieces %.0f ms" % [id, (t2 - t1) / 1000.0, Crags.plan_ms, k.cells.size(), (t3 - t2) / 1000.0])
				view.queue_free()
				view = null
				await tool.call("wait_frames", 3)
			var cold := ms[0]
			ms.sort()
			print("CRAGS_BUILD %s: first %.0f ms, median %.0f ms over %d builds (%s)" % [id, cold, ms[floori(ms.size() * 0.5)], runs, ", ".join(ms.map(func(v: float) -> String: return "%.0f" % v))])
		_build(id, hour)
		await tool.call("wait_frames", 30)
		if view.board.cliffs != null:
			print("CLIFFS_COVERAGE %s: %s sides %d" % [id, view.board.cliffs.coverage(), view.board.cliffs.side_count()])
		if view.board.crags != null:
			var top := 0.0
			for c: Vector2i in view.board.crags.cells:
				top = maxf(top, view.board.crags.top_of(c))
			print("CRAGS_CELLS %s: %d rock squares, highest %.1f, %d boulders" % [id, view.board.crags.cells.size(), top, view.board.crags.boulders().size()])
		var rig := view.rig
		var at := view.board.cell_center(_spawn())
		if OS.get_environment("CV_AIM") != "" and AIMS.has(id):
			at = view.board.cell_center(AIMS[id] as Vector2i)
		if OS.get_environment("CV_AT") != "":
			var a := OS.get_environment("CV_AT").split(",")
			at = view.board.cell_center(Vector2i(int(a[0]), int(a[1])))
		var steps := 0
		if "whole" in shots and OS.get_environment("CV_NOSHOTS") == "":
			rig.horizon = 0.0
			rig.distance = maxf(view.grid.width, view.grid.depth) * 1.05
			rig.global_position = Vector3(view.grid.width / 2.0, 0, view.grid.depth / 2.0)
			rig.snap_to_target()
			await tool.call("wait_frames", 12)
			tool.call("_shot", "%s_%s_whole.png" % [out, id])
		for yaw in yaws:
			rig.rotate_step(yaw - steps)
			steps = yaw
			if "play" in shots and OS.get_environment("CV_NOSHOTS") == "":
				rig.horizon = 0.0
				rig.distance = float(OS.get_environment("CV_DIST")) if OS.get_environment("CV_DIST") != "" else PLAY_DISTANCE
				rig.global_position = at
				rig.snap_to_target()
				await tool.call("wait_frames", 12)
				tool.call("_shot", "%s_%s_y%d_play.png" % [out, id, yaw])
			if "tilt" in shots and OS.get_environment("CV_NOSHOTS") == "":
				rig.horizon = 1.0
				rig.distance = 22.0
				rig.global_position = at
				rig.snap_to_target()
				await tool.call("wait_frames", 12)
				tool.call("_shot", "%s_%s_y%d_tilt.png" % [out, id, yaw])
			_hidden_table(id, yaw)
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


## The squares a player has to see: exits, spawns, finds (containers, props), people and where foes start.
func _key_squares() -> Dictionary:
	var d := Compendium.shared().get_entry("locations", view.loc_id) as Dictionary
	var out := {}
	for e: Dictionary in d.get("exits", []):
		out[_cell(e["cell"])] = "exit %s" % e["id"]
	for k: String in d.get("spawns", {}):
		out[_cell(d["spawns"][k])] = "spawn %s" % k
	for key: String in ["containers", "props", "npcs"]:
		for p: Dictionary in d.get(key, []):
			if p.has("cell"):
				out[_cell(p["cell"])] = "%s %s" % [key.trim_suffix("s"), p.get("id", p.get("npc", "?"))]
	for e: Dictionary in d.get("encounters", []):
		for m: Dictionary in e.get("monsters", []):
			if m.has("cell"):
				out[_cell(m["cell"])] = "foe %s" % m.get("monster", "?")
	for c: Variant in d.get("foe_spots", []):
		out[_cell(c)] = "foe spot"
	return out


func _cell(v: Variant) -> Vector2i:
	var a := v as Array
	return Vector2i(int(a[0]), int(a[1]))


## For each key square: whether a crag (or, before, a rock column) stands between a token there and the play camera at
## heading `yaw`, ignoring the fade (the party stands elsewhere). Prints the squares a crag hides that the columns didn't,
## and the other way about.
func _hidden_table(id: String, yaw: int) -> void:
	var crags := view.board.crags
	if crags == null:
		return
	var rig := view.rig
	var now := 0
	var was := 0
	var worse: Array[String] = []
	var better := 0
	var keys := _key_squares()
	for c: Vector2i in keys:
		if not view.grid.in_bounds(c) or crags.cells.has(c):
			continue
		var from := view.board.cell_center(c)
		rig.horizon = 0.0
		rig.distance = PLAY_DISTANCE
		rig.global_position = from
		rig.snap_to_target()
		var cam := rig.camera.global_position
		var head := from + Vector3(0, HEAD, 0)
		var blocked_now := false
		var blocked_was := false
		var t := 0.03
		while t < 1.0:
			var p := head.lerp(cam, t)
			t += 0.004
			var sq := Vector2i(floori(p.x), floori(p.z))
			if sq == c:
				continue
			var g := view.board.ground_y(Vector2(p.x, p.z))
			if crags.cells.has(sq):
				if p.y < g + crags.top_at(p.x, p.z):
					blocked_now = true
				if p.y < g + (COLUMN_EDGE if sq.x == 0 or sq.y == 0 or sq.x == view.grid.width - 1 or sq.y == view.grid.depth - 1 else COLUMN):
					blocked_was = true
			elif view.grid.in_bounds(sq) and p.y < g + crags.top_at(p.x, p.z) - 0.02:
				blocked_now = true   # scree or a face reaching out over a walkable square
		now += 1 if blocked_now else 0
		was += 1 if blocked_was else 0
		if blocked_now and not blocked_was:
			worse.append("%s %s" % [c, keys[c]])
		elif blocked_was and not blocked_now:
			better += 1
	print("CRAGS_HIDDEN %s yaw %d: %d key squares, hidden now %d (columns hid %d, %d now clear); newly hidden: %s" % [
		id, yaw, keys.size(), now, was, better, ", ".join(worse) if not worse.is_empty() else "none"])
	# Put the camera back where the shots had it.
	rig.global_position = view.board.cell_center(_spawn())
