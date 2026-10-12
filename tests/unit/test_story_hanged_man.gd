extends TestCase
## The Hanged Man at the Crossroads (Ashwin, 2026-10-12): a party that met Nicu as the risen dead by night and buried
## what was left never "saw" the gallows, so neither Luminita nor Stanimir would hear about him, and Luminita's first
## words put the quest back to "asked". Both hear it however he was met, and her greeting only starts the quest.


func test_luminita_hears_about_nicu_after_the_fight() -> void:
	var st := _after_the_fight()
	var beats := SideQuestPlay.play(st, "svalich_road/luminita:start", ["We found a Vistana"])
	assert_eq(SideQuestPlay.missing(beats), "", "she can be told")
	assert_eq(st.quest_stage("the_hanged_vistana"), "told")
	assert_true(st.party_has_item("potion_of_healing"), "and she thanks the party for the burial")


func test_stanimir_hears_about_nicu_after_the_fight() -> void:
	var st := _after_the_fight()
	st.set_flag("luminita_met")
	var beats := SideQuestPlay.play(st, "svalich_road/stanimir:menu", ["hanged at the crossroads"])
	assert_eq(SideQuestPlay.missing(beats), "")
	assert_eq(st.quest_stage("the_hanged_vistana"), "told")


func test_meeting_luminita_doesnt_move_the_quest_back() -> void:
	var st := _after_the_fight()
	SideQuestPlay.play(st, "svalich_road/luminita:start", ["Goodbye"])
	assert_eq(st.quest_stage("the_hanged_vistana"), "risen", "not back to asked")


## His save's state: the risen hanged beaten at the gallows by night, the remains buried, the gallows never examined.
func _after_the_fight() -> StoryState:
	var st := SideQuestPlay.party(["ilse_varga"], 5, "tser_pool", 12)
	st.set_quest_stage("the_hanged_vistana", "risen")
	for f: String in ["crossroads_dead_cleared", "nicu_cut_down", "nicu_token_taken"]:
		st.set_flag(f)
	return st
