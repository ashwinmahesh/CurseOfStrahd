extends TestCase

var _book_content: BookContentFixture

func before_each() -> void:
	_book_content = BookContentFixture.new()

func after_each() -> void:
	_book_content.restore()

func mystic(level: int) -> Character:
	return TestChars.custom("monk", "human", level, {"monk_subclass": ["warrior_of_the_mystic_arts"], "monk.cantrips": ["fire_bolt", "ray_of_frost"]})

func test_third_caster_progression_uses_wisdom_sorcerer_list_and_level_up_swaps() -> void:
	var ch := mystic(3)
	assert_eq(ch.spellcasting.size(), 1)
	assert_eq(ch.spellcasting[0]["ability"], "wis")
	assert_eq(ch.spellcasting[0]["list"], "sorcerer")
	assert_eq(ch.spellcasting[0]["cantrips_max"], 2)
	assert_eq(ch.spellcasting[0]["prepared_max"], 3)
	assert_eq(ch.spellcasting_slots(), [2, 0, 0, 0, 0, 0, 0, 0, 0])
	assert_eq(ch.spell_save_dc("monk").total(), 8 + ch.proficiency_bonus() + ch.ability_mod(&"wis"))
	assert_eq(ch.choice("monk.cantrips").replace_max, 1)
	assert_eq(ch.choice("monk.prepared").replaceable, "level_up")
	assert_eq(ch.choice("monk.prepared").replace_max, 1)
	var high := mystic(19)
	assert_eq(high.spellcasting[0]["cantrips_max"], 3)
	assert_eq(high.spellcasting[0]["prepared_max"], 12)
	assert_eq(high.spellcasting_slots(), [4, 3, 3, 1, 0, 0, 0, 0, 0])
	assert_eq(Spellcasting.slots_for([{"progression": "third", "level": 7}, {"progression": "full", "level": 1}]), [4, 2, 0, 0, 0, 0, 0, 0, 0], "multiclass third-caster levels round down")

func test_mystic_cantrip_replaces_one_attack_without_using_bonus_action() -> void:
	var e := TestCombat.open_field()
	var c := e.add(mystic(6), &"party", Vector2i(2, 3))
	c.reaction_rules["heroic_inspiration"] = "never"
	var target := TestCombat.punching_bag(e, Vector2i(3, 3), 500)
	TestCombat.start_with(e, c)
	var catalog := ActionCatalog.new(e)
	var action := catalog.find(c, "war_magic:fire_bolt")
	assert_false(action.is_empty())
	assert_true(catalog.perform(c, action, [target]).ok)
	assert_eq(c.attacks_left, 1)
	assert_true(c.bonus_available)
	assert_false(e.spells.cast(c, "fire_bolt", 0, [target], Vector2.INF, Vector2.ZERO, {"war_magic": true}).ok)
	assert_true(e.attack(c, target, "weapon:unarmed_strike").ok)

func test_slot_conversion_cost_caps_and_action_economy() -> void:
	var e := TestCombat.open_field()
	var ch := mystic(7)
	var c := e.add(ch, &"party", Vector2i(2, 3))
	TestCombat.punching_bag(e, Vector2i(9, 3), 500)
	TestCombat.start_with(e, c)
	assert_false(ch.convert_slot_to_resource("mystic_focus", 2), "cannot waste a slot on a full pool")
	ch.spend_resource("focus_points", 1)
	var slots := ch.slots_left(2)
	assert_true(e.feature_actions.perform(c, "slot_exchange:mystic_focus:2", null, Vector2.INF).ok)
	assert_eq(ch.slots_left(2), slots - 1)
	assert_eq(ch.resource_left("focus_points"), ch.resource_max("focus_points"))
	assert_true(c.action_available and c.bonus_available and c.reaction_available)
	assert_false(c.cast_slot_spell_this_turn, "converting a slot is not casting a spell")
	assert_false(ch.convert_slot_to_resource("unknown", 1))
	assert_false(ch.convert_slot_to_resource("mystic_focus", 10))

func test_recovery_windows_level_gates_and_exact_costs() -> void:
	for row: Array in [[6, 1, 2], [7, 2, 3], [13, 3, 5], [19, 4, 6]]:
		var ch := mystic(int(row[0]))
		var slot := int(row[1])
		assert_true(ch.expend_slot(slot))
		assert_false(ch.recover_slot_with_resource("mystic_focus", slot), "must be in a triggering event")
		ch.finish_short_rest()
		var before := ch.resource_left("focus_points")
		assert_true(ch.recover_slot_with_resource("mystic_focus", slot))
		assert_eq(ch.resource_left("focus_points"), before - int(row[2]))
		assert_false(ch.recover_slot_with_resource("mystic_focus", slot), "one recovery per event")
		ch.expend_slot(slot)
		ch.finish_short_rest()
		ch.close_slot_recovery()
		assert_false(ch.recover_slot_with_resource("mystic_focus", slot), "closing the rest ends the choice")
	var low := mystic(6)
	low.slots_used[1] = 1
	low.open_slot_recovery("short_rest")
	assert_false(low.recover_slot_with_resource("mystic_focus", 2), "class level gate also applies to multiclass slots")

func test_uncanny_metabolism_offers_one_recovery_without_a_reaction_cost() -> void:
	var e := TestCombat.open_field()
	var ch := mystic(7)
	ch.expend_slot(1)
	ch.expend_slot(2)
	ch.spend_resource("focus_points", 3)
	var c := e.add(ch, &"party", Vector2i(2, 3))
	c.reaction_rules["mystic_focus"] = "ask"
	TestCombat.punching_bag(e, Vector2i(9, 3), 500)
	TestCombat.start_with(e, c)
	assert_true(e.pending != null)
	if e.pending == null:return
	assert_false(e.pending.spends_reaction)
	assert_eq(e.pending.kind, "mystic_focus")
	assert_true(e.answer_reaction(false).ok, "decline level 1 and choose level 2")
	assert_true(e.pending != null)
	assert_true(e.answer_reaction(true).ok)
	assert_true(e.pending == null)
	assert_eq(ch.expended_slots(1), 1)
	assert_eq(ch.expended_slots(2), 0)
	assert_eq(ch.resource_left("focus_points"), 4)
	assert_true(c.reaction_available)
	assert_true(ch.slot_recovery_options().is_empty())

func test_focused_strike_applies_on_both_stunning_save_outcomes_and_expires() -> void:
	for succeeds: bool in [true, false]:
		var e := TestCombat.open_field()
		var c := e.add(mystic(11), &"party", Vector2i(2, 3))
		var target := TestCombat.punching_bag(e, Vector2i(3, 3), 500)
		target.creature.add_effect(Effect.new("Force save outcome").with_modifier("save", {"ability": "con", "value": 100 if succeeds else -100}))
		TestCombat.start_with(e, c)
		c.armed.append("stunning_strike")
		TestCombat.next_d20(e, 19)
		assert_true(e.attack(c, target, "weapon:unarmed_strike").ok)
		assert_eq(target.creature.has_condition(&"stunned"), not succeeds)
		var test := target.creature.roll_save(e.dice, &"wis", 15, [], [], "same caster", SpellCaster.spell_save_keys(c.id))
		assert_true(test.disadvantage)
		var other := target.creature.roll_save(e.dice, &"wis", 15, [], [], "another caster", SpellCaster.spell_save_keys("other"))
		assert_false(other.disadvantage)
		target.creature.on_turn_start(c.id)
		var expired := target.creature.roll_save(e.dice, &"wis", 15, [], [], "expired", SpellCaster.spell_save_keys(c.id))
		assert_false(expired.disadvantage)


func test_flurry_spell_substitution_shares_bonus_cost_and_leaves_one_unarmed_strike() -> void:
	var e := TestCombat.open_field()
	var ch := mystic(17)
	(ch.spellcasting[0]["prepared"] as Array).append("magic_missile")
	var c := e.add(ch, &"party", Vector2i(2, 3))
	c.reaction_rules["heroic_inspiration"] = "never"
	var target := TestCombat.punching_bag(e, Vector2i(3, 3), 500)
	TestCombat.start_with(e, c)
	e.spend_action(c)
	c.magic_action_used = true
	var catalog := ActionCatalog.new(e)
	var action := catalog.find(c, "spell:magic_missile:improved_mystic_fighting_style")
	assert_false(action.is_empty())
	assert_true(bool(action["legal"]), "a used Magic action does not block this Bonus Action spell")
	var focus := ch.resource_left("focus_points")
	var slots := ch.slots_left(2)
	assert_eq(catalog.level_choices(c, action), [1, 2])
	assert_true(catalog.perform(c, action, [target], Vector2.INF, Vector2.ZERO, 2).ok, "upcasting is allowed within the feature's level limit")
	assert_eq(ch.resource_left("focus_points"), focus - 1)
	assert_eq(ch.slots_left(2), slots - 1)
	assert_false(c.bonus_available)
	assert_false(c.action_available)
	assert_true(c.cast_slot_spell_this_turn)
	assert_true(e.triggered_features.sequence_attack_options(c).all(func(o: Dictionary) -> bool: return (o["profile"] as WeaponProfile).item_id == "unarmed_strike"))
	assert_false(e.triggered_features.sequence_attack(c, null, "weapon:unarmed_strike").ok)
	assert_eq(int((c.get_meta("sequence_attacks") as Dictionary)["remaining"]), 1)
	ch.add_condition(&"stunned", "test")
	assert_false(e.triggered_features.sequence_attack(c, target, "weapon:unarmed_strike").ok)
	ch.remove_condition(&"stunned", "test")
	TestCombat.next_d20(e, 19)
	assert_true(e.feature_actions.perform(c, "sequence_attack:weapon:unarmed_strike", target, Vector2.INF).ok)
	assert_true(e.triggered_features.sequence_attack_options(c).is_empty())
	assert_false(e.triggered_features.sequence_attack(c, target, "weapon:unarmed_strike").ok)
	assert_false(c.has_meta("flurry_turn"))

func test_flurry_spell_rejects_wrong_spell_and_targets_before_any_costs() -> void:
	var e := TestCombat.open_field()
	var ch := mystic(17)
	(ch.spellcasting[0]["prepared"] as Array).append_array(["fireball", "magic_missile"])
	var c := e.add(ch, &"party", Vector2i(2, 3))
	var target := TestCombat.punching_bag(e, Vector2i(3, 3), 500)
	TestCombat.start_with(e, c)
	var opts := {"spell_sequence": "improved_mystic_fighting_style"}
	var focus := ch.resource_left("focus_points")
	var slots := ch.slots_left(1)
	var high_slots := ch.slots_left(3)
	assert_false(e.spells.cast(c, "magic_missile", 3, [target], Vector2.INF, Vector2.ZERO, opts).ok, "upcast spells take the higher level for that casting")
	assert_eq(ch.slots_left(3), high_slots)
	assert_false(e.spells.cast(c, "fireball", 3, [], Vector2(3.5, 3.5), Vector2.ZERO, opts).ok)
	assert_false(e.spells.cast(c, "fire_bolt", 0, [target], Vector2.INF, Vector2.ZERO, opts).ok)
	assert_false(e.spells.cast(c, "magic_missile", 1, [], Vector2.INF, Vector2.ZERO, opts).ok)
	assert_eq(ch.resource_left("focus_points"), focus)
	assert_eq(ch.slots_left(1), slots)
	assert_true(c.bonus_available)
	assert_false(c.has_meta("sequence_attacks"))
	ch.spend_resource("focus_points", focus)
	assert_false(e.spells.cast(c, "magic_missile", 1, [target], Vector2.INF, Vector2.ZERO, opts).ok)
	assert_true(c.bonus_available)


func test_focused_strike_reaches_casting_and_repeated_spell_save_paths() -> void:
	var e := TestCombat.open_field()
	var ch := mystic(11)
	(ch.spellcasting[0]["prepared"] as Array).append("hold_person")
	var c := e.add(ch, &"party", Vector2i(2, 3))
	var target := TestCombat.punching_bag(e, Vector2i(3, 3), 500)
	target.creature.add_effect(Effect.new("Fail the save").with_modifier("save", {"ability": "wis", "value": -100}))
	TestCombat.start_with(e, c)
	e.feature_recipes.on_feature_target(c, target, "stunning_strike")
	var observed: Array[bool] = []
	target.creature.d20_after = func(_creature: Creature, test: D20Test, keys: Array[String]) -> void:
		if "save_vs:spell" in keys:
			observed.append(test.disadvantage)
	assert_true(e.spells.cast(c, "hold_person", 2, [target]).ok)
	assert_eq(observed, [true])
	assert_true(target.creature.has_condition(&"paralyzed"))
	var hold: Effect = null
	for fx in target.creature.effects:
		if fx.source_id == "hold_person":
			hold = fx
	assert_true(hold != null)
	if hold == null:return
	e.spells._repeat_save(target, hold, [])
	assert_eq(observed, [true, true])
	target.creature.on_turn_start(c.id)
	e.spells._repeat_save(target, hold, [])
	assert_eq(observed, [true, true, false])

func test_slot_exchange_can_restore_spent_pact_slots_without_creating_extra_slots() -> void:
	var ch := mystic(7)
	ch.spellcasting.append({"progression": "pact", "pact_slots": 2, "pact_level": 2})
	ch.pact_slots_used = 1
	ch.open_slot_recovery("uncanny_metabolism")
	assert_true(ch.recover_slot_with_resource("mystic_focus", 2))
	assert_eq(ch.pact_slots_used, 0)
	assert_eq(ch.resource_left("focus_points"), 4)
	ch.open_slot_recovery("uncanny_metabolism")
	assert_false(ch.recover_slot_with_resource("mystic_focus", 2), "only an expended slot can be recovered")


func test_focused_strike_applies_to_command_and_sleep_special_save_paths() -> void:
	for spell: String in ["command", "sleep"]:
		var e := TestCombat.open_field()
		var ch := mystic(11)
		(ch.spellcasting[0]["prepared"] as Array).append(spell)
		var c := e.add(ch, &"party", Vector2i(2, 3))
		var target := TestCombat.punching_bag(e, Vector2i(5, 3), 500)
		target.creature.add_effect(Effect.new("Fail the save").with_modifier("save", {"ability": "wis", "value": -100}))
		TestCombat.start_with(e, c)
		e.feature_recipes.on_feature_target(c, target, "stunning_strike")
		var observed: Array[bool] = []
		target.creature.d20_after = func(_creature: Creature, test: D20Test, keys: Array[String]) -> void:
			if "save_vs:spell" in keys:
				observed.append(test.disadvantage)
		assert_true(e.spells.cast(c, spell, 1, [target] if spell == "command" else [], Vector2(5.5, 3.5)).ok)
		assert_eq(observed, [true], spell)


func test_multiclass_spell_duplicates_use_the_eligible_casting_source() -> void:
	var e := TestCombat.open_field()
	var ch := mystic(17)
	(ch.spellcasting[0]["prepared"] as Array).append("magic_missile")
	var wizard := (ch.spellcasting[0] as Dictionary).duplicate(true)
	wizard["class_id"] = "wizard"
	wizard["ability"] = "int"
	wizard["name"] = "Wizard"
	ch.spellcasting.push_front(wizard)
	var c := e.add(ch, &"party", Vector2i(2, 3))
	c.reaction_rules["heroic_inspiration"] = "never"
	var target := TestCombat.punching_bag(e, Vector2i(3, 3), 500)
	TestCombat.start_with(e, c)
	var initial := e.spells._entry(c, "fire_bolt")
	assert_eq(initial["class_id"], "wizard")
	var eligible := e.triggered_features.attack_cantrip_entry(c, Compendium.shared().spell_data("fire_bolt"), initial)
	assert_eq(eligible["class_id"], "monk")
	assert_eq(e.spells.numbers(c, eligible)["ability"], &"wis")
	assert_true(e.spells.cast(c, "fire_bolt", 0, [target], Vector2.INF, Vector2.ZERO, {"war_magic": true}).ok)
	var sequence := e.triggered_features.spell_sequences(c, Compendium.shared().spell_data("magic_missile"), e.spells._entry(c, "magic_missile"))
	assert_eq(sequence.size(), 1)
	assert_true(e.spells.cast(c, "magic_missile", 1, [target], Vector2.INF, Vector2.ZERO, {"spell_sequence": "improved_mystic_fighting_style"}).ok)


func test_flurry_spell_rejects_high_slots_when_lower_slots_are_exhausted() -> void:
	var e := TestCombat.open_field()
	var ch := mystic(17)
	(ch.spellcasting[0]["prepared"] as Array).append("magic_missile")
	for level: int in [1, 2]:
		while ch.slots_left(level) > 0:
			ch.expend_slot(level)
	var c := e.add(ch, &"party", Vector2i(2, 3))
	TestCombat.punching_bag(e, Vector2i(3, 3), 500)
	TestCombat.start_with(e, c)
	var catalog := ActionCatalog.new(e)
	var action := catalog.find(c, "spell:magic_missile:improved_mystic_fighting_style")
	assert_false(bool(action["legal"]))
	assert_true(catalog.level_choices(c, action).is_empty())
	assert_true(ch.slots_left(3) > 0)
