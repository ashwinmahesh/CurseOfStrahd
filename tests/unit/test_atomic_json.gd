extends TestCase

var path_ := "user://test_atomic_mobile_%d/save.json" % OS.get_process_id()


func after_each() -> void:
	for suffix: String in ["", ".tmp", ".bak", ".bak.tmp", ".2", ".2.tmp", ".2.bak", ".2.bak.tmp", ".3", ".3.tmp", ".3.bak", ".3.bak.tmp"]:
		if FileAccess.file_exists(path_ + suffix):
			DirAccess.remove_absolute(path_ + suffix)
	DirAccess.remove_absolute(path_.get_base_dir())


func test_failed_writes_preserve_committed_save_at_every_boundary() -> void:
	assert_eq(AtomicJson.write(path_, {"version": 2, "gold": 7}), OK)
	for boundary: String in ["write", "verify", "backup", "commit"]:
		assert_true(AtomicJson.write(path_, {"version": 2, "gold": 90},
			func(step: String) -> bool: return step == boundary) != OK)
		assert_eq(int(AtomicJson.read(path_)["gold"]), 7, boundary)


func test_corrupt_primary_recovers_previous_copy_and_ignores_uncommitted_temp() -> void:
	assert_eq(AtomicJson.write(path_, {"version": 2, "gold": 7}), OK)
	assert_eq(AtomicJson.write(path_, {"version": 2, "gold": 9}), OK)
	var file := FileAccess.open(path_, FileAccess.WRITE)
	file.store_string("{broken")
	file.close()
	assert_eq(int(AtomicJson.read(path_)["gold"]), 7)
	assert_eq(AtomicJson.write(path_, {"version": 2, "gold": 11}), OK)
	assert_eq(int(AtomicJson.read(path_)["gold"]), 11)
	assert_eq(int(AtomicJson.read_one(path_ + ".bak")["gold"]), 7)


func test_newer_valid_save_never_falls_back_to_older_backup() -> void:
	assert_eq(AtomicJson.write(path_, {"version": 2}), OK)
	assert_eq(AtomicJson.write(path_, {"version": 999}), OK)
	assert_eq(int(AtomicJson.read(path_)["version"]), 999)


func test_rotation_never_removes_newest_save_when_a_boundary_fails() -> void:
	var paths: Array[String] = [path_, path_ + ".2", path_ + ".3"]
	for boundary: String in ["write", "verify", "backup", "commit"]:
		for index in paths.size():
			assert_eq(AtomicJson.write(paths[index], {"generation": 3 - index}), OK)
		assert_true(AtomicJson.rotate(paths, func(step: String) -> bool: return step == boundary) != OK)
		assert_eq(int(AtomicJson.read(path_)["generation"]), 3, boundary)
	assert_eq(AtomicJson.rotate(paths), OK)
	assert_eq(AtomicJson.write(path_, {"generation": 4}), OK)
	assert_eq(int(AtomicJson.read(path_)["generation"]), 4)
	assert_eq(int(AtomicJson.read(path_ + ".2")["generation"]), 3)
	assert_eq(int(AtomicJson.read(path_ + ".3")["generation"]), 2)
