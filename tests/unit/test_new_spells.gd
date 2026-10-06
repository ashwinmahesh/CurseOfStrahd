extends TestCase
## The 2024 PHB spells the Phase 4 classes brought in, each doing what its text says in a fight: smites cast on a
## hit, marks the caster carries, retaliation, Death Ward, Heroism, split damage types, summons, walls and the rest.


func _field() -> Encounter:
	return TestCombat.open_field(4)


func _melee(e: Encounter, c: Combatant) -> String:
	for o in e.attack_options(c):
		if bool(o["melee"]):
			return str(o["id"])
	return ""


func _ranged(e: Encounter, c: Combatant) -> String:
	var ch := c.creature as Character
	ch.add_item("shortbow")
	ch.add_item("arrow", 20)
	ch.equip("shortbow", "main_hand")
	for o in e.attack_options(c):
		if not bool(o["melee"]) and str(o["kind"]) == "weapon":
			return str(o["id"])
	return ""


func _logged(e: Encounter, text: String) -> bool:
	return e.log.entries.any(func(x: Dictionary) -> bool: return str(x["text"]).contains(text))


func _smite(e: Encounter, c: Combatant, t: Combatant, spell_id: String, ranged: bool = false, d20: int = 19) -> CombatResult:
	var opt := _ranged(e, c) if ranged else _melee(e, c)
	assert_true(e.features.toggle_rider(c, "smite:" + spell_id).ok, "arm " + spell_id)
	TestCombat.next_d20(e, d20)
	return e.attack(c, t, opt)


# --- Smites ---------------------------------------------------------------------------------------------

func test_divine_smite_adds_radiant_dice_and_more_against_undead() -> void:
	var e := _field()
	var c := TestCombat.caster_with(e, ["divine_smite"], Vector2i(2, 3))
	var z := TestCombat.punching_bag(e, Vector2i(3, 3), 200, "undead")
	TestCombat.start_with(e, c)
	var slots := (c.creature as Character).slots_left(1)
	var r := _smite(e, c, z, "divine_smite")
	assert_true(r.hit)
	assert_eq((c.creature as Character).slots_left(1), slots - 1)
	assert_true(_logged(e, "Divine Smite (undead)") or e.log.entries.any(func(x: Dictionary) -> bool:
		return (x.get("details", []) as Array).any(func(d: Variant) -> bool: return str(d).contains("Divine Smite (undead)"))), "the undead die")


func test_thunderous_smite_pushes_and_knocks_prone_on_a_failed_save() -> void:
	var e := _field()
	var c := TestCombat.caster_with(e, ["thunderous_smite"], Vector2i(2, 3))
	var t := TestCombat.punching_bag(e, Vector2i(3, 3), 200)
	TestCombat.start_with(e, c)
	assert_true(_smite(e, c, t, "thunderous_smite").hit)
	assert_true(t.creature.has_condition(&"prone"), "Prone")
	assert_true(t.cell.x >= 4, "pushed away: %s" % t.cell)


func test_searing_smite_burns_at_the_start_of_each_turn() -> void:
	var e := _field()
	var c := TestCombat.caster_with(e, ["searing_smite"], Vector2i(2, 3))
	var t := TestCombat.punching_bag(e, Vector2i(3, 3), 200)
	TestCombat.start_with(e, c)
	assert_true(_smite(e, c, t, "searing_smite").hit)
	assert_true(t.creature.has_flag("burning"))
	var hp := t.creature.hp
	e.end_turn()
	assert_eq(e.current(), t)
	assert_true(t.creature.hp < hp, "burning damage at the start of its turn")


func test_wrathful_smite_frightens() -> void:
	var e := _field()
	var c := TestCombat.caster_with(e, ["wrathful_smite"], Vector2i(2, 3))
	var t := TestCombat.punching_bag(e, Vector2i(3, 3), 300)
	TestCombat.start_with(e, c)
	assert_true(_smite(e, c, t, "wrathful_smite").hit)
	assert_true(t.creature.has_condition(&"frightened"))


func test_staggering_smite_stuns() -> void:
	var e := _field()
	var c := TestCombat.high_caster(e, ["staggering_smite"], Vector2i(2, 3))
	var t := TestCombat.punching_bag(e, Vector2i(3, 3), 300)
	TestCombat.start_with(e, c)
	assert_true(_smite(e, c, t, "staggering_smite").hit)
	assert_true(t.creature.has_condition(&"stunned"))


func test_ensnaring_strike_restrains_and_its_thorns_hurt() -> void:
	var e := _field()
	var c := TestCombat.caster_with(e, ["ensnaring_strike"], Vector2i(2, 3))
	var t := TestCombat.punching_bag(e, Vector2i(3, 3), 200)
	TestCombat.start_with(e, c)
	assert_true(_smite(e, c, t, "ensnaring_strike").hit)
	assert_true(t.creature.has_condition(&"restrained"))
	assert_true(c.creature.concentration != null and c.creature.concentration.source_id == "ensnaring_strike")
	var hp := t.creature.hp
	e.end_turn()
	assert_true(t.creature.hp < hp, "1d6 Piercing at the start of its turn")


func test_hail_of_thorns_bursts_around_a_ranged_hit() -> void:
	var e := _field()
	var c := TestCombat.caster_with(e, ["hail_of_thorns"], Vector2i(1, 3))
	var t := TestCombat.punching_bag(e, Vector2i(6, 3), 200)
	var near := TestCombat.punching_bag(e, Vector2i(7, 3), 200)
	TestCombat.start_with(e, c)
	assert_true(_smite(e, c, t, "hail_of_thorns", true).hit)
	assert_true(near.creature.hp < 200, "the creature beside the target is caught")


func test_hail_of_thorns_isnt_offered_on_a_melee_hit() -> void:
	var e := _field()
	var c := TestCombat.caster_with(e, ["hail_of_thorns"], Vector2i(2, 3))
	var t := TestCombat.punching_bag(e, Vector2i(3, 3), 200)
	TestCombat.start_with(e, c)
	var slots := (c.creature as Character).slots_left(1)
	assert_true(_smite(e, c, t, "hail_of_thorns").hit)
	assert_eq((c.creature as Character).slots_left(1), slots, "no slot spent on a melee hit")


func test_lightning_arrow_replaces_the_shot_and_still_bursts_on_a_miss() -> void:
	var e := _field()
	var c := TestCombat.caster_with(e, ["lightning_arrow"], Vector2i(1, 3))
	var t := TestCombat.punching_bag(e, Vector2i(6, 3), 200)
	var near := TestCombat.punching_bag(e, Vector2i(7, 3), 200)
	TestCombat.start_with(e, c)
	var r := _smite(e, c, t, "lightning_arrow", true, 1)
	assert_false(r.hit)
	assert_true(t.creature.hp < 200, "half the bolt on a miss")
	assert_true(near.creature.hp < 200, "the burst still goes off")


# --- Marks ----------------------------------------------------------------------------------------------

func test_hunters_mark_adds_force_damage_to_hits_on_its_quarry() -> void:
	var e := _field()
	var c := TestCombat.caster_with(e, ["hunters_mark"], Vector2i(2, 3))
	var t := TestCombat.punching_bag(e, Vector2i(3, 3), 200)
	TestCombat.start_with(e, c)
	assert_true(e.spells.cast(c, "hunters_mark", 1, [t]).ok)
	c.action_available = true
	TestCombat.next_d20(e, 19)
	assert_true(e.attack(c, t, _melee(e, c)).hit)
	assert_true(e.log.entries.any(func(x: Dictionary) -> bool:
		return (x.get("details", []) as Array).any(func(d: Variant) -> bool: return str(d).contains("Hunter's Mark"))))


func test_hex_curses_an_ability_and_adds_necrotic_damage() -> void:
	var e := _field()
	var c := TestCombat.caster_with(e, ["hex"], Vector2i(2, 3))
	var t := TestCombat.punching_bag(e, Vector2i(3, 3), 200)
	TestCombat.start_with(e, c)
	assert_true(e.spells.cast(c, "hex", 1, [t], Vector2.INF, Vector2.ZERO, {"choice": "str"}).ok)
	assert_eq(c.creature.modifiers_for(&"extra_damage").size(), 1)
	assert_true(t.creature.effects.any(func(fx: Effect) -> bool: return fx.source_id == "hex"), "the ability curse sits on the target")


# --- Defences -------------------------------------------------------------------------------------------

func test_armor_of_agathys_freezes_melee_attackers_and_ends_without_temp_hp() -> void:
	var e := _field()
	var c := TestCombat.caster_with(e, ["armor_of_agathys"], Vector2i(2, 3))
	var w := TestCombat.foe(e, "zombie", Vector2i(3, 3))
	w.creature.hp = 100
	TestCombat.start_with(e, c)
	assert_true(e.spells.cast(c, "armor_of_agathys", 2).ok)
	assert_eq(c.creature.temp_hp, 10, "5 + 5 per slot level above 1")
	var hp := w.creature.hp
	e.retaliate(w, c)
	assert_eq(w.creature.hp, hp - 10, "10 Cold at level 2")
	e.deal_damage(w, c, [{"amount": 15, "type": "slashing"}], false, "test")
	assert_false(c.creature.effects.any(func(fx: Effect) -> bool: return fx.source_id == "armor_of_agathys"), "ends with the Temporary Hit Points")


func test_death_ward_keeps_its_bearer_up_once() -> void:
	var e := _field()
	var c := TestCombat.high_caster(e, ["death_ward"], Vector2i(2, 3))
	var a := TestCombat.hero(e, "ilse_varga", Vector2i(3, 3))
	TestCombat.start_with(e, c)
	assert_true(e.spells.cast(c, "death_ward", 4, [a]).ok)
	e.deal_damage(null, a, [{"amount": a.creature.hp + 5, "type": "slashing"}], false, "test")
	assert_eq(a.creature.hp, 1)
	assert_false(a.creature.has_flag("death_ward"), "used up")
	e.deal_damage(null, a, [{"amount": 3, "type": "slashing"}], false, "test")
	assert_eq(a.creature.hp, 0)


func test_heroism_grants_temp_hp_at_the_start_of_each_turn() -> void:
	var e := _field()
	var c := TestCombat.caster_with(e, ["heroism"], Vector2i(2, 3))
	var t := TestCombat.punching_bag(e, Vector2i(6, 6), 50)
	TestCombat.start_with(e, c)
	assert_true(e.spells.cast(c, "heroism", 1, [c]).ok)
	assert_eq(c.creature.temp_hp, 0, "nothing on the cast itself")
	e.end_turn()
	while e.current() != c:
		e.end_turn()
	assert_true(c.creature.temp_hp > 0)
	assert_true(t.is_alive())


func test_fire_shield_burns_a_melee_attacker() -> void:
	var e := _field()
	var c := TestCombat.high_caster(e, ["fire_shield"], Vector2i(2, 3))
	var w := TestCombat.foe(e, "zombie", Vector2i(3, 3))
	w.creature.hp = 100
	TestCombat.start_with(e, c)
	assert_true(e.spells.cast(c, "fire_shield", 4, [], Vector2.INF, Vector2.ZERO, {"choice": "chill"}).ok)
	e.retaliate(w, c)
	assert_true(w.creature.hp < 100)
	assert_true(_logged(e, "Cold"), "the chill shield strikes back with Cold")


# --- Damage -------------------------------------------------------------------------------------------------

func test_ice_storm_deals_bludgeoning_and_cold_separately() -> void:
	var e := _field()
	var c := TestCombat.high_caster(e, ["ice_storm"], Vector2i(1, 1))
	var t := TestCombat.punching_bag(e, Vector2i(6, 6), 200)
	t.creature.add_effect(Effect.new("Cold-proof", &"effect", "test").with_modifier("immunity", {"value": "cold"}))
	TestCombat.start_with(e, c)
	assert_true(e.spells.cast(c, "ice_storm", 4, [], Vector2(6.5, 6.5)).ok)
	assert_true(t.creature.hp < 200, "the Bludgeoning half still lands on a creature immune to Cold")
	assert_true(e.spells.zones.difficult_cells(t).has(t.cell), "hail makes Difficult Terrain")
