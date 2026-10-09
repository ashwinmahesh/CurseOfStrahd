extends TestCase
## The Barrow on Yester Hill (docs/story/side_quests.md): Freydis at the foot of the hill from level 7, what History
## knows about bound bones, Silverjaw's cairn on the barrow slope and the watch that gets up out of it, and the bones
## laid back in the mound.

const FOUR: Array[String] = ["liriel_dawnsong", "godrick_pendlebrook", "kip_smudgewick", "thistle"]
const HILL := "yester_hill"


func test_freydis_wants_her_grandmother() -> void:
	var st := SideQuestPlay.party(FOUR, 6, HILL, 14)
	assert_eq(SideQuestPlay.standing(st, HILL, "freydis"), "", "not before level 7")
	st = SideQuestPlay.party(FOUR, 7, HILL, 14)
	assert_eq(SideQuestPlay.standing(st, HILL, "freydis"), "yester_hill/the_barrow:freydis")
	var beats := SideQuestPlay.play(st, "yester_hill/the_barrow:freydis", ["We'll bring her down"])
	assert_eq(SideQuestPlay.missing(beats), "")
	var said := SideQuestPlay.text(beats)
	assert_true(said.contains("We called her Silverjaw"))
	assert_eq(st.quest_stage("the_barrow_on_yester_hill"), "asked")
	assert_eq(str(SideQuestPlay.encounter(st, HILL, "hill_watch").get("surprise", "")), "party", "unwarned")
	beats = SideQuestPlay.play(st, "yester_hill/the_barrow:warned")
	assert_true(SideQuestPlay.text(beats).contains("the watch gets up"))
	assert_eq(str(SideQuestPlay.encounter(st, HILL, "hill_watch").get("surprise", "")), "", "warned")


func test_the_watch_gets_up_out_of_the_cairn() -> void:
	var st := SideQuestPlay.party(FOUR, 7, HILL, 22)
	var beats := SideQuestPlay.play(st, "yester_hill/the_barrow:cairn")
	assert_true(SideQuestPlay.text(beats).contains("stacked like turnips"), "before the quest")
	st.set_quest_stage("the_barrow_on_yester_hill", "asked")
	beats = SideQuestPlay.play(st, "yester_hill/the_barrow:cairn", ["Lift her out"])
	assert_eq(SideQuestPlay.missing(beats), "")
	var said := SideQuestPlay.text(beats)
	assert_true(said.contains("This hill is watched"))
	assert_eq(SideQuestPlay.combat_of(beats), "hill_watch")
	var enc := SideQuestPlay.encounter(st, HILL, "hill_watch")
	assert_true(SideQuestPlay.has_foe(enc, "Silverjaw"))
	assert_true(SideQuestPlay.has_foe(enc, "A Barrow-Warden"))
	assert_true(SideQuestPlay.has_foe(enc, "The Hill's Watch"))


func test_silverjaw_goes_home_to_the_mound() -> void:
	var st := SideQuestPlay.party(FOUR, 7, HILL, 14)
	st.set_quest_stage("the_barrow_on_yester_hill", "fought")
	st.set_flag("hill_watch_beaten")
	st.gold = 0
	var beats := SideQuestPlay.play(st, "yester_hill/the_barrow:freydis", ["Tell her what got up"])
	assert_eq(SideQuestPlay.missing(beats), "")
	var said := SideQuestPlay.text(beats)
	assert_true(said.contains("Of course she got up"))
	assert_true(said.contains("face to the mountains") or said.contains("facing north"))
	assert_eq(st.quest_stage("the_barrow_on_yester_hill"), "done")
	assert_true(st.party_has_item("blood_amulet"))
	assert_eq(roundi(st.gold), 150)
	beats = SideQuestPlay.play(st, "yester_hill/the_barrow:cairn")
	assert_true(SideQuestPlay.text(beats).contains("just paint now"))
