extends Node
## Runs every tests/unit/test_*.gd and tests/integration/test_*.gd headless. Exits non-zero on any
## failure or if no tests ran. Use: make test   (optionally -- --only=<substring> --files=test_a.gd,test_b.gd)
## make test starts several of these at once (tools/run_tests.py) with --claim=<folder>: each takes the files in
## --files order, skips any another runner has claimed (a folder per file there, made atomically), and marks where
## each file starts and ends ("@@ start <file>", "@@ done <file> <ms>") so the driver can keep a file's lines together.

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
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--only="):
			only = arg.get_slice("=", 1)
		elif arg.begins_with("--files="):
			files_only = arg.get_slice("=", 1).split(",", false)
		elif arg.begins_with("--claim="):
			claim_dir = arg.substr(arg.find("=") + 1)
	var total := 0
	var failed: Array[String] = []
	for path: String in _test_files(files_only):
		var f := path.get_file()
		if claim_dir != "":
			if DirAccess.make_dir_absolute(claim_dir.path_join(f)) != OK:
				continue   # another runner has it
			print("@@ start ", f)
		var started := Time.get_ticks_msec()
		var script := load(path) as GDScript
		if script == null or not script.can_instantiate():
			total += 1
			failed.append(f)
			print("  FAIL  ", f, ": script failed to load")
		else:
			for m in script.get_script_method_list():
				var method := str(m["name"])
				if not method.begins_with("test_"):
					continue
				if only != "" and not (f + ":" + method).contains(only):
					continue
				total += 1
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
		if claim_dir != "":
			print("@@ done %s %d" % [f, Time.get_ticks_msec() - started])
	Creature.clear_caches()
	Compendium.release()
	print("")
	print("%d tests, %d passed, %d failed" % [total, total - failed.size(), failed.size()])
	_clear_saves()
	# One of several runners may find nothing left to claim; the driver checks that the run as a whole ran tests.
	get_tree().quit(1 if not failed.is_empty() or (total == 0 and claim_dir == "") else 0)


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


## Removes this run's save folder.
func _clear_saves() -> void:
	var dir := DirAccess.open(SaveSystem.save_dir)
	if dir == null:
		return
	for f in dir.get_files():
		dir.remove(f)
	DirAccess.remove_absolute(SaveSystem.save_dir)
