extends TestCase
## Report a bug (core/bug_reports.gd, ui/screens/bug_report_screen.gd; owner 2026-10-11), in dev builds only: F12 or
## the pause menu's link opens a screen over the paused game; Send writes report.md, the picture and a copy of the
## game into the reports folder, never into the saves or settings.cfg; Cancel, Escape and B write nothing.

const GOLDEN := "v2_vallaki"

var reports: BugReports
var out := ""
var menu: PauseMenu = null


func before_each() -> void:
	InputActions.ensure()   # Escape and B are the game's combat_cancel, as the game root sets them up
	reports = BugReports.current   # UiFeel's: tests run on the editor's Godot, a dev build
	out = SaveSystem.save_dir.path_join("bug_reports_test")
	if reports != null:
		reports.dir = out


func after_each() -> void:
	if reports != null:
		if reports.screen != null and is_instance_valid(reports.screen):
			reports.screen.close()
		reports.dir = ""
	if menu != null:
		menu.queue_free()
		menu = null
	await _frames(1)
	get_tree().paused = false
	_remove(ProjectSettings.globalize_path(out))
	GameState.reset()
	SaveSystem.current_slot = ""


## The pause menu's Resume and Escape call this on whatever opened it.
func close_screen() -> void:
	pass


func _frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame


func _remove(path: String) -> void:
	if not DirAccess.dir_exists_absolute(path):
		return
	for d in DirAccess.get_directories_at(path):
		_remove(path.path_join(d))
	for f in DirAccess.get_files_at(path):
		DirAccess.remove_absolute(path.path_join(f))
	DirAccess.remove_absolute(path)


## A game going: the golden save at Vallaki, loaded from tests/saves (so the saves folder isn't touched).
func _game() -> void:
	assert_eq(SaveSystem.load_from(GoldenSaves.DIR, GOLDEN), OK, "the golden save loads")
	SaveSystem.take_recap()


func _reports_made() -> Array[String]:
	var out_: Array[String] = []
	var base := ProjectSettings.globalize_path(out)
	if DirAccess.dir_exists_absolute(base):
		out_.assign(DirAccess.get_directories_at(base))
	return out_


func _key(code: Key, command := false) -> InputEventKey:
	var k := InputEventKey.new()
	k.keycode = code
	k.physical_keycode = code
	k.meta_pressed = command
	k.pressed = true
	return k


func test_only_in_dev_builds() -> void:
	assert_true(BugReports.enabled(), "the editor's Godot (make run, make play, tests) is a dev build")
	assert_true(reports != null and UiFeel.bug_reports == reports, "UiFeel keeps the one BugReports")
	# An exported game runs on an export template: no node, so no key and no menu entry.
	assert_false(OS.has_feature("template"), "an export template is never a dev build")


func test_a_report_holds_the_words_the_picture_where_the_game_is_and_a_copy_of_it() -> void:
	_game()
	var st := GameState.story
	var saves_before := Array(DirAccess.get_files_at(SaveSystem.save_dir)) if DirAccess.dir_exists_absolute(SaveSystem.save_dir) else []
	var settings_before := FileAccess.get_md5(GameSettings.path) if FileAccess.file_exists(GameSettings.path) else ""
	var context := reports.gather("F12")
	assert_true(str(context["place"]).contains("Vallaki"), "where the party is")
	assert_eq((context["party"] as Array).size(), st.party.size() + st.guests.size(), "a line for each of the party")
	assert_true(str(context["clock"]).begins_with("Day %d" % st.day), "the day and the hour")
	assert_true(str(context["build"]) != "", "the build")
	var shot := Image.create(64, 36, false, Image.FORMAT_RGB8)
	shot.fill(Color(0.4, 0.05, 0.05))
	var folder := reports.write("The door won't open\nI clicked it twice.", "Plays wrong", shot, context, reports.snapshot())
	assert_true(folder.begins_with(ProjectSettings.globalize_path(out)), "into the reports folder")
	assert_true(folder.get_file().ends_with("-the-door-won-t-open"), "named by when, then its first words: %s" % folder.get_file())
	var md := FileAccess.get_file_as_string(folder.path_join("report.md"))
	for want: String in ["status: open", "kind: \"Plays wrong\"", "place: \"%s\"" % st.location, "# The door won't open",
			"I clicked it twice.", "![screenshot](screenshot.png)", "- Place: ", "Vallaki", "## Errors this session",
			"## The log's last lines", "- save.json: "]:
		assert_true(md.contains(want), "report.md has %s" % want)
	for ch in st.party:
		assert_true(md.contains(ch.name), "and %s in the party" % ch.name)
	var img := Image.load_from_file(folder.path_join("screenshot.png"))
	assert_true(img != null and img.get_size() == Vector2i(64, 36), "the picture beside it")
	GameState.reset()
	assert_eq(SaveSystem.load_from(folder, "save"), OK, "the copy of the game loads as a save")
	assert_eq(GameState.story.location, st.location, "at the same place")
	assert_eq(GameState.story.party.size(), st.party.size(), "with the same party")
	assert_true(FileAccess.file_exists(ProjectSettings.globalize_path(out).path_join("README.md")), "the folder says what's in it")
	var saves_after := Array(DirAccess.get_files_at(SaveSystem.save_dir)) if DirAccess.dir_exists_absolute(SaveSystem.save_dir) else []
	assert_eq(saves_after, saves_before, "nothing written into the saves")
	assert_eq(FileAccess.get_md5(GameSettings.path) if FileAccess.file_exists(GameSettings.path) else "", settings_before,
		"nor the settings")


func test_titles_and_folder_names() -> void:
	var at := {"place": "Vallaki (vallaki)", "place_id": "vallaki"}
	assert_eq(BugReports.title_of("", "", at), "A bug in Vallaki", "nothing written: named for the place")
	assert_eq(BugReports.title_of("\n  \n", "Sound", at), "Sound in Vallaki", "or the kind picked")
	assert_eq(BugReports.title_of("", "", {"place": "none (no game going)", "place_id": ""}), "A bug", "at the title screen")
	assert_eq(BugReports.title_of("  Rats  \nmore", "", at), "Rats", "else the first line written")
	var long := BugReports.title_of("word ".repeat(30), "", at)
	assert_true(long.length() <= 73 and long.ends_with("…"), "cut at a word: %s" % long)
	assert_eq(BugReports.slug("The door won't open!"), "the-door-won-t-open")
	assert_eq(BugReports.slug("one two three four five six seven"), "one-two-three-four-five-six", "six words at most")
	assert_eq(BugReports.slug("!!! ???"), "bug", "never empty")
	var context := reports.gather("F12")
	var first := reports.write("Same", "", null, context, {})
	var second := reports.write("Same", "", null, context, {})
	assert_true(first != "" and second != "" and first != second, "two reports in one second get folders of their own")
	assert_false(FileAccess.file_exists(first.path_join("save.json")), "no game going: no copy of one")
	assert_true(FileAccess.get_file_as_string(first.path_join("report.md")).contains("- Party: none"), "and no party")


func test_errors_and_the_log_go_in() -> void:
	ErrorWatch.recent.append({"script": true, "where": "res://world/x.gd:12", "text": "Cannot call method 'foo' on a null value.",
		"time": "2026-10-11 12:00:00"})
	var context := reports.gather("F12")
	ErrorWatch.recent.pop_back()
	context["log"] = ["Godot Engine v4.7.2", "a line ``` with fences"] as Array[String]
	var md := BugReports.markdown("", "", "A bug", context, [] as Array[String])
	assert_true(md.contains("[2026-10-11 12:00:00] SCRIPT ERROR at res://world/x.gd:12: Cannot call method 'foo' on a null value."),
		"this session's errors")
	assert_true(md.contains("Godot Engine v4.7.2"), "the log's last lines")
	assert_eq(md.count("```"), 4, "fenced, with a fence in a line taken out")


func test_the_screen_pauses_the_game_and_send_writes_the_report() -> void:
	_game()
	await reports.open()
	var screen := reports.screen
	assert_true(screen != null and screen.is_inside_tree(), "F12's screen is open")
	assert_true(get_tree().paused, "the game waits while he writes")
	await _frames(2)
	screen.words.text = "A rat walks through the wall"
	var kind := screen.find_child("KindLookswrong", true, false) as Button
	kind.button_pressed = true
	assert_eq(screen.kind, "Looks wrong", "a kind picked")
	kind.button_pressed = false
	assert_eq(screen.kind, "", "and taken back")
	(screen.find_child("KindRules", true, false) as Button).button_pressed = true
	screen._input(_key(KEY_ENTER, true))
	assert_true(screen.sent_to != "", "Cmd+Enter sends")
	var md := FileAccess.get_file_as_string(screen.sent_to.path_join("report.md"))
	assert_true(md.contains("# A rat walks through the wall") and md.contains("kind: \"Rules\""), "what he wrote and picked")
	assert_true(md.contains("with F12"), "and how it was opened")
	assert_true(screen.find_child("SentTo", true, false) != null, "the screen says where it went")
	var done := screen.find_child("Done", true, false) as Button
	assert_true(done != null, "with a way out")
	done.pressed.emit()
	await _frames(1)
	assert_true(reports.screen == null, "closed")
	assert_false(get_tree().paused, "and the game goes on as it was")
	assert_eq(_reports_made().size(), 1, "one report")


func test_cancel_escape_and_b_write_nothing() -> void:
	for way: String in ["Cancel", "Escape", "B"]:
		await reports.open()
		var screen := reports.screen
		await _frames(1)
		screen.words.text = "never sent"
		match way:
			"Cancel":
				(screen.find_child("Cancel", true, false) as Button).pressed.emit()
			"Escape":
				screen._input(_key(KEY_ESCAPE))
			"B":
				var b := InputEventAction.new()
				b.action = &"combat_cancel"
				b.pressed = true
				screen._unhandled_input(b)
		await _frames(1)
		assert_true(reports.screen == null, "%s closes it" % way)
		assert_false(get_tree().paused, "and the game goes on")
	assert_true(_reports_made().is_empty(), "nothing written")


func test_f12_opens_it_once() -> void:
	reports._input(_key(BugReports.KEY))
	await _frames(1)
	var screen := reports.screen
	assert_true(screen != null, "F12 opens the screen")
	reports._input(_key(BugReports.KEY))
	await _frames(1)
	assert_eq(get_tree().root.find_children("*", "BugReportScreen", false, false).size(), 1, "a second F12 opens no second one")
	screen.close()


func test_the_pause_menu_steps_aside_for_it() -> void:
	_game()
	menu = PauseMenu.new()
	add_child(menu)
	menu.open(self, GameState.story, 0)
	await _frames(2)
	var link := menu.find_child("ReportBug", true, false) as Button
	assert_true(link != null, "a dev build's menu has Report a bug")
	if link == null:
		return
	assert_true(link in PadNav.choices(menu), "which the pad reaches")
	# Three links side by side inside the arch, none over another.
	var row: Array[Button] = []
	for b in menu.find_children("*", "Button", true, false):
		if absf((b as Button).position.y - link.position.y) < 1.0:
			row.append(b as Button)
	assert_eq(row.size(), 3, "Settings, Cheat codes and Report a bug")
	row.sort_custom(func(a: Button, b: Button) -> bool: return a.position.x < b.position.x)
	var arch := PauseMenu.W_U * PauseMenu.K
	assert_true(row[0].position.x >= 9.0 * PauseMenu.K and row[2].position.x + row[2].size.x <= arch - 9.0 * PauseMenu.K,
		"inside the arch's inner line")
	for i in range(1, row.size()):
		assert_true(row[i].position.x >= row[i - 1].position.x + row[i - 1].size.x, "%s clear of %s" % [row[i].text, row[i - 1].text])
	link.pressed.emit()
	await _frames(3)
	var screen := reports.screen
	assert_true(screen != null, "it opens the report screen")
	assert_false(menu.visible, "with the arch out of the way (and out of the picture)")
	assert_true(str(screen.context.get("screen", "")).contains("the pause menu"), "noting where it came from")
	screen.close()
	await _frames(1)
	assert_true(menu.visible, "the arch comes back when it closes")
