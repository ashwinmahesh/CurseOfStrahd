extends TestCase
## The Waystone (docs/story/side_quests.md): Clovin's news about Lark from level 6, the waystone by day and Lark at it
## by night, the pack coming down the road, and Yanko coming into the light (back to a boy, and to Krezk if Pavel is
## found; or staying a wolf at her feet).

const FOUR: Array[String] = ["liriel_dawnsong", "godrick_pendlebrook", "wren_featherfoot", "thistle"]
const STONE := "krezk_road_waystone"


func test_clovin_tells_of_lark() -> void:
	var st := SideQuestPlay.party(FOUR, 5, "abbey_of_st_markovia", 14)
	SideQuestPlay.play(st, "abbey_of_st_markovia/mothers_ninth_improvement:clovin_news")
	assert_eq(st.quest_stage("the_waystone"), "", "not before level 6")
	st = SideQuestPlay.party(FOUR, 6, "abbey_of_st_markovia", 14)
	var beats := SideQuestPlay.play(st, "abbey_of_st_markovia/mothers_ninth_improvement:clovin_news")
	assert_true(SideQuestPlay.text(beats).contains("over the wall like a cat"))
	assert_eq(st.quest_stage("the_waystone"), "rumored")
	st.set_quest_stage("mothers_ninth_improvement", "done")
	beats = SideQuestPlay.play(st, "abbey_of_st_markovia/mothers_ninth_improvement:clovin_news")
	assert_true(SideQuestPlay.text(beats).contains("Sundays now"), "his own news still comes first")


func test_lark_at_the_stone_by_night() -> void:
	var st := SideQuestPlay.party(FOUR, 6, STONE, 13)
	st.set_quest_stage("the_waystone", "rumored")
	assert_eq(SideQuestPlay.standing(st, STONE, "waystone_lark"), "", "only by night")
	var beats := SideQuestPlay.play(st, "krezk/the_waystone:stone")
	assert_true(SideQuestPlay.text(beats).contains("comes by night"))
	st.minute_of_day = 23 * 60
	assert_eq(SideQuestPlay.standing(st, STONE, "waystone_lark"), "krezk/the_waystone:lark")
	beats = SideQuestPlay.play(st, "krezk/the_waystone:lark", ["Who's the candle for", "Stand by the stone"])
	assert_eq(SideQuestPlay.missing(beats), "")
	var said := SideQuestPlay.text(beats)
	assert_true(said.contains("Not ate him. Got him."))
	assert_true(said.contains("Wolves don't go soft"))
	assert_eq(st.quest_stage("the_waystone"), "asked")
	assert_eq(SideQuestPlay.combat_of(beats), "waystone_wolves")
	assert_true(SideQuestPlay.has_foe(SideQuestPlay.encounter(st, STONE, "waystone_wolves"), "A Pack Hunter"))


func test_yanko_comes_back_to_a_boy() -> void:
	var st := SideQuestPlay.party(FOUR, 6, STONE, 23)
	st.set_quest_stage("the_waystone", "defended")
	st.set_flag("waystone_wolves_beaten")
	st.set_flag("clovin_family_found")
	st.gold = 0
	assert_eq(SideQuestPlay.standing(st, STONE, "waystone_yanko"), "krezk/the_waystone:after")
	var beats := SideQuestPlay.play(st, "krezk/the_waystone:turns")
	var said := SideQuestPlay.text(beats)
	assert_true(said.contains("I couldn't remember how to come any closer"))
	assert_true(said.contains("Great-uncle Pavel"))
	assert_eq(st.quest_stage("the_waystone"), "done")
	assert_true(st.get_flag("yanko_to_krezk", false))
	assert_true(st.party_has_item("wand_of_slumber"))
	assert_eq(roundi(st.gold), 120)
	assert_eq(SideQuestPlay.standing(st, STONE, "waystone_lark"), "")
	st.location = "abbey_of_st_markovia"
	beats = SideQuestPlay.play(st, "krezk/the_waystone:clovin_news")
	assert_true(SideQuestPlay.text(beats).contains("put them in the loft"))


func test_yanko_stays_a_wolf_at_her_feet() -> void:
	var st := SideQuestPlay.party(FOUR, 6, STONE, 23)
	st.set_quest_stage("the_waystone", "defended")
	st.set_flag("waystone_wolves_beaten")
	var beats := SideQuestPlay.play(st, "krezk/the_waystone:after", ["Let her sing to him"])
	assert_eq(SideQuestPlay.missing(beats), "")
	assert_true(SideQuestPlay.text(beats).contains("like a dog at a fire"))
	assert_eq(st.quest_stage("the_waystone"), "done")
	beats = SideQuestPlay.play(st, "krezk/the_waystone:clovin_news")
	assert_true(SideQuestPlay.text(beats).contains("Something grey walks her home"))
	beats = SideQuestPlay.play(st, "krezk/the_waystone:stone")
	assert_true(SideQuestPlay.text(beats).contains("a grey hair"))
