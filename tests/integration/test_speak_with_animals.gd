extends TestCase
## Talking to animals and the dead while exploring (Ashwin, 2026-10-11: more to speak with): a conversation casts the
## spell itself (`cast`: Speak with Animals as a Ritual's ten minutes, Speak with Dead with a slot), or uses a casting
## still running from the character sheet, and the creature tells what it knows, often where something is hidden
## (`reveal`). Thistle prepares Speak with Animals from level 3; nobody prebuilt prepares Speak with Dead.

const PARTY: Array[String] = ["thistle", "godrick_pendlebrook", "liriel_dawnsong", "ratatoille"]


func _party(location: String, hour: int = 12, level: int = 3) -> StoryState:
	return SideQuestPlay.party(PARTY, level, location, hour)


func _found(st: StoryState, location: String, prop: String) -> bool:
	return bool((st.loc_state(location)["found"] as Dictionary).get(prop, false))


func _offered(beats: Array[Dictionary], text: String) -> bool:
	return beats.any(func(b: Dictionary) -> bool: return str(b["kind"]) == "options" and (b["options"] as Array).any(
		func(o: Variant) -> bool: return str((o as Dictionary)["text"]).contains(text)))


func test_a_conversation_casts_the_ritual_and_a_running_spell_needs_no_new_one() -> void:
	var st := _party("village_of_barovia")
	var thistle := st.party[0]
	var slots := thistle.slots_left(1)
	var before := st.total_minutes()
	var beats := SideQuestPlay.play(st, "village_of_barovia/townsfolk:goat", ["Cast Speak with Animals"])
	assert_eq(SideQuestPlay.missing(beats), "")
	assert_true(SideQuestPlay.text(beats).contains("Thistle casts Speak with Animals as a Ritual"), SideQuestPlay.text(beats))
	assert_eq(thistle.slots_left(1), slots, "a Ritual: no slot")
	assert_true(st.total_minutes() - before >= 10, "a Ritual's ten minutes")
	assert_true(StoryConditions.check("spell:speak_with_animals", st), "the spell runs on")
	assert_true(_found(st, "village_of_barovia", "barn_beams_stash"), "the goat has tasted the barn's stash")
	assert_true(SideQuestPlay.text(beats).contains("Found: a stash under the fallen beams"))
	beats = SideQuestPlay.play(st, "village_of_barovia/townsfolk:goat", ["Ask the goat"])
	assert_eq(SideQuestPlay.missing(beats), "", "while it runs, just ask")
	assert_false(_offered(beats, "Cast Speak with Animals"))
	assert_false(SideQuestPlay.text(beats).contains("Found:"), "a find shows once")


func test_without_the_spell_an_animal_is_only_an_animal() -> void:
	var st := SideQuestPlay.party(["godrick_pendlebrook", "ratatoille"], 3, "village_of_barovia", 12)
	var beats := SideQuestPlay.play(st, "village_of_barovia/townsfolk:goat")
	assert_false(beats.any(func(b: Dictionary) -> bool: return str(b["kind"]) == "options"), "no menu at all")
	assert_false(_found(st, "village_of_barovia", "barn_beams_stash"))


func test_reveal_finds_its_place_wherever_the_party_is() -> void:
	var st := _party("vallaki")
	DialogueFile.register(DialogueFile.parse("~ tip\nreveal carcass_pack\nreveal not_a_find\n-> END\n", "test/tip"))
	var beats := SideQuestPlay.play(st, "test/tip:tip")
	assert_true(_found(st, "into_the_mists_road", "carcass_pack"), "the road's find, told about in Vallaki")
	assert_eq(SideQuestPlay.text(beats).count("Found:"), 1, "nothing for a find that isn't one")


func test_speak_with_dead_is_cast_at_the_corpse_with_a_slot() -> void:
	var st := SideQuestPlay.party(["liriel_dawnsong", "thistle"], 7, "yester_hill", 12)
	var liriel := st.party[0]
	((liriel.spellcasting[0] as Dictionary)["prepared"] as Array).append("speak_with_dead")
	for level in range(3, 10):
		while liriel.slots_left(level) > 0:
			liriel.expend_slot(level)
	var beats := SideQuestPlay.play(st, "yester_hill/summit:elvir", ["Cast Speak with Dead"])
	assert_eq(SideQuestPlay.missing(beats), "")
	assert_true(SideQuestPlay.text(beats).contains("No spell slots left"), SideQuestPlay.text(beats))
	assert_false(bool(st.get_flag("elvir_spoke", false)), "no slot, no answer")
	liriel.finish_long_rest()
	var slots := liriel.slots_left(3)
	beats = SideQuestPlay.play(st, "yester_hill/summit:elvir", ["Cast Speak with Dead"])
	assert_eq(SideQuestPlay.missing(beats), "")
	assert_true(bool(st.get_flag("elvir_spoke", false)))
	assert_eq(liriel.slots_left(3), slots - 1, "a 3rd-level slot")
	assert_true(SideQuestPlay.text(beats).contains("Tell Father it was mine"))


func test_the_mists_wolves_say_who_sent_them_and_let_the_party_by() -> void:
	var st := _party("into_the_mists_road")
	var beats := SideQuestPlay.play(st, "into_the_mists/wolves:start", ["Cast Speak with Animals"])
	assert_eq(SideQuestPlay.missing(beats), "")
	assert_eq(SideQuestPlay.combat_of(beats), "", "no fight")
	assert_true(bool(st.get_flag("mists_wolves_cowed", false)))
	assert_true(SideQuestPlay.text(beats).contains("old one in the white"), "the man in the fog, not met yet")


func test_the_crow_sees_through_the_children_and_knows_the_pack() -> void:
	var st := _party("into_the_mists_road")
	var beats := SideQuestPlay.play(st, "into_the_mists/arrival:crow", ["Cast Speak with Animals"])
	assert_eq(SideQuestPlay.missing(beats), "")
	assert_true(_found(st, "into_the_mists_road", "carcass_pack"), "the boots under the carcass")
	beats = SideQuestPlay.play(st, "death_house/rose_thorn:start", ["The crow down the road"])
	assert_eq(SideQuestPlay.missing(beats), "")
	assert_true(bool(st.get_flag("death_house_saw_through_lure", false)), "seen through")


func test_lupu_says_who_is_in_the_wall() -> void:
	var st := _party("village_of_barovia", 21)
	var beats := SideQuestPlay.play(st, "village_of_barovia/the_burgomasters_hound:lupu", ["Cast Speak with Animals"])
	assert_eq(SideQuestPlay.missing(beats), "")
	assert_true(bool(st.get_flag("sergiu_known", false)) and bool(st.get_flag("lupu_friend", false)))
	assert_eq(st.quest_stage("the_burgomasters_hound"), "asked")
	st.location = "burgomaster_mansion"
	beats = SideQuestPlay.play(st, "village_of_barovia/the_burgomasters_hound:bricks")
	assert_false(_offered(beats, "Look for anything pushed in among the bricks"), "no need for the note")


func test_snowdrop_and_the_flock_tell_where_she_came_from() -> void:
	var st := _party("barovia_high_pasture", 12)
	SideQuestPlay.play(st, "village_of_barovia/the_goatherds_count:goat", ["Cast Speak with Animals"])
	assert_eq(st.quest_stage("the_goatherds_count"), "asked", "the flock knows there's one too many")
	st.minute_of_day = 19 * 60
	var beats := SideQuestPlay.play(st, "village_of_barovia/the_goatherds_count:erno", ["old nanny goat where"])
	assert_eq(SideQuestPlay.missing(beats), "")
	assert_true(SideQuestPlay.text(beats).contains("man in the grey boots"))
	assert_true(SideQuestPlay.text(beats).contains("On a stone by the road"), "Ilarion's still out there")
	assert_eq(SideQuestPlay.combat_of(beats), "pasture_wolves", "and the white sends for her")


func test_the_tser_pool_dog_knows_who_went_out_and_what_is_hidden() -> void:
	var st := _party("tser_pool", 12, 4)
	var beats := SideQuestPlay.play(st, "svalich_road/tser_camp:dog", ["Cast Speak with Animals"])
	assert_eq(SideQuestPlay.missing(beats), "")
	assert_eq(st.quest_stage("the_hanged_vistana"), "asked")
	assert_true(_found(st, "tser_pool", "tser_stump_flask"))


func test_bujor_knows_whose_iron_holds_the_cub() -> void:
	var st := _party("tser_woods_den", 12, 4)
	st.set_quest_stage("the_dancing_bear", "asked")
	var beats := SideQuestPlay.play(st, "svalich_road/the_dancing_bear:den", ["Cast Speak with Animals"])
	assert_eq(SideQuestPlay.missing(beats), "")
	assert_true(bool(st.get_flag("bear_trap_marked", false)), "the skinning man's iron")
	assert_false(_offered(beats, "Look at the trap"), "nothing left to read off the trap")
	assert_eq(SideQuestPlay.combat_of(beats), "den_blights", "and the trees come for the crying")


func test_steaua_is_talked_down_and_knows_the_milestone() -> void:
	var st := _party("svalich_crossroads", 22, 4)
	st.set_quest_stage("the_grey_mare", "asked")
	var beats := SideQuestPlay.play(st, "svalich_road/grey_mare:mare", ["Cast Speak with Animals"])
	assert_eq(SideQuestPlay.missing(beats), "")
	assert_true(bool(st.get_flag("mare_calmed", false)))
	assert_false(bool(st.get_flag("mare_lost", false)))
	assert_true(_found(st, "svalich_crossroads", "milestone_hollow"))
	assert_true(_offered(beats, "Pour a flask of holy water") or _offered(beats, "Press a holy symbol"), "on to the brand")


func test_the_crossroads_raven_carries_the_keepers_word() -> void:
	var st := _party("svalich_crossroads", 12, 4)
	var beats := SideQuestPlay.play(st, "svalich_road/crossroads:raven", ["Cast Speak with Animals"])
	assert_eq(SideQuestPlay.missing(beats), "")
	assert_eq(st.quest_stage("wizard_of_wines"), "rumored")
	assert_true(_found(st, "svalich_crossroads", "newer_mound"), "who buries boots?")


func test_billy_speaks_after_a_casting() -> void:
	var st := SideQuestPlay.party(PARTY, 7, "krezk", 11)
	var beats := SideQuestPlay.play(st, "krezk/townsfolk:billy", ["Cast Speak with Animals"])
	assert_eq(SideQuestPlay.missing(beats), "")
	assert_true(bool(st.get_flag("billy_eyes_seen", false)))
	assert_eq(st.quest_stage("one_horned_billy"), "the_ring")
