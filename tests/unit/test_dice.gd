extends TestCase
## The seeded, logged dice service (ADR 0002).


func test_same_seed_same_rolls() -> void:
	var a := DiceRoller.new(1234)
	var b := DiceRoller.new(1234)
	for i in 50:
		assert_eq(a.d20(), b.d20())


func test_rolls_stay_in_range() -> void:
	var d := DiceRoller.new(7)
	for sides: int in [4, 6, 8, 10, 12, 20, 100]:
		for i in 200:
			var r := d.roll_one(sides)
			assert_true(r >= 1 and r <= sides, "d%d rolled %d" % [sides, r])


func test_every_roll_is_logged() -> void:
	var d := DiceRoller.new(1)
	d.roll(6, 3, "fireball")
	d.d20("attack")
	assert_eq(d.log.size(), 2)
	assert_eq(d.log[0]["reason"], "fireball")
	assert_eq((d.log[0]["rolls"] as Array).size(), 3)


func test_parse_expressions() -> void:
	assert_eq(DiceRoller.parse_expr("2d6+3"), {"count": 2, "sides": 6, "modifier": 3})
	assert_eq(DiceRoller.parse_expr("d20"), {"count": 1, "sides": 20, "modifier": 0})
	assert_eq(DiceRoller.parse_expr("1d8 - 1"), {"count": 1, "sides": 8, "modifier": -1})
	assert_eq(DiceRoller.parse_expr("4"), {"count": 0, "sides": 0, "modifier": 4})


func test_roll_expr_total() -> void:
	var d := DiceRoller.new(99)
	var r := d.roll_expr("3d6+2")
	var sum := 2
	for x: int in r["rolls"]:
		sum += x
	assert_eq(r["total"], sum)
	assert_between(float(r["total"]), 5, 20)


func test_state_round_trip_continues_sequence() -> void:
	var d := DiceRoller.new(42)
	for i in 10:
		d.d20()
	var saved := d.get_state()
	var expected: Array[int] = []
	for i in 10:
		expected.append(d.d20())
	var restored := DiceRoller.new(0)
	restored.set_state(saved)
	for i in 10:
		assert_eq(restored.d20(), expected[i], "roll %d after restore" % i)
