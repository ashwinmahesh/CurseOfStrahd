extends Node
## How long a cutscene's opening frames take (Functional QA FN-20, 2026-10-09: some stills froze the screen for up to
## 2.3 s as they opened). Opens each still in a CutscenePlayer, as a place's trigger does, and records the worst frame
## over its first SECONDS, then the next. Run it in a window that never shows, so the still is really uploaded:
##   tools/godot --path . --resolution 1920x1080 --position 100000,100000 res://tools/perf/cutscene_open.tscn -- \
##       [--ids=godfrey_rests,strahd_mist_flight] [--out=/abs/report.json]
## Prints one line per still and the worst of them.

const SECONDS := 1.5
const DEFAULT := ["godfrey_rests", "strahd_mist_flight", "marina_statue", "sq_rag_queen", "vr_tower", "godfrey_steps"]

var _last := 0
var _worst := 0.0


func _ready() -> void:
	var args := {}
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--") and a.contains("="):
			args[a.substr(2, a.find("=") - 2)] = a.get_slice("=", 1)
	var ids: Array = str(args.get("ids", "")).split(",", false) if args.has("ids") else DEFAULT
	await get_tree().process_frame
	await get_tree().create_timer(1.0).timeout   # the window and the renderer settle first
	var report := {}
	for id: Variant in ids:
		var c := Cutscenes.get_cutscene(str(id))
		if c.is_empty():
			print("CUTSCENE_OPEN %s: no such cutscene" % id)
			continue
		var player := CutscenePlayer.new()
		add_child(player)
		var st := StoryState.new()
		for f: String in _flags_for(c):
			st.set_flag(f, true)
		_worst = 0.0
		_last = Time.get_ticks_usec()
		var t0 := Time.get_ticks_msec()
		var call := Time.get_ticks_usec()
		var played := player.play(str(id), ["A caption."] as Array[String], st)
		var call_ms := (Time.get_ticks_usec() - call) / 1000.0   # the main thread's own wait as it opens
		if not played:
			# A still whose takes all need the story somewhere: open its first take's picture directly.
			player.view = CutsceneView.new()
			player.add_child(player.view)
			player.view.show_image(Cutscenes.ART % str(((c["images"] as Array)[0] as Dictionary)["image"]))
		while Time.get_ticks_msec() - t0 < SECONDS * 1000.0:
			await get_tree().process_frame
			var now := Time.get_ticks_usec()
			_worst = maxf(_worst, (now - _last) / 1000.0)
			_last = now
		report[str(id)] = {"worst_frame_ms": snappedf(_worst, 0.1), "open_call_ms": snappedf(call_ms, 0.1)}
		print("CUTSCENE_OPEN %s: worst frame %.0f ms, opening call %.1f ms" % [id, _worst, call_ms])
		player.queue_free()
		get_tree().paused = false
		await get_tree().process_frame
	var worst := 0.0
	for k: String in report:
		worst = maxf(worst, float((report[k] as Dictionary)["worst_frame_ms"]))
	print("CUTSCENE_OPEN worst of all: %.0f ms" % worst)
	if args.has("out"):
		var f := FileAccess.open(str(args["out"]), FileAccess.WRITE)
		f.store_string(JSON.stringify(report, "\t"))
		f.close()
	get_tree().quit()


## The flags a still's first take names in its `when`, so the story picks it (a rough guess: every `flag.x` set).
static func _flags_for(c: Dictionary) -> Array[String]:
	var out: Array[String] = []
	var re := RegEx.create_from_string("flag\\.([a-z0-9_]+)")
	for m in re.search_all(str(((c.get("images", []) as Array)[0] as Dictionary).get("when", ""))):
		out.append(m.get_string(1))
	return out
