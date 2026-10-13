extends TestCase
## Slot levels on reaction prompts (owner reports 2026-10-12): a level 6 warlock's Hellish Rebuke is cast with its
## level 3 Pact Magic slot and its prompt says so; a paladin asked to smite on a hit picks the slot level.


func test_a_warlocks_hellish_rebuke_uses_its_pact_slot_and_says_so() -> void:
	var e := TestCombat.open_field(5)
	var kip := TestCombat.hero(e, "kip_smudgewick", Vector2i(2, 2), 6)
	var ogre := TestCombat.foe(e, "ogre", Vector2i(3, 2))
	ogre.creature.hp = 500
	TestCombat.start_with(e, ogre)
	kip.reaction_rules["hellish_rebuke"] = "ask"
	(kip.creature as Character).spend_resource("spell:hellish_rebuke")   # the tiefling's free casting: a second pick
	e.deal_damage(ogre, kip, [{"amount": 3, "type": "bludgeoning"}], false, "A shove")
	e.run_reaction_queue(CombatResult.new())
	assert_true(e.pending != null and e.pending.kind == "hellish_rebuke", "asked: %s" % [e.pending.kind if e.pending != null else "nothing"])
	if e.pending == null:
		return
	assert_true(e.pending.target_choices.is_empty(), "one pact level: nothing to pick")
	assert_true(e.pending.cost.contains("level 3") and e.pending.cost.contains("Pact Magic"), e.pending.cost)
	assert_true(e.pending.text.contains("4d10"), e.pending.text)
	e.answer_reaction(true)
	assert_true(e.log.texts().any(func(t: String) -> bool: return t.contains("Hellish Rebuke (level 3 slot)")))
	assert_eq((kip.creature as Character).pact_magic()["left"], 1, "a pact slot spent")


func test_a_reaction_spell_is_cast_at_the_level_picked() -> void:
	var e := TestCombat.open_field(5)
	var kip := TestCombat.hero(e, "kip_smudgewick", Vector2i(2, 2), 6)
	var ogre := TestCombat.foe(e, "ogre", Vector2i(3, 2))
	ogre.creature.hp = 500
	TestCombat.start_with(e, ogre)
	e.spells.cast_reaction_spell(kip, "hellish_rebuke", ogre, 1)   # no level 1 slot: its pact level instead
	assert_true(e.log.texts().any(func(t: String) -> bool: return t.contains("(level 3 slot)")))


func test_a_paladin_picks_the_slot_to_smite_with() -> void:
	var e := TestCombat.open_field(3)
	var ch := TestChars.custom("paladin", "human", 5)
	ch.heroic_inspiration = false
	ch.spend_resource("spell:divine_smite")   # the free use is gone: slots only
	var p := e.add(ch, &"party", Vector2i(3, 3))
	var z := TestCombat.foe(e, "zombie", Vector2i(4, 3))
	z.creature.hp = 200
	TestCombat.start_with(e, z)
	z.movement_left = 30
	e.move(z, Vector2i(8, 3))
	assert_eq(e.pending.kind, "opportunity_attack")
	TestCombat.next_d20(e, 19)
	e.answer_reaction(true)
	assert_true(e.pending != null and e.pending.kind == "divine_smite")
	if e.pending == null:
		return
	var ids: Array = e.pending.target_choices.map(func(o: Dictionary) -> String: return str(o["id"]))
	assert_eq(ids, ["1", "2"], "each level with a slot")
	assert_eq(e.pending.selected_ids, ["1"] as Array[String], "the lowest first")
	assert_true(str(e.pending.target_choices[1]["label"]).contains("3d8"), str(e.pending.target_choices[1]["label"]))
	var level2 := ch.slots_left(2)
	var level1 := ch.slots_left(1)
	e.pending.selected_ids.assign(["2"])
	e.answer_reaction(true)
	while e.pending != null:
		e.answer_reaction(false)
	assert_eq(ch.slots_left(2), level2 - 1, "smitten with the level 2 slot")
	assert_eq(ch.slots_left(1), level1, "not the level 1 one")
	assert_true(e.log.texts().any(func(t: String) -> bool: return t.contains("a level 2 spell slot")))


## And on its own turn: a warlock's levelled spell is cast at its pact level too (Armor of Agathys: 5 Temporary Hit
## Points a slot level).
func test_a_warlocks_spell_on_its_turn_uses_its_pact_level() -> void:
	var e := TestCombat.open_field(5)
	var kip := TestCombat.hero(e, "kip_smudgewick", Vector2i(2, 2), 6)
	TestCombat.foe(e, "ogre", Vector2i(9, 2))
	TestCombat.start_with(e, kip)
	var ch := kip.creature as Character
	var spell := ""
	for id: String in ["armor_of_agathys", "false_life"]:
		if ch.knows_spell(id):
			spell = id
	if spell == "":
		print("  (Kip knows neither Armor of Agathys nor False Life: skipped)")
		return
	var r := e.spells.cast(kip, spell, 0, [kip])   # no slot named: the one it has
	assert_true(r.ok, r.reason)
	while e.pending != null:
		e.answer_reaction(false)
	assert_eq(int(ch.pact_magic()["left"]), 1, "a pact slot spent")
	assert_true(e.log.texts().any(func(t: String) -> bool: return t.contains("level 3")), "\n".join(e.log.texts().slice(-4)))


## A Critical Hit doubles the smite's dice too, so its prompt says so in red and each slot shows its dice doubled (owner,
## 2026-10-13); an ordinary hit shows neither.
func test_a_paladins_smite_prompt_says_when_the_hit_is_critical() -> void:
	for crit: bool in [true, false]:
		var e := TestCombat.open_field(3)
		var ch := TestChars.custom("paladin", "human", 5)
		ch.heroic_inspiration = false
		var p := e.add(ch, &"party", Vector2i(3, 3))
		var z := TestCombat.foe(e, "zombie", Vector2i(4, 3))
		z.creature.hp = 200
		TestCombat.start_with(e, p)
		TestCombat.next_d20(e, 20 if crit else 15)
		e.attack(p, z, str(e.attack_options(p)[0]["id"]))
		assert_true(e.pending != null and e.pending.kind == "divine_smite", "asked: %s" % [e.pending.kind if e.pending != null else "nothing"])
		if e.pending == null:
			return
		var labels: Array = e.pending.target_choices.map(func(o: Dictionary) -> String: return str(o["label"]))
		if crit:
			assert_eq(e.pending.callout, "Critical Hit: the smite's dice are doubled")
			assert_true(e.pending.text.contains("Critical Hit") and e.pending.text.contains("every die doubled"), e.pending.text)
			assert_true(str(labels[0]).ends_with("4d8 (2d8 doubled)"), str(labels[0]))
			assert_true(labels.any(func(l: Variant) -> bool: return str(l).begins_with("Level 2 slot · 6d8 (3d8 doubled)")), str(labels))
		else:
			assert_eq(e.pending.callout, "", "no red line on an ordinary hit")
			assert_false(e.pending.text.contains("Critical"), e.pending.text)
			assert_true(str(labels[0]).ends_with("2d8"), str(labels[0]))
		while e.pending != null:
			e.answer_reaction(false)
