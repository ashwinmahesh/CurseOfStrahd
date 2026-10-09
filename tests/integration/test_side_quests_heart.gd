extends TestCase
## The Mountain's Heart (docs/story/side_quests.md): Freydis's news once her grandmother is laid, the cracked cairn at
## the Tsolenka landing, the captives chained by the crate in the Ghakis Quarry, Grandfather Stone standing up out of
## the floor, and his heart carried home or kept.

const FOUR: Array[String] = ["liriel_dawnsong", "godrick_pendlebrook", "wren_featherfoot", "thistle"]
const QUARRY := "ghakis_quarry"


func test_freydis_says_grandfather_is_walking() -> void:
	var st := SideQuestPlay.party(FOUR, 9, "yester_hill", 12)
	st.set_quest_stage("the_barrow_on_yester_hill", "done")
	var beats := SideQuestPlay.play(st, "yester_hill/the_barrow:freydis")
	assert_true(SideQuestPlay.text(beats).contains("She's in the mound"), "not before level 10")
	assert_eq(st.quest_stage("the_mountains_heart"), "")
	st = SideQuestPlay.party(FOUR, 10, "yester_hill", 12)
	st.set_quest_stage("the_barrow_on_yester_hill", "done")
	beats = SideQuestPlay.play(st, "yester_hill/the_barrow:freydis")
	assert_true(SideQuestPlay.text(beats).contains("Grandfather's walking"))
	assert_eq(st.quest_stage("the_mountains_heart"), "asked")
	beats = SideQuestPlay.play(st, "yester_hill/the_barrow:freydis")
	assert_true(SideQuestPlay.text(beats).contains("She's in the mound"), "she says it once")


func test_the_cracked_cairn() -> void:
	var st := SideQuestPlay.party(FOUR, 9, "tsolenka_pass", 12)
	assert_false(SideQuestPlay.shown(st, "tsolenka_pass", "tsolenka_folk_cairn"), "not before level 10")
	st = SideQuestPlay.party(FOUR, 10, "tsolenka_pass", 12)
	assert_true(SideQuestPlay.shown(st, "tsolenka_pass", "tsolenka_folk_cairn"))
	var beats := SideQuestPlay.play(st, "mount_ghakis/the_mountains_heart:cairn")
	assert_true(SideQuestPlay.text(beats).contains("GRANDFATHER WALKS"))
	assert_eq(st.quest_stage("the_mountains_heart"), "asked")


func test_the_captives_and_the_crate() -> void:
	var st := SideQuestPlay.party(FOUR, 10, QUARRY, 12)
	assert_eq(SideQuestPlay.standing(st, QUARRY, "quarry_captive"), "", "nobody there before the quest")
	st.set_quest_stage("the_mountains_heart", "asked")
	assert_eq(SideQuestPlay.standing(st, QUARRY, "quarry_captive"), "mount_ghakis/the_mountains_heart:captive")
	var beats := SideQuestPlay.play(st, "mount_ghakis/the_mountains_heart:captive", ["Break their chain"])
	assert_eq(SideQuestPlay.missing(beats), "")
	var said := SideQuestPlay.text(beats)
	assert_true(said.contains("so whatever comes for it eats us first"))
	assert_true(said.contains("Then it stands up"))
	assert_eq(SideQuestPlay.combat_of(beats), "grandfather_stone")
	var enc := SideQuestPlay.encounter(st, QUARRY, "grandfather_stone")
	assert_true(SideQuestPlay.has_foe(enc, "grandfather_stone"))
	assert_eq((enc["monsters"] as Array).size(), 1, "he comes alone")


func test_the_heart_goes_home() -> void:
	var st := SideQuestPlay.party(FOUR, 10, QUARRY, 12)
	st.set_quest_stage("the_mountains_heart", "stilled")
	st.set_flag("grandfather_stilled")
	st.gold = 0
	var beats := SideQuestPlay.play(st, "mount_ghakis/the_mountains_heart:captive", ["Carry the heart back"])
	assert_eq(SideQuestPlay.missing(beats), "")
	assert_true(SideQuestPlay.text(beats).contains("the rock closes over it like water"))
	assert_eq(st.quest_stage("the_mountains_heart"), "done")
	assert_true(st.party_has_item("belt_of_giant_strength_stone"))
	assert_eq(roundi(st.gold), 400)
	assert_eq(SideQuestPlay.standing(st, QUARRY, "quarry_captive"), "", "the mountain folk go home")
	beats = SideQuestPlay.play(st, "mount_ghakis/the_mountains_heart:cairn")
	assert_true(SideQuestPlay.text(beats).contains("the stone is warm"))


func test_the_heart_kept() -> void:
	var st := SideQuestPlay.party(FOUR, 10, QUARRY, 12)
	st.set_quest_stage("the_mountains_heart", "stilled")
	st.set_flag("grandfather_stilled")
	var beats := SideQuestPlay.play(st, "mount_ghakis/the_mountains_heart:captive", ["Keep the heart"])
	assert_eq(SideQuestPlay.missing(beats), "")
	assert_true(SideQuestPlay.text(beats).contains("turns over in its sleep"))
	assert_eq(st.quest_stage("the_mountains_heart"), "done")
	assert_true(st.party_has_item("stone_of_controlling_earth_elementals"))
	assert_false(st.party_has_item("belt_of_giant_strength_stone"))
