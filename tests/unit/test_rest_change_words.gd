extends TestCase
## What a rest lets the party change, said in words (owner report 2026-10-18: "How to change Fiendish Resilience?"): the
## rest screen's button, the camp's, the Prepare screen's title and intro and the line after the rest all name it, and a
## Short Rest's changes stay on offer when the screen is closed and opened again, until the next rest, an hour or the
## party moving on (RestRules.short_change). The rule itself is unchanged.


func _state(chars: Array) -> StoryState:
	var st := StoryState.new()
	for ch: Character in chars:
		st.party.append(ch)
	return st


func test_a_fiend_warlock_alone_has_just_fiendish_resilience_to_change() -> void:
	var st := _state([TestChars.pregen("kip_smudgewick", 10)])
	for rest: String in ["short_rest", "long_rest"]:
		assert_eq(PrepareScreen.change_names(st, rest), ["Fiendish Resilience"] as Array[String], rest)
	assert_eq(PrepareScreen.change_words(PrepareScreen.change_names(st, "short_rest")), "Fiendish Resilience")
	assert_eq(PrepareScreen.title_for(st, "short_rest"), "Change Fiendish Resilience")
	assert_eq(PrepareScreen.available_line(st, "short_rest"), "You can change Fiendish Resilience now: the lit button below.")


func test_with_a_cleric_the_long_rest_names_both_and_the_short_one_only_the_damage_type() -> void:
	var st := _state([TestChars.pregen("kip_smudgewick", 10), TestChars.pregen("hedda_ironvow", 3)])
	assert_eq(PrepareScreen.change_names(st, "long_rest"), ["Prepared Spells", "Fiendish Resilience"] as Array[String])
	assert_eq(PrepareScreen.change_names(st, "short_rest"), ["Fiendish Resilience"] as Array[String])
	assert_eq(PrepareScreen.change_words(PrepareScreen.change_names(st, "long_rest")), "prepared spells and Fiendish Resilience", "a button")
	assert_eq(PrepareScreen.title_for(st, "long_rest"), "Change Prepared Spells and Fiendish Resilience")
	assert_eq(PrepareScreen.available_line(st, "long_rest"), "You can change prepared spells and Fiendish Resilience now: the lit button below.")


func test_a_party_with_only_spells_to_change_reads_as_it_always_did() -> void:
	var st := _state([TestChars.pregen("hedda_ironvow", 3)])
	assert_eq(PrepareScreen.change_names(st, "long_rest"), ["Prepared Spells"] as Array[String])
	assert_eq(PrepareScreen.title_for(st, "long_rest"), "Prepare Spells")
	assert_eq(PrepareScreen.available_line(st, "long_rest"), "", "the lit button already says it")
	assert_eq(PrepareScreen.title_for(st, PrepareScreen.ANYTIME), "Prepare Spells", "and the any-time screen is spells only")


func test_the_intro_explains_the_damage_type_and_keeps_the_spells_text() -> void:
	var st := _state([TestChars.pregen("kip_smudgewick", 10), TestChars.pregen("hedda_ironvow", 3)])
	var short := PrepareScreen.intro_for(st, "short_rest")
	assert_true(short.contains("Fiendish Resilience (Kip)") and short.contains("damage type"), short)
	assert_false(short.contains("prepared") or short.contains("Clerics"), "a Short Rest changes no spells")
	var long := PrepareScreen.intro_for(st, "long_rest")
	assert_true(long.begins_with("After a Long Rest, choose which spells each caster has ready"), "the spells text first")
	assert_true(long.contains("Fiendish Resilience (Kip): choose a different damage type to resist"), long)
	var cleric := PrepareScreen.intro_for(_state([TestChars.pregen("hedda_ironvow", 3)]), "long_rest")
	assert_false(cleric.contains("damage type"), "nothing added where there is nothing to name")


func test_a_short_rests_changes_stay_until_the_next_rest_an_hour_or_a_move() -> void:
	var st := _state([TestChars.pregen("kip_smudgewick", 10)])
	st.location = "village_of_barovia"
	assert_true(RestRules.short_change(st).is_empty(), "no Short Rest yet")
	RestRules.note_short_rest(st, {"a/b": ["acid"]})
	assert_eq((RestRules.short_change(st)["picks"] as Dictionary)["a/b"], ["acid"], "what a swap limit counts from")
	st.advance_minutes(RestRules.CHANGE_MINUTES)
	assert_false(RestRules.short_change(st).is_empty(), "still on offer within the hour")
	st.advance_minutes(1)
	assert_true(RestRules.short_change(st).is_empty(), "an hour on, it has passed")
	RestRules.note_short_rest(st)
	st.location = "vallaki"
	assert_true(RestRules.short_change(st).is_empty(), "the party moved on")
	st.location = "village_of_barovia"
	assert_false(RestRules.short_change(st).is_empty(), "back where it rested, within the hour")
	LongRest.finish(st, DiceRoller.new(3))
	assert_true(RestRules.short_change(st).is_empty(), "a Long Rest offers them itself")
	# It is part of the saved game: bookkeeping in the flags.
	RestRules.note_short_rest(st)
	var back := JSON.parse_string(JSON.stringify(st.flags)) as Dictionary
	assert_true(back.has(RestRules.SHORT_CHANGE))
