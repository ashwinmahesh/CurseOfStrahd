extends Node
## The performance probe (P3): times loads (the data, the title, a new game, every move between places, saving and
## loading) and measures frame time, draw calls and memory in the heavy places, at 1080p in a window that never shows.
## Writes one JSON report; tools/perf/perf_run.py launches it and prints the summary.
## Args after --: --out=/abs/report.json [--frames=N] [--warm=N] [--passes=N]
## [--only=title,newgame,places,saveload,combat,transitions,fights,foemem,screens] [--screen=inventory] [--places=id,id] [--encounters=id,id]
## [--size=1920x1080] [--cover=1]

const PLACES := ["village_of_barovia", "vallaki", "castle_ravenloft_gates", "castle_ravenloft_main_floor",
	"castle_ravenloft_court", "castle_ravenloft_catacombs", "wizard_of_wines", "krezk", "argynvostholt", "berez",
	"death_house_ground", "tser_pool"]
## The big fight: the vineyard ambush (16 foes) against a level 7 party, every side played by the AI.
const FIGHT_PLACE := "wizard_of_wines"
const FIGHT := "vineyard_ambush"
const NIGHT := 22 * 60
## The effects phase: each of the Modern finish's costs switched off in turn, in a few heavy places (for W17's presets).
const EFFECT_PLACES := ["village_of_barovia@night", "vallaki@day", "castle_ravenloft_main_floor@day"]
const EFFECTS := ["msaa", "edge_aa", "ssr", "ssao", "ssil", "volumetric_fog", "glow", "dof", "sun_shadows", "lamp_shadows",
	"screen_pass", "lamps", "half_res", "metalfx_75", "all"]
const DAY := 12 * 60
## The transitions phase: the way a player goes, in one game from a new game's first place: out of doors and in, room
## to room, back the way they came, and on to another region. The first pass is a cold start; later ones go the same
## way again with what the first one left cached.
const ROUTE := ["village_of_barovia", "bildraths_mercantile", "village_of_barovia", "death_house_ground",
	"death_house_upper", "death_house_third", "death_house_upper", "death_house_ground", "village_of_barovia",
	"vallaki", "vallaki_blue_water_inn", "vallaki", "castle_ravenloft_gates", "castle_ravenloft_main_floor",
	"castle_ravenloft_court", "castle_ravenloft_main_floor"]
## A frame this slow reads as the game hanging; a move counts as stuck until the last such frame in the SETTLE_S after.
const STUCK_MS := 100.0
const SETTLE_S := 2.0

var frames := 240                    ## measured frames per sample
var warm := 90                       ## frames let pass before measuring (shaders compile, tweens settle)
var passes := 2
var pairs := 3                       ## on/off pairs per effect in the effects phase
var cycles := 10                     ## off/on switches per effect in the effects_fast phase
## The effects phases' list (--effects=a,b; default EFFECTS). A name that isn't one of EFFECTS is a class with a
## `static func set_enabled(on: bool)` (SpriteReflection), switched off through it: a new effect needs no line here.
var effects: Array = EFFECTS
var cover := false                   ## the transitions phase goes through the game's loading cover (--cover=1)
var report := {"samples": [], "loads": [], "memory": [], "transitions": [], "fights": [], "foe_memory": [], "screens": [],
	"meta": {}}
var _last_usec := 0
var _draw_start := 0
var _draw_ms := 0.0                 ## ms drawing since the last frame began
var _frame_draw_ms := 0.0           ## ms the frame that just ended spent drawing
var _rec: Array[Dictionary] = []     ## the frames of the sample being taken
var _recording := false
var _vp: RID


func _ready() -> void:
	var args := {}
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--") and a.contains("="):
			args[a.substr(2, a.find("=") - 2)] = a.get_slice("=", 1)
	frames = int(args.get("frames", frames))
	warm = int(args.get("warm", warm))
	passes = int(args.get("passes", passes))
	pairs = int(args.get("pairs", pairs))
	cycles = int(args.get("cycles", cycles))
	if str(args.get("effects", "")) != "":
		effects = Array(str(args["effects"]).split(","))
	cover = str(args.get("cover", "")) == "1"
	fight_settle_s = float(args.get("settle", fight_settle_s))
	if cover:
		# The cover only runs with the interface's motion on, which a run with --out= (and a headless one) turns off.
		UiMotion._checked = true
		UiMotion.reduced = false
		PlacePreload.headless_too = true
	var only := str(args.get("only", "title,newgame,places,saveload,combat,effects")).split(",")
	var places: Array = PLACES if str(args.get("places", "")) == "" else Array(str(args["places"]).split(","))
	var out := str(args.get("out", "user://perf_report.json"))
	# Saves and settings in a folder of this run's own, never the player's.
	SaveSystem.save_dir = "user://perf_saves/%d/" % OS.get_process_id()
	GameSettings.path = SaveSystem.save_dir.path_join("settings.cfg")
	Dice.deterministic = true
	var win := get_window()
	win.borderless = true
	win.position = Vector2i(-20000, -20000)
	var size := str(args.get("size", "1920x1080")).split("x")
	win.size = Vector2i(int(size[0]), int(size[1]))
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	Engine.max_fps = 0
	_vp = get_viewport().get_viewport_rid()
	RenderingServer.viewport_set_measure_render_time(_vp, true)
	get_tree().process_frame.connect(_on_frame)
	RenderingServer.frame_pre_draw.connect(_pre_draw)
	RenderingServer.frame_post_draw.connect(_post_draw)
	report["meta"] = {"engine_ready_ms": Time.get_ticks_msec(), "size": win.size, "frames": frames, "warm": warm,
		"passes": passes, "pid": OS.get_process_id(), "adapter": RenderingServer.get_video_adapter_name(),
		"api": RenderingServer.get_video_adapter_api_version(), "renderer": ProjectSettings.get_setting("rendering/renderer/rendering_method")}
	await _wait(5)
	_data_load()
	if args.has("preload"):
		await _preload_game(str(args["preload"]))
	for p in passes:
		if "title" in only:
			await _title(p)
		if "newgame" in only:
			await _new_game(p)
		if "places" in only:
			await _places(p, places)
		if "saveload" in only:
			await _save_load(p)
		if "combat" in only:
			await _combat(p)
		if "effects" in only:
			await _effects(p)
		if "effects_fast" in only:
			await _effects_fast(p)
		if "presets" in only:
			await _presets(p)
		if "transitions" in only:
			await _transitions(p)
		if "screens" in only:
			await _screens(p, SCREEN_PLACES if str(args.get("places", "")) == "" else places, str(args.get("screen", "inventory")))
		if "foemem" in only:
			await _foe_memory(p, FOE_MEM_PLACES if str(args.get("places", "")) == "" else places)
		if "fights" in only:
			await _fights(p, [] if str(args.get("encounters", "")) == "" else Array(str(args["encounters"]).split(",")))
	if "memory" in only:
		await _memory(places)
	var f := FileAccess.open(out, FileAccess.WRITE)
	f.store_string(JSON.stringify(report, "\t"))
	f.close()
	_clean_saves()
	print("PERF done ", out)
	get_tree().quit()


# --- Phases ---------------------------------------------------------------------------------------

## The rules data (data/*.json through Compendium): read again from disk, warm file cache.
func _data_load() -> void:
	_phase("load: data")
	for i in 3:
		Compendium.release()
		var t := Time.get_ticks_usec()
		Compendium.shared()
		_load("data_load", "compendium", t)
	var t2 := Time.get_ticks_usec()
	var json := 0
	for folder: String in Compendium.FOLDERS:
		json += Compendium.shared().table(folder).size()
	report["meta"]["data_entries"] = json
	_load("data_load", "count", t2)


## What the title screen could do while the player picks: load (and compile the scripts of) the game scene on a
## worker thread. `how` is "thread" or "main" (the same load on the main thread, for comparison).
func _preload_game(how: String) -> void:
	_phase("load: preload game scene")
	var t := Time.get_ticks_usec()
	if how == "main":
		load("res://scenes/game.tscn")
		_load("preload", "game.tscn (main thread)", t)
		return
	ResourceLoader.load_threaded_request("res://scenes/game.tscn", "", true)
	var frames_ := 0
	var worst := 0.0
	var last := Time.get_ticks_usec()
	while ResourceLoader.load_threaded_get_status("res://scenes/game.tscn") == ResourceLoader.THREAD_LOAD_IN_PROGRESS:
		await get_tree().process_frame
		frames_ += 1
		var now := Time.get_ticks_usec()
		worst = maxf(worst, (now - last) / 1000.0)
		last = now
	ResourceLoader.load_threaded_get("res://scenes/game.tscn")
	var row := _load("preload", "game.tscn (worker thread)", t)
	row["frames"] = frames_
	row["worst_frame_ms"] = worst


func _title(p: int) -> void:
	_phase("load: title")
	var t := Time.get_ticks_usec()
	var menu := (load("res://scenes/main_menu.tscn") as PackedScene).instantiate()
	add_child(menu)
	var sync := Time.get_ticks_usec()
	await _wait(1)
	_load("title", "title", t, sync)
	await _sample("title", "title", p)
	menu.queue_free()
	await _wait(2)


func _new_game(p: int) -> void:
	_phase("load: new game")
	GameState.reset()
	var t := Time.get_ticks_usec()
	var root := (load("res://scenes/game.tscn") as PackedScene).instantiate()
	add_child(root)
	var sync := Time.get_ticks_usec()
	await _wait(1)
	_load("new_game", str(root.get("view").get("loc_id")), t, sync)
	await _sample("place", "into_the_mists_road (new game)", p)
	root.queue_free()
	await _wait(2)


## Every move: the time inside enter_location, to the first frame drawn, and the worst frame of the next second.
func _places(p: int, places: Array) -> void:
	var root := await _story_root(5)
	for id: Variant in places:
		var where := str(id)
		if not Compendium.shared().has("locations", where):
			continue
		var st := GameState.story
		st.minute_of_day = DAY
		var t := Time.get_ticks_usec()
		_phase("move: " + where)
		root.call("enter_location", where, "default")
		var sync := Time.get_ticks_usec()
		_close_popups(root)
		await _wait(1)
		var row := _load("move", where, t, sync)
		row["hitch_ms"] = await _worst_frame(60)
		var outdoors := bool(((root.get("view").get("loc") as Dictionary)["map"] as Dictionary).get("outdoors", false))
		_close_popups(root)
		await _sample("place", where + (" day" if outdoors else ""), p)
		if outdoors:
			st.minute_of_day = NIGHT
			root.call("_refresh")
			await _sample("place", where + " night", p)
	root.queue_free()
	await _wait(2)


func _save_load(p: int) -> void:
	var root := await _story_root(5)
	_phase("load: save and load")
	root.call("enter_location", "vallaki", "default")
	_close_popups(root)
	await _wait(10)
	for i in 3:
		var t := Time.get_ticks_usec()
		SaveSystem.save("perf")
		_load("save", "vallaki", t)
	var size := FileAccess.get_file_as_bytes(SaveSystem.slot_path("perf")).size()
	report["meta"]["save_bytes"] = size
	for i in 3:
		var t := Time.get_ticks_usec()
		SaveSystem.load_slot("perf")
		_load("load_state", "vallaki", t)
	var t2 := Time.get_ticks_usec()
	SaveSystem.list_slots()
	_load("list_slots", "%d slots" % DirAccess.get_files_at(SaveSystem.save_dir).size(), t2)
	root.queue_free()
	await _wait(2)
	# A full load: the save read, the game scene built and the place drawn (what Load and Continue do).
	var t3 := Time.get_ticks_usec()
	SaveSystem.load_slot("perf")
	var root2 := (load("res://scenes/game.tscn") as PackedScene).instantiate()
	add_child(root2)
	var sync := Time.get_ticks_usec()
	await _wait(1)
	_load("load_game", "vallaki", t3, sync)
	root2.queue_free()
	await _wait(2)


## How long each change of place keeps the screen stuck (the loading lane): a new game's first place, then ROUTE.
## With --cover=1 each change goes the way the game makes it, behind the black or the loading card (game_root's
## `_covered`, motion on), and the run also times how soon the cover is up and when the place is ready under it.
func _transitions(p: int) -> void:
	_phase("transition: new game")
	GameState.reset()
	var st := GameState.story
	for id: String in ["godrick_pendlebrook", "liriel_dawnsong", "thistle", "ratatoille", "wren_featherfoot", "kip_smudgewick"]:
		var ch := Pregens.build(id, 5)
		ch.finish_long_rest()
		if st.party.size() < StoryState.PARTY_CAP:
			st.party.append(ch)
		else:
			st.bench.append(ch)
	var root := (load("res://scenes/game.tscn") as PackedScene).instantiate()
	root.set("autosaves", true)   # as in play: arriving somewhere writes the autosave
	await _timed_move(p, root, "new game", "", true, func() -> void: add_child(root))
	var from := str(root.get("view").get("loc_id"))
	report["transitions"][-1]["to"] = from
	var visited := {from: true}
	for id: String in ROUTE:
		st.minute_of_day = DAY
		_phase("transition: %s -> %s" % [from, id])
		var change := func() -> void: root.call("enter_location", id, "default")
		if cover:
			change = func() -> void: root.call("_covered", id, Callable(root, "enter_location").bind(id, "default"))
		await _timed_move(p, root, from, id, not visited.has(id), change)
		visited[id] = true
		from = id
	root.queue_free()
	await _wait(2)


## How each fight's first moments go (the loading lane, after Functional QA's hitch tour of 2026-10-09): every
## encounter in the data (or `only`), each in its own place entered fresh and left a second (--settle) to settle, as a
## party walks up to a fight. `call` is the start of the fight (the foes' figures built, CombatView begun), `first` the next frame
## drawn, `worst` the worst frame in the second after, with how many were over STUCK_MS.
## The screens phase (Functional QA's FN-23): places where the first inventory opened with a stutter, and two without.
const SCREEN_PLACES := ["into_the_mists_road", "death_house_third", "old_bonegrinder_loft", "village_of_barovia",
	"amber_temple_faceless_god", "castle_ravenloft_catacombs_strahd", "castle_ravenloft_chapel", "vallaki"]
## The foemem phase: the places holding the most foes to come, and a small room holding none to stop in between.
const FOE_MEM_PLACES := ["village_of_barovia", "lake_zarovich", "vallaki", "castle_ravenloft_larders_dungeon",
	"castle_ravenloft_court", "castle_ravenloft_main_floor", "castle_ravenloft_catacombs"]
const FOE_MEM_NEUTRAL := "berez_marinas_monument"
var fight_settle_s := 1.0           ## --settle=seconds: how long a place is left before its fight starts


func _fights(p: int, only: Array) -> void:
	var root := await _story_root(5)
	var ids: Array = Compendium.shared().table("locations").keys()
	ids.sort()
	for loc_id: Variant in ids:
		var seen := {}
		for en: Variant in Compendium.shared().get_entry("locations", str(loc_id)).get("encounters", []):
			var eid := str((en as Dictionary)["id"])
			if seen.has(eid) or (not only.is_empty() and not eid in only):
				continue
			seen[eid] = true
			GameState.story.minute_of_day = DAY
			_phase("fight arrive: %s for %s" % [loc_id, eid])
			root.call("enter_location", str(loc_id), "default")
			_close_popups(root)
			await get_tree().create_timer(fight_settle_s).timeout
			_close_popups(root)
			var view := root.get("view") as LocationView
			_phase("fight: " + eid)
			var t0 := Time.get_ticks_usec()
			var started := view.start_encounter(eid)
			var call := (Time.get_ticks_usec() - t0) / 1000.0
			await get_tree().process_frame
			var first := (Time.get_ticks_usec() - t0) / 1000.0
			var last := Time.get_ticks_usec()
			var worst := 0.0
			var slow := 0
			while Time.get_ticks_usec() - t0 < 1000000:
				await get_tree().process_frame
				var now := Time.get_ticks_usec()
				var ms := (now - last) / 1000.0
				worst = maxf(worst, ms)
				if ms > STUCK_MS:
					slow += 1
				last = now
			var row := {"pass": p, "location": str(loc_id), "encounter": eid, "started": started, "call_ms": call,
				"first_frame_ms": first, "worst_after_ms": worst, "slow_after": slow, "load": _loadavg()}
			report["fights"].append(row)
			print("PERF fight %d %-30s %-34s %s call %5.0f | first frame %5.0f | worst after %5.0f (%d slow)" % [p,
				str(loc_id), eid, "     " if started else "(not started)", call, first, worst, slow])
	root.queue_free()
	await _wait(2)


## How a full-screen panel opens (the loading lane, FN-23): in each place (with --cover=1 reached through the loading
## cover, motion on, as in play), the
## panel (--screen=inventory by default) is opened three times; for each, the call that builds it and the next eight
## frames, each with its time spent drawing.
func _screens(p: int, places: Array, kind: String) -> void:
	var root := await _story_root(7)
	for id: Variant in places:
		GameState.story.minute_of_day = DAY
		if cover:
			root.call("_covered", str(id), Callable(root, "enter_location").bind(str(id), "default"))
			var t := Time.get_ticks_msec()
			while (bool(root.get("moving")) or root.get("view") == null) and Time.get_ticks_msec() - t < 30000:
				await get_tree().process_frame
		else:
			root.call("enter_location", str(id), "default")
		_close_popups(root)
		await get_tree().create_timer(2.0).timeout
		_close_popups(root)
		root.call("close_screen")
		get_tree().paused = false
		await _wait(30)
		for n in 3:
			_phase("screen %s %d: %s" % [kind, n + 1, id])
			var t0 := Time.get_ticks_usec()
			root.call("open_screen", kind, 0)
			var call_ms := (Time.get_ticks_usec() - t0) / 1000.0
			var frames_: Array = []
			var last := Time.get_ticks_usec()
			var compiled := _pipelines()
			for i in 8:
				await get_tree().process_frame
				var now := Time.get_ticks_usec()
				var c := _pipelines()
				var new_ones: Array = []
				for k in c.size():
					new_ones.append(c[k] - compiled[k])
				compiled = c
				frames_.append([snappedf((now - last) / 1000.0, 0.1), snappedf(_frame_draw_ms, 0.1), new_ones])
				last = now
			var worst := 0.0
			for f: Array in frames_:
				worst = maxf(worst, float(f[0]))
			report["screens"].append({"pass": p, "place": str(id), "screen": kind, "open": n + 1, "call_ms": call_ms,
				"worst_ms": worst, "frames": frames_})
			print("PERF screen %d %-34s %s %d call %6.1f | worst frame %6.1f | frames (ms, draw) %s" % [p, str(id), kind, n + 1,
				call_ms, worst, str(frames_)])
			_phase("screen closed: %s" % id)
			await get_tree().create_timer(0.4).timeout
			root.call("close_screen")
			await get_tree().create_timer(0.4).timeout
	root.queue_free()
	await _wait(2)


## Pipelines the renderer has compiled so far, by what asked: [canvas, mesh, surface, draw, specialization].
static func _pipelines() -> Array[int]:
	return [RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_PIPELINE_COMPILATIONS_CANVAS),
		RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_PIPELINE_COMPILATIONS_MESH),
		RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_PIPELINE_COMPILATIONS_SURFACE),
		RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_PIPELINE_COMPILATIONS_DRAW),
		RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_PIPELINE_COMPILATIONS_SPECIALIZATION)]


## What holding a place's foes costs (the loading lane): in each place, the video and texture memory once the foes of
## its fights still to come are read (PlacePreload.foes_mode "when", "possible", "all") against none ("off"), each from
## a fresh arrival after a stop in a small room that has no fights; and how long the threads took to read them.
func _foe_memory(p: int, places: Array) -> void:
	var root := await _story_root(5)
	for id: Variant in places:
		for mode: String in ["off", "when", "possible", "all"]:
			PlacePreload.foes_mode = "off"
			root.call("enter_location", FOE_MEM_NEUTRAL, "default")
			_close_popups(root)
			await _wait(30)
			PlacePreload.foes_mode = mode
			root.call("enter_location", str(id), "default")
			_close_popups(root)
			var kept := (root.get("view") as Node).get_node_or_null("FoeSheets")
			var t0 := Time.get_ticks_msec()
			while kept != null and not bool(kept.get("done")) and Time.get_ticks_msec() - t0 < 10000:
				await get_tree().process_frame
			var read_ms := Time.get_ticks_msec() - t0
			await _wait(30)
			var row := {"pass": p, "place": str(id), "mode": mode,
				"files": (kept.get("pre") as PlacePreload).paths.size() if kept != null else 0, "read_ms": read_ms,
				"video_mb": RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_VIDEO_MEM_USED) / 1048576.0,
				"texture_mb": RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TEXTURE_MEM_USED) / 1048576.0}
			report["foe_memory"].append(row)
			print("PERF foemem %-34s %-4s %3d files read in %5d ms | video %6.0f MB | textures %6.0f MB" % [str(id), mode,
				row["files"], read_ms, row["video_mb"], row["texture_mb"]])
	PlacePreload.foes_mode = "possible"
	root.queue_free()
	await _wait(2)


## Times one change of place (`change`), from the moment it's asked for: `block` is the longest frame until the place
## is ready (the build), `first` when the next frame is drawn (the old place frozen till then, or the cover up), `ready`
## when the place is (behind a cover: when it starts to lift), and `stuck` the end of the last frame over STUCK_MS in
## the SETTLE_S after that.
func _timed_move(p: int, root: Node, from: String, to: String, first_visit: bool, change: Callable) -> void:
	var t0 := Time.get_ticks_usec()
	change.call()
	var call_ms := (Time.get_ticks_usec() - t0) / 1000.0
	await get_tree().process_frame   # the frame the change was asked for in has now been drawn
	var first := Time.get_ticks_usec()
	var block := (first - t0) / 1000.0
	var block_draw := _frame_draw_ms
	var last := first
	while cover and (bool(root.get("moving")) or root.get("view") == null) and last - t0 < 30000000:
		await get_tree().process_frame
		var now := Time.get_ticks_usec()
		if (now - last) / 1000.0 > block:
			block = (now - last) / 1000.0
			block_draw = _frame_draw_ms
		last = now
	var ready := last
	_close_popups(root)
	var stuck_end := ready
	var worst := 0.0
	var slow := 0
	while last - ready < int(SETTLE_S * 1000000.0):
		await get_tree().process_frame
		var now := Time.get_ticks_usec()
		var ms := (now - last) / 1000.0
		worst = maxf(worst, ms)
		if ms > STUCK_MS:
			stuck_end = now
			slow += 1
		last = now
	var loc: Dictionary = Compendium.shared().get_entry("locations", to) if Compendium.shared().has("locations", to) else {}
	var row := {"pass": p, "from": from, "to": to, "first_visit": first_visit, "cover": cover,
		"outdoors": bool((loc.get("map", {}) as Dictionary).get("outdoors", false)),
		"region": str(loc.get("region", "")),
		"block_ms": block, "block_draw_ms": block_draw, "call_ms": call_ms,
		"first_frame_ms": (first - t0) / 1000.0, "ready_ms": (ready - t0) / 1000.0,
		"stuck_ms": (stuck_end - t0) / 1000.0, "worst_after_ms": worst, "slow_after": slow, "load": _loadavg()}
	report["transitions"].append(row)
	print("PERF transition %d %-30s -> %-30s %s block %6.0f | first frame %6.0f | ready %6.0f | stuck %6.0f | worst after %5.0f (%d slow)" % [
		p, from, to, "new  " if first_visit else "again", block, row["first_frame_ms"], row["ready_ms"], row["stuck_ms"],
		worst, slow])


## The vineyard ambush with every side on the AI, start to finish (or `frames * 8` frames).
func _combat(p: int) -> void:
	var root := await _story_root(7)
	GameState.story.minute_of_day = DAY
	root.call("enter_location", FIGHT_PLACE, "default")
	_close_popups(root)
	await _wait(warm)
	var view := root.get("view") as Node
	_phase("combat: " + FIGHT)
	var t := Time.get_ticks_usec()
	var ok := bool(view.call("start_encounter", FIGHT))
	var sync := Time.get_ticks_usec()
	if not ok:
		push_warning("PERF: no fight %s" % FIGHT)
		root.queue_free()
		return
	var cv := view.get("combat_view") as Node
	var e := cv.get("e") as Object
	for c: Variant in e.get("combatants"):
		(c as Object).set("controller", &"ai")
	await _wait(1)
	var row := _load("combat_start", FIGHT, t, sync)
	row["combatants"] = (e.get("combatants") as Array).size()
	_rec.clear()
	_recording = true
	var limit := frames * 8
	var n := 0
	var t0 := Time.get_ticks_usec()
	var slow: Array[Dictionary] = []   ## frames over 100 ms, with whose turn it was
	while n < limit and is_instance_valid(cv) and int(e.get("state")) != Encounter.State.OVER:
		await get_tree().process_frame
		n += 1
		if not _rec.is_empty() and float(_rec[_rec.size() - 1]["ms"]) > 100.0:
			var cur := e.call("current") as Object
			slow.append({"ms": _rec[_rec.size() - 1]["ms"], "draw": _rec[_rec.size() - 1]["draw"],
				"turn": str(cur.call("name")) if cur != null else ""})
	_recording = false
	var s := _summarise("combat", "%s (%d combatants, round %d)" % [FIGHT, row["combatants"], int(e.get("round_no"))], p, _rec)
	s["wall_s"] = (Time.get_ticks_usec() - t0) / 1e6
	s["over"] = int(e.get("state")) == Encounter.State.OVER
	s["slow_frames"] = slow
	for f in slow:
		print("PERF slow frame %.0f ms, %.0f drawing (%s)" % [f["ms"], f["draw"], f["turn"]])
	report["samples"].append(s)
	root.queue_free()
	await _wait(2)


## The three graphics presets (Graphics, W17) in the same places, each place built again under each.
func _presets(p: int) -> void:
	var root := await _story_root(5)
	for spec: String in EFFECT_PLACES:
		var where := spec.get_slice("@", 0)
		for preset: String in ["high", "medium", "low", "high"]:
			Graphics.set_preset(preset, false)
			GameState.story.minute_of_day = NIGHT if spec.ends_with("night") else DAY
			_phase("move: " + where)
			root.call("enter_location", where, "default")
			_close_popups(root)
			root.call("_refresh")
			await _sample("preset", "%s %s" % [spec, preset], p)
	Graphics.set_preset("high", false)
	root.queue_free()
	await _wait(2)


## Each effect off in turn, in pairs with everything on just before it (`pairs` times), so the Mac's changing load
## weighs on both halves of a pair alike; tools/perf/perf_effects.py turns the pairs into a cost per effect.
func _effects(p: int) -> void:
	var root := await _story_root(5)
	for spec: String in EFFECT_PLACES:
		var where := spec.get_slice("@", 0)
		GameState.story.minute_of_day = NIGHT if spec.ends_with("night") else DAY
		_phase("move: " + where)
		root.call("enter_location", where, "default")
		_close_popups(root)
		root.call("_refresh")
		await _wait(warm * 2)
		var view := root.get("view") as Node
		for fx: String in effects:
			for k in pairs:
				await _sample("effects", "%s all on|%s" % [spec, fx], p)
				var undo := _effect_off(view, fx)
				await _sample("effects", "%s without|%s" % [spec, fx], p)
				undo.call()
	root.queue_free()
	await _wait(2)


## Each effect switched off and on every few frames (`cycles` times), the first frames after each switch dropped:
## the GPU is shared with other work (Blender renders) whose load swings within seconds, and a fast alternation
## cancels most of it. One sample row per effect: frame_ms is with it off, on_ms with it on.
func _effects_fast(p: int) -> void:
	var root := await _story_root(5)
	const RUN := 12
	const SKIP := 4
	for spec: String in EFFECT_PLACES:
		var where := spec.get_slice("@", 0)
		GameState.story.minute_of_day = NIGHT if spec.ends_with("night") else DAY
		_phase("move: " + where)
		root.call("enter_location", where, "default")
		_close_popups(root)
		root.call("_refresh")
		await _wait(warm * 2)
		var view := root.get("view") as Node
		for fx: String in effects:
			_phase("effects: %s %s" % [spec, fx])
			var on_ms: Array[float] = []
			var off_ms: Array[float] = []
			var diffs: Array[float] = []
			var draws_on := 0
			var draws_off := 0
			for k in cycles:
				var on_run := await _run_frames(RUN, SKIP)
				draws_on = RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME)
				var undo := _effect_off(view, fx)
				var off_run := await _run_frames(RUN, SKIP)
				draws_off = RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME)
				undo.call()
				on_ms.append_array(on_run)
				off_ms.append_array(off_run)
				diffs.append(_stats(on_run)["p50"] - _stats(off_run)["p50"])
			var row := {"kind": "effect", "what": "%s|%s" % [spec, fx], "pass": p, "on_ms": _stats(on_ms),
				"frame_ms": _stats(off_ms), "saves_ms": _stats(diffs), "draws_on": draws_on, "draws_off": draws_off,
				"video_mb": RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_VIDEO_MEM_USED) / 1048576.0,
				"load": _loadavg()}
			report["samples"].append(row)
			print("PERF effect %s %s | on p50 %.1f | off p50 %.1f | saves %.1f ms (cycle median) | draws %d -> %d" % [
				spec, fx, row["on_ms"]["p50"], row["frame_ms"]["p50"], row["saves_ms"]["p50"], draws_on, draws_off])
	root.queue_free()
	await _wait(2)


## `n` frame times (ms), after letting `skip` frames pass (a switch's first frames can carry a shader compile).
func _run_frames(n: int, skip: int) -> Array[float]:
	await _wait(skip)
	_rec.clear()
	_recording = true
	await _wait(n)
	_recording = false
	var out: Array[float] = []
	for r in _rec:
		out.append(float(r["ms"]))
	return out


## Switches one effect off in the place being shown; returns what puts it back.
func _effect_off(view: Node, fx: String) -> Callable:
	var atmo := view.get("atmosphere") as Atmosphere
	var env := atmo.env
	var cam := (view.get("rig") as CameraRig).camera
	match fx:
		"msaa":
			var was := get_viewport().msaa_3d
			get_viewport().msaa_3d = Viewport.MSAA_DISABLED
			return func() -> void: get_viewport().msaa_3d = was
		"edge_aa":
			var was := get_viewport().screen_space_aa
			get_viewport().screen_space_aa = Viewport.SCREEN_SPACE_AA_DISABLED
			return func() -> void: get_viewport().screen_space_aa = was
		"ssr":
			var was := env.ssr_enabled
			env.ssr_enabled = false
			return func() -> void: env.ssr_enabled = was
		"lamp_shadows":
			var shadowed: Array[Light3D] = []
			for n in view.find_children("*", "OmniLight3D", true, false) + view.find_children("*", "SpotLight3D", true, false):
				var l := n as Light3D
				if l.shadow_enabled:
					shadowed.append(l)
					l.shadow_enabled = false
			return func() -> void:
				for l in shadowed:
					if is_instance_valid(l):
						l.shadow_enabled = true
		"ssao":
			var was := env.ssao_enabled
			env.ssao_enabled = false
			return func() -> void: env.ssao_enabled = was
		"ssil":
			var was := env.ssil_enabled
			env.ssil_enabled = false
			return func() -> void: env.ssil_enabled = was
		"volumetric_fog":
			var was := env.volumetric_fog_enabled
			env.volumetric_fog_enabled = false
			return func() -> void: env.volumetric_fog_enabled = was
		"glow":
			var was := env.glow_enabled
			env.glow_enabled = false
			return func() -> void: env.glow_enabled = was
		"dof":
			var was := cam.attributes
			cam.attributes = null
			return func() -> void: cam.attributes = was
		"sun_shadows":
			var was := atmo.sun.shadow_enabled
			atmo.sun.shadow_enabled = false
			return func() -> void: atmo.sun.shadow_enabled = was
		"screen_pass":
			var post := view.get("post") as Node3D
			post.visible = false
			return func() -> void: post.visible = true
		"lamps":
			var lit: Array[OmniLight3D] = []
			for n in view.find_children("*", "OmniLight3D", true, false):
				var l := n as OmniLight3D
				if l.visible:
					lit.append(l)
					l.visible = false
			return func() -> void:
				for l in lit:
					if is_instance_valid(l):
						l.visible = true
		"half_res":
			get_viewport().scaling_3d_scale = 0.5
			return func() -> void: get_viewport().scaling_3d_scale = 1.0
		"metalfx_75":
			# Not an effect switched off: the 3D drawn at 75% and scaled up by MetalFX (Apple's upscaler).
			var mode := get_viewport().scaling_3d_mode
			get_viewport().scaling_3d_mode = Viewport.SCALING_3D_MODE_METALFX_SPATIAL
			get_viewport().scaling_3d_scale = 0.75
			return func() -> void:
				get_viewport().scaling_3d_mode = mode
				get_viewport().scaling_3d_scale = 1.0
		"all":
			var undos: Array[Callable] = []
			for each: String in EFFECTS:
				if each not in ["all", "half_res", "lamps", "metalfx_75"]:
					undos.append(_effect_off(view, each))
			return func() -> void:
				for u in undos:
					u.call()
	return _class_off(fx)


## An effect named by its class (`class_name` with a `static func set_enabled(on: bool)`, as SpriteReflection has):
## switched off through it, and back on.
func _class_off(cls: String) -> Callable:
	for c: Dictionary in ProjectSettings.get_global_class_list():
		if str(c["class"]) == cls:
			var script := load(str(c["path"])) as Script
			if not script.get_script_method_list().any(func(m: Dictionary) -> bool: return m["name"] == "set_enabled"):
				break
			script.call("set_enabled", false)
			return func() -> void: script.call("set_enabled", true)
	push_warning("perf: no effect or class with a static set_enabled called %s" % cls)
	return func() -> void: pass


## Where the video memory goes: a new game, every place visited, back to the title, then each session-long cache
## emptied in turn (they keep every sprite sheet, texture and material ever shown until the game quits).
func _memory(places: Array) -> void:
	_phase("memory")
	await _wait(10)
	_mem("before a game")
	var root := await _story_root(5)
	await _wait(warm)
	_mem("new game, first place")
	for id: Variant in places:
		if not Compendium.shared().has("locations", str(id)):
			continue
		root.call("enter_location", str(id), "default")
		_close_popups(root)
		await _wait(30)
	_mem("after %d places" % places.size())
	root.queue_free()
	await _wait(10)
	_mem("back at the title (game freed)")
	var caches := [["DirectionalSprite._frames_cache (sprite sheets)", func() -> void: DirectionalSprite._frames_cache.clear()],
		["HeroLook caches (custom heroes)", func() -> void:
			HeroLook._frames.clear()
			HeroLook._images.clear()
			HeroLook._views.clear()],
		["Look._textured/_textures/_normals (surface textures)", func() -> void:
			Look._textured.clear()
			Look._textures.clear()
			Look._normals.clear()],
		["ModelPiece._materials/_tree_meshes (3D pieces)", func() -> void:
			ModelPiece._materials.clear()
			ModelPiece._tree_meshes.clear()],
		["ArenaBoard._props (prop art)", func() -> void: ArenaBoard._props.clear()],
		["Icons._cache", func() -> void: Icons._cache.clear()]]
	for c: Variant in caches:
		var pair := c as Array
		(pair[1] as Callable).call()
		await _wait(10)
		_mem("after emptying " + str(pair[0]))


func _mem(what: String) -> void:
	var row := {"kind": "memory", "what": what,
		"video_mb": RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_VIDEO_MEM_USED) / 1048576.0,
		"texture_mb": RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TEXTURE_MEM_USED) / 1048576.0,
		"buffer_mb": RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_BUFFER_MEM_USED) / 1048576.0,
		"static_mb": Performance.get_monitor(Performance.MEMORY_STATIC) / 1048576.0,
		"objects": Performance.get_monitor(Performance.OBJECT_COUNT),
		"resources": Performance.get_monitor(Performance.OBJECT_RESOURCE_COUNT)}
	report["memory"].append(row)
	print("PERF memory %-60s video %5.0f MB (textures %5.0f) | static %5.0f MB | %d resources" % [what, row["video_mb"],
		row["texture_mb"], row["static_mb"], row["resources"]])


# --- Helpers --------------------------------------------------------------------------------------

## A story game with the six pregens at `level` (four travelling), started at the first place.
func _story_root(level: int) -> Node:
	GameState.reset()
	var st := GameState.story
	for id: String in ["godrick_pendlebrook", "liriel_dawnsong", "thistle", "ratatoille", "wren_featherfoot", "kip_smudgewick"]:
		var ch := Pregens.build(id, level)
		ch.finish_long_rest()
		if st.party.size() < StoryState.PARTY_CAP:
			st.party.append(ch)
		else:
			st.bench.append(ch)
	var root := (load("res://scenes/game.tscn") as PackedScene).instantiate()
	root.set("autosaves", true)   # as in play: arriving somewhere writes the autosave
	add_child(root)
	await _wait(5)
	_close_popups(root)
	return root


## Conversations or a Strahd visit that open on arrival would hold the measurement: close them.
func _close_popups(root: Node) -> void:
	var d := root.get("dialogue") as Node
	if d != null:
		d.queue_free()
		root.set("dialogue", null)
		ModeController.force(ModeController.Mode.EXPLORATION)


func _load(kind: String, what: String, t0: int, sync_end: int = -1) -> Dictionary:
	var now := Time.get_ticks_usec()
	var row := {"kind": kind, "what": what, "ms": (now - t0) / 1000.0}
	if sync_end >= 0:
		row["sync_ms"] = (sync_end - t0) / 1000.0
	report["loads"].append(row)
	print("PERF load %s %s %.1f ms" % [kind, what, row["ms"]])
	return row


func _sample(kind: String, what: String, p: int) -> void:
	await _wait(warm)
	_phase("%s: %s" % [kind, what])
	_rec.clear()
	_recording = true
	await _wait(frames)
	_recording = false
	report["samples"].append(_summarise(kind, what, p, _rec))


func _worst_frame(n: int) -> float:
	_rec.clear()
	_recording = true
	await _wait(n)
	_recording = false
	var worst := 0.0
	for r in _rec:
		worst = maxf(worst, float(r["ms"]))
	return worst


func _summarise(kind: String, what: String, p: int, rec: Array[Dictionary]) -> Dictionary:
	var ms: Array[float] = []
	var gpu: Array[float] = []
	var rcpu: Array[float] = []
	var proc: Array[float] = []
	var draw: Array[float] = []
	for r in rec:
		ms.append(float(r["ms"]))
		gpu.append(float(r["gpu"]))
		rcpu.append(float(r["rcpu"]))
		proc.append(float(r["proc"]))
		draw.append(float(r["draw"]))
	var s := {"kind": kind, "what": what, "pass": p, "n": rec.size(),
		"frame_ms": _stats(ms), "gpu_ms": _stats(gpu), "render_cpu_ms": _stats(rcpu), "process_ms": _stats(proc), "draw_ms": _stats(draw),
		"over_16ms": ms.filter(func(x: float) -> bool: return x > 16.7).size(),
		"over_33ms": ms.filter(func(x: float) -> bool: return x > 33.3).size(),
		"draw_calls": RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME),
		"primitives": RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_PRIMITIVES_IN_FRAME),
		"objects": RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_OBJECTS_IN_FRAME),
		"video_mb": RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_VIDEO_MEM_USED) / 1048576.0,
		"texture_mb": RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TEXTURE_MEM_USED) / 1048576.0,
		"buffer_mb": RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_BUFFER_MEM_USED) / 1048576.0,
		"static_mb": Performance.get_monitor(Performance.MEMORY_STATIC) / 1048576.0,
		"nodes": Performance.get_monitor(Performance.OBJECT_NODE_COUNT),
		"objects_all": Performance.get_monitor(Performance.OBJECT_COUNT),
		"resources": Performance.get_monitor(Performance.OBJECT_RESOURCE_COUNT),
		"rss_mb": _rss_mb(), "load": _loadavg()}
	print("PERF sample %s | %s | frame p50 %.2f p95 %.2f max %.2f | draw p50 %.2f | gpu p50 %.2f | draws %d | vram %.0f MB | rss %.0f MB" % [
		kind, what, s["frame_ms"]["p50"], s["frame_ms"]["p95"], s["frame_ms"]["max"], s["draw_ms"]["p50"],
		s["gpu_ms"]["p50"], s["draw_calls"], s["video_mb"], s["rss_mb"]])
	return s


static func _stats(xs: Array[float]) -> Dictionary:
	if xs.is_empty():
		return {"mean": 0.0, "min": 0.0, "p10": 0.0, "p50": 0.0, "p95": 0.0, "p99": 0.0, "max": 0.0}
	var v: Array[float] = xs.duplicate()
	v.sort()
	var total := 0.0
	for x in v:
		total += x
	return {"mean": total / v.size(), "min": v[0], "p10": v[v.size() / 10], "p50": v[v.size() / 2], "p95": v[mini(v.size() - 1, int(v.size() * 0.95))],
		"p99": v[mini(v.size() - 1, int(v.size() * 0.99))], "max": v[v.size() - 1]}


## The Mac's one-minute load average when the sample ended (other lanes' tests and renders share it).
func _loadavg() -> float:
	var out: Array = []
	OS.execute("sysctl", ["-n", "vm.loadavg"], out)
	return float(str(out[0]).strip_edges().trim_prefix("{ ").get_slice(" ", 0)) if not out.is_empty() else 0.0


func _rss_mb() -> float:
	var out: Array = []
	OS.execute("ps", ["-o", "rss=", "-p", str(OS.get_process_id())], out)
	return float(str(out[0]).strip_edges()) / 1024.0 if not out.is_empty() else 0.0


## Tells tools/perf/perf_run.py's script profiler which part of the run the next frames belong to.
func _phase(what: String) -> void:
	print("PERF phase ", what)


func _wait(n: int) -> void:
	for i in n:
		await get_tree().process_frame


## Each frame: draw the window macOS won't (it's off screen), then note how long the last frame took and how much of
## it went to drawing (the renderer's CPU side, plus any wait for the GPU to free a frame), from the renderer's own
## pre- and post-draw signals so it counts the same whether the engine or this probe drew the frame.
func _on_frame() -> void:
	if not DisplayServer.window_can_draw():
		RenderingServer.force_draw(false, get_process_delta_time())
	var now := Time.get_ticks_usec()
	if _recording and _last_usec > 0:
		_rec.append({"ms": (now - _last_usec) / 1000.0, "draw": _draw_ms,
			"gpu": RenderingServer.viewport_get_measured_render_time_gpu(_vp),
			"rcpu": RenderingServer.viewport_get_measured_render_time_cpu(_vp),
			"proc": Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0})
	_last_usec = now
	_frame_draw_ms = _draw_ms
	_draw_ms = 0.0


func _pre_draw() -> void:
	_draw_start = Time.get_ticks_usec()


func _post_draw() -> void:
	_draw_ms += (Time.get_ticks_usec() - _draw_start) / 1000.0


func _clean_saves() -> void:
	var dir := DirAccess.open(SaveSystem.save_dir)
	if dir == null:
		return
	for f in dir.get_files():
		dir.remove(f)
	DirAccess.remove_absolute(SaveSystem.save_dir)
