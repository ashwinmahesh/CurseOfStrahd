extends Node
## Runs every tests/unit/test_*.gd and tests/integration/test_*.gd headless. Exits non-zero on any
## failure or if no tests ran. Use: make test   (optionally -- --only=<substring>)

const DIRS := ["res://tests/unit/", "res://tests/integration/"]


func _ready() -> void:
	SaveSystem.save_dir = "user://test_saves/"
	var only := ""
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--only="):
			only = arg.get_slice("=", 1)
	var total := 0
	var failed: Array[String] = []
	for dir_path: String in DIRS:
		var dir := DirAccess.open(dir_path)
		if dir == null:
			continue
		var files := dir.get_files()
		files.sort()
		for f in files:
			if not f.begins_with("test_") or not f.ends_with(".gd"):
				continue
			var script := load(dir_path + f) as GDScript
			if script == null or not script.can_instantiate():
				total += 1
				failed.append(f)
				print("  FAIL  ", f, ": script failed to load")
				continue
			for m in script.get_script_method_list():
				var method := str(m["name"])
				if not method.begins_with("test_"):
					continue
				if only != "" and not (f + ":" + method).contains(only):
					continue
				total += 1
				var tc := script.new() as TestCase
				tc.current_test = "%s:%s" % [f.get_basename(), method]
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
	Creature.clear_caches()
	Compendium.release()
	print("")
	print("%d tests, %d passed, %d failed" % [total, total - failed.size(), failed.size()])
	get_tree().quit(1 if not failed.is_empty() or total == 0 else 0)
