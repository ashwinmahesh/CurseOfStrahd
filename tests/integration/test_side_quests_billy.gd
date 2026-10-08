extends TestCase
## The One-Horned Billy (docs/story/side_quests.md): Stelian's rumour, the ring on the billy's horn, Remove Curse (or
## a scroll) making him Dragos, the Rag Queen in Berez's scarecrow field, and Dragos paying once.

const PARTY: Array[String] = ["godrick_pendlebrook", "liriel_dawnsong", "thistle", "ratatoille"]


func test_the_ring_the_curse_and_the_rag_queen() -> void:
	var st := SideQuestPlay.party(PARTY, 9, "krezk", 11)
	st.set_flag("krezk_gate_open")
	SideQuestPlay.play(st, "krezk/townsfolk:goatherd")
	assert_eq(st.quest_stage("one_horned_billy"), "rumored")
	# Animal Handling to read the ring: try a few dice.
	for seed: int in [1, 2, 3, 4, 5, 6]:
		SideQuestPlay.play(st, "krezk/townsfolk:billy", ["Get close enough to look at the ring"], seed)
		if bool(st.get_flag("billy_ring_read", false)):
			break
	assert_true(bool(st.get_flag("billy_ring_read", false)), "someone reads the ring")
	assert_eq(st.quest_stage("one_horned_billy"), "the_ring")
	assert_true(StoryConditions.check("knows:remove_curse", st), "Liriel has Remove Curse at level 9")
	var beats := SideQuestPlay.play(st, "krezk/townsfolk:billy", ["Cast Remove Curse"])
	assert_eq(SideQuestPlay.missing(beats), "")
	assert_true(bool(st.get_flag("dragos_freed", false)))
	assert_eq(st.quest_stage("one_horned_billy"), "dragos")
	assert_true(SideQuestPlay.text(beats).contains("Rag Queen") or SideQuestPlay.text(beats).contains("queen"))
	assert_eq(SideQuestPlay.standing(st, "krezk", "krezk_billy_goat"), "", "the goat's gone from the pen")
	assert_eq(SideQuestPlay.standing(st, "krezk", "krezk_dragos"), "krezk/one_horned_billy:dragos")
	st.location = "berez"
	beats = SideQuestPlay.play(st, "krezk/one_horned_billy:field", ["Burn it"])
	assert_true(SideQuestPlay.text(beats).contains("eyes are shut"), "Vera's face in the stitching, now you know to look")
	assert_eq(SideQuestPlay.combat_of(beats), "rag_queen")
	var enc := SideQuestPlay.encounter(st, "berez", "rag_queen")
	assert_true(SideQuestPlay.has_foe(enc, "rag_queen"))
	assert_true(SideQuestPlay.xp(enc) >= 7000, "the hardest batch 2 fight at level 9: %d" % SideQuestPlay.xp(enc))
	st.set_flag("rag_queen_beaten")
	st.set_quest_stage("one_horned_billy", "burned")
	st.location = "krezk"
	st.gold = 0
	SideQuestPlay.play(st, "krezk/one_horned_billy:dragos")
	assert_eq(st.quest_stage("one_horned_billy"), "vera_freed")
	assert_eq(roundi(st.gold), 500)
	assert_true(st.party_has_item("dancing_sword") or st.party.any(func(c: Character) -> bool: return c.carries("dancing_sword__longsword")))
	SideQuestPlay.play(st, "krezk/one_horned_billy:dragos")
	assert_eq(roundi(st.gold), 500, "paid once")


func test_a_scroll_frees_him_without_a_cleric() -> void:
	var st := SideQuestPlay.party(["godrick_pendlebrook", "thistle", "wren_featherfoot", "kip_smudgewick"], 7, "krezk", 11)
	st.set_flag("billy_eyes_seen")
	st.set_quest_stage("one_horned_billy", "the_ring")
	assert_false(StoryConditions.check("knows:remove_curse", st))
	(st.party[0] as Character).add_item("spell_scroll__remove_curse")
	var beats := SideQuestPlay.play(st, "krezk/townsfolk:billy", ["Read a Scroll of Remove Curse"])
	assert_eq(SideQuestPlay.missing(beats), "")
	assert_true(bool(st.get_flag("dragos_freed", false)))
	assert_false(st.party_has_item("spell_scroll__remove_curse"), "the scroll is used up")


func test_the_rag_queen_is_a_boss() -> void:
	var q := Compendium.shared().get_entry("monsters", "rag_queen")
	assert_eq(str(q["size"]), "huge")
	assert_eq(int(q["cr"]), 10)
	assert_true("fire" in (q["vulnerabilities"] as Array))
	assert_eq(str(q["art"]), "scarecrow")
