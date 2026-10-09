extends TestCase
## One Lantern Too Many (docs/story/side_quests.md): the town guard's count, Old Sabin's extra lantern and his grandson
## gone to the lake, the girl of light at the end of the fishers' jetty, her lantern brought up or a fight, and the
## dream-catcher she made the week before.

const FOUR: Array[String] = ["liriel_dawnsong", "godrick_pendlebrook", "ratatoille", "thistle"]


func test_the_count_and_the_lantern_maker() -> void:
	var st := SideQuestPlay.party(FOUR, 5, "vallaki", 10)
	var beats := SideQuestPlay.play(st, "vallaki/one_lantern_too_many:guard_news")
	assert_true(SideQuestPlay.text(beats).contains("Thirty-two lanterns"))
	assert_eq(st.quest_stage("one_lantern_too_many"), "rumored")
	assert_eq(SideQuestPlay.standing(st, "vallaki", "vallaki_sabin"), "vallaki/one_lantern_too_many:sabin")
	beats = SideQuestPlay.play(st, "vallaki/one_lantern_too_many:sabin", ["Watch his hands"], 5)
	var said := SideQuestPlay.text(beats)
	assert_true(said.contains("my hands make thirty-two"))
	assert_true(said.contains("fishers' jetty"))
	assert_eq(st.quest_stage("one_lantern_too_many"), "asked")


func test_the_girl_at_the_end_of_the_jetty() -> void:
	var st := SideQuestPlay.party(FOUR, 5, "lake_zarovich", 22)
	st.set_quest_stage("one_lantern_too_many", "asked")
	assert_eq(SideQuestPlay.standing(st, "lake_zarovich", "lantern_girl"), "vallaki/one_lantern_too_many:girl")
	st.minute_of_day = 12 * 60
	assert_eq(SideQuestPlay.standing(st, "lake_zarovich", "lantern_girl"), "", "only after dark")
	st.minute_of_day = 22 * 60
	var beats := SideQuestPlay.play(st, "vallaki/one_lantern_too_many:girl", ["Let him go"])
	assert_true(SideQuestPlay.text(beats).contains("Nobody came back"))
	assert_eq(SideQuestPlay.combat_of(beats), "lantern_girl")
	# Her father remembers, and somebody turns back.
	var kind := SideQuestPlay.party(FOUR, 5, "lake_zarovich", 22)
	kind.set_quest_stage("one_lantern_too_many", "asked")
	kind.set_flag("sabin_remembered")
	kind.set_flag("lantern_girl_met")
	beats = SideQuestPlay.play(kind, "vallaki/one_lantern_too_many:girl", ["Your father remembers", "Then we will"], 2)
	assert_eq(SideQuestPlay.missing(beats), "")
	assert_true(SideQuestPlay.text(beats).contains("He made me one every week"))
	assert_true(kind.get_flag("lantern_girl_rested", false) or SideQuestPlay.combat_of(beats) == "lantern_girl", "the dive, made or missed")


func test_sandu_home_and_the_dream_catcher() -> void:
	var st := SideQuestPlay.party(FOUR, 5, "lake_zarovich", 22)
	st.set_quest_stage("one_lantern_too_many", "fought")
	st.set_flag("lantern_girl_slain")
	assert_eq(SideQuestPlay.standing(st, "lake_zarovich", "vallaki_sandu"), "vallaki/one_lantern_too_many:sandu")
	var beats := SideQuestPlay.play(st, "vallaki/one_lantern_too_many:sandu")
	assert_true(SideQuestPlay.text(beats).contains("Can we go home?"))
	assert_eq(st.quest_stage("one_lantern_too_many"), "home")
	st.location = "vallaki"
	st.minute_of_day = 10 * 60
	assert_eq(SideQuestPlay.standing(st, "vallaki", "vallaki_sandu"), "vallaki/one_lantern_too_many:sandu")
	st.gold = 0
	beats = SideQuestPlay.play(st, "vallaki/one_lantern_too_many:sabin")
	assert_true(SideQuestPlay.text(beats).contains("For catching the bad dreams"))
	assert_eq(st.quest_stage("one_lantern_too_many"), "done")
	assert_true(st.party_has_item("dream_weaver"))
	assert_eq(roundi(st.gold), 40)
	beats = SideQuestPlay.play(st, "vallaki/one_lantern_too_many:sabin")
	assert_true(SideQuestPlay.text(beats).contains("Thirty-one this week"))
	assert_eq(roundi(st.gold), 40, "paid once")
