extends TestCase
## Find Steed (2024 PHB; owner report 2026-10-11: a paladin couldn't cast it outside fights): cast from the sheet while
## exploring (Faithful Steed's free casting first), the steed stays with its caster (Character.steed: its creature type
## and the spell's level) and joins every fight beside them until it drops to 0 Hit Points or its caster dies. A steed
## called in a fight stays too.


func _paladin(level: int = 5) -> Character:
	var ch := TestChars.pregen("godrick_pendlebrook", level)
	ch.finish_long_rest()
	return ch


func _steed_in(e: Encounter) -> Combatant:
	for c in e.combatants:
		if c.creature is Monster and bool((c.creature as Monster).data.get("steed", false)) and c.is_alive():
			return c
	return null


func test_find_steed_is_cast_while_exploring_with_the_free_casting_first() -> void:
	var ch := _paladin()
	var st := StoryState.new()
	st.party.append(ch)
	var option := {}
	for o in FieldCasting.utility_options(st.party, ch, DiceRoller.new(1)):
		if str(o["id"]) == "find_steed":
			option = o
	assert_false(option.is_empty(), "Find Steed is on the exploring list")
	assert_true(bool(option["legal"]) and bool(option["free"]), "Faithful Steed's free casting")
	assert_eq(option["choices"], ["celestial", "fey", "fiend"], "the steed's creature type")
	var slots := ch.slots_left(2)
	var res := FieldCasting.cast_utility(st, ch, "find_steed", false, 0, "", "fey")
	assert_true(bool(res["ok"]), str(res))
	assert_eq(ch.steed, {"type": "fey", "level": 2})
	assert_eq(ch.resource_left("spell:find_steed"), 0, "the free casting is spent")
	assert_eq(ch.slots_left(2), slots, "no slot")
	res = FieldCasting.cast_utility(st, ch, "find_steed", false, 0, "", "fiend")
	assert_true(bool(res["ok"]), "again, with a slot: %s" % [res])
	assert_eq(ch.slots_left(2), slots - 1)
	assert_eq(ch.steed, {"type": "fiend", "level": 2}, "a new casting replaces the steed")
	assert_eq(Character.from_dict(ch.to_dict()).steed, {"type": "fiend", "level": 2}, "the steed is saved")


func test_the_steed_joins_fights_until_it_falls() -> void:
	var ch := _paladin()
	ch.steed = {"type": "celestial", "level": 3}
	var e := TestCombat.open_field()
	var c := e.add(ch, &"party", Vector2i(2, 2))
	var slots := ch.slots_left(2)
	EncounterSetup.bring_steeds(e, [c])
	var steed := _steed_in(e)
	assert_true(steed != null, "the steed is beside its caster")
	assert_eq(steed.side, &"guest")
	assert_eq(ch.slots_left(2), slots, "nothing spent")
	e.deal_damage(null, steed, [{"amount": 999, "type": "force"}], false, "Test")
	assert_eq(ch.steed, {}, "a steed at 0 Hit Points is gone")
	var e2 := TestCombat.open_field()
	EncounterSetup.bring_steeds(e2, [e2.add(ch, &"party", Vector2i(2, 2))])
	assert_true(_steed_in(e2) == null, "and doesn't come back")


func test_a_steed_called_in_a_fight_stays_and_goes_when_its_caster_dies() -> void:
	var ch := _paladin()
	var e := TestCombat.open_field()
	var c := e.add(ch, &"party", Vector2i(2, 2))
	TestCombat.foe(e, "zombie", Vector2i(9, 2))
	TestCombat.start_with(e, c)
	assert_true(e.spells.cast(c, "find_steed", 2, [], Vector2(3.5, 3.5), Vector2.ZERO, {"choice": "celestial"}).ok)
	assert_eq(ch.steed, {"type": "celestial", "level": 2}, "the steed stays after the fight")
	ch.hp = 0
	ch.dead = true
	e.spells.summons.on_death(c)
	assert_eq(ch.steed, {}, "its caster died")
	assert_true(_steed_in(e) == null, "and it vanished")
