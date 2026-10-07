extends TestCase
## The Arcana Unleashed wizard traditions switched on in batch 6 (Enchanter, Necromancer, Transmuter), built through
## the real level-up path and used in a fight.


func _wizard(e: Encounter, sub: String, level: int, cell: Vector2i, picks: Dictionary = {}) -> Combatant:
	var p := picks.duplicate()
	p["wizard_subclass"] = [sub]
	return e.add(TestChars.custom("wizard", "human", level, p), &"party", cell)


func _ch(c: Combatant) -> Character:
	return c.creature as Character


func _find(e: Encounter, c: Combatant, id: String) -> Dictionary:
	return ActionCatalog.new(e).find(c, id)


func test_the_three_traditions_are_offered() -> void:
	var ids := Compendium.shared().subclasses_of("wizard").map(func(s: Dictionary) -> String: return str(s["id"]))
	for id: String in ["enchanter", "necromancer", "transmuter"]:
		assert_true(id in ids, "%s offered" % id)


func test_instinctive_charm_turns_a_hit_on_someone_else() -> void:
	var e := TestCombat.open_field(5)
	var c := _wizard(e, "enchanter", 10, Vector2i(2, 3))
	var foe := TestCombat.foe(e, "zombie", Vector2i(3, 3))
	var other := TestCombat.foe(e, "zombie", Vector2i(4, 3))
	TestCombat.start_with(e, foe)
	c.reaction_rules["instinctive_charm"] = "ask"
	c.reaction_rules["shield"] = "never"
	TestCombat.next_d20(e, 18)
	e.monster_attack(foe, c, "slam")
	assert_true(e.pending != null and e.pending.kind == "instinctive_charm", "asked when hit")
	if e.pending == null:
		return
	foe.creature.add_effect(Effect.new("Dull").with_modifier("auto_fail", {"on": "save:wis"}))
	var hp := c.creature.hp
	e.answer_reaction(true)
	assert_eq(c.creature.hp, hp, "the blow misses the Enchanter")
	assert_true(e.log.texts().any(func(x: String) -> bool: return x.contains("turns the blow")), "and turns on another creature")
	assert_eq(_ch(c).resource_left("instinctive_charm"), 0)
	var _unused := other


func test_necromancer_familiar_vitality_and_harvest() -> void:
	var e := TestCombat.open_field(5)
	var c := _wizard(e, "necromancer", 10, Vector2i(2, 3))
	var foe := TestCombat.foe(e, "zombie", Vector2i(8, 3))
	TestCombat.start_with(e, c)
	c.set_meta("familiar_form", "zombie")
	assert_true(e.spells.precast(c, "find_familiar"), "Find Familiar before the fight")
	var fam: Combatant = null
	for sid: Variant in e.spells.summoned.get(c.id, []):
		fam = e.get_c(str(sid))
	assert_true(fam != null and fam.creature.creature_type == &"undead", "an Undead familiar")
	assert_true(fam.creature.max_hp() > 15, "Undead Thralls adds Hit Points to the 15 of a Zombie")
	assert_false(_find(e, c, "feat:cf:familiar_strike").is_empty(), "it can strike in place of an attack")
	fam.creature.hp = 5
	c.action_available = true
	c.magic_action_used = false
	c.cast_slot_spell_this_turn = false
	if not _ch(c).knows_spell("ray_of_enfeeblement"):
		(_ch(c).spellcasting[0]["prepared"] as Array).append("ray_of_enfeeblement")
	assert_true(e.spells.cast(c, "ray_of_enfeeblement", 2, [foe]).ok)
	assert_true(fam.creature.hp > 5, "Undead Vitality")
	var dice := e.faerun.hit_dice(fam, foe)
	assert_eq(dice.size(), 1, "Undead Thralls' Necrotic on its hits")
	c.reaction_rules["fr_harvest_undead"] = "auto"
	c.creature.hp = c.creature.max_hp() / 2 + 2
	e.end_turn()
	e.deal_damage(foe, c, [{"amount": 5, "type": "slashing"}], false, "Slam")
	e.run_reaction_queue(CombatResult.new())
	assert_false(fam.is_alive() and fam.creature.hp > 0, "Harvest Undead drained the familiar")


func test_grave_power_eases_exhaustion_and_pierces_necrotic_resistance() -> void:
	var ch := TestChars.custom("wizard", "human", 6, {"wizard_subclass": ["necromancer"]})
	assert_true(ch.modifiers_for(&"ignore_resistance").any(func(m: Modifier) -> bool: return m.text("value") == "necrotic"))
	ch.exhaustion = 2
	ch.spend_resource("arcane_recovery")
	assert_eq(ch.exhaustion, 1, "Arcane Recovery removes a level")
	assert_eq(ch.resource_left("spell:animate_dead"), 1, "a free Animate Dead")


func test_deaths_master_shields_and_explodes_undead() -> void:
	var e := TestCombat.open_field(5)
	var c := _wizard(e, "necromancer", 14, Vector2i(2, 3))
	var foe := TestCombat.punching_bag(e, Vector2i(6, 3), 300)
	TestCombat.start_with(e, c)
	assert_true(e.spells.precast(c, "find_familiar"))
	var fam: Combatant = null
	for sid: Variant in e.spells.summoned.get(c.id, []):
		fam = e.get_c(str(sid))
	foe.cell = fam.cell + Vector2i(1, 0)
	assert_true(ActionCatalog.new(e).perform(c, _find(e, c, "feat:fr:deaths_master")).ok)
	assert_eq(fam.creature.temp_hp, 14, "Wizard level Temporary Hit Points")
	e.deal_damage(foe, fam, [{"amount": 500, "type": "force"}], false, "Crush")
	assert_true(foe.creature.hp < 300, "the fallen Undead explodes")


func test_transmuters_stone_alteration_and_panacea() -> void:
	var ch := TestChars.custom("wizard", "human", 14, {"wizard_subclass": ["transmuter"], "transmuters_stone": ["resist_fire"], "potent_stone": ["speed"]})
	assert_true(ch.save_proficiency(&"con") != "", "the stone's Constitution saves")
	assert_true(ch.modifiers_for(&"resistance").any(func(m: Modifier) -> bool: return m.text("value") == "fire"))
	assert_true(ch.modifiers_for(&"speed").any(func(m: Modifier) -> bool: return m.source_name.contains("stone") or m.number("value") == 10))
	var e := TestCombat.open_field(5)
	var c := e.add(ch, &"party", Vector2i(2, 3))
	var ally := TestCombat.hero(e, "ilse_varga", Vector2i(3, 3))
	TestCombat.punching_bag(e, Vector2i(9, 3))
	TestCombat.start_with(e, c)
	assert_true(e.spells.cast(c, "alter_self", 2, [c], Vector2.INF, Vector2.ZERO, {"choice": "slashing"}).ok)
	assert_eq(ch.resource_left("spell:alter_self"), 0, "the free casting")
	assert_true(c.creature.modifiers_for(&"weapon_override").any(func(m: Modifier) -> bool: return m.text("die") == "2d6"), "2d6 natural weapons")
	assert_false((c.creature.d20_sources(["concentration"])["advantage"] as Array).is_empty(), "Advantage on Concentration")
	ally.creature.hp = 2
	ally.creature.add_condition(&"poisoned", "test")
	c.action_available = true
	c.magic_action_used = false
	assert_true(ActionCatalog.new(e).perform(c, _find(e, c, "feat:fr:master_transmuter:panacea"), [ally]).ok)
	assert_true(ally.creature.hp >= ally.creature.max_hp() / 2, "half its Hit Points")
	assert_false(ally.creature.has_condition(&"poisoned"), "cured")


func test_shape_shifter_keeps_the_mind_once() -> void:
	var e := TestCombat.open_field(5)
	var c := _wizard(e, "transmuter", 10, Vector2i(2, 3))
	TestCombat.punching_bag(e, Vector2i(9, 3))
	TestCombat.start_with(e, c)
	var intel := c.creature.ability_score(&"int")
	assert_true(e.spells.cast(c, "polymorph", 4, [c]).ok)
	assert_eq(c.creature.ability_score(&"int"), intel, "Intelligence kept")
	assert_eq(_ch_of_original(e, c).resource_left("shape_shifter"), 0)


func _ch_of_original(e: Encounter, c: Combatant) -> Character:
	return e.shapes.original(c) as Character if e.shapes.is_shaped(c) else c.creature as Character
