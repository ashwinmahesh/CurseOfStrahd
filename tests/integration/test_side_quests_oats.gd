extends TestCase
## The Oat Thief (docs/story/side_quests.md): Bildrath's missing oats, the back room by day (clues, naming the thief),
## Parriwimple on the north path by night, the path to the charcoal-burners' hollow, Agafia and why only oats, the
## hunters up the trail or a false trail to the river, and her thanks.

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


func test_agafia_and_the_hunters() -> void:
	var st := SideQuestPlay.party(FOUR, 3, "woodcutters_hollow", 23)
	st.set_quest_stage("the_oat_thief", "asked")
	st.set_flag("hollow_known")
	var beats := SideQuestPlay.play(st, "village_of_barovia/the_oat_thief:agafia", ["Why only oats?", "Look at the ground", "Stand in front"], 4)
	assert_eq(SideQuestPlay.missing(beats), "")
	assert_true(SideQuestPlay.text(beats).contains("Oats don't teach anything"))
	assert_eq(SideQuestPlay.combat_of(beats), "oat_hunters")
	var enc := SideQuestPlay.encounter(st, "woodcutters_hollow", "oat_hunters")
	assert_true(SideQuestPlay.has_foe(enc, "A Pack Hunter"))
	if st.get_flag("oat_trail_seen", false):
		assert_eq(str(enc.get("surprise", "")), "enemies", "seen coming up the oats")
	st.set_flag("oat_hunters_beaten")
	st.set_quest_stage("the_oat_thief", "defended")
	beats = SideQuestPlay.play(st, "village_of_barovia/the_oat_thief:agafia")
	assert_true(SideQuestPlay.text(beats).contains("My grandmother's. Feel inside"))
	assert_eq(st.quest_stage("the_oat_thief"), "done")
	assert_true(st.party_has_item("bag_of_tricks_tan"), "her grandmother's bag")
	st.location = "village_of_barovia"
	beats = SideQuestPlay.play(st, "village_of_barovia/bildrath:news", ["Your stock"])
	assert_true(SideQuestPlay.text(beats).contains("I've decided it's charity"))


func test_clues_in_the_back_room_make_a_suspect() -> void:
	var st := SideQuestPlay.party(FOUR, 2, "village_of_barovia", 10)
	st.set_quest_stage("the_oat_thief", "rumored")
	SideQuestPlay.play(st, "village_of_barovia/the_oat_thief:clue_dust")
	assert_true(st.get_flag("oat_clue_dust", false))
	assert_eq(st.quest_stage("the_oat_thief"), "rumored", "one clue isn't enough")
	var beats := SideQuestPlay.play(st, "village_of_barovia/the_oat_thief:clue_print")
	assert_true(SideQuestPlay.text(beats).contains("print of an enormous boot"))
	assert_eq(st.quest_stage("the_oat_thief"), "suspect", "two clues name a very large man")


func test_naming_parriwimple_needs_no_roll() -> void:
	# A failed roll never locks the quest: with no clues and no rolls, naming him gets the same confession.
	var st := SideQuestPlay.party(FOUR, 2, "village_of_barovia", 10)
	st.set_quest_stage("the_oat_thief", "rumored")
	var beats := SideQuestPlay.play(st, "village_of_barovia/the_oat_thief:accuse", ["Parriwimple", "Say nothing"])
	assert_eq(SideQuestPlay.missing(beats), "")
	assert_true(SideQuestPlay.text(beats).contains("It was me took the oats"))
	assert_eq(st.quest_stage("the_oat_thief"), "asked")
	assert_true(st.get_flag("hollow_known", false))
	assert_true(_exit_open(st, "village_of_barovia", "north_path_hollow"), "and the hollow is open by day")


func test_wrong_guesses_cost_ten_minutes_each_and_then_bildrath_names_him() -> void:
	var st := SideQuestPlay.party(FOUR, 2, "village_of_barovia", 10)
	st.set_quest_stage("the_oat_thief", "rumored")
	var before := st.minute_of_day
	var beats := SideQuestPlay.play(st, "village_of_barovia/the_oat_thief:accuse", ["Arik", "village goat"])
	assert_eq(SideQuestPlay.missing(beats), "")
	var said := SideQuestPlay.text(beats)
	assert_true(said.contains("Leaving."), "Arik")
	assert_true(said.contains("eats the corner of Bildrath's receipt book"), "the goat")
	assert_true(said.contains("It is Parriwimple, obviously"), "after two wrong guesses he says it himself")
	assert_eq(st.minute_of_day - before, 20, "ten minutes a wrong guess")
	assert_eq(st.quest_stage("the_oat_thief"), "asked")


func test_a_false_trail_to_the_river_ends_it_without_a_fight() -> void:
	var st := SideQuestPlay.party(FOUR, 3, "woodcutters_hollow", 23)
	st.set_quest_stage("the_oat_thief", "asked")
	st.set_flag("hollow_known")
	var beats := SideQuestPlay.play(st, "village_of_barovia/the_oat_thief:false_ok")
	assert_true(SideQuestPlay.text(beats).contains("passes wide toward the water"))
	assert_eq(SideQuestPlay.combat_of(beats), "", "no fight")
	assert_true(st.get_flag("oat_trail_cleared", false))
	assert_eq(st.quest_stage("the_oat_thief"), "defended")
	beats = SideQuestPlay.play(st, "village_of_barovia/the_oat_thief:agafia")
	assert_true(SideQuestPlay.text(beats).contains("went down by the river before dawn"))
	assert_eq(st.quest_stage("the_oat_thief"), "done")
	assert_true(st.party_has_item("bag_of_tricks_tan"), "the bag all the same")


func test_a_half_laid_trail_is_the_fight() -> void:
	var st := SideQuestPlay.party(FOUR, 3, "woodcutters_hollow", 23)
	st.set_quest_stage("the_oat_thief", "asked")
	var beats := SideQuestPlay.play(st, "village_of_barovia/the_oat_thief:false_fail")
	assert_eq(SideQuestPlay.combat_of(beats), "oat_hunters", "the failure path is the fight, still there to play")
