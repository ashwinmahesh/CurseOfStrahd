extends TestCase
## Mother's Ninth Improvement (docs/story/side_quests.md): Clovin's news, Mother under her blanket (not while the Abbot
## is improving), her boys in the cells first, the silver wire, the courtyard wall, and the boots given once.

const SIX: Array[String] = ["wren_featherfoot", "liriel_dawnsong", "godrick_pendlebrook", "ratatoille"]


func _abbey(fate: String = "repentant") -> StoryState:
	var st := SideQuestPlay.party(SIX, 7, "abbey_of_st_markovia", 11)
	st.set_flag("clovin_met")
	if fate != "":
		st.set_flag("abbot_fate", fate)
	return st


func test_the_wire_the_wall_and_the_flight() -> void:
	var st := _abbey()
	st.set_flag("clovin_family_found")
	var beats := SideQuestPlay.play(st, "abbey_of_st_markovia/clovin:start", ["Heard anything interesting?"])
	assert_eq(SideQuestPlay.missing(beats), "")
	assert_true(SideQuestPlay.text(beats).contains("Sunday soup"))
	assert_eq(st.quest_stage("mothers_ninth_improvement"), "rumored")
	st.location = "abbey_of_st_markovia_wards"
	assert_eq(SideQuestPlay.standing(st, "abbey_of_st_markovia_wards", "belview_mother"), "abbey_of_st_markovia/mothers_ninth_improvement:mother")
	beats = SideQuestPlay.play(st, "abbey_of_st_markovia/mothers_ninth_improvement:mother", ["What do you need first?"])
	assert_eq(SideQuestPlay.missing(beats), "")
	assert_true(SideQuestPlay.text(beats).contains("stitched shut") or SideQuestPlay.text(beats).contains("bound shut"))
	assert_true(SideQuestPlay.text(beats).contains("My boys first"), "the cells come first")
	assert_eq(st.quest_stage("mothers_ninth_improvement"), "asked")
	assert_false(bool(st.get_flag("cells_seen_to", false)))
	# The cells let out (the abbey's own scene), then the wire, then the wall.
	st.set_flag("wards_cells_freed")
	var flown := false
	for seed: int in [1, 2, 3, 5]:
		var copy := _abbey()
		copy.location = "abbey_of_st_markovia_wards"
		copy.flags = st.flags.duplicate(true)
		copy.quests = st.quests.duplicate(true)
		beats = SideQuestPlay.play(copy, "abbey_of_st_markovia/mothers_ninth_improvement:mother",
			["What do you need first?", "Take the stitches out", "Help her up", "Let Wren tell her", "Shout down"], seed)
		assert_eq(SideQuestPlay.missing(beats), "")
		var said := SideQuestPlay.text(beats)
		assert_true(said.contains("ran up the mountain"))
		assert_true(said.contains("Krezk isn't going anywhere"), "Wren talks her off the wall")
		assert_true(said.contains("Old Pavel's house") or said.contains("goat pens"))
		assert_true(bool(copy.get_flag("mother_flown", false)))
		assert_eq(copy.quest_stage("mothers_ninth_improvement"), "done")
		assert_true(copy.party_has_item("boots_of_levitation"))
		assert_eq(SideQuestPlay.standing(copy, "abbey_of_st_markovia_wards", "belview_mother"), "", "she's gone down the mountain")
		copy.location = "krezk"
		beats = SideQuestPlay.play(copy, "krezk/townsfolk:carver", ["Good day"])
		assert_true(SideQuestPlay.text(beats).contains("lands on my roof"))
		copy.location = "abbey_of_st_markovia"
		beats = SideQuestPlay.play(copy, "abbey_of_st_markovia/clovin:start", ["Heard anything interesting?"])
		assert_true(SideQuestPlay.text(beats).contains("Lands on Great-uncle Pavel's roof"))
		flown = true
		break
	assert_true(flown)


func test_not_while_hes_improving() -> void:
	var st := _abbey("")
	st.location = "abbey_of_st_markovia_wards"
	var beats := SideQuestPlay.play(st, "abbey_of_st_markovia/mothers_ninth_improvement:mother")
	assert_true(SideQuestPlay.text(beats).contains("Not while he's improving"))
	assert_eq(st.quest_stage("mothers_ninth_improvement"), "")


func test_if_her_boys_were_killed_she_still_goes() -> void:
	var st := _abbey("slain")
	st.location = "abbey_of_st_markovia_wards"
	st.set_flag("wards_cells_fought")
	var beats := SideQuestPlay.play(st, "abbey_of_st_markovia/mothers_ninth_improvement:mother", ["What do you need first?", "Goodbye"])
	assert_true(SideQuestPlay.text(beats).contains("They're dead"))
	assert_true(bool(st.get_flag("cells_seen_to", false)))
