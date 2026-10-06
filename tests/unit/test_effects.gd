extends TestCase
## Effects (plan §4.3): modifiers with a source and a duration, stacking rules and Concentration.


func _bless() -> Effect:
	var spell := Compendium.shared().spell_data("bless")
	var e := Effect.new("Bless", &"spell", "bless")
	for fx: Variant in spell["effects"]:
		for md: Variant in ((fx as Dictionary)["params"] as Dictionary)["modifiers"]:
			e.modifiers.append(Modifier.make(md as Dictionary, "Bless", &"spell", "bless"))
	return e.lasting(spell["duration"] as Dictionary)


func test_bless_adds_a_d4_to_attacks_and_saves_from_its_data() -> void:
	var c := TestChars.dummy(20)
	c.add_effect(_bless())
	var t := c.roll_save(DiceRoller.new(11), &"wis", 10)
	assert_between(t.extra, 1, 4, "Bless die")
	assert_true(t.extra_label.contains("Bless"))
	assert_eq(t.total, t.kept + t.modifier + t.extra)
	var check := c.roll_check(DiceRoller.new(11), &"perception", 10)
	assert_eq(check.extra, 0, "Bless doesn't touch ability checks")


func test_same_effect_from_two_casters_does_not_stack() -> void:
	var c := TestChars.dummy(20)
	var a := _bless()
	a.caster_id = "cleric_a"
	var b := _bless()
	b.caster_id = "cleric_b"
	c.add_effect(a)
	c.add_effect(b)
	assert_eq(c.modifiers_for(&"bonus_die").size(), 1)
	c.remove_effect(b)
	assert_eq(c.modifiers_for(&"bonus_die").size(), 1, "the other Bless still applies")


func test_shield_of_faith_and_concentration_switch() -> void:
	var cleric := TestChars.pregen("hedda_ironvow")
	var ally := TestChars.pregen("ilse_varga")
	var conc := cleric.begin_concentration("shield_of_faith", "Shield of Faith")
	conc.attach(ally, Effect.new("Shield of Faith", &"spell", "shield_of_faith").with_modifier("ac", {"value": 2}))
	assert_eq(ally.ac_value(), 19)
	assert_true(ally.armor_class().describe().contains("Shield of Faith 2"))
	var conc2 := cleric.begin_concentration("bless", "Bless")
	conc2.attach(ally, _bless())
	assert_eq(ally.ac_value(), 17, "starting a new Concentration ends Shield of Faith")
	assert_eq(ally.modifiers_for(&"bonus_die").size(), 1)


func test_failed_concentration_save_ends_the_spell() -> void:
	var caster := TestChars.dummy(80, false, {"con": 1})
	var target := TestChars.dummy(20)
	caster.begin_concentration("bless", "Bless").attach(target, _bless())
	var r := caster.take_damage(60, &"fire", false, DiceRoller.new(5))
	assert_eq(r.concentration_dc, 30)
	assert_true(r.concentration_broken, "Con save -5 can't reach DC 30")
	assert_eq(target.effects.size(), 0)


func test_round_durations() -> void:
	var c := TestChars.dummy(20)
	var e := Effect.new("Test").with_modifier("ac", {"value": 1}).lasting_rounds(2, "caster")
	c.add_effect(e)
	c.on_turn_start("someone_else")
	assert_eq(c.effects.size(), 1)
	c.on_turn_start("caster")
	assert_eq(c.effects.size(), 1, "one round left")
	c.on_turn_start("caster")
	assert_eq(c.effects.size(), 0, "ended at the start of the caster's second turn")


func test_until_start_of_next_turn() -> void:
	var c := TestChars.dummy(20)
	var shield := Effect.new("Shield", &"spell", "shield").with_modifier("ac", {"value": 5})
	shield.ends = Effect.Ends.START_OF_TURN
	shield.caster_id = c.id
	c.add_effect(shield)
	assert_eq(c.ac_value(), 17)
	c.on_turn_start(c.id)
	assert_eq(c.ac_value(), 12)


func test_minutes_and_hours_in_exploration() -> void:
	var c := TestChars.dummy(20)
	var spell := Compendium.shared().spell_data("mage_armor")
	var e := Effect.new("Mage Armor", &"spell", "mage_armor").lasting(spell["duration"] as Dictionary)
	c.add_effect(e)
	c.advance_minutes(60 * 7)
	assert_eq(c.effects.size(), 1)
	c.advance_minutes(61)
	assert_eq(c.effects.size(), 0, "8 hours is up")


func test_rest_durations() -> void:
	var c := TestChars.dummy(20)
	var e := Effect.new("Until rest").with_modifier("ac", {"value": 1})
	e.ends = Effect.Ends.SHORT_REST
	c.add_effect(e)
	c.finish_short_rest()
	assert_eq(c.effects.size(), 0)


func test_conditions_through_effects_respect_immunity() -> void:
	var zombie := Monster.from_data(Compendium.shared().monster_data("zombie"))
	var e := Effect.new("Ray of Sickness").with_condition(&"poisoned")
	assert_false(zombie.add_effect(e), "zombies are immune to Poisoned")
