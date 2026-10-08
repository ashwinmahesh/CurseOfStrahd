extends TestCase
## The Count's Huntsman (docs/story/side_quests.md): Old Paraschiva's rumour, whose scent he has (Gavril's, or the
## party's once Strahd has marked them), the quarry stones, the stand at the crossroads with the hounds called by name,
## the saddlebag paid once, and the mark it leaves on Strahd's attention.

const SIX: Array[String] = ["thistle", "godrick_pendlebrook", "liriel_dawnsong", "ratatoille"]


func _camp() -> StoryState:
	return SideQuestPlay.party(SIX, 8, "vallaki_vistani_camp", 12)


func test_gavrils_scent_the_names_and_the_stand() -> void:
	var st := _camp()
	var beats := SideQuestPlay.play(st, "vallaki/camp_folk:cook", ["Heard anything interesting?"])
	assert_eq(SideQuestPlay.missing(beats), "")
	assert_true(SideQuestPlay.text(beats).contains("it blew for Gavril"))
	assert_eq(str(st.get_flag("hunt_quarry", "")), "gavril")
	assert_eq(st.quest_stage("the_counts_huntsman"), "hunted")
	# The crossroads by day: the stones, and nobody on the east road.
	st.location = "svalich_crossroads"
	assert_true(SideQuestPlay.shown(st, "svalich_crossroads", "quarry_stones"))
	assert_eq(SideQuestPlay.standing(st, "svalich_crossroads", "count_huntsman"), "")
	SideQuestPlay.play(st, "svalich_road/the_counts_huntsman:stones")
	assert_true(bool(st.get_flag("hounds_named", false)))
	# Moonrise.
	st.minute_of_day = 23 * 60
	assert_eq(SideQuestPlay.standing(st, "svalich_crossroads", "camp_groom"), "svalich_road/the_counts_huntsman:gavril_waits")
	assert_eq(SideQuestPlay.standing(st, "svalich_crossroads", "count_huntsman"), "svalich_road/the_counts_huntsman:stand")
	beats = SideQuestPlay.play(st, "svalich_road/the_counts_huntsman:stand", ["Who were you", "Call the hounds", "Draw steel"])
	assert_eq(SideQuestPlay.missing(beats), "")
	var said := SideQuestPlay.text(beats)
	assert_true(said.contains("Not you. The horse-seller."))
	assert_true(said.contains("Toader"))
	assert_true(said.contains("Nobody's ever said them"))
	assert_eq(SideQuestPlay.combat_of(beats), "the_hunt")
	var enc := SideQuestPlay.encounter(st, "svalich_crossroads", "the_hunt")
	assert_true(SideQuestPlay.has_foe(enc, "count_huntsman"))
	assert_eq((enc["monsters"] as Array).filter(func(m: Variant) -> bool: return str((m as Dictionary).get("name", "")) == "Hound of the Hunt").size(), 2, "two hounds still come when the rest are called")
	# After.
	st.set_flag("huntsman_slain")
	st.set_quest_stage("the_counts_huntsman", "stood")
	assert_eq(SideQuestPlay.standing(st, "svalich_crossroads", "count_huntsman"), "")
	assert_true(SideQuestPlay.shown(st, "svalich_crossroads", "huntsman_saddlebag"))
	st.gold = 0
	beats = SideQuestPlay.play(st, "svalich_road/the_counts_huntsman:saddlebag")
	assert_true(SideQuestPlay.text(beats).contains("I actually stood"))
	assert_eq(st.quest_stage("the_counts_huntsman"), "ended")
	assert_eq(roundi(st.gold), 300)
	assert_true(st.party_has_item("ring_of_animal_influence"))
	SideQuestPlay.play(st, "svalich_road/the_counts_huntsman:saddlebag")
	assert_eq(roundi(st.gold), 300, "paid once")
	st.location = "vallaki_vistani_camp"
	beats = SideQuestPlay.play(st, "vallaki/camp_folk:cook", ["Heard anything interesting?"])
	assert_true(SideQuestPlay.text(beats).contains("No horn in the woods"))


func test_once_strahd_has_marked_them_the_horn_is_for_the_party() -> void:
	var st := _camp()
	for f: String in ["rahadin_defeated", "gulthias_tree_burned", "doru_destroyed", "carriage_beaten", "greytooth_beaten"]:
		st.set_flag(f)
	assert_true(StoryConditions.check("attention >= marked", st), "seven points: marked")
	var beats := SideQuestPlay.play(st, "vallaki/camp_folk:cook", ["Heard anything interesting?"])
	assert_true(SideQuestPlay.text(beats).contains("Three notes is for strangers"))
	assert_eq(str(st.get_flag("hunt_quarry", "")), "party")
	st.location = "svalich_crossroads"
	st.minute_of_day = 23 * 60
	assert_eq(SideQuestPlay.standing(st, "svalich_crossroads", "camp_groom"), "", "Gavril isn't the quarry")
	beats = SideQuestPlay.play(st, "svalich_road/the_counts_huntsman:stand", ["Draw steel"])
	assert_false(SideQuestPlay.text(beats).contains("horse-seller"))
	assert_eq(SideQuestPlay.combat_of(beats), "the_hunt")
	var enc := SideQuestPlay.encounter(st, "svalich_crossroads", "the_hunt")
	assert_eq((enc["monsters"] as Array).filter(func(m: Variant) -> bool: return str((m as Dictionary).get("name", "")) == "Hound of the Hunt").size(), 4, "the whole pack at level 8")


func test_beating_him_is_a_mark_against_the_party() -> void:
	var st := _camp()
	assert_false(StoryConditions.check("attention >= 1", st))
	st.set_flag("huntsman_slain")
	assert_true(StoryConditions.check("attention >= 1", st))
