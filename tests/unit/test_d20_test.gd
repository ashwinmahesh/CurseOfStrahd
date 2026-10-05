extends TestCase
## 2024 PHB rules glossary: D20 Test, Advantage, Disadvantage, Critical Hit.


func test_meeting_dc_succeeds() -> void:
	var t := D20Test.from_natural(D20Test.Kind.ABILITY_CHECK, 12, 3, 15)
	assert_eq(t.total, 15)
	assert_true(t.success, "15 vs DC 15 succeeds")
	assert_false(D20Test.from_natural(D20Test.Kind.ABILITY_CHECK, 11, 3, 15).success)


func test_natural_20_on_check_is_not_automatic() -> void:
	var t := D20Test.from_natural(D20Test.Kind.ABILITY_CHECK, 20, -1, 25)
	assert_false(t.success, "checks have no automatic success in 2024 rules")
	assert_false(t.critical)


func test_natural_1_on_save_is_not_automatic() -> void:
	var t := D20Test.from_natural(D20Test.Kind.SAVING_THROW, 1, 9, 10)
	assert_true(t.success, "1 + 9 = 10 meets DC 10")


func test_natural_20_attack_always_hits_and_crits() -> void:
	var t := D20Test.from_natural(D20Test.Kind.ATTACK_ROLL, 20, 0, 30)
	assert_true(t.success)
	assert_true(t.critical)


func test_natural_1_attack_always_misses() -> void:
	var t := D20Test.from_natural(D20Test.Kind.ATTACK_ROLL, 1, 15, 10)
	assert_false(t.success)
	assert_true(t.natural_one)


func test_advantage_keeps_higher() -> void:
	var d := DiceRoller.new(5)
	for i in 100:
		var t := D20Test.roll(d, D20Test.Kind.ABILITY_CHECK, 0, 10, 1, 0)
		assert_eq(t.rolls.size(), 2)
		assert_eq(t.kept, maxi(t.rolls[0], t.rolls[1]))


func test_disadvantage_keeps_lower() -> void:
	var d := DiceRoller.new(6)
	for i in 100:
		var t := D20Test.roll(d, D20Test.Kind.SAVING_THROW, 0, 10, 0, 2)
		assert_eq(t.kept, mini(t.rolls[0], t.rolls[1]))


func test_advantage_and_disadvantage_cancel_regardless_of_count() -> void:
	var d := DiceRoller.new(8)
	var t := D20Test.roll(d, D20Test.Kind.ATTACK_ROLL, 5, 15, 3, 1)
	assert_false(t.advantage)
	assert_false(t.disadvantage)
	assert_eq(t.rolls.size(), 1, "rolls one d20 when both apply")


func test_combat_log_text() -> void:
	var t := D20Test.from_natural(D20Test.Kind.ATTACK_ROLL, 14, 5, 16)
	assert_eq(t.describe(), "Attack: d20 14 + 5 = 19 vs AC 16, hit")


func test_advantage_raises_average() -> void:
	var d := DiceRoller.new(2024)
	var plain := 0
	var adv := 0
	for i in 2000:
		plain += D20Test.roll(d, D20Test.Kind.ABILITY_CHECK, 0, 10).kept
		adv += D20Test.roll(d, D20Test.Kind.ABILITY_CHECK, 0, 10, 1).kept
	# Expected means: 10.5 plain, 13.825 with advantage.
	assert_between(plain / 2000.0, 10.0, 11.0, "plain mean")
	assert_between(adv / 2000.0, 13.3, 14.3, "advantage mean")
