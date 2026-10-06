extends TestCase
## The 15 conditions of the 2024 Rules Glossary (data/conditions) and how they reach rolls.


func test_all_fifteen_conditions_are_data() -> void:
	assert_eq(Compendium.shared().table("conditions").size(), 15)


func test_paralyzed_fails_strength_and_dexterity_saves() -> void:
	var c := TestChars.dummy(20)
	c.add_condition(&"paralyzed", "Hold Person")
	assert_true(c.has_condition(&"incapacitated"))
	var dex := c.roll_save(DiceRoller.new(1), &"dex", 5)
	assert_true(dex.auto_failed)
	assert_true(dex.describe().contains("automatic failure"))
	var con := c.roll_save(DiceRoller.new(1), &"con", 5)
	assert_false(con.auto_failed)
	assert_eq(c.speed().total(), 0)


func test_poisoned_gives_disadvantage_on_attacks_and_checks() -> void:
	var c := TestChars.dummy(20)
	c.add_condition(&"poisoned")
	assert_false((c.d20_sources(["attack"])["disadvantage"] as Array).is_empty())
	assert_false((c.d20_sources(c.check_keys(&"stealth"))["disadvantage"] as Array).is_empty())
	assert_true((c.d20_sources(c.save_keys(&"con"))["disadvantage"] as Array).is_empty(), "saves unaffected")
	var t := c.roll_check(DiceRoller.new(3), &"stealth", 10)
	assert_true(t.disadvantage)
	assert_eq(t.disadvantage_sources, ["Poisoned"] as Array[String])


func test_restrained_and_grappled_speed_zero() -> void:
	var c := TestChars.dummy(20)
	c.add_condition(&"grappled", "Wolf")
	assert_eq(c.speed().total(), 0)
	assert_true(c.speed().describe().contains("Grappled"))
	c.remove_condition(&"grappled")
	assert_eq(c.speed().total(), 30)
	c.add_condition(&"restrained")
	assert_false((c.d20_sources(c.save_keys(&"dex"))["disadvantage"] as Array).is_empty())


func test_exhaustion_levels() -> void:
	var c := TestChars.dummy(20)
	c.add_exhaustion(2)
	assert_eq(c.skill_bonus(&"stealth").total(), -4, "D20 Tests -2 per level")
	assert_eq(c.save_bonus(&"wis").total(), -4)
	assert_eq(c.speed().total(), 20, "Speed -5 per level")
	c.finish_long_rest()
	assert_eq(c.exhaustion, 1, "a Long Rest removes one level")
	c.add_exhaustion(5)
	assert_true(c.dead, "level 6 is death")


func test_condition_immunity() -> void:
	var c := TestChars.dummy(20)
	c.base_condition_immunities.append("poisoned")
	assert_false(c.add_condition(&"poisoned"))
	assert_false(c.has_condition(&"poisoned"))


func test_petrified_resists_all_damage() -> void:
	var c := TestChars.dummy(40)
	c.add_condition(&"petrified")
	assert_eq(c.take_damage(10, &"fire").final, 5)
	assert_false(c.add_condition(&"poisoned"), "Petrified grants Poisoned immunity")


func test_incapacitated_breaks_concentration() -> void:
	var caster := TestChars.dummy(20)
	var target := TestChars.dummy(20)
	var conc := caster.begin_concentration("bless", "Bless")
	conc.attach(target, Effect.new("Bless").with_modifier("bonus_die", {"dice": "1d4", "on": ["attack", "save:all"]}))
	assert_eq(target.effects.size(), 1)
	caster.add_condition(&"stunned")
	assert_true(caster.concentration == null)
	assert_eq(target.effects.size(), 0, "Bless ends on its targets")


func test_invisible_rolls_initiative_with_advantage() -> void:
	var c := TestChars.dummy(20)
	c.add_condition(&"invisible")
	var t := c.roll_initiative(DiceRoller.new(9))
	assert_true(t.advantage)


func test_species_advantage_against_conditions() -> void:
	var hedda := TestChars.pregen("hedda_ironvow")
	var keys := hedda.save_keys(&"con")
	keys.append("save_vs:poisoned")
	assert_eq(hedda.d20_sources(keys)["advantage"], ["Dwarven Resilience"])
