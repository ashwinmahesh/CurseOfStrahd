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


# --- Summons --------------------------------------------------------------------------------------------

func _summoned(e: Encounter, c: Combatant) -> Combatant:
	for id: Variant in e.spells.summoned.get(c.id, []):
		var s := e.get_c(str(id))
		if s != null and s.is_alive():
			return s
	return null


func test_summon_beast_brings_a_pack_hunting_spirit_that_attacks_after_its_caster() -> void:
	var e := _field()
	var c := TestCombat.caster_with(e, ["summon_beast"], Vector2i(2, 3))
	TestCombat.punching_bag(e, Vector2i(8, 3), 100)
	TestCombat.start_with(e, c)
	assert_true(e.spells.cast(c, "summon_beast", 3, [], Vector2(3.5, 3.5), Vector2.ZERO, {"choice": "land"}).ok)
	var b := _summoned(e, c)
	assert_true(b != null)
	assert_eq(b.creature.ac_value(), 14, "AC 11 + level 3")
	assert_eq(b.creature.max_hp(), 35, "30 + 5 above level 2")
	assert_true(b.creature.has_flag("pack_tactics"))
	assert_true(b.is_player_controlled())
	assert_eq(e.order[e.order.find(c) + 1], b, "takes its turn right after the caster")


func test_summon_aberration_slaad_regenerates() -> void:
	var e := _field()
	var c := TestCombat.high_caster(e, ["summon_aberration"], Vector2i(2, 3))
	TestCombat.punching_bag(e, Vector2i(8, 3), 100)
	TestCombat.start_with(e, c)
	assert_true(e.spells.cast(c, "summon_aberration", 4, [], Vector2(3.5, 3.5), Vector2.ZERO, {"choice": "slaad"}).ok)
	var a := _summoned(e, c)
	a.creature.hp = 10
	e.end_turn()
	assert_eq(e.current(), a)
	assert_eq(a.creature.hp, 15, "Regeneration 5")


func test_metal_construct_spirit_burns_whoever_hits_it() -> void:
	var e := _field()
	var c := TestCombat.high_caster(e, ["summon_construct"], Vector2i(2, 3))
	var z := TestCombat.foe(e, "zombie", Vector2i(5, 3))
	z.creature.hp = 100
	TestCombat.start_with(e, c)
	assert_true(e.spells.cast(c, "summon_construct", 4, [], Vector2(4.5, 3.5), Vector2.ZERO, {"choice": "metal"}).ok)
	var k := _summoned(e, c)
	e.retaliate(z, k)
	assert_true(z.creature.hp < 100, "Heated Body")


func test_find_steed_heals_with_its_touch_and_shares_its_riders_healing() -> void:
	var e := _field()
	var c := TestCombat.caster_with(e, ["find_steed", "cure_wounds"], Vector2i(2, 3))
	TestCombat.punching_bag(e, Vector2i(9, 9), 100)
	TestCombat.start_with(e, c)
	assert_true(e.spells.cast(c, "find_steed", 2, [], Vector2(3.5, 3.5), Vector2.ZERO, {"choice": "celestial"}).ok)
	var st := _summoned(e, c)
	assert_eq(st.creature.size, &"large")
	assert_eq(st.creature.max_hp(), 25, "5 + 10 × level 2")
	st.creature.hp = 5
	c.creature.hp = 5
	c.action_available = true
	c.magic_action_used = false
	c.cast_slot_spell_this_turn = false
	assert_true(e.spells.cast(c, "cure_wounds", 1, [c]).ok)
	assert_true(st.creature.hp > 5, "Life Bond")
	e.end_turn()
	assert_eq(e.current(), st)
	var touch := {}
	for a in e.feature_actions.list(st):
		if str(a["id"]) == "feat:creature:healing_touch":
			touch = a
	assert_false(touch.is_empty(), "Healing Touch is offered")
	c.creature.hp = 3
	assert_true(e.feature_actions.perform(st, "creature:healing_touch", c, Vector2.INF).ok)
	assert_true(c.creature.hp > 3)
	assert_eq(str(e.feature_actions.list(st).filter(func(a: Dictionary) -> bool: return str(a["id"]) == "feat:creature:healing_touch")[0]["why"]) != "", true, "once per Long Rest")


func test_giant_spider_webs_its_target_in_place() -> void:
	var e := _field()
	var c := TestCombat.high_caster(e, ["giant_insect"], Vector2i(2, 3))
	var t := TestCombat.punching_bag(e, Vector2i(8, 3), 100)
	TestCombat.start_with(e, c)
	assert_true(e.spells.cast(c, "giant_insect", 4, [], Vector2(3.5, 3.5), Vector2.ZERO, {"choice": "spider"}).ok)
	var sp := _summoned(e, c)
	e.end_turn()
	assert_eq(e.current(), sp)
	TestCombat.next_d20(e, 19)
	assert_true(e.attack(sp, t, "monster:web_bolt").hit)
	assert_eq(t.speed(), 0, "Speed 0 until the start of the insect's next turn")


# --- Shapes, banishment, spheres, teleports ------------------------------------------------------------

func test_polymorph_turns_a_foe_into_a_beast_until_its_beast_hit_points_run_out() -> void:
	var e := _field()
	var c := TestCombat.high_caster(e, ["polymorph"], Vector2i(2, 3))
	var t := TestCombat.foe(e, "scout", Vector2i(5, 3))
	var real := t.creature
	var hp := real.hp
	TestCombat.start_with(e, c)
	TestCombat.next_d20(e, 1)
	assert_true(e.spells.cast(c, "polymorph", 4, [t], Vector2.INF, Vector2.ZERO, {"choice": "bat"}).ok)
	if real.has_flag("shapechanger"):
		assert_eq(t.creature, real, "a shapechanger is unaffected")
		return
	assert_true(e.shapes.is_shaped(t))
	assert_eq(t.creature.creature_type, &"beast")
	assert_eq(t.creature.hp, hp, "keeps its own Hit Points")
	assert_true(t.creature.temp_hp > 0, "the Beast's Hit Points as Temporary Hit Points")
	e.deal_damage(c, t, [{"amount": t.creature.temp_hp + 2, "type": "force"}], false, "test")
	assert_false(e.shapes.is_shaped(t), "back once the Temporary Hit Points are gone")
	assert_eq(t.creature, real)
	assert_eq(real.hp, hp - 2, "the rest of the damage carries over")


func test_polymorph_ends_with_concentration() -> void:
	var e := _field()
	var c := TestCombat.high_caster(e, ["polymorph"], Vector2i(2, 3))
	var a := TestCombat.hero(e, "ilse_varga", Vector2i(3, 3))
	TestCombat.start_with(e, c)
	assert_true(e.spells.cast(c, "polymorph", 4, [a]).ok)
	assert_true(e.shapes.is_shaped(a), "an ally doesn't resist")
	assert_true(a.creature is Monster)
	c.creature.concentration.end("test")
	assert_false(e.shapes.is_shaped(a))
	assert_true(a.creature is Character)


func test_banishment_removes_a_foe_until_the_spell_ends() -> void:
	var e := _field()
	var c := TestCombat.high_caster(e, ["banishment"], Vector2i(2, 3))
	var t := TestCombat.punching_bag(e, Vector2i(5, 3), 100)
	TestCombat.start_with(e, c)
	assert_true(e.spells.cast(c, "banishment", 4, [t]).ok)
	assert_true(t.creature.has_condition(&"incapacitated"))
	assert_true(e.distance(c, t) > 1000, "off the grid")
	c.creature.concentration.end("test")
	assert_eq(t.cell, Vector2i(5, 3), "back where it was")


func test_resilient_sphere_stops_damage_both_ways() -> void:
	var e := _field()
	var c := TestCombat.high_caster(e, ["otilukes_resilient_sphere"], Vector2i(2, 3))
	var t := TestCombat.punching_bag(e, Vector2i(5, 3), 100)
	TestCombat.start_with(e, c)
	assert_true(e.spells.cast(c, "otilukes_resilient_sphere", 4, [t]).ok)
	e.deal_damage(c, t, [{"amount": 20, "type": "fire"}], false, "test")
	assert_eq(t.creature.hp, 100)
	assert_true(e.attack_legal(c, t, e.attack_options(c)[0]) != "")


func test_dimension_door_takes_an_ally_along() -> void:
	var e := _field()
	var c := TestCombat.high_caster(e, ["dimension_door"], Vector2i(2, 3))
	var a := TestCombat.hero(e, "ilse_varga", Vector2i(3, 3))
	TestCombat.start_with(e, c)
	var dd := e.spells.cast(c, "dimension_door", 4, [], Vector2(10.5, 6.5), Vector2.ZERO, {"with": a.id})
	assert_true(dd.ok, dd.reason)
	assert_eq(c.cell, Vector2i(10, 6))
	assert_true(e.distance(c, a) <= 5, "the ally arrives beside")


# --- Areas and objects ------------------------------------------------------------------------------------

func test_spike_growth_hurts_for_every_square_walked() -> void:
	var e := _field()
	var c := TestCombat.caster_with(e, ["spike_growth"], Vector2i(0, 0))
	var t := TestCombat.punching_bag(e, Vector2i(2, 4), 200)
	TestCombat.start_with(e, c)
	assert_true(e.spells.cast(c, "spike_growth", 2, [], Vector2(6.0, 4.0)).ok)
	var hp := t.creature.hp
	e.end_turn()
	assert_eq(e.current(), t)
	assert_true(e.move(t, Vector2i(5, 4)).ok)
	assert_true(e.log.entries.filter(func(x: Dictionary) -> bool: return str(x["text"]).contains("Spike Growth")).size() >= 2, "hurt more than once")
	assert_true(t.creature.hp < hp)


func test_hunger_of_hadar_chills_at_the_start_and_burns_at_the_end() -> void:
	var e := _field()
	var c := TestCombat.caster_with(e, ["hunger_of_hadar"], Vector2i(0, 0))
	var t := TestCombat.punching_bag(e, Vector2i(6, 4), 200)
	TestCombat.start_with(e, c)
	assert_true(e.spells.cast(c, "hunger_of_hadar", 3, [], Vector2(6.5, 4.5)).ok)
	assert_true(t.creature.has_condition(&"blinded"))
	e.end_turn()
	assert_true(t.creature.hp < 200, "cold at the start of its turn")
	var hp := t.creature.hp
	e.end_turn()
	assert_true(t.creature.hp < hp, "acid at the end of its turn")


func test_wall_of_fire_covers_a_line_and_burns_its_chosen_side() -> void:
	var e := _field()
	var c := TestCombat.high_caster(e, ["wall_of_fire"], Vector2i(0, 0))
	var t := TestCombat.punching_bag(e, Vector2i(6, 5), 300)
	TestCombat.start_with(e, c)
	assert_true(e.spells.cast(c, "wall_of_fire", 4, [], Vector2(6.5, 3.5), Vector2.RIGHT).ok)
	var wall := e.spells.zones.object_of(c.id, "wall_of_fire")
	assert_true(wall.cells.size() >= 10, "a 60 ft wall")
	e.end_turn()
	e.end_turn()
	assert_true(t.creature.hp < 300, "ending a turn on the burning side")


func test_wind_wall_turns_aside_arrows() -> void:
	var e := _field()
	var c := TestCombat.caster_with(e, ["wind_wall"], Vector2i(0, 4))
	var t := TestCombat.punching_bag(e, Vector2i(9, 4), 200)
	TestCombat.start_with(e, c)
	assert_true(e.spells.cast(c, "wind_wall", 3, [], Vector2(5.5, 4.5), Vector2.DOWN).ok)
	var opt := _ranged(e, c)
	assert_true(e.attack_legal(c, t, e.option_by_id(c, opt)).contains("Wind Wall"))


func test_call_lightning_strikes_now_and_again_later() -> void:
	var e := _field()
	var c := TestCombat.caster_with(e, ["call_lightning"], Vector2i(0, 0))
	var t := TestCombat.punching_bag(e, Vector2i(6, 4), 300)
	TestCombat.start_with(e, c)
	assert_true(e.spells.cast(c, "call_lightning", 3, [], Vector2(6.5, 4.5)).ok)
	var hp := t.creature.hp
	assert_true(hp < 300)
	e.end_turn()
	while e.current() != c:
		e.end_turn()
	var bolt := e.spells.sustained_for(c, "call_lightning")
	assert_true(bool(bolt["legal"]), str(bolt["reason"]))
	assert_true(e.spells.use_sustained(c, str(bolt["id"]), [], Vector2(6.5, 4.5)).ok)
	assert_true(t.creature.hp < hp)


func test_cordon_of_arrows_runs_out_of_ammunition() -> void:
	var e := _field()
	var c := TestCombat.caster_with(e, ["cordon_of_arrows"], Vector2i(0, 0))
	TestCombat.start_with(e, c)
	assert_true(e.spells.cast(c, "cordon_of_arrows", 2, [], Vector2(1.0, 1.0)).ok)
	var o := e.spells.zones.object_of(c.id, "cordon_of_arrows")
	assert_eq(int(o.rules["charges"]), 4)
	var t := TestCombat.punching_bag(e, Vector2i(3, 3), 200)
	for i in 4:
		o.hit_on_turn.clear()
		e.spells.zones._affect(o, t, "enter", CombatResult.new(), {})
	assert_true(o.expired(), "no ammunition left")


func test_guardian_of_faith_vanishes_after_60_damage() -> void:
	var e := _field()
	var c := TestCombat.high_caster(e, ["guardian_of_faith"], Vector2i(0, 0))
	var t := TestCombat.punching_bag(e, Vector2i(6, 4), 300)
	TestCombat.start_with(e, c)
	assert_true(e.spells.cast(c, "guardian_of_faith", 4, [], Vector2(5.5, 4.5)).ok)
	var o := e.spells.zones.object_of(c.id, "guardian_of_faith")
	for i in 3:
		o.hit_on_turn.clear()
		e.spells.zones._affect(o, t, "start_turn", CombatResult.new(), {})
	assert_eq(t.creature.hp, 240, "20 a time")
	assert_true(o.expired())


func test_faithful_hound_bites_at_the_start_of_its_casters_turn() -> void:
	var e := _field()
	var c := TestCombat.high_caster(e, ["mordenkainens_faithful_hound"], Vector2i(0, 0))
	var t := TestCombat.punching_bag(e, Vector2i(4, 1), 300)
	TestCombat.start_with(e, c)
	assert_true(e.spells.cast(c, "mordenkainens_faithful_hound", 4, [], Vector2(3.5, 1.5)).ok)
	e.end_turn()
	while e.current() != c:
		e.end_turn()
	assert_true(t.creature.hp < 300)


func test_grasping_vine_pulls_its_victim_in() -> void:
	var e := _field()
	var c := TestCombat.high_caster(e, ["grasping_vine"], Vector2i(0, 0))
	var t := TestCombat.punching_bag(e, Vector2i(10, 4), 300)
	TestCombat.start_with(e, c)
	TestCombat.next_d20(e, 19)
	assert_true(e.spells.cast(c, "grasping_vine", 4, [], Vector2(5.5, 4.5)).ok)
	assert_true(t.creature.hp < 300, "lashed as the vine appears")
	assert_true(t.cell.x <= 7, "pulled toward the vine: %s" % t.cell)
	assert_true(t.creature.has_condition(&"grappled"))


func test_conjure_animals_pack_savages_foes_and_moves_with_its_caster() -> void:
	var e := _field()
	var c := TestCombat.caster_with(e, ["conjure_animals"], Vector2i(0, 0))
	var t := TestCombat.punching_bag(e, Vector2i(9, 4), 300)
	TestCombat.start_with(e, c)
	assert_true(e.spells.cast(c, "conjure_animals", 3, [], Vector2(4.0, 4.0)).ok)
	assert_eq(t.creature.hp, 300, "out of reach of the pack")
	var mv := e.spells.sustained_for(c, "conjure_animals")
	assert_true(bool(mv["legal"]), str(mv["reason"]))
	assert_true(e.spells.use_sustained(c, str(mv["id"]), [], Vector2(7.5, 4.5)).ok)
	assert_true(t.creature.hp < 300, "the pack moves within 10 ft")


func test_plant_growth_costs_four_feet_per_foot() -> void:
	var e := _field()
	var c := TestCombat.caster_with(e, ["plant_growth"], Vector2i(0, 0))
	var t := TestCombat.punching_bag(e, Vector2i(6, 4), 300)
	TestCombat.start_with(e, c)
	assert_true(e.spells.cast(c, "plant_growth", 3, [], Vector2(6.5, 4.5)).ok)
	e.end_turn()
	var reach := e.reachable_for(t)
	assert_false(reach.has(Vector2i(8, 4)), "30 ft of Speed covers less than 10 ft")
	assert_true(reach.has(Vector2i(7, 4)))


# --- Minds ---------------------------------------------------------------------------------------------

func test_confusion_takes_away_bonus_actions_and_reactions() -> void:
	var e := _field()
	var c := TestCombat.high_caster(e, ["confusion"], Vector2i(0, 0))
	var t := TestCombat.punching_bag(e, Vector2i(6, 4), 300)
	TestCombat.start_with(e, c)
	assert_true(e.spells.cast(c, "confusion", 4, [], Vector2(6.5, 4.5)).ok)
	assert_true(t.creature.has_flag("confused"))
	e.end_turn()
	assert_false(t.bonus_available)
	assert_true(e.log.entries.any(func(x: Dictionary) -> bool: return str(x["text"]).begins_with("Confusion (d10")))


func test_compelled_duel_hinders_attacks_on_others_and_ends_when_the_caster_turns_away() -> void:
	var e := _field()
	var c := TestCombat.caster_with(e, ["compelled_duel"], Vector2i(2, 3))
	var a := TestCombat.hero(e, "ilse_varga", Vector2i(2, 5))
	var t := TestCombat.punching_bag(e, Vector2i(3, 4), 300)
	var other := TestCombat.punching_bag(e, Vector2i(1, 3), 300)
	TestCombat.start_with(e, c)
	assert_true(e.spells.cast(c, "compelled_duel", 1, [t]).ok)
	var sit := e.attack_situation(t, a, e.attack_options(t)[0] if not e.attack_options(t).is_empty() else e.attack_options(c)[0])
	assert_true("Compelled Duel" in (sit["disadvantage"] as Array))
	assert_false(e.reachable_for(t, 60).has(Vector2i(11, 7)), "can't wander more than 30 ft away")
	TestCombat.next_d20(e, 19)
	e.attack(c, other, _melee(e, c))
	assert_true(c.creature.concentration == null, "the duel ends when the caster attacks someone else")


func test_dominate_beast_turns_a_beast_to_the_casters_side_until_it_breaks_free() -> void:
	var e := _field()
	var c := TestCombat.high_caster(e, ["dominate_beast"], Vector2i(2, 3))
	var w := TestCombat.punching_bag(e, Vector2i(4, 3), 100, "beast")
	TestCombat.start_with(e, c)
	assert_true(e.spells.cast(c, "dominate_beast", 4, [w]).ok)
	assert_true(w.is_player_controlled(), "under the player's command")
	assert_false(c.hostile_to(w))
	c.creature.concentration.end("test")
	assert_false(w.is_player_controlled())
	assert_true(c.hostile_to(w))


func test_dissonant_whispers_makes_its_victim_flee() -> void:
	var e := _field()
	var c := TestCombat.caster_with(e, ["dissonant_whispers"], Vector2i(2, 3))
	var t := TestCombat.punching_bag(e, Vector2i(3, 3), 300)
	e.default_player_reaction = "never"
	TestCombat.start_with(e, c)
	assert_true(e.spells.cast(c, "dissonant_whispers", 1, [t]).ok)
	assert_false(t.reaction_available)
	assert_true(e.distance(c, t) > 5, "ran away")


func test_heat_metal_sears_an_armoured_foe_each_turn() -> void:
	var e := _field()
	var c := TestCombat.caster_with(e, ["heat_metal"], Vector2i(2, 3))
	var t := TestCombat.foe(e, "bandit", Vector2i(5, 3))
	t.creature.hp = 100
	TestCombat.start_with(e, c)
	var r := e.spells.cast(c, "heat_metal", 2, [t])
	assert_true(r.ok, r.reason)
	assert_true(t.creature.hp < 100 or e.spells.specials.metal_of(t) == "")
	assert_false(e.spells.sustained_for(c, "heat_metal").is_empty())


# --- Cantrips -----------------------------------------------------------------------------------------

func test_eldritch_blast_fires_more_beams_with_level() -> void:
	var e := _field()
	var c := TestCombat.high_caster(e, ["eldritch_blast"], Vector2i(2, 3))
	var a := TestCombat.punching_bag(e, Vector2i(6, 3), 300)
	var b := TestCombat.punching_bag(e, Vector2i(6, 5), 300)
	TestCombat.start_with(e, c)
	assert_true(e.spells.cast(c, "eldritch_blast", 0, [a, b]).ok)
	var shots := e.drain_events().filter(func(x: Dictionary) -> bool: return str(x["type"]) == "attack" and str(x["attacker"]) == c.id)
	assert_eq(shots.size(), 2, "two beams at level 7")
