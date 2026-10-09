extends TestCase
## The Last Egg (docs/story/side_quests.md): Tibor at the Tsolenka landing and the marks on his wrist, the hatching egg
## on the roc's shelf, the count's falconer, and either the chick handed over or the roc's thanks.

const FOUR: Array[String] = ["liriel_dawnsong", "godrick_pendlebrook", "ratatoille", "thistle"]


func _pass(level: int = 9) -> StoryState:
	return SideQuestPlay.party(FOUR, level, "tsolenka_pass", 12)


func test_tibor_and_his_buyer() -> void:
	var st := _pass(8)
	assert_eq(SideQuestPlay.standing(st, "tsolenka_pass", "tsolenka_tibor"), "", "not before level 9")
	st = _pass()
	assert_eq(SideQuestPlay.standing(st, "tsolenka_pass", "tsolenka_tibor"), "tsolenka_pass/the_last_egg:tibor")
	assert_false(SideQuestPlay.shown(st, "tsolenka_pass", "roc_egg"))
	var beats := SideQuestPlay.play(st, "tsolenka_pass/the_last_egg:tibor", ["Watch him"], 3)
	assert_true(SideQuestPlay.text(beats).contains("once in eleven years"))
	assert_eq(st.quest_stage("the_last_egg"), "asked")
	assert_true(SideQuestPlay.shown(st, "tsolenka_pass", "roc_egg"))


func test_the_chick_handed_over() -> void:
	var st := _pass()
	st.set_quest_stage("the_last_egg", "asked")
	st.set_flag("tibor_met")
	st.gold = 0
	var beats := SideQuestPlay.play(st, "tsolenka_pass/the_last_egg:egg", ["Wrap the egg", "Step back"])
	assert_eq(SideQuestPlay.missing(beats), "")
	var said := SideQuestPlay.text(beats)
	assert_true(said.contains("screams for its mother"))
	assert_true(said.contains("carrying it so far"))
	assert_eq(st.quest_stage("the_last_egg"), "sold")
	assert_eq(roundi(st.gold), 400)
	assert_true(st.get_flag("roc_egg_sold", false), "a mark on his attention")
	assert_eq(SideQuestPlay.standing(st, "tsolenka_pass", "tsolenka_tibor"), "", "gone with his money")


func test_the_falconer_and_the_rocs_thanks() -> void:
	var st := _pass()
	st.set_quest_stage("the_last_egg", "asked")
	var beats := SideQuestPlay.play(st, "tsolenka_pass/the_last_egg:egg", ["Stand between", "No."])
	assert_eq(SideQuestPlay.missing(beats), "")
	assert_true(SideQuestPlay.text(beats).contains("finding it for us"))
	assert_eq(SideQuestPlay.combat_of(beats), "last_egg")
	assert_true(SideQuestPlay.has_foe(SideQuestPlay.encounter(st, "tsolenka_pass", "last_egg"), "The Falconer"))
	st.set_flag("last_egg_defended")
	st.set_quest_stage("the_last_egg", "defended")
	st.gold = 0
	beats = SideQuestPlay.play(st, "tsolenka_pass/the_last_egg:egg")
	assert_true(SideQuestPlay.text(beats).contains("She doesn't come for you"))
	assert_eq(st.quest_stage("the_last_egg"), "done")
	assert_true(st.get_flag("roc_driven_off", false), "the roc lets the party cross the bridge")
	assert_true(st.party_has_item("staff_of_the_woodlands"))
	assert_eq(roundi(st.gold), 300)
	beats = SideQuestPlay.play(st, "tsolenka_pass/the_last_egg:egg")
	assert_eq(roundi(st.gold), 300, "once")
