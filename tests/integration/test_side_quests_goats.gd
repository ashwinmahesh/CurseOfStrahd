extends TestCase
## The Goatherd's Count (docs/story/side_quests.md): Goodwife Petra at the well, Erno counting one goat too many at the
## fold on the high pasture by evening, the bell on the old nanny's collar, the wolves out of the mists, and Snowdrop
## taken home or walked back.

const FOUR: Array[String] = ["liriel_dawnsong", "godrick_pendlebrook", "wren_featherfoot", "thistle"]
const PASTURE := "barovia_high_pasture"


func test_goodwife_petra_on_her_grandson() -> void:
	var st := SideQuestPlay.party(FOUR, 1, "village_of_barovia", 10)
	var beats := SideQuestPlay.play(st, "village_of_barovia/townsfolk:goodwife", ["Whose goats are those"])
	assert_eq(SideQuestPlay.missing(beats), "")
	assert_true(SideQuestPlay.text(beats).contains("He's a good boy. He can count."))
	assert_eq(st.quest_stage("the_goatherds_count"), "asked")


func test_twenty_four() -> void:
	var st := SideQuestPlay.party(FOUR, 1, PASTURE, 12)
	st.set_quest_stage("the_goatherds_count", "asked")
	st.set_flag("ilarion_met")
	assert_eq(SideQuestPlay.standing(st, PASTURE, "pasture_erno"), "", "in the evening")
	st.minute_of_day = 18 * 60
	assert_eq(SideQuestPlay.standing(st, PASTURE, "pasture_erno"), "village_of_barovia/the_goatherds_count:erno")
	var beats := SideQuestPlay.play(st, "village_of_barovia/the_goatherds_count:erno", ["Look at the bell"])
	assert_eq(SideQuestPlay.missing(beats), "")
	var said := SideQuestPlay.text(beats)
	assert_true(said.contains("Twenty-four."))
	assert_true(said.contains("SNOWDROP"))
	assert_true(said.contains("good grey boots"), "the Last Traveller's mark")
	assert_eq(SideQuestPlay.combat_of(beats), "pasture_wolves")
	assert_true(SideQuestPlay.has_foe(SideQuestPlay.encounter(st, PASTURE, "pasture_wolves"), "A Mist Wolf"))


func test_snowdrop_goes_home() -> void:
	var st := SideQuestPlay.party(FOUR, 1, PASTURE, 18)
	st.set_quest_stage("the_goatherds_count", "defended")
	st.set_flag("pasture_wolves_beaten")
	st.set_flag("ilarion_home")
	st.gold = 0
	var beats := SideQuestPlay.play(st, "village_of_barovia/the_goatherds_count:erno", ["Take her down"])
	assert_eq(SideQuestPlay.missing(beats), "")
	assert_true(SideQuestPlay.text(beats).contains("Father's by the fire"))
	assert_eq(st.quest_stage("the_goatherds_count"), "done")
	assert_true(st.party_has_item("potion_of_animal_friendship"))
	assert_eq(roundi(st.gold), 25)
	assert_eq(SideQuestPlay.standing(st, PASTURE, "pasture_snowdrop"), "")
	beats = SideQuestPlay.play(st, "village_of_barovia/the_goatherds_count:erno")
	assert_true(SideQuestPlay.text(beats).contains("sleeps in Gran's kitchen"))


func test_snowdrop_goes_back_into_the_mists() -> void:
	var st := SideQuestPlay.party(FOUR, 1, PASTURE, 18)
	st.set_quest_stage("the_goatherds_count", "defended")
	st.set_flag("pasture_wolves_beaten")
	var beats := SideQuestPlay.play(st, "village_of_barovia/the_goatherds_count:erno", ["Walk her back up"])
	assert_eq(SideQuestPlay.missing(beats), "")
	assert_true(SideQuestPlay.text(beats).contains("THANK YOU"))
	assert_true(st.party_has_item("potion_of_animal_friendship"))
	beats = SideQuestPlay.play(st, "village_of_barovia/the_goatherds_count:erno")
	assert_true(SideQuestPlay.text(beats).contains("I can still hear the bell"))
