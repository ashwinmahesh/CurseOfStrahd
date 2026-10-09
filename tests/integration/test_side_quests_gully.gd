extends TestCase
## The Spiders' Gully (docs/story/side_quests.md): Iancu at the Tser Pool camp from level 3, Tsura wrapped on the ledge
## in the Webbed Gully, the web read (or not) before she's cut down, and where she goes after.

const FOUR: Array[String] = ["liriel_dawnsong", "godrick_pendlebrook", "wren_featherfoot", "thistle"]
const GULLY := "ivlis_spider_gully"


func test_iancu_waits_badly() -> void:
	var st := SideQuestPlay.party(FOUR, 2, "tser_pool", 12)
	var beats := SideQuestPlay.play(st, "svalich_road/tser_camp:iancu")
	assert_true(SideQuestPlay.text(beats).contains("Ten paces"), "his old line before level 3")
	st = SideQuestPlay.party(FOUR, 3, "tser_pool", 12)
	beats = SideQuestPlay.play(st, "svalich_road/tser_camp:iancu")
	assert_true(SideQuestPlay.text(beats).contains("web on its saddle"))
	assert_eq(st.quest_stage("the_spiders_gully"), "asked")


func test_tsura_on_the_ledge() -> void:
	var st := SideQuestPlay.party(FOUR, 3, GULLY, 12)
	st.set_quest_stage("the_spiders_gully", "asked")
	var beats := SideQuestPlay.play(st, "svalich_road/the_spiders_gully:cocoon", ["Cut her down"])
	assert_eq(SideQuestPlay.missing(beats), "")
	var said := SideQuestPlay.text(beats)
	assert_true(said.contains("an eye is open"))
	assert_true(said.contains("the whole gully answers"))
	assert_eq(SideQuestPlay.combat_of(beats), "gully_spiders")
	assert_eq(str(SideQuestPlay.encounter(st, GULLY, "gully_spiders").get("surprise", "")), "party", "caught unawares")
	SideQuestPlay.play(st, "svalich_road/the_spiders_gully:strung")
	assert_eq(str(SideQuestPlay.encounter(st, GULLY, "gully_spiders").get("surprise", "")), "", "ready for them")


func test_tsura_goes_home() -> void:
	var st := SideQuestPlay.party(FOUR, 3, GULLY, 12)
	st.set_quest_stage("the_spiders_gully", "cut_down")
	st.set_flag("gully_spiders_beaten")
	st.gold = 0
	var beats := SideQuestPlay.play(st, "svalich_road/the_spiders_gully:cocoon", ["Come back to the camp"])
	assert_eq(SideQuestPlay.missing(beats), "")
	assert_true(SideQuestPlay.text(beats).contains("find another bride"))
	assert_eq(st.quest_stage("the_spiders_gully"), "done")
	assert_true(st.party_has_item("boon_companions_bands"))
	assert_eq(roundi(st.gold), 40)
	st.location = "tser_pool"
	beats = SideQuestPlay.play(st, "svalich_road/tser_camp:iancu")
	assert_true(SideQuestPlay.text(beats).contains("Tsura's back by the fire"))


func test_tsura_goes_on_to_krezk() -> void:
	var st := SideQuestPlay.party(FOUR, 3, GULLY, 12)
	st.set_quest_stage("the_spiders_gully", "cut_down")
	st.set_flag("gully_spiders_beaten")
	var beats := SideQuestPlay.play(st, "svalich_road/the_spiders_gully:cocoon", ["Go on to Krezk"])
	assert_eq(SideQuestPlay.missing(beats), "")
	assert_true(SideQuestPlay.text(beats).contains("nine out of ten is very good"))
	beats = SideQuestPlay.play(st, "svalich_road/tser_camp:iancu")
	assert_true(SideQuestPlay.text(beats).contains("sent word from Krezk"))
	beats = SideQuestPlay.play(st, "svalich_road/the_spiders_gully:cocoon")
	assert_true(SideQuestPlay.text(beats).contains("Nothing else"))
