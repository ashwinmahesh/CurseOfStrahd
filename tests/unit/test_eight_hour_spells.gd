extends TestCase
## House rule (owner, 2026-10-12): spells that last 8 hours (Mage Armor, Aid, Darkvision, Death Ward ...) last until the
## next Long Rest instead; 24 hours and longer keep the clock. Saves from before switch on load.


func _effect_of(ch: Character, spell_id: String) -> Effect:
	for fx in ch.effects:
		if fx.source_id == spell_id:
			return fx
	return null


func test_the_duration_reads_until_the_next_long_rest() -> void:
	for id: String in ["mage_armor", "aid", "darkvision", "death_ward"]:
		var d := Compendium.shared().spell_data(id).get("duration", {}) as Dictionary
		assert_true(Effect.until_long_rest(d), id)
		assert_eq(Effect.duration_text(d), "Until your next Long Rest", id)
	var goodberry := Compendium.shared().spell_data("goodberry").get("duration", {}) as Dictionary
	assert_false(Effect.until_long_rest(goodberry), "24 hours keeps the clock")
	assert_eq(Effect.duration_text(goodberry), "24 hours")


func test_mage_armor_outlasts_the_clock_and_ends_at_a_long_rest() -> void:
	var st := StoryState.new()
	var wiz := TestChars.pregen("silvain_aster", 5)
	wiz.finish_long_rest()
	st.party.append(wiz)
	var res := FieldCasting.cast(st.party, wiz, "mage_armor", 0, [wiz], DiceRoller.new(2))
	assert_true(bool(res["ok"]), str(res))
	var fx := _effect_of(wiz, "mage_armor")
	assert_true(fx != null and fx.ends == Effect.Ends.LONG_REST, "until the next Long Rest")
	st.advance_minutes(10 * 60)
	assert_true(_effect_of(wiz, "mage_armor") != null, "still on after 10 hours")
	wiz.finish_long_rest()
	assert_true(_effect_of(wiz, "mage_armor") == null, "gone after the rest")


func test_aid_cast_in_a_fight_lasts_until_the_long_rest() -> void:
	var e := TestCombat.open_field(2)
	var cleric := TestCombat.caster_with(e, ["aid"], Vector2i(2, 2), 5, "liriel_dawnsong")
	TestCombat.foe(e, "zombie", Vector2i(10, 6))
	TestCombat.start_with(e, cleric)
	assert_true(e.spells.cast(cleric, "aid", 2, [cleric]).ok)
	var fx := _effect_of(cleric.creature as Character, "aid")
	assert_true(fx != null and fx.ends == Effect.Ends.LONG_REST)


func test_an_exploring_darkvision_runs_until_the_long_rest() -> void:
	var st := StoryState.new()
	st.active_spells["darkvision"] = {"until": st.total_minutes() + 8 * 60, "caster": "x"}
	RestRules.keep_until_long_rest(st, "darkvision")
	st.advance_minutes(12 * 60)
	assert_true(st.spell_active("darkvision"), "still running")
	RestRules.note_long_rest(st)
	assert_false(st.spell_active("darkvision"), "ended by the rest")


func test_a_save_from_before_switches_on_load() -> void:
	GameState.reset()
	var wiz := TestChars.pregen("silvain_aster", 5)
	var armor := Effect.new("Mage Armor", &"spell", "mage_armor").with_modifier("ac_base", {"value": 13})
	armor.ends = Effect.Ends.MINUTES
	armor.minutes_left = 120
	wiz.add_effect(armor)
	GameState.story.party.append(wiz)
	GameState.story.active_spells["darkvision"] = {"until": GameState.story.total_minutes() + 60, "caster": wiz.id}
	var saved := GameState.to_dict()
	GameState.from_dict(JSON.parse_string(JSON.stringify(saved)) as Dictionary)
	var back := _effect_of(GameState.story.party[0], "mage_armor")
	assert_true(back != null and back.ends == Effect.Ends.LONG_REST, "Mage Armor until the Long Rest now")
	assert_true(bool((GameState.story.active_spells["darkvision"] as Dictionary).get("long_rest", false)), "and Darkvision")
	GameState.reset()
