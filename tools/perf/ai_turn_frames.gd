extends Node
## Frame times through a fight's AI turns in the real game, in a window that never shows (FN-14: an enemy's plan froze
## the screen). Every side is played by the AI, as Functional QA's hitch tour did; each turn's worst frame is printed,
## and how many of its frames went by while its plan was made on the worker thread. Its own settings and saves.
##   tools/godot --path . --resolution 1920x1080 --position 100000,100000 res://tools/perf/ai_turn_frames.tscn -- \
##       --location=<id> --fight=<id> [--level=n] [--turns=n] [--aside=0|1]

const PARTY: Array[String] = ["ilse_varga", "hedda_ironvow", "silvain_aster", "tamsin_tealeaf"]

var _last := 0
var _ms := 0.0
var _frames: Array[float] = []


func _ready() -> void:
	var args := {}
	for a in OS.get_cmdline_user_args():
		var kv := a.trim_prefix("--").split("=", true, 1)
		args[kv[0]] = kv[1] if kv.size() > 1 else "1"
	SaveSystem.save_dir = "user://ai_turn_frames/%d/" % OS.get_process_id()
	DirAccess.make_dir_recursive_absolute(SaveSystem.save_dir)
	GameSettings.path = SaveSystem.save_dir.path_join("settings.cfg")
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	Engine.max_fps = 0
	get_tree().process_frame.connect(_on_frame)
	GameState.reset()
	var st := GameState.story
	for id in PARTY:
		var ch := Pregens.build(id, int(args.get("level", "8")))
		ch.finish_long_rest()
		st.party.append(ch)
	st.minute_of_day = 12 * 60
	var root := (load("res://scenes/game.tscn") as PackedScene).instantiate()
	add_child(root)
	await _secs(3.0)
	var loc := str(args.get("location", ""))
	root.call("enter_location", loc, "default")
	await _secs(4.0)
	var view := root.get("view") as LocationView
	if view == null or not view.start_encounter(str(args.get("fight", ""))):
		printerr("no fight %s at %s" % [args.get("fight", ""), loc])
		_done(1)
		return
	await _secs(3.0)
	var cv := view.combat_view
	cv.think_aside = str(args.get("aside", "1")) == "1"
	var e := cv.e
	for c in e.combatants:
		c.controller = &"ai"
	var want := int(args.get("turns", "8"))
	var turns := 0
	var who := e.current()
	var start := Time.get_ticks_msec()
	_frames.clear()
	var aside := 0
	var worst := 0.0
	print("AI turns in %s, plans %s" % [e.title, "on the worker thread" if cv.think_aside else "in line"])
	while turns < want and e.state == Encounter.State.ACTIVE and Time.get_ticks_msec() - start < 120000:
		await get_tree().process_frame
		worst = maxf(worst, _ms)
		if cv.get("_thinker") != null:
			aside += 1
		if e.pending != null:
			e.answer_reaction(false)
		if e.current() != who:
			print("  %-28s worst frame %6.1f ms, %3d frames planning aside" % [who.name(), worst, aside])
			turns += 1
			who = e.current()
			worst = 0.0
			aside = 0
	var over := _frames.filter(func(f: float) -> bool: return f > 100.0).size()
	_frames.sort()
	print("frames %d, over 100 ms %d, worst %.0f ms" % [_frames.size(), over, _frames[-1] if not _frames.is_empty() else 0.0])
	cv.finished.emit("victory")
	await _secs(1.0)
	_done(0)


func _on_frame() -> void:
	var now := Time.get_ticks_usec()
	_ms = (now - _last) / 1000.0 if _last > 0 else 0.0
	_last = now
	_frames.append(_ms)


func _secs(s: float) -> void:
	var t := Time.get_ticks_msec()
	while Time.get_ticks_msec() - t < int(s * 1000.0):
		await get_tree().process_frame


func _done(code: int) -> void:
	for f in DirAccess.get_files_at(SaveSystem.save_dir):
		DirAccess.remove_absolute(SaveSystem.save_dir.path_join(f))
	DirAccess.remove_absolute(SaveSystem.save_dir)
	DirAccess.remove_absolute("user://ai_turn_frames")   # only goes once no other run's folder is left in it
	get_tree().quit(code)
