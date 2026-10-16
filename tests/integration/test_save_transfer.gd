extends TestCase

var test_dir := "user://test_save_transfer_%d/" % OS.get_process_id()
var old_dir: String
var old_slot: String


func before_each() -> void:
	old_dir = SaveSystem.save_dir
	old_slot = SaveSystem.current_slot
	SaveSystem.save_dir = test_dir
	DirAccess.make_dir_recursive_absolute(test_dir)


func after_each() -> void:
	for name in DirAccess.get_files_at(test_dir):
		DirAccess.remove_absolute(test_dir.path_join(name))
	DirAccess.remove_absolute(test_dir)
	SaveSystem.save_dir = old_dir
	SaveSystem.current_slot = old_slot


func test_every_shipped_campaign_save_can_be_reviewed_without_loading() -> void:
	var before := GameState.to_dict()
	var dice := Dice.roller.get_state()
	for file in DirAccess.get_files_at("res://tests/saves"):
		if not file.begins_with("v2_") or not file.ends_with(".json"):
			continue
		var review := SaveTransfer.inspect("res://tests/saves/" + file)
		assert_false(review.has("error"), file + ": " + str(review.get("error", "")))
	assert_eq(GameState.story.to_dict(), before["story"])
	assert_eq(Dice.roller.get_state(), dice)
	assert_eq(SaveSystem.current_slot, old_slot)


func test_import_creates_new_slot_and_never_overwrites_existing_campaign() -> void:
	var review := SaveTransfer.inspect("res://tests/saves/v2_vallaki.json")
	assert_false(review.has("error"))
	var first := SaveTransfer.commit(review)
	var second := SaveTransfer.commit(review)
	assert_false(first.has("error"))
	assert_false(second.has("error"))
	assert_true(str(first["slot"]) != str(second["slot"]))
	assert_eq(AtomicJson.read(SaveSystem.slot_path(str(first["slot"])))["story"], (review["data"] as Dictionary)["story"])
	assert_eq(SaveSystem.current_slot, old_slot)


func test_invalid_and_newer_imports_leave_saves_and_current_game_untouched() -> void:
	var source := AtomicJson.read("res://tests/saves/v2_vallaki.json")
	var future := source.duplicate(true)
	future["version"] = 999
	var broken := source.duplicate(true)
	(broken["story"] as Dictionary)["party"] = ["not a character"]
	var malformed := source.duplicate(true)
	(malformed["story"] as Dictionary)["positions"] = [[1]]
	for data: Dictionary in [{"hello": "world"}, future, broken, malformed]:
		assert_eq(AtomicJson.write(test_dir + "incoming.json", data), OK)
		assert_true(SaveTransfer.inspect(test_dir + "incoming.json").has("error"))
	assert_eq(SaveSystem.current_slot, old_slot)


func test_share_uses_a_snapshot_and_recovers_a_corrupt_primary() -> void:
	var path := test_dir + "save.json"
	assert_eq(AtomicJson.write(path, {"version": 2, "story": {"gold": 5}}), OK)
	assert_eq(AtomicJson.write(path, {"version": 2, "story": {"gold": 10}}), OK)
	var broken := FileAccess.open(path, FileAccess.WRITE)
	broken.store_string("{truncated")
	broken.close()
	assert_eq(SaveTransfer.share_copy(path, test_dir + "shared.json"), OK)
	assert_eq(int((AtomicJson.read(test_dir + "shared.json")["story"] as Dictionary)["gold"]), 5)
	assert_eq(FileAccess.get_file_as_string(path), "{truncated")


func test_nested_import_shapes_are_rejected_before_any_campaign_is_loaded() -> void:
	var base := AtomicJson.read("res://tests/saves/v2_vallaki.json")
	var variants: Array[Dictionary] = []
	for field: String in ["conditions", "effects", "concentration"]:
		var data := base.duplicate(true)
		var member := ((data["story"] as Dictionary)["party"] as Array)[0] as Dictionary
		(member["state"] as Dictionary)[field] = {"bad": 12} if field != "effects" else ["not an effect"]
		variants.append(data)
	var position := base.duplicate(true)
	position["party_positions"] = [[0, 1]]
	variants.append(position)
	var version := base.duplicate(true)
	version["version"] = 1.5
	variants.append(version)
	for data in variants:
		assert_eq(AtomicJson.write(test_dir + "incoming.json", data), OK)
		assert_true(SaveTransfer.inspect(test_dir + "incoming.json").has("error"))
