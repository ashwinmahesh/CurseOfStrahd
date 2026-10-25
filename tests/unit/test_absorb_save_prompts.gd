extends TestCase
## Absorb Elements against a saving throw's damage (Ashwin, 2026-10-24: it must ask before it is spent, and also when the
## save is passed but the effect still deals damage): a stat block's save action (a breath) and a spell a foe casts (a
## Fireball) pause for the hero's answer before the damage lands. Only when nothing is left to deal is nobody asked.

## A d20 that comes out as the test says: the saves of the case (every other roll as ever).
class ScriptedDice extends DiceRoller:
	var d20s: Array[int] = []

	func roll(sides: int, count: int = 1, reason: String = "") -> Array[int]:
		if sides == 20 and count == 1 and not d20s.is_empty():
			var out: Array[int] = [d20s.pop_front() as int]
			_record({"reason": reason, "sides": sides, "rolls": out.duplicate()})
			return out
		return super.roll(sides, count, reason)


## A burst of exactly 20 `type` damage (2d1+18, or `plus` 4 for 6), Dexterity save against `dc`, `success` ("half" or "none") on a pass.
func _burst(dc: int, success: String = "half", type: String = "fire", plus: int = 18) -> Dictionary:
	return {"id": "flame_wave", "name": "Flame Wave", "kind": "save", "save": {"ability": "dex", "dc": dc, "success": success},
		"damage": [{"dice": "2d1+%d" % plus, "average": 2 + plus, "type": type}], "targets": {"range": 60}}


## Silvain (a wizard at `level` who knows Absorb Elements, rule `rule`) 15 ft from a dummy with `act`, on the dummy's turn:
## {e, c, foe}.
func _scene(act: Dictionary, rule: String = "ask", level: int = 9, d20s: Array[int] = []) -> Dictionary:
	var rows: Array[String] = []
	for z in 8:
		rows.append("............")
	var dice := ScriptedDice.new(7)
	dice.d20s.assign(d20s)
	var e := Encounter.new(CombatGrid.from_rows(rows), dice)
	var c := TestCombat.caster_with(e, ["absorb_elements"], Vector2i(2, 3), level)
	var foe := e.add(TestChars.dummy(500, false, {"ac": 1, "actions": [act]}), &"enemy", Vector2i(5, 3))
	e.shared_turns = false
	TestCombat.start_with(e, foe)
	c.reaction_rules["absorb_elements"] = rule
	c.reaction_rules["shield"] = "never"
	dice.d20s.assign(d20s)
	return {"e": e, "c": c, "foe": foe, "dice": dice}


func _use(sc: Dictionary, act: Dictionary) -> CombatResult:
	var e := sc["e"] as Encounter
	return e.monster_actions.save_action(sc["foe"] as Combatant, act, sc["c"] as Combatant, CombatResult.new(), true)


func _asked(e: Encounter) -> bool:
	return e.pending != null and e.pending.kind == "absorb_elements"


func _settle(e: Encounter) -> void:
	var guard := 0
	while e.pending != null and guard < 10:
		e.answer_reaction(false)
		guard += 1


func _resisting(c: Combatant) -> bool:
	return c.creature.resistance_source(&"fire") != ""


func test_a_failed_save_asks_before_the_blow_lands() -> void:
	var act := _burst(99)
	var sc := _scene(act)
	var e := sc["e"] as Encounter
	var c := sc["c"] as Combatant
	var hp := c.creature.hp
	var slots := (c.creature as Character).slots_left(1)
	var r := _use(sc, act)
	assert_true(r.is_paused(), "the blow waits for the hero's answer")
	assert_true(_asked(e), "an Absorb Elements prompt")
	assert_eq(e.pending.reactor_id, c.id)
	assert_true(e.pending.text.contains("20 Fire"), e.pending.text)
	assert_eq(c.creature.hp, hp, "nothing has landed yet")
	e.answer_reaction(true)
	assert_eq(c.creature.hp, hp - 10, "20 Fire halved by the Resistance that came first")
	assert_true(_resisting(c))
	assert_false(c.reaction_available, "the Reaction is spent")
	assert_eq((c.creature as Character).slots_left(1), slots - 1, "and a level 1 slot")
	_settle(e)


func test_declining_takes_the_whole_blow_and_keeps_the_reaction() -> void:
	var act := _burst(99)
	var sc := _scene(act)
	var e := sc["e"] as Encounter
	var c := sc["c"] as Combatant
	var hp := c.creature.hp
	assert_true(_use(sc, act).is_paused())
	e.answer_reaction(false)
	assert_eq(c.creature.hp, hp - 20)
	assert_true(c.reaction_available, "declining keeps the Reaction")
	assert_false(_resisting(c))
	assert_true(e.pending == null, "and nothing asks twice")


func test_a_passed_save_that_still_hurts_asks_too() -> void:
	var act := _burst(0, "half")
	var sc := _scene(act)
	var e := sc["e"] as Encounter
	var c := sc["c"] as Combatant
	var hp := c.creature.hp
	assert_true(_use(sc, act).is_paused(), "half of 20 is still damage")
	assert_true(_asked(e))
	assert_true(e.pending.text.contains("10 Fire"), "it names what is left to take: %s" % e.pending.text)
	e.answer_reaction(true)
	assert_eq(c.creature.hp, hp - 5, "the half, halved again")
	_settle(e)


func test_a_passed_save_that_leaves_no_damage_asks_nothing() -> void:
	var act := _burst(0, "none")
	var sc := _scene(act)
	var e := sc["e"] as Encounter
	var c := sc["c"] as Combatant
	var hp := c.creature.hp
	var r := _use(sc, act)
	assert_false(r.is_paused(), "nothing to answer")
	assert_eq(c.creature.hp, hp)
	assert_true(c.reaction_available)


func test_damage_of_another_type_is_not_asked_about() -> void:
	var act := _burst(99, "half", "necrotic")
	var sc := _scene(act)
	var e := sc["e"] as Encounter
	var c := sc["c"] as Combatant
	var hp := c.creature.hp
	assert_false(_use(sc, act).is_paused())
	assert_eq(c.creature.hp, hp - 20)


func test_off_asks_nothing_and_ask_never_fires_by_itself() -> void:
	var act := _burst(99)
	var off := _scene(act, "never")
	assert_false(_use(off, act).is_paused(), "Off")
	assert_true((off["c"] as Combatant).reaction_available)
	# With several ways to cast it, even Automatic asks.
	var auto := _scene(act, "auto", 9)
	assert_true(_use(auto, act).is_paused(), "Automatic still asks when there are several slot levels")
	_settle(auto["e"] as Encounter)


func test_automatic_with_one_way_to_cast_answers_without_asking() -> void:
	var act := _burst(99, "half", "fire", 4)   # 6 Fire: a level 1 wizard has Hit Points to spare for that
	var sc := _scene(act, "auto", 1)   # a level 1 wizard has one slot level: nothing to choose
	var e := sc["e"] as Encounter
	var c := sc["c"] as Combatant
	var hp := c.creature.hp
	var r := _use(sc, act)
	assert_false(r.is_paused(), "Automatic with one way to pay")
	assert_eq(c.creature.hp, hp - 3)
	assert_false(c.reaction_available)


## A foe's Fireball takes the same prompt before the blow, and the Resistance halves that blow.
func test_a_foes_fireball_asks_and_the_resistance_halves_its_damage() -> void:
	var lost := {}
	for answer: bool in [false, true]:
		var rows: Array[String] = []
		for z in 8:
			rows.append("............")
		var dice := ScriptedDice.new(11)
		var e := Encounter.new(CombatGrid.from_rows(rows), dice)
		var c := TestCombat.caster_with(e, ["absorb_elements"], Vector2i(2, 3), 9)
		var mage := TestCombat.foe(e, "mage", Vector2i(8, 3))
		mage.creature.hp = 200
		TestCombat.start_with(e, mage)
		c.reaction_rules["counterspell"] = "never"
		c.reaction_rules["shield"] = "never"
		c.reaction_rules["absorb_elements"] = "ask"
		dice.d20s.assign([1])   # the hero's Dexterity save
		var hp := c.creature.hp
		var r := e.monster_actions.cast(mage, "fireball", [], Vector2(c.cell) + Vector2(0.5, 0.5))
		assert_true(r.is_paused() and _asked(e), "the Fireball waits for the answer")
		e.answer_reaction(answer)
		_settle(e)
		lost[answer] = hp - c.creature.hp
	assert_true(int(lost[false]) > 0, "the Fireball hurt")
	assert_eq(int(lost[true]), int(lost[false]) / 2, "Resistance halves the same blow")
