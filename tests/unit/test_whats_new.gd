extends TestCase
## The title's What's new (Q2, ui/menu/whats_new.gd): which of the play copy's changes the player hasn't seen yet,
## and the panel that lists them by day and marks them seen when it closes.

const DAY := 86400
const NOW := 1_791_400_000


func before_each() -> void:
	WhatsNew.seen_path = SaveSystem.save_dir.path_join("whats_new.cfg")   # never the player's own
	DirAccess.make_dir_recursive_absolute(SaveSystem.save_dir)
	if FileAccess.file_exists(WhatsNew.seen_path):
		DirAccess.remove_absolute(WhatsNew.seen_path)
	WhatsNew.build_override = _build()


func after_each() -> void:
	if FileAccess.file_exists(WhatsNew.seen_path):
		DirAccess.remove_absolute(WhatsNew.seen_path)
	WhatsNew.build_override = {}
	WhatsNew.seen_path = "user://whats_new.cfg"


func _build(extra: Array = []) -> Dictionary:
	var changes: Array = extra.duplicate()
	changes.append_array([
		{"commit": "cccc0003", "date": "2026-10-07", "at": NOW, "lines": ["Echo Knight fitted to the 2024 Fighter"]},
		{"commit": "cccc0002", "date": "2026-10-06", "at": NOW - DAY, "lines": ["Pit traps", "Fresh dice on every load"]},
		{"commit": "cccc0001", "date": "2026-10-01", "at": NOW - 6 * DAY, "lines": ["Old news"]}])
	var head := changes[0] as Dictionary
	return {"commit": head["commit"], "committed": "%sT12:00:00-04:00" % head["date"], "committed_at": head["at"],
		"changes": changes}


func _lines(changes: Array[Dictionary]) -> Array[String]:
	var out: Array[String] = []
	for c in changes:
		for l: Variant in c["lines"]:
			out.append(str(l))
	return out


func _texts(root: Node) -> Array[String]:
	var out: Array[String] = []
	for n in root.find_children("*", "Label", true, false):
		out.append((n as Label).text)
	return out


func test_the_first_time_it_shows_the_last_few_days() -> void:
	assert_eq(_lines(WhatsNew.unseen()), ["Echo Knight fitted to the 2024 Fighter", "Pit traps", "Fresh dice on every load"],
		"the newest three days, not the week-old change")


func test_once_seen_only_newer_changes_show() -> void:
	WhatsNew.mark_seen()
	assert_true(WhatsNew.unseen().is_empty(), "nothing is new right after it was seen")
	WhatsNew.build_override = _build([{"commit": "cccc0004", "date": "2026-10-08", "at": NOW + DAY, "lines": ["Undo a move"]}])
	assert_eq(_lines(WhatsNew.unseen()), ["Undo a move"], "the next play copy shows only what it added")


func test_the_panel_lists_them_by_day_and_closing_marks_them_seen() -> void:
	var host := Control.new()
	add_child(host)
	var layer := WhatsNew.open(host)
	var texts := _texts(layer)
	assert_true("What's new" in texts, "titled")
	assert_true("Wednesday 7 October" in texts and "Tuesday 6 October" in texts, "a heading per day")
	assert_true("Pit traps" in texts, "each change on its own line")
	assert_false("Old news" in texts, "what came before the last few days stays out")
	var close: Button = null
	for b in layer.find_children("*", "Button", true, false):
		if (b as Button).text == "Close":
			close = b as Button
	assert_true(close != null, "a Close button")
	close.pressed.emit()
	assert_true(WhatsNew.unseen().is_empty(), "closing marks them seen")
	assert_eq(WhatsNew.seen_at(), NOW, "up to the copy's commit")
	host.free()


func test_the_title_opens_it_only_as_the_games_own_scene() -> void:
	var host := Control.new()
	add_child(host)
	WhatsNew.show_if_new(host)
	assert_eq(host.get_child_count(), 0, "inside a test or a capture the title never opens it by itself")
	host.free()


func test_without_a_list_there_is_nothing_to_show() -> void:
	WhatsNew.build_override = {"commit": "cccc0003", "changes": []}
	assert_false(WhatsNew.available(), "no changes, no button")
	assert_true(WhatsNew.unseen().is_empty(), "and nothing opens")
