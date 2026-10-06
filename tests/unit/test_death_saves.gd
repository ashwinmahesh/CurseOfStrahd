extends TestCase
## 2024 PHB "Death Saving Throws" and "Stabilizing a Character".


func _downed() -> Monster:
	var c := TestChars.dummy(10, true)
	c.take_damage(10, &"slashing")
	return c


func test_natural_20_restores_one_hit_point() -> void:
	var c := _downed()
	var t := c.roll_death_save(DiceRoller.new(TestChars.seed_for_d20(20)))
	assert_eq(t.kept, 20)
	assert_eq(c.hp, 1)
	assert_false(c.has_condition(&"unconscious"))


func test_natural_1_is_two_failures() -> void:
	var c := _downed()
	c.roll_death_save(DiceRoller.new(TestChars.seed_for_d20(1)))
	assert_eq(c.death_failures, 2)


func test_ten_or_more_succeeds_and_three_successes_stabilize() -> void:
	var c := _downed()
	var s := TestChars.seed_for_d20(15)
	for i in 3:
		c.roll_death_save(DiceRoller.new(s))
	assert_true(c.stable)
	assert_eq(c.hp, 0)
	assert_true(c.has_condition(&"unconscious"), "Stable creatures stay Unconscious")
	assert_true(c.roll_death_save(DiceRoller.new(s)) == null, "Stable creatures don't roll")


func test_nine_fails_and_three_failures_kill() -> void:
	var c := _downed()
	var s := TestChars.seed_for_d20(9)
	for i in 3:
		c.roll_death_save(DiceRoller.new(s))
	assert_true(c.dead)


func test_damage_breaks_stability() -> void:
	var c := _downed()
	c.stabilize()
	c.take_damage(1, &"slashing")
	assert_false(c.stable)
	assert_eq(c.death_failures, 1)


func test_champion_survivor_gives_advantage() -> void:
	var c := _downed()
	c.effects.append(Effect.new("Survivor", &"feature").with_modifier("advantage", {"on": "death_save"}))
	var t := c.roll_death_save(DiceRoller.new(4))
	assert_eq(t.rolls.size(), 2, "rolled with Advantage")
