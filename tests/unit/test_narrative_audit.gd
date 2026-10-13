extends TestCase
## The Narrative Audit (vault "Narrative Audit.md", Ashwin 2026-10-12: "Some scenes / chapters need more explanation on
## the significance. Ex) the effigy on Yester Hill."): each big moment says what it is and why it matters on the paths
## a player actually takes, not only behind an optional question.


# ---------------------------------------------------------------- Batch 1: Yester Hill

## Pledging to Davian before asking about the hill used to hide his answer for good (the pledge set yester_hill_known).
func test_a_party_that_pledges_first_still_hears_what_the_hill_is_for() -> void:
	var st := SideQuestPlay.party(["ilse_varga"], 6, "wizard_of_wines", 12)
	var beats := SideQuestPlay.play(st, "wizard_of_wines/davian:start", ["We'll clear your house", "Goodbye"])
	assert_eq(SideQuestPlay.missing(beats), "")
	var said := SideQuestPlay.text(beats)
	assert_true(said.contains("in the likeness of the lord in the castle"), said)
	assert_true(said.contains("he walks east"), said)
	assert_true(bool(st.get_flag("yester_effigy_known", false)))
	assert_true(str(QuestLog.journal(st)).contains("a giant of earth in the likeness of the lord in the castle"),
		"the journal says it too")


func test_davian_does_not_tell_it_twice() -> void:
	var st := SideQuestPlay.party(["ilse_varga"], 6, "wizard_of_wines", 12)
	var beats := SideQuestPlay.play(st, "wizard_of_wines/davian:start",
		["What do the druids want", "We'll clear your house", "Goodbye"])
	assert_eq(SideQuestPlay.missing(beats), "")
	var said := SideQuestPlay.text(beats)
	assert_true(said.contains("he walks east"), said)
	assert_false(said.contains("there is a great deal to say about it"), said)


## Ashwin's own path: Kostin scared off, the gully, and the first blow before anyone speaks.
func test_kostin_shouts_what_waits_on_the_hill_as_he_runs() -> void:
	var st := SideQuestPlay.party(["ilse_varga"], 6, "wizard_of_wines_press_house", 12)
	var said := SideQuestPlay.text(SideQuestPlay.play(st, "wizard_of_wines/kostin:scared"))
	assert_true(said.contains("tread the bird-man's vines into the mud"), said)


func test_a_party_that_strikes_first_hears_the_chant() -> void:
	var st := SideQuestPlay.party(["ilse_varga"], 6, "yester_hill_gulthias_tree", 20)
	st.set_flag("yester_sneaked")
	var beats := SideQuestPlay.play(st, "yester_hill/ruxandra:summit", ["Strike now"])
	assert_eq(SideQuestPlay.missing(beats), "")
	assert_true(SideQuestPlay.text(beats).contains("Walk east. Tread the ravens' vines into the mud."))
	assert_eq(SideQuestPlay.combat_of(beats), "summit_ritual")
	assert_true(bool(st.get_flag("yester_effigy_known", false)))


func test_ruxandra_says_what_the_effigy_is_for() -> void:
	var st := SideQuestPlay.party(["ilse_varga"], 6, "yester_hill_gulthias_tree", 20)
	var beats := SideQuestPlay.play(st, "yester_hill/ruxandra:summit", ["Why give it his face", "We're taking the stone"])
	assert_eq(SideQuestPlay.missing(beats), "")
	var said := SideQuestPlay.text(beats)
	assert_true(said.contains("go east, and put his foot down on the ravens' vines"), said)
	assert_true(said.contains("A god should have a face"), said)
	assert_eq(SideQuestPlay.combat_of(beats), "summit_ritual")


func test_the_broken_giant_is_said_to_be_harmless() -> void:
	var st := SideQuestPlay.party(["ilse_varga"], 6, "yester_hill_gulthias_tree", 20)
	st.set_flag("davian_met")
	st.set_flag("yester_hill_resolved")
	var said := SideQuestPlay.text(SideQuestPlay.play(st, "yester_hill/summit:heart"))
	assert_true(said.contains("is only firewood"), said)
	st.set_flag("winery_reclaimed")
	said = SideQuestPlay.text(SideQuestPlay.play(st, "wizard_of_wines/davian:hill_report"))
	assert_true(said.contains("So it won't walk."), said)


# ---------------------------------------------------------------- Batch 2: Krezk and the Abbey

## The Abbot's nature was only told to a cleric, a paladin or a Religion check; now he says he was sent.
func test_the_abbot_says_he_was_sent() -> void:
	var st := SideQuestPlay.party(["ilse_varga"], 7, "abbey_of_st_markovia_shrine", 12)
	st.set_flag("abbot_met")
	var beats := SideQuestPlay.play(st, "abbey_of_st_markovia/abbot:start", ["Who are you?", "Goodbye"])
	assert_eq(SideQuestPlay.missing(beats), "")
	assert_true(SideQuestPlay.text(beats).contains("I was sent here, long ago, to keep the faith of this valley"))


## Without Stanimir's tale or Tamsin's locket, nobody at the pool said who the young man in the water was.
func test_the_pool_says_who_sergei_is() -> void:
	var st := SideQuestPlay.party(["godrick_pendlebrook"], 7, "krezk_pool_of_the_white_sun", 12)
	assert_true(st.add_guest("ireena"))
	var beats := SideQuestPlay.play(st, "krezk/pool:the_pool", ["Stay with us"])
	assert_eq(SideQuestPlay.missing(beats), "")
	assert_true(SideQuestPlay.text(beats).contains("She was meant to marry this one."))
	var told := SideQuestPlay.party(["godrick_pendlebrook"], 7, "krezk_pool_of_the_white_sun", 12)
	assert_true(told.add_guest("ireena"))
	told.set_flag("stanimir_tale_heard")
	beats = SideQuestPlay.play(told, "krezk/pool:the_pool", ["Stay with us"])
	assert_false(SideQuestPlay.text(beats).contains("She was meant to marry this one."), "the tale already said it")
