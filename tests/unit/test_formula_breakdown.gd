extends TestCase
## Formula values used by data (docs/contracts/modifiers.md) and Breakdown explanations (plan §5.6).


func test_formulas() -> void:
	var ctx := {"pb": 3, "level": 5, "class_level": 4, "slot_level": 2, "exhaustion": 2, "mod:int": 4, "mod:wis": -1, "score:str": 17}
	assert_eq(Formula.evaluate(7, ctx), 7)
	assert_eq(Formula.evaluate("pb", ctx), 3)
	assert_eq(Formula.evaluate("2*level", ctx), 10, "Tough")
	assert_eq(Formula.evaluate("2*class_level+mod:int", ctx), 12, "Arcane Ward")
	assert_eq(Formula.evaluate("level/2", ctx), 2, "rounds down")
	assert_eq(Formula.evaluate("-2*exhaustion", ctx), -4, "Exhaustion penalty")
	assert_eq(Formula.evaluate("2+slot_level", ctx), 4, "Disciple of Life")
	assert_eq(Formula.evaluate("mod:wis", ctx), -1)
	assert_eq(Formula.evaluate("score:str-10", ctx), 7)


func test_modifier_minimum() -> void:
	var m := Modifier.make({"stat": "check", "skill": "arcana", "value": "mod:wis", "min": 1}, "Thaumaturge")
	assert_eq(m.value_on({"mod:wis": -1}), 1, "minimum +1")
	assert_eq(m.value_on({"mod:wis": 3}), 3)


func test_breakdown_describes_parts() -> void:
	var b := Breakdown.new("AC")
	b.add("Chain Mail", 16).add("Defense", 1)
	assert_eq(b.total(), 17)
	assert_eq(b.describe(), "AC 17 = Chain Mail 16 + Defense 1")
	b.add("Cursed ring", -2)
	assert_eq(b.describe(), "AC 15 = Chain Mail 16 + Defense 1 - Cursed ring 2")


func test_breakdown_floor_and_override() -> void:
	var b := Breakdown.new("AC")
	b.add("Unarmored", 10).add("Dex modifier", 1)
	b.set_floor(17, "Barkskin")
	assert_eq(b.total(), 17)
	assert_true(b.describe().contains("raised to 17 by Barkskin"))
	var s := Breakdown.new("Speed")
	s.add("Base", 30)
	s.set_override(0, "Grappled")
	assert_eq(s.total(), 0)
	assert_eq(s.describe(), "Speed 0 (Grappled)")


func test_when_filters() -> void:
	var defense := Modifier.make({"stat": "ac", "value": 1, "when": {"armor": "any"}}, "Defense")
	assert_true(defense.applies_when({"armor": "heavy"}))
	assert_false(defense.applies_when({"armor": "none"}), "no armor, no Defense")
	var archery := Modifier.make({"stat": "attack", "value": 2, "when": {"weapon": "ranged"}}, "Archery")
	assert_true(archery.applies_when({"weapon_tags": ["ranged"]}))
	assert_false(archery.applies_when({"weapon_tags": ["melee"]}))
	assert_false(archery.applies_when({}), "unknown situation: doesn't leak into generic numbers")
