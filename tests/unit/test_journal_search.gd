extends TestCase
## The journal's quest search (Ashwin, 2026-10-19): it finds a quest by what the journal shows of it (the name, who gave it, its
## place, the entries of the stages reached, the objectives), never by the summary or the hint, which the card doesn't show; the
## chips keep All, Open, Done or Failed; a list with nothing to show says why and offers to clear the search; Esc or B in the
## box clears it and leaves it; Ctrl+F, / and Y go to the box.


func _story() -> StoryState:
	var st := StoryState.new()
	st.set_quest_stage("death_house", "plea")
	st.advance_minutes(10)
	st.set_quest_stage("the_priests_son", "doru_destroyed")
	st.advance_minutes(10)
	st.set_quest_stage("escort_ireena", "asked")
	st.advance_minutes(10)
	st.set_quest_stage("the_oat_thief", "rumored")
	return st


func _journal(st: StoryState) -> JournalScreen:
	var j := JournalScreen.new()
	add_child(j)
	j.open(self, st, 0)
	return j


func _row(j: JournalScreen, quest_id: String) -> Node:
	return j.find_child("Quest_" + quest_id, true, false)


func _type(j: JournalScreen, text: String) -> void:
	var box := j.find_child("QuestSearch", true, false) as LineEdit
	box.text = text
	box.text_changed.emit(text)


func _quest(st: StoryState, id: String) -> Dictionary:
	for q in QuestLog.journal(st):
		if str(q["id"]) == id:
			return q
	return {}


func _key(code: Key, ctrl: bool = false) -> InputEventKey:
	var ev := InputEventKey.new()
	ev.keycode = code
	ev.physical_keycode = code
	ev.pressed = true
	ev.ctrl_pressed = ctrl
	return ev


func _texts(n: Node) -> Array[String]:
	var out: Array[String] = []
	for l in n.find_children("*", "Label", true, false):
		out.append((l as Label).text)
	return out


# --- What the search looks at -------------------------------------------------------------------------

func test_the_giver_is_in_the_journal_and_searchable() -> void:
	var st := _story()
	var oat := _quest(st, "the_oat_thief")
	assert_eq(str(oat["giver"]), "bildrath")
	assert_eq(str(oat["giver_name"]), "Bildrath Cantemir")
	assert_true(JournalScreen.matches("cantemir", oat), "found by who gave it")
	assert_true(JournalScreen.matches("bildrath oat", oat), "with words of its name besides")
	assert_false(JournalScreen.matches("cantemir", _quest(st, "escort_ireena")), "and not the other quests")
	var j := _journal(st)
	j.pad_trigger(1)
	_type(j, "cantemir")
	assert_true(_row(j, "the_oat_thief") != null and _row(j, "the_priests_son") == null, "the list keeps the quest he gave")
	assert_true(_texts(j).has("Given by Bildrath Cantemir"), "and its card says who gave it")
	j.free()


func test_the_place_and_the_entries_are_searched_but_not_the_summary_or_the_hint() -> void:
	var q := {"name": "A Plain Name", "giver_name": "Old Giver", "region": "vallaki", "summary": "secretly the vampire's doing",
		"entries": ["The ledger is missing."], "objectives": ["Find the ledger"], "hint": "ask the cobbler"}
	assert_true(JournalScreen.matches("plain", q), "name")
	assert_true(JournalScreen.matches("giver", q), "giver")
	assert_true(JournalScreen.matches("vallaki", q), "place")
	assert_true(JournalScreen.matches("ledger missing", q), "entry")
	assert_true(JournalScreen.matches("find ledger", q), "objective")
	assert_false(JournalScreen.matches("vampire", q), "not the summary: the card never shows it")
	assert_false(JournalScreen.matches("cobbler", q), "not the hint")


func test_only_the_stages_reached_are_searched() -> void:
	var st := _story()
	var q := _quest(st, "the_oat_thief")
	var later := ""
	for s: Variant in Compendium.shared().get_entry("quests", "the_oat_thief")["stages"]:
		later = str((s as Dictionary)["journal"])   # the last stage's words
	assert_false((q["entries"] as Array).has(later), "the story hasn't got that far")
	var words := later.split(" ", false)
	var unique := ""
	for w in words:
		if w.length() > 7 and not JournalScreen.matches(w, q):
			unique = w
			break
	assert_true(unique != "", "a word only the unreached stage has")
	assert_false(JournalScreen.matches(unique, q), "is not found")


# --- The chips -------------------------------------------------------------------------------------------

func test_the_chips_keep_open_done_or_failed_quests() -> void:
	var st := _story()
	var j := _journal(st)
	j.pad_trigger(1)
	assert_true(_row(j, "the_oat_thief") != null and _row(j, "the_priests_son") != null, "All: open and finished")
	assert_eq((j.find_child("Chip_all", true, false) as Button).text, "All  2", "with how many each keeps")
	assert_eq((j.find_child("Chip_active", true, false) as Button).text, "Open  1")
	assert_eq((j.find_child("Chip_success", true, false) as Button).text, "Done  1")
	assert_eq((j.find_child("Chip_failure", true, false) as Button).text, "Failed  0")
	(j.find_child("Chip_success", true, false) as Button).pressed.emit()
	assert_eq(j.status_filter, "success")
	assert_true(_row(j, "the_priests_son") != null and _row(j, "the_oat_thief") == null, "Done: the finished ones")
	(j.find_child("Chip_active", true, false) as Button).pressed.emit()
	assert_true(_row(j, "the_oat_thief") != null and _row(j, "the_priests_son") == null, "Open: the open ones")
	(j.find_child("Chip_all", true, false) as Button).pressed.emit()
	assert_true(_row(j, "the_priests_son") != null, "All again")
	j.free()


func test_a_list_with_nothing_says_why_and_clears() -> void:
	var st := _story()
	var j := _journal(st)
	j.pad_trigger(1)
	(j.find_child("Chip_failure", true, false) as Button).pressed.emit()
	assert_true(_texts(j).has("No failed quests under Other."), str(_texts(j)))
	var clear := j.find_child("ClearSearch", true, false) as Button
	assert_true(clear != null and clear.text == "Show all", "a way out of the empty list")
	clear.pressed.emit()
	assert_eq(j.status_filter, "all")
	assert_true(_row(j, "the_oat_thief") != null, "the quests are back")
	_type(j, "nothing like this")
	assert_true(_texts(j).has("No quest matches \"nothing like this\"."), str(_texts(j)))
	clear = j.find_child("ClearSearch", true, false) as Button
	assert_true(clear != null and clear.text == "Clear search")
	clear.pressed.emit()
	assert_eq(j.search, "")
	assert_eq((j.find_child("QuestSearch", true, false) as LineEdit).text, "", "the box is emptied too")
	assert_true(_row(j, "the_oat_thief") != null, "and the list is back")
	_type(j, "oat")
	(j.find_child("Chip_success", true, false) as Button).pressed.emit()
	assert_true(_texts(j).has("No done quest matches \"oat\"."), str(_texts(j)))
	j.free()


# --- Getting to the box and leaving it ------------------------------------------------------------------

func test_ctrl_f_slash_and_y_go_to_the_box() -> void:
	var j := _journal(_story())
	var box := j.find_child("QuestSearch", true, false) as LineEdit
	assert_false(box.has_focus())
	j._unhandled_input(_key(KEY_F, true))
	assert_true(box.has_focus(), "Ctrl+F")
	box.release_focus()
	j._unhandled_input(_key(KEY_SLASH))
	assert_true(box.has_focus(), "/")
	box.release_focus()
	assert_true(j.pad_button(JOY_BUTTON_Y), "Y is the journal's")
	assert_true(box.has_focus(), "on a pad")
	assert_false(j.pad_button(JOY_BUTTON_X), "X isn't")
	assert_true(j.pad_prompts().any(func(p: Array) -> bool: return str(p[0]) == "y"), "and the prompt bar says so")
	j.pad_tab(1)
	assert_false(j.pad_button(JOY_BUTTON_Y), "not on the Codex page")
	j.free()


func test_esc_in_the_box_clears_it_and_leaves_it() -> void:
	var j := _journal(_story())
	j.pad_trigger(1)
	_type(j, "nothing like this")
	var box := j.find_child("QuestSearch", true, false) as LineEdit
	box.grab_focus()
	j._search_keys(_key(KEY_ESCAPE))
	assert_eq(j.search, "")
	assert_eq(box.text, "", "what was typed is gone")
	assert_false(box.has_focus(), "and the box is left")
	assert_true(_row(j, "the_oat_thief") != null, "the list is whole again")
	j.free()
