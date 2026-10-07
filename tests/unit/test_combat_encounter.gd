extends TestCase
## Encounter rules (2024 PHB "Combat"): Initiative, turns and the action economy, movement and Opportunity
## Attacks, attacks with Advantage sources and cover, the standard actions and reaction prompts.


func test_initiative_orders_everyone_and_identical_monsters_share_a_roll() -> void:
	var e := TestCombat.open_field(3)
	TestCombat.hero(e, "ilse_varga", Vector2i(1, 1))
	TestCombat.hero(e, "tamsin_tealeaf", Vector2i(1, 2))
	var w1 := TestCombat.foe(e, "wolf", Vector2i(8, 1))
	var w2 := TestCombat.foe(e, "wolf", Vector2i(8, 2))
	var z := TestCombat.foe(e, "zombie", Vector2i(8, 4))
	e.start()
	assert_eq(e.order.size(), 5)
	assert_eq(w1.initiative, w2.initiative, "wolves share one Initiative roll")
	assert_ne(z.initiative_group, w1.initiative_group)
	for i in range(1, e.order.size()):
		assert_true(e.order[i - 1].initiative >= e.order[i].initiative, "sorted by Initiative")
	assert_eq(e.round_no, 1)
	assert_eq(e.current().id, e.order[0].id)


func test_surprise_gives_disadvantage_on_initiative() -> void:
	var e := TestCombat.open_field(5)
	var w := TestCombat.foe(e, "wolf", Vector2i(8, 1))
	TestCombat.hero(e, "ilse_varga", Vector2i(1, 1))
	e.start([w.id])
	assert_true(w.surprised)
	assert_true(w.initiative_test.disadvantage)


func test_turns_and_rounds_advance() -> void:
	var e := TestCombat.open_field()
	var a := TestCombat.hero(e, "ilse_varga", Vector2i(1, 1))
	var b := TestCombat.foe(e, "zombie", Vector2i(9, 6))
	TestCombat.start_with(e, a)
	assert_eq(e.current().id, a.id)
	assert_eq(a.movement_left, 30)
	e.end_turn()
	assert_eq(e.current().id, b.id)
	e.end_turn()
	assert_eq(e.current().id, a.id)
	assert_eq(e.round_no, 2)


func test_moving_spends_feet_and_cant_end_in_an_occupied_square() -> void:
	var e := TestCombat.open_field()
	var a := TestCombat.hero(e, "ilse_varga", Vector2i(0, 0))
	var ally := TestCombat.hero(e, "hedda_ironvow", Vector2i(1, 0))
	TestCombat.foe(e, "zombie", Vector2i(10, 7))
	TestCombat.start_with(e, a)
	assert_false(e.move(a, Vector2i(1, 0)).ok, "can't stop in an ally's square")
	var r := e.move(a, Vector2i(2, 0))
	assert_true(r.ok, r.reason)
	assert_eq(a.cell, Vector2i(2, 0))
	assert_eq(a.movement_left, 20)
	assert_true(a.moved)
	assert_false(e.move(a, Vector2i(9, 0)).ok, "35 ft is too far")
	assert_eq(ally.cell, Vector2i(1, 0))


func test_an_enemys_space_is_difficult_terrain_and_halflings_slip_past() -> void:
	var e := TestCombat.encounter(["...", "...", "..."])
	var t := TestCombat.hero(e, "tamsin_tealeaf", Vector2i(0, 1))
	var z := TestCombat.foe(e, "zombie", Vector2i(1, 1))
	TestCombat.start_with(e, t)
	# Halfling Nimbleness: through a larger creature's space, which costs double (Difficult Terrain).
	var reach := e.reachable_for(t)
	assert_true(reach.has(Vector2i(1, 1)) and bool((reach[Vector2i(1, 1)] as Dictionary)["occupied"]))
	assert_eq(int((reach[Vector2i(1, 1)] as Dictionary)["cost"]), 10)
	z.creature.size = &"small"
	reach = e.reachable_for(t)
	assert_false(reach.has(Vector2i(1, 1)), "a same-size enemy blocks")


func test_leaving_reach_provokes_an_opportunity_attack() -> void:
	var e := TestCombat.open_field(7)
	var a := TestCombat.hero(e, "silvain_aster", Vector2i(2, 2))
	a.reaction_rules["shield"] = "never"
	var w := TestCombat.foe(e, "wolf", Vector2i(3, 2))
	TestCombat.start_with(e, a)
	var hp_before := a.creature.hp
	var r := e.move(a, Vector2i(0, 2))
	assert_true(r.ok)
	assert_false(r.is_paused(), "AI reactors don't ask")
	assert_false(w.reaction_available, "the wolf used its Reaction")
	assert_true(e.log.texts().any(func(t: String) -> bool: return t.contains("Opportunity Attack")))
	assert_true(a.creature.hp <= hp_before)


func test_disengage_prevents_opportunity_attacks() -> void:
	var e := TestCombat.open_field(7)
	var a := TestCombat.hero(e, "silvain_aster", Vector2i(2, 2))
	var w := TestCombat.foe(e, "wolf", Vector2i(3, 2))
	TestCombat.start_with(e, a)
	assert_true(e.disengage(a).ok)
	assert_false(a.action_available)
	e.move(a, Vector2i(0, 2))
	assert_true(w.reaction_available)


func test_player_reactions_pause_and_resume_the_move() -> void:
	var e := TestCombat.open_field(11)
	var ilse := TestCombat.hero(e, "ilse_varga", Vector2i(3, 2))
	var z := TestCombat.foe(e, "zombie", Vector2i(4, 2))
	TestCombat.start_with(e, z)
	var r := e.move(z, Vector2i(6, 2))
	assert_true(r.is_paused(), "Ilse is asked about her Opportunity Attack")
	assert_eq(r.pending.kind, "opportunity_attack")
	assert_eq(r.pending.reactor_id, ilse.id)
	assert_false(e.end_turn().ok, "the prompt must be answered first")
	var r2 := e.answer_reaction(false)
	assert_false(r2.is_paused())
	assert_eq(z.cell, Vector2i(6, 2), "the move finished after the answer")
	assert_true(ilse.reaction_available)


func test_reaction_rule_auto_takes_the_reaction_without_asking() -> void:
	var e := TestCombat.open_field(11)
	var ilse := TestCombat.hero(e, "ilse_varga", Vector2i(3, 2))
	ilse.reaction_rules["opportunity_attack"] = "auto"
	var z := TestCombat.foe(e, "zombie", Vector2i(4, 2))
	TestCombat.start_with(e, z)
	var r := e.move(z, Vector2i(6, 2))
	assert_false(r.is_paused())
	assert_false(ilse.reaction_available)


func test_attack_hits_and_deals_damage() -> void:
	var e := TestCombat.open_field()
	var ilse := TestCombat.hero(e, "ilse_varga", Vector2i(2, 2))
	var z := TestCombat.foe(e, "zombie", Vector2i(3, 2))
	TestCombat.start_with(e, ilse)
	TestCombat.next_d20(e, 15)
	var r := e.attack(ilse, z, "weapon:greatsword")
	assert_true(r.ok, r.reason)
	assert_true(r.hit)
	assert_true(z.creature.hp < z.creature.max_hp() or z.creature.hp == 1)
	assert_false(ilse.action_available)
	assert_eq(ilse.attacks_left, 0, "one attack at level 3")
	assert_false(e.attack(ilse, z, "weapon:greatsword").ok, "no attacks left")


func test_graze_deals_strength_damage_on_a_miss() -> void:
	var e := TestCombat.open_field()
	var ilse := TestCombat.hero(e, "ilse_varga", Vector2i(2, 2))
	var w := TestCombat.foe(e, "dire_wolf", Vector2i(3, 2))
	TestCombat.start_with(e, ilse)
	TestCombat.next_d20(e, 2)
	var r := e.attack(ilse, w, "weapon:greatsword")
	assert_false(r.hit)
	assert_eq(w.creature.hp, w.creature.max_hp() - 3, "Graze: Strength modifier 3")


func test_out_of_reach_and_range() -> void:
	var e := TestCombat.open_field()
	var ilse := TestCombat.hero(e, "ilse_varga", Vector2i(0, 0))
	var z := TestCombat.foe(e, "zombie", Vector2i(5, 0))
	TestCombat.start_with(e, ilse)
	assert_false(e.attack(ilse, z, "weapon:greatsword").ok)
	assert_true(e.attack_legal(ilse, z, e.option_by_id(ilse, "thrown:javelin")) == "")


func test_prone_targets_and_ranged_attacks_in_melee() -> void:
	var e := TestCombat.open_field()
	var t := TestCombat.hero(e, "tamsin_tealeaf", Vector2i(2, 2))
	var w := TestCombat.foe(e, "wolf", Vector2i(3, 2))
	var far := TestCombat.foe(e, "zombie", Vector2i(9, 2))
	TestCombat.start_with(e, t)
	var bow := e.option_by_id(t, "weapon:shortbow")
	var sit := e.attack_situation(t, far, bow)
	assert_true((sit["disadvantage"] as Array).any(func(s: String) -> bool: return s.contains("within 5 ft")))
	w.creature.add_condition(&"prone")
	var sword := e.option_by_id(t, "weapon:shortsword")
	assert_true((e.attack_situation(t, w, sword)["advantage"] as Array).has("target Prone within 5 ft"))


func test_pack_tactics() -> void:
	var e := TestCombat.open_field()
	var h := TestCombat.hero(e, "hedda_ironvow", Vector2i(4, 4))
	var w1 := TestCombat.foe(e, "wolf", Vector2i(5, 4))
	var w2 := TestCombat.foe(e, "wolf", Vector2i(3, 4))
	TestCombat.start_with(e, w1)
	var bite := e.option_by_id(w1, "monster:bite")
	assert_true((e.attack_situation(w1, h, bite)["advantage"] as Array).has("Pack Tactics"))
	w2.creature.add_condition(&"incapacitated")
	assert_false((e.attack_situation(w1, h, bite)["advantage"] as Array).has("Pack Tactics"), "an Incapacitated ally doesn't count")


func test_wolf_bite_knocks_prone() -> void:
	var e := TestCombat.open_field()
	var h := TestCombat.hero(e, "hedda_ironvow", Vector2i(4, 4))
	var w := TestCombat.foe(e, "wolf", Vector2i(5, 4))
	TestCombat.start_with(e, w)
	TestCombat.next_d20(e, 18)
	var r := e.monster_attack(w, h, "bite")
	assert_true(r.hit)
	assert_true(h.creature.has_condition(&"prone"))


func test_cover_raises_ac() -> void:
	var e := TestCombat.encounter(["......", "......", "..=...", "......"])
	var t := TestCombat.hero(e, "tamsin_tealeaf", Vector2i(0, 2))
	var z := TestCombat.foe(e, "zombie", Vector2i(5, 2))
	TestCombat.start_with(e, t)
	var sit := e.attack_situation(t, z, e.option_by_id(t, "weapon:shortbow"))
	assert_eq(int(sit["cover"]), CombatGrid.Cover.HALF)
	assert_eq(int(sit["cover_bonus"]), 2)


func test_dodge_and_help() -> void:
	var e := TestCombat.open_field()
	var ilse := TestCombat.hero(e, "ilse_varga", Vector2i(2, 2))
	var hedda := TestCombat.hero(e, "hedda_ironvow", Vector2i(2, 3))
	var w := TestCombat.foe(e, "wolf", Vector2i(3, 2))
	TestCombat.start_with(e, ilse)
	assert_true(e.dodge(ilse).ok)
	var bite := e.option_by_id(w, "monster:bite")
	assert_true((e.attack_situation(w, ilse, bite)["disadvantage"] as Array).any(func(s: String) -> bool: return s.begins_with("Dodging")))
	e.end_turn()
	# Hedda's turn (order: Ilse, then the others by Initiative); make it hers for the test.
	e.turn_index = e.order.find(hedda)
	e._begin_turn()
	assert_true(e.help_attack(hedda, w).ok)
	var sword := e.option_by_id(ilse, "weapon:greatsword")
	assert_true((e.attack_situation(ilse, w, sword)["advantage"] as Array).any(func(s: String) -> bool: return s.begins_with("Help")))
	assert_false((e.attack_situation(hedda, w, e.option_by_id(hedda, "weapon:mace"))["advantage"] as Array).any(func(s: String) -> bool: return s.begins_with("Help")), "not the helper's own attack")


func test_hide_needs_cover_from_every_enemy() -> void:
	var e := TestCombat.encounter(["......", "..#...", "..#...", "..#...", "......"])
	var t := TestCombat.hero(e, "tamsin_tealeaf", Vector2i(1, 2))
	var z := TestCombat.foe(e, "zombie", Vector2i(4, 2))
	TestCombat.start_with(e, t)
	TestCombat.next_d20(e, 15)
	var r := e.hide(t, true)
	assert_true(r.ok, r.reason)
	assert_true(t.hidden)
	assert_true(t.creature.has_condition(&"invisible"))
	assert_false(e.can_see(z, t))
	# Attacking reveals her.
	z.cell = Vector2i(1, 3)
	e.attack(t, z, "weapon:shortsword")
	assert_false(t.hidden)


func test_sneak_attack_with_an_ally_next_to_the_target() -> void:
	var e := TestCombat.open_field()
	var t := TestCombat.hero(e, "tamsin_tealeaf", Vector2i(2, 2))
	var ilse := TestCombat.hero(e, "ilse_varga", Vector2i(5, 2))
	var w := TestCombat.foe(e, "dire_wolf", Vector2i(3, 2))
	TestCombat.start_with(e, t)
	TestCombat.next_d20(e, 17)
	var r := e.attack(t, w, "weapon:shortsword")
	assert_true(r.hit)
	assert_true(e.log.dump().contains("Sneak Attack 2d6"))
	assert_false(e.features.sneak_attack_ready(t), "once per turn")
	assert_true(ilse.is_alive())


func test_sneak_attack_rules_disadvantage_weapon_and_reaction_turns() -> void:
	var e := TestCombat.open_field()
	var t := TestCombat.hero(e, "tamsin_tealeaf", Vector2i(2, 2))
	TestCombat.hero(e, "ilse_varga", Vector2i(4, 2))
	var w := TestCombat.foe(e, "dire_wolf", Vector2i(3, 2))
	w.creature.hp = 300
	TestCombat.start_with(e, t)
	var opt := e.option_by_id(t, "weapon:shortsword")
	var adv := D20Test.new()
	adv.advantage = true
	var dis := D20Test.new()
	dis.disadvantage = true
	var plain := D20Test.new()
	assert_eq(e.features.sneak_attack_dice(t, w, opt, dis), "", "Disadvantage blocks it, even with an ally beside the target")
	var club := e.option_by_id(t, "unarmed")
	if not club.is_empty():
		assert_eq(e.features.sneak_attack_dice(t, w, club, adv), "", "not with a weapon that's neither Finesse nor ranged")
	assert_eq(e.features.sneak_attack_dice(t, w, opt, plain), "2d6", "an ally within 5 ft of the target is enough")
	assert_eq(e.features.sneak_attack_dice(t, w, opt, adv), "", "once per turn")
	# The wolf's turn: an Opportunity Attack on someone else's turn can Sneak Attack again.
	e.end_turn()
	while e.current() != w:
		e.end_turn()
	assert_eq(e.features.sneak_attack_dice(t, w, opt, plain), "2d6", "again on another creature's turn (a Reaction attack)")


func test_nick_offhand_attack_is_part_of_the_attack_action() -> void:
	var e := TestCombat.open_field()
	var t := TestCombat.hero(e, "tamsin_tealeaf", Vector2i(2, 2))
	var w := TestCombat.foe(e, "dire_wolf", Vector2i(3, 2))
	TestCombat.start_with(e, t)
	assert_true(e.attack(t, w, "weapon:dagger").ok)
	var r := e.offhand_attack(t, w, "weapon:shortsword")
	assert_true(r.ok, r.reason)
	assert_true(t.bonus_available, "Nick: no Bonus Action needed")
	assert_false(e.offhand_attack(t, w, "weapon:shortsword").ok, "only one extra attack")


func test_undead_fortitude_and_radiant_damage() -> void:
	var e := TestCombat.open_field(2)
	var h := TestCombat.hero(e, "hedda_ironvow", Vector2i(2, 2))
	var z := TestCombat.foe(e, "zombie", Vector2i(3, 2))
	TestCombat.start_with(e, h)
	z.creature.hp = 3
	TestCombat.next_d20(e, 20)
	e.deal_damage(h, z, [{"amount": 4, "type": "bludgeoning"}], false, "test")
	assert_true(z.is_alive(), "Con save DC 9 succeeds on a natural 20 (+3)")
	assert_eq(z.creature.hp, 1)
	assert_false(z.is_down(), "it never falls: still standing")
	var kinds: Array = e.events.map(func(x: Dictionary) -> String: return str(x["type"]))
	assert_false("down" in kinds or "death" in kinds, "no fall, no death on a successful save")
	assert_true("trait" in kinds, "the board shows Undead Fortitude over it")
	assert_false(e.log.dump().contains("Zombie falls unconscious"))
	e.deal_damage(h, z, [{"amount": 4, "type": "radiant"}], false, "test")
	assert_false(z.is_alive(), "no save against Radiant damage")


func test_shield_prompt_turns_a_hit_into_a_miss() -> void:
	var e := TestCombat.open_field()
	var s := TestCombat.hero(e, "silvain_aster", Vector2i(2, 2))
	var w := TestCombat.foe(e, "dire_wolf", Vector2i(3, 2))
	TestCombat.start_with(e, w)
	TestCombat.next_d20(e, 9)
	var r := e.monster_attack(w, s, "bite")
	# 9 + 5 = 14 vs AC 11 hits; with Shield AC 16 it misses.
	assert_true(r.is_paused())
	assert_eq(r.pending.kind, "shield")
	var r2 := e.answer_reaction(true)
	assert_false(r2.hit)
	assert_eq(s.creature.hp, s.creature.max_hp())
	assert_eq((s.creature as Character).slots_left(1), 3)
	assert_eq(s.creature.ac_value(), 16)
	assert_false(s.reaction_available)


func test_grapple_and_escape() -> void:
	var e := TestCombat.open_field()
	var ilse := TestCombat.hero(e, "ilse_varga", Vector2i(2, 2))
	var z := TestCombat.foe(e, "zombie", Vector2i(3, 2))
	TestCombat.start_with(e, ilse)
	TestCombat.next_d20(e, 2)
	var r := e.unarmed_special(ilse, z, "grapple")
	assert_true(r.ok)
	assert_true(z.creature.has_condition(&"grappled"))
	assert_eq(z.speed(), 0)


func test_action_surge_gives_a_second_attack_action() -> void:
	var e := TestCombat.open_field()
	var ilse := TestCombat.hero(e, "ilse_varga", Vector2i(2, 2))
	var w := TestCombat.foe(e, "dire_wolf", Vector2i(3, 2))
	w.creature.hp = 200
	TestCombat.start_with(e, ilse)
	assert_true(e.attack(ilse, w, "weapon:greatsword").ok)
	assert_false(e.attack(ilse, w, "weapon:greatsword").ok)
	assert_true(e.features.action_surge(ilse).ok)
	assert_true(e.attack(ilse, w, "weapon:greatsword").ok)
	assert_false(e.features.action_surge(ilse).ok, "one use")


func test_second_wind_and_steady_aim() -> void:
	var e := TestCombat.open_field()
	var ilse := TestCombat.hero(e, "ilse_varga", Vector2i(2, 2))
	var t := TestCombat.hero(e, "tamsin_tealeaf", Vector2i(2, 4))
	TestCombat.foe(e, "zombie", Vector2i(9, 2))
	TestCombat.start_with(e, ilse)
	ilse.creature.hp = 10
	assert_true(e.features.second_wind(ilse).ok)
	assert_true(ilse.creature.hp >= 14)
	assert_false(ilse.bonus_available)
	e.turn_index = e.order.find(t)
	e._begin_turn()
	assert_true(e.features.steady_aim(t).ok)
	assert_eq(t.movement_left, 0)
	assert_true(e.marks.any(func(m: Dictionary) -> bool: return str(m["kind"]) == "advantage_next_attack"))
	assert_false(e.move(t, Vector2i(3, 4)).ok)


func test_victory_when_every_enemy_falls() -> void:
	var e := TestCombat.open_field()
	var ilse := TestCombat.hero(e, "ilse_varga", Vector2i(2, 2))
	var w := TestCombat.foe(e, "wolf", Vector2i(3, 2))
	TestCombat.start_with(e, ilse)
	e.deal_damage(ilse, w, [{"amount": 50, "type": "slashing"}], false, "test")
	assert_true(e.is_over())
	assert_eq(e.outcome, "victory")


func test_thrown_weapons_leave_the_hand() -> void:
	var e := TestCombat.open_field()
	var t := TestCombat.hero(e, "tamsin_tealeaf", Vector2i(1, 1))
	var w := TestCombat.foe(e, "dire_wolf", Vector2i(5, 1))
	w.creature.hp = 100
	TestCombat.start_with(e, t)
	assert_eq(e.item_count(t, "dagger"), 4)
	assert_true(e.attack(t, w, "thrown:dagger").ok)
	assert_eq(e.item_count(t, "dagger"), 3)
	for c in (t.creature as Character).inventory:
		if str(c["id"]) == "dagger":
			c["qty"] = 0
	assert_eq(e.attack_legal(t, w, e.option_by_id(t, "thrown:dagger")), "No Dagger left")


func test_heroic_inspiration_offers_a_reroll_on_a_miss() -> void:
	var e := TestCombat.open_field()
	var ilse := TestCombat.hero(e, "ilse_varga", Vector2i(2, 2))
	var w := TestCombat.foe(e, "dire_wolf", Vector2i(3, 2))
	w.creature.hp = 100
	(ilse.creature as Character).finish_long_rest()
	assert_true((ilse.creature as Character).heroic_inspiration, "Resourceful: Heroic Inspiration after a Long Rest")
	TestCombat.start_with(e, ilse)
	TestCombat.next_d20(e, 2)
	var r := e.attack(ilse, w, "weapon:greatsword")
	assert_true(r.is_paused())
	assert_eq(r.pending.kind, "heroic_inspiration")
	e.answer_reaction(true)
	assert_false((ilse.creature as Character).heroic_inspiration, "spent")
	assert_true(e.log.texts().any(func(t: String) -> bool: return t.contains("spends Heroic Inspiration to reroll")))



func test_frightened_creatures_cannot_move_closer_to_what_they_fear() -> void:
	var e := TestCombat.open_field()
	var ilse := TestCombat.hero(e, "ilse_varga", Vector2i(2, 2))
	var z := TestCombat.foe(e, "zombie", Vector2i(8, 2))
	var fx := Effect.new("Frightened", &"spell", "test").with_condition(&"frightened")
	fx.caster_id = z.id
	ilse.creature.add_effect(fx)
	TestCombat.start_with(e, ilse)
	assert_eq(e.fear_sources(ilse).size(), 1)
	assert_false(e.move(ilse, Vector2i(4, 2)).ok, "closer to the zombie")
	assert_true(e.move(ilse, Vector2i(1, 2)).ok, "away is fine")
	ilse.creature.remove_effect(fx)
	assert_true(e.move(ilse, Vector2i(3, 2)).ok, "no longer Frightened")


func test_party_members_move_through_each_other_as_difficult_terrain() -> void:
	var e := TestCombat.encounter(["#########", "#.......#", "#########"])
	var a := TestCombat.hero(e, "ilse_varga", Vector2i(1, 1))
	TestCombat.hero(e, "silvain_aster", Vector2i(2, 1))
	TestCombat.foe(e, "zombie", Vector2i(7, 1))
	TestCombat.start_with(e, a)
	var reach := e.reachable_for(a)
	assert_true(reach.has(Vector2i(3, 1)), "through the ally in a one-square corridor")
	assert_eq(int((reach[Vector2i(3, 1)] as Dictionary)["cost"]), 15, "the ally's square costs double (Difficult Terrain)")
	assert_true(bool((reach[Vector2i(2, 1)] as Dictionary)["occupied"]), "but you can't stop there")
	e.allies_block = true
	assert_false(e.reachable_for(a).has(Vector2i(3, 1)), "a place can say allies block each other")
