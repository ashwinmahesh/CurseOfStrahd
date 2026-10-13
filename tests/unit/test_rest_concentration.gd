extends TestCase
## Concentration and rests (owner report 2026-10-13: Kip's Hex stayed on through Long Rests). Asleep, a creature has
## the Unconscious condition (2024 glossary "Long Rest"), which ends Concentration, so a Long Rest ends it, an
## interrupted one too; a Trance keeps its creature conscious, so an elf's runs on to its own end, but a spell the
## 8-hour house rule holds until the rest ends there either way. A save keeps how long a Concentration has left: one
## loaded without it used to have no end at all.


func after_each() -> void:
	GameState.reset()


func _effects_of(cr: Creature, spell_id: String) -> Array[Effect]:
	var out: Array[Effect] = []
	for fx in cr.effects:
		if fx.source_id == spell_id:
			out.append(fx)
	return out


## Kip (a level 1 warlock: a level 1 Pact Magic slot, so an hour's Hex) hexes a foe in a fight: [the encounter, Kip,
## the foe]. A higher slot lasts longer (test_slot_durations).
func _kip_hexes() -> Array:
	var e := TestCombat.open_field(2)
	var kip := TestCombat.caster_with(e, ["hex"], Vector2i(2, 3), 1, "kip_smudgewick")
	var foe := TestCombat.punching_bag(e, Vector2i(3, 3), 200)
	TestCombat.start_with(e, kip)
	var cast := e.spells.cast(kip, "hex", 1, [foe], Vector2.INF, Vector2.ZERO, {"choice": "str"})
	assert_true(cast.ok, cast.reason)
	assert_eq(kip.creature.concentration.source_id, "hex")
	return [e, kip, foe]


## The game saved with `party` and loaded again; `edit` changes the saved game first (a save from before).
func _saved_and_loaded(party: Array[Character], edit: Callable = Callable()) -> StoryState:
	GameState.reset()
	for ch in party:
		GameState.story.party.append(ch)
	var saved := JSON.parse_string(JSON.stringify(GameState.to_dict())) as Dictionary
	if edit.is_valid():
		edit.call(saved)
	GameState.from_dict(saved)
	return GameState.story


func test_hex_keeps_its_clock_through_a_save_and_runs_out() -> void:
	var kip := _kip_hexes()[1] as Combatant
	var left := kip.creature.concentration.rounds_left
	assert_true(left > 0 and left <= 600, "an hour, less what has passed")
	var st := _saved_and_loaded([kip.creature as Character])
	var back := st.party[0]
	assert_true(back.concentration != null, "still concentrating after the load")
	assert_eq(back.concentration.rounds_left, left, "with the time it had left")
	st.advance_minutes(61)
	assert_true(back.concentration == null, "an hour later it has run out")
	assert_true(_effects_of(back, "hex").is_empty(), "and the curse with it")


func test_a_save_from_before_gives_the_spell_its_whole_duration() -> void:
	# The owner's saves: Kip concentrating on Hex with nothing left attached and no time kept.
	var kip := TestChars.pregen("kip_smudgewick", 5)
	kip.begin_concentration("hex", "Hex").rounds_left = 120
	var st := _saved_and_loaded([kip], func(saved: Dictionary) -> void:
		var member := ((saved["story"] as Dictionary)["party"] as Array)[0] as Dictionary
		var conc := (member["state"] as Dictionary)["concentration"] as Dictionary
		assert_true(conc.erase("rounds_left"), "the saved game holds the time left"))
	var back := st.party[0]
	assert_eq(back.concentration.rounds_left, 600, "an hour from the load, never endless")
	LongRest.finish(st, DiceRoller.new(3))
	assert_true(back.concentration == null, "and the next Long Rest ends it")


func test_a_long_rest_ends_hex_after_a_load() -> void:
	var kip := _kip_hexes()[1] as Combatant
	var st := _saved_and_loaded([kip.creature as Character])
	LongRest.finish(st, DiceRoller.new(3))
	var back := st.party[0]
	assert_true(back.concentration == null, "no Hex after the rest")
	assert_true(_effects_of(back, "hex").is_empty(), "nor its extra damage")


func test_sleep_ends_concentration_with_time_left() -> void:
	var hexed := _kip_hexes()
	var kip := hexed[1] as Combatant
	var foe := hexed[2] as Combatant
	kip.creature.finish_long_rest()
	assert_true(kip.creature.concentration == null, "asleep is Unconscious: Concentration ends")
	assert_true(_effects_of(kip.creature, "hex").is_empty(), "the caster's curse damage goes")
	assert_false(foe.creature.effects.any(func(fx: Effect) -> bool: return fx.source_id.begins_with("hex")),
		"and the curse and its mark on the foe")


func test_every_kind_of_concentration_ends_at_the_rest_after_a_load() -> void:
	# An hour, a minute, a day and the house rule's 8 hours on the clock, and one with no spell's duration (a readied
	# spell), each kept through a save and a load first.
	for id: String in ["hex", "hunters_mark", "bless", "enhance_ability", "invisibility", "suggestion", "find_the_path",
			"readied:fire_bolt"]:
		var ch := TestChars.pregen("kip_smudgewick", 5)
		var conc := ch.begin_concentration(id, id)
		var fx := Effect.new(id, &"spell", id)
		fx.lasting(Compendium.shared().spell_data(id).get("duration", {}) as Dictionary)
		assert_true(conc.attach(ch, fx), id)
		var saved := JSON.parse_string(JSON.stringify(ch.state_to_dict())) as Dictionary
		ch.state_from_dict(saved)
		var loaded: Array[Creature] = [ch]
		Creature.relink_concentration(loaded, {ch.id: saved})
		assert_eq(ch.concentration.rounds_left, conc.rounds_left, "%s: its time left is kept" % id)
		ch.finish_long_rest()
		assert_true(ch.concentration == null, "%s: Concentration ends" % id)
		assert_true(_effects_of(ch, id).is_empty(), "%s: its effect ends" % id)


func test_the_house_rule_holds_an_eight_hour_concentration_until_the_rest() -> void:
	var ch := TestChars.pregen("kip_smudgewick", 5)
	var conc := ch.begin_concentration("suggestion", "Suggestion")
	assert_true(conc.until_long_rest and conc.rounds_left < 0, "no clock: until the next Long Rest")
	assert_eq(str(EffectIcons.entries(ch)[0]["when"]), "Concentration · until a Long Rest")
	ch.advance_minutes(10 * 60)
	assert_true(ch.concentration == conc, "still on after 10 hours")
	ch.finish_long_rest()
	assert_true(ch.concentration == null, "ended by the rest")


func test_a_trance_keeps_a_long_concentration_but_not_one_held_until_the_rest() -> void:
	var elf := TestChars.pregen("silvain_aster", 5)
	assert_true(elf.has_flag("trance"), "an elf trances")
	elf.begin_concentration("find_the_path", "Find the Path")
	elf.finish_long_rest()
	assert_true(elf.concentration != null and elf.concentration.source_id == "find_the_path",
		"conscious in a Trance: a day's spell runs on")
	elf.begin_concentration("suggestion", "Suggestion")
	elf.finish_long_rest()
	assert_true(elf.concentration == null, "the house rule's 8 hours end at the rest, Trance or not")


func test_an_interrupted_rest_still_ends_concentration() -> void:
	var dice_seed := 1
	while DiceRoller.new(dice_seed).roll_one(6) != 1:
		dice_seed += 1
	var st := StoryState.new()
	var kip := TestChars.pregen("kip_smudgewick", 5)
	var elf := TestChars.pregen("silvain_aster", 5)
	st.party.append(kip)
	st.party.append(elf)
	kip.begin_concentration("find_the_path", "Find the Path")
	elf.begin_concentration("find_the_path", "Find the Path")
	var res := LongRest.take(st, "risky", DiceRoller.new(dice_seed))
	assert_true(bool(res["interrupted"]), "the night is interrupted")
	assert_true(kip.concentration == null, "the party slept before it was: Concentration ends")
	assert_true(elf.concentration != null, "the elf's Trance kept it")
