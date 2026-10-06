extends TestCase
## Changing Weapon Mastery under the 2024 PHB: after a Long Rest a Barbarian or Fighter swaps one kind of weapon, while a
## Paladin, Ranger or Rogue may change all of theirs; a level up only adds kinds (the earlier ones change after a Long
## Rest). Only which masteries are chosen; how they work in a fight is tested elsewhere.


func _swap(ch: Character, key: String, earlier: Array[String], occasion: String) -> Choice:
	var c := ch.choice(key)
	ChoiceOptions.open_swap(c, earlier, occasion)
	ChoiceOptions.populate(c, ch)
	return c


func _store(ch: Character, key: String, picks: Array) -> void:
	(ch.build["choices"] as Dictionary)[key] = picks.duplicate()
	ch.refresh()


## Legal options of `c` that aren't picked (or only wait for the kind they replace to be unpicked).
func _unpicked(c: Choice, n: int) -> Array[String]:
	var out: Array[String] = []
	for o in c.options:
		if (o.legal or o.reason.begins_with("Unpick")) and not o.id in c.picks and out.size() < n:
			out.append(o.id)
	return out


## Replaces the first `n` earlier masteries after a Long Rest; returns the errors.
func _replace(ch: Character, key: String, n: int) -> Array[String]:
	var earlier := ch.picks_for(key)
	var c := _swap(ch, key, earlier, "long_rest")
	var fresh := _unpicked(c, n)
	var picks: Array = earlier.duplicate()
	for i in n:
		picks[i] = fresh[i]
	_store(ch, key, picks)
	c = _swap(ch, key, earlier, "long_rest")
	return ChoiceOptions.errors(c, ch)


func test_a_fighter_swaps_one_weapon_mastery_after_a_long_rest() -> void:
	var ch := TestChars.pregen("ilse_varga", 1)
	var key := "fighter.1.weapon_mastery"
	var c := _swap(ch, key, ch.picks_for(key), "long_rest")
	assert_eq(c.swap_max, 1, "Fighter: one kind per Long Rest")
	assert_true(ChoiceOptions.swap_note(c).begins_with("Replace up to 1 weapon choice"), ChoiceOptions.swap_note(c))
	assert_true(key in PrepareScreen.preparable(_state([ch])).map(func(e: Dictionary) -> String: return (e["choice"] as Choice).key),
		"on the Prepare screen after a Long Rest")
	assert_eq(_replace(ch, key, 1), [] as Array[String], "one kind swapped")
	var errs := _replace(TestChars.pregen("ilse_varga", 1), key, 2)
	assert_true(errs.size() == 1 and errs[0].contains("Only 1 weapon choice can change after a Long Rest"), str(errs))


func test_a_barbarian_swaps_one_weapon_mastery_after_a_long_rest() -> void:
	var ch := TestChars.custom("barbarian", "human", 1)
	var key := "barbarian.1.weapon_mastery"
	assert_eq(_swap(ch, key, ch.picks_for(key), "long_rest").swap_max, 1)
	var errs := _replace(ch, key, 2)
	assert_true(errs.size() == 1 and errs[0].contains("Only 1 weapon choice"), str(errs))


func test_paladins_rangers_and_rogues_change_both_masteries() -> void:
	var chars := {"paladin": TestChars.custom("paladin", "human", 1), "ranger": TestChars.custom("ranger", "human", 1),
		"rogue": TestChars.pregen("tamsin_tealeaf", 1)}
	for cid: String in chars:
		var ch := chars[cid] as Character
		var key := "%s.1.weapon_mastery" % cid
		assert_false(ChoiceOptions.swap_open(_swap(ch, key, ch.picks_for(key), "long_rest")), "%s: no limit" % cid)
		assert_eq(_replace(ch, key, 2), [] as Array[String], "%s changes both" % cid)


func test_a_level_up_only_adds_weapon_masteries() -> void:
	var ch := TestChars.custom("barbarian", "human", 3)
	var key := "barbarian.1.weapon_mastery"
	var earlier := ch.picks_for(key)
	var up := LevelUpController.new(ch)
	assert_true(up.choose_class("barbarian"))
	up.take_fixed_hit_points()
	var wm: Choice = null
	for c in up.level_choices():
		if c.key == key:
			wm = c
	assert_true(wm != null, "Barbarian 4 masters a third kind")
	assert_eq(wm.swap_max, 0)
	assert_true(wm.option(earlier[0]).locked, "earlier kinds change after a Long Rest")
	var fresh := _unpicked(wm, 2)
	var swapped: Array = [fresh[0], earlier[1], fresh[1]]
	var errs := up.choose(key, swapped)
	assert_true(errs.size() == 1 and errs[0].contains("Your earlier weapon choices change after a Long Rest"), str(errs))
	var added: Array = earlier.duplicate()
	added.append(fresh[0])
	assert_eq(up.choose(key, added), [] as Array[String], "a third kind added")


func _state(party: Array[Character]) -> StoryState:
	var st := StoryState.new()
	st.party = party
	return st
