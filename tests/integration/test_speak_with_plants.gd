extends TestCase
## Speak with Plants (docs/story/talking_creatures.md): plants tell what passed them in the last day, and each one
## here knows where something is hidden. Thistle, a ranger, prepares the spell at level 9; the conversation casts it
## with a 3rd-level slot.


func _party(location: String, hour: int = 12) -> StoryState:
	var st := SideQuestPlay.party(["thistle", "liriel_dawnsong"], 9, location, hour)
	((st.party[0].spellcasting[0] as Dictionary)["prepared"] as Array).append("speak_with_plants")
	return st


func _found(st: StoryState, location: String, prop: String) -> bool:
	return bool((st.loc_state(location)["found"] as Dictionary).get(prop, false))


func _offered(beats: Array[Dictionary], text: String) -> bool:
	return beats.any(func(b: Dictionary) -> bool: return str(b["kind"]) == "options" and (b["options"] as Array).any(
		func(o: Variant) -> bool: return str((o as Dictionary)["text"]).contains(text)))


func _speak(st: StoryState, ref: String) -> Array[Dictionary]:
	var slots := st.party[0].slots_left(3)
	var beats := SideQuestPlay.play(st, ref, ["Cast Speak with Plants"])
	assert_eq(SideQuestPlay.missing(beats), "")
	assert_eq(st.party[0].slots_left(3), slots - 1, "a 3rd-level slot: not a Ritual")
	return beats


func test_the_wolfsbane_saw_zuleika_hide_a_flask() -> void:
	var st := _party("werewolf_den")
	_speak(st, "werewolf_den/wolfsbane:patch")
	assert_true(bool(st.get_flag("wolfsbane_spoke", false)))
	assert_true(_found(st, "werewolf_den_caves", "herb_elixir"), "the Elixir of Health in the drying herbs")


func test_the_vines_saw_the_druids_come_from_yester_hill() -> void:
	var st := _party("wizard_of_wines")
	_speak(st, "wizard_of_wines/vines:row")
	assert_true(bool(st.get_flag("yester_hill_known", false)))
	assert_true(_found(st, "wizard_of_wines", "vine_sickle"))


func test_once_the_winery_is_won_back_the_vines_saw_only_the_family() -> void:
	var st := _party("wizard_of_wines")
	st.set_flag("winery_reclaimed")
	var beats := _speak(st, "wizard_of_wines/vines:row")
	assert_true(SideQuestPlay.text(beats).contains("Let us sleep"))
	assert_false(_found(st, "wizard_of_wines", "vine_sickle"), "a sickle dropped long ago is past a day's memory")


func test_the_hags_garden_saw_bella_fly_home_and_not_once_she_is_gone() -> void:
	var st := _party("old_bonegrinder_hill")
	_speak(st, "old_bonegrinder/garden:garden")
	assert_true(_found(st, "old_bonegrinder_loft", "rafters_broom"), "the broom in the loft's rafters")
	st = _party("old_bonegrinder_hill")
	st.set_flag("bella_fled")
	var beats := SideQuestPlay.play(st, "old_bonegrinder/garden:garden")
	assert_true(_offered(beats, "Leave the garden alone"), "the spell is known")
	assert_false(_offered(beats, "Cast Speak with Plants"), "Bella gone: nothing flew over last night")
