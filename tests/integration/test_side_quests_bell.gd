extends TestCase
## The Bell Under the Lake (docs/story/side_quests.md): Old Nistor's story once Bluto's sacks have stopped, the bell
## after moonrise, the drowned coming for Bluto (defend him or stand aside) or for Nistor, and the bell silenced for
## the staff and the chapel silver, paid once.

const PARTY: Array[String] = ["godrick_pendlebrook", "liriel_dawnsong", "thistle", "ratatoille"]


func test_nistor_waits_for_the_arabelle_business() -> void:
	var st := SideQuestPlay.party(PARTY, 8, "lake_zarovich", 11)
	var beats := SideQuestPlay.play(st, "lake_zarovich/old_fisher:start")
	assert_false(SideQuestPlay.text(beats).contains("Pescari"), "no story while Bluto still feeds the lake")
	assert_eq(st.quest_stage("bell_under_the_lake"), "")


func test_defending_bluto_and_ringing_the_bell_for_the_dead() -> void:
	var st := SideQuestPlay.party(PARTY, 8, "lake_zarovich", 11)
	st.set_flag("arabelle_rescued")
	st.set_flag("bluto_fate", "saved")
	var beats := SideQuestPlay.play(st, "lake_zarovich/old_fisher:start", ["Why did the fish go deep", "We'll be here when it comes"])
	assert_eq(SideQuestPlay.missing(beats), "")
	assert_eq(st.quest_stage("bell_under_the_lake"), "asked")
	assert_true(SideQuestPlay.shown(st, "lake_zarovich", "bell_water"))
	beats = SideQuestPlay.play(st, "lake_zarovich/bell_under_the_lake:water")
	assert_eq(SideQuestPlay.combat_of(beats), "", "nothing by day")
	st.minute_of_day = 23 * 60
	beats = SideQuestPlay.play(st, "lake_zarovich/bell_under_the_lake:water", ["Stand in front of him"])
	assert_eq(SideQuestPlay.missing(beats), "")
	assert_true(SideQuestPlay.text(beats).contains("I paid you"), "Bluto knows what's come for him")
	assert_eq(SideQuestPlay.combat_of(beats), "drowned_landing")
	var enc := SideQuestPlay.encounter(st, "lake_zarovich", "drowned_landing")
	assert_true(SideQuestPlay.has_foe(enc, "The Bellringer of Pescari"))
	assert_true(SideQuestPlay.xp(enc) >= 5000, "Moderate for level 8: %d" % SideQuestPlay.xp(enc))
	st.set_flag("drowned_beaten")
	st.gold = 0
	var rung := false
	for seed: int in [1, 2, 3, 5, 8]:
		SideQuestPlay.play(st, "lake_zarovich/bell_under_the_lake:water", ["Ring it once"], seed)
		if bool(st.get_flag("bell_silenced", false)):
			rung = true
			break
	assert_true(rung, "a Religion roll rings it for the dead")
	assert_eq(st.quest_stage("bell_under_the_lake"), "silenced")
	assert_eq(roundi(st.gold), 200)
	assert_true(st.party_has_item("staff_of_healing"))
	SideQuestPlay.play(st, "lake_zarovich/bell_under_the_lake:water")
	assert_eq(roundi(st.gold), 200, "paid once")
	beats = SideQuestPlay.play(st, "lake_zarovich/old_fisher:start")
	assert_true(SideQuestPlay.text(beats).contains("pike"))
	assert_true(SideQuestPlay.text(beats).contains("child in a sack"))


func test_standing_aside_gives_them_bluto_and_they_rise_anyway() -> void:
	var st := SideQuestPlay.party(PARTY, 7, "lake_zarovich", 23)
	st.set_flag("arabelle_lost")
	st.set_flag("bluto_fate", "left")
	st.set_quest_stage("bell_under_the_lake", "asked")
	var beats := SideQuestPlay.play(st, "lake_zarovich/bell_under_the_lake:water", ["Stand aside"])
	assert_eq(SideQuestPlay.combat_of(beats), "drowned_landing", "they were never coming for just one")
	assert_eq(str(st.get_flag("bluto_fate", "")), "drowned")
	assert_eq(SideQuestPlay.standing(st, "lake_zarovich", "bluto"), "", "Bluto is gone")


func test_without_bluto_they_come_for_nistor() -> void:
	var st := SideQuestPlay.party(PARTY, 8, "lake_zarovich", 23)
	st.set_flag("arabelle_rescued")
	st.set_flag("bluto_fate", "killed")
	st.set_quest_stage("bell_under_the_lake", "asked")
	var beats := SideQuestPlay.play(st, "lake_zarovich/bell_under_the_lake:water", ["Stand in front of him"])
	assert_true(SideQuestPlay.text(beats).contains("one of us"), "Old Nistor sits down on his step")
	assert_eq(SideQuestPlay.combat_of(beats), "drowned_landing")
