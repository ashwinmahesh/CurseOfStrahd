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
		if not file.begins_with("v") or not file.ends_with(".json"):
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


func test_mobile_recovery_uses_a_separate_continuation_slot_and_rejects_damaged_imports() -> void:
	var before := GameState.to_dict()
	var old_dice := Dice.roller.get_state()
	var e := TestCombat.open_field(92)
	var hero := TestCombat.hero(e, "godrick_pendlebrook", Vector2i(2, 2), 5)
	TestCombat.foe(e, "zombie", Vector2i(9, 6))
	GameState.reset()
	GameState.story.party.append(hero.creature as Character)
	GameState.story.location = "into_the_mists_road"
	var journal := CombatJournal.begin(e)
	journal.append(e, "start", {"surprised": []})
	GameState.combat_snapshot = {"location": "into_the_mists_road", "encounter": "wolves", "data": EncounterSnapshot.capture(e), "journal": journal.data}
	SaveSystem.current_slot = "my_campaign"
	assert_eq(SaveSystem.save_combat_recovery(), OK)
	assert_eq(SaveSystem.current_slot, "my_campaign")
	var review := SaveTransfer.inspect(SaveSystem.slot_path(SaveSystem.COMBAT_RECOVERY))
	assert_false(review.has("error"), str(review.get("error", "")))
	assert_eq(SaveSystem.load_slot(SaveSystem.COMBAT_RECOVERY), OK)
	assert_eq(SaveSystem.current_slot, "my_campaign")
	var stored := CombatJournal.new()
	stored.data = GameState.combat_snapshot["journal"]
	var recovered := stored.restore(Dice.roller, GameState.story.party)
	assert_eq(recovered.state, Encounter.State.ACTIVE)
	assert_true(recovered.get_c(hero.id).creature == GameState.story.party[0])
	var malformed := (review["data"] as Dictionary).duplicate(true)
	malformed["combat"]["journal"]["commands"][0]["args"]["surprised"] = "bad"
	assert_eq(AtomicJson.write(test_dir + "broken.json", malformed), OK)
	assert_true(SaveTransfer.inspect(test_dir + "broken.json").has("error"))
	var state := GameState.story.to_dict()
	assert_eq(SaveSystem.load_slot("broken"), ERR_FILE_CORRUPT)
	assert_eq(GameState.story.to_dict(), state, "a rejected ledger never changes the current campaign")
	GameState.story.options["difficulty"] = "honour"
	var honour := SaveSystem.honour_slot()
	assert_eq(SaveSystem.save_combat_recovery(), OK)
	assert_true(SaveSystem.has_slot(honour))
	assert_eq(SaveSystem.current_slot, honour)
	if recovered.pending != null:
		recovered.pending.continuation = Callable()
		recovered.pending = null
	GameState.from_dict(before)
	Dice.roller.set_state(old_dice)


func test_ios_preview_saves_remain_readable_and_new_writes_use_desktop_version_two() -> void:
	var preview := AtomicJson.read("res://tests/saves/v2_vallaki.json")
	preview["version"] = 3
	var path := test_dir + "preview.json"
	assert_eq(AtomicJson.write(path, preview), OK)
	var review := SaveTransfer.inspect(path)
	assert_false(review.has("error"), str(review.get("error", "")))
	assert_eq(int((review.get("data", {}) as Dictionary).get("version", 0)), 2)
	assert_false(bool(SaveSystem.describe("preview").get("newer", true)))
	var before := GameState.to_dict()
	assert_eq(SaveSystem.load_slot("preview"), OK)
	assert_eq(int(GameState.to_dict()["version"]), 2)
	assert_eq(SaveSystem.save("desktop_compatible"), OK)
	assert_eq(int(AtomicJson.read(SaveSystem.slot_path("desktop_compatible"))["version"]), 2)
	GameState.from_dict(before)


func test_exploration_checkpoints_preserve_all_five_event_autosaves_and_home_slot() -> void:
	var before := GameState.to_dict()
	GameState.reset()
	SaveSystem.current_slot = "campaign_home"
	var generations: Array[String] = []
	for n in range(1, SaveSystem.AUTOSAVES + 1):
		var path := SaveSystem.slot_path(SaveSystem.autosave_slot(n))
		assert_eq(AtomicJson.write(path, {"version": 2, "event_generation": n}), OK)
		generations.append(FileAccess.get_file_as_string(path))
	for step in 8:
		GameState.story.gold = float(step)
		assert_eq(SaveSystem.save_mobile_checkpoint(), OK)
	assert_eq(SaveSystem.current_slot, "campaign_home")
	for n in range(1, SaveSystem.AUTOSAVES + 1):
		assert_eq(FileAccess.get_file_as_string(SaveSystem.slot_path(SaveSystem.autosave_slot(n))), generations[n - 1])
	var checkpoint := AtomicJson.read(SaveSystem.slot_path(SaveSystem.MOBILE_CHECKPOINT))
	assert_eq(str(checkpoint["home_slot"]), "campaign_home")
	assert_eq(float((checkpoint["story"] as Dictionary)["gold"]), 7.0)
	assert_eq(SaveSystem.load_slot(SaveSystem.MOBILE_CHECKPOINT), OK)
	assert_eq(SaveSystem.current_slot, "campaign_home", "continuation does not steal quicksave ownership")
	GameState.from_dict(before)


func test_command_continuation_does_not_overwrite_a_round_retry_and_clears_only_its_campaign() -> void:
	var before := GameState.to_dict()
	GameState.reset()
	SaveSystem.current_slot = "round_retry_campaign"
	GameState.combat_snapshot = {"location": "into_the_mists_road", "encounter": "wolves", "data": {"round": 2}}
	assert_eq(SaveSystem.save_round(), OK)
	var round_before := FileAccess.get_file_as_string(SaveSystem.slot_path(SaveSystem.ROUND_START))
	GameState.combat_snapshot["journal"] = {"last_command": 7}
	assert_eq(SaveSystem.save_combat_recovery(), OK)
	assert_eq(FileAccess.get_file_as_string(SaveSystem.slot_path(SaveSystem.ROUND_START)), round_before)
	assert_true(AtomicJson.read(SaveSystem.slot_path(SaveSystem.COMBAT_RECOVERY))["combat"].has("journal"))
	var round_data := AtomicJson.read(SaveSystem.slot_path(SaveSystem.ROUND_START))
	var command_data := AtomicJson.read(SaveSystem.slot_path(SaveSystem.COMBAT_RECOVERY))
	command_data["saved_at"] = round_data["saved_at"]
	assert_eq(AtomicJson.write(SaveSystem.slot_path(SaveSystem.COMBAT_RECOVERY), command_data), OK)
	for slot: String in ["manual_same_second", SaveSystem.MOBILE_CHECKPOINT, SaveSystem.AUTOSAVE]:
		assert_eq(AtomicJson.write(SaveSystem.slot_path(slot), round_data), OK)
	assert_eq(str(SaveSystem.list_slots()[0]["slot"]), SaveSystem.COMBAT_RECOVERY, "Continue prefers the command continuation when timestamps tie")
	SaveSystem.clear_combat_recovery("another_location", "wolves")
	assert_true(SaveSystem.has_slot(SaveSystem.COMBAT_RECOVERY))
	SaveSystem.clear_combat_recovery("into_the_mists_road", "wolves")
	assert_false(SaveSystem.has_slot(SaveSystem.COMBAT_RECOVERY))
	assert_eq(FileAccess.get_file_as_string(SaveSystem.slot_path(SaveSystem.ROUND_START)), round_before)
	GameState.from_dict(before)


func test_honour_checkpoints_keep_the_single_campaign_slot() -> void:
	var before := GameState.to_dict()
	GameState.reset()
	GameState.story.options["difficulty"] = "honour"
	SaveSystem.current_slot = "honour_campaign"
	assert_eq(SaveSystem.save_mobile_checkpoint(), OK)
	assert_true(SaveSystem.has_slot("honour_campaign"))
	assert_false(SaveSystem.has_slot(SaveSystem.MOBILE_CHECKPOINT))
	assert_eq(SaveSystem.current_slot, "honour_campaign")
	GameState.from_dict(before)
