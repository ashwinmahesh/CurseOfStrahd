extends TestCase
## A warlock's spells are cast at its pact level, the only level offered (owner, 2026-10-13; 2024 PHB: Pact Magic slots
## are all one level): on the hotbar and its numbers, outside a fight, readied, and whatever level a caller names (the
## test autopilot's). At-will invocations take no slot; a free casting (a tiefling's Darkness) waits for the pact slots;
## a multiclassed caster's ordinary slots keep their choices.


func _kip(level: int) -> Array:
	var e := TestCombat.open_field(5)
	var kip := TestCombat.hero(e, "kip_smudgewick", Vector2i(2, 2), level)
	var ogre := TestCombat.foe(e, "ogre", Vector2i(5, 2))
	ogre.creature.hp = 500
	TestCombat.start_with(e, kip)
	return [e, kip, ogre]


func test_every_slot_spell_is_offered_at_the_pact_level_only() -> void:
	var setup := _kip(6)
	var e := setup[0] as Encounter
	var kip := setup[1] as Combatant
	var ch := kip.creature as Character
	assert_eq(int(ch.pact_magic()["level"]), 3)
	var cat := ActionCatalog.new(e)
	var seen := 0
	for a: Dictionary in cat.actions_for(kip):
		if str(a.get("kind", "")) != "spell" or int(a["slot"]) == 0 or bool(a.get("at_will", false)):
			continue
		seen += 1
		assert_eq(cat.level_choices(kip, a), [3] as Array[int], str(a["label"]))
	assert_true(seen >= 5, "Kip's levelled spells: %d" % seen)
	var hands := cat.find(kip, "spell:burning_hands")
	assert_true(str(hands["sub"]).begins_with("Pact level 3") and str(hands["sub"]).contains("5d6"), str(hands["sub"]))
	assert_eq(int(hands["slot"]), 1, "still listed with the level 1 spells")
	var hold := cat.find(kip, "spell:hold_person")
	var levels := cat.level_choices(kip, hold)
	assert_eq(levels, [3] as Array[int], "the casting level menu has one entry")
	# Outside a fight: the same one level.
	var party: Array[Character] = [ch]
	for o in FieldCasting.options(party, ch, DiceRoller.new(1)):
		if str(o["id"]) in ["hex", "armor_of_agathys"]:
			assert_eq(o["slots"], [3] as Array[int], str(o["id"]))
	for o in FieldCasting.utility_options(party, ch, DiceRoller.new(1)):
		if str(o["id"]) == "alarm":
			assert_eq(o["slots"], [3] as Array[int], "alarm")


## The autopilot (and any test or tool) names a spell's own level: a warlock casts it at its pact level all the same.
func test_a_lower_level_named_is_cast_at_the_pact_level() -> void:
	var setup := _kip(9)
	var e := setup[0] as Encounter
	var kip := setup[1] as Combatant
	var ogre := setup[2] as Combatant
	var ch := kip.creature as Character
	assert_eq(int(ch.pact_magic()["level"]), 5)
	var r := PartyAutopilot.new(e)._cast(kip, "hex", 1, [ogre])
	assert_true(r.ok, r.reason)
	while e.pending != null:
		e.answer_reaction(false)
	assert_true(e.log.texts().any(func(t: String) -> bool: return t.contains("Hex (level 5 slot)")), "\n".join(e.log.texts().slice(-4)))
	assert_eq(int(ch.pact_magic()["left"]), 1, "one pact slot spent")


func test_readying_a_spell_uses_the_pact_level() -> void:
	var setup := _kip(6)
	var e := setup[0] as Encounter
	var kip := setup[1] as Combatant
	var ch := kip.creature as Character
	var r := e.ready_spell(kip, "hold_person", 2)   # the hotbar names the spell's own level
	assert_true(r.ok, r.reason)
	assert_eq(int(kip.readied["slot"]), 3)
	assert_eq(int(ch.pact_magic()["left"]), 1)


## Armor of Shadows: Mage Armor at will, never a pact slot, whatever the hotbar's pip said.
func test_an_at_will_invocation_spends_no_pact_slot() -> void:
	var setup := _kip(6)
	var e := setup[0] as Encounter
	var kip := setup[1] as Combatant
	var ch := kip.creature as Character
	var cat := ActionCatalog.new(e)
	var armor := cat.find(kip, "spell:mage_armor")
	assert_false(armor.is_empty(), "Kip knows Armor of Shadows")
	if armor.is_empty():
		return
	assert_eq(cat.level_choices(kip, armor), [] as Array[int], "no slot to pick")
	assert_true(str(armor["sub"]).contains("free"), str(armor["sub"]))
	var r := cat.perform(kip, armor, [kip], Vector2.INF, Vector2.ZERO, 3)
	assert_true(r.ok, r.reason)
	assert_eq(int(ch.pact_magic()["left"]), 2, "no pact slot spent")
	assert_true(e.log.texts().any(func(t: String) -> bool: return t.contains("Mage Armor (free casting)")), "\n".join(e.log.texts().slice(-3)))
	var party: Array[Character] = [ch]
	for o in FieldCasting.options(party, ch, DiceRoller.new(1)):
		if str(o["id"]) == "mage_armor":
			assert_true(bool(o["free"]) and (o["slots"] as Array).is_empty(), str(o))


## A tiefling's free Darkness (level 2) waits while a level 3 pact slot is left, then is the casting offered.
func test_a_free_casting_waits_until_the_pact_slots_are_spent() -> void:
	var setup := _kip(6)
	var e := setup[0] as Encounter
	var kip := setup[1] as Combatant
	var ch := kip.creature as Character
	var cat := ActionCatalog.new(e)
	var dark := cat.find(kip, "spell:darkness")
	assert_true(str(dark["sub"]).begins_with("Pact level 3") and not str(dark["sub"]).contains("free"), str(dark["sub"]))
	assert_eq(cat.level_choices(kip, dark), [3] as Array[int])
	ch.pact_slots_used = 2
	dark = cat.find(kip, "spell:darkness")
	assert_eq(str(dark["sub"]), "Level 2 · free")
	assert_eq(cat.level_choices(kip, dark), [] as Array[int])
	var r := cat.perform(kip, dark, [], Vector2(6, 2), Vector2.ZERO, int(dark["slot"]))
	assert_true(r.ok, r.reason)
	assert_eq(ch.resource_left("spell:darkness"), 0, "the free casting used")


## A warlock 5 / sorcerer 1: its sorcerer slots still offer level 1 beside the pact level; once they're spent, a level
## 1 spell named is cast at the pact level.
func test_a_multiclassed_casters_own_slots_keep_their_choices() -> void:
	var ch := TestChars.pregen("kip_smudgewick", 5)
	var up := LevelUpController.new(ch)
	assert_true(up.choose_class("sorcerer"), "Kip can multiclass into Sorcerer")
	up.take_fixed_hit_points()
	assert_eq(TestChars.auto_pick(up.pending_choices, up.choose), [] as Array[String])
	assert_true(up.confirm(), str(up.errors()))
	assert_eq(ch.slot_levels(1), [1, 3] as Array[int])
	assert_eq(ch.pact_only_level(1), 0)
	ch.slots_used[0] = 2
	assert_eq(ch.slot_levels(1), [3] as Array[int])
	assert_eq(ch.pact_only_level(1), 3)
	ch.slots_used[0] = 0
	var e := TestCombat.open_field(5)
	var kip := e.add(ch, &"party", Vector2i(2, 2))
	var ogre := TestCombat.foe(e, "ogre", Vector2i(5, 2))
	ogre.creature.hp = 500
	TestCombat.start_with(e, kip)
	var r := e.spells.cast(kip, "hex", 1, [ogre])
	assert_true(r.ok, r.reason)
	assert_true(e.log.texts().any(func(t: String) -> bool: return t.contains("Hex (level 1 slot)")), "a sorcerer slot at level 1")
	assert_eq(int(ch.pact_magic()["left"]), 2, "the pact slots kept")
