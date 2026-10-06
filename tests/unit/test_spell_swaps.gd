extends TestCase
## Changing spells under the 2024 PHB: after a Long Rest a Cleric, Druid or Wizard may change any number of prepared
## spells, a Paladin or Ranger one, and a Wizard one cantrip; gaining a level lets that class swap one spell (Bard,
## Sorcerer, Warlock) and one cantrip (every caster's but a Wizard's), while a Cleric or Wizard only adds new spells
## then. ChoiceOptions.open_swap sets the limit; populate() locks and blocks options to match; errors() reports a
## list that changed too much.


## The choice `key` of `ch` as it stands, with a swap chance open from `earlier` for `occasion`.
func _swap(ch: Character, key: String, earlier: Array[String], occasion: String) -> Choice:
	var c := ch.choice(key)
	ChoiceOptions.open_swap(c, earlier, occasion)
	ChoiceOptions.populate(c, ch)
	return c


func _store(ch: Character, key: String, picks: Array) -> void:
	(ch.build["choices"] as Dictionary)[key] = picks.duplicate()
	ch.refresh()


func _same(a: Array, b: Array) -> bool:
	if a.size() != b.size():
		return false
	for i in a.size():
		if str(a[i]) != str(b[i]):
			return false
	return true


## A legal option of `c` that isn't picked (or one only waiting for the spell it replaces to be unpicked).
func _unpicked(c: Choice, skip: Array = []) -> String:
	for o in c.options:
		if (o.legal or o.reason.begins_with("Unpick")) and not o.id in c.picks and not o.id in skip:
			return o.id
	return ""


func test_a_paladin_replaces_one_prepared_spell_after_a_long_rest() -> void:
	var ch := TestChars.custom("paladin", "human", 3)
	var earlier := ch.picks_for("paladin.prepared")
	assert_true(earlier.size() >= 3, "Paladin 3 prepares several spells: %s" % [earlier])
	var c := _swap(ch, "paladin.prepared", earlier, "long_rest")
	assert_eq(c.swap_max, 1, "one spell per Long Rest")
	assert_true(ChoiceOptions.swap_note(c).begins_with("Replace up to 1 spell"), ChoiceOptions.swap_note(c))
	# The list is full of earlier picks: a new spell waits until the one it replaces is unpicked.
	var other := ""
	for o in c.options:
		if not o.id in c.picks and o.reason.begins_with("Unpick the spell"):
			other = o.id
	assert_true(other != "", "unpicked spells wait for an unpick")
	assert_true(_same(ChoiceOptions.toggled(c, other, true), c.picks), "picking past the count never drops an earlier spell")
	# Unpick one, and the rest are locked.
	_store(ch, "paladin.prepared", ChoiceOptions.toggled(c, earlier[0], false))
	c = _swap(ch, "paladin.prepared", earlier, "long_rest")
	assert_eq(c.picks.size(), earlier.size() - 1)
	assert_true(c.option(earlier[1]).locked, "the swap is used: %s stays" % earlier[1])
	assert_true(c.option(earlier[1]).reason.contains("Only 1 spell can change after a Long Rest"), c.option(earlier[1]).reason)
	assert_true(_same(ChoiceOptions.toggled(c, earlier[1], false), c.picks), "a locked spell can't be unpicked")
	# Pick the replacement.
	var replacement := _unpicked(c, [earlier[0]])
	assert_true(replacement != "", "a spell to swap in")
	_store(ch, "paladin.prepared", ChoiceOptions.toggled(c, replacement, true))
	c = _swap(ch, "paladin.prepared", earlier, "long_rest")
	assert_true(replacement in c.picks)
	assert_eq(ChoiceOptions.errors(c, ch), [] as Array[String], "one spell replaced is fine")
	# Changing the replacement again keeps the earlier spells: picking past the count drops the new one.
	var second := _unpicked(c, [earlier[0], replacement])
	var again := ChoiceOptions.toggled(c, second, true)
	assert_true(second in again and not replacement in again, "the new pick goes, not an earlier one: %s" % [again])
	# A second replacement is an error.
	var two: Array = earlier.duplicate()
	two[0] = replacement
	two[1] = second
	_store(ch, "paladin.prepared", two)
	c = _swap(ch, "paladin.prepared", earlier, "long_rest")
	var errs := ChoiceOptions.errors(c, ch)
	assert_eq(errs.size(), 1, str(errs))
	assert_true(errs[0].contains("Only 1 spell can change after a Long Rest"), str(errs))


func test_a_ranger_also_replaces_one_spell() -> void:
	var ch := TestChars.custom("ranger", "human", 3)
	var c := _swap(ch, "ranger.prepared", ch.picks_for("ranger.prepared"), "long_rest")
	assert_eq(c.swap_max, 1)


func test_a_cleric_changes_any_number_after_a_long_rest() -> void:
	var ch := TestChars.pregen("hedda_ironvow", 3)
	var earlier := ch.picks_for("cleric.prepared")
	var c := _swap(ch, "cleric.prepared", earlier, "long_rest")
	assert_false(ChoiceOptions.swap_open(c), "no limit for a Cleric")
	assert_eq(ChoiceOptions.swap_note(c), "")
	var a := _unpicked(c)
	var b := _unpicked(c, [a])
	var picks: Array = earlier.duplicate()
	picks[0] = a
	picks[1] = b
	_store(ch, "cleric.prepared", picks)
	c = _swap(ch, "cleric.prepared", earlier, "long_rest")
	assert_eq(ChoiceOptions.errors(c, ch), [] as Array[String], "two spells changed")
	# Without a swap chance (character creation) picking past the count still drops the oldest pick.
	var free := ch.choice("cleric.prepared")
	ChoiceOptions.populate(free, ch)
	var more := ChoiceOptions.toggled(free, _unpicked(free), true)
	assert_eq(more.size(), free.count)
	assert_false(free.picks[0] in more, "the oldest pick went")


func test_a_wizard_swaps_one_cantrip_after_a_long_rest() -> void:
	var ch := TestChars.pregen("silvain_aster", 3)
	var cantrips := ch.choice("wizard.cantrips")
	assert_eq(cantrips.replaceable, "long_rest")
	var c := _swap(ch, "wizard.cantrips", ch.picks_for("wizard.cantrips"), "long_rest")
	assert_eq(c.swap_max, 1, "one cantrip")
	var prepared := _swap(ch, "wizard.prepared", ch.picks_for("wizard.prepared"), "long_rest")
	assert_false(ChoiceOptions.swap_open(prepared), "any number of prepared spells, from the spellbook")
	for o in prepared.options:
		assert_true(o.id in ch.picks_for("wizard.spellbook") or o.id in ch.spellcasting_entry("wizard").get("spellbook", []),
			"%s is in the spellbook" % o.id)


func test_a_bard_swaps_one_cantrip_and_one_spell_each_level() -> void:
	var ch := TestChars.custom("bard", "human", 1)
	var up := LevelUpController.new(ch)
	assert_true(up.choose_class("bard"))
	up.take_fixed_hit_points()
	var keys: Array = up.level_choices().map(func(c: Choice) -> String: return c.key)
	assert_true("bard.cantrips" in keys, "Bard 2 keeps two cantrips but may swap one: %s" % [keys])
	assert_true("bard.prepared" in keys)
	var cantrips := ch.picks_for("bard.cantrips")
	var lc := {}
	for c in up.level_choices():
		lc[c.key] = c
	var cc := lc["bard.cantrips"] as Choice
	assert_eq(cc.swap_max, 1)
	var new1 := _unpicked(cc)
	var new2 := _unpicked(cc, [new1])
	assert_eq(up.choose("bard.cantrips", [new1, cantrips[1]]), [] as Array[String], "one cantrip swapped")
	var errs := up.choose("bard.cantrips", [new1, new2])
	assert_true(errs.size() == 1 and errs[0].contains("Only 1 cantrip can change at a level up"), str(errs))
	up.choose("bard.cantrips", [new1, cantrips[1]])
	# Spells: one swapped plus the new one the level brings.
	var spells := ch.picks_for("bard.prepared")
	var pc := lc["bard.prepared"] as Choice
	var s1 := _unpicked(pc)
	var s2 := _unpicked(pc, [s1])
	var s3 := _unpicked(pc, [s1, s2])
	var one: Array = spells.duplicate()
	one[0] = s1
	one.append(s2)
	assert_eq(up.choose("bard.prepared", one), [] as Array[String], "one swapped, one added")
	var two: Array = one.duplicate()
	two[1] = s3
	errs = up.choose("bard.prepared", two)
	assert_true(errs.size() == 1 and errs[0].contains("Only 1 spell can change at a level up"), str(errs))
	up.choose("bard.prepared", one)
	TestChars.auto_pick(up.pending_choices, up.choose)
	assert_true(up.confirm(), str(up.errors()))
	assert_true(new1 in ch.picks_for("bard.cantrips") and s1 in ch.picks_for("bard.prepared"))


func test_a_cleric_only_adds_spells_at_a_level_up() -> void:
	var ch := TestChars.pregen("hedda_ironvow", 1)
	var up := LevelUpController.new(ch)
	assert_true(up.choose_class("cleric"))
	up.take_fixed_hit_points()
	var earlier := ch.picks_for("cleric.prepared")
	var pc: Choice = null
	for c in up.level_choices():
		if c.key == "cleric.prepared":
			pc = c
	assert_true(pc != null, "Cleric 2 prepares one more spell")
	assert_eq(pc.swap_max, 0)
	assert_true(pc.option(earlier[0]).locked, "earlier spells change after a Long Rest")
	assert_true(ChoiceOptions.swap_note(pc).contains("change after a Long Rest"), ChoiceOptions.swap_note(pc))
	var swapped: Array = earlier.duplicate()
	swapped[0] = _unpicked(pc)
	swapped.append(_unpicked(pc, [swapped[0]]))
	var errs := up.choose("cleric.prepared", swapped)
	assert_true(errs.size() == 1 and errs[0].contains("Your earlier spells change after a Long Rest"), str(errs))
	var added: Array = earlier.duplicate()
	added.append(_unpicked(pc))
	assert_eq(up.choose("cleric.prepared", added), [] as Array[String])
	# Its cantrips swap at a level up (one).
	var keys: Array = up.level_choices().map(func(c: Choice) -> String: return c.key)
	assert_true("cleric.cantrips" in keys, str(keys))


func test_a_wizard_level_up_leaves_cantrips_for_the_long_rest() -> void:
	var ch := TestChars.pregen("silvain_aster", 1)
	var up := LevelUpController.new(ch)
	assert_true(up.choose_class("wizard"))
	var keys: Array = up.level_choices().map(func(c: Choice) -> String: return c.key)
	assert_false("wizard.cantrips" in keys, "a Wizard swaps a cantrip after a Long Rest, not at level 2: %s" % [keys])
