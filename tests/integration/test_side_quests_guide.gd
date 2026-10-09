extends TestCase
## The Guide to the Temple (docs/story/side_quests.md): the Tsolenka sergeant's log from level 10, the camp on the goat
## path, the child's tea (Medicine) and the guide's look (Insight), turning back or confronting him, and Floarea after.

const FOUR: Array[String] = ["liriel_dawnsong", "godrick_pendlebrook", "kip_smudgewick", "thistle"]
const CAMP := "amber_road_camp"


func test_the_sergeant_logged_the_goat_path() -> void:
	var st := SideQuestPlay.party(FOUR, 9, "tsolenka_pass_guard_tower", 14)
	var beats := SideQuestPlay.play(st, "tsolenka_pass/watch:passed_again", ["Has anybody else gone up"])
	assert_ne(SideQuestPlay.missing(beats), "", "not before level 10")
	st = SideQuestPlay.party(FOUR, 10, "tsolenka_pass_guard_tower", 14)
	beats = SideQuestPlay.play(st, "tsolenka_pass/watch:passed_again", ["Has anybody else gone up"])
	assert_eq(SideQuestPlay.missing(beats), "")
	assert_true(SideQuestPlay.text(beats).contains("One lantern came down"))
	assert_eq(st.quest_stage("the_guide_to_the_temple"), "asked")


func test_the_childs_tea() -> void:
	var st := SideQuestPlay.party(FOUR, 10, CAMP, 20)
	st.set_quest_stage("the_guide_to_the_temple", "asked")
	assert_eq(SideQuestPlay.standing(st, CAMP, "amber_guide"), "tsolenka_pass/the_guide:camp")
	var beats := SideQuestPlay.play(st, "tsolenka_pass/the_guide:camp", ["Leave them to their fire"])
	var said := SideQuestPlay.text(beats)
	assert_true(said.contains("Share the fire"))
	assert_true(said.contains("The lung fever, since the autumn"))
	beats = SideQuestPlay.play(st, "tsolenka_pass/the_guide:child")
	assert_true(SideQuestPlay.text(beats).contains("sleep-root"))
	assert_true(st.get_flag("amber_tea_known", false))
	beats = SideQuestPlay.play(st, "tsolenka_pass/the_guide:camp", ["You've been putting something in her tea"])
	assert_eq(SideQuestPlay.missing(beats), "")
	assert_true(SideQuestPlay.text(beats).contains("a year for each one"))
	assert_eq(SideQuestPlay.combat_of(beats), "amber_guide")
	var enc := SideQuestPlay.encounter(st, CAMP, "amber_guide")
	assert_true(SideQuestPlay.has_foe(enc, "amber_guide"))
	assert_true(SideQuestPlay.has_foe(enc, "One of His Shadows"))


func test_nobody_turns_back_on_his_mountain() -> void:
	var st := SideQuestPlay.party(FOUR, 10, CAMP, 20)
	st.set_quest_stage("the_guide_to_the_temple", "asked")
	var beats := SideQuestPlay.play(st, "tsolenka_pass/the_guide:camp", ["Turn back"])
	assert_eq(SideQuestPlay.missing(beats), "")
	assert_true(SideQuestPlay.text(beats).contains("Nobody turns back on my mountain"))
	assert_eq(SideQuestPlay.combat_of(beats), "amber_guide")


func test_floarea_pours_out_the_tea() -> void:
	var st := SideQuestPlay.party(FOUR, 10, CAMP, 20)
	st.set_quest_stage("the_guide_to_the_temple", "fought")
	st.set_flag("amber_guide_beaten")
	st.gold = 0
	assert_eq(SideQuestPlay.standing(st, CAMP, "amber_guide"), "")
	var beats := SideQuestPlay.play(st, "tsolenka_pass/the_guide:camp")
	var said := SideQuestPlay.text(beats)
	assert_true(said.contains("I knew sleep-root when I smelled it"))
	assert_eq(st.quest_stage("the_guide_to_the_temple"), "done")
	assert_true(st.party_has_item("rod_of_alertness"))
	assert_eq(roundi(st.gold), 400)
	assert_eq(SideQuestPlay.standing(st, CAMP, "goat_path_remus"), "", "they're going down")
	beats = SideQuestPlay.play(st, "tsolenka_pass/the_guide:camp")
	assert_true(SideQuestPlay.text(beats).contains("A real sleep"))
