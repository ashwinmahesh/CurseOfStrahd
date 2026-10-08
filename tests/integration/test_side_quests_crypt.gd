extends TestCase
## The Unnamed Crypt (docs/story/side_quests.md): Pidlwick's news, the crypt with no name, Corvina's name said (or not)
## before she rises, the reward given once, and Mordenkainen hearing of it.

const SIX: Array[String] = ["liriel_dawnsong", "godrick_pendlebrook", "ratatoille", "thistle"]


func _catacombs() -> StoryState:
	return SideQuestPlay.party(SIX, 10, "castle_ravenloft_catacombs", 23)


func test_the_name_said_before_she_rises() -> void:
	var st := _catacombs()
	st.location = "castle_ravenloft_spires"
	st.set_flag("pidlwick_met")
	var beats := SideQuestPlay.play(st, "castle_ravenloft/spires_pidlwick:start", ["Heard anything interesting?"])
	assert_eq(SideQuestPlay.missing(beats), "")
	assert_true(SideQuestPlay.text(beats).contains("EVEN THE HORSE"))
	assert_eq(st.quest_stage("the_unnamed_crypt"), "rumored")
	st.location = "castle_ravenloft_catacombs"
	st.set_flag("corvina_name_known")
	assert_true(SideQuestPlay.shown(st, "castle_ravenloft_catacombs", "unnamed_crypt"))
	beats = SideQuestPlay.play(st, "castle_ravenloft/the_unnamed_crypt:crypt", ["Corvina."])
	assert_eq(SideQuestPlay.missing(beats), "")
	assert_true(SideQuestPlay.text(beats).contains("He remembered"))
	assert_eq(SideQuestPlay.combat_of(beats), "corvina")
	var enc := SideQuestPlay.encounter(st, "castle_ravenloft_catacombs", "corvina")
	var her := (enc["monsters"] as Array).filter(func(m: Variant) -> bool: return str((m as Dictionary)["monster"]) == "corvina")
	assert_true(int((her[0] as Dictionary).get("hp", 999)) < 165, "her name weakens what holds her")
	st.set_flag("corvina_slain")
	st.gold = 0
	beats = SideQuestPlay.play(st, "castle_ravenloft/the_unnamed_crypt:crypt")
	assert_true(SideQuestPlay.text(beats).contains("Put it on the box"))
	assert_eq(st.quest_stage("the_unnamed_crypt"), "done")
	assert_eq(roundi(st.gold), 500)
	assert_true(st.party_has_item("rod_of_absorption"))
	beats = SideQuestPlay.play(st, "castle_ravenloft/the_unnamed_crypt:crypt")
	assert_true(SideQuestPlay.text(beats).contains("CORVINA"))
	assert_eq(roundi(st.gold), 500, "paid once")
	# Mordenkainen hears. At level 10 his first news is Khazan under the tower (The Name Over the Door); she comes next.
	st.location = "mount_baratok_hut"
	st.set_flag("mordenkainen_met")
	st.set_flag("mordenkainen_restored")
	beats = SideQuestPlay.play(st, "mount_baratok/mordenkainen:start", ["Heard anything interesting?", "Heard anything interesting?", "Goodbye"])
	assert_true(SideQuestPlay.text(beats).contains("Khazan"))
	assert_true(SideQuestPlay.text(beats).contains("ink on her fingers"))


func test_without_her_name_the_lid_is_all_there_is() -> void:
	var st := _catacombs()
	var beats := SideQuestPlay.play(st, "castle_ravenloft/the_unnamed_crypt:crypt", ["Corvina."])
	assert_true(SideQuestPlay.missing(beats).contains("Corvina."), "nobody here knows it")
	beats = SideQuestPlay.play(st, "castle_ravenloft/the_unnamed_crypt:crypt", ["Lift the lid"])
	assert_eq(SideQuestPlay.combat_of(beats), "corvina")
	assert_eq(st.quest_stage("the_unnamed_crypt"), "found")
	var enc := SideQuestPlay.encounter(st, "castle_ravenloft_catacombs", "corvina")
	assert_true(SideQuestPlay.has_foe(enc, "A Door-Warden"))
	st.set_flag("corvina_slain")
	beats = SideQuestPlay.play(st, "castle_ravenloft/the_unnamed_crypt:crypt")
	assert_true(SideQuestPlay.text(beats).contains("a name at the bottom: Corvina"))
