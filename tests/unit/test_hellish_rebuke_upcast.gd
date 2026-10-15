extends TestCase
## Hellish Rebuke at a high Pact Magic level (owner report 2026-10-15: Kip, a level 9 warlock, saw 9 damage): a pact slot
## is level 5, so 6d10 Fire (2d10 and 1d10 a slot level above 1). Only the tiefling's free casting, once the pact slots
## are spent, is the level 1 cast of 2d10, and the log says which one it was.


func _hit(level: int, rule: String, spend_pact: bool, pick: String = "") -> Array:
	var e := TestCombat.open_field(5)
	var kip := TestCombat.hero(e, "kip_smudgewick", Vector2i(2, 2), level)
	var ogre := TestCombat.foe(e, "ogre", Vector2i(3, 2))
	ogre.creature.hp = 5000
	TestCombat.start_with(e, ogre)
	var ch := kip.creature as Character
	if spend_pact:
		while ch.pact_magic()["left"] > 0:
			ch.expend_slot(int(ch.pact_magic()["level"]))
	kip.reaction_rules["hellish_rebuke"] = rule
	e.deal_damage(ogre, kip, [{"amount": 3, "type": "bludgeoning"}], false, "A shove")
	e.run_reaction_queue(CombatResult.new())
	if e.pending != null:
		if pick != "":
			e.pending.selected_ids.assign([pick])
		e.answer_reaction(true)
	while e.pending != null:
		e.answer_reaction(false)
	return [e, kip]


func _dice(e: Encounter) -> String:
	var dump := e.log.dump()
	for d: String in ["6d10", "2d10", "4d10"]:
		if dump.contains("Hellish Rebuke " + d + ":"):
			return d
	return ""


func test_a_level_nine_warlock_casts_it_with_the_level_five_pact_slot() -> void:
	for rule: String in ["ask", "auto"]:
		var r := _hit(9, rule, false)
		var e := r[0] as Encounter
		assert_eq(SpellReactions.slot_levels((r[1] as Combatant).creature as Character, 1), [5] as Array[int], "a pact slot is level 5")
		assert_true(e.log.texts().any(func(t: String) -> bool: return t.contains("Hellish Rebuke (level 5 slot)")), "%s: %s" % [rule, e.log.dump()])
		assert_eq(_dice(e), "6d10", rule)
		assert_eq(((r[1] as Combatant).creature as Character).pact_magic()["left"], 1, "a pact slot spent, the free casting kept")


func test_the_prompt_names_the_dice_of_each_casting() -> void:
	var e := TestCombat.open_field(5)
	var kip := TestCombat.hero(e, "kip_smudgewick", Vector2i(2, 2), 9)
	var ogre := TestCombat.foe(e, "ogre", Vector2i(3, 2))
	TestCombat.start_with(e, ogre)
	kip.reaction_rules["hellish_rebuke"] = "ask"
	e.deal_damage(ogre, kip, [{"amount": 3, "type": "bludgeoning"}], false, "A shove")
	e.run_reaction_queue(CombatResult.new())
	assert_true(e.pending != null and e.pending.kind == "hellish_rebuke")
	if e.pending == null:
		return
	var labels: Array = e.pending.target_choices.map(func(o: Dictionary) -> String: return str(o["label"]))
	assert_true(str(labels[0]).contains("Level 5") and str(labels[0]).contains("6d10"), str(labels))
	assert_true(str(labels[1]).contains("Free casting") and str(labels[1]).contains("2d10"), str(labels))
	assert_eq(e.pending.selected_ids, ["5"] as Array[String], "the pact slot is what the prompt starts on")
	while e.pending != null:
		e.answer_reaction(false)


## Both pact slots spent on his own turn: the free casting is all that's left, and it is a level 1 cast (2d10).
func test_with_the_pact_slots_spent_it_is_the_free_level_one_casting() -> void:
	for rule: String in ["ask", "auto"]:
		var r := _hit(9, rule, true)
		var e := r[0] as Encounter
		assert_true(e.log.texts().any(func(t: String) -> bool: return t.contains("Hellish Rebuke (free casting, level 1)")), "%s: %s" % [rule, e.log.dump()])
		assert_eq(_dice(e), "2d10", rule)


func test_the_free_casting_can_be_picked_over_the_pact_slot() -> void:
	var r := _hit(9, "ask", false, "free")
	var e := r[0] as Encounter
	assert_eq(_dice(e), "2d10")
	assert_eq(((r[1] as Combatant).creature as Character).pact_magic()["left"], 2, "no pact slot spent")


## Automatic still asks when there is a choice of how to cast it (owner, 2026-10-15), and only then.
func test_on_automatic_it_asks_when_there_is_more_than_one_way_to_cast_it() -> void:
	var e := TestCombat.open_field(5)
	var kip := TestCombat.hero(e, "kip_smudgewick", Vector2i(2, 2), 9)
	var ogre := TestCombat.foe(e, "ogre", Vector2i(3, 2))
	ogre.creature.hp = 5000
	TestCombat.start_with(e, ogre)
	kip.reaction_rules["hellish_rebuke"] = "auto"
	e.deal_damage(ogre, kip, [{"amount": 3, "type": "bludgeoning"}], false, "A shove")
	e.run_reaction_queue(CombatResult.new())
	assert_true(e.pending != null and e.pending.kind == "hellish_rebuke", "asked: a pact slot or the free casting")
	if e.pending == null:
		return
	assert_eq(e.pending.target_choices.size(), 2)
	while e.pending != null:
		e.answer_reaction(false)
