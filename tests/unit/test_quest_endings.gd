extends TestCase
## Side quest failure plan, F1 (endings are endings): a failure ending is final unless it names a comeback in `then`,
## the notice says how a quest moved ("Quest failed", "Quest complete", else "Journal updated"), and a quest or a
## stamped flag can be counted in whole days (`quest_days.<id>`, `days_since.<flag>`, `set <flag> = now`).

const DIALOGUE := """
~ lose
quest the_last_egg sold

~ win
quest the_last_egg done

~ look
quest the_last_egg asked

~ stamp
set rang_the_bell = now

~ stamp_again
set rang_the_bell = now
"""


func before_each() -> void:
	DialogueFile.register(DialogueFile.parse(DIALOGUE, "test/endings"))


func _story() -> StoryState:
	var st := StoryState.new()
	st.party.append(TestChars.pregen("thistle", 1))
	return st


func _name(quest_id: String) -> String:
	return Compendium.shared().display_name("quests", quest_id)


# --- A failure is final -------------------------------------------------------------------------------------------

func test_a_failure_ending_refuses_a_later_success_and_an_open_stage() -> void:
	var st := _story()
	assert_true(st.set_quest_stage("the_last_egg", "asked"))
	assert_true(st.set_quest_stage("the_last_egg", "sold"))
	assert_eq(st.quest_ending("the_last_egg"), "failure")
	assert_false(st.set_quest_stage("the_last_egg", "done"), "a success line can't paper over a failure")
	assert_eq(st.quest_stage("the_last_egg"), "sold")
	assert_false(st.set_quest_stage("the_last_egg", "defended"), "nor can the quest go back to an open stage")
	assert_eq(st.quest_stage("the_last_egg"), "sold")
	assert_true(st.set_quest_stage("the_last_egg", "sold"), "the failure set again is no move, and no refusal")


func test_a_failure_names_its_comebacks() -> void:
	# The comebacks the game means to allow: a failure's `then` lists the stages it may still move to.
	for row: Array in [["the_stolen_children", "left", "freed"], ["the_order_of_the_silver_dragon", "grudge", "rest"],
			["rose_and_thorn", "left_behind", "at_rest"], ["the_ladle", "unknighted", "knighted"],
			["hunters_ledger", "ledger_closed", "ledger_struck"], ["children_of_the_mill", "children_abandoned", "children_freed"]]:
		var st := _story()
		assert_true(st.set_quest_stage(str(row[0]), str(row[1])), str(row))
		assert_eq(st.quest_ending(str(row[0])), "failure", str(row))
		assert_true(st.set_quest_stage(str(row[0]), str(row[2])), "%s moves on from %s to %s" % [row[0], row[1], row[2]])
		assert_eq(st.quest_ending(str(row[0])), "success", str(row))


func test_a_failure_refuses_a_stage_it_does_not_name() -> void:
	var st := _story()
	assert_true(st.set_quest_stage("rose_and_thorn", "left_behind"))
	assert_false(st.set_quest_stage("rose_and_thorn", "remains"), "an open stage isn't a comeback")
	assert_eq(st.quest_stage("rose_and_thorn"), "left_behind")


func test_a_success_ending_still_gives_way_to_another() -> void:
	var st := _story()
	assert_true(st.set_quest_stage("sanctuary_for_ireena", "travels_on"))
	assert_true(st.set_quest_stage("sanctuary_for_ireena", "leaving_vallaki"), "only a failure is final")


# --- What the notice says -----------------------------------------------------------------------------------------

func test_the_notice_says_failed_complete_or_updated() -> void:
	var st := _story()
	var title := _name("the_last_egg")
	assert_true(st.set_quest_stage("the_last_egg", "asked"))
	assert_eq(st.quest_notice(), "Journal updated: %s" % title)
	assert_true(st.set_quest_stage("the_last_egg", "sold"))
	assert_eq(st.quest_notice(), "Quest failed: %s" % title)
	var won := _story()
	assert_true(won.set_quest_stage("the_last_egg", "done"))
	assert_eq(won.quest_notice(), "Quest complete: %s" % title)
	assert_true(won.set_quest_stage("the_last_egg", "done"))
	assert_eq(won.quest_notice(), "Journal updated: %s" % title, "a stage set again moved nothing: no second 'complete'")


func test_a_conversation_says_how_the_quest_moved() -> void:
	var st := _story()
	var r := DialogueRunner.new(st, DiceRoller.new(1))
	assert_true(r.start("test/endings:look"))
	assert_eq(str(r.next()["text"]), "Journal updated: %s" % _name("the_last_egg"))
	r = DialogueRunner.new(st, DiceRoller.new(1))
	assert_true(r.start("test/endings:lose"))
	var b := r.next()
	assert_eq(str(b["kind"]), "notice")
	assert_eq(str(b["text"]), "Quest failed: %s" % _name("the_last_egg"))
	r = DialogueRunner.new(st, DiceRoller.new(1))
	assert_true(r.start("test/endings:win"))
	assert_eq(str(r.next()["kind"]), "end", "the success line is refused, so it says nothing")
	assert_eq(st.quest_stage("the_last_egg"), "sold")


func test_experience_mode_says_the_quest_complete_line_once() -> void:
	var st := _story()
	st.options[Xp.OPTION] = Xp.EXPERIENCE
	st.xp = Xp.threshold(5)
	st.milestones = 4
	var said: Array[String] = []
	st.xp_gained.connect(func(t: String) -> void: said.append(t))
	assert_true(st.set_quest_stage("the_stolen_children", "freed"))
	assert_eq(said.size(), 1)
	assert_true(said[0].begins_with("Quest complete: %s, +" % _name("the_stolen_children")), said[0])
	assert_eq(st.quest_notice(), said[0], "the notice is the XP line, not a second 'Quest complete'")
	var lost := _story()
	lost.options[Xp.OPTION] = Xp.EXPERIENCE
	assert_true(lost.set_quest_stage("the_last_egg", "sold"))
	assert_eq(lost.quest_notice(), "Quest failed: %s" % _name("the_last_egg"), "a failure pays nothing and says so")


func test_an_ending_announces_itself_once() -> void:
	var st := _story()
	var ended: Array[String] = []
	st.quest_finished.connect(func(id: String, how: String) -> void: ended.append("%s:%s" % [id, how]))
	st.set_quest_stage("the_last_egg", "asked")
	assert_true(ended.is_empty(), "an open stage ends nothing")
	st.set_quest_stage("the_last_egg", "sold")
	st.set_quest_stage("the_last_egg", "sold")
	st.set_quest_stage("the_last_egg", "done")
	assert_eq(ended, ["the_last_egg:failure"] as Array[String], "once, and not for the success the failure refused")


# --- Clocks -------------------------------------------------------------------------------------------------------

func test_quest_days_counts_from_the_stage_the_quest_last_moved_to() -> void:
	var st := _story()
	assert_eq(st.quest_days("the_last_egg"), -1, "a quest that hasn't begun has no clock")
	assert_false(StoryConditions.check("quest_days.the_last_egg >= 0", st), "and no condition on it is true")
	assert_false(StoryConditions.check("quest_days.the_last_egg < 9", st))
	st.set_quest_stage("the_last_egg", "asked")
	st.advance_minutes(2 * 24 * 60 + 600)
	assert_eq(st.quest_days("the_last_egg"), 2, "whole days only")
	assert_true(StoryConditions.check("quest_days.the_last_egg >= 2", st))
	assert_false(StoryConditions.check("quest_days.the_last_egg >= 3", st))
	assert_true(StoryConditions.check("quest.the_last_egg == asked and quest_days.the_last_egg > 1", st))
	st.set_quest_stage("the_last_egg", "asked")
	assert_eq(st.quest_days("the_last_egg"), 2, "asking again moves nothing, so the clock isn't restarted")
	st.set_quest_stage("the_last_egg", "defended")
	assert_eq(st.quest_days("the_last_egg"), 0, "a new stage starts it over")


func test_set_now_stamps_the_flag_and_days_since_counts_from_it() -> void:
	var st := _story()
	assert_eq(st.days_since("rang_the_bell"), -1)
	assert_false(StoryConditions.check("days_since.rang_the_bell >= 0", st), "never true while the flag isn't stamped")
	var r := DialogueRunner.new(st, DiceRoller.new(1))
	assert_true(r.start("test/endings:stamp"))
	assert_eq(str(r.next()["kind"]), "end")
	assert_eq(st.get_flag("rang_the_bell"), st.total_minutes(), "the flag holds the game minute")
	assert_eq(st.days_since("rang_the_bell"), 0)
	st.advance_minutes(3 * 24 * 60 + 5)
	assert_true(StoryConditions.check("days_since.rang_the_bell >= 3", st))
	assert_false(StoryConditions.check("days_since.rang_the_bell >= 4", st))
	r = DialogueRunner.new(st, DiceRoller.new(1))
	r.start("test/endings:stamp_again")
	r.next()
	assert_eq(st.days_since("rang_the_bell"), 0, "stamped again, the clock starts over")


func test_a_flag_that_holds_something_else_has_no_clock() -> void:
	var st := _story()
	st.set_flag("rang_the_bell", true)
	assert_eq(st.days_since("rang_the_bell"), -1)
	st.set_flag("rang_the_bell", "dusk")
	assert_eq(st.days_since("rang_the_bell"), -1)
