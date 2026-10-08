extends TestCase
## The Pack's Runt (docs/story/side_quests.md): the Krezk watchman's news once the den's children are home, Petru in
## the goat pens, the wolf in him seen and lifted, the Grandsire at the full moon, his bargain, and Krezk's bounty paid
## once.

const SIX: Array[String] = ["liriel_dawnsong", "thistle", "godrick_pendlebrook", "ratatoille"]


func _krezk(hour: int = 12) -> StoryState:
	var st := SideQuestPlay.party(SIX, 8, "krezk", hour)
	st.set_flag("krezk_gate_open")
	st.set_flag("den_children_freed")
	return st


func test_the_news_the_cure_and_the_grandsire() -> void:
	var st := _krezk()
	var beats := SideQuestPlay.play(st, "krezk/gate:news")
	assert_true(SideQuestPlay.text(beats).contains("sleeps in the goat pens"))
	assert_eq(st.quest_stage("the_packs_runt"), "rumored")
	assert_eq(SideQuestPlay.standing(st, "krezk", "krezk_petru"), "krezk/the_packs_runt:petru")
	beats = SideQuestPlay.play(st, "krezk/the_packs_runt:petru", ["What happened to you in the den?", "Goodbye"])
	assert_eq(SideQuestPlay.missing(beats), "")
	assert_true(SideQuestPlay.text(beats).contains("the Grandsire"))
	assert_eq(st.quest_stage("the_packs_runt"), "asked")
	for seed: int in [1, 2, 3]:
		SideQuestPlay.play(st, "krezk/the_packs_runt:petru", ["Look at him the way a goat would", "Goodbye"], seed)
		if bool(st.get_flag("petru_seen", false)):
			break
	# Liriel leads, and prepares Remove Curse.
	beats = SideQuestPlay.play(st, "krezk/the_packs_runt:petru", ["Lift the curse from him", "Goodbye"])
	assert_eq(SideQuestPlay.missing(beats), "")
	assert_true(bool(st.get_flag("petru_cured", false)))
	assert_true(SideQuestPlay.text(beats).contains("I can't smell the rain any more"))
	beats = SideQuestPlay.play(st, "krezk/the_packs_runt:petru", ["Wait with him by the pens"])
	assert_true(SideQuestPlay.missing(beats).contains("Wait with him"), "only after dark")
	st.minute_of_day = 23 * 60
	beats = SideQuestPlay.play(st, "krezk/the_packs_runt:petru", ["Wait with him by the pens", "Stand in front of the boy"])
	assert_eq(SideQuestPlay.missing(beats), "")
	assert_true(SideQuestPlay.text(beats).contains("What have you done to my runt"))
	assert_eq(SideQuestPlay.combat_of(beats), "grandsire")
	var enc := SideQuestPlay.encounter(st, "krezk", "grandsire")
	assert_true(SideQuestPlay.has_foe(enc, "the_grandsire"))
	assert_true(SideQuestPlay.xp(enc) >= 6800, "Moderate for level 8: %d" % SideQuestPlay.xp(enc))
	st.set_flag("grandsire_slain")
	st.gold = 0
	beats = SideQuestPlay.play(st, "krezk/the_packs_runt:petru")
	assert_true(SideQuestPlay.text(beats).contains("for the wolf that never came"))
	assert_eq(st.quest_stage("the_packs_runt"), "done")
	assert_eq(roundi(st.gold), 300)
	assert_true(st.party_has_item("iron_bands_of_bilarro"))
	beats = SideQuestPlay.play(st, "krezk/the_packs_runt:petru")
	assert_true(SideQuestPlay.text(beats).contains("I'm a boy all month now"))
	assert_eq(roundi(st.gold), 300, "paid once")
	beats = SideQuestPlay.play(st, "krezk/gate:news")
	assert_true(SideQuestPlay.text(beats).contains("Petru sleeps in a bed"))


func test_the_grandsires_bargain() -> void:
	var st := _krezk(23)
	st.set_quest_stage("the_packs_runt", "asked")
	var beats := SideQuestPlay.play(st, "krezk/the_packs_runt:petru", ["Wait with him by the pens", "Hear what it wants", "Give Petru to the Grandsire"])
	assert_eq(SideQuestPlay.missing(beats), "")
	assert_eq(SideQuestPlay.combat_of(beats), "")
	assert_eq(st.quest_stage("the_packs_runt"), "given")
	assert_eq(SideQuestPlay.standing(st, "krezk", "krezk_petru"), "", "he's gone with the pack")


func test_no_runt_until_the_children_are_home() -> void:
	var st := SideQuestPlay.party(SIX, 8, "krezk", 12)
	st.set_flag("krezk_gate_open")
	assert_eq(SideQuestPlay.standing(st, "krezk", "krezk_petru"), "")
	var beats := SideQuestPlay.play(st, "krezk/gate:news")
	assert_false(SideQuestPlay.text(beats).contains("goat pens"))
