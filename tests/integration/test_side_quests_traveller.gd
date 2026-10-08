extends TestCase
## The Last Traveller (docs/story/side_quests.md): Ilarion at the edge of the mists, the wolves on the road, the walk
## home, and Goodwife Petra at the well. The boots are given once.

const SIX: Array[String] = ["godrick_pendlebrook", "liriel_dawnsong", "thistle", "ratatoille"]


func test_one_night_and_fifty_years() -> void:
	var st := SideQuestPlay.party(SIX, 1, "into_the_mists_road", 9)
	assert_eq(SideQuestPlay.standing(st, "into_the_mists_road", "ilarion"), "into_the_mists/the_last_traveller:ilarion")
	var beats := SideQuestPlay.play(st, "into_the_mists/the_last_traveller:ilarion", ["What's your name?", "We'll walk you down"])
	assert_eq(SideQuestPlay.missing(beats), "")
	assert_true(SideQuestPlay.text(beats).contains("Petra and Mihail"))
	assert_eq(SideQuestPlay.combat_of(beats), "ilarion_wolves")
	var enc := SideQuestPlay.encounter(st, "into_the_mists_road", "ilarion_wolves")
	assert_true(SideQuestPlay.xp(enc) >= 200 and SideQuestPlay.xp(enc) <= 400, "Low to High for level 1: %d" % SideQuestPlay.xp(enc))
	st.set_flag("ilarion_wolves_beaten")
	beats = SideQuestPlay.play(st, "into_the_mists/the_last_traveller:ilarion")
	assert_eq(st.quest_stage("the_last_traveller"), "home")
	assert_eq(SideQuestPlay.standing(st, "into_the_mists_road", "ilarion"), "", "he's walked on to the village")
	st.location = "village_of_barovia"
	st.minute_of_day = 12 * 60
	assert_eq(SideQuestPlay.standing(st, "village_of_barovia", "ilarion"), "into_the_mists/the_last_traveller:well")
	beats = SideQuestPlay.play(st, "into_the_mists/the_last_traveller:well")
	assert_true(SideQuestPlay.text(beats).contains("Fifty years, Tata"))
	assert_eq(st.quest_stage("the_last_traveller"), "done")
	assert_true(st.party_has_item("winged_boots"))
	beats = SideQuestPlay.play(st, "into_the_mists/the_last_traveller:well")
	assert_true(SideQuestPlay.text(beats).contains("I carry the water now"), "the boots once")
	beats = SideQuestPlay.play(st, "village_of_barovia/townsfolk:gravedigger")
	assert_true(SideQuestPlay.text(beats).contains("My father's home"))
