extends TestCase
## In-place updates (core/patch_loader.gd): which patch goes on which full download.


func test_a_patch_for_this_download_is_used() -> void:
	assert_eq(PatchLoader.check({"base": "1.0.3", "version": "1.0.5"}, "1.0.3", true), "")


func test_a_patch_for_another_download_is_left_unused() -> void:
	assert_eq(PatchLoader.check({"base": "1.0.3", "version": "1.0.5"}, "1.0.4", true),
		"it builds on 1.0.3, and this is 1.0.4")


func test_a_patch_needs_its_pack_and_a_complete_description() -> void:
	assert_eq(PatchLoader.check({"base": "1.0.3", "version": "1.0.5"}, "1.0.3", false), "patch.pck is missing")
	assert_eq(PatchLoader.check({"version": "1.0.5"}, "1.0.3", true), "patch.json doesn't name its base and version")
	assert_eq(PatchLoader.check({}, "1.0.3", true), "patch.json doesn't name its base and version")


func test_an_unreadable_description_reads_as_empty() -> void:
	var path := "user://test_patch_loader.json"
	var f := FileAccess.open(path, FileAccess.WRITE)
	f.store_string("[1, 2]")
	f.close()
	assert_eq(PatchLoader.read_info(path), {})
	f = FileAccess.open(path, FileAccess.WRITE)
	f.store_string("{not json")
	f.close()
	assert_eq(PatchLoader.read_info(path), {})
	f = FileAccess.open(path, FileAccess.WRITE)
	f.store_string("{\"base\": \"1.0.3\", \"version\": \"1.0.4\"}")
	f.close()
	assert_eq(PatchLoader.read_info(path), {"base": "1.0.3", "version": "1.0.4"})
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	assert_eq(PatchLoader.read_info("user://no_such_patch.json"), {})
