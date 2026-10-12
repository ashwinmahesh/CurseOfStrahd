extends TestCase
## Owner ask (2026-10-12): summoned steeds and familiars rank below the heroes on a foe's list. A foe strikes a familiar
## or a steed only when no hero can be reached this turn (moving first included), and no spell is aimed for one.


static func _owl(e: Encounter, owner: Combatant, cell: Vector2i) -> Combatant:
	var owl := e.add(Monster.from_data(SummonBlocks.for_spell("find_familiar", 1, "", {})), &"guest", cell)
	owl.set_meta("summoner", owner.id)
	return owl


func test_a_foe_goes_past_the_familiar_to_a_hero_it_can_reach() -> void:
	var e := TestCombat.open_field()
	var ilse := TestCombat.hero(e, "ilse_varga", Vector2i(11, 6))
	var owl := _owl(e, ilse, Vector2i(5, 3))
	var wolf := TestCombat.foe(e, "wolf", Vector2i(4, 3))
	TestCombat.start_with(e, wolf)
	assert_true(AiBrain.companion(owl) and not AiBrain.companion(ilse))
	var plan := e.ai.plan_turn(wolf)
	assert_eq(str(plan["kind"]), "attack", str(plan))
	assert_true(plan.get("target") == ilse, "the hero, not the owl beside it: %s" % plan.get("why", ""))


func test_the_familiar_is_struck_when_no_hero_can_be_reached() -> void:
	var rows: Array[String] = []
	for z in 4:
		rows.append("..............................")
	var e := TestCombat.encounter(rows)
	var ilse := TestCombat.hero(e, "ilse_varga", Vector2i(29, 3))
	var owl := _owl(e, ilse, Vector2i(3, 1))
	var wolf := TestCombat.foe(e, "wolf", Vector2i(2, 1))
	TestCombat.start_with(e, wolf)
	var plan := e.ai.plan_turn(wolf)
	assert_eq(str(plan["kind"]), "attack", str(plan))
	assert_true(plan.get("target") == owl, "the owl, with the hero out of reach: %s" % plan.get("why", ""))


func test_a_spell_counts_a_familiar_for_little() -> void:
	var e := TestCombat.open_field()
	var ilse := TestCombat.hero(e, "ilse_varga", Vector2i(8, 3))
	var owl := _owl(e, ilse, Vector2i(8, 4))
	var mage := TestCombat.foe(e, "mage", Vector2i(2, 3))
	TestCombat.start_with(e, mage)
	var s := Compendium.shared().spell_data("fireball")
	var spells := AiSpells.new(e)
	assert_true(spells.worth(mage, s, owl) < spells.worth(mage, s, ilse) * 0.5, "a hero is worth far more")
