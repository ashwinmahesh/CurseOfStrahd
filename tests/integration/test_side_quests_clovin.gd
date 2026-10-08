extends TestCase
## Clovin's Audience (docs/story/side_quests.md): the Krezk watchman's bucket story, Clovin's ask at the abbey, Dmitri's
## yes (or the hood), the show in the square by the shrine scored by the beats that land, Old Pavel's father's joke, and
## the hat and the ring paid once.

const WITH_WREN: Array[String] = ["wren_featherfoot", "godrick_pendlebrook", "liriel_dawnsong", "ratatoille"]
const NO_WREN: Array[String] = ["godrick_pendlebrook", "thistle", "liriel_dawnsong", "ratatoille"]


func _krezk(ids: Array[String]) -> StoryState:
	var st := SideQuestPlay.party(ids, 7, "krezk", 12)
	st.set_flag("krezk_gate_open")
	st.set_flag("clovin_met")
	st.set_flag("dmitri_met")
	return st


func test_the_bucket_dmitris_yes_and_a_full_square() -> void:
	var st := _krezk(WITH_WREN)
	var beats := SideQuestPlay.play(st, "krezk/gate:start", ["Heard anything interesting?"])
	assert_eq(SideQuestPlay.missing(beats), "")
	assert_true(SideQuestPlay.text(beats).contains("very good bucket"))
	assert_eq(st.quest_stage("clovins_audience"), "rumored")
	st.location = "abbey_of_st_markovia"
	beats = SideQuestPlay.play(st, "abbey_of_st_markovia/clovin:start", ["The Krezk watch says"])
	assert_eq(SideQuestPlay.missing(beats), "")
	assert_eq(st.quest_stage("clovins_audience"), "asked")
	# Dmitri owes the party a son, so he says yes without a roll.
	st.location = "krezk_burgomaster_house"
	st.set_flag("ilya_fate", "healed")
	beats = SideQuestPlay.play(st, "krezk/dmitri:start", ["Clovin Belview wants", "Goodbye"])
	assert_eq(SideQuestPlay.missing(beats), "")
	assert_eq(st.quest_stage("clovins_audience"), "booked")
	assert_eq(SideQuestPlay.standing(st, "krezk", "clovin_belview"), "", "not at noon")
	st.minute_of_day = 18 * 60
	assert_eq(SideQuestPlay.standing(st, "krezk", "clovin_belview"), "krezk/clovins_audience:show")
	st.location = "krezk"
	st.gold = 0
	beats = SideQuestPlay.play(st, "krezk/clovins_audience:show", ["Let Wren warm them up", "Yourself", "Let Clovin answer him"])
	assert_eq(SideQuestPlay.missing(beats), "")
	var said := SideQuestPlay.text(beats)
	assert_eq(int(st.get_flag("clovin_laughs", 0)), 2)
	assert_true(said.contains("Krezk laughs. Properly"))
	assert_true(said.contains("my father's joke"), "Old Pavel knows the joke")
	assert_eq(st.quest_stage("clovins_audience"), "done")
	assert_eq(roundi(st.gold), 250)
	assert_true(st.party_has_item("ring_of_the_ram"))
	assert_eq(SideQuestPlay.standing(st, "krezk", "clovin_belview"), "", "the show's over")
	beats = SideQuestPlay.play(st, "krezk/townsfolk:carver", ["Good day"])
	assert_true(SideQuestPlay.text(beats).contains("soup"))
	st.location = "abbey_of_st_markovia"
	beats = SideQuestPlay.play(st, "abbey_of_st_markovia/clovin:start", ["How's your great-uncle", "Goodbye"])
	assert_eq(SideQuestPlay.missing(beats), "")
	assert_true(SideQuestPlay.text(beats).contains("Sundays"))


func test_the_hood_lazar_and_an_empty_hat() -> void:
	var st := _krezk(NO_WREN)
	st.location = "abbey_of_st_markovia"
	st.set_quest_stage("clovins_audience", "refused")
	var beats := SideQuestPlay.play(st, "abbey_of_st_markovia/clovin:start", ["Dmitri won't open the gate"])
	assert_eq(SideQuestPlay.missing(beats), "")
	assert_true(bool(st.get_flag("clovin_hooded", false)))
	assert_eq(st.quest_stage("clovins_audience"), "booked")
	st.location = "krezk"
	st.minute_of_day = 18 * 60
	st.gold = 0
	beats = SideQuestPlay.play(st, "krezk/clovins_audience:show", ["Just introduce him", "Keep going", "Let Clovin answer him"])
	assert_eq(SideQuestPlay.missing(beats), "", "no Wren, no warm-up from her")
	var said := SideQuestPlay.text(beats)
	assert_true(said.contains("flips it back"), "Lazar pulls the hood")
	assert_true(said.contains("goat's tooth"), "a flop, and Pavel fills the hat anyway")
	assert_true(said.contains("Floarea was my sister"))
	assert_eq(roundi(st.gold), 75)
	assert_true(st.party_has_item("ring_of_the_ram"))
	assert_eq(st.quest_stage("clovins_audience"), "done")


func test_the_crowd_is_read_once() -> void:
	var st := _krezk(WITH_WREN)
	st.set_quest_stage("clovins_audience", "booked")
	st.minute_of_day = 18 * 60
	var beats := SideQuestPlay.play(st, "krezk/clovins_audience:show", ["Just introduce him", "Read the crowd first", "Read the crowd first"])
	assert_true(SideQuestPlay.missing(beats).contains("Read the crowd first"), "one look at the crowd")
	assert_true(bool(st.get_flag("clovin_crowd_tried", false)))


func test_dmitri_can_be_talked_round_or_not() -> void:
	var booked := false
	var refused := false
	for seed: int in [1, 2, 3, 5, 8, 13, 21]:
		var st := _krezk(NO_WREN)
		st.location = "krezk_burgomaster_house"
		st.set_quest_stage("clovins_audience", "asked")
		var beats := SideQuestPlay.play(st, "krezk/dmitri:start", ["Clovin Belview wants", "Two doors down", "Goodbye"], seed)
		assert_eq(SideQuestPlay.missing(beats), "")
		booked = booked or st.quest_stage("clovins_audience") == "booked"
		refused = refused or st.quest_stage("clovins_audience") == "refused"
	assert_true(booked, "some roll talks him round")
	assert_true(refused, "some roll doesn't")


func test_clovin_still_asks_once_the_abbot_is_dealt_with() -> void:
	var st := _krezk(NO_WREN)
	st.location = "abbey_of_st_markovia"
	st.set_flag("abbot_fate", "slain")
	st.set_quest_stage("clovins_audience", "rumored")
	var beats := SideQuestPlay.play(st, "abbey_of_st_markovia/clovin:start", ["The Krezk watch says"])
	assert_eq(SideQuestPlay.missing(beats), "")
	assert_eq(st.quest_stage("clovins_audience"), "asked")
	# With nothing to ask him, his lines end as they did.
	var quiet := _krezk(NO_WREN)
	quiet.location = "abbey_of_st_markovia"
	quiet.set_flag("abbot_fate", "slain")
	beats = SideQuestPlay.play(quiet, "abbey_of_st_markovia/clovin:start")
	assert_eq(str(beats[-1]["kind"]), "end")
	assert_false(beats.any(func(b: Dictionary) -> bool: return str(b["kind"]) == "options"), "no menu after his news")
