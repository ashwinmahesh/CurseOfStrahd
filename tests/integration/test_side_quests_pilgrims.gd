extends TestCase
## The Frozen Pilgrims (docs/story/side_quests.md): Sergeant Valcu's report, the nine in the gorge wall, Mother
## Ecaterina's voice through the ice, and the two ways out: the last rites, or breaking her free and facing the
## Penitent. Each pays once.

const SIX: Array[String] = ["liriel_dawnsong", "godrick_pendlebrook", "thistle", "ratatoille"]


func _pass() -> StoryState:
	return SideQuestPlay.party(SIX, 10, "tsolenka_pass", 12)


func test_the_report_the_ice_and_the_penitent() -> void:
	var st := _pass()
	st.location = "tsolenka_pass_guard_tower"
	st.set_flag("tsolenka_watch_met")
	st.set_flag("tsolenka_watch_fate", "passed")
	var beats := SideQuestPlay.play(st, "tsolenka_pass/watch:sergeant", ["Anything to report"])
	assert_eq(SideQuestPlay.missing(beats), "")
	assert_true(SideQuestPlay.text(beats).contains("nine pilgrims"))
	assert_eq(st.quest_stage("the_frozen_pilgrims"), "rumored")
	st.location = "tsolenka_pass"
	assert_true(SideQuestPlay.shown(st, "tsolenka_pass", "pilgrims_ice"))
	beats = SideQuestPlay.play(st, "tsolenka_pass/the_frozen_pilgrims:ice", ["Can you hear us?", "Break her out"])
	assert_eq(SideQuestPlay.missing(beats), "")
	var said := SideQuestPlay.text(beats)
	assert_true(said.contains("the price was to be the cold"))
	assert_eq(st.quest_stage("the_frozen_pilgrims"), "found")
	assert_eq(SideQuestPlay.combat_of(beats), "the_penitent")
	var enc := SideQuestPlay.encounter(st, "tsolenka_pass", "the_penitent")
	assert_true(SideQuestPlay.has_foe(enc, "the_penitent"))
	assert_true(SideQuestPlay.xp(enc) >= 9000, "level 10: %d" % SideQuestPlay.xp(enc))
	st.set_flag("penitent_slain")
	st.gold = 0
	beats = SideQuestPlay.play(st, "tsolenka_pass/the_frozen_pilgrims:ice")
	assert_true(SideQuestPlay.text(beats).contains("see the valley in spring"))
	assert_eq(st.quest_stage("the_frozen_pilgrims"), "done")
	assert_eq(roundi(st.gold), 500)
	assert_true(st.party_has_item("staff_of_frost"))
	beats = SideQuestPlay.play(st, "tsolenka_pass/the_frozen_pilgrims:ice")
	assert_true(SideQuestPlay.text(beats).contains("The ice has gone"))
	assert_eq(roundi(st.gold), 500, "paid once")


func test_the_last_rites_let_them_go() -> void:
	var st := _pass()
	st.gold = 0
	var beats := SideQuestPlay.play(st, "tsolenka_pass/the_frozen_pilgrims:ice", ["Can you hear us?", "Say the rites of the dead"])
	assert_eq(SideQuestPlay.missing(beats), "", "Liriel is a cleric")
	assert_eq(SideQuestPlay.combat_of(beats), "", "no fight")
	assert_eq(st.quest_stage("the_frozen_pilgrims"), "rested")
	assert_eq(roundi(st.gold), 400)
	assert_false(st.party_has_item("staff_of_frost"), "the staff comes only with her")
	beats = SideQuestPlay.play(st, "tsolenka_pass/the_frozen_pilgrims:ice")
	assert_true(SideQuestPlay.text(beats).contains("a lamp with no oil in it"))
	st.location = "tsolenka_pass_guard_tower"
	st.set_flag("tsolenka_watch_met")
	st.set_flag("tsolenka_watch_fate", "passed")
	beats = SideQuestPlay.play(st, "tsolenka_pass/watch:sergeant", ["Anything to report"])
	assert_true(SideQuestPlay.text(beats).contains("has gone out"))
