extends TestCase
## The Counterspell chain (2024 PHB, Counterspell; combat/spell_counters.gd): a foe's Counterspell at a hero's spell can be
## Counterspelled back by a hero who sees the foe, that one by another foe, and so on until no one answers. It resolves
## from the last Counterspell back: the creature each one targets makes a Constitution save against its caster's DC, and
## on a failure what it was casting dissipates. Each Counterspell spends its Reaction when cast, its slot only if it
## isn't countered itself.


## A d20 that comes out as the test says: the saves of a chain (every other roll as ever).
class ScriptedDice extends DiceRoller:
	var d20s: Array[int] = []

	func roll(sides: int, count: int = 1, reason: String = "") -> Array[int]:
		if sides == 20 and count == 1 and not d20s.is_empty():
			var out: Array[int] = [d20s.pop_front() as int]
			_record({"reason": reason, "sides": sides, "rolls": out.duplicate()})
			return out
		return super.roll(sides, count, reason)


## Silvain (h1, a level 9 wizard who casts Bless and answers nothing), Ratatouille (h2, who may Counterspell) and two mages
## (f1, f2: Protective Magic, three Counterspells a day), 30 ft apart, on h1's turn: {e, dice, h1, h2, f1, f2}. `d20s` are the
## saves the chain will roll, in order.
func _field(d20s: Array[int], h2_level: int = 9) -> Dictionary:
	var rows: Array[String] = []
	for z in 8:
		rows.append("............")
	var dice := ScriptedDice.new(7)
	var e := Encounter.new(CombatGrid.from_rows(rows), dice)
	var h1 := TestCombat.caster_with(e, ["bless", "counterspell"], Vector2i(2, 3), 9, "silvain_aster")
	var h2 := TestCombat.caster_with(e, ["counterspell"], Vector2i(2, 5), h2_level, "ratatoille")
	var f1 := TestCombat.foe(e, "mage", Vector2i(8, 3))
	var f2 := TestCombat.foe(e, "mage", Vector2i(8, 5))
	f1.creature.hp = 200
	f2.creature.hp = 200
	h1.reaction_rules["counterspell"] = "never"
	TestCombat.start_with(e, h1)
	while e.pending != null:
		e.answer_reaction(false)
	dice.d20s.assign(d20s)
	return {"e": e, "dice": dice, "h1": h1, "h2": h2, "f1": f1, "f2": f2}


func _logged(e: Encounter, part: String) -> bool:
	return e.log.texts().any(func(t: String) -> bool: return t.contains(part))


## Where in the log `part` first appears (-1 if never).
func _at(e: Encounter, part: String) -> int:
	var texts := e.log.texts()
	for i in texts.size():
		if texts[i].contains(part):
			return i
	return -1


## Answers whatever prompt is still open (no: a prompt left open leaks at exit).
func _settle(e: Encounter) -> void:
	var guard := 0
	while e.pending != null and guard < 10:
		e.answer_reaction(false)
		guard += 1


func _bless_held(f: Dictionary) -> bool:
	return (f["h1"] as Combatant).creature.concentration != null


func test_a_foes_counterspell_asks_the_hero_who_could_answer() -> void:
	var f := _field([1])
	var e := f["e"] as Encounter
	var h1 := f["h1"] as Combatant
	var r := e.spells.cast(h1, "bless", 1, [h1])
	assert_true(r.is_paused(), "the cast waits for the hero's answer")
	var req := e.pending
	assert_true(req != null and req.kind == "counterspell", "a Counterspell prompt")
	assert_eq(req.reactor_id, (f["h2"] as Combatant).id, "for the hero who can answer")
	assert_eq(req.title, "Reaction: Counterspell?")
	assert_true(req.text.contains("Constitution save") and req.text.contains("DC") and req.text.contains("to fail"), "with each side's save and its odds: %s" % req.text)
	assert_true(req.text.contains("Silvain") and req.text.contains("Bless"), "naming the spell it would stop: %s" % req.text)
	assert_false(h1.action_available, "the action is spent however it ends")
	_settle(e)


func test_declining_keeps_the_reaction_and_the_foes_counterspell_stands() -> void:
	var f := _field([1])
	var e := f["e"] as Encounter
	var h1 := f["h1"] as Combatant
	var h2 := f["h2"] as Combatant
	var slots := (h1.creature as Character).slots_left(1)
	assert_true(e.spells.cast(h1, "bless", 1, [h1]).is_paused())
	var r := e.answer_reaction(false)
	assert_false(r.is_paused(), "nothing more to ask")
	assert_true(h2.reaction_available, "declining keeps the Reaction")
	assert_false(_bless_held(f), "the Bless dissipated: the caster failed the save")
	assert_eq((h1.creature as Character).slots_left(1), slots, "its slot is kept")
	assert_true(_logged(e, "Bless dissipates (Counterspell)"))
	assert_false(_logged(e, "Ratatouille casts Counterspell"))


func test_a_hero_who_counters_back_and_the_foes_counterspell_fizzles() -> void:
	# H2's Counterspell stands (no one answers it) and F1 fails its save: the Bless goes ahead. Rolls: F1's save.
	var f := _field([1])
	var e := f["e"] as Encounter
	var h1 := f["h1"] as Combatant
	var h2 := f["h2"] as Combatant
	var f1 := f["f1"] as Combatant
	var f2 := f["f2"] as Combatant
	f2.reaction_available = false   # no one to answer the answer
	var slots := (h2.creature as Character).slots_left(3)
	assert_true(e.spells.cast(h1, "bless", 1, [h1]).is_paused())
	var r := e.answer_reaction(true)
	assert_false(r.is_paused())
	assert_false(h2.reaction_available, "its Reaction is spent")
	assert_eq((h2.creature as Character).slots_left(3), slots - 1, "and its slot too: its Counterspell stood")
	assert_true(_logged(e, "Ratatouille casts Counterspell at Mage"), "the log names the step")
	assert_true(_logged(e, "Mage's Counterspell fizzles (countered by Ratatouille)"))
	assert_true(_bless_held(f), "the Bless goes ahead")
	assert_true((f["dice"] as ScriptedDice).d20s.is_empty(), "one save was rolled")


func test_a_chain_of_three_heroes_against_foes_losing_every_step_back() -> void:
	# F1 counters H1's Bless, H2 counters F1, F2 counters H2. Saves, last to first: H2 fails (its Counterspell fizzles, its
	# slot kept), so F1's stands and H1 fails (the Bless dissipates).
	var f := _field([1, 1])
	var e := f["e"] as Encounter
	var h1 := f["h1"] as Combatant
	var h2 := f["h2"] as Combatant
	var f1 := f["f1"] as Combatant
	var f2 := f["f2"] as Combatant
	var slots := (h2.creature as Character).slots_left(3)
	var h1_slots := (h1.creature as Character).slots_left(1)
	assert_true(e.spells.cast(h1, "bless", 1, [h1]).is_paused())
	var r := e.answer_reaction(true)
	assert_false(r.is_paused(), "F2 answers at once and no hero is left to ask")
	assert_false(f1.reaction_available, "F1's Reaction is spent")
	assert_false(h2.reaction_available, "H2's")
	assert_false(f2.reaction_available, "F2's")
	assert_eq((h2.creature as Character).slots_left(3), slots, "H2's slot is kept: its Counterspell was countered")
	assert_eq((h1.creature as Character).slots_left(1), h1_slots, "H1's slot is kept: its spell dissipated")
	assert_false(_bless_held(f))
	var c1 := _at(e, "Mage casts Counterspell at Silvain")
	var c2 := _at(e, "Ratatouille casts Counterspell at Mage")
	var c3 := _at(e, "casts Counterspell at Ratatouille")
	assert_true(c1 >= 0 and c2 > c1 and c3 > c2, "cast in order: %s" % [e.log.texts()])
	var gone := _at(e, "Ratatouille's Counterspell fizzles")
	var bless := _at(e, "Bless dissipates (Counterspell)")
	assert_true(gone > c3 and bless > gone, "resolved last to first: %s" % [e.log.texts()])
	assert_true((f["dice"] as ScriptedDice).d20s.is_empty(), "two saves were rolled: H2's and H1's")


func test_a_chain_of_three_where_the_heroes_win_it() -> void:
	# H2 passes its save against F2 (its Counterspell stands, and its slot goes), F1 fails against it (F1's Counterspell
	# fizzles) and the Bless goes ahead without a save of H1's.
	var f := _field([20, 1])
	var e := f["e"] as Encounter
	var h1 := f["h1"] as Combatant
	var h2 := f["h2"] as Combatant
	var slots := (h2.creature as Character).slots_left(3)
	assert_true(e.spells.cast(h1, "bless", 1, [h1]).is_paused())
	e.answer_reaction(true)
	assert_eq((h2.creature as Character).slots_left(3), slots - 1, "H2's Counterspell stood: its slot is spent")
	assert_true(_bless_held(f), "the Bless goes ahead")
	assert_true(_logged(e, "Ratatouille's Counterspell holds against"), "H2 got through F2's")
	assert_true(_logged(e, "Mage's Counterspell fizzles (countered by Ratatouille)"))
	assert_true((f["dice"] as ScriptedDice).d20s.is_empty())


func test_a_chain_of_three_where_the_foes_win_after_all() -> void:
	# H2 and F1 both pass their saves, H1 fails: the Bless dissipates, and H2's slot is spent (it stood).
	var f := _field([20, 20, 1])
	var e := f["e"] as Encounter
	var h1 := f["h1"] as Combatant
	var h2 := f["h2"] as Combatant
	var slots := (h2.creature as Character).slots_left(3)
	assert_true(e.spells.cast(h1, "bless", 1, [h1]).is_paused())
	e.answer_reaction(true)
	assert_eq((h2.creature as Character).slots_left(3), slots - 1, "H2's Counterspell stood, so its slot is spent")
	assert_false(_bless_held(f))
	assert_true(_logged(e, "Bless dissipates (Counterspell)"))
	assert_true((f["dice"] as ScriptedDice).d20s.is_empty(), "three saves")


func test_a_chain_of_three_where_the_spell_gets_through() -> void:
	var f := _field([20, 20, 20])
	var e := f["e"] as Encounter
	var h1 := f["h1"] as Combatant
	assert_true(e.spells.cast(h1, "bless", 1, [h1]).is_paused())
	e.answer_reaction(true)
	assert_true(_bless_held(f), "all three Counterspells held and H1 saved: the Bless goes ahead")
	assert_true(_logged(e, "Silvain Aster's Bless gets through the Counterspell"), str(e.log.texts()))


func test_automatic_still_asks_when_there_are_several_ways_to_pay() -> void:
	var f := _field([1])
	var e := f["e"] as Encounter
	var h1 := f["h1"] as Combatant
	var h2 := f["h2"] as Combatant
	h2.reaction_rules["counterspell"] = "auto"
	assert_true(SpellReactions.slot_levels(h2.creature as Character, 3).size() > 1, "a level 9 wizard has several levels of slot")
	assert_true(e.spells.cast(h1, "bless", 1, [h1]).is_paused(), "Automatic still asks")
	var req := e.pending
	assert_true(req.target_choices.size() > 1, "with the slots to pick from")
	assert_eq(req.cost, "Reaction and the spell slot you choose")
	assert_eq(req.min_targets, 1)
	req.selected_ids.assign(["4"])
	(f["f2"] as Combatant).reaction_available = false
	var slots4 := (h2.creature as Character).slots_left(4)
	var slots3 := (h2.creature as Character).slots_left(3)
	e.answer_reaction(true)
	assert_eq((h2.creature as Character).slots_left(4), slots4 - 1, "the slot picked is the one spent")
	assert_eq((h2.creature as Character).slots_left(3), slots3)


func test_automatic_with_one_way_to_pay_counters_without_asking() -> void:
	var f := _field([1], 5)
	var e := f["e"] as Encounter
	var h1 := f["h1"] as Combatant
	var h2 := f["h2"] as Combatant
	(f["f2"] as Combatant).reaction_available = false
	h2.reaction_rules["counterspell"] = "auto"
	assert_eq(SpellReactions.slot_levels(h2.creature as Character, 3).size(), 1, "one level of slot")
	var r := e.spells.cast(h1, "bless", 1, [h1])
	assert_false(r.is_paused(), "no prompt: the rule decides")
	assert_false(h2.reaction_available, "it Counterspelled")
	assert_true(_bless_held(f), "and the Bless went ahead")


func test_off_never_answers() -> void:
	var f := _field([1])
	var e := f["e"] as Encounter
	var h1 := f["h1"] as Combatant
	var h2 := f["h2"] as Combatant
	h2.reaction_rules["counterspell"] = "never"
	var r := e.spells.cast(h1, "bless", 1, [h1])
	assert_false(r.is_paused())
	assert_true(h2.reaction_available)
	assert_false(_bless_held(f))


func test_a_hero_without_a_reaction_or_a_slot_is_not_asked() -> void:
	var f := _field([1])
	var e := f["e"] as Encounter
	var h1 := f["h1"] as Combatant
	var h2 := f["h2"] as Combatant
	h2.reaction_available = false
	assert_false(e.spells.cast(h1, "bless", 1, [h1]).is_paused(), "no Reaction, no prompt")
	f = _field([1])
	e = f["e"] as Encounter
	h1 = f["h1"] as Combatant
	h2 = f["h2"] as Combatant
	var ch := h2.creature as Character
	for l in range(3, 10):
		while ch.slots_left(l) > 0:
			ch.expend_slot(l)
	assert_false(e.spells.cast(h1, "bless", 1, [h1]).is_paused(), "no slot, no prompt")


func test_a_hero_who_cannot_see_or_reach_the_foe_is_not_asked() -> void:
	var rows: Array[String] = []
	for z in 4:
		rows.append("................")
	var dice := ScriptedDice.new(7)
	var e := Encounter.new(CombatGrid.from_rows(rows), dice)
	var h1 := TestCombat.caster_with(e, ["bless"], Vector2i(8, 1), 9, "silvain_aster")
	var h2 := TestCombat.caster_with(e, ["counterspell"], Vector2i(0, 1), 9, "ratatoille")
	h1.reaction_rules["counterspell"] = "never"   # Silvain knows it too, and is in reach
	var f1 := TestCombat.foe(e, "mage", Vector2i(14, 1))   # 30 ft from H1, 70 ft from H2
	f1.creature.hp = 200
	TestCombat.start_with(e, h1)
	while e.pending != null:
		e.answer_reaction(false)
	assert_true(e.distance(h2, f1) > 60 and e.distance(h1, f1) <= 60)
	dice.d20s.assign([1] as Array[int])
	var r := e.spells.cast(h1, "bless", 1, [h1])
	assert_false(r.is_paused(), "H2 is 70 ft from the Counterspell: no prompt")
	assert_true(_logged(e, "Mage casts Counterspell at Silvain"))


func test_a_cantrip_is_still_let_through() -> void:
	var f := _field([1])
	var e := f["e"] as Encounter
	var h1 := f["h1"] as Combatant
	var r := e.spells.cast(h1, "fire_bolt", 0, [f["f2"]])
	assert_false(r.is_paused())
	assert_false(_logged(e, "Counterspell"))


func test_the_reactions_tab_lists_the_counterspell_rule_for_a_hero_who_knows_it() -> void:
	var f := _field([])
	var e := f["e"] as Encounter
	var h2 := f["h2"] as Combatant
	var cat := ActionCatalog.new(e)
	var slot := cat.find(h2, "feat:reaction_policy:counterspell:ask")
	assert_false(slot.is_empty(), "a toggle for it")
	assert_true(bool(slot["selected"]), "Ask until set")
	assert_eq(str(slot["policy_name"]), "Counterspell")
