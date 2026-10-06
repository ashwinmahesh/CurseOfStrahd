extends TestCase
## Spells of levels 7 to 9 in a fight (combat/high_magic.gd). The class data stops at level 7, so these are cast
## with a stat-block caster's numbers (save DC 17, +9 to hit, +5 modifier), the way a monster or a magic item casts.


func _nums() -> Dictionary:
	return {"dc": Breakdown.new("DC").add("DC", 17), "attack": Breakdown.new("Attack").add("Attack", 9), "mod": 5}


func _field() -> Encounter:
	return TestCombat.open_field(5)


func _cast(e: Encounter, c: Combatant, id: String, level: int, targets: Array = [], point: Vector2 = Vector2.INF, opts: Dictionary = {}) -> CombatResult:
	c.action_available = true
	c.bonus_available = true
	c.magic_action_used = false
	return e.spells.cast_with_numbers(c, id, level, targets, point, _nums(), opts)


func _caster(e: Encounter) -> Combatant:
	return TestCombat.hero(e, "silvain_aster", Vector2i(1, 3))


func test_power_word_kill_kills_under_100_hit_points_and_hurts_above() -> void:
	var e := _field()
	var c := _caster(e)
	var weak := TestCombat.punching_bag(e, Vector2i(5, 3), 90)
	var strong := TestCombat.punching_bag(e, Vector2i(5, 5), 200)
	TestCombat.start_with(e, c)
	assert_true(_cast(e, c, "power_word_kill", 9, [weak]).ok)
	assert_true(weak.creature.dead)
	assert_true(_cast(e, c, "power_word_kill", 9, [strong]).ok)
	assert_false(strong.creature.dead)
	assert_true(strong.creature.hp < 200)


func test_power_word_stun_stuns_under_150_and_stops_the_rest() -> void:
	var e := _field()
	var c := _caster(e)
	var weak := TestCombat.punching_bag(e, Vector2i(5, 3), 140)
	var strong := TestCombat.punching_bag(e, Vector2i(5, 5), 200)
	TestCombat.start_with(e, c)
	assert_true(_cast(e, c, "power_word_stun", 8, [weak]).ok)
	assert_true(weak.creature.has_condition(&"stunned"))
	assert_true(_cast(e, c, "power_word_stun", 8, [strong]).ok)
	assert_false(strong.creature.has_condition(&"stunned"))
	assert_eq(strong.speed(), 0)


func test_power_word_heal_restores_everything() -> void:
	var e := _field()
	var c := _caster(e)
	var a := TestCombat.hero(e, "ilse_varga", Vector2i(2, 3))
	TestCombat.punching_bag(e, Vector2i(9, 7), 100)
	a.creature.hp = 3
	a.creature.add_condition(&"poisoned", "test")
	TestCombat.start_with(e, c)
	assert_true(_cast(e, c, "power_word_heal", 9, [a]).ok)
	assert_eq(a.creature.hp, a.creature.max_hp())
	assert_false(a.creature.has_condition(&"poisoned"))


func test_mass_heal_and_power_word_fortify_share_their_pools() -> void:
	var e := _field()
	var c := _caster(e)
	var a := TestCombat.hero(e, "ilse_varga", Vector2i(2, 3))
	var b := TestCombat.hero(e, "hedda_ironvow", Vector2i(2, 4))
	TestCombat.punching_bag(e, Vector2i(9, 7), 100)
	a.creature.hp = 1
	b.creature.hp = 1
	TestCombat.start_with(e, c)
	assert_true(_cast(e, c, "mass_heal", 9, [a, b]).ok)
	assert_eq(a.creature.hp, a.creature.max_hp())
	assert_eq(b.creature.hp, b.creature.max_hp())
	assert_true(_cast(e, c, "power_word_fortify", 7, [a, b]).ok)
	assert_eq(a.creature.temp_hp, 60)
	assert_eq(b.creature.temp_hp, 60)


func test_divine_word_by_hit_points() -> void:
	var e := _field()
	var c := _caster(e)
	var dead := TestCombat.punching_bag(e, Vector2i(3, 3), 15)
	var stunned := TestCombat.punching_bag(e, Vector2i(3, 5), 25)
	var fine := TestCombat.punching_bag(e, Vector2i(4, 3), 80)
	TestCombat.start_with(e, c)
	assert_true(_cast(e, c, "divine_word", 7, [dead, stunned, fine]).ok)
	assert_true(dead.creature.dead)
	assert_true(stunned.creature.has_condition(&"stunned"))
	assert_false(fine.creature.has_condition(&"deafened"))


func test_prismatic_spray_hits_with_rays() -> void:
	var e := _field()
	var c := _caster(e)
	var t := TestCombat.punching_bag(e, Vector2i(4, 3), 300)
	TestCombat.start_with(e, c)
	assert_true(e.spells.cast_with_numbers(c, "prismatic_spray", 7, [t], Vector2.INF, _nums()).ok)
	assert_true(t.creature.hp < 300 or t.creature.has_condition(&"restrained") or t.creature.has_condition(&"blinded"))


func test_maze_removes_a_creature_until_it_escapes_or_the_spell_ends() -> void:
	var e := _field()
	var c := _caster(e)
	var t := TestCombat.punching_bag(e, Vector2i(5, 3), 100)
	TestCombat.start_with(e, c)
	assert_true(_cast(e, c, "maze", 8, [t]).ok)
	assert_true(e.distance(c, t) > 1000)
	c.creature.concentration.end("test")
	assert_eq(t.cell, Vector2i(5, 3))


func test_forcecage_traps_the_creatures_inside() -> void:
	var e := _field()
	var c := _caster(e)
	var t := TestCombat.punching_bag(e, Vector2i(6, 3), 100)
	TestCombat.start_with(e, c)
	assert_true(_cast(e, c, "forcecage", 7, [], Vector2(6.0, 3.0), {"choice": "box"}).ok)
	var reach := e.reachable_for(t, 30)
	for cell: Vector2i in reach:
		assert_true(e.spells.specials.high.cage_of(t) == null or cell in e.spells.specials.high.cage_of(t).cells, "stays in the box")
	assert_true(e.attack_legal(c, t, e.attack_options(c)[0]) != "" or e.spells.specials.high.cage_of(t) == null)


func test_time_stop_gives_extra_turns_until_the_caster_touches_someone() -> void:
	var e := _field()
	var c := _caster(e)
	var t := TestCombat.punching_bag(e, Vector2i(6, 3), 100)
	TestCombat.start_with(e, c)
	assert_true(_cast(e, c, "time_stop", 9).ok)
	assert_true(int(c.get_meta("time_stop", 0)) >= 1)
	e.end_turn()
	assert_eq(e.current(), c, "the caster goes again")
	e.deal_damage(c, t, [{"amount": 1, "type": "force"}], false, "test")
	e.end_turn()
	assert_ne(e.current(), c, "touching someone ends it")


func test_reverse_gravity_lifts_and_drops() -> void:
	var e := _field()
	var c := _caster(e)
	var t := TestCombat.punching_bag(e, Vector2i(6, 3), 100)
	TestCombat.start_with(e, c)
	assert_true(_cast(e, c, "reverse_gravity", 7, [], Vector2(6.5, 3.5)).ok)
	assert_true(t.creature.has_flag("aloft"))
	c.creature.concentration.end("test")
	assert_true(t.creature.has_condition(&"prone"))
	assert_true(t.creature.hp < 100, "falling damage")


func test_true_polymorph_and_animal_shapes() -> void:
	var e := _field()
	var c := _caster(e)
	var a := TestCombat.hero(e, "ilse_varga", Vector2i(2, 3))
	var t := TestCombat.foe(e, "scout", Vector2i(6, 3))
	TestCombat.start_with(e, c)
	assert_true(_cast(e, c, "animal_shapes", 8, [a]).ok)
	assert_true(e.shapes.is_shaped(a))
	assert_eq(a.creature.creature_type, &"beast")
	TestCombat.next_d20(e, 1)
	assert_true(_cast(e, c, "true_polymorph", 9, [t]).ok)
	assert_true(e.shapes.is_shaped(t) or t.creature.has_flag("shapechanger"))


func test_delayed_blast_fireball_grows_and_bursts_when_let_go() -> void:
	var e := _field()
	var c := _caster(e)
	var t := TestCombat.punching_bag(e, Vector2i(7, 3), 300)
	TestCombat.start_with(e, c)
	assert_true(_cast(e, c, "delayed_blast_fireball", 7, [], Vector2(7.5, 3.5)).ok)
	var bead := e.spells.zones.object_of(c.id, "delayed_blast_fireball")
	assert_eq(int(bead.rules["bead_dice"]), 12)
	e.end_turn()
	assert_eq(int(bead.rules["bead_dice"]), 13, "grows at the end of the caster's turn")
	assert_eq(t.creature.hp, 300)
	c.creature.concentration.end("test")
	assert_true(t.creature.hp < 300, "bursts when the spell ends")


func test_storm_of_vengeance_rains_acid_on_its_second_round() -> void:
	var e := _field()
	var c := _caster(e)
	var t := TestCombat.punching_bag(e, Vector2i(7, 3), 500)
	TestCombat.start_with(e, c)
	assert_true(_cast(e, c, "storm_of_vengeance", 9, [], Vector2(6.5, 4.5)).ok)
	var hp := t.creature.hp
	e.end_turn()
	while e.current() != c:
		e.end_turn()
	assert_true(t.creature.hp < hp, "acid rain")


func test_meteor_swarm_strikes_several_points_once_each() -> void:
	var e := _field()
	var c := _caster(e)
	var t := TestCombat.punching_bag(e, Vector2i(10, 6), 500)
	TestCombat.start_with(e, c)
	assert_true(_cast(e, c, "meteor_swarm", 9, [], Vector2(10.5, 6.5), {"points": [Vector2(10.5, 6.5), Vector2(10.5, 5.5)]}).ok)
	var hits := e.drain_events().filter(func(x: Dictionary) -> bool: return str(x["type"]) == "damage" and str(x["id"]) == t.id)
	assert_eq(hits.size(), 1, "one blast's worth, however many spheres overlap")


func test_antimagic_field_stops_spells_inside_and_suppresses_effects() -> void:
	var e := _field()
	var c := _caster(e)
	var a := TestCombat.hero(e, "ilse_varga", Vector2i(2, 3))
	var t := TestCombat.punching_bag(e, Vector2i(9, 7), 100)
	TestCombat.start_with(e, c)
	var bless := Effect.new("Bless", &"spell", "bless").with_modifier("bonus_die", {"dice": "1d4", "on": ["attack"]})
	a.creature.add_effect(bless)
	assert_true(_cast(e, c, "antimagic_field", 8).ok)
	assert_false(bless in a.creature.effects, "Bless is suppressed inside")
	assert_false(_cast(e, c, "magic_missile", 1, [t]).ok, "no casting inside")
	e.spells.zones.end_spell(c.id, "antimagic_field")
	e.spells.zones.refresh_auras()
	assert_true(bless in a.creature.effects, "back when the field is gone")


func test_conjure_celestial_heals_allies_and_burns_foes() -> void:
	var e := _field()
	var c := _caster(e)
	var a := TestCombat.hero(e, "ilse_varga", Vector2i(6, 3))
	var t := TestCombat.punching_bag(e, Vector2i(6, 4), 300)
	a.creature.hp = 5
	TestCombat.start_with(e, c)
	assert_true(_cast(e, c, "conjure_celestial", 7, [], Vector2(6.5, 3.5)).ok)
	assert_true(a.creature.hp > 5)
	assert_true(t.creature.hp < 300)
