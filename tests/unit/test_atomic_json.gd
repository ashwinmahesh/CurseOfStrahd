extends TestCase

const PATH := "user://test_atomic_mobile/save.json"


func after_each() -> void:
	for suffix: String in ["", ".tmp", ".bak", ".bak.tmp"]:
		if FileAccess.file_exists(PATH + suffix):
			DirAccess.remove_absolute(PATH + suffix)
	DirAccess.remove_absolute(PATH.get_base_dir())


func test_failed_writes_preserve_committed_save_at_every_boundary() -> void:
	assert_eq(AtomicJson.write(PATH, {"version": 2, "gold": 7}), OK)
	for boundary: String in ["write", "verify", "backup", "commit"]:
		assert_true(AtomicJson.write(PATH, {"version": 2, "gold": 90},
			func(step: String) -> bool: return step == boundary) != OK)
		assert_eq(int(AtomicJson.read(PATH)["gold"]), 7, boundary)


func test_corrupt_primary_recovers_previous_copy_and_ignores_uncommitted_temp() -> void:
	assert_eq(AtomicJson.write(PATH, {"version": 2, "gold": 7}), OK)
	assert_eq(AtomicJson.write(PATH, {"version": 2, "gold": 9}), OK)
	var file := FileAccess.open(PATH, FileAccess.WRITE)
	file.store_string("{broken")
	file.close()
	assert_eq(int(AtomicJson.read(PATH)["gold"]), 7)
	assert_eq(AtomicJson.write(PATH, {"version": 2, "gold": 11}), OK)
	assert_eq(int(AtomicJson.read(PATH)["gold"]), 11)
	assert_eq(int(AtomicJson.read_one(PATH + ".bak")["gold"]), 7)


func test_newer_valid_save_never_falls_back_to_older_backup() -> void:
	assert_eq(AtomicJson.write(PATH, {"version": 2}), OK)
	assert_eq(AtomicJson.write(PATH, {"version": 999}), OK)
	assert_eq(int(AtomicJson.read(PATH)["version"]), 999)
