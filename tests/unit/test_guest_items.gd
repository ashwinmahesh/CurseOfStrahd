extends TestCase
## Potions and items for story allies outside a fight (owner, 2026-10-12): a guest travelling with the party drinks a
## potion a hero gives them (even when down), with its healing or what it grants theirs, and a power aimed at a
## creature (a Cure Wounds scroll) can be used on them. The potion comes out of the giver's pack.


func _story(hero: String = "ilse_varga") -> StoryState:
	var st := StoryState.new()
	var ch := TestChars.pregen(hero, 5)
	ch.finish_long_rest()
	st.party.append(ch)
	assert_true(st.add_guest("adrian_martikov"))
	return st


func _count(ch: Character, id: String) -> int:
	return ch.inventory.filter(func(e: Dictionary) -> bool: return str(e["id"]) == id).reduce(
		func(a: int, e: Dictionary) -> int: return a + int(e.get("qty", 1)), 0)


func test_a_guest_drinks_a_healing_potion_even_when_down() -> void:
	var st := _story()
	var ilse := st.party[0]
	var adrian := st.guests[0]
	for id: String in ["potion_of_healing", "potion_of_healing_greater"]:
		ilse.add_item(id, 1)
		adrian.hp = 0
		var res := FieldItems.give_potion(st, ilse, id, "drink", adrian, DiceRoller.new(5))
		assert_true(bool(res["ok"]), "%s: %s" % [id, res])
		assert_true(adrian.hp > 0, "%s brings Adrian back up" % id)
		assert_eq(_count(ilse, id), 0, "out of Ilse's pack")


func test_a_potion_of_heroism_is_the_guests() -> void:
	var st := _story()
	var ilse := st.party[0]
	var adrian := st.guests[0]
	ilse.add_item("potion_of_heroism", 1)
	var res := FieldItems.give_potion(st, ilse, "potion_of_heroism", "drink", adrian, DiceRoller.new(5))
	assert_true(bool(res["ok"]), str(res))
	assert_eq(adrian.temp_hp, 10, "Adrian's 10 Temporary Hit Points")
	assert_eq(ilse.temp_hp, 0, "not Ilse's")


func test_a_cure_wounds_scroll_read_on_a_guest() -> void:
	var st := _story("liriel_dawnsong")
	var liriel := st.party[0]
	var adrian := st.guests[0]
	adrian.hp = 2
	liriel.add_item("spell_scroll__cure_wounds", 1)
	var res := FieldItems.use(st, liriel, "spell_scroll__cure_wounds", "read", adrian, DiceRoller.new(5))
	assert_true(bool(res["ok"]), str(res))
	assert_true(adrian.hp > 2, "Adrian healed")
	assert_eq(_count(liriel, "spell_scroll__cure_wounds"), 0, "the scroll is used up")


func test_only_a_potion_is_given_to_drink() -> void:
	var st := _story("liriel_dawnsong")
	st.party[0].add_item("spell_scroll__cure_wounds", 1)
	var res := FieldItems.give_potion(st, st.party[0], "spell_scroll__cure_wounds", "read", st.guests[0], DiceRoller.new(5))
	assert_false(bool(res["ok"]))
