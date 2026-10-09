extends TestCase
## The Forgotten Storm (docs/story/side_quests.md): the mage on the lightning from level 8, mad or himself, the ring of
## glass at dusk, the count's two words in the spell, Corvina's name (at rest, or in the castle), the censer in the
## glass and the mage's thanks.

const FOUR: Array[String] = ["liriel_dawnsong", "godrick_pendlebrook", "wren_featherfoot", "thistle"]
const MOUNTAIN := "mount_baratok"


func test_the_mad_mage_asks_about_his_lightning() -> void:
	var st := SideQuestPlay.party(FOUR, 7, "mount_baratok_hut", 14)
	st.set_flag("mordenkainen_met")
	var beats := SideQuestPlay.play(st, "mount_baratok/mordenkainen:mad_menu", ["The lightning that lands"])
	assert_ne(SideQuestPlay.missing(beats), "", "not before level 8")
	st = SideQuestPlay.party(FOUR, 8, "mount_baratok_hut", 14)
	st.set_flag("mordenkainen_met")
	beats = SideQuestPlay.play(st, "mount_baratok/mordenkainen:mad_menu", ["The lightning that lands", "Goodbye"])
	assert_eq(SideQuestPlay.missing(beats), "")
	assert_true(SideQuestPlay.text(beats).contains("I'm fairly sure it wants me"))
	assert_eq(st.quest_stage("the_forgotten_storm"), "asked")


func test_mordenkainen_knows_his_storm() -> void:
	var st := SideQuestPlay.party(FOUR, 9, "mount_baratok_hut", 14)
	st.set_flag("mordenkainen_restored")
	var beats := SideQuestPlay.play(st, "mount_baratok/mordenkainen:restored_menu", ["The lightning that lands", "Goodbye"])
	assert_eq(SideQuestPlay.missing(beats), "")
	assert_true(SideQuestPlay.text(beats).contains("bring her after me"))
	assert_eq(st.quest_stage("the_forgotten_storm"), "asked")


func test_at_dusk_on_the_glass() -> void:
	var st := SideQuestPlay.party(FOUR, 8, MOUNTAIN, 12)
	var beats := SideQuestPlay.play(st, "mount_baratok/the_forgotten_storm:glass")
	assert_true(SideQuestPlay.text(beats).contains("struck the same place"), "before the quest")
	st.set_quest_stage("the_forgotten_storm", "asked")
	beats = SideQuestPlay.play(st, "mount_baratok/the_forgotten_storm:glass", ["Wait here for dusk", "Read the spell", "Stand your ground"], 3)
	assert_eq(SideQuestPlay.missing(beats), "")
	var said := SideQuestPlay.text(beats)
	assert_true(said.contains("WHERE IS SHE"))
	assert_eq(st.minute_of_day / 60, 19, "dusk")
	assert_eq(SideQuestPlay.combat_of(beats), "forgotten_storm")
	assert_true(SideQuestPlay.has_foe(SideQuestPlay.encounter(st, MOUNTAIN, "forgotten_storm"), "forgotten_storm"))
	beats = SideQuestPlay.play(st, "mount_baratok/the_forgotten_storm:arcana", ["Stand your ground"])
	assert_true(SideQuestPlay.text(beats).contains("and him"))
	assert_true(st.get_flag("storm_spell_read", false))


func test_told_she_is_in_the_castle() -> void:
	var st := SideQuestPlay.party(FOUR, 8, MOUNTAIN, 20)
	st.set_quest_stage("the_forgotten_storm", "asked")
	st.set_flag("corvina_letter_2")
	var beats := SideQuestPlay.play(st, "mount_baratok/the_forgotten_storm:dusk", ["Say her name", "In the count's castle"])
	assert_eq(SideQuestPlay.missing(beats), "")
	assert_eq(st.minute_of_day / 60, 20, "no waiting after dark")
	assert_true(SideQuestPlay.text(beats).contains("It can't go there"))
	assert_eq(SideQuestPlay.combat_of(beats), "forgotten_storm")
	var enc := SideQuestPlay.encounter(st, MOUNTAIN, "forgotten_storm")
	assert_eq(int((enc["monsters"] as Array)[0].get("hp", 0)), 110, "spent against the sky")


func test_told_she_is_at_rest() -> void:
	var st := SideQuestPlay.party(FOUR, 9, MOUNTAIN, 20)
	st.set_quest_stage("the_forgotten_storm", "asked")
	st.set_flag("corvina_name_known")
	st.set_flag("corvina_slain")
	st.set_flag("mordenkainen_restored")
	st.gold = 0
	var beats := SideQuestPlay.play(st, "mount_baratok/the_forgotten_storm:dusk", ["Say her name", "She's at rest"])
	assert_eq(SideQuestPlay.missing(beats), "")
	var said := SideQuestPlay.text(beats)
	assert_true(said.contains("like a held breath"))
	assert_true(said.contains("little brass censer"))
	assert_eq(SideQuestPlay.combat_of(beats), "", "no fight")
	assert_eq(st.quest_stage("the_forgotten_storm"), "broken")
	assert_true(st.party_has_item("censer_of_controlling_air_elementals"))
	st.location = "mount_baratok_hut"
	beats = SideQuestPlay.play(st, "mount_baratok/mordenkainen:start", ["Goodbye"])
	assert_true(SideQuestPlay.text(beats).contains("nobody's angry on it"))
	assert_eq(st.quest_stage("the_forgotten_storm"), "done")
	assert_eq(roundi(st.gold), 250)
