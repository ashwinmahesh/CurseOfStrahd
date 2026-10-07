extends TestCase
## Heroes of Faerûn and Arcana Unleashed spells that were text-only, now with rules (batch 4), cast with the real data.


func _cast(e: Encounter, c: Combatant, id: String, targets: Array = [], point: Vector2 = Vector2.INF, opts: Dictionary = {}, slot: int = 0) -> CombatResult:
	var data := Compendium.shared().spell_data(id)
	return e.spells.cast_with_numbers(c, id, maxi(slot, int(data["level"])), targets, point,
		{"dc": Breakdown.new("DC").add("test", 40), "attack": Breakdown.new("Attack").add("test", 30), "mod": 5}, opts)


func _order(e: Encounter, first: Combatant, rest: Array) -> void:
	TestCombat.start_with(e, first)
	var init := 20
	for x: Variant in rest:
		(x as Combatant).initiative = init
		init -= 1
	e.order.sort_custom(func(a: Combatant, b: Combatant) -> bool: return a.initiative > b.initiative)


func test_grave_ground_hinders_enemies_only_and_saps_their_damage() -> void:
	var e := TestCombat.open_field(1)
	var c := TestCombat.caster_with(e, ["grave_ground"], Vector2i(1, 3))
	var foe := TestCombat.punching_bag(e, Vector2i(6, 3), 500)
	var ally := TestCombat.hero(e, "ilse_varga", Vector2i(6, 4))
	TestCombat.start_with(e, c)
	assert_true(_cast(e, c, "grave_ground", [], Vector2(6.5, 4.0)).ok)
	assert_true(foe.creature.hp < 500, "an enemy there as it appears fails its Strength save")
	assert_false(foe.creature.modifiers_for(&"damage_penalty_die").is_empty(), "−1d6 on its damage rolls")
	assert_true(e.spells.zones.difficult_cells(foe).has(Vector2i(6, 3)), "Difficult Terrain for an enemy")
	assert_false(e.spells.zones.difficult_cells(ally).has(Vector2i(6, 4)), "not for an ally")
	assert_eq(ally.creature.hp, ally.creature.max_hp(), "allies are spared")


func test_spellfire_storm_burns_and_makes_casting_inside_a_gamble() -> void:
	var e := TestCombat.open_field(1)
	var c := TestCombat.caster_with(e, ["spellfire_storm"], Vector2i(1, 3))
	var foe := TestCombat.punching_bag(e, Vector2i(6, 3), 500)
	TestCombat.start_with(e, c)
	assert_true(_cast(e, c, "spellfire_storm", [], Vector2(6.5, 3.5)).ok)
	assert_true(foe.creature.hp < 500, "Radiant damage as it appears")
	assert_true(foe.creature.effects.any(func(fx: Effect) -> bool: return fx.data.has("casting_save")), "casting inside takes a Constitution save")
	assert_false(c.creature.effects.any(func(fx: Effect) -> bool: return fx.data.has("casting_save")), "the caster stands outside")


func test_doomtide_darkens_hurts_and_drifts_away_each_turn() -> void:
	var e := TestCombat.encounter(["....................", "....................", "....................", "....................",
		"....................", "....................", "...................."], 1)
	var c := TestCombat.caster_with(e, ["doomtide"], Vector2i(1, 3))
	var foe := TestCombat.punching_bag(e, Vector2i(8, 3), 500)
	_order(e, c, [foe])
	assert_true(_cast(e, c, "doomtide", [], Vector2(8.5, 3.5)).ok)
	assert_true(foe.creature.hp < 500)
	assert_false(foe.creature.modifiers_for(&"penalty_die").is_empty(), "−1d6 on its saves")
	var zone := e.spells.zones.object_of(c.id, "doomtide")
	assert_true(e.spells.zones.magical_darkness(Vector2i(8, 3)), "magical Darkness")
	var before := zone.cell
	e.end_turn()
	e.end_turn()
	assert_eq(zone.cell.x - before.x, 2, "10 ft away from the caster as its turn starts")


func test_dirge_stops_enemy_healing_and_knocks_down() -> void:
	var e := TestCombat.open_field(1)
	var c := TestCombat.caster_with(e, ["dirge"], Vector2i(2, 3), 20)
	var foe := TestCombat.punching_bag(e, Vector2i(5, 3), 500)
	var ally := TestCombat.hero(e, "ilse_varga", Vector2i(3, 3))
	_order(e, c, [foe, ally])
	assert_true(_cast(e, c, "dirge").ok)
	assert_true(foe.creature.has_flag("cant_regain_hp"), "no healing for a foe inside")
	assert_false(ally.creature.has_flag("cant_regain_hp"), "allies spared")
	e.end_turn()
	e.end_turn()
	assert_true(foe.creature.hp < 500 and foe.creature.has_condition(&"prone"), "ending its turn there: Necrotic and Prone")


func test_songals_suffusion_resists_flies_and_pulses_each_turn() -> void:
	var e := TestCombat.open_field(1)
	var c := TestCombat.caster_with(e, ["songals_elemental_suffusion"], Vector2i(2, 3))
	var foe := TestCombat.punching_bag(e, Vector2i(4, 3), 500)
	_order(e, c, [foe])
	assert_true(_cast(e, c, "songals_elemental_suffusion", [], Vector2.INF, {"choice": "cold"}).ok)
	assert_true(c.creature.modifiers_for(&"resistance").any(func(m: Modifier) -> bool: return m.text("value") == "cold"))
	assert_true(c.creature.modifiers_for(&"speed_set").any(func(m: Modifier) -> bool: return m.text("kind") == "fly"))
	assert_true(foe.creature.hp < 500 and foe.creature.has_condition(&"prone"), "the pulse as it's cast")
	var hp := foe.creature.hp
	foe.creature.remove_condition(&"prone")
	e.end_turn()
	e.end_turn()
	assert_true(foe.creature.hp < hp, "again as the caster's turn starts")


func test_alustriels_mooncloak_shelters_allies_and_ends_to_heal_or_resist() -> void:
	var e := TestCombat.open_field(1)
	var c := TestCombat.caster_with(e, ["alustriels_mooncloak"], Vector2i(2, 3))
	var ally := TestCombat.hero(e, "ilse_varga", Vector2i(3, 3))
	TestCombat.punching_bag(e, Vector2i(9, 3))
	TestCombat.start_with(e, c)
	assert_true(_cast(e, c, "alustriels_mooncloak").ok)
	assert_true(ally.creature.has_flag("half_cover"), "Half Cover in the moonlight")
	assert_true(ally.creature.modifiers_for(&"resistance").any(func(m: Modifier) -> bool: return m.text("value") == "radiant"))
	ally.creature.hp = 5
	c.action_available = true
	c.magic_action_used = false
	var a := ActionCatalog.new(e).find(c, "sustain:alustriels_mooncloak:0")
	if a.is_empty():
		for x in ActionCatalog.new(e).actions_for(c):
			if str(x.get("spell_id", "")) == "alustriels_mooncloak":
				a = x
	assert_false(a.is_empty(), "the healing action")
	var hr := ActionCatalog.new(e).perform(c, a, [ally])
	assert_true(hr.ok, "heal: %s %s" % [hr.reason, a])
	assert_true(ally.creature.hp > 5, "healed")
	assert_true(c.creature.concentration == null, "and the spell ends")
	var e2 := TestCombat.open_field(1)
	var c2 := TestCombat.caster_with(e2, ["alustriels_mooncloak"], Vector2i(2, 3))
	TestCombat.punching_bag(e2, Vector2i(9, 3))
	TestCombat.start_with(e2, c2)
	assert_true(_cast(e2, c2, "alustriels_mooncloak").ok)
	c2.reaction_rules["alustriels_mooncloak"] = "auto"
	var sv := c2.creature.roll_save(e2.dice, &"wis", 99, [], [], "", ["save_vs:frightened"])
	assert_true(sv.success, "the moonlight turns a failed save against fear into a success")
	assert_true(c2.creature.concentration == null, "spending the spell")


func test_wither_and_bloom_hurts_foes_and_mends_an_ally() -> void:
	var e := TestCombat.open_field(1)
	var c := TestCombat.caster_with(e, ["wither_and_bloom"], Vector2i(1, 3))
	var foe := TestCombat.punching_bag(e, Vector2i(6, 3), 500)
	var ally := TestCombat.hero(e, "ilse_varga", Vector2i(6, 4))
	TestCombat.start_with(e, c)
	ally.creature.hp = 3
	var spent := 0
	for k: String in (ally.creature as Character).hit_dice_spent:
		spent += int((ally.creature as Character).hit_dice_spent[k])
	var wr := _cast(e, c, "wither_and_bloom", [], Vector2(6.5, 3.5))
	assert_true(wr.ok, "cast: %s" % wr.reason)
	assert_true(foe.creature.hp < 500, "the foe withers")
	assert_true(ally.creature.hp > 3, "the ally blooms")
	var after := 0
	for k: String in (ally.creature as Character).hit_dice_spent:
		after += int((ally.creature as Character).hit_dice_spent[k])
	assert_eq(after, spent + 1, "one Hit Die at level 2")


func test_negative_energy_flood_feeds_undead_and_raises_the_slain() -> void:
	var e := TestCombat.open_field(1)
	var c := TestCombat.caster_with(e, ["negative_energy_flood"], Vector2i(1, 3), 20)
	var zombie := TestCombat.foe(e, "zombie", Vector2i(5, 3))
	var victim := TestCombat.punching_bag(e, Vector2i(5, 5), 10, "humanoid")
	_order(e, c, [zombie, victim])
	assert_true(_cast(e, c, "negative_energy_flood", [zombie]).ok)
	assert_true(zombie.creature.temp_hp > 0, "Undead gain Temporary Hit Points")
	c.action_available = true
	c.magic_action_used = false
	c.cast_slot_spell_this_turn = false
	assert_true(_cast(e, c, "negative_energy_flood", [victim]).ok)
	assert_true(victim.creature.dead, "slain")
	var before := e.combatants.size()
	e.end_turn()
	e.end_turn()
	e.end_turn()
	assert_eq(e.combatants.size(), before + 1, "a Zombie rises as the caster's turn starts")
	var risen := e.combatants[e.combatants.size() - 1]
	assert_true(risen.allied_with(c), "on the caster's side")


func test_simbuls_synostodweomer_heals_after_a_slotted_spell() -> void:
	var e := TestCombat.open_field(1)
	var c := TestCombat.caster_with(e, ["simbuls_synostodweomer", "magic_missile"], Vector2i(2, 3), 20)
	var foe := TestCombat.punching_bag(e, Vector2i(6, 3), 500)
	TestCombat.start_with(e, c)
	assert_true(_cast(e, c, "simbuls_synostodweomer", [c]).ok)
	c.creature.hp = 5
	c.action_available = true
	c.magic_action_used = false
	c.cast_slot_spell_this_turn = false
	assert_true(e.spells.cast(c, "magic_missile", 3, [foe]).ok)
	assert_true(c.creature.hp > 5, "Hit Dice up to the slot's level, plus the modifier")


func _sustain(e: Encounter, c: Combatant, spell_id: String, mode: String = "") -> Dictionary:
	for x in ActionCatalog.new(e).actions_for(c):
		if str(x.get("kind", "")) != "sustain" or str(x.get("spell_id", "")) != spell_id:
			continue
		if mode == "" or str(x.get("label", "")).contains(mode):
			return x
	return {}


func test_backlash_cuts_an_attack_and_lashes_back() -> void:
	var e := TestCombat.open_field(4)
	var c := TestCombat.caster_with(e, ["backlash"], Vector2i(2, 3), 9)
	var foe := TestCombat.foe(e, "zombie", Vector2i(3, 3))
	_order(e, foe, [c])
	c.reaction_rules["backlash"] = "ask"
	c.reaction_rules["shield"] = "never"
	TestCombat.next_d20(e, 19)
	var r := e.monster_attack(foe, c, "slam")
	assert_true(r.ok)
	assert_true(e.pending != null and e.pending.kind == "backlash", "asked against an attack")
	if e.pending == null:
		return
	var slots := (c.creature as Character).slots_left(4)
	var hp := foe.creature.hp
	assert_true(e.answer_reaction(true).ok)
	assert_eq((c.creature as Character).slots_left(4), slots - 1, "a level 4 slot")
	assert_true(foe.creature.hp < hp, "the zombie takes Force damage")
	assert_false(c.reaction_available)


func test_effulgent_spheres_hurl_and_ward() -> void:
	var e := TestCombat.open_field(4)
	var c := TestCombat.caster_with(e, ["elminsters_effulgent_spheres"], Vector2i(2, 3), 20)
	var foe := TestCombat.punching_bag(e, Vector2i(6, 3), 500)
	TestCombat.start_with(e, c)
	assert_true(_cast(e, c, "elminsters_effulgent_spheres", [], Vector2.INF, {"choice": "cold"}).ok)
	assert_eq(int(c.get_meta("effulgent_spheres", 0)), 6)
	var a := _sustain(e, c, "elminsters_effulgent_spheres")
	assert_false(a.is_empty(), "Hurl a sphere")
	TestCombat.next_d20(e, 19)
	assert_true(ActionCatalog.new(e).perform(c, a, [foe]).ok)
	assert_eq(int(c.get_meta("effulgent_spheres", 0)), 5)
	assert_true(foe.creature.hp < 500, "Cold damage")
	c.reaction_rules["elminsters_effulgent_spheres"] = "auto"
	var hp := c.creature.hp
	e.deal_damage(foe, c, [{"amount": 10, "type": "fire", "spell": true}], false, "Fire")
	assert_eq(c.creature.hp, hp - 5, "a sphere's ward halves the Fire")
	assert_eq(int(c.get_meta("effulgent_spheres", 0)), 4)


func test_holy_star_shoots_shields_and_turns_spells() -> void:
	var e := TestCombat.open_field(4)
	var c := TestCombat.caster_with(e, ["holy_star_of_mystra"], Vector2i(2, 3), 20)
	var foe := TestCombat.punching_bag(e, Vector2i(6, 3), 500)
	TestCombat.start_with(e, c)
	TestCombat.next_d20(e, 19)
	assert_true(_cast(e, c, "holy_star_of_mystra", [foe], Vector2.INF, {"choice": "radiant"}).ok)
	assert_true(foe.creature.hp < 500, "the star strikes as it's cast")
	assert_true(c.creature.has_flag("three_quarters_cover"))
	var archer := TestCombat.foe(e, "zombie", Vector2i(3, 4))
	assert_eq(int(e.attack_situation(archer, c, e.attack_options(archer)[0])["cover"]), CombatGrid.Cover.THREE_QUARTERS)
	assert_false(_sustain(e, c, "holy_star_of_mystra").is_empty(), "a Bonus Action strike later")


func test_spirit_lantern_gathers_fragments_and_spends_them() -> void:
	var e := TestCombat.open_field(4)
	var c := TestCombat.caster_with(e, ["spirit_lantern"], Vector2i(2, 3), 20)
	var weak := TestCombat.punching_bag(e, Vector2i(4, 3), 3)
	var foe := TestCombat.punching_bag(e, Vector2i(6, 3), 500)
	TestCombat.start_with(e, c)
	assert_true(_cast(e, c, "spirit_lantern").ok)
	e.deal_damage(c, weak, [{"amount": 10, "type": "fire"}], false, "Fire")
	assert_eq(int(c.get_meta("lantern_fragments", 0)), 1, "a fragment from an enemy dying in its light")
	var a := _sustain(e, c, "spirit_lantern", "drain")
	assert_true(ActionCatalog.new(e).perform(c, a, [foe]).ok)
	assert_true(foe.creature.hp < 500)
	assert_eq(int(c.get_meta("lantern_fragments", 0)), 0)


func test_transfix_draws_its_victim_in_and_hurts_it_close() -> void:
	var e := TestCombat.encounter(["................", "................", "................", "................", "................"], 4)
	var c := TestCombat.caster_with(e, ["transfix"], Vector2i(1, 2), 20)
	var foe := TestCombat.foe(e, "zombie", Vector2i(6, 2))
	_order(e, c, [foe])
	assert_true(_cast(e, c, "transfix", [foe]).ok)
	assert_true(foe.creature.has_condition(&"charmed") and foe.creature.has_condition(&"incapacitated"))
	e.end_turn()
	var before := e.distance(foe, c)
	var hp := foe.creature.hp
	e.run_ai_turn()
	assert_true(e.distance(foe, c) < before, "it walks toward the caster")
	if e.distance(foe, c) <= 5:
		assert_true(foe.creature.hp < hp, "ending its turn beside the caster hurts")


func test_illusory_dragon_frightens_and_breathes() -> void:
	var e := TestCombat.encounter(["....................", "....................", "....................", "....................",
		"....................", "....................", "...................."], 4)
	var c := TestCombat.caster_with(e, ["illusory_dragon"], Vector2i(1, 3), 20)
	var foe := TestCombat.punching_bag(e, Vector2i(12, 3), 500)
	TestCombat.start_with(e, c)
	var dr := _cast(e, c, "illusory_dragon", [], Vector2(6.5, 3.5), {"choice": "cold"})
	assert_true(dr.ok, "cast: %s" % dr.reason)
	assert_true(foe.creature.has_condition(&"frightened"), "cowed by its appearance")
	var a := _sustain(e, c, "illusory_dragon")
	assert_false(a.is_empty())
	assert_true(ActionCatalog.new(e).perform(c, a, [], Vector2(12.5, 3.5)).ok)
	assert_true(foe.creature.hp < 500, "the breath")


func test_distorted_distance_speeds_allies_and_snares_foes() -> void:
	var e := TestCombat.open_field(4)
	var c := TestCombat.caster_with(e, ["distorted_distance"], Vector2i(2, 3), 20)
	var ally := TestCombat.hero(e, "ilse_varga", Vector2i(5, 3))
	var foe := TestCombat.punching_bag(e, Vector2i(6, 3), 500)
	TestCombat.start_with(e, c)
	var spd := ally.speed()
	assert_true(_cast(e, c, "distorted_distance", [], Vector2(6.5, 3.5)).ok)
	assert_eq(ally.speed(), spd + 20, "an ally gains 20 ft")
	assert_true(foe.creature.hp < 500 and foe.creature.has_flag("distorted_distance"), "a foe fails")
	assert_true(e.spells.zones.difficult_cells(foe).has(Vector2i(6, 3)), "the Sphere is Difficult Terrain for it")
	assert_false(e.spells.zones.difficult_cells(ally).has(Vector2i(6, 3)), "not for the ally")


func test_conjure_constructs_strike_foes_and_shield_allies() -> void:
	var e := TestCombat.open_field(4)
	var c := TestCombat.caster_with(e, ["conjure_constructs"], Vector2i(2, 3), 20)
	var foe := TestCombat.punching_bag(e, Vector2i(6, 3), 500)
	var ally := TestCombat.hero(e, "ilse_varga", Vector2i(6, 5))
	TestCombat.start_with(e, c)
	var cr := _cast(e, c, "conjure_constructs", [foe])
	assert_true(cr.ok, "cast: %s" % cr.reason)
	assert_true(foe.creature.hp < 500, "Force damage as they gather")
	var obj := e.spells.zones.object_of(c.id, "conjure_constructs")
	assert_true(obj != null and e.grid.distance_ft(obj.cell, 1, foe.cell, 1) <= 5, "beside the target")
	var mv := _sustain(e, c, "conjure_constructs", "Move")
	var mr := ActionCatalog.new(e).perform(c, mv, [], Vector2(6.5, 4.5)) if not mv.is_empty() else CombatResult.fail("no move action")
	assert_true(mr.ok, "move the spirits: %s" % mr.reason)
	e.end_turn()
	while e.current() != c:
		e.end_turn()
	var act := _sustain(e, c, "conjure_constructs", "act")
	var ar := ActionCatalog.new(e).perform(c, act, [ally]) if not act.is_empty() else CombatResult.fail("no act action")
	assert_true(ar.ok, "act: %s" % ar.reason)
	assert_true(ally.creature.temp_hp > 0, "an ally gains Temporary Hit Points")


func test_backlash_on_automatic_answers_spell_damage_too() -> void:
	var e := TestCombat.open_field(4)
	var c := TestCombat.caster_with(e, ["backlash"], Vector2i(2, 3), 9)
	var foe := TestCombat.punching_bag(e, Vector2i(4, 3), 500)
	TestCombat.start_with(e, c)
	var hp := c.creature.hp
	var dr := e.deal_damage(foe, c, [{"amount": 10, "type": "fire", "spell": true}], false, "Fire")
	assert_eq(dr.final, 10, "on Ask a spell's damage can't wait for an answer")
	c.reaction_rules["backlash"] = "auto"
	c.creature.hp = hp
	var dr2 := e.deal_damage(foe, c, [{"amount": 10, "type": "fire", "spell": true}], false, "Fire")
	assert_true(dr2.final < 10, "Automatic: cut by 4d6 + modifier")
	assert_true(foe.creature.hp < 500, "and the caster lashes back")
