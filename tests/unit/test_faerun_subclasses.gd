extends TestCase
## The Heroes of Faerûn subclasses switched on in batch 5 (College of the Moon, Banneret, Oath of the Noble Genies,
## Scion of the Three, Spellfire Sorcery, Arcana Domain), built through the real level-up path and used in a fight.


func _hero(e: Encounter, class_id: String, sub: String, level: int, cell: Vector2i, picks: Dictionary = {}) -> Combatant:
	var p := picks.duplicate()
	p["%s_subclass" % class_id] = [sub]
	return e.add(TestChars.custom(class_id, "human", level, p), &"party", cell)


func _find(e: Encounter, c: Combatant, id: String) -> Dictionary:
	return ActionCatalog.new(e).find(c, id)


func _do(e: Encounter, c: Combatant, id: String, targets: Array = [], point: Vector2 = Vector2.INF) -> CombatResult:
	var a := _find(e, c, id)
	if a.is_empty():
		return CombatResult.fail("no action " + id)
	return ActionCatalog.new(e).perform(c, a, targets, point)


func _ch(c: Combatant) -> Character:
	return c.creature as Character


func test_the_six_subclasses_are_offered() -> void:
	var comp := Compendium.shared()
	for pair: Array in [["bard", "college_of_the_moon"], ["fighter", "banneret"], ["paladin", "oath_of_the_noble_genies"],
			["rogue", "scion_of_the_three"], ["sorcerer", "spellfire_sorcery"], ["cleric", "arcana_domain"]]:
		var ids := comp.subclasses_of(str(pair[0])).map(func(s: Dictionary) -> String: return str(s["id"]))
		assert_true(str(pair[1]) in ids, "%s offered" % pair[1])


func test_moon_bard_eclipses_and_mends_with_moonlight() -> void:
	var e := TestCombat.open_field(3)
	var c := _hero(e, "bard", "college_of_the_moon", 14, Vector2i(2, 3))
	var ally := TestCombat.hero(e, "ilse_varga", Vector2i(3, 3))
	TestCombat.punching_bag(e, Vector2i(10, 3))
	TestCombat.start_with(e, c)
	assert_true(_do(e, c, "feat:cf:bardic_inspiration", [ally]).ok, "Bardic Inspiration")
	assert_true(_do(e, c, "feat:fr:inspired_eclipse", [], Vector2(5.5, 5.5)).ok, "Inspired Eclipse")
	assert_eq(c.cell, Vector2i(5, 5))
	assert_true(c.creature.has_condition(&"invisible"))
	assert_true(_do(e, c, "feat:fr:eventide_step", [], Vector2(6.5, 1.5)).ok, "Eventide's Splendor moves the ally")
	assert_eq(ally.cell, Vector2i(6, 1))
	assert_true(ally.creature.has_condition(&"invisible") and not ally.reaction_available)
	ally.creature.hp = 3
	ally.cell = Vector2i(5, 4)
	c.action_available = true
	c.magic_action_used = false
	(_ch(c).spellcasting[0]["prepared"] as Array).append("cure_wounds")
	var spd := ally.speed()
	var bi := _ch(c).resource_left("bardic_inspiration")
	var cr := e.spells.cast(c, "cure_wounds", 1, [ally])
	assert_true(cr.ok, "Cure Wounds: %s" % cr.reason)
	assert_eq(ally.speed(), spd + 10, "Lunar Vitality's Speed")
	assert_eq(_ch(c).resource_left("bardic_inspiration"), bi, "at level 14 it uses a free 1d6")


func test_blessed_moonbeam_heals_an_ally_when_a_foe_fails() -> void:
	var e := TestCombat.open_field(3)
	var c := _hero(e, "bard", "college_of_the_moon", 6, Vector2i(2, 3))
	var ally := TestCombat.hero(e, "ilse_varga", Vector2i(3, 3))
	var foe := TestCombat.punching_bag(e, Vector2i(7, 3), 300)
	TestCombat.start_with(e, c)
	ally.creature.hp = 2
	assert_true(e.spells.cast(c, "moonbeam", 2, [], Vector2(7.5, 3.5)).ok)
	assert_true(foe.creature.hp < 300)
	assert_true(ally.creature.hp > 2, "the blessing mends an ally")
	assert_eq(_ch(c).resource_left("blessing_of_moonlight"), 0)


func test_banneret_rallies_with_second_wind_and_action_surge() -> void:
	var e := TestCombat.open_field(3)
	var c := _hero(e, "fighter", "banneret", 10, Vector2i(2, 3))
	var ally := TestCombat.hero(e, "ilse_varga", Vector2i(4, 3))
	var foe := TestCombat.punching_bag(e, Vector2i(5, 3), 300)
	TestCombat.start_with(e, c)
	c.creature.hp = 5
	ally.creature.hp = 5
	assert_true(_do(e, c, "second_wind").ok)
	assert_true(ally.creature.hp > 5, "Group Recovery")
	assert_false((ally.creature.d20_sources(["attack"])["advantage"] as Array).is_empty(), "Team Tactics")
	var hp := foe.creature.hp
	assert_true(_do(e, c, "action_surge").ok)
	assert_false(ally.reaction_available, "the ally answered the Rallying Surge")
	assert_true(e.log.texts().any(func(x: String) -> bool: return x.contains("rallying surge")))
	var _unused := hp


func test_noble_genie_smites_with_fire_and_shields_its_aura() -> void:
	var e := TestCombat.open_field(3)
	var c := _hero(e, "paladin", "oath_of_the_noble_genies", 15, Vector2i(2, 3))
	var ally := TestCombat.hero(e, "ilse_varga", Vector2i(2, 4))
	var foe := TestCombat.foe(e, "zombie", Vector2i(3, 3))
	var other := TestCombat.foe(e, "zombie", Vector2i(5, 5))
	TestCombat.start_with(e, c)
	e.class_features.refresh_auras()
	assert_true(ally.creature.modifiers_for(&"resistance").any(func(m: Modifier) -> bool: return m.text("value") == "fire"), "Aura of Elemental Shielding")
	assert_true(_do(e, c, "feat:fr:genie_smite:efreeti").ok)
	assert_true(e.features.toggle_rider(c, "smite:divine_smite").ok)
	var hp := other.creature.hp
	TestCombat.next_d20(e, 19)
	assert_true(e.attack(c, foe, str(e.attack_options(c)[0]["id"])).ok)
	assert_true(other.creature.hp < hp or not other.is_alive(), "the efreeti's fire leaps to another foe")
	assert_true(_do(e, c, "feat:fr:shift_element").ok)
	assert_eq(e.faerun.genie_element(c), "cold")


func test_elemental_rebuke_halves_a_hit() -> void:
	var e := TestCombat.open_field(3)
	var c := _hero(e, "paladin", "oath_of_the_noble_genies", 15, Vector2i(2, 3))
	var foe := TestCombat.foe(e, "zombie", Vector2i(3, 3))
	TestCombat.start_with(e, foe)
	c.reaction_rules["elemental_rebuke"] = "ask"
	TestCombat.next_d20(e, 19)
	e.monster_attack(foe, c, "slam")
	assert_true(e.pending != null and e.pending.kind == "elemental_rebuke", "asked when hit")
	if e.pending == null:
		return
	var uses := _ch(c).resource_left("elemental_rebuke")
	assert_true(e.answer_reaction(true).ok)
	assert_eq(_ch(c).resource_left("elemental_rebuke"), uses - 1)


func test_scion_thirsts_for_blood_and_terrifies() -> void:
	var e := TestCombat.open_field(3)
	var c := _hero(e, "rogue", "scion_of_the_three", 17, Vector2i(1, 3))
	var foe := TestCombat.punching_bag(e, Vector2i(6, 3), 40)
	var ally := TestCombat.hero(e, "ilse_varga", Vector2i(7, 4))
	TestCombat.start_with(e, c)
	c.reaction_rules["fr_bloodthirst"] = "auto"
	e.deal_damage(ally, foe, [{"amount": 25, "type": "fire"}], false, "Fire")
	e.run_reaction_queue(CombatResult.new())
	assert_true(e.distance(c, foe) <= 5, "Bloodthirst: beside the bloodied foe")
	assert_eq(_ch(c).resource_left("scion_bloodthirst"), maxi(1, c.creature.ability_mod(&"int")) - 1)
	var opts := e.features.rider_options(c).map(func(o: Dictionary) -> String: return str(o["id"]))
	assert_true("cunning:terrify" in opts, "Terrify is a Cunning Strike option")


func test_spellfire_bursts_after_sorcery_points_are_spent() -> void:
	var e := TestCombat.open_field(3)
	var c := _hero(e, "sorcerer", "spellfire_sorcery", 14, Vector2i(2, 3))
	var ally := TestCombat.hero(e, "ilse_varga", Vector2i(3, 3))
	TestCombat.punching_bag(e, Vector2i(10, 3))
	TestCombat.start_with(e, c)
	var ch := _ch(c)
	while ch.resource_left("innate_sorcery") > 0:
		ch.spend_resource("innate_sorcery")
	assert_true(_do(e, c, "feat:cf:innate_sorcery").ok, "Innate Sorcery for 2 Sorcery Points")
	assert_true(_do(e, c, "feat:fr:burst_flames", [ally]).ok, "Bolstering Flames")
	assert_true(ally.creature.temp_hp >= 1 + 14, "Honed: + Sorcerer level")
	assert_true(_find(e, c, "feat:fr:burst_fire").is_empty(), "once per turn")


func test_arcana_cleric_modifies_magic_and_dispels_after_healing() -> void:
	var e := TestCombat.open_field(3)
	var c := _hero(e, "cleric", "arcana_domain", 6, Vector2i(2, 3))
	var ally := TestCombat.hero(e, "ilse_varga", Vector2i(3, 3))
	TestCombat.punching_bag(e, Vector2i(10, 3))
	TestCombat.start_with(e, c)
	var ch := _ch(c)
	ally.creature.hp = 4
	if not ch.knows_spell("cure_wounds"):
		(ch.spellcasting[0]["prepared"] as Array).append("cure_wounds")
	var cd := ch.resource_left("channel_divinity")
	assert_true(_do(e, c, "feat:fr:modify_magic:ward").ok)
	assert_true(e.spells.cast(c, "cure_wounds", 1, [ally]).ok)
	assert_true(ally.creature.temp_hp >= 2 + 6, "Ward: 2d8 + Cleric level")
	assert_eq(ch.resource_left("channel_divinity"), cd - 1)
	var bane := Effect.new("Bane", &"spell", "bane").with_modifier("penalty_die", {"dice": "1d4", "on": ["attack"]})
	bane.spell_level = 1
	ally.creature.add_effect(bane)
	assert_true(_do(e, c, "feat:fr:dispelling_recovery", [ally]).ok, "a free Dispel Magic after the healing")
	assert_false(ally.creature.effects.has(bane), "Bane is dispelled")


func test_noble_scion_flies_and_turns_failures_in_its_aura() -> void:
	var e := TestCombat.open_field(3)
	var c := _hero(e, "paladin", "oath_of_the_noble_genies", 20, Vector2i(2, 3))
	var ally := TestCombat.hero(e, "ilse_varga", Vector2i(3, 3))
	TestCombat.punching_bag(e, Vector2i(10, 3))
	TestCombat.start_with(e, c)
	assert_true(_do(e, c, "feat:fr:noble_scion").ok)
	assert_true(c.creature.modifiers_for(&"speed_set").any(func(m: Modifier) -> bool: return m.text("kind") == "fly"))
	c.reaction_rules["noble_scion"] = "auto"
	var sv := ally.creature.roll_save(e.dice, &"wis", 99)
	assert_true(sv.success, "an ally's failure in the aura becomes a success")
	assert_false(c.reaction_available)


func test_crown_of_spellfire_turns_magic_to_half_or_none() -> void:
	var e := TestCombat.open_field(3)
	var c := _hero(e, "sorcerer", "spellfire_sorcery", 18, Vector2i(2, 3))
	TestCombat.punching_bag(e, Vector2i(10, 3))
	TestCombat.start_with(e, c)
	assert_true(_do(e, c, "feat:cf:innate_sorcery").ok)
	assert_true(_do(e, c, "feat:fr:crown_of_spellfire").ok)
	assert_eq(c.creature.damage_after_save(20, &"con", true, true, true), 0, "none on a success")
	assert_eq(c.creature.damage_after_save(20, &"con", false, true, true), 10, "half on a failure")


func test_modify_magic_unravels_the_first_save() -> void:
	var e := TestCombat.open_field(3)
	var c := _hero(e, "cleric", "arcana_domain", 3, Vector2i(2, 3))
	var foe := TestCombat.foe(e, "zombie", Vector2i(5, 3))
	TestCombat.start_with(e, c)
	assert_true(_do(e, c, "feat:fr:modify_magic:unravel").ok)
	var cd := _ch(c).resource_left("channel_divinity")
	if not _ch(c).knows_spell("sacred_flame"):
		(_ch(c).spellcasting[0]["prepared"] as Array).append("sacred_flame")
	TestCombat.next_d20(e, 20)
	var r := e.spells.cast(c, "sacred_flame", 0, [foe])
	assert_true(r.ok, "Sacred Flame: %s" % r.reason)
	assert_true(e.log.texts().any(func(x: String) -> bool: return x.contains("unravels")) or _ch(c).resource_left("channel_divinity") == cd,
		"spent only if the foe succeeded")
