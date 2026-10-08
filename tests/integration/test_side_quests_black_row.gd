extends TestCase
## The Black Row (docs/story/side_quests.md): Andrei's warning, Davian's news, the Seventh Row by day, the night watch
## and Adrian in the vines, the Vine Mother woken with or without him, and Davian's wand paid once.

const SIX: Array[String] = ["godrick_pendlebrook", "liriel_dawnsong", "thistle", "ratatoille"]


func _home(hour: int = 11) -> StoryState:
	var st := SideQuestPlay.party(SIX, 6, "wizard_of_wines", hour)
	for f: String in ["davian_met", "adrian_met", "winery_reclaimed"]:
		st.set_flag(f)
	return st


func test_the_rumour_the_row_and_adrian_brought_round() -> void:
	var st := _home()
	var beats := SideQuestPlay.play(st, "wizard_of_wines/hands:picker")
	assert_true(SideQuestPlay.text(beats).contains("Seventh Row"))
	assert_eq(st.quest_stage("the_black_row"), "rumored")
	beats = SideQuestPlay.play(st, "wizard_of_wines/davian:start", ["Heard anything interesting?", "Goodbye"])
	assert_eq(SideQuestPlay.missing(beats), "")
	assert_eq(st.quest_stage("the_black_row"), "asked")
	assert_true(SideQuestPlay.shown(st, "wizard_of_wines", "seventh_row"))
	# By day the row can be looked at, but there's nobody to wait for.
	beats = SideQuestPlay.play(st, "wizard_of_wines/the_black_row:row", ["Look at where the vine meets the root", "Leave it"], 3)
	assert_eq(SideQuestPlay.missing(beats), "")
	assert_true(SideQuestPlay.text(beats).contains("wearing the vines like sleeves") or SideQuestPlay.text(beats).contains("That's all you can tell"))
	beats = SideQuestPlay.play(st, "wizard_of_wines/the_black_row:row", ["Wait in the vines"])
	assert_true(SideQuestPlay.missing(beats).contains("Wait in the vines"), "not by day")
	# After dark: Adrian. The family has made its peace, so he listens.
	st.set_flag("martikovs_reconciled")
	st.set_flag("elvir_buried")
	st.minute_of_day = 23 * 60
	beats = SideQuestPlay.play(st, "wizard_of_wines/the_black_row:row", ["Wait in the vines", "Step out of the vines", "Your father forgave you"])
	assert_eq(SideQuestPlay.missing(beats), "")
	var said := SideQuestPlay.text(beats)
	assert_true(said.contains("Adrian Martikov in his shirtsleeves"))
	assert_true(said.contains("where his brother is buried"))
	assert_true(said.contains("almost a Martikov's"), "it's been drinking from Elvir's grave")
	assert_eq(SideQuestPlay.combat_of(beats), "vine_mother")
	assert_true("adrian_martikov" in st.guest_ids, "Adrian fights beside the party")
	var enc := SideQuestPlay.encounter(st, "wizard_of_wines", "vine_mother")
	assert_true(SideQuestPlay.has_foe(enc, "vine_mother"))
	assert_true(SideQuestPlay.xp(enc) >= 4400, "High for level 6: %d" % SideQuestPlay.xp(enc))
	# Davian pays once.
	st.set_flag("vine_mother_slain")
	st.set_quest_stage("the_black_row", "cut_out")
	st.minute_of_day = 11 * 60
	st.gold = 0
	beats = SideQuestPlay.play(st, "wizard_of_wines/davian:start", ["Your Seventh Row is cut out", "Goodbye"])
	assert_eq(SideQuestPlay.missing(beats), "")
	assert_true(SideQuestPlay.text(beats).contains("I don't need grapes"))
	assert_eq(st.quest_stage("the_black_row"), "done")
	assert_eq(roundi(st.gold), 250)
	assert_true(st.party_has_item("wand_of_fireballs"))
	assert_false("adrian_martikov" in st.guest_ids, "he goes back to the winery")
	beats = SideQuestPlay.play(st, "wizard_of_wines/davian:start", ["Goodbye"])
	assert_eq(roundi(st.gold), 250, "paid once")
	beats = SideQuestPlay.play(st, "wizard_of_wines/the_black_row:row")
	assert_true(SideQuestPlay.text(beats).contains("rosemary"))


func test_without_the_truth_he_flies_and_the_party_cuts_alone() -> void:
	var cut := false
	for seed: int in [1, 2, 3, 5, 8, 13]:
		var st := _home(23)
		st.set_quest_stage("the_black_row", "asked")
		var beats := SideQuestPlay.play(st, "wizard_of_wines/the_black_row:row", ["Wait in the vines", "Step out of the vines", "That isn't Elvir"], seed)
		assert_eq(SideQuestPlay.missing(beats), "")
		assert_eq(SideQuestPlay.combat_of(beats), "vine_mother")
		if not bool(st.get_flag("adrian_against_row", false)):
			cut = true
			assert_true(SideQuestPlay.text(beats).contains("One more night"))
			assert_false("adrian_martikov" in st.guest_ids)
			assert_false(SideQuestPlay.text(beats).contains("almost a Martikov's"), "Elvir isn't buried there")
			break
	assert_true(cut, "some roll leaves him unconvinced")


func test_the_row_isnt_there_before_the_family_is_home() -> void:
	var st := SideQuestPlay.party(SIX, 6, "wizard_of_wines", 11)
	assert_false(SideQuestPlay.shown(st, "wizard_of_wines", "seventh_row"))
	assert_eq(SideQuestPlay.standing(st, "wizard_of_wines", "wine_picker"), "", "Andrei picks only once they're home")
