extends TestCase
## Side quest failure plan, F1 (closures): a quest's `closes` rules end it without a line or a fight saying so. Made-up
## quests, so the rules under test don't move when a real quest's data does.

const QUESTS := {
	"test_closing": {"id": "test_closing", "name": "The Ledge", "summary": "A man on a ledge.", "stages": [
		{"id": "asked", "journal": "Asked.", "objectives": ["Climb up."], "hint": "The ledge.", "ends": ""},
		{"id": "climbing", "journal": "Climbing.", "objectives": ["Keep on."], "hint": "The ledge.", "ends": ""},
		{"id": "saved", "journal": "Saved.", "ends": "success"},
		{"id": "fell", "journal": "He fell.", "ends": "failure"},
		{"id": "carried", "journal": "Carried down at the last.", "ends": "success"}],
		"closes": [
			{"stage": "fell", "when": "quest_days.test_closing >= 3", "from": ["asked"], "warn": "He has been up there days."},
			{"stage": "carried", "when": "flag.test_fever", "from": ["climbing"]},
			{"stage": "fell", "leave": "test_region", "from": ["asked", "climbing"], "when": "flag.test_walked_off"},
			{"stage": "fell", "when": "flag.test_stuck", "old_saves": true}]},
	"test_next": {"id": "test_next", "name": "The Widow", "summary": "Whoever he left.", "stages": [
		{"id": "waiting", "journal": "Waiting.", "objectives": ["Wait."], "hint": "Home.", "ends": ""},
		{"id": "alone", "journal": "Alone.", "ends": "failure"}],
		"closes": [{"stage": "alone", "when": "quest.test_closing == fell"}]},
}


func before_each() -> void:
	for id: String in QUESTS:
		(Compendium.shared().tables["quests"] as Dictionary)[id] = (QUESTS[id] as Dictionary).duplicate(true)


func after_each() -> void:
	for id: String in QUESTS:
		(Compendium.shared().tables["quests"] as Dictionary).erase(id)


func _story() -> StoryState:
	var st := StoryState.new()
	st.party.append(TestChars.pregen("thistle", 1))
	return st


# --- A clock ------------------------------------------------------------------------------------------------------

func test_a_clock_rule_closes_the_quest_when_its_days_have_passed() -> void:
	var st := _story()
	st.set_quest_stage("test_closing", "asked")
	st.advance_minutes(2 * 24 * 60 + 60)
	assert_true(QuestClosures.sweep(st).is_empty(), "two days: the quest is still open")
	assert_eq(st.quest_stage("test_closing"), "asked")
	st.advance_minutes(24 * 60)
	assert_eq(QuestClosures.sweep(st), ["Quest failed: The Ledge"] as Array[String])
	assert_eq(st.quest_stage("test_closing"), "fell")
	assert_true(QuestClosures.sweep(st).is_empty(), "and it closes once")


func test_a_rule_waits_for_the_stage_it_names() -> void:
	var st := _story()
	st.set_quest_stage("test_closing", "asked")
	st.advance_minutes(24 * 60)
	st.set_quest_stage("test_closing", "climbing")
	st.advance_minutes(5 * 24 * 60)
	assert_true(QuestClosures.sweep(st).is_empty(), "the clock was for `asked`; the quest has moved on and restarted it")
	assert_eq(st.quest_stage("test_closing"), "climbing")


func test_a_rule_can_end_a_quest_in_a_quiet_success() -> void:
	var st := _story()
	st.set_quest_stage("test_closing", "climbing")
	st.set_flag("test_fever")
	assert_eq(QuestClosures.sweep(st), ["Quest complete: The Ledge"] as Array[String])
	assert_eq(st.quest_ending("test_closing"), "success")


func test_a_quest_that_has_not_begun_or_has_ended_is_left_alone() -> void:
	var st := _story()
	st.set_flag("test_fever")
	st.set_flag("test_walked_off")
	assert_true(QuestClosures.sweep(st, {"leaving": "test_region"}).is_empty())
	assert_eq(st.quest_stage("test_closing"), "", "a rule never starts a quest")
	st.set_quest_stage("test_closing", "saved")
	assert_true(QuestClosures.sweep(st, {"leaving": "test_region"}).is_empty())
	assert_eq(st.quest_stage("test_closing"), "saved", "nor takes a finished one back")


# --- Leaving a region ---------------------------------------------------------------------------------------------

func test_a_leave_rule_fires_only_as_the_party_leaves_that_region() -> void:
	var st := _story()
	st.set_quest_stage("test_closing", "asked")
	st.set_flag("test_walked_off")
	assert_true(QuestClosures.sweep(st).is_empty(), "the world has moved, but nobody is leaving")
	assert_true(QuestClosures.sweep(st, {"leaving": "elsewhere"}).is_empty(), "another region")
	assert_eq(QuestClosures.sweep(st, {"leaving": "test_region"}), ["Quest failed: The Ledge"] as Array[String])


# --- Old saves ----------------------------------------------------------------------------------------------------

func test_a_save_load_runs_only_the_rules_marked_for_old_saves() -> void:
	var st := _story()
	st.set_quest_stage("test_closing", "asked")
	st.set_flag("test_fever")
	st.set_flag("test_walked_off")
	st.advance_minutes(9 * 24 * 60)
	assert_true(QuestClosures.sweep(st, {"load": true}).is_empty(), "no clock, no departure, no fever: none is for an old save")
	assert_eq(st.quest_stage("test_closing"), "asked")
	st.set_flag("test_stuck")
	assert_eq(QuestClosures.sweep(st, {"load": true}).size(), 1)
	assert_eq(st.quest_stage("test_closing"), "fell")


func test_loading_a_save_mends_a_stuck_quest() -> void:
	var st := _story()
	st.set_quest_stage("test_closing", "climbing")
	st.set_flag("test_stuck")
	var back := StoryState.from_dict(JSON.parse_string(JSON.stringify(st.to_dict())) as Dictionary)
	assert_eq(back.quest_stage("test_closing"), "fell", "the stuck state is closed when the save loads")
	var fresh := _story()
	fresh.set_quest_stage("test_closing", "climbing")
	var again := StoryState.from_dict(JSON.parse_string(JSON.stringify(fresh.to_dict())) as Dictionary)
	assert_eq(again.quest_stage("test_closing"), "climbing", "and a quest in no such state is left as it was")


# --- One closure leads to another ---------------------------------------------------------------------------------

func test_a_closure_can_close_another_quest_in_the_same_sweep() -> void:
	var st := _story()
	st.set_quest_stage("test_closing", "asked")
	st.set_quest_stage("test_next", "waiting")
	st.advance_minutes(4 * 24 * 60)
	var said := QuestClosures.sweep(st)
	assert_eq(said.size(), 2)
	assert_true("Quest failed: The Ledge" in said and "Quest failed: The Widow" in said, str(said))
	assert_eq(st.quest_stage("test_next"), "alone")


# --- The journal's warning ----------------------------------------------------------------------------------------

func test_the_warning_shows_while_the_stage_holds() -> void:
	var st := _story()
	assert_eq(QuestClosures.warning(st, "test_closing"), "", "nothing before the quest begins")
	st.set_quest_stage("test_closing", "asked")
	assert_eq(QuestClosures.warning(st, "test_closing"), "He has been up there days.")
	var card := _card(st, "test_closing")
	assert_eq(str(card["warn"]), "He has been up there days.", "the journal carries it for the quest card")
	st.set_quest_stage("test_closing", "climbing")
	assert_eq(QuestClosures.warning(st, "test_closing"), "", "the clock was for another stage")
	st.set_quest_stage("test_closing", "saved")
	assert_eq(str(_card(st, "test_closing")["warn"]), "", "and a finished quest warns of nothing")


func test_the_journal_shows_the_warning_under_the_objectives() -> void:
	var st := _story()
	st.set_quest_stage("test_closing", "asked")
	var j := JournalScreen.new()
	add_child(j)
	j.open(self, st, 0)
	var w := j.find_child("Warning", true, false) as Label
	assert_true(w != null, "an open quest with a rule that could run it out shows the line")
	if w != null:
		assert_eq(w.text, "He has been up there days.")
	j.free()
	st.set_quest_stage("test_closing", "climbing")
	var other := JournalScreen.new()
	add_child(other)
	other.open(self, st, 0)
	assert_true(other.find_child("Warning", true, false) == null, "and none once the stage the rule was for is past")
	other.free()


func _card(st: StoryState, quest_id: String) -> Dictionary:
	for q: Dictionary in QuestLog.journal(st):
		if str(q["id"]) == quest_id:
			return q
	return {}
