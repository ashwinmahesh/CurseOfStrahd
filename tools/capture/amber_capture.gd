extends Node3D
## The Amber Temple build's own shots and clips (Amber Temple Look Plan §9, "Pictures"): one place from the game's camera
## at a square, the party where the shot wants them, story flags set first, and a clip of the game's time running fast
## (so a five second breath of light, or a block flaring as a vestige speaks, fits in a couple of dozen frames). Not part
## of the game.
##   make capture SCENE=res://tools/capture/amber_capture.tscn NAME=amber-look/s3 FRAMES=10
## then, for a clip, python3 tools/capture/clip_gif.py <out.gif> <out>_<place>_<x>_<z> (its frames and times).
## Environment: AMBER_LOC=amber_temple_vault, AMBER_AT=19,24 (the square the camera looks at; several, split by |, each a
## shot), AMBER_ZOOM=9 (the camera's distance), AMBER_TURNS=1 (camera quarter turns), AMBER_PARTY=19,26|20,26 (the
## party's squares; empty: the place's own spawn), AMBER_FLAGS=amber_temple_sealed,... (story flags set first),
## AMBER_HOUR=12, AMBER_WINDOW=1 (keep the window round the party that walls and blocks open; off by default), AMBER_CLIP=24,0.5 (a clip at each square: that many frames, this many seconds of the game between them).

const PARTY: Array[String] = ["godrick_pendlebrook", "liriel_dawnsong", "thistle", "ratatoille"]
## How much faster than real time the game runs while a clip's frames are taken.
const CLIP_SPEED := 8.0

var view: LocationView = null


func _ready() -> void:
	InputActions.ensure()


func capture_shots(tool: Node, out: String) -> void:
	var loc_id := OS.get_environment("AMBER_LOC")
	if loc_id == "":
		push_error("AMBER_LOC names the place to shoot")
		return
	_build(loc_id)
	await tool.call("wait_frames", 30)
	var zoom := float(OS.get_environment("AMBER_ZOOM")) if OS.get_environment("AMBER_ZOOM") != "" else 9.0
	var rig := view.rig
	rig.follow = null
	rig.distance = zoom
	rig.rotate_step(int(OS.get_environment("AMBER_TURNS")))
	var spots := OS.get_environment("AMBER_AT").split("|", false)
	for spot: String in spots:
		var cell := Vector2i(int(spot.get_slice(",", 0)), int(spot.get_slice(",", 1)))
		rig.global_position = view.board.cell_center(cell)
		rig.snap_to_target()
		await tool.call("wait_frames", 12)
		var base := "%s_%s_%d_%d" % [out, loc_id, cell.x, cell.y]
		tool.call("_shot", base + ".png")
		if OS.get_environment("AMBER_CLIP") != "":
			var bits := OS.get_environment("AMBER_CLIP").split(",")
			await _clip(tool, base, int(bits[0]), float(bits[1]) if bits.size() > 1 else 0.5)
	view.queue_free()
	view = null


func _build(loc_id: String) -> void:
	GameState.reset()
	for pid: String in PARTY:
		var ch := Pregens.build(pid, 3)
		ch.finish_long_rest()
		GameState.story.party.append(ch)
	var st := GameState.story
	st.minute_of_day = (int(OS.get_environment("AMBER_HOUR")) if OS.get_environment("AMBER_HOUR") != "" else 12) * 60
	for flag: String in OS.get_environment("AMBER_FLAGS").split(",", false):
		st.set_flag(flag)
	var party := OS.get_environment("AMBER_PARTY").split("|", false)
	if not party.is_empty():
		st.location = loc_id
		st.visited[loc_id] = true
		for c: String in party:
			st.positions.append(Vector2i(int(c.get_slice(",", 0)), int(c.get_slice(",", 1))))
	view = LocationView.create(loc_id, st, Narrator.new(), Dice.roller, "" if not party.is_empty() else "default")
	add_child(view)
	view.update_daylight()
	if OS.get_environment("AMBER_WINDOW") != "1":
		# No window opened in the walls and blocks nearer the camera than the party (SeeThrough puts it where the camera
		# looks when nobody is followed): a shot of a block wants it whole.
		var see := view.find_child("SeeThrough", true, false)
		if see != null:
			see.queue_free()


## `frames` frames of the place, `seconds` of its time apart (the game runs CLIP_SPEED times fast between them):
## <base>_clip_000.png on, and <base>_clip.txt with each frame's time, which clip_gif.py turns into the GIF's frame lengths.
func _clip(tool: Node, base: String, frames: int, seconds: float) -> void:
	Engine.time_scale = CLIP_SPEED
	var between := maxi(1, int(round(seconds / CLIP_SPEED * 60.0)))
	var at := 0.0
	var times := PackedStringArray()
	for i in frames:
		for k in between:
			await get_tree().process_frame
			at += get_process_delta_time()
		times.append("%.4f" % at)
		tool.call("_shot", "%s_clip_%03d.png" % [base, i])
	Engine.time_scale = 1.0
	var f := FileAccess.open(base + "_clip.txt", FileAccess.WRITE)
	f.store_string("\n".join(times) + "\n")
	f.close()
