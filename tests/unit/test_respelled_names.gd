extends TestCase
## The Wizard is "Ratatouille" (owner, 2026-10-12), and a save an older build wrote calls him by the old spelling: in
## his build, the run's stats and a fight's log. SaveSystem.upgrade respells every string a save holds when it's read,
## whatever its version, so the Load list and the game both show the name as it is spelled now. Ids stay lowercase and
## as they were, and so does the player's own note. The golden saves in tests/saves keep the old spelling for this.

const OLD_SAVE := "res://tests/saves/v2_new_game.json"


static func _old_in(v: Variant) -> bool:
	var text := JSON.stringify(v)
	for old: String in SaveSystem.RESPELLED:
		if text.contains(old):
			return true
	return false


static func _read(path: String) -> Dictionary:
	return JSON.parse_string(FileAccess.get_file_as_string(path)) as Dictionary


func test_an_old_save_calls_the_wizard_by_his_name_now() -> void:
	var raw := _read(OLD_SAVE)
	assert_true(_old_in(raw), "the golden save still has the old spelling")
	var up := SaveSystem.upgrade(raw)
	assert_false(_old_in(up), "nothing in the save says it the old way")
	assert_true(_old_in(raw), "the save read from disk is left as it was")
	var wizard := {}
	var story := up["story"] as Dictionary
	for m: Variant in (story["party"] as Array) + (story["bench"] as Array):
		if str((m as Dictionary).get("id", "")) == "ratatoille":
			wizard = m as Dictionary
	assert_eq(str((wizard.get("build", {}) as Dictionary).get("name", "")), "Ratatouille", "his name")
	assert_eq(str(wizard.get("id", "")), "ratatoille", "his id is the same")


func test_ids_and_the_players_note_stay_as_they_were() -> void:
	var old: String = SaveSystem.RESPELLED.keys()[0]
	var save := {"version": GameState.SAVE_VERSION, "note": "%s burnt the stew" % old,
		"story": {"party": [{"id": "ratatoille", "build": {"name": old, "appearance": {"art": "ratatoille"}}}],
			"flags": {"ratatoille_supper_cooked": true}, "run_stats": {"heroes": {"ratatoille": {"name": old}}}},
		"combat": {"data": {"log": [{"text": "%s casts Fire Bolt." % old, "details": ["%s: 1d20 + 5" % old]}]}}}
	var up := SaveSystem.upgrade(save)
	var story := up["story"] as Dictionary
	var hero := (story["party"] as Array)[0] as Dictionary
	assert_eq(hero["build"]["name"], "Ratatouille", "the name in his build")
	assert_eq(hero["id"], "ratatoille", "the id")
	assert_eq(hero["build"]["appearance"]["art"], "ratatoille", "the art he wears")
	assert_true((story["flags"] as Dictionary).has("ratatoille_supper_cooked"), "a flag named for him")
	assert_eq(story["run_stats"]["heroes"]["ratatoille"]["name"], "Ratatouille", "the run's stats")
	var entry := (up["combat"]["data"]["log"] as Array)[0] as Dictionary
	assert_eq(entry["text"], "Ratatouille casts Fire Bolt.", "the fight's log")
	assert_eq(entry["details"], ["Ratatouille: 1d20 + 5"], "and its details")
	assert_eq(up["note"], save["note"], "the player's own note")


func test_the_load_list_shows_the_new_spelling() -> void:
	# The list names the travelling party, and he waits at camp in the golden save: bring him along.
	var save := _read(OLD_SAVE)
	var story := save["story"] as Dictionary
	(story["party"] as Array).append_array(story["bench"] as Array)
	var dir := "user://test_respelled_names"
	DirAccess.make_dir_recursive_absolute(dir)
	var f := FileAccess.open(dir.path_join("old.json"), FileAccess.WRITE)
	f.store_string(JSON.stringify(save))
	f.close()
	var said := SaveSystem.describe("old", dir)
	DirAccess.remove_absolute(dir.path_join("old.json"))
	DirAccess.remove_absolute(dir)
	assert_true(str(said.get("party", "")).contains("Ratatouille"), "the party: %s" % said.get("party", ""))
	assert_false(_old_in(said), "no old spelling")


func test_a_loaded_old_save_shows_the_new_spelling() -> void:
	GameState.from_dict(SaveSystem.upgrade(_read(OLD_SAVE)))
	var names: Array[String] = []
	for ch in GameState.story.roster():
		names.append(ch.name)
	GameState.reset()
	assert_true("Ratatouille" in names, "the roster: %s" % [names])


func test_the_wizard_built_today_keeps_his_id() -> void:
	var ch := Pregens.build("ratatoille", 1)
	assert_eq(ch.name, "Ratatouille", "his name")
	assert_eq(ch.id, "ratatoille", "the id saves, flags, art and voice are keyed by")
	assert_true(StoryState.member_matches(ch, "name:ratatoille"), "the story still finds him")
	assert_eq(VoiceOver.voice_for(ch), "ratatoille", "his own voice")
	assert_eq(DialogueRunner.portrait_of(ch), "ratatoille", "his own portrait")
	var b := CharacterBuilder.new(null, {"name": "Ratatouille", "appearance": {"custom": true}})
	assert_false(b.name_problems().is_empty(), "a hero of your own can't take his name")
