extends TestCase
## The journal's quest page (Ashwin, 2026-10-09: "make it tabular for main / other. Be able to select a current quest,
## search for a quest"): Main and Other tabs, a list beside the picked quest, a search box over both, and Track, which
## makes a quest the one the HUD follows.


## The story's spine is under Main (the quest's `kind`); side and companion quests are under Other.
func test_main_and_other() -> void:
	var main := 0
	for q: Dictionary in Compendium.shared().all("quests"):
		if QuestLog.kind(str(q["id"])) == "main":
			main += 1
	assert_true(main >= 10 and main <= 20, "a short Main tab (%d)" % main)
	for id: String in ["into_the_mists", "death_house", "escort_ireena", "madam_evas_reading", "find_the_tome", "strahds_lair"]:
		assert_eq(QuestLog.kind(id), "main", id)
	for id: String in ["the_oat_thief", "the_ladle", "wizard_of_wines", "the_priests_son"]:
		assert_eq(QuestLog.kind(id), "other", id)


## One quest at a time is tracked; it's saved with the story; a finished one isn't tracked any more.
func test_tracking_one_quest() -> void:
	var st := _story()
	assert_eq(QuestLog.tracked(st), "", "nothing tracked to begin with")
	QuestLog.track(st, "the_oat_thief")
	assert_eq(QuestLog.tracked(st), "the_oat_thief")
	QuestLog.track(st, "escort_ireena")
	assert_eq(QuestLog.tracked(st), "escort_ireena", "tracking another stops the first")
	var back := StoryState.from_dict(JSON.parse_string(JSON.stringify(st.to_dict())) as Dictionary)
	assert_eq(QuestLog.tracked(back), "escort_ireena", "kept through a save and load")
	QuestLog.track(st, "")
	assert_eq(QuestLog.tracked(st), "", "and Stop tracking follows none")
	QuestLog.track(st, "the_priests_son")
	assert_eq(QuestLog.tracked(st), "", "a finished quest can't be followed")


## The HUD shows the tracked quest's objective, else the newest open quest's.
func test_the_hud_follows_the_tracked_quest() -> void:
	var st := _story()
	var hud := ExploreHud.new()
	add_child(hud)
	hud.build(st)
	assert_eq(str(hud.call("_objective")), "◆ Watch the north path at night", "the newest open quest's")
	QuestLog.track(st, "escort_ireena")
	assert_eq(str(hud.call("_objective")), "◆ Help bury the burgomaster", "the tracked one's")
	hud.free()


## The journal opens on Main with its list and the picked quest; LT/RT turn to Other; Track there makes the HUD follow
## it, and the journal opens on it next time; the search finds quests under either tab; LB/RB still turn the pages.
func test_the_quest_page() -> void:
	var st := _story()
	var j := _journal(st)
	assert_eq(j.quest_tab, "Main", "Main while it has an open quest")
	assert_true(_row(j, "escort_ireena") != null, "Ireena's Escort in the Main list")
	assert_true(_row(j, "the_oat_thief") == null, "The Oat Thief isn't")
	assert_eq(j.picked, "escort_ireena", "the newest open main quest is picked")
	j.pad_trigger(1)
	assert_eq(j.quest_tab, "Other")
	assert_true(_row(j, "the_oat_thief") != null and _row(j, "the_priests_son") != null, "Other lists open and finished")
	assert_eq(j.picked, "the_oat_thief", "open quests come first")
	assert_true(j.find_child("Track_the_priests_son", true, false) == null)
	var track := j.find_child("Track_the_oat_thief", true, false) as Button
	assert_true(track != null, "the picked open quest has Track")
	track.pressed.emit()
	assert_eq(QuestLog.tracked(st), "the_oat_thief")
	assert_eq((j.find_child("Track_the_oat_thief", true, false) as Button).text, "Stop tracking")
	j.free()
	j = _journal(st)
	assert_eq(j.quest_tab, "Other", "the journal opens on the tracked quest's tab")
	assert_eq(j.picked, "the_oat_thief", "with it picked")
	var box := j.find_child("QuestSearch", true, false) as LineEdit
	box.text = "burgomaster"
	box.text_changed.emit(box.text)
	assert_eq(j.quest_tab, "Main", "a search with nothing under Other turns to Main")
	assert_true(_row(j, "escort_ireena") != null)
	assert_true(box.is_inside_tree(), "the search box stays while the list redraws")
	box.text = "nothing like this"
	box.text_changed.emit(box.text)
	assert_true(j.find_child("QuestEntry", true, false) == null, "no quest shown when nothing matches")
	j.pad_tab(1)
	assert_eq(j.tab, "Codex", "LB/RB still turn the journal's pages")
	j.free()


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
