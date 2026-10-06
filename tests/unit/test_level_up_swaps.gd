extends TestCase
## The other 2024 level-up swaps: gaining a level in the class lets a Warlock replace one Eldritch Invocation (never one
## another invocation needs), a Battle Master one Maneuver, a Sorcerer one Metamagic option, a Paladin or Ranger one
## Blessed or Druidic Warrior cantrip, and a Fighter its Fighting Style (a Paladin's or Ranger's feat stays), offered
## every level even when the count stays. LevelUpController opens the chance;
## ChoiceOptions limits it.


## The level-up controller for `ch` gaining a level in `cid`, and its choices by key.
func _level(ch: Character, cid: String) -> Array:
	var up := LevelUpController.new(ch)
	assert_true(up.choose_class(cid), "%s can level" % cid)
	up.take_fixed_hit_points()
	var by_key := {}
	for c in up.level_choices():
		by_key[c.key] = c
	return [up, by_key]


## Unpicked options of `c` (legal, or only waiting for the pick they replace to be unpicked).
func _unpicked(c: Choice, n: int) -> Array[String]:
	var out: Array[String] = []
	for o in c.options:
		if (o.legal or o.reason.begins_with("Unpick")) and not o.id in c.picks and out.size() < n:
			out.append(o.id)
	return out


## Swapping one earlier pick of `key` is fine and two is an error naming `noun`.
func _one_not_two(up: LevelUpController, c: Choice, noun: String) -> void:
	var earlier: Array = c.picks.duplicate()
	assert_true(earlier.size() >= 2, "%s: at least two earlier picks" % c.key)
	assert_eq(c.swap_max, 1, "%s: one per level" % c.key)
	var fresh := _unpicked(c, 2)
	var one: Array = earlier.duplicate()
	one[0] = fresh[0]
	assert_eq(up.choose(c.key, one), [] as Array[String], "%s: one swapped" % c.key)
	var two: Array = one.duplicate()
	two[1] = fresh[1]
	var errs := up.choose(c.key, two)
	assert_true(errs.size() == 1 and errs[0].contains("Only 1 %s can change at a level up" % noun), str(errs))
	up.choose(c.key, one)
	TestChars.auto_pick(up.pending_choices, up.choose)
	assert_true(up.confirm(), str(up.errors()))


func test_a_warlock_swaps_one_invocation_at_a_level_without_new_ones() -> void:
	var ch := TestChars.custom("warlock", "human", 2)
	var lv := _level(ch, "warlock")
	var c := (lv[1] as Dictionary).get("warlock.1.eldritch_invocations") as Choice
	assert_true(c != null, "Warlock 3 keeps three invocations but may swap one")
	assert_true(ChoiceOptions.swap_note(c).begins_with("Replace up to 1 invocation"), ChoiceOptions.swap_note(c))
	_one_not_two(lv[0] as LevelUpController, c, "invocation")


func test_an_invocation_another_needs_stays() -> void:
	var ch := TestChars.custom("warlock", "human", 5)
	var key := "warlock.1.eldritch_invocations"
	var picks: Array = ch.picks_for(key).filter(func(p: String) -> bool: return p != "pact_of_the_blade" and p != "thirsting_blade")
	picks = picks.slice(0, ch.choice(key).count - 2)
	picks.append_array(["pact_of_the_blade", "thirsting_blade"])
	(ch.build["choices"] as Dictionary)[key] = picks
	ch.refresh()
	var c := ((_level(ch, "warlock")[1]) as Dictionary).get(key) as Choice
	assert_true(c != null and "thirsting_blade" in c.picks, "Thirsting Blade is on the list: %s" % [c.picks if c != null else []])
	assert_true(c.option("pact_of_the_blade").locked, "Pact of the Blade can't go while Thirsting Blade needs it")
	assert_true(c.option("pact_of_the_blade").reason.contains("Thirsting Blade needs it"), c.option("pact_of_the_blade").reason)
	assert_false(c.option("thirsting_blade").locked, "Thirsting Blade itself may be swapped")


func test_a_battle_master_swaps_one_maneuver() -> void:
	var ch := TestChars.custom("fighter", "human", 3, {"fighter_subclass": ["battle_master"]})
	var lv := _level(ch, "fighter")
	var c := (lv[1] as Dictionary).get("battle_master.3.combat_superiority") as Choice
	assert_true(c != null, "Fighter 4 keeps three maneuvers but may swap one")
	_one_not_two(lv[0] as LevelUpController, c, "maneuver")


func test_a_sorcerer_swaps_one_metamagic_option() -> void:
	var ch := TestChars.custom("sorcerer", "human", 2)
	var lv := _level(ch, "sorcerer")
	var c := (lv[1] as Dictionary).get("sorcerer.2.metamagic") as Choice
	assert_true(c != null, "Sorcerer 3 keeps two Metamagic options but may swap one")
	_one_not_two(lv[0] as LevelUpController, c, "Metamagic option")


func test_a_fighter_switches_fighting_style_by_picking_the_new_one() -> void:
	var ch := TestChars.custom("fighter", "human", 1)
	var key := "fighter.1.fighting_style"
	var before := ch.picks_for(key)
	var lv := _level(ch, "fighter")
	var up := lv[0] as LevelUpController
	var c := (lv[1] as Dictionary).get(key) as Choice
	assert_true(c != null, "Fighter 2 may change its Fighting Style")
	assert_eq(ChoiceOptions.swap_note(c), "You can switch to another Fighting Style.")
	var other := _unpicked(c, 1)
	assert_eq(other.size(), 1, "another Fighting Style can be picked straight away")
	var picks := ChoiceOptions.toggled(c, other[0], true)
	assert_true(picks.size() == 1 and str(picks[0]) == other[0], "picking it replaces the old one: %s" % [picks])
	assert_eq(up.choose(key, picks), [] as Array[String])
	assert_true(up.confirm(), str(up.errors()))
	assert_true(other[0] in ch.picks_for(key) and not before[0] in ch.picks_for(key))


func test_a_paladin_keeps_its_fighting_style_but_swaps_a_blessed_warrior_cantrip() -> void:
	var feat := TestChars.custom("paladin", "human", 2)
	assert_false("paladin.2.fighting_style" in ((_level(feat, "paladin")[1]) as Dictionary), "only a Fighter's Fighting Style feat changes at a level up")
	var blessed := TestChars.custom("paladin", "human", 2, {"fighting_style": ["blessed_warrior"]})
	assert_true("blessed_warrior" in blessed.picks_for("paladin.2.fighting_style"))
	var by_key := (_level(blessed, "paladin")[1]) as Dictionary
	assert_false("paladin.2.fighting_style" in by_key, str(by_key.keys()))
	var cantrips: Choice = null
	for k: String in by_key:
		if k.contains("blessed_warrior"):
			cantrips = by_key[k] as Choice
	assert_true(cantrips != null and cantrips.kind == "cantrip" and cantrips.swap_max == 1,
		"one Blessed Warrior cantrip per Paladin level: %s" % [by_key.keys()])


func test_a_ranger_keeps_its_fighting_style() -> void:
	var ch := TestChars.custom("ranger", "human", 2)
	assert_false("ranger.2.fighting_style" in ((_level(ch, "ranger")[1]) as Dictionary))


func test_another_class_level_changes_none_of_them() -> void:
	var ch := TestChars.custom("fighter", "human", 3, {"fighter_subclass": ["battle_master"]})
	var up := LevelUpController.new(ch)
	assert_true(up.choose_class("barbarian"), "Strength 13 for a Barbarian level")
	up.take_fixed_hit_points()
	var keys: Array = up.level_choices().map(func(c: Choice) -> String: return c.key)
	assert_false("battle_master.3.combat_superiority" in keys, "a Barbarian level swaps no maneuver: %s" % [keys])
	assert_false("fighter.1.fighting_style" in keys, str(keys))


func test_mystic_arcanum_swaps_one_spell_across_all_its_levels() -> void:
	var ch := TestChars.custom("warlock", "human", 13)
	var lv := _level(ch, "warlock")
	var up := lv[0] as LevelUpController
	var six := (lv[1] as Dictionary).get("warlock.11.mystic_arcanum") as Choice
	var seven := (lv[1] as Dictionary).get("warlock.13.mystic_arcanum") as Choice
	assert_true(six != null and seven != null, "Warlock 14 may swap an arcanum: %s" % [(lv[1] as Dictionary).keys()])
	assert_true(ChoiceOptions.swap_note(six).begins_with("1 of your Mystic Arcanum spells can change"), ChoiceOptions.swap_note(six))
	var new6 := _unpicked(six, 1)
	var new7 := _unpicked(seven, 1)
	assert_eq(up.choose(six.key, new6), [] as Array[String], "one arcanum swapped")
	var spent := ((_offered(up))[seven.key]) as Choice
	assert_true(spent != null, "the level 7 arcanum stays on screen")
	assert_eq(spent.swap_max, 0, "the one swap is used")
	assert_true(spent.option(spent.picks[0]).locked, "the level 7 arcanum is locked now")
	var errs := up.choose(seven.key, new7)
	assert_true(errs.size() == 1 and errs[0].contains("Only 1 of your Mystic Arcanum spells can change at a level up"), str(errs))
	up.choose(seven.key, ch.picks_for(seven.key))
	TestChars.auto_pick(up.pending_choices, up.choose)
	assert_true(up.confirm(), str(up.errors()))
	assert_true(new6[0] in ch.picks_for(six.key))


func test_magic_initiate_swaps_one_of_its_spells_on_any_level() -> void:
	var ch := TestChars.custom("fighter", "human", 1, {}, "acolyte")
	var lv := _level(ch, "fighter")
	var up := lv[0] as LevelUpController
	var cantrips := (lv[1] as Dictionary).get("background.feat.two_cantrips.cantrips") as Choice
	var spell := (lv[1] as Dictionary).get("background.feat.level_1_spell") as Choice
	assert_true(cantrips != null and spell != null, "a Fighter level may swap a Magic Initiate spell: %s" % [(lv[1] as Dictionary).keys()])
	var new_spell := _unpicked(spell, 1)
	var swapped: Array = cantrips.picks.duplicate()
	swapped[0] = _unpicked(cantrips, 1)[0]
	assert_eq(up.choose(cantrips.key, swapped), [] as Array[String], "one cantrip swapped")
	var errs := up.choose(spell.key, new_spell)
	assert_true(errs.size() == 1 and errs[0].contains("Only 1 of your Magic Initiate spells can change at a level up"), str(errs))
	up.choose(spell.key, ch.picks_for(spell.key))
	TestChars.auto_pick(up.pending_choices, up.choose)
	assert_true(up.confirm(), str(up.errors()))


## The level's choices by key, as the screen shows them now.
func _offered(up: LevelUpController) -> Dictionary:
	var by_key := {}
	for c in up.level_choices():
		by_key[c.key] = c
	return by_key


func test_magical_discoveries_swap_one_spell_per_bard_level() -> void:
	var ch := TestChars.custom("bard", "human", 6, {"bard_subclass": ["college_of_lore"]})
	var lv := _level(ch, "bard")
	var c := (lv[1] as Dictionary).get("college_of_lore.6.magical_discoveries") as Choice
	assert_true(c != null, "Bard 7 may swap a Magical Discovery: %s" % [(lv[1] as Dictionary).keys()])
	_one_not_two(lv[0] as LevelUpController, c, "spell")
