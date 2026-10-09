extends TestCase
## The Baron's Island (docs/story/side_quests.md): Old Nistor on the Reed Isle from level 5 (not once the council has
## the town), Ostap and the castaways, the Baron's boat coming in the dark, and what the castaways do with a boat.

const FOUR: Array[String] = ["liriel_dawnsong", "godrick_pendlebrook", "wren_featherfoot", "thistle"]
const ISLE := "zarovich_reed_island"


func test_old_nistor_on_the_reed_isle() -> void:
	var st := SideQuestPlay.party(FOUR, 4, "lake_zarovich", 14)
	var beats := SideQuestPlay.play(st, "lake_zarovich/old_fisher:start", ["What's on that island"])
	assert_ne(SideQuestPlay.missing(beats), "", "not before level 5")
	st = SideQuestPlay.party(FOUR, 5, "lake_zarovich", 14)
	st.set_flag("vallaki_backed", "neither")
	beats = SideQuestPlay.play(st, "lake_zarovich/old_fisher:start", ["What's on that island"])
	assert_ne(SideQuestPlay.missing(beats), "", "not once the council has the town")
	st = SideQuestPlay.party(FOUR, 5, "lake_zarovich", 14)
	beats = SideQuestPlay.play(st, "lake_zarovich/old_fisher:start", ["What's on that island"])
	assert_eq(SideQuestPlay.missing(beats), "")
	assert_true(SideQuestPlay.text(beats).contains("It leaks on the left"))
	assert_eq(st.quest_stage("the_barons_island"), "asked")


func test_the_castaways_and_the_boat() -> void:
	var st := SideQuestPlay.party(FOUR, 5, ISLE, 20)
	st.set_quest_stage("the_barons_island", "asked")
	assert_eq(SideQuestPlay.standing(st, ISLE, "reed_isle_ostap"), "lake_zarovich/the_barons_island:ostap")
	var beats := SideQuestPlay.play(st, "lake_zarovich/the_barons_island:ostap", ["Come back with us", "Wait at the landing"])
	assert_eq(SideQuestPlay.missing(beats), "")
	var said := SideQuestPlay.text(beats)
	assert_true(said.contains("waste of good wicker"))
	assert_true(said.contains("Nobody has to be happy on a Thursday"))
	assert_true(said.contains("with clubs and a lantern"))
	assert_eq(SideQuestPlay.combat_of(beats), "reed_isle_boatmen")
	var enc := SideQuestPlay.encounter(st, ISLE, "reed_isle_boatmen")
	assert_true(SideQuestPlay.has_foe(enc, "The Boatmaster"))
	assert_true(SideQuestPlay.has_foe(enc, "Something in the Reeds"))


func test_they_stay_on_the_island() -> void:
	var st := SideQuestPlay.party(FOUR, 5, ISLE, 20)
	st.set_quest_stage("the_barons_island", "defended")
	st.set_flag("reed_isle_boatmen_beaten")
	st.gold = 0
	var beats := SideQuestPlay.play(st, "lake_zarovich/the_barons_island:ostap", ["Stay"])
	assert_eq(SideQuestPlay.missing(beats), "")
	assert_true(SideQuestPlay.text(beats).contains("The Baron can count his drowned"))
	assert_eq(st.quest_stage("the_barons_island"), "done")
	assert_true(st.party_has_item("dimensional_shackles"))
	assert_eq(roundi(st.gold), 80)
	beats = SideQuestPlay.play(st, "lake_zarovich/the_barons_island:ostap")
	assert_true(SideQuestPlay.text(beats).contains("Come and eat fish sometime"))


func test_they_row_home_singing() -> void:
	var st := SideQuestPlay.party(FOUR, 5, ISLE, 20)
	st.set_quest_stage("the_barons_island", "defended")
	st.set_flag("reed_isle_boatmen_beaten")
	var beats := SideQuestPlay.play(st, "lake_zarovich/the_barons_island:ostap", ["Come home with us"])
	assert_eq(SideQuestPlay.missing(beats), "")
	assert_true(SideQuestPlay.text(beats).contains("singing, and see who stops us"))
	assert_eq(SideQuestPlay.standing(st, ISLE, "reed_isle_ostap"), "")
