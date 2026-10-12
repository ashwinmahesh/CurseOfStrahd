extends TestCase
## Speak with Dead around Barovia and Vallaki (docs/story/talking_creatures.md, batch 3): Kolyan at his coffin or his
## grave, Nicu on the gallows or in his roadside grave, Brother Kesten behind Old Bonegrinder, Grigor's brother Mircea
## in the werewolves' midden, and Tudor the shepherd at the Lake Zarovich landing. Liriel prepares the spell, and the
## conversation casts it with a 3rd-level slot.


func _party(location: String, hour: int = 12) -> StoryState:
	var st := SideQuestPlay.party(["liriel_dawnsong", "thistle"], 7, location, hour)
	((st.party[0].spellcasting[0] as Dictionary)["prepared"] as Array).append("speak_with_dead")
	return st


func _found(st: StoryState, location: String, prop: String) -> bool:
	return bool((st.loc_state(location)["found"] as Dictionary).get(prop, false))


func _menus(beats: Array[Dictionary]) -> bool:
	return beats.any(func(b: Dictionary) -> bool: return str(b["kind"]) == "options")


func _offered(beats: Array[Dictionary], text: String) -> bool:
	return beats.any(func(b: Dictionary) -> bool: return str(b["kind"]) == "options" and (b["options"] as Array).any(
		func(o: Variant) -> bool: return str((o as Dictionary)["text"]).contains(text)))


func test_kolyan_tells_where_he_found_ireena_and_where_the_brooch_is() -> void:
	var st := _party("village_of_barovia")
	st.set_flag("burgomaster_buried")
	st.set_flag("izek_story_heard")
	var liriel := st.party[0]
	var slots := liriel.slots_left(3)
	var beats := SideQuestPlay.play(st, "village_of_barovia/kolyan:grave", ["Cast Speak with Dead"])
	assert_eq(SideQuestPlay.missing(beats), "")
	assert_eq(liriel.slots_left(3), slots - 1, "a 3rd-level slot")
	assert_true(bool(st.get_flag("kolyan_spoke", false)))
	assert_true(bool(st.get_flag("izek_sister_truth", false)), "Izek's story heard, and now the other half of it")
	assert_eq(st.quest_stage("izek_obsession"), "truth_guessed")
	assert_true(_found(st, "burgomaster_mansion", "study_panel"), "his wife's brooch behind the study desk")
	beats = SideQuestPlay.play(st, "village_of_barovia/kolyan:grave")
	assert_false(_offered(beats, "Ask the burgomaster") or _offered(beats, "Cast Speak with Dead"), "a corpse answers once")


func test_kolyan_in_his_coffin_first_and_izeks_story_finishes_it() -> void:
	var st := _party("burgomaster_mansion")
	var beats := SideQuestPlay.play(st, "village_of_barovia/kolyan:coffin", ["Cast Speak with Dead"])
	assert_eq(SideQuestPlay.missing(beats), "")
	assert_true(bool(st.get_flag("ireena_finding_known", false)))
	assert_false(bool(st.get_flag("izek_sister_truth", false)), "nobody's told Izek's half yet")
	st.location = "vallaki"
	beats = SideQuestPlay.play(st, "vallaki/izek:arm")
	assert_true(bool(st.get_flag("izek_sister_truth", false)), SideQuestPlay.text(beats))
	assert_eq(st.quest_stage("izek_obsession"), "truth_guessed")


func test_without_the_spell_or_once_raised_kolyan_doesnt_answer() -> void:
	var st := SideQuestPlay.party(["godrick_pendlebrook", "ratatoille"], 7, "village_of_barovia", 12)
	st.set_flag("burgomaster_buried")
	assert_false(_menus(SideQuestPlay.play(st, "village_of_barovia/kolyan:grave")), "only the grave")
	st = _party("village_of_barovia")
	st.set_flag("burgomaster_buried")
	st.set_flag("kolyan_raised")
	var beats := SideQuestPlay.play(st, "village_of_barovia/kolyan:grave")
	assert_false(SideQuestPlay.text(beats).contains("Speak with Dead"), "he's alive, and answers for himself")


func test_nicu_names_his_hangmen_and_sends_his_sister_word() -> void:
	var st := _party("svalich_crossroads")
	var beats := SideQuestPlay.play(st, "svalich_road/crossroads:gallows", ["Cast Speak with Dead"])
	assert_eq(SideQuestPlay.missing(beats), "")
	assert_true(bool(st.get_flag("nicu_spoke", false)))
	assert_true(_found(st, "svalich_crossroads", "field_wall_cache"), "the farmer's gloves behind the field wall")
	st.location = "tser_pool"
	beats = SideQuestPlay.play(st, "svalich_road/luminita:start", ["We found a Vistana", "Nicu had a message"])
	assert_eq(SideQuestPlay.missing(beats), "")
	assert_true(bool(st.get_flag("nicu_message_given", false)))
	assert_true(SideQuestPlay.text(beats).contains("still telling jokes"))


func test_nicu_answers_from_his_grave_but_not_once_he_has_walked() -> void:
	var st := _party("svalich_crossroads")
	st.set_flag("nicu_cut_down")
	var beats := SideQuestPlay.play(st, "svalich_road/crossroads:gallows", ["Cast Speak with Dead over the grave"])
	assert_eq(SideQuestPlay.missing(beats), "")
	assert_true(bool(st.get_flag("nicu_spoke", false)))
	st = _party("svalich_crossroads")
	st.set_flag("crossroads_dead_cleared")
	st.set_flag("nicu_cut_down")
	beats = SideQuestPlay.play(st, "svalich_road/crossroads:gallows")
	assert_false(_menus(beats), "he died Undead: nothing for the spell to wake")


func test_brother_kesten_gives_the_three_words_that_send_offalia_off() -> void:
	var st := _party("old_bonegrinder_hill")
	assert_false(SideQuestPlay.shown(st, "old_bonegrinder_hill", "kesten_bones"), "not before the heap is searched")
	st.set_flag("bone_heap_searched")
	assert_true(SideQuestPlay.shown(st, "old_bonegrinder_hill", "kesten_bones"))
	var beats := SideQuestPlay.play(st, "old_bonegrinder/kesten:bones", ["Cast Speak with Dead"])
	assert_eq(SideQuestPlay.missing(beats), "")
	assert_true(bool(st.get_flag("kesten_spoke", false)))
	st.location = "old_bonegrinder"
	beats = SideQuestPlay.play(st, "old_bonegrinder/offalia:start", ["Mother's calling, dearie"])
	assert_eq(SideQuestPlay.missing(beats), "")
	assert_true(bool(st.get_flag("offalia_lured", false)), "no roll to fail")
	assert_eq(st.quest_stage("children_of_the_mill"), "bakery_cleared")


func test_mircea_in_the_midden_knows_where_his_boots_came_off() -> void:
	var st := _party("werewolf_den")
	var beats := SideQuestPlay.play(st, "werewolf_den/mircea:midden", ["Cast Speak with Dead"])
	assert_eq(SideQuestPlay.missing(beats), "")
	assert_true(bool(st.get_flag("mircea_spoke", false)))
	assert_true(_found(st, "werewolf_den", "mud_boots"), "the Boots of Speed in the mud at the foot of the slope")


func test_tudor_saw_szoldar_watch_from_the_rise() -> void:
	var st := _party("lake_zarovich")
	var beats := SideQuestPlay.play(st, "vallaki/hunters_at_the_inn:shepherd", ["Cast Speak with Dead"])
	assert_eq(SideQuestPlay.missing(beats), "")
	assert_true(bool(st.get_flag("tudor_spoke", false)))
	st.location = "vallaki_blue_water_inn"
	st.set_quest_stage("hunters_at_the_inn", "asked")
	beats = SideQuestPlay.play(st, "vallaki/hunters_at_the_inn:szoldar", ["A shepherd died on that shore", "Then don't come"])
	assert_eq(SideQuestPlay.missing(beats), "")
	assert_true(SideQuestPlay.text(beats).contains("talking to Tudor"))
	assert_true(bool(st.get_flag("szoldar_stays", false)), "Szoldar stays off the rise")
	assert_eq(st.quest_stage("hunters_at_the_inn"), "the_trap")
