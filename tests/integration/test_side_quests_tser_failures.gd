extends TestCase
## Side Quest Failure Plan, package T1: four Tser Pool camp quests can be lost to time or a wrong choice (Ashwin,
## 2026-10-19: clocks yes, a failed roll never ends a quest). Called by Name: three days after Big Tobar asks, Nelu answers
## the voices (`answered`). The Dancing Bear: a day after the party backs away from the trapped cub, the blights have both
## bears (`torn`). The Grey Mare: a mare the castle kept is mourned as a failure, and Radu keeps her bride price. The
## Hanged Man at the Crossroads: telling Luminita the road was empty leaves her waiting (`unspoken`), for good.

const FOUR: Array[String] = ["liriel_dawnsong", "godrick_pendlebrook", "thistle", "wren_featherfoot"]
const S := "svalich_road/"
const DAY := 24 * 60


func _st(hour: int = 12, location: String = "tser_pool") -> StoryState:
	return SideQuestPlay.party(FOUR, 4, location, hour)


func _has(beats: Array[Dictionary], words: String) -> bool:
	return SideQuestPlay.text(beats).contains(words)


# --- Called by Name ---------------------------------------------------------------------------------------------

func test_nelu_answers_the_voices_three_days_after_tobar_asks() -> void:
	var st := _st()
	var beats := SideQuestPlay.play(st, S + "called_by_name:asks", ["We'll go"])
	assert_eq(SideQuestPlay.missing(beats), "")
	assert_true(_has(beats, "Three days he's been down there"), "Tobar names the time")
	assert_eq(st.quest_stage("called_by_name"), "asked")
	assert_eq(QuestClosures.warning(st, "called_by_name"), "Three days without bread, and the voices call him every night.")
	st.advance_minutes(2 * DAY + 600)
	assert_true(QuestClosures.sweep(st).is_empty(), "two days and a half: still time")
	st.advance_minutes(DAY)
	assert_eq(QuestClosures.sweep(st), ["Quest failed: Called by Name"] as Array[String])
	assert_eq(st.quest_stage("called_by_name"), "answered")


func test_the_clock_stops_once_nelu_is_off_the_ledge() -> void:
	var st := _st()
	SideQuestPlay.play(st, S + "called_by_name:asks", ["We'll go"])
	st.set_flag("nelu_saved")
	st.set_quest_stage("called_by_name", "nelu_found")
	st.advance_minutes(5 * DAY)
	assert_true(QuestClosures.sweep(st).is_empty())
	assert_eq(st.quest_stage("called_by_name"), "nelu_found")


func test_after_he_answered_the_falls_call_in_his_voice_and_tobar_grieves() -> void:
	var st := _st(23, "tser_falls")
	SideQuestPlay.play(st, S + "called_by_name:asks", ["We'll go"])
	st.advance_minutes(4 * DAY)
	QuestClosures.sweep(st)
	assert_true(SideQuestPlay.shown(st, "tser_falls", "gorge_voices"))
	var falls := SideQuestPlay.play(st, S + "called_by_name:falls")
	assert_true(_has(falls, "calling for its Da"), SideQuestPlay.text(falls))
	assert_eq(SideQuestPlay.combat_of(falls), "", "no wisps' fight for a boy who's gone")
	var tobar := SideQuestPlay.play(st, S + "called_by_name:tobar")
	assert_true(_has(tobar, "two wedges where his hands ought to be"))


# --- The Dancing Bear -------------------------------------------------------------------------------------------

func test_backing_away_from_the_cub_starts_a_day_and_then_the_bears_are_gone() -> void:
	var st := _st(12, "tser_woods_den")
	st.set_quest_stage("the_dancing_bear", "asked")
	var den := SideQuestPlay.play(st, S + "the_dancing_bear:den", ["Back away"])
	assert_eq(SideQuestPlay.missing(den), "")
	assert_true(_has(den, "begin creeping toward the cub"), "the warning as the party backs off")
	assert_eq(QuestClosures.warning(st, "the_dancing_bear"), "The things in the trees are closing in on Bujor and the cub.")
	st.advance_minutes(DAY - 60)
	assert_true(QuestClosures.sweep(st).is_empty())
	st.advance_minutes(120)
	assert_eq(QuestClosures.sweep(st), ["Quest failed: The Dancing Bear"] as Array[String])
	assert_eq(SideQuestPlay.standing(st, "tser_woods_den", "bujor"), "", "Bujor is gone from the clearing")
	var trap := SideQuestPlay.play(st, S + "the_dancing_bear:trap_prop")
	assert_true(_has(trap, "pried open and empty"))
	var lavinia := SideQuestPlay.play(st, S + "the_dancing_bear:lavinia")
	assert_true(_has(lavinia, "I know what silence sounds like"))


func test_a_second_retreat_doesnt_buy_another_day() -> void:
	var st := _st(12, "tser_woods_den")
	st.set_quest_stage("the_dancing_bear", "asked")
	SideQuestPlay.play(st, S + "the_dancing_bear:den", ["Back away"])
	st.advance_minutes(20 * 60)
	SideQuestPlay.play(st, S + "the_dancing_bear:den", ["Back away"])
	st.advance_minutes(5 * 60)
	QuestClosures.sweep(st)
	assert_eq(st.quest_stage("the_dancing_bear"), "torn", "the day runs from the first time")


func test_opening_the_trap_in_time_stops_the_clock() -> void:
	var st := _st(12, "tser_woods_den")
	st.set_quest_stage("the_dancing_bear", "asked")
	SideQuestPlay.play(st, S + "the_dancing_bear:den", ["Back away"])
	st.set_quest_stage("the_dancing_bear", "defended")
	st.advance_minutes(3 * DAY)
	assert_true(QuestClosures.sweep(st).is_empty())


# --- The Grey Mare ----------------------------------------------------------------------------------------------

func test_a_mourned_mare_is_a_failure_and_radu_keeps_the_bride_price() -> void:
	var st := _st()
	st.set_quest_stage("the_grey_mare", "lost")
	st.set_flag("carriage_beaten")
	var gold := st.gold
	var beats := SideQuestPlay.play(st, S + "grey_mare:radu")
	assert_eq(st.quest_stage("the_grey_mare"), "mourned")
	assert_eq(st.quest_ending("the_grey_mare"), "failure")
	assert_eq(st.gold, gold + 120, "the castle's gold is still paid over")
	assert_false(st.party_has_item("rod_of_the_pact_keeper_plus_1"), "the rod stays on the gate")
	assert_true(_has(beats, "the last thing of hers I have"))


func test_a_saved_mare_still_brings_the_rod() -> void:
	var st := _st()
	st.set_quest_stage("the_grey_mare", "carriage_beaten")
	st.set_flag("carriage_beaten")
	st.set_flag("mare_saved")
	SideQuestPlay.play(st, S + "grey_mare:radu")
	assert_eq(st.quest_stage("the_grey_mare"), "home")
	assert_true(st.party_has_item("rod_of_the_pact_keeper_plus_1"))


# --- The Hanged Man at the Crossroads -----------------------------------------------------------------------------

func test_the_lie_is_marked_and_leaves_luminita_waiting_for_good() -> void:
	var st := _st()
	st.set_flag("crossroads_gallows_seen")
	st.set_quest_stage("the_hanged_vistana", "found")
	var r := DialogueRunner.new(st, DiceRoller.new(1))
	assert_true(r.start(S + "luminita:start"))
	var b := r.next()
	while str(b["kind"]) != "options":
		b = r.next()
	var lie := -1
	for i in (b["options"] as Array).size():
		if str((b["options"] as Array)[i]["text"]).contains("passed no one on the road from the crossroads"):
			lie = i
	assert_true(lie >= 0, "the lie is offered once the gallows were seen")
	assert_eq((b["options"] as Array)[lie]["ends"], ["The Hanged Man at the Crossroads"] as Array[String], "and marked")
	var beats := SideQuestPlay.play(st, S + "luminita:start", ["passed no one on the road from the crossroads"])
	assert_eq(st.quest_stage("the_hanged_vistana"), "unspoken")
	assert_eq(st.quest_ending("the_hanged_vistana"), "failure")
	assert_true(_has(beats, "empty bend in the road"))
	var again := SideQuestPlay.play(st, S + "luminita:start", ["Hanged"])
	assert_true(SideQuestPlay.missing(again) != "", "nobody tells her afterwards")
	assert_true(_has(again, "front wagon by the ditch"))
	var stanimir := SideQuestPlay.play(st, S + "stanimir:menu", ["hanged at the crossroads"])
	assert_true(SideQuestPlay.missing(stanimir) != "", "nor Stanimir")
	assert_false(bool(st.get_flag("nicu_kin_told")))


func test_telling_her_still_works() -> void:
	var st := _st()
	st.set_flag("crossroads_gallows_seen")
	st.set_quest_stage("the_hanged_vistana", "found")
	SideQuestPlay.play(st, S + "luminita:start", ["Hanged"])
	assert_eq(st.quest_stage("the_hanged_vistana"), "told")
