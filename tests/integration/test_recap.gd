extends TestCase
## "Previously in Barovia" (Q3, ui/exploration/recap.gd): loading a game saved a while ago opens the Narrator's box with
## a recap of where the party is, the road ahead and its last big choice. A fresh save (a quick reload) and a fight's
## round start get none.

var root: Node
var _real_dir := ""


func before_each() -> void:
	_real_dir = SaveSystem.save_dir
	SaveSystem.save_dir = _real_dir.path_join("recap/")
	DirAccess.make_dir_recursive_absolute(SaveSystem.save_dir)
	ModeController.force(ModeController.Mode.EXPLORATION)
	SaveSystem.take_recap()
	Recap.always = true


func after_each() -> void:
	Recap.always = false
	SaveSystem.take_recap()
	if root != null:
		root.queue_free()
		root = null
	for f in DirAccess.get_files_at(SaveSystem.save_dir):
		DirAccess.remove_absolute(SaveSystem.save_dir.path_join(f))
	DirAccess.remove_absolute(SaveSystem.save_dir)
	SaveSystem.save_dir = _real_dir
	SaveSystem.current_slot = ""
	GameState.reset()


func _frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame


## Golden save `f` (tests/saves) copied in as `slot`, with its saved_at moved to `minutes_ago`.
func _old_save(f: String, slot: String, minutes_ago: int) -> void:
	var data := JSON.parse_string(FileAccess.get_file_as_string(GoldenSaves.DIR + f)) as Dictionary
	var now := Time.get_unix_time_from_datetime_string(Time.get_datetime_string_from_system())
	data["saved_at"] = Time.get_datetime_string_from_unix_time(now - minutes_ago * 60)
	var out := FileAccess.open(SaveSystem.slot_path(slot), FileAccess.WRITE)
	out.store_string(JSON.stringify(data))
	out.close()


func _game() -> void:
	root = (load("res://scenes/game.tscn") as PackedScene).instantiate()
	add_child(root)
	await _frames(3)


func test_a_game_saved_a_while_ago_opens_with_the_recap() -> void:
	_old_save("v2_vallaki.json", "old", 90)
	assert_eq(SaveSystem.load_slot("old"), OK)
	await _game()
	Recap.show_on(root)
	var hud := root.get("hud") as ExploreHud
	assert_true(hud.narration_showing(), "the Narrator's box opens")
	var said := str((hud.get("_narr") as RichTextLabel).text)
	assert_true(said.contains("Vallaki"), "it says where the party is: %s" % said)
	assert_false(SaveSystem.take_recap(), "once")


func test_a_quick_reload_and_a_round_start_have_none() -> void:
	_old_save("v2_vallaki.json", "fresh", 2)
	assert_eq(SaveSystem.load_slot("fresh"), OK)
	assert_false(SaveSystem.take_recap(), "saved two minutes ago: no recap")
	_old_save("v2_vallaki.json", SaveSystem.ROUND_START, 90)
	assert_eq(SaveSystem.load_slot(SaveSystem.ROUND_START), OK)
	assert_false(SaveSystem.take_recap(), "a fight's round start is a retry: no recap")
	_old_save("v2_vallaki.json", "old", 90)
	assert_eq(SaveSystem.load_slot("old"), OK)
	assert_true(SaveSystem.take_recap(), "an hour and a half ago: a recap")


func test_the_recap_names_the_place_the_road_and_the_last_choice() -> void:
	_old_save("v2_amber_temple.json", "late", 600)
	assert_eq(SaveSystem.load_slot("late"), OK)
	var st := GameState.story
	var narrator := Narrator.new()
	var region := str(Compendium.shared().get_entry("locations", st.location).get("region", ""))
	assert_true(narrator.has_trigger("recap:where:" + region), "a line for the %s" % region)
	# Two quests move; the newest is named first.
	st.set_quest_stage("the_amber_temple", str(((Compendium.shared().get_entry("quests", "the_amber_temple")["stages"] as Array)[0] as Dictionary)["id"]))
	assert_eq(int((st.quests["the_amber_temple"] as Dictionary)["at"]), st.total_minutes(), "a quest notes when it moved")
	st.advance_minutes(30)
	Approval.change(st, "thistle", 2, "You laid Rose and Thorn to rest")
	var beats := Recap.lines(st, narrator)
	var text := "\n".join(beats.map(func(b: Dictionary) -> String: return str(b["text"])))
	assert_true(text.begins_with("Previously") or text.begins_with("Where") or text.begins_with("The mists"), "the Narrator opens: %s" % text)
	assert_true(text.contains("Amber Temple"), "where the party is")
	assert_true(text.contains("Ahead of you:"), "the road ahead")
	assert_true(Recap.road_ahead(st).size() <= Recap.GOALS)
	assert_true(text.contains("Not long ago, you laid Rose and Thorn to rest."), "the last big choice: %s" % text)
	for b in beats:
		assert_eq(str(b["speaker_id"]), VoiceOver.NARRATOR, "in the Narrator's voice")


func test_every_region_has_a_place_line() -> void:
	var narrator := Narrator.new()
	var regions := {}
	for loc: Dictionary in Compendium.shared().all("locations"):
		regions[str(loc.get("region", ""))] = true
	for r: String in regions:
		if r != "" and r != "test":
			assert_true(narrator.has_trigger("recap:where:" + r), "recap:where:%s" % r)
