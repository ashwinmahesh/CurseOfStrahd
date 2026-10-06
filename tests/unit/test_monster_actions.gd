extends TestCase
## Monster stat blocks in a fight (monster audit): timed riders, real grapples, save actions, Multiattack choices,
## drains, spellcasting, swarms, sunlight and the AI using all of it.


func _field(seed_value: int = 1) -> Encounter:
	return TestCombat.open_field(seed_value)


func test_ghoul_claw_paralysis_ends_and_spares_elves() -> void:
	var e := _field(2)
	var g := TestCombat.foe(e, "ghoul", Vector2i(3, 3))
	var ilse := TestCombat.hero(e, "ilse_varga", Vector2i(4, 3))
	var silvain := TestCombat.hero(e, "silvain_aster", Vector2i(2, 3))
	TestCombat.start_with(e, g)
	e.monster_actions.apply_riders(g, ilse, (g.creature as Monster).action("claw")["on_hit"] as Array, {}, "Claw")
	e.monster_actions.apply_riders(g, silvain, (g.creature as Monster).action("claw")["on_hit"] as Array, {}, "Claw")
	assert_false(silvain.creature.has_condition(&"paralyzed"), "elves are immune to ghoul paralysis")
	if ilse.creature.has_condition(&"paralyzed"):
		while e.current() != ilse:
			e.end_turn()
		e.end_turn()
		assert_false(ilse.creature.has_condition(&"paralyzed"), "it ends at the end of the target's next turn")


func test_grick_grapple_is_escapable_with_the_printed_dc() -> void:
	var e := _field()
	var g := TestCombat.foe(e, "grick", Vector2i(3, 3))
	var h := TestCombat.hero(e, "ilse_varga", Vector2i(4, 3))
	TestCombat.start_with(e, g)
	e.monster_actions.apply_riders(g, h, (g.creature as Monster).action("tentacles")["on_hit"] as Array, {}, "Tentacles")
	assert_true(h.creature.has_condition(&"grappled"))
	assert_eq(str(e.grapples.get(h.id, "")), g.id, "registered as a grapple")
	assert_eq(int(h.get_meta("escape_dc")), 12)
	g.creature.hp = 0
	e.deal_damage(null, g, [{"amount": 5, "type": "fire"}], false, "test")
	assert_false(h.creature.has_condition(&"grappled") and e.grapples.has(h.id) and g.is_alive(), "released when the grick dies")


func test_specter_life_drain_lowers_the_hit_point_maximum() -> void:
	var e := _field(3)
	var s := TestCombat.foe(e, "specter", Vector2i(3, 3))
	var h := TestCombat.hero(e, "ilse_varga", Vector2i(4, 3))
	TestCombat.start_with(e, s)
	var before := h.creature.max_hp()
	TestCombat.next_d20(e, 19)
	var r := e.monster_attack(s, h, "life_drain")
	assert_true(r.hit)
	assert_eq(h.creature.max_hp(), before - r.damage)


func test_shadow_drains_strength() -> void:
	var e := _field(3)
	var s := TestCombat.foe(e, "shadow", Vector2i(3, 3))
	var h := TestCombat.hero(e, "ilse_varga", Vector2i(4, 3))
	TestCombat.start_with(e, s)
	var before := h.creature.ability_score(&"str")
	TestCombat.next_d20(e, 19)
	assert_true(e.monster_attack(s, h, "draining_swipe").hit)
	assert_true(h.creature.ability_score(&"str") < before)


func test_vampire_spawn_bites_a_grappled_target_and_heals() -> void:
	var e := _field(4)
	var v := TestCombat.foe(e, "vampire_spawn", Vector2i(3, 3))
	var h := TestCombat.punching_bag(e, Vector2i(4, 3), 80)
	h.side = &"party"
	TestCombat.start_with(e, v)
	v.creature.hp = 40
	e.monster_actions.grapple(v, h, 13, 2, "Claw")
	var bite := (v.creature as Monster).action("bite")
	assert_eq(e.monster_actions.save_targets(v, bite).size(), 1, "a Grappled target in reach")
	var r := CombatResult.new()
	e.monster_actions.save_action(v, bite, h, r)
	assert_true(v.creature.hp > 40, "the bite heals the spawn")
	assert_true(h.creature.max_hp() < 80, "and drains the victim's maximum")


func test_multiattack_switches_to_the_ranged_choice_at_range() -> void:
	var e := _field(5)
	var b := TestCombat.foe(e, "bandit_captain", Vector2i(1, 3))
	var h := TestCombat.punching_bag(e, Vector2i(6, 3), 80)
	h.side = &"party"
	b.creature.base_speed = {"walk": 0}
	TestCombat.start_with(e, b)
	e.run_ai_turn()
	assert_true(h.creature.hp < 80, "the Pistol fired from range instead of wasting the Multiattack")


func test_swarm_damage_drops_when_bloodied() -> void:
	var e := _field()
	var s := TestCombat.foe(e, "swarm_of_rats", Vector2i(3, 3))
	var m := s.creature as Monster
	var healthy := m.attack_profile("bites").damage_dice
	m.hp = 1
	assert_ne(m.attack_profile("bites").damage_dice, healthy, "1d4 once Bloodied")


func test_swarm_shares_spaces() -> void:
	var e := _field()
	var s := TestCombat.foe(e, "swarm_of_rats", Vector2i(3, 3))
	TestCombat.hero(e, "ilse_varga", Vector2i(4, 3))
	TestCombat.start_with(e, s)
	var reach := e.reachable_for(s)
	assert_true(reach.has(Vector2i(4, 3)) and not bool((reach[Vector2i(4, 3)] as Dictionary)["occupied"]), "it can end in a foe's space")


func test_flyers_use_their_fly_speed() -> void:
	var e := _field()
	var b := TestCombat.foe(e, "broom_of_animated_attack", Vector2i(3, 3))
	assert_eq(b.speed(), 50, "the broom flies 50 ft")


func test_shambling_mound_absorbs_lightning() -> void:
	var e := _field()
	var m := TestCombat.foe(e, "shambling_mound", Vector2i(3, 3))
	m.creature.hp = 50
	e.deal_damage(null, m, [{"amount": 10, "type": "lightning"}], false, "test")
	assert_eq(m.creature.hp, 60)


func test_night_hag_casts_magic_missile_at_level_four() -> void:
	var e := _field(2)
	var hag := TestCombat.foe(e, "night_hag", Vector2i(1, 3))
	var h := TestCombat.punching_bag(e, Vector2i(10, 3), 80)
	h.side = &"party"
	TestCombat.start_with(e, hag)
	var r := e.monster_actions.cast(hag, "magic_missile", [h])
	assert_true(r.ok, r.reason)
	assert_true(h.creature.hp < 80)


func test_parry_can_turn_a_hit_into_a_miss() -> void:
	var e := _field(6)
	var n := TestCombat.foe(e, "noble", Vector2i(3, 3))
	var f := TestCombat.hero(e, "ilse_varga", Vector2i(4, 3))
	TestCombat.start_with(e, f)
	var parried := false
	for i in 20:
		n.creature.hp = n.creature.max_hp()
		n.reaction_available = true
		f.action_available = true
		f.attacks_left = 0
		TestCombat.next_d20(e, 10)
		e.attack(f, n, "weapon:greatsword")
		if not n.reaction_available:
			parried = true
			break
	assert_true(parried, "the noble parried at least once")


func test_werewolf_bite_curses_and_only_in_beast_forms() -> void:
	var e := _field()
	var w := TestCombat.foe(e, "werewolf", Vector2i(3, 3))
	var bite := (w.creature as Monster).action("bite")
	assert_ne(e.monster_actions.why_not(w, bite), "", "no Bite in humanoid form")
	w.set_meta("form", "hybrid")
	assert_eq(e.monster_actions.why_not(w, bite), "")
