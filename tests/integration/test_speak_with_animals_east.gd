extends TestCase
## Speak with Animals east of the crossroads (docs/story/talking_creatures.md, batch 2): Vallaki's dogs and horses, the
## Wizard of Wines' ravens, Old Bonegrinder's oak, Krezk's goats and the castle's roost, and Stella Wachter, who isn't
## a cat. Thistle prepares the spell; the conversation casts it as a Ritual.

const PARTY: Array[String] = ["thistle", "godrick_pendlebrook", "liriel_dawnsong", "ratatoille"]


func _party(location: String, level: int, hour: int = 12) -> StoryState:
	return SideQuestPlay.party(PARTY, level, location, hour)


func _found(st: StoryState, location: String, prop: String) -> bool:
	return bool((st.loc_state(location)["found"] as Dictionary).get(prop, false))


func test_the_vallaki_dog_saw_the_gravedigger_and_knows_the_ring() -> void:
	var st := _party("vallaki", 5)
	var beats := SideQuestPlay.play(st, "vallaki/townsfolk:dog", ["Cast Speak with Animals"])
	assert_eq(SideQuestPlay.missing(beats), "")
	assert_true(bool(st.get_flag("vallaki_dog_told", false)))
	assert_eq(st.quest_stage("bones_of_st_andral"), "rumored", "the saint's bones, before Father Lucian")
	assert_true(_found(st, "vallaki", "stocks_mud"), "the ring by the stocks")
	st.set_flag("bones_theft_known")
	st.set_quest_stage("bones_of_st_andral", "asked")
	beats = SideQuestPlay.play(st, "vallaki/milivoj:start", ["The saint's bones", "A dog saw you"])
	assert_eq(SideQuestPlay.missing(beats), "")
	assert_true(bool(st.get_flag("milivoj_confessed", false)), "what the dog saw is enough")
	assert_eq(st.quest_stage("bones_of_st_andral"), "milivoj_confessed")


func test_the_camp_dog_points_at_luvash_and_then_at_the_lake() -> void:
	var st := _party("vallaki_vistani_camp", 5)
	var beats := SideQuestPlay.play(st, "vallaki/camp_folk:dog", ["Cast Speak with Animals"])
	assert_eq(SideQuestPlay.missing(beats), "")
	assert_eq(st.quest_stage("missing_arabelle"), "rumored")
	st.set_quest_stage("missing_arabelle", "asked")
	beats = SideQuestPlay.play(st, "vallaki/camp_folk:dog", ["Ask the dog"])
	assert_eq(SideQuestPlay.missing(beats), "", "the spell still runs")
	assert_eq(st.quest_stage("missing_arabelle"), "clue", "the fisherman with the sack")
	assert_eq(SideQuestPlay.standing(st, "vallaki_vistani_camp", "bluto"), "vallaki/vistani_camp:bluto", "Bluto's on the shore")


func test_arrigals_horse_knows_the_castle_road() -> void:
	var st := _party("vallaki_vistani_camp", 5, 22)
	var beats := SideQuestPlay.play(st, "vallaki/vistani_camp:black_horse", ["Cast Speak with Animals"])
	assert_eq(SideQuestPlay.missing(beats), "")
	assert_true(bool(st.get_flag("arrigal_suspected", false)), "the accusation opens up")
	assert_true(_found(st, "vallaki_vistani_camp", "arrigal_wagon_drawer"), "the knife that stinks of snake")


func test_the_inn_horse_knows_whats_in_rictavios_wagon() -> void:
	var st := _party("vallaki_blue_water_inn", 5, 20)
	var beats := SideQuestPlay.play(st, "vallaki/rictavio:stable_horse", ["Cast Speak with Animals"])
	assert_eq(SideQuestPlay.missing(beats), "")
	assert_true(bool(st.get_flag("rictavio_suspected", false)), "an old hunter in a showman's coat")


func test_speak_with_animals_finds_no_cat_in_stellas_room() -> void:
	var st := _party("vallaki_wachter_house", 5, 15)
	var beats := SideQuestPlay.play(st, "vallaki/cat_in_the_window:stella", ["Cast Speak with Animals"])
	assert_eq(SideQuestPlay.missing(beats), "")
	assert_true(bool(st.get_flag("stella_bound_known", false)))
	assert_eq(st.quest_stage("cat_in_the_window"), "bound")


func test_the_winery_ravens_report_like_scouts() -> void:
	var st := _party("wizard_of_wines", 6)
	var beats := SideQuestPlay.play(st, "wizard_of_wines/hands:raven", ["Cast Speak with Animals"])
	assert_eq(SideQuestPlay.missing(beats), "")
	assert_true(bool(st.get_flag("winery_stone_hiding_told", false)), "the third hoop")
	assert_true(bool(st.get_flag("yester_hill_known", false)), "the hill to the west")
	assert_eq(st.quest_stage("the_third_stone"), "told", "the stone in Berez")
	assert_true(_found(st, "wizard_of_wines", "roost_hoard"), "the ring that falls slowly")


func test_the_bonegrinder_ravens_tell_of_the_children() -> void:
	var st := _party("old_bonegrinder_hill", 6)
	var beats := SideQuestPlay.play(st, "old_bonegrinder/ilinca:oak", ["Cast Speak with Animals"])
	assert_eq(SideQuestPlay.missing(beats), "")
	assert_eq(st.quest_stage("children_of_the_mill"), "heard")
	assert_true(_found(st, "old_bonegrinder_hill", "oak_raven_hoard"), "the silver raven")


func test_krezks_goats_know_who_sleeps_in_their_pens() -> void:
	var st := _party("krezk", 7)
	st.set_flag("den_children_freed")
	var beats := SideQuestPlay.play(st, "krezk/townsfolk:goat", ["Cast Speak with Animals"])
	assert_eq(SideQuestPlay.missing(beats), "")
	assert_eq(st.quest_stage("one_horned_billy"), "rumored", "the billy talks in his sleep")
	assert_eq(st.quest_stage("the_packs_runt"), "rumored", "the boy who smells of wolf")
	assert_true(_found(st, "krezk", "track_cairn_ring"), "warm in the mouth")


func test_the_castle_roost_talks_even_to_those_who_hurt_a_raven() -> void:
	var st := _party("castle_ravenloft_spires_roost", 10, 22)
	st.set_flag("raven_harmed")
	var beats := SideQuestPlay.play(st, "castle_ravenloft/spires_roost:ravens", ["Cast Speak with Animals"])
	assert_eq(SideQuestPlay.missing(beats), "")
	assert_eq(SideQuestPlay.combat_of(beats), "", "no swarm")
	assert_true(bool(st.get_flag("roost_ravens_calm", false)))
	assert_true(_found(st, "castle_ravenloft_spires_roost", "nest_ring"))
	assert_true(SideQuestPlay.text(beats).contains("toy-man"), "Pidlwick II's key, not found yet")
