extends TestCase
## The Tinker's Wagon (docs/story/side_quests.md): Zora's count, Iosif at the crossroads by day, what Insight and
## Perception see, the chain, the Wagon, and the belly paid once.

const SIX: Array[String] = ["thistle", "godrick_pendlebrook", "liriel_dawnsong", "ratatoille"]


func test_zoras_count_the_chain_and_the_belly() -> void:
	var st := SideQuestPlay.party(SIX, 5, "tser_pool", 12)
	var beats := SideQuestPlay.play(st, "svalich_road/tser_camp:zora", ["Heard anything interesting?"])
	assert_eq(SideQuestPlay.missing(beats), "")
	assert_true(SideQuestPlay.text(beats).contains("Wagons don't get fatter"))
	assert_eq(st.quest_stage("the_tinkers_wagon"), "rumored")
	st.location = "svalich_crossroads"
	assert_eq(SideQuestPlay.standing(st, "svalich_crossroads", "tinker_iosif"), "svalich_road/the_tinkers_wagon:iosif")
	st.minute_of_day = 22 * 60
	assert_eq(SideQuestPlay.standing(st, "svalich_crossroads", "tinker_iosif"), "", "not by night")
	st.minute_of_day = 12 * 60
	beats = SideQuestPlay.play(st, "svalich_road/the_tinkers_wagon:iosif", ["What are you selling", "Why don't you ever get down", "Goodbye"])
	assert_eq(SideQuestPlay.missing(beats), "")
	assert_eq(st.quest_stage("the_tinkers_wagon"), "met")
	beats = SideQuestPlay.play(st, "svalich_road/the_tinkers_wagon:iosif", ["Go for the chain"])
	assert_true(SideQuestPlay.missing(beats).contains("Go for the chain"), "not until something's been seen")
	# Somebody looks properly, whatever the dice.
	for seed: int in [1, 2, 3]:
		SideQuestPlay.play(st, "svalich_road/the_tinkers_wagon:iosif", ["Look at the wagon", "Goodbye"], seed)
		if bool(st.get_flag("wagon_seen", false)):
			break
	assert_true(bool(st.get_flag("wagon_seen", false)))
	beats = SideQuestPlay.play(st, "svalich_road/the_tinkers_wagon:iosif", ["Go for the chain"])
	assert_eq(SideQuestPlay.missing(beats), "")
	assert_true(SideQuestPlay.text(beats).contains("the wagon stands up off its wheels"))
	assert_eq(SideQuestPlay.combat_of(beats), "tinkers_wagon")
	var enc := SideQuestPlay.encounter(st, "svalich_crossroads", "tinkers_wagon")
	assert_true(SideQuestPlay.has_foe(enc, "tinkers_wagon"))
	assert_true(SideQuestPlay.xp(enc) >= 3000, "level 5: %d" % SideQuestPlay.xp(enc))
	st.set_flag("wagon_slain")
	assert_false(SideQuestPlay.shown(st, "svalich_crossroads", "tinker_wagon"))
	st.gold = 0
	beats = SideQuestPlay.play(st, "svalich_road/the_tinkers_wagon:iosif")
	assert_true(SideQuestPlay.text(beats).contains("Seven years"))
	assert_eq(st.quest_stage("the_tinkers_wagon"), "done")
	assert_eq(roundi(st.gold), 300)
	assert_true(st.party_has_item("gem_of_seeing"))
	assert_eq(SideQuestPlay.standing(st, "svalich_crossroads", "tinker_iosif"), "")
	assert_eq(SideQuestPlay.standing(st, "tser_pool", "tinker_iosif"), "svalich_road/the_tinkers_wagon:at_camp")
	beats = SideQuestPlay.play(st, "svalich_road/tser_camp:zora", ["Heard anything interesting?"])
	assert_true(SideQuestPlay.text(beats).contains("count back in") or SideQuestPlay.text(beats).contains("stopped counting"))
	assert_eq(roundi(st.gold), 300, "paid once")
