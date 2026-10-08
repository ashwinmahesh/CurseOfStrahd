extends TestCase
## Called by Name (docs/story/side_quests.md): Zora's rumour, Big Tobar's ask, the voices at Tser Falls calling each
## companion by someone they lost, the will-o'-wisps (surprising the party if someone is lured), Nelu brought up from
## his ledge, and Tobar's thanks paid once.

const SIX: Array[String] = ["godrick_pendlebrook", "wren_featherfoot", "thistle", "kip_smudgewick"]


func test_the_rumour_the_voices_and_the_way_home() -> void:
	var st := SideQuestPlay.party(SIX, 4, "tser_pool", 18)
	var beats := SideQuestPlay.play(st, "svalich_road/tser_camp:zora", ["Heard anything interesting?"])
	assert_eq(SideQuestPlay.missing(beats), "")
	assert_eq(st.quest_stage("called_by_name"), "rumored")
	beats = SideQuestPlay.play(st, "svalich_road/tser_camp:tobar", ["your son went after a voice", "We'll go to the falls"])
	assert_eq(SideQuestPlay.missing(beats), "")
	assert_eq(st.quest_stage("called_by_name"), "asked")
	st.location = "tser_falls"
	assert_true(SideQuestPlay.shown(st, "tser_falls", "gorge_voices"))
	beats = SideQuestPlay.play(st, "svalich_road/called_by_name:falls")
	assert_true(SideQuestPlay.text(beats).contains("nothing calling"), "by day the gorge is quiet")
	assert_eq(SideQuestPlay.combat_of(beats), "")
	st.minute_of_day = 22 * 60
	beats = SideQuestPlay.play(st, "svalich_road/called_by_name:falls")
	assert_eq(st.quest_stage("called_by_name"), "voices")
	var said := SideQuestPlay.text(beats)
	for who: String in ["Sir Pellam", "Sorrel", "grandda", "Pip"]:
		assert_true(said.contains(who), "each companion hears someone they lost: %s" % who)
	assert_false(said.contains("Maman"), "only companions in the party hear theirs")
	assert_eq(SideQuestPlay.combat_of(beats), "falls_wisps")
	var enc := SideQuestPlay.encounter(st, "tser_falls", "falls_wisps")
	assert_eq((enc["monsters"] as Array).size(), 4, "four lights at level 4")
	assert_true(SideQuestPlay.xp(enc) >= 1800, "High for level 4")
	assert_eq(str(enc["surprise"]), "party" if bool(st.get_flag("wisps_lured", false)) else "", "a lured party starts surprised")
	st.set_flag("wisps_beaten")
	beats = SideQuestPlay.play(st, "svalich_road/called_by_name:falls", ["Rope off a pine"], 5)
	if not bool(st.get_flag("nelu_saved", false)):
		beats = SideQuestPlay.play(st, "svalich_road/called_by_name:falls", ["Rope off a pine"], 11)
	if not bool(st.get_flag("nelu_saved", false)):
		beats = SideQuestPlay.play(st, "svalich_road/called_by_name:falls", ["Rope off a pine"], 23)
	assert_true(bool(st.get_flag("nelu_saved", false)), "someone climbs down for him")
	assert_eq(st.quest_stage("called_by_name"), "nelu_found")
	assert_false(SideQuestPlay.shown(st, "tser_falls", "gorge_voices"))
	st.gold = 0
	beats = SideQuestPlay.play(st, "svalich_road/tser_camp:tobar")
	assert_eq(st.quest_stage("called_by_name"), "home")
	assert_eq(roundi(st.gold), 100)
	assert_true(st.party_has_item("efficient_quiver"))
	assert_eq(SideQuestPlay.standing(st, "tser_pool", "tser_nelu"), "svalich_road/tser_camp:nelu")
	SideQuestPlay.play(st, "svalich_road/tser_camp:tobar")
	assert_eq(roundi(st.gold), 100, "Tobar pays once")


func test_misty_step_brings_him_up_without_a_climb() -> void:
	var st := SideQuestPlay.party(["ratatoille", "liriel_dawnsong", "kip_smudgewick", "godrick_pendlebrook"], 4, "tser_falls", 23)
	st.set_quest_stage("called_by_name", "voices")
	st.set_flag("wisps_beaten")
	var stepper := StoryConditions.check("knows:misty_step", st)
	if stepper:
		SideQuestPlay.play(st, "svalich_road/called_by_name:falls", ["Step down to his ledge"])
		assert_true(bool(st.get_flag("nelu_saved", false)))
	else:
		assert_true(true, "nobody here knows Misty Step at level 4; the climb covers it")
