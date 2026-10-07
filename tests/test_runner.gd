extends Node
## Runs every tests/unit/test_*.gd and tests/integration/test_*.gd headless. Exits non-zero on any
## failure or if no tests ran. Use: make test   (optionally -- --only=<substring> --files=test_a.gd,test_b.gd)
## make test starts several of these at once (tools/run_tests.py) with --claim=<folder>: each takes the files in
## --files order, skips any another runner has claimed (a folder per file there, made atomically), and marks where
## each file starts and ends ("@@ start <file>", "@@ done <file> <ms>") so the driver can keep a file's lines together.
## The files in --split are claimed a test at a time instead (<file>@<test>), so a long file's tests run side by side.

const DIRS := ["res://tests/unit/", "res://tests/integration/"]


func _ready() -> void:
	# Saves go to a folder of this run's own: every checkout of the project shares one user:// folder, so test runs in
	# two worktrees at once would load each other's round-start saves.
	SaveSystem.save_dir = "user://test_saves/%d/" % OS.get_process_id()
	# Loads and new games roll fresh dice (ADR 0002); in tests they are fresh but repeatable from run to run.
	Dice.deterministic = true
	GameSettings.path = SaveSystem.save_dir.path_join("settings.cfg")   # never the player's own settings
	var only := ""
	var files_only := PackedStringArray()
	var claim_dir := ""
	var split := PackedStringArray()
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--only="):
			only = arg.get_slice("=", 1)
		elif arg.begins_with("--files="):
			files_only = arg.get_slice("=", 1).split(",", false)
		elif arg.begins_with("--claim="):
			claim_dir = arg.substr(arg.find("=") + 1)
		elif arg.begins_with("--split="):
			split = arg.get_slice("=", 1).split(",", false)
	var total := 0
	var failed: Array[String] = []
	for path: String in _test_files(files_only):
		var f := path.get_file()
		if claim_dir != "" and f in split:
			# A big file's tests are shared out one at a time, so its slow ones run side by side.
			var shared := load(path) as GDScript
			if shared != null and shared.can_instantiate():
				for method in _methods(shared, f, only):
					if DirAccess.make_dir_absolute(claim_dir.path_join("%s@%s" % [f, method])) != OK:
						continue
					var part := await _run_file(shared, f, [method], claim_dir)
					total += int(part["total"])
					failed.append_array(part["failed"] as Array)
				continue
		if claim_dir != "" and DirAccess.make_dir_absolute(claim_dir.path_join(f)) != OK:
			continue   # another runner has it
		var script := load(path) as GDScript
		if script == null or not script.can_instantiate():
			if claim_dir != "":
				print("@@ start ", f)
			total += 1
			failed.append(f)
			print("  FAIL  ", f, ": script failed to load")
			if claim_dir != "":
				print("@@ done %s 0" % f)
			continue
		var whole := await _run_file(script, f, _methods(script, f, only), claim_dir)
		total += int(whole["total"])
		failed.append_array(whole["failed"] as Array)
	Creature.clear_caches()
	Compendium.release()
	print("")
	print("%d tests, %d passed, %d failed" % [total, total - failed.size(), failed.size()])
	_clear_saves()
	# One of several runners may find nothing left to claim; the driver checks that the run as a whole ran tests.
	get_tree().quit(1 if not failed.is_empty() or (total == 0 and claim_dir == "") else 0)


## The test methods of a test file, in the order written, that `only` lets through.
func _methods(script: GDScript, f: String, only: String) -> Array[String]:
	var out: Array[String] = []
	for m in script.get_script_method_list():
		var method := str(m["name"])
		if method.begins_with("test_") and (only == "" or (f + ":" + method).contains(only)):
			out.append(method)
	return out


## Runs `methods` of one test file: {total, failed (names)}. With a claim folder it marks where the part starts and ends
## for the driver, and whatever the part added to the Compendium is taken out after it.
func _run_file(script: GDScript, f: String, methods: Array[String], claim_dir: String) -> Dictionary:
	if claim_dir != "":
		print("@@ start ", f)
	var started := Time.get_ticks_msec()
	var data_before := _data_ids()
	var failed: Array[String] = []
	for method in methods:
		var tc := script.new() as TestCase
		tc.current_test = "%s:%s" % [f.get_basename(), method]
		# Each test starts from dice of its own, so it rolls the same whichever process runs it and after what.
		Dice.reseed(hash(tc.current_test))
		add_child(tc)
		await tc.before_each()
		await tc.call(method)
		if tc.has_method("after_each"):
			await tc.call("after_each")
		if tc.failures.is_empty():
			print("  ok    ", tc.current_test)
		else:
			for fail_msg: String in tc.failures:
				print("  FAIL  ", fail_msg)
			failed.append(tc.current_test)
		tc.queue_free()
		await get_tree().process_frame
	_drop_added_data(data_before)
	_reset_globals()
	if claim_dir != "":
		print("@@ done %s %d" % [f, Time.get_ticks_msec() - started])
	return {"total": methods.size(), "failed": failed}


## The test files to run: every test_*.gd under DIRS, or those named in `files_only`, in the order given there.
func _test_files(files_only: PackedStringArray) -> Array[String]:
	var found := {}
	for dir_path: String in DIRS:
		var dir := DirAccess.open(dir_path)
		if dir == null:
			continue
		var files := dir.get_files()
		files.sort()
		for f in files:
			if f.begins_with("test_") and f.ends_with(".gd"):
				found[f] = dir_path + f
	var out: Array[String] = []
	if files_only.is_empty():
		out.assign(found.values())
	else:
		for f in files_only:
			if found.has(f):
				out.append(found[f])
	return out


## Puts back the game's global state a test file may leave behind, before the next file in the same process: a scene
## that started a fight left ModeController in COMBAT, and every later save in that process was refused
## (test_settings_page before test_fresh_dice, 2026-10-07). Also the tree's pause, the time scale, the save slot and
## GameState, as a fresh process has them.
func _reset_globals() -> void:
	ModeController.force(ModeController.Mode.EXPLORATION)
	get_tree().paused = false
	Engine.time_scale = 1.0
	SaveSystem.current_slot = ""
	GameState.reset()


## Every id in the shared Compendium's tables, so what a test file adds there (fixture places, made-up monsters) can
## be taken out after it. Files share a process, so a fixture left behind turned up in later files' loops over every
## place (test_skirmish's every-map test, 2026-10-07).
func _data_ids() -> Dictionary:
	var comp := Compendium.shared()
	var tables := {}
	for t: String in comp.tables:
		var ids := {}
		for id: Variant in (comp.tables[t] as Dictionary):
			ids[id] = true
		tables[t] = ids
	return {"compendium": comp, "tables": tables}


## Takes out of the Compendium every table and id a test file added (`before` is _data_ids() from before it ran). A
## file that reloaded the Compendium left nothing of its own in it.
func _drop_added_data(before: Dictionary) -> void:
	var comp := Compendium.shared()
	if comp != before["compendium"]:
		return
	var had := before["tables"] as Dictionary
	for t: String in comp.tables.keys():
		if not had.has(t):
			comp.tables.erase(t)
			continue
		var table := comp.tables[t] as Dictionary
		for id: Variant in table.keys():
			if not (had[t] as Dictionary).has(id):
				table.erase(id)


## Removes this run's save folder.
func _clear_saves() -> void:
	var dir := DirAccess.open(SaveSystem.save_dir)
	if dir == null:
		return
	for f in dir.get_files():
		dir.remove(f)
	DirAccess.remove_absolute(SaveSystem.save_dir)
