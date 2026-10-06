extends TestCase
## Spells and Channel Divinity in combat (2024 PHB "Spells", "Cleric", "Wizard").


func _wizard_vs(monsters: Array, seed_value: int = 1) -> Encounter:
	var e := TestCombat.open_field(seed_value)
	TestCombat.hero(e, "silvain_aster", Vector2i(1, 3))
	var x := 5
	for id: String in monsters:
		TestCombat.foe(e, id, Vector2i(x, 3))
		x += 1
	return e


func test_spell_list_says_what_can_be_cast_and_why_not() -> void:
	var e := _wizard_vs(["wolf"])
	var s := e.combatants[0]
	TestCombat.start_with(e, s)
	var by_id := {}
	for entry in e.spells.castable(s):
		by_id[str(entry["id"])] = entry
	assert_true(bool((by_id["magic_missile"] as Dictionary)["legal"]))
	assert_false(bool((by_id["shield"] as Dictionary)["legal"]), "Shield waits for its trigger")
	assert_false(bool((by_id["find_familiar"] as Dictionary)["legal"]), "takes an hour")
	assert_true(bool((by_id["fire_bolt"] as Dictionary)["legal"]))


func test_magic_missile_always_hits_and_spends_a_slot() -> void:
	var e := _wizard_vs(["wolf", "wolf"])
	var s := e.combatants[0]
	var w1 := e.combatants[1]
	var w2 := e.combatants[2]
	TestCombat.start_with(e, s)
	var r := e.spells.cast(s, "magic_missile", 1, [w1, w1, w2])
	assert_true(r.ok, r.reason)
	assert_eq((s.creature as Character).slots_left(1), 3)
	assert_true(w1.creature.hp <= w1.creature.max_hp() - 4, "two darts of 2-5")
	assert_true(w2.creature.hp <= w2.creature.max_hp() - 2)
	assert_false(s.action_available)


func test_one_slot_spell_per_turn() -> void:
	var e := TestCombat.open_field()
	var h := TestCombat.hero(e, "hedda_ironvow", Vector2i(1, 3))
	var ally := TestCombat.hero(e, "ilse_varga", Vector2i(2, 3))
	var z := TestCombat.foe(e, "zombie", Vector2i(8, 3))
	z.creature.hp = 100
	TestCombat.start_with(e, h)
	assert_true(e.spells.cast(h, "guiding_bolt", 1, [z]).ok)
	var r := e.spells.cast(h, "healing_word", 1, [ally])
	assert_false(r.ok)
	assert_true(r.reason.contains("slot"), r.reason)
	# Toll the Dead needs the action Guiding Bolt already used.
	assert_false(e.spells.cast(h, "toll_the_dead", 0, [z]).ok)


func test_healing_word_adds_disciple_of_life() -> void:
	var e := TestCombat.open_field(4)
	var h := TestCombat.hero(e, "hedda_ironvow", Vector2i(1, 3))
	var ally := TestCombat.hero(e, "ilse_varga", Vector2i(6, 3))
	TestCombat.foe(e, "zombie", Vector2i(10, 7))
	TestCombat.start_with(e, h)
	ally.creature.hp = 5
	var r := e.spells.cast(h, "healing_word", 1, [ally])
	assert_true(r.ok, r.reason)
	# 2d4 + Wis 3 + Disciple of Life (2 + slot level 1) = 8 to 14.
	assert_between(ally.creature.hp, 13, 19)
	assert_false(h.bonus_available)
	assert_true(h.action_available)


func test_burning_hands_cone_with_dex_saves() -> void:
	var e := TestCombat.open_field(9)
	var s := TestCombat.hero(e, "silvain_aster", Vector2i(1, 3))
	var w1 := TestCombat.foe(e, "wolf", Vector2i(3, 3))
	var w2 := TestCombat.foe(e, "wolf", Vector2i(3, 2))
	var far := TestCombat.foe(e, "wolf", Vector2i(9, 3))
	TestCombat.start_with(e, s)
	# Burning Hands isn't prepared by the pregen; prepare it for this test.
	(s.creature as Character).build["choices"]["wizard.prepared"].append("burning_hands")
	(s.creature as Character).refresh()
	var r := e.spells.cast(s, "burning_hands", 1, [], Vector2.INF, Vector2.RIGHT)
	assert_true(r.ok, r.reason)
	assert_true(w1.creature.hp < w1.creature.max_hp(), "in the cone")
	assert_eq(far.creature.hp, far.creature.max_hp(), "out of the cone")
	assert_true(w2.creature.hp <= w2.creature.max_hp())


func test_sleep_takes_wolves_but_not_zombies() -> void:
	var e := TestCombat.open_field(12)
	var s := TestCombat.hero(e, "silvain_aster", Vector2i(1, 3))
	var w := TestCombat.foe(e, "wolf", Vector2i(6, 3))
	var z := TestCombat.foe(e, "zombie", Vector2i(6, 4))
	TestCombat.start_with(e, s)
	TestCombat.next_d20(e, 2)
	var r := e.spells.cast(s, "sleep", 1, [], Vector2(7, 4))
	assert_true(r.ok, r.reason)
	assert_true(w.creature.has_condition(&"incapacitated"), "a failed save")
	assert_false(z.creature.has_condition(&"incapacitated"), "zombies don't sleep")
	assert_true(s.creature.concentration != null)
	# Damage wakes it.
	e.deal_damage(s, w, [{"amount": 1, "type": "fire"}], false, "test")
	assert_false(w.creature.has_condition(&"incapacitated"))


func test_bless_concentration_on_three_allies() -> void:
	var e := TestCombat.open_field()
	var h := TestCombat.hero(e, "hedda_ironvow", Vector2i(1, 3))
	var i := TestCombat.hero(e, "ilse_varga", Vector2i(2, 3))
	var t := TestCombat.hero(e, "tamsin_tealeaf", Vector2i(2, 4))
	TestCombat.foe(e, "zombie", Vector2i(10, 7))
	TestCombat.start_with(e, h)
	assert_true(e.spells.cast(h, "bless", 1, [h, i, t]).ok)
	assert_eq(h.creature.concentration.effect_count(), 3)
	assert_eq(i.creature.modifiers_for(&"bonus_die").size(), 1)
	h.creature.concentration.end("test")
	assert_eq(i.creature.modifiers_for(&"bonus_die").size(), 0)


func test_guiding_bolt_grants_advantage_to_the_next_attack() -> void:
	var e := TestCombat.open_field(3)
	var h := TestCombat.hero(e, "hedda_ironvow", Vector2i(1, 3))
	var ilse := TestCombat.hero(e, "ilse_varga", Vector2i(6, 4))
	var w := TestCombat.foe(e, "dire_wolf", Vector2i(7, 3))
	w.creature.hp = 100
	TestCombat.start_with(e, h)
	TestCombat.next_d20(e, 18)
	var r := e.spells.cast(h, "guiding_bolt", 1, [w])
	assert_true(r.hit)
	var sword := e.option_by_id(ilse, "weapon:greatsword")
	assert_true((e.attack_situation(ilse, w, sword)["advantage"] as Array).has("Guiding Bolt"))
	e.end_turn()
	assert_true(e.marks.any(func(m: Dictionary) -> bool: return str(m["source"]) == "Guiding Bolt"), "lasts until the end of Hedda's next turn")


func test_command_grovel_on_the_targets_turn() -> void:
	var e := TestCombat.open_field(5)
	var h := TestCombat.hero(e, "hedda_ironvow", Vector2i(1, 3))
	var w := TestCombat.foe(e, "wolf", Vector2i(6, 3))
	TestCombat.start_with(e, h)
	TestCombat.next_d20(e, 2)
	var r := e.spells.cast(h, "command", 1, [w], Vector2.INF, Vector2.ZERO, {"word": "grovel"})
	assert_true(r.ok, r.reason)
	assert_true(w.creature.has_flag("command_grovel"))
	assert_false(w.creature.has_condition(&"prone"), "it obeys on its own turn")
	e.end_turn()
	assert_eq(e.current().id, w.id)
	e.run_ai_turn()
	assert_true(w.creature.has_condition(&"prone"))
	assert_eq(w.cell, Vector2i(6, 3), "grovelling ends its turn")


func test_turn_undead_makes_zombies_flee() -> void:
	var e := TestCombat.open_field(6)
	var h := TestCombat.hero(e, "hedda_ironvow", Vector2i(3, 3))
	var z := TestCombat.foe(e, "zombie", Vector2i(5, 3))
	var w := TestCombat.foe(e, "wolf", Vector2i(4, 4))
	TestCombat.start_with(e, h)
	TestCombat.next_d20(e, 3)
	var r := e.features.turn_undead(h)
	assert_true(r.ok, r.reason)
	assert_true(z.creature.has_condition(&"frightened") and z.creature.has_condition(&"incapacitated"))
	assert_false(w.creature.has_condition(&"frightened"), "only Undead")
	assert_eq((h.creature as Character).resource_left("channel_divinity"), 1)
	var d0 := e.distance(h, z)
	e.turn_index = e.order.find(z)
	e._begin_turn()
	e.run_ai_turn()
	assert_true(e.distance(h, z) > d0, "it fled")
	e.deal_damage(h, z, [{"amount": 1, "type": "bludgeoning"}], false, "test")
	assert_false(z.creature.has_condition(&"frightened"), "damage ends the turning")


func test_preserve_life_heals_bloodied_allies_up_to_half() -> void:
	var e := TestCombat.open_field()
	var h := TestCombat.hero(e, "hedda_ironvow", Vector2i(1, 3))
	var i := TestCombat.hero(e, "ilse_varga", Vector2i(2, 3))
	var t := TestCombat.hero(e, "tamsin_tealeaf", Vector2i(2, 4))
	TestCombat.foe(e, "zombie", Vector2i(10, 7))
	TestCombat.start_with(e, h)
	i.creature.hp = 4
	t.creature.hp = 20
	var r := e.features.preserve_life(h)
	assert_true(r.ok, r.reason)
	assert_eq(i.creature.hp, i.creature.max_hp() / 2, "up to half its maximum")
	assert_eq(t.creature.hp, 20, "not Bloodied")


func test_divine_spark_harms_with_a_con_save() -> void:
	var e := TestCombat.open_field(8)
	var h := TestCombat.hero(e, "hedda_ironvow", Vector2i(1, 3))
	var z := TestCombat.foe(e, "zombie", Vector2i(4, 3))
	TestCombat.start_with(e, h)
	var r := e.features.divine_spark(h, z, true, "radiant")
	assert_true(r.ok, r.reason)
	assert_true(z.creature.hp < z.creature.max_hp())


func test_sanctuary_stops_an_attacker_that_fails() -> void:
	var e := TestCombat.open_field(10)
	var h := TestCombat.hero(e, "hedda_ironvow", Vector2i(3, 3))
	var z := TestCombat.foe(e, "zombie", Vector2i(4, 3))
	TestCombat.start_with(e, h)
	var r := e.spells.cast(h, "sanctuary", 1, [h])
	assert_true(r.ok, r.reason)
	assert_eq((h.creature as Character).resource_left("spell:sanctuary"), 0, "the feat's free casting")
	assert_eq((h.creature as Character).slots_left(1), 4)
	e.end_turn()
	TestCombat.next_d20(e, 2)
	var a := e.monster_attack(z, h, "slam")
	assert_false(a.ok)
	assert_true(a.reason.begins_with("Sanctuary"))
	assert_false(e.monster_attack(z, h, "slam").ok, "no second try this turn")
	assert_true(z.action_available)


func test_spiritual_weapon_attacks_again_as_a_bonus_action() -> void:
	var e := TestCombat.open_field(13)
	var h := TestCombat.hero(e, "hedda_ironvow", Vector2i(1, 3))
	var w := TestCombat.foe(e, "dire_wolf", Vector2i(6, 3))
	w.creature.hp = 100
	TestCombat.start_with(e, h)
	var r := e.spells.cast(h, "spiritual_weapon", 2, [w])
	assert_true(r.ok, r.reason)
	assert_true(e.spells.has_spiritual_weapon(h))
	e.end_turn()
	e.end_turn()
	assert_eq(e.current().id, h.id)
	var cell := e.spells.weapon_of(h).cell
	var r2 := e.spells.spiritual_weapon_attack(h, w, cell)
	assert_true(r2.ok, r2.reason)
	assert_false(h.bonus_available)


func test_shield_spell_is_a_reaction_only() -> void:
	var e := _wizard_vs(["wolf"])
	var s := e.combatants[0]
	TestCombat.start_with(e, s)
	assert_false(e.spells.cast(s, "shield", 1, [s]).ok)
	assert_true(e.spells.can_cast_reaction(s, "shield"))


func test_thunderwave_pushes_on_a_failed_save() -> void:
	var e := TestCombat.open_field(14)
	var s := TestCombat.hero(e, "silvain_aster", Vector2i(3, 3))
	var w := TestCombat.foe(e, "wolf", Vector2i(4, 3))
	TestCombat.start_with(e, s)
	TestCombat.next_d20(e, 2)
	var r := e.spells.cast(s, "thunderwave", 1, [], Vector2.INF, Vector2.RIGHT)
	assert_true(r.ok, r.reason)
	if w.is_alive():
		assert_eq(w.cell, Vector2i(6, 3), "pushed 10 ft")


func test_potent_cantrip_half_damage_on_a_miss() -> void:
	var e := _wizard_vs(["dire_wolf"])
	var s := e.combatants[0]
	var w := e.combatants[1]
	w.creature.hp = 100
	TestCombat.start_with(e, s)
	TestCombat.next_d20(e, 2)
	var r := e.spells.cast(s, "fire_bolt", 0, [w])
	assert_true(r.ok)
	assert_false(r.hit)
	assert_true(w.creature.hp < 100, "Potent Cantrip")
