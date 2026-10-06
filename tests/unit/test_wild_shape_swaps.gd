extends TestCase
## Wild Shape's known forms under the 2024 PHB: after a Long Rest a Druid replaces one known form with another eligible
## one; a level up adds forms and leaves the known ones alone.


func test_a_druid_swaps_one_known_form_after_a_long_rest() -> void:
	var ch := TestChars.custom("druid", "human", 2)
	var key := "druid.2.wild_shape"
	var earlier := ch.picks_for(key)
	assert_true(earlier.size() >= 2, "Druid 2 knows several forms: %s" % [earlier])
	var st := StoryState.new()
	st.party = [ch] as Array[Character]
	var keys: Array = PrepareScreen.preparable(st).map(func(e: Dictionary) -> String: return (e["choice"] as Choice).key)
	assert_true(key in keys, "on the Prepare screen after a Long Rest: %s" % [keys])
	var c := ch.choice(key)
	ChoiceOptions.open_swap(c, earlier, "long_rest")
	ChoiceOptions.populate(c, ch)
	assert_eq(c.swap_max, 1, "one form per Long Rest")
	assert_true(ChoiceOptions.swap_note(c).begins_with("Replace up to 1 Beast form"), ChoiceOptions.swap_note(c))
	var fresh: Array[String] = []
	for o in c.options:
		if (o.legal or o.reason.begins_with("Unpick")) and not o.id in earlier and fresh.size() < 2:
			fresh.append(o.id)
	var two: Array = earlier.duplicate()
	two[0] = fresh[0]
	two[1] = fresh[1]
	(ch.build["choices"] as Dictionary)[key] = two
	ch.refresh()
	c = ch.choice(key)
	ChoiceOptions.open_swap(c, earlier, "long_rest")
	ChoiceOptions.populate(c, ch)
	var errs := ChoiceOptions.errors(c, ch)
	assert_true(errs.size() == 1 and errs[0].contains("Only 1 Beast form can change after a Long Rest"), str(errs))


func test_a_druid_level_up_only_adds_forms() -> void:
	var ch := TestChars.custom("druid", "human", 3)
	var key := "druid.2.wild_shape"
	var earlier := ch.picks_for(key)
	var up := LevelUpController.new(ch)
	assert_true(up.choose_class("druid"))
	up.take_fixed_hit_points()
	var c: Choice = null
	for lc in up.level_choices():
		if lc.key == key:
			c = lc
	assert_true(c != null and c.count > earlier.size(), "Druid 4 learns more forms")
	assert_eq(c.swap_max, 0)
	assert_true(c.option(earlier[0]).locked, "known forms change after a Long Rest")
	var swapped: Array = earlier.duplicate()
	for o in c.options:
		if o.legal and not o.id in earlier:
			swapped[0] = o.id
			break
	var errs := up.choose(key, swapped)
	assert_true(errs.any(func(e: String) -> bool: return e.contains("Your earlier Beast forms change after a Long Rest")), str(errs))
