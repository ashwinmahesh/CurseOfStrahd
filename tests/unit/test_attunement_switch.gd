extends TestCase
## Switching the Attunement setting must never turn an effect off unseen (owner report 2026-10-18: after switching to
## Unlimited a worn Belt of Dwarvenkind seemed dead). Unlimited only adds effects; every special that asked the raw
## attuned list asks Character.attuned_to now, so an item that is worn and unattuned works under Unlimited there too;
## an item that is worn and unattuned under the book's rule is named as idle (Character.idle_for_attunement).


func after_each() -> void:
	GameSettings.set_unlimited_attunement(false)
	GameState.reset()


func _wearer() -> Character:
	var ch := TestChars.pregen("godrick_pendlebrook", 5)
	ch.attuned.clear()
	return ch


func test_attuned_to_is_the_list_in_the_book_and_the_list_or_use_when_unlimited() -> void:
	var ch := _wearer()
	ch.add_item("belt_of_dwarvenkind")
	ch.add_item("pipes_of_the_sewers")
	ch.add_item("luck_blade__longsword")
	ch.wear("belt_of_dwarvenkind")
	assert_false(ch.attuned_to("belt_of_dwarvenkind"), "worn but unattuned: the book's rule says no")
	assert_true(ch.attune("pipes_of_the_sewers"))
	assert_true(ch.attuned_to("pipes_of_the_sewers"))
	GameSettings.set_unlimited_attunement(true)
	assert_true(ch.attuned_to("belt_of_dwarvenkind"), "worn: it counts as attuned for what it does")
	assert_true(ch.attuned_to("pipes_of_the_sewers"), "the list still counts")
	assert_false(ch.attuned_to("luck_blade__longsword"), "a Luck Blade left in the pack is not in use")
	ch.equip("luck_blade__longsword", "main_hand")
	assert_true(ch.attuned_to("luck_blade__longsword"), "drawn, it is")


func test_unlimited_never_takes_away_what_attunement_gave() -> void:
	# An attuned Berserker Axe in the pack still gives its Hit Points ("while attuned"); the switch can't cost them.
	var ch := _wearer()
	ch.add_item("berserker_axe__greataxe")
	var plain := ch.max_hp()
	assert_true(ch.attune("berserker_axe__greataxe"))
	var attuned_hp := ch.max_hp()
	assert_true(attuned_hp > plain, "attuned, in the pack: the Hit Points")
	GameSettings.set_unlimited_attunement(true)
	assert_eq(ch.max_hp(), attuned_hp, "still there when the setting changes")


func test_the_worn_belt_works_the_moment_the_setting_is_unlimited() -> void:
	var ch := _wearer()
	ch.add_item("belt_of_dwarvenkind")
	ch.wear("belt_of_dwarvenkind")
	var con := ch.ability_score(&"con")
	assert_true(ch.idle_for_attunement(ch.entry_of("belt_of_dwarvenkind")), "the book's rule: worn and idle, and it says so")
	GameSettings.set_unlimited_attunement(true)
	assert_false(ch.idle_for_attunement(ch.entry_of("belt_of_dwarvenkind")))
	assert_eq(ch.ability_score(&"con"), mini(con + 2, 20), "Constitution +2 (to 20)")
	assert_eq(ch.darkvision(), 60)
	assert_true(ch.resistance_source(&"poison") != "", "Resistance to Poison")


func test_what_attunement_stands_between_is_listed_worn_things_first() -> void:
	var ch := _wearer()
	for id: String in ["pipes_of_the_sewers", "belt_of_dwarvenkind", "cloak_of_protection"]:
		ch.add_item(id)
	ch.wear("belt_of_dwarvenkind")
	ch.wear("cloak_of_protection")
	var ids: Array[String] = []
	for e in ch.unattuned_in_place():
		ids.append(str(e["id"]))
	assert_eq(ids.size(), 3)
	assert_eq(ids[2], "pipes_of_the_sewers", "the one that works from the pack comes last")
	ch.attune("cloak_of_protection")
	ids.clear()
	for e in ch.unattuned_in_place():
		ids.append(str(e["id"]))
	assert_false("cloak_of_protection" in ids, "an attuned one is not listed")


func test_pipes_of_the_sewers_hold_the_rats_off_a_wearer_who_is_not_attuned_when_unlimited() -> void:
	var e := TestCombat.open_field()
	var hero := TestCombat.hero(e, "godrick_pendlebrook", Vector2i(2, 2), 5)
	var ch := hero.creature as Character
	ch.attuned.clear()
	ch.add_item("pipes_of_the_sewers")
	TestCombat.start_with(e, hero)
	assert_false(e.items._rats_leave_alone(hero), "the book's rule: unattuned pipes do nothing")
	GameSettings.set_unlimited_attunement(true)
	assert_true(e.items._rats_leave_alone(hero), "Unlimited: carried, they work")
