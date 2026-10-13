extends TestCase
## Spells that last longer from a higher slot (2024 PHB, each spell's "Using a Higher-Level Spell Slot"; data
## `upcast.durations`, Spellcasting.duration_at): Hex 4 hours with a level 2 slot, 8 with 3-4 and 24 with 5+; Hunter's
## Mark 8 with 3-4 and 24 with 5+; the Dominates; Bestow Curse without Concentration from level 5; Magic Circle an hour
## more a level. The 8-hour house rule applies on top: a slot that makes 8 hours makes "until the next Long Rest".


func after_each() -> void:
	GameState.reset()


func _at(spell_id: String, slot: int) -> Dictionary:
	return Spellcasting.duration_at(Compendium.shared().spell_data(spell_id), slot)


func _lasts(spell_id: String, slot: int) -> String:
	return Effect.duration_text(_at(spell_id, slot))


## A warlock of `level` (Kip) hexes a foe with a Pact Magic slot of `slot`: [Kip, the foe].
func _hex(level: int, slot: int) -> Array[Combatant]:
	var e := TestCombat.open_field(2)
	var kip := TestCombat.caster_with(e, ["hex"], Vector2i(2, 3), level, "kip_smudgewick")
	var foe := TestCombat.punching_bag(e, Vector2i(3, 3), 200)
	TestCombat.start_with(e, kip)
	var cast := e.spells.cast(kip, "hex", slot, [foe], Vector2.INF, Vector2.ZERO, {"choice": "str"})
	assert_true(cast.ok, cast.reason)
	var out: Array[Combatant] = [kip, foe]
	return out


func _effect_of(cr: Creature, spell_id: String) -> Effect:
	for fx in cr.effects:
		if fx.source_id == spell_id:
			return fx
	return null


func test_the_durations_follow_the_slot() -> void:
	assert_eq(_lasts("hex", 1), "Concentration, up to 1 hour")
	assert_eq(_lasts("hex", 2), "Concentration, up to 4 hours")
	assert_eq(_lasts("hex", 3), "Concentration, until your next Long Rest", "8 hours: the house rule")
	assert_eq(_lasts("hex", 4), "Concentration, until your next Long Rest")
	assert_eq(_lasts("hex", 5), "Concentration, up to 24 hours")
	assert_eq(_lasts("hunters_mark", 2), "Concentration, up to 1 hour")
	assert_eq(_lasts("hunters_mark", 3), "Concentration, until your next Long Rest")
	assert_eq(_lasts("hunters_mark", 9), "Concentration, up to 24 hours")
	assert_eq(_lasts("dominate_beast", 4), "Concentration, up to 1 minute")
	assert_eq(_lasts("dominate_beast", 6), "Concentration, up to 1 hour")
	assert_eq(_lasts("dominate_person", 6), "Concentration, up to 10 minutes")
	assert_eq(_lasts("dominate_person", 8), "Concentration, until your next Long Rest")
	assert_eq(_lasts("dominate_monster", 9), "Concentration, until your next Long Rest")
	assert_eq(_lasts("bestow_curse", 4), "Concentration, up to 10 minutes")
	assert_eq(_lasts("bestow_curse", 5), "Until your next Long Rest", "no Concentration from level 5")
	assert_eq(_lasts("bestow_curse", 7), "24 hours")
	assert_eq(_lasts("bestow_curse", 9), "Until dispelled")
	assert_eq(_lasts("major_image", 4), "Until dispelled")
	assert_eq(_lasts("magic_circle", 3), "1 hour")
	assert_eq(_lasts("magic_circle", 6), "4 hours")
	assert_eq(_lasts("mass_suggestion", 9), "366 days")


func test_kips_hex_with_a_level_3_pact_slot_lasts_until_the_long_rest() -> void:
	var cast := _hex(5, 3)
	var kip := cast[0].creature
	assert_true(kip.concentration.until_long_rest and kip.concentration.rounds_left < 0, "8 hours: until the Long Rest")
	var curse := _effect_of(kip, "hex")
	assert_true(curse != null and curse.ends == Effect.Ends.LONG_REST, "the curse's damage too")
	kip.advance_minutes(10 * 60)
	assert_true(kip.concentration != null and _effect_of(kip, "hex") != null, "still on 10 hours later")
	kip.finish_long_rest()
	assert_true(kip.concentration == null and _effect_of(kip, "hex") == null, "the Long Rest ends it")


func test_a_level_2_hex_lasts_four_hours() -> void:
	var kip := _hex(3, 2)[0].creature
	kip.advance_minutes(3 * 60)
	assert_true(kip.concentration != null, "on after 3 hours")
	kip.advance_minutes(61)
	assert_true(kip.concentration == null and _effect_of(kip, "hex") == null, "gone after 4")


func test_a_level_5_hex_lasts_a_day_and_a_trance_keeps_it_through_the_rest() -> void:
	var e := TestCombat.open_field(2)
	var elf := TestCombat.caster_with(e, ["hex"], Vector2i(2, 3), 9, "silvain_aster")
	var foe := TestCombat.punching_bag(e, Vector2i(3, 3), 200)
	TestCombat.start_with(e, elf)
	assert_true(e.spells.cast(elf, "hex", 5, [foe], Vector2.INF, Vector2.ZERO, {"choice": "str"}).ok)
	var conc := elf.creature.concentration
	assert_true(not conc.until_long_rest and conc.rounds_left > 23 * 60 * Effect.ROUNDS_PER_MINUTE, "24 hours on the clock")
	elf.creature.advance_minutes(8 * 60)
	elf.creature.finish_long_rest()
	assert_true(elf.creature.concentration == conc, "an elf's Trance keeps a day's Hex through the rest")
	elf.creature.advance_minutes(16 * 60)
	assert_true(elf.creature.concentration == null, "and the day runs out")


func test_hunters_mark_with_a_level_3_slot_lasts_until_the_long_rest() -> void:
	var e := TestCombat.open_field(2)
	var c := TestCombat.caster_with(e, ["hunters_mark"], Vector2i(2, 3), 9, "silvain_aster")
	var foe := TestCombat.punching_bag(e, Vector2i(3, 3), 200)
	TestCombat.start_with(e, c)
	assert_true(e.spells.cast(c, "hunters_mark", 3, [foe]).ok)
	assert_true(c.creature.concentration.until_long_rest)
	c.creature.finish_long_rest()
	assert_true(c.creature.concentration == null, "a Trance doesn't keep a spell held until the rest")


func test_bestow_curse_from_a_level_5_slot_needs_no_concentration() -> void:
	var e := TestCombat.open_field(2)
	var c := TestCombat.caster_with(e, ["bestow_curse"], Vector2i(2, 3), 9, "silvain_aster")
	var foe := TestCombat.punching_bag(e, Vector2i(3, 3), 200)
	TestCombat.start_with(e, c)
	assert_true(e.spells.cast(c, "bestow_curse", 5, [foe], Vector2.INF, Vector2.ZERO, {"choice": "ability_str"}).ok)
	assert_true(c.creature.concentration == null, "no Concentration")
	var curse := _effect_of(foe.creature, "bestow_curse")
	assert_true(curse != null and curse.ends == Effect.Ends.LONG_REST, "8 hours: until the Long Rest")


func test_a_saved_hex_keeps_its_long_rest_hold() -> void:
	var kip := _hex(5, 3)[0].creature as Character
	GameState.reset()
	GameState.story.party.append(kip)
	GameState.from_dict(JSON.parse_string(JSON.stringify(GameState.to_dict())) as Dictionary)
	var back := GameState.story.party[0]
	assert_true(back.concentration != null and back.concentration.until_long_rest, "still until the Long Rest after a load")


func test_magic_circle_from_a_higher_slot_stands_longer() -> void:
	var st := StoryState.new()
	var cleric := TestChars.custom("cleric", "human", 11)
	var prepared := (cleric.spellcasting[0] as Dictionary)["prepared"] as Array
	if not "magic_circle" in prepared:
		prepared.append("magic_circle")
	TestCombat.give_components(cleric, ["magic_circle"])
	cleric.finish_long_rest()
	st.party.append(cleric)
	var res := FieldCasting.cast_utility(st, cleric, "magic_circle", false, 5)
	assert_true(bool(res["ok"]), str(res["text"]))
	assert_eq(int((st.active_spells["magic_circle"] as Dictionary)["until"]) - st.total_minutes(), 3 * 60, "3 hours at level 5")
