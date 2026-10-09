extends TestCase
## The Oat Thief (docs/story/side_quests.md): Bildrath's missing oats, Parriwimple on the north path by night, the path
## to the charcoal-burners' hollow, Domnica and why only oats, the hunters up the trail, and her thanks.

const FOUR: Array[String] = ["liriel_dawnsong", "godrick_pendlebrook", "ratatoille", "thistle"]


func _exit_open(st: StoryState, location: String, exit_id: String) -> bool:
	for e: Variant in Compendium.shared().get_entry("locations", location)["exits"]:
		if str((e as Dictionary)["id"]) == exit_id:
			return StoryConditions.check(str((e as Dictionary).get("when", "")), st)
	return false


func test_bildrath_and_the_north_path() -> void:
	var st := SideQuestPlay.party(FOUR, 2, "village_of_barovia", 12)
	var beats := SideQuestPlay.play(st, "village_of_barovia/bildrath:news", ["Your stock"])
	assert_eq(SideQuestPlay.missing(beats), "")
	assert_true(SideQuestPlay.text(beats).contains("Who steals oats"))
	assert_eq(st.quest_stage("the_oat_thief"), "rumored")
	assert_eq(SideQuestPlay.standing(st, "village_of_barovia", "parriwimple"), "", "not by day")
	st.minute_of_day = 23 * 60
	assert_eq(SideQuestPlay.standing(st, "village_of_barovia", "parriwimple"), "village_of_barovia/the_oat_thief:path")
	assert_false(_exit_open(st, "village_of_barovia", "north_path_hollow"))
	beats = SideQuestPlay.play(st, "village_of_barovia/the_oat_thief:path", ["Those are Bildrath's oats"])
	assert_true(SideQuestPlay.text(beats).contains("It's for the lady"))
	assert_eq(st.quest_stage("the_oat_thief"), "asked")
	assert_true(_exit_open(st, "village_of_barovia", "north_path_hollow"))


func test_domnica_and_the_hunters() -> void:
	var st := SideQuestPlay.party(FOUR, 3, "woodcutters_hollow", 23)
	st.set_quest_stage("the_oat_thief", "asked")
	st.set_flag("hollow_known")
	var beats := SideQuestPlay.play(st, "village_of_barovia/the_oat_thief:domnica", ["Why only oats?", "Look at the ground"], 4)
	assert_eq(SideQuestPlay.missing(beats), "")
	assert_true(SideQuestPlay.text(beats).contains("Oats don't teach anything"))
	assert_eq(SideQuestPlay.combat_of(beats), "oat_hunters")
	var enc := SideQuestPlay.encounter(st, "woodcutters_hollow", "oat_hunters")
	assert_true(SideQuestPlay.has_foe(enc, "A Pack Hunter"))
	if st.get_flag("oat_trail_seen", false):
		assert_eq(str(enc.get("surprise", "")), "enemies", "seen coming up the oats")
	st.set_flag("oat_hunters_beaten")
	st.set_quest_stage("the_oat_thief", "defended")
	beats = SideQuestPlay.play(st, "village_of_barovia/the_oat_thief:domnica")
	assert_true(SideQuestPlay.text(beats).contains("My grandmother made this"))
	assert_eq(st.quest_stage("the_oat_thief"), "done")
	assert_true(st.party_has_item("restorative_ointment"))
	st.location = "village_of_barovia"
	beats = SideQuestPlay.play(st, "village_of_barovia/bildrath:news", ["Your stock"])
	assert_true(SideQuestPlay.text(beats).contains("I've decided it's charity"))
