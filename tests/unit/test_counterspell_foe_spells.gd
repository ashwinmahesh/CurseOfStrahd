extends TestCase
## Counterspell against a foe's own spells (Ashwin, 2026-10-24: "Strahd cast Fireball and the player was not offered
## Counterspell"; docs/rules/deviations.md used to say heroes never counter a foe's casting): a hero who sees a foe cast a
## levelled spell within 60 ft, with a Reaction and Counterspell and a slot (or a free casting) for it, is asked on the
## usual Reaction prompt, whoever the foe is (a stat block's Spellcasting: Baba Lysaga, Strahd, a mage), and the chain that
## follows (the foes' answers to that Counterspell) works as it does for a hero's own spells.


## A d20 that comes out as the test says: the saves of a chain (every other roll as ever).
class ScriptedDice extends DiceRoller:
	var d20s: Array[int] = []

	func roll(sides: int, count: int = 1, reason: String = "") -> Array[int]:
		if sides == 20 and count == 1 and not d20s.is_empty():
			var out: Array[int] = [d20s.pop_front() as int]
			_record({"reason": reason, "sides": sides, "rolls": out.duplicate()})
			return out
		return super.roll(sides, count, reason)


## A mage (f1: Fireball 2 a day, Protective Magic) on its turn 30 ft from Ratatouille (h, a wizard at `level` with
## Counterspell): {e, dice, h, f1, f2}. f2, a second mage, is there only when `second`. `d20s` are the saves the cast will roll.
func _field(d20s: Array[int], level: int = 9, second: bool = false, mage_cell: Vector2i = Vector2i(8, 3)) -> Dictionary:
	var rows: Array[String] = []
	for z in 8:
		rows.append("................")
	var dice := ScriptedDice.new(7)
	var e := Encounter.new(CombatGrid.from_rows(rows), dice)
	var h := TestCombat.caster_with(e, ["counterspell"], Vector2i(2, 3), level, "ratatoille")
	var f1 := TestCombat.foe(e, "mage", mage_cell)
	f1.creature.hp = 200
	var f2: Combatant = null
	if second:
		f2 = TestCombat.foe(e, "mage", Vector2i(8, 5))
		f2.creature.hp = 200
	TestCombat.start_with(e, f1)
	while e.pending != null:
		e.answer_reaction(false)
	f1.reaction_available = false   # the caster could Counterspell the hero's Counterspell; these cases leave that to f2
	dice.d20s.assign(d20s)
	return {"e": e, "dice": dice, "h": h, "f1": f1, "f2": f2}


func _fireball(f: Dictionary) -> CombatResult:
	var h := f["h"] as Combatant
	return (f["e"] as Encounter).monster_actions.cast(f["f1"] as Combatant, "fireball", [], Vector2(h.cell) + Vector2(0.5, 0.5))


func _logged(e: Encounter, part: String) -> bool:
	return e.log.texts().any(func(t: String) -> bool: return t.contains(part))


## Answers whatever prompt is still open (no: a prompt left open leaks at exit).
func _settle(e: Encounter) -> void:
	var guard := 0
	while e.pending != null and guard < 10:
		e.answer_reaction(false)
		guard += 1


func test_a_hero_who_could_counter_a_foes_fireball_is_asked() -> void:
	var f := _field([1])
	var e := f["e"] as Encounter
	var h := f["h"] as Combatant
	var r := _fireball(f)
	assert_true(r.is_paused(), "the cast waits for the hero's answer")
	var req := e.pending
	assert_true(req != null and req.kind == "counterspell", "a Counterspell prompt")
	assert_eq(req.reactor_id, h.id)
	assert_eq(req.title, "Reaction: Counterspell?")
	assert_true(req.text.contains("Mage") and req.text.contains("Fireball"), "naming the caster and the spell: %s" % req.text)
	assert_true(req.text.contains("Constitution save") and req.text.contains("DC") and req.text.contains("to fail"), "and the odds: %s" % req.text)
	assert_eq(h.creature.hp, h.creature.max_hp(), "nothing has burned yet")
	_settle(e)


func test_the_counterspell_stops_the_fireball_when_the_mage_fails_its_save() -> void:
	var f := _field([1])
	var e := f["e"] as Encounter
	var h := f["h"] as Combatant
	var f1 := f["f1"] as Combatant
	var slots := (h.creature as Character).slots_left(3)
	assert_true(_fireball(f).is_paused())
	var r := e.answer_reaction(true)
	assert_false(r.is_paused(), "nothing more to ask")
	assert_false(h.reaction_available, "the hero's Reaction is spent")
	assert_eq((h.creature as Character).slots_left(3), slots - 1, "and a level 3 slot, as the Counterspell stood")
	assert_eq(h.creature.hp, h.creature.max_hp(), "the Fireball never went off")
	assert_true(_logged(e, "Ratatouille casts Counterspell at Mage"), "the log names the Counterspell")
	assert_true(_logged(e, "Mage's Fireball dissipates (Counterspell)"), "and what it stopped")
	assert_false(f1.action_available, "the mage's action is spent")


func test_the_fireball_goes_ahead_when_the_mage_saves() -> void:
	var f := _field([20])
	var e := f["e"] as Encounter
	var h := f["h"] as Combatant
	assert_true(_fireball(f).is_paused())
	e.answer_reaction(true)
	assert_true(_logged(e, "Mage's Fireball gets through the Counterspell"), "\n".join(e.log.texts().slice(-6)))
	assert_true(h.creature.hp < h.creature.max_hp() or _logged(e, "saves against Fireball"), "the Fireball resolved")
	_settle(e)


func test_declining_keeps_the_reaction_and_the_fireball_goes_off() -> void:
	var f := _field([1])
	var e := f["e"] as Encounter
	var h := f["h"] as Combatant
	var slots := (h.creature as Character).slots_left(3)
	assert_true(_fireball(f).is_paused())
	e.answer_reaction(false)
	assert_true(h.reaction_available, "declining keeps the Reaction")
	assert_eq((h.creature as Character).slots_left(3), slots, "and the slot")
	assert_false(_logged(e, "Ratatouille casts Counterspell"))
	assert_true(_logged(e, "Mage casts Fireball"), "the spell went ahead")
	_settle(e)


func test_a_hero_with_counterspell_off_is_not_asked() -> void:
	var f := _field([1])
	var e := f["e"] as Encounter
	(f["h"] as Combatant).reaction_rules["counterspell"] = "never"
	var r := _fireball(f)
	assert_false(r.is_paused(), "nothing to ask")
	assert_true(_logged(e, "Mage casts Fireball"))
	_settle(e)


func test_automatic_counters_without_asking_when_there_is_one_way_to_pay() -> void:
	var f := _field([1], 5)   # a level 5 wizard has no slot above level 3, no free casting: one way to pay
	var e := f["e"] as Encounter
	var h := f["h"] as Combatant
	h.reaction_rules["counterspell"] = "auto"
	var r := _fireball(f)
	assert_false(r.is_paused(), "Automatic: no prompt")
	assert_true(_logged(e, "Ratatouille casts Counterspell at Mage"))
	assert_true(_logged(e, "Mage's Fireball dissipates (Counterspell)"))
	_settle(e)


func test_nobody_is_asked_who_cannot_counter() -> void:
	# Too far (over 60 ft), with no Reaction, or with no slot of level 3 or more.
	var far := _field([1], 9, false, Vector2i(15, 3))
	assert_false(_fireball(far).is_paused(), "75 ft away")
	_settle(far["e"] as Encounter)
	var spent := _field([1])
	(spent["h"] as Combatant).reaction_available = false
	assert_false(_fireball(spent).is_paused(), "no Reaction")
	_settle(spent["e"] as Encounter)
	var dry := _field([1])
	var ch := (dry["h"] as Combatant).creature as Character
	for l in range(3, 10):
		ch.slots_used[l - 1] = ch.spell_slots()[l - 1]
	assert_false(_fireball(dry).is_paused(), "no slot")
	_settle(dry["e"] as Encounter)


func test_a_cantrip_is_let_through() -> void:
	var f := _field([1])
	var e := f["e"] as Encounter
	var r := e.monster_actions.cast(f["f1"] as Combatant, "mage_hand", [], Vector2(f["h"].cell) + Vector2(0.5, 0.5))
	assert_false(r.is_paused(), "a cantrip is not Counterspelled")
	_settle(e)


func test_a_second_mage_can_counter_the_heros_counterspell() -> void:
	# H counters the Fireball, the second mage answers with its own Counterspell: the chain resolves from the last back.
	var f := _field([1, 20], 9, true)
	var e := f["e"] as Encounter
	var h := f["h"] as Combatant
	assert_true(_fireball(f).is_paused())
	var r := e.answer_reaction(true)
	assert_false(r.is_paused())
	assert_true(_logged(e, "Mage casts Counterspell at Ratatouille"), "the second mage answered: %s" % "\n".join(e.log.texts().slice(-8)))
	assert_false(h.reaction_available)
	_settle(e)
