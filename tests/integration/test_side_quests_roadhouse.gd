extends TestCase
## The Lantern in the Roadhouse (docs/story/side_quests.md): Arik's one-word rumour from level 2, the Grey Goose by
## night, the innkeeper's ghost and his ledger, the trapdoor and what's under it, and the lantern put down.

const FOUR: Array[String] = ["liriel_dawnsong", "godrick_pendlebrook", "kip_smudgewick", "thistle"]
const GOOSE := "svalich_roadhouse"


func test_arik_says_three_words() -> void:
	var st := SideQuestPlay.party(FOUR, 1, "village_of_barovia", 14)
	for q: String in ["cut_after_noon", "polite_caller", "six_feet"]:
		st.set_quest_stage(q, "rumored")
	var beats := SideQuestPlay.play(st, "village_of_barovia/arik:rumors")
	assert_false(SideQuestPlay.text(beats).contains("Grey Goose"), "not before level 2")
	assert_eq(st.quest_stage("the_roadhouse_lantern"), "")
	st = SideQuestPlay.party(FOUR, 2, "village_of_barovia", 14)
	for q: String in ["cut_after_noon", "polite_caller", "six_feet"]:
		st.set_quest_stage(q, "rumored")
	beats = SideQuestPlay.play(st, "village_of_barovia/arik:rumors")
	assert_true(SideQuestPlay.text(beats).contains("Grey Goose. Lantern. No upstairs."))
	assert_eq(st.quest_stage("the_roadhouse_lantern"), "rumored")


func test_the_innkeeper_keeps_his_light() -> void:
	var st := SideQuestPlay.party(FOUR, 2, GOOSE, 13)
	st.set_quest_stage("the_roadhouse_lantern", "rumored")
	assert_eq(SideQuestPlay.standing(st, GOOSE, "roadhouse_innkeeper"), "", "only by night")
	st.minute_of_day = 23 * 60
	assert_eq(SideQuestPlay.standing(st, GOOSE, "roadhouse_innkeeper"), "svalich_road/the_roadhouse_lantern:innkeeper")
	var beats := SideQuestPlay.play(st, "svalich_road/the_roadhouse_lantern:innkeeper", ["Who's the lantern for", "Leave him"])
	assert_eq(SideQuestPlay.missing(beats), "")
	var said := SideQuestPlay.text(beats)
	assert_true(said.contains("There's no room at the Goose"))
	assert_true(said.contains("A lit one has somebody in it already"))
	assert_eq(st.quest_stage("the_roadhouse_lantern"), "asked")
	beats = SideQuestPlay.play(st, "svalich_road/the_roadhouse_lantern:ledger")
	assert_true(SideQuestPlay.text(beats).contains("Mama made a stew"))
	beats = SideQuestPlay.play(st, "svalich_road/the_roadhouse_lantern:trapdoor", ["Pull the nails"])
	assert_eq(SideQuestPlay.missing(beats), "")
	assert_true(SideQuestPlay.text(beats).contains("I burned the house over them"))
	assert_eq(SideQuestPlay.combat_of(beats), "roadhouse_cellar")
	var enc := SideQuestPlay.encounter(st, GOOSE, "roadhouse_cellar")
	assert_true(SideQuestPlay.has_foe(enc, "The Innkeeper's Wife"))
	assert_true(SideQuestPlay.has_foe(enc, "A Son of the House"))


func test_he_puts_the_lantern_down() -> void:
	var st := SideQuestPlay.party(FOUR, 2, GOOSE, 23)
	st.set_quest_stage("the_roadhouse_lantern", "opened")
	st.set_flag("roadhouse_cellar_beaten")
	st.gold = 0
	assert_eq(SideQuestPlay.standing(st, GOOSE, "roadhouse_innkeeper"), "svalich_road/the_roadhouse_lantern:after")
	var beats := SideQuestPlay.play(st, "svalich_road/the_roadhouse_lantern:after")
	assert_true(SideQuestPlay.text(beats).contains("It's very tiring, being a warning"))
	assert_eq(st.quest_stage("the_roadhouse_lantern"), "done")
	assert_true(st.party_has_item("pipes_of_the_sewers"))
	assert_eq(roundi(st.gold), 50)
	assert_eq(SideQuestPlay.standing(st, GOOSE, "roadhouse_innkeeper"), "")
	beats = SideQuestPlay.play(st, "svalich_road/the_roadhouse_lantern:lantern")
	assert_true(SideQuestPlay.text(beats).contains("Nothing holds it up any more"))
