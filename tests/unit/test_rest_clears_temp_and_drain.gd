extends TestCase
## 2024 PHB, Long Rest: "If your Hit Point maximum was reduced, it returns to normal", and Temporary Hit Points last
## "until they're depleted or you finish a Long Rest". A monster's drain (Wight, Wraith, Specter, Vampire Spawn, Strahd,
## Harm) and Temporary Hit Points from a spell or a feature both end with the Long Rest; a Short Rest leaves both; a room
## at an inn that grants Temporary Hit Points on waking still does (the rest's own words).


func after_each() -> void:
	GameState.reset()


## A hero in a fight with `amount` of its Hit Point maximum drained by a monster's attack: [the encounter, the hero].
func _drained(amount: int) -> Array:
	var e := TestCombat.open_field()
	var hero := TestCombat.hero(e, "ilse_varga", Vector2i(2, 2), 5)
	TestCombat.punching_bag(e, Vector2i(6, 6))
	TestCombat.start_with(e, hero)
	e.monster_actions.drain_max_hp(hero, amount, "Life Drain")
	return [e, hero]


func _party_of(ch: Character) -> StoryState:
	GameState.reset()
	GameState.story.party.append(ch)
	return GameState.story


func test_a_drained_maximum_returns_with_a_long_rest_and_not_before() -> void:
	var hero := _drained(12)[1] as Combatant
	var ch := hero.creature as Character
	var full := ch.max_hp() + 12
	assert_eq(ch.max_hp(), full - 12, "drained")
	ch.finish_short_rest()
	assert_eq(ch.max_hp(), full - 12, "a Short Rest does not give it back")
	var st := _party_of(ch)
	LongRest.finish(st, DiceRoller.new(3))
	assert_eq(ch.max_hp(), full, "a Long Rest does")
	assert_eq(ch.hp, full, "and all the Hit Points with it")
	assert_true(ch.effects.all(func(fx: Effect) -> bool: return fx.source_id != "drain_max_hp"), "the drain effect is gone")


func test_every_drain_stacks_and_every_one_ends_at_the_long_rest() -> void:
	var run := _drained(5)
	var e := run[0] as Encounter
	var hero := run[1] as Combatant
	var ch := hero.creature as Character
	var full := ch.max_hp() + 5
	e.monster_actions.drain_max_hp(hero, 7, "Bite")
	assert_eq(ch.max_hp(), full - 12, "two drains add up")
	LongRest.finish(_party_of(ch), DiceRoller.new(3))
	assert_eq(ch.max_hp(), full)


func test_a_drain_survives_a_save_and_still_ends_at_the_long_rest() -> void:
	var hero := _drained(9)[1] as Combatant
	var ch := hero.creature as Character
	var full := ch.max_hp() + 9
	_party_of(ch)
	var saved := JSON.parse_string(JSON.stringify(GameState.to_dict())) as Dictionary
	GameState.from_dict(saved)
	var back := GameState.story.party[0]
	assert_eq(back.max_hp(), full - 9, "still drained after the load")
	LongRest.finish(GameState.story, DiceRoller.new(3))
	assert_eq(back.max_hp(), full, "and restored by the rest")


func test_temporary_hit_points_end_with_the_long_rest_and_not_the_short_one() -> void:
	var ch := TestChars.pregen("ilse_varga", 5)
	ch.hp = ch.max_hp()
	assert_true(ch.add_temp_hp(11, "Test"))
	ch.finish_short_rest()
	assert_eq(ch.temp_hp, 11, "a Short Rest leaves them")
	LongRest.finish(_party_of(ch), DiceRoller.new(3))
	assert_eq(ch.temp_hp, 0, "a Long Rest takes them")


func test_a_guest_travelling_with_the_party_gets_both_too() -> void:
	var guest := TestChars.pregen("kip_smudgewick", 3)
	var st := _party_of(TestChars.pregen("ilse_varga", 3))
	st.guests.append(guest)
	var full := guest.max_hp()
	guest.add_temp_hp(6, "Test")
	var fx := Effect.new("Life Drain (drained)", &"monster", "drain_max_hp")
	fx.ends = Effect.Ends.LONG_REST
	fx.modifiers.append(Modifier.of("hp_max", {"value": -4}, "Life Drain", &"monster"))
	guest.add_effect(fx)
	assert_eq(guest.max_hp(), full - 4)
	LongRest.finish(st, DiceRoller.new(3))
	assert_eq(guest.temp_hp, 0)
	assert_eq(guest.max_hp(), full)


func test_what_the_rest_itself_grants_stays() -> void:
	# Celestial Resilience and an inn's room grant Temporary Hit Points as the rest ends: those are the rest's words.
	var ch := TestChars.pregen("ilse_varga", 5)
	var st := _party_of(ch)
	ch.add_temp_hp(3, "Old")
	LongRest.finish(st, DiceRoller.new(3))
	assert_eq(ch.temp_hp, 0)
	assert_true(ch.add_temp_hp(ch.character_level(), "Inn"), "granted after the rest it stays")
	assert_eq(ch.temp_hp, ch.character_level())
