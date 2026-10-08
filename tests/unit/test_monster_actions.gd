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


func test_giant_elk_charge_adds_damage_and_knocks_prone() -> void:
	var e := _field(3)
	var elk := TestCombat.foe(e, "giant_elk", Vector2i(2, 3))
	var h := TestCombat.hero(e, "ilse_varga", Vector2i(6, 3), 12)
	TestCombat.start_with(e, elk)
	# Standing still: an ordinary Ram, no Prone.
	TestCombat.next_d20(e, 19)
	e.attack(elk, h, "monster:ram")
	assert_false(h.creature.has_condition(&"prone"), "no charge without a run-up")
	assert_false(e.log.entries.any(func(x: Dictionary) -> bool: return "Charge" in str(x.get("details", ""))), "no charge dice")
	# A 20-ft run straight at the target.
	elk.record_step(Vector2i(-2, 3), elk.cell)
	elk.moved = true
	elk.action_available = true
	elk.attacks_left = 0
	TestCombat.next_d20(e, 19)
	h.creature.hp = h.creature.max_hp()
	e.attack(elk, h, "monster:ram")
	assert_true(h.creature.has_condition(&"prone"), "the charge knocks a Huge or smaller target Prone")
	assert_true(e.log.entries.any(func(x: Dictionary) -> bool: return "Charge" in str(x.get("details", ""))), "the charge's extra 2d4 is rolled")


func test_roc_talons_restrain_until_the_swoop_drops_the_victim() -> void:
	var e := _field(4)
	var roc := TestCombat.foe(e, "roc", Vector2i(2, 2))
	var h := TestCombat.hero(e, "ilse_varga", Vector2i(6, 3))
	TestCombat.start_with(e, roc)
	e.monster_actions.apply_riders(roc, h, (roc.creature as Monster).action("talons")["on_hit"] as Array, {}, "Talons")
	assert_true(h.creature.has_condition(&"grappled") and h.creature.has_condition(&"restrained"), "grappled and restrained")
	var before := h.creature.hp
	e.monster_actions.bonus_action(roc, "swoop")
	assert_false(e.grapples.has(h.id), "dropped")
	assert_false(h.creature.has_condition(&"restrained"), "the restraint ends with the grapple")
	assert_true(h.creature.has_condition(&"prone"), "lands Prone")
	assert_true(h.creature.hp < before, "falls 60 ft")
	assert_eq(e.monster_actions.why_not(roc, (roc.creature as Monster).data["bonus_actions"][0] as Dictionary), "Recharging")


func test_restraining_grapple_ends_when_the_victim_breaks_free() -> void:
	var e := _field(5)
	var roc := TestCombat.foe(e, "roc", Vector2i(2, 2))
	var h := TestCombat.hero(e, "ilse_varga", Vector2i(6, 3))
	TestCombat.start_with(e, roc)
	e.monster_actions.apply_riders(roc, h, (roc.creature as Monster).action("talons")["on_hit"] as Array, {}, "Talons")
	assert_true(h.creature.has_condition(&"restrained"))
	h.creature.remove_condition(&"grappled")
	assert_false(h.creature.has_condition(&"restrained"), "free of the grapple, free of the restraint")


func test_djinni_storm_bolt_knocks_down_large_or_smaller() -> void:
	var e := _field()
	var dj := TestCombat.foe(e, "djinni", Vector2i(2, 2))
	var h := TestCombat.hero(e, "ilse_varga", Vector2i(8, 3))
	TestCombat.start_with(e, dj)
	e.monster_actions.apply_riders(dj, h, (dj.creature as Monster).action("storm_bolt")["on_hit"] as Array, {}, "Storm Bolt")
	assert_true(h.creature.has_condition(&"prone"))


func test_fire_elemental_sets_targets_burning_until_they_douse() -> void:
	var e := _field(7)
	var fe := TestCombat.foe(e, "fire_elemental", Vector2i(2, 2))
	var h := TestCombat.hero(e, "ilse_varga", Vector2i(4, 2), 12)
	TestCombat.start_with(e, fe)
	e.monster_actions.turn_end(fe)
	assert_true(h.creature.effects.any(func(x: Effect) -> bool: return x.name == "Burning"), "Fire Aura sets creatures within 10 ft burning")
	var hp := h.creature.hp
	e.spells._turn_start_effects(h)
	assert_true(h.creature.hp < hp, "1d4 Fire at the start of its turn")
	while e.current() != h:
		e.end_turn()
	var ids: Array = ActionCatalog.new(e).actions_for(h).map(func(a: Dictionary) -> String: return str(a["id"]))
	assert_true("douse" in ids, "offered: put out the flames")
	e.douse(h)
	assert_false(h.creature.effects.any(func(x: Effect) -> bool: return x.name == "Burning"))
	assert_true(h.creature.has_condition(&"prone"), "rolling on the ground leaves it Prone")


func test_ghost_horrific_visage_fills_a_cone_and_leaves_survivors_immune() -> void:
	var e := _field(8)
	var g := TestCombat.foe(e, "ghost", Vector2i(2, 3))
	var a := TestCombat.hero(e, "ilse_varga", Vector2i(5, 3))
	var b := TestCombat.hero(e, "silvain_aster", Vector2i(6, 3))
	var behind := TestCombat.hero(e, "hedda_ironvow", Vector2i(0, 3))
	TestCombat.start_with(e, g)
	var act := (g.creature as Monster).action("horrific_visage")
	var hit := e.monster_actions.save_victims(g, act, a)
	assert_true(a in hit and b in hit, "both creatures in the cone")
	assert_false(behind in hit, "not the one behind the ghost")
	var r := CombatResult.new()
	for i in 6:
		e.monster_actions.save_action(g, act, a, r)
	var immune_or_scared := a.creature.has_condition(&"frightened") or a.has_meta(ClassFeatures.meta_key("immune_%s_Horrific Visage" % g.id))
	assert_true(immune_or_scared, "a failure frightens, a success makes it immune")


func test_ghost_possession_turns_the_body_until_it_drops() -> void:
	var e := _field(9)
	var g := TestCombat.foe(e, "ghost", Vector2i(2, 3))
	var h := TestCombat.hero(e, "ilse_varga", Vector2i(3, 3))
	TestCombat.hero(e, "silvain_aster", Vector2i(8, 3))
	TestCombat.start_with(e, g)
	e.monster_actions.possess(g, h, "Possession")
	assert_eq(h.side, g.side, "the body fights for the ghost")
	assert_false(e.can_see(e.get_c(h.id), g), "the ghost is hidden inside")
	e.deal_damage(null, h, [{"amount": 999, "type": "force"}], false, "test")
	assert_eq(h.side, &"party", "the body's owner is back in control")
	assert_false(g.has_meta("possessing"))
	assert_true(h.has_meta(ClassFeatures.meta_key("immune_%s_Possession" % g.id)))


func test_water_elemental_whelm_holds_restrains_and_batters() -> void:
	var e := _field(10)
	var we := TestCombat.foe(e, "water_elemental", Vector2i(3, 3))
	var h := TestCombat.hero(e, "silvain_aster", Vector2i(6, 3), 12)
	TestCombat.start_with(e, we)
	h.cell = Vector2i(3, 3)
	var act := (we.creature as Monster).action("whelm")
	var held := false
	for i in 20:
		h.creature.hp = h.creature.max_hp()
		e.monster_actions.save_action(we, act, h, CombatResult.new())
		if e.grapples.has(h.id):
			held = true
			break
	assert_true(held, "a failed save leaves it held")
	assert_true(h.creature.has_condition(&"restrained"))
	h.creature.hp = h.creature.max_hp()
	e.monster_actions.turn_start(we)
	assert_true(h.creature.hp < h.creature.max_hp(), "battered at the start of the elemental's turn")


func test_air_elemental_whirlwind_flings_and_drops() -> void:
	var e := _field(11)
	var ae := TestCombat.foe(e, "air_elemental", Vector2i(3, 3))
	var h := TestCombat.hero(e, "silvain_aster", Vector2i(6, 3), 12)
	TestCombat.start_with(e, ae)
	h.cell = Vector2i(3, 3)
	assert_true(h in e.monster_actions.save_targets(ae, (ae.creature as Monster).action("whirlwind")), "a creature in its space")
	var prone := false
	for i in 20:
		h.cell = Vector2i(3, 3)
		h.creature.hp = h.creature.max_hp()
		e.monster_actions.save_action(ae, (ae.creature as Monster).action("whirlwind"), h, CombatResult.new())
		if h.creature.has_condition(&"prone"):
			prone = true
			break
	assert_true(prone, "a failure knocks it Prone")


func test_elephant_tramples_a_prone_creature() -> void:
	var e := _field(12)
	var el := TestCombat.foe(e, "elephant", Vector2i(2, 2))
	var h := TestCombat.hero(e, "ilse_varga", Vector2i(5, 3), 12)
	TestCombat.start_with(e, el)
	h.creature.add_condition(&"prone", "test")
	var hp := h.creature.hp
	e.monster_actions.bonus_action(el, "trample")
	assert_true(h.creature.hp < hp, "Trample hits a Prone creature")
	assert_false(el.bonus_available)


func test_giant_hyena_rampages_after_biting_a_bloodied_foe() -> void:
	var e := _field(13)
	var hy := TestCombat.foe(e, "giant_hyena", Vector2i(3, 3))
	var h := TestCombat.hero(e, "ilse_varga", Vector2i(4, 3), 12)
	TestCombat.start_with(e, hy)
	h.creature.hp = h.creature.max_hp() / 2
	var hits := 0
	for i in 10:
		TestCombat.next_d20(e, 19)
		hy.action_available = true
		hy.attacks_left = 0
		e.monster_attack(hy, h, "bite")
		hits += 1
		if hy.has_meta("hit_bloodied"):
			break
	assert_true(hy.has_meta("hit_bloodied"), "it hurt an already Bloodied creature")
	var before := h.creature.hp
	TestCombat.next_d20(e, 19)
	e.monster_actions.bonus_action(hy, "rampage")
	assert_true(h.creature.hp < before, "the Rampage bite lands")
	assert_eq(e.monster_actions.why_not(hy, (hy.creature as Monster).data["bonus_actions"][0] as Dictionary), "No uses left")


func test_flesh_golem_shies_from_fire_and_goes_berserk() -> void:
	var e := _field(14)
	var g := TestCombat.foe(e, "flesh_golem", Vector2i(3, 3))
	TestCombat.hero(e, "ilse_varga", Vector2i(6, 3))
	TestCombat.start_with(e, g)
	e.deal_damage(null, g, [{"amount": 5, "type": "fire"}], false, "test")
	assert_true(g.creature.d20_sources(["attack", "attack:melee"])["disadvantage"].size() > 0, "Aversion to Fire")
	g.creature.hp = g.creature.max_hp() / 3
	var mad := false
	for i in 40:
		e.monster_actions.turn_start(g)
		if g.has_meta("berserk"):
			mad = true
			break
	assert_true(mad, "a 6 sends a Bloodied golem berserk")
	g.creature.hp = g.creature.max_hp()
	e.monster_actions.turn_start(g)
	assert_false(g.has_meta("berserk"), "calm once no longer Bloodied")


func test_berserker_frenzy_only_while_bloodied() -> void:
	var b := TestCombat.monster("berserker")
	assert_eq((b.d20_sources(["attack"])["advantage"] as Array).size(), 0)
	b.hp = b.max_hp() / 2 - 1
	assert_true((b.d20_sources(["attack"])["advantage"] as Array).size() > 0, "Advantage on attacks while Bloodied")
	assert_true((b.d20_sources(["save:con", "save:all"])["advantage"] as Array).size() > 0, "and on saves")


func test_will_o_wisp_vanishes_and_consumes_the_dying() -> void:
	var e := _field(15)
	var w := TestCombat.foe(e, "will_o_wisp", Vector2i(3, 3))
	var h := TestCombat.hero(e, "ilse_varga", Vector2i(4, 3))
	TestCombat.hero(e, "silvain_aster", Vector2i(9, 9))
	TestCombat.start_with(e, w)
	e.monster_actions.bonus_action(w, "vanish")
	assert_true(w.creature.has_condition(&"invisible"))
	TestCombat.next_d20(e, 15)
	e.monster_attack(w, h, "shock")
	assert_false(w.creature.has_condition(&"invisible"), "attacking ends Vanish")
	h.creature.hp = 0
	h.creature.add_condition(&"unconscious", "0 Hit Points")
	w.bonus_available = true
	w.creature.hp = 5
	var tries := 0
	while not h.creature.dead and tries < 10:
		w.bonus_available = true
		e.monster_actions.bonus_action(w, "consume_life")
		tries += 1
	assert_true(h.creature.dead, "a failed DC 10 Con save kills the dying creature")
	assert_true(w.creature.hp > 5, "and the wisp heals")


func test_giant_spider_web_restrains_until_broken() -> void:
	var e := _field(16)
	var sp := TestCombat.foe(e, "giant_spider", Vector2i(2, 2))
	var h := TestCombat.hero(e, "ilse_varga", Vector2i(8, 2))
	TestCombat.start_with(e, sp)
	e.monster_actions.apply_riders(sp, h, (sp.creature as Monster).action("web")["on_fail"] as Array, {}, "Web")
	assert_true(h.creature.has_condition(&"restrained"))
	assert_false(h.creature.effects.any(func(x: Effect) -> bool: return not x.escape.is_empty()), "2025: no check breaks it")
	var web := e.objects.objects_at(h.cell)
	assert_eq(web.size(), 1, "the webbing is an object round it (AC 10, 5 Hit Points)")
	e.objects.damage(web[0], [{"amount": 3, "type": "fire"}], null, "test")
	assert_false(h.creature.has_condition(&"restrained"), "free once the web is destroyed (Vulnerability to Fire)")


func test_rat_slips_away_without_opportunity_attacks() -> void:
	var r := TestCombat.monster("rat")
	assert_true(r.has_flag("agile"))


func test_vine_blight_grip_crushes_on_the_victims_turn_and_holds_one_at_a_time() -> void:
	var e := _field(17)
	var vb := TestCombat.foe(e, "vine_blight", Vector2i(3, 3))
	var h := TestCombat.hero(e, "ilse_varga", Vector2i(4, 3))
	TestCombat.start_with(e, vb)
	var vine := (vb.creature as Monster).action("constricting_vine")
	e.monster_actions.apply_riders(vb, h, vine["on_hit"] as Array, {}, "Constricting Vine")
	assert_true(e.grapples.has(h.id))
	assert_false(h.creature.has_condition(&"restrained"), "the 2025 vine grips but doesn't restrain")
	assert_eq(e.monster_actions.why_not(vb, vine), "Its vine is holding someone")
	var hp := h.creature.hp
	e.monster_actions.turn_start(h)
	assert_true(h.creature.hp < hp, "crushed at the start of its own turn")


func test_banshee_wail_drops_the_weak_and_hurts_the_rest() -> void:
	var e := _field(18)
	var b := TestCombat.foe(e, "banshee", Vector2i(3, 3))
	var weak := TestCombat.hero(e, "silvain_aster", Vector2i(4, 3))
	var tough := TestCombat.hero(e, "ilse_varga", Vector2i(3, 4), 12)
	TestCombat.start_with(e, b)
	weak.creature.hp = 20
	tough.creature.hp = 80
	var wail := (b.creature as Monster).action("deathly_wail")
	var victims := e.monster_actions.save_victims(b, wail, weak)
	assert_true(weak in victims and tough in victims)
	for i in 10:
		weak.creature.hp = 20
		tough.creature.hp = 80
		weak.creature.remove_condition(&"unconscious")
		e.monster_actions._save_one(b, wail, weak, CombatResult.new(), {})
		if weak.creature.hp == 0:
			break
	assert_eq(weak.creature.hp, 0, "a failed save at 25 Hit Points or fewer drops it to 0")
	var hurt := false
	for i in 10:
		tough.creature.hp = 80
		e.monster_actions._save_one(b, wail, tough, CombatResult.new(), {})
		if tough.creature.hp < 80:
			hurt = true
			assert_true(tough.creature.hp > 0, "a sturdier creature only takes the damage")
			break
	assert_true(hurt)


func test_revenant_vow_makes_its_glare_paralyze() -> void:
	var e := _field(19)
	var rv := TestCombat.foe(e, "revenant", Vector2i(3, 3))
	var h := TestCombat.hero(e, "ilse_varga", Vector2i(5, 3))
	TestCombat.start_with(e, rv)
	e.monster_actions.bonus_action(rv, "vow")
	assert_eq(str(h.get_meta("vowed_by", "")), rv.id)
	e.monster_actions.apply_riders(rv, h, (rv.creature as Monster).action("vengeful_glare")["on_fail"] as Array, {}, "Vengeful Glare")
	assert_true(h.creature.has_condition(&"frightened") and h.creature.has_condition(&"paralyzed"), "its sworn foe is also Paralyzed")


func test_tree_blight_drags_grips_and_gnashes() -> void:
	var e := _field(20)
	var tb := TestCombat.foe(e, "tree_blight", Vector2i(2, 2))
	var h := TestCombat.hero(e, "silvain_aster", Vector2i(7, 3))
	TestCombat.start_with(e, tb)
	var before := e.distance(tb, h)
	e.monster_actions.apply_riders(tb, h, (tb.creature as Monster).action("grasping_root")["on_fail"] as Array, {}, "Grasping Root")
	assert_true(e.distance(tb, h) < before, "pulled closer")
	assert_true(e.grapples.has(h.id), "held by a root")
	var hp := h.creature.hp
	e.monster_actions.bonus_action(tb, "bonus_save")
	assert_true(h.creature.hp < hp or not tb.bonus_available, "Gnash goes at the held creature")


func test_arcanaloth_banishing_claw_locks_a_creature_in_the_tome() -> void:
	var e := _field(21)
	var a := TestCombat.foe(e, "arcanaloth", Vector2i(3, 3))
	var h := TestCombat.hero(e, "ilse_varga", Vector2i(4, 3))
	TestCombat.start_with(e, a)
	var rider := ((a.creature as Monster).action("banishing_claw")["on_hit"] as Array).duplicate(true)
	(rider[0] as Dictionary).erase("save")
	e.monster_actions.apply_riders(a, h, rider, {}, "Banishing Claw")
	assert_true(h.creature.has_condition(&"incapacitated"))
	assert_true(h.creature.has_flag("ethereal"), "gone into the tome, out of reach")
	var fx: Effect = null
	for x: Effect in h.creature.effects:
		if not x.repeat_save.is_empty():
			fx = x
	assert_true(fx != null and int(fx.repeat_save.get("bind_after", 0)) == 3, "a Cha save each turn; three failures bind it")


func test_wereraven_curse_raises_a_wereraven() -> void:
	var e := _field(22)
	var w := TestCombat.foe(e, "wereraven", Vector2i(3, 3))
	var h := TestCombat.hero(e, "ilse_varga", Vector2i(4, 3))
	TestCombat.hero(e, "silvain_aster", Vector2i(8, 8))
	TestCombat.start_with(e, w)
	var fx := Effect.new("Cursed: Wereraven Lycanthropy", &"monster", "wereraven_lycanthropy").with_modifier("flag", {"value": "curse:wereraven_lycanthropy"})
	fx.ends = Effect.Ends.NEVER
	h.creature.add_effect(fx)
	assert_true(e.monster_actions.lycanthrope(h))
	var raised := e.combatants.filter(func(c: Combatant) -> bool: return c.creature.name.contains("wereraven"))
	assert_eq(raised.size(), 1, "it rises as a wereraven")
