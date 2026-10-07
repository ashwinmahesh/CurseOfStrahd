extends TestCase

var _book_content: BookContentFixture

func before_each() -> void:
	_book_content = BookContentFixture.new()

func after_each() -> void:
	_book_content.restore()

func _cast(e: Encounter, c: Combatant, id: String, targets: Array = [], point: Vector2 = Vector2.INF, opts: Dictionary = {}) -> CombatResult:
	var data := Compendium.shared().spell_data(id)
	return e.spells.cast_with_numbers(c, id, int(data["level"]), targets, point,
		{"dc": Breakdown.new("DC").add("test", 40), "attack": Breakdown.new("Attack").add("test", 30), "mod": 5}, opts)

func test_wardaway_auto_success_and_action_choice() -> void:
	var e := TestCombat.open_field(1)
	var c := TestCombat.caster_with(e, ["wardaway"], Vector2i(2, 3))
	var target := TestCombat.punching_bag(e, Vector2i(4, 3), 500, "undead")
	TestCombat.start_with(e, c)
	assert_true(_cast(e, c, "wardaway", [target]).ok)
	assert_true(target.creature.hp < 500, "automatic success still takes half damage")
	assert_false(target.creature.has_flag("action_or_bonus"), "Undead avoid the failed-save effects")
	target.creature.creature_type = &"humanoid"
	c.action_available = true
	c.magic_action_used = false
	assert_true(_cast(e, c, "wardaway", [target]).ok)
	assert_false(target.creature.has_flag("action_or_bonus"), "restriction begins on the target’s next turn")
	assert_eq(target.speed(), 15)
	e.end_turn()
	assert_true(target.creature.has_flag("action_or_bonus"))

func test_uncertain_footing_prevents_dash_without_spending_action() -> void:
	var e := TestCombat.open_field(1)
	var c := TestCombat.caster_with(e, ["uncertain_footing"], Vector2i(2, 3))
	var t := TestCombat.punching_bag(e, Vector2i(4, 3), 500)
	TestCombat.start_with(e, c)
	assert_true(_cast(e, c, "uncertain_footing", [t]).ok)
	e.end_turn()
	assert_false(e.dash(t).ok)
	assert_true(t.action_available)
	c.creature.concentration.end("test")
	assert_false(t.creature.has_flag("cannot_dash"))

func test_disruptive_tune_breaks_existing_concentration() -> void:
	var e := TestCombat.open_field(1)
	var c := TestCombat.caster_with(e, ["disruptive_tune"], Vector2i(2, 3))
	var t := TestCombat.punching_bag(e, Vector2i(5, 3), 500)
	TestCombat.start_with(e, c)
	var concentration := t.creature.begin_concentration("test", "Test")
	assert_true(_cast(e, c, "disruptive_tune", [], Vector2(5.5, 3.5)).ok)
	assert_true(concentration.ended)
	assert_false((t.creature.d20_sources(["concentration"])["disadvantage"] as Array).is_empty())

func test_spellfire_flare_upcast_adds_separately_targeted_attacks() -> void:
	var e := TestCombat.open_field(1)
	var c := TestCombat.caster_with(e, ["spellfire_flare"], Vector2i(2, 3))
	var a := TestCombat.punching_bag(e, Vector2i(5, 3), 500)
	var b := TestCombat.punching_bag(e, Vector2i(5, 4), 500)
	TestCombat.start_with(e, c)
	e.drain_events()
	assert_true(e.spells.cast_with_numbers(c, "spellfire_flare", 3, [a, b], Vector2.INF,
		{"dc": Breakdown.new("DC").add("test", 40), "attack": Breakdown.new("Attack").add("test", 30), "mod": 5}).ok)
	var attacks := e.drain_events().filter(func(x: Dictionary) -> bool: return str(x["type"]) == "attack")
	assert_eq(attacks.size(), 3)
	assert_true(a.creature.hp < 500 and b.creature.hp < 500)

func test_aura_of_evasion_stops_helping_incapacitated_allies() -> void:
	var e := TestCombat.open_field(1)
	var c := TestCombat.caster_with(e, ["aura_of_evasion"], Vector2i(2, 3))
	var ally := TestCombat.hero(e, "ilse_varga", Vector2i(3, 3))
	TestCombat.punching_bag(e, Vector2i(8, 3), 500)
	TestCombat.start_with(e, c)
	assert_true(_cast(e, c, "aura_of_evasion").ok)
	assert_true(ally.creature.has_flag("evasion"))
	assert_false((ally.creature.d20_sources(["save:dex"])["advantage"] as Array).is_empty())
	ally.creature.add_condition(&"incapacitated", "test")
	assert_true((ally.creature.d20_sources(["save:dex"])["advantage"] as Array).is_empty())
	c.creature.concentration.end("test")
	e.spells.zones.prune()
	assert_false(ally.creature.has_flag("evasion"))

func test_vision_repeat_failure_adds_exhaustion_and_can_be_woken() -> void:
	var e := TestCombat.open_field(1)
	var c := TestCombat.caster_with(e, ["vision_of_elapsing_eons"], Vector2i(2, 3))
	var t := TestCombat.punching_bag(e, Vector2i(4, 3), 500)
	TestCombat.start_with(e, c)
	assert_true(_cast(e, c, "vision_of_elapsing_eons", [t]).ok)
	assert_true(t.creature.has_condition(&"paralyzed"))
	var fx := t.creature.effects[0]
	assert_true(bool(fx.data.get("wakeable", false)))
	e.spells._repeat_save(t, fx, [])
	assert_eq(t.creature.exhaustion, 1)
	assert_true(t.creature.has_condition(&"paralyzed"))

func test_festering_blast_ongoing_damage_does_not_upcast() -> void:
	var e := TestCombat.open_field(1)
	var c := TestCombat.caster_with(e, ["festering_blast"], Vector2i(2, 3))
	var t := TestCombat.punching_bag(e, Vector2i(4, 3), 500)
	TestCombat.start_with(e, c)
	assert_true(e.spells.cast_with_numbers(c, "festering_blast", 9, [], Vector2.INF,
		{"dc": Breakdown.new("DC").add("test", 40), "attack": Breakdown.new("Attack").add("test", 30), "mod": 5}, {"direction": Vector2.RIGHT}).ok)
	assert_true(t.creature.has_condition(&"poisoned"))
	assert_eq(str((t.creature.effects[0].data["turn_damage"] as Dictionary)["dice"]), "2d10")

func test_pending_spell_has_an_honest_disabled_reason() -> void:
	var e := TestCombat.open_field()
	var c := TestCombat.caster_with(e, ["hindsight"], Vector2i(2, 3))
	TestCombat.punching_bag(e, Vector2i(8, 3))
	TestCombat.start_with(e, c)
	var a := ActionCatalog.new(e).find(c, "spell:hindsight")
	assert_false(bool(a["legal"]))
	assert_eq(str(a["reason"]), "Not automated yet")

func test_blade_reuses_spell_weapon_with_two_attacks_and_shared_bonus_cost() -> void:
	var e := TestCombat.open_field(1)
	var c := TestCombat.caster_with(e, ["blade_of_disaster"], Vector2i(2, 3))
	var a := TestCombat.punching_bag(e, Vector2i(7, 3), 1000)
	var b := TestCombat.punching_bag(e, Vector2i(7, 4), 1000)
	TestCombat.start_with(e, c)
	e.drain_events()
	assert_true(_cast(e, c, "blade_of_disaster", [a, b], Vector2(6.5, 3.5)).ok)
	assert_eq(e.drain_events().filter(func(x: Dictionary) -> bool: return str(x["type"]) == "attack").size(), 2)
	assert_true(a.creature.hp < 1000 and b.creature.hp < 1000)
	var blade := e.spells.zones.object_of(c.id, "blade_of_disaster")
	assert_true(blade != null)
	var action := e.spells.sustained_for(c, "blade_of_disaster")
	assert_false(bool(action["legal"]), "activation already spent this turn's Bonus Action")
	while true:
		e.end_turn()
		if e.current() == c:
			break
	a.cell = Vector2i(9, 3)
	b.cell = Vector2i(9, 4)
	e.drain_events()
	var result := e.spells.use_sustained(c, str(action["id"]), [a, b], Vector2(8.5, 3.5))
	assert_true(result.ok, result.reason)
	assert_false(c.bonus_available)
	assert_true(c.action_available, "the two strikes share one Bonus Action")
	assert_eq(blade.cell, Vector2i(8, 3))
	assert_eq(e.drain_events().filter(func(x: Dictionary) -> bool: return str(x["type"]) == "attack").size(), 2)
	c.creature.concentration.end("test")
	e.spells.zones.prune()
	assert_true(e.spells.zones.object_of(c.id, "blade_of_disaster") == null)
	assert_true(e.spells.sustained_actions(c).is_empty())

func test_spell_critical_threshold_and_attack_origin_are_not_caster_position() -> void:
	var e := TestCombat.open_field(1)
	var c := TestCombat.caster_with(e, ["blade_of_disaster"], Vector2i(2, 3))
	var t := TestCombat.punching_bag(e, Vector2i(8, 3), 1000)
	TestCombat.start_with(e, c)
	t.creature.add_effect(Effect.new("Huge AC", &"effect", "test").with_modifier("ac", {"value": 100}))
	var ctx := {"c": c, "s": Compendium.shared().spell_data("blade_of_disaster"), "slot": 9,
		"nums": {"attack": Breakdown.new("Attack"), "dc": Breakdown.new("DC"), "mod": 0}, "conc": null, "opts": {}, "attack_origin": Vector2i(7, 3)}
	TestCombat.next_d20(e, 18)
	var result := CombatResult.new()
	var rolled := e.spells.spell_attack(ctx, t, result)
	assert_true(rolled.success and rolled.critical, "18 is a Critical Hit even against otherwise unreachable AC")
	assert_true(result.damage >= 20, "critical rolls twenty d6")
	t.creature.add_condition(&"prone", "test")
	var sit := e.attack_situation(c, t, {"kind": "spell", "melee": true, "profile": WeaponProfile.new(), "origin_cell": Vector2i(7, 3)})
	assert_true("target Prone within 5 ft" in (sit["advantage"] as Array))
	assert_false("target Prone beyond 5 ft" in (sit["disadvantage"] as Array))

func test_blade_validates_every_target_before_bonus_action_or_movement() -> void:
	var e := TestCombat.open_field(1)
	var c := TestCombat.caster_with(e, ["blade_of_disaster"], Vector2i(2, 3))
	var a := TestCombat.punching_bag(e, Vector2i(7, 3), 1000)
	var b := TestCombat.punching_bag(e, Vector2i(1, 7), 1000)
	TestCombat.start_with(e, c)
	assert_true(_cast(e, c, "blade_of_disaster", [a], Vector2(6.5, 3.5)).ok)
	var blade := e.spells.zones.object_of(c.id, "blade_of_disaster")
	while true:
		e.end_turn()
		if e.current() == c:break
	var a0 := e.spells.sustained_for(c, "blade_of_disaster")
	assert_false(e.spells.use_sustained(c, str(a0["id"]), [a, b], Vector2(7.5, 3.5)).ok)
	assert_true(c.bonus_available)
	assert_eq(blade.cell, Vector2i(6, 3))

func test_death_armor_retaliates_once_per_turn_across_multiple_attackers() -> void:
	var e := TestCombat.open_field()
	var c := TestCombat.caster_with(e, ["death_armor"], Vector2i(2, 3))
	var a := TestCombat.punching_bag(e, Vector2i(3, 3), 500)
	var b := TestCombat.punching_bag(e, Vector2i(2, 4), 500)
	TestCombat.start_with(e, c)
	assert_true(_cast(e, c, "death_armor", [c]).ok)
	assert_false((c.creature.d20_sources(["death_save"])["advantage"] as Array).is_empty())
	e.retaliate(a, c)
	assert_true(a.creature.hp <= 498)
	e.retaliate(b, c)
	assert_eq(b.creature.hp, 500)
	e.end_turn()
	e.retaliate(b, c)
	assert_true(b.creature.hp <= 498)
	c.creature.advance_minutes(60)
	assert_true((c.creature.d20_sources(["death_save"])["advantage"] as Array).is_empty())

func test_enervation_drains_actual_damage_and_breaks_when_either_endpoint_moves() -> void:
	var e := TestCombat.open_field()
	var c := TestCombat.caster_with(e, ["enervation"], Vector2i(2, 3))
	var t := TestCombat.punching_bag(e, Vector2i(4, 3), 500)
	t.creature.base_resistances.append("necrotic")
	TestCombat.start_with(e, c)
	c.creature.hp = 1
	assert_true(_cast(e, c, "enervation", [t]).ok)
	assert_eq(c.creature.hp, mini(c.creature.max_hp(), 1 + (500 - t.creature.hp) / 2))
	assert_true(c.creature.concentration != null)
	while true:
		e.end_turn()
		if e.current() == c:break
	c.creature.hp = 1
	var before := t.creature.hp
	var act := e.spells.sustained_for(c, "enervation")
	assert_true(e.spells.use_sustained(c, str(act["id"])).ok)
	assert_true(before - t.creature.hp >= 1 and before - t.creature.hp <= 8, "2d8 is halved by Resistance")
	assert_eq(c.creature.hp, 1 + (before - t.creature.hp) / 2)
	var old := c.cell
	c.cell = Vector2i(40, 3)
	e.spells.zones.on_moved(c, old)
	assert_true(c.creature.concentration == null or c.creature.concentration.ended)
	assert_true(e.spells.sustained_actions(c).is_empty())

func test_enervation_success_heals_half_of_half_damage_and_grants_no_sustain() -> void:
	var e := TestCombat.open_field()
	var c := TestCombat.caster_with(e, ["enervation"], Vector2i(2, 3))
	var t := TestCombat.punching_bag(e, Vector2i(4, 3), 500)
	TestCombat.start_with(e, c)
	c.creature.hp = 1
	assert_true(e.spells.cast_with_numbers(c, "enervation", 5, [t], Vector2.INF,
		{"dc": Breakdown.new("DC").add("test", -100), "attack": Breakdown.new("Attack"), "mod": 5}).ok)
	assert_eq(c.creature.hp, mini(c.creature.max_hp(), 1 + (500 - t.creature.hp) / 2))
	assert_true(c.creature.concentration == null or c.creature.concentration.ended)
	assert_true(e.spells.sustained_actions(c).is_empty())

func test_sustained_casting_numbers_survive_json_save_and_load() -> void:
	var e := TestCombat.open_field()
	var c := TestCombat.caster_with(e, ["blade_of_disaster"], Vector2i(2, 3))
	var t := TestCombat.punching_bag(e, Vector2i(4, 3), 500)
	TestCombat.start_with(e, c)
	assert_true(_cast(e, c, "blade_of_disaster", [t]).ok)
	var saved := JSON.parse_string(JSON.stringify(EncounterSnapshot.capture(e))) as Dictionary
	var restored := EncounterSnapshot.restore(saved, DiceRoller.new(4))
	var rc := restored.get_c(c.id)
	var data := restored.spells.sustained_for(rc, "blade_of_disaster")
	var nums := SpellCaster._unpack_numbers(data["numbers"] as Dictionary)
	assert_eq((nums["attack"] as Breakdown).total(), 30)
	assert_eq((nums["dc"] as Breakdown).total(), 40)
	while true:
		restored.end_turn()
		if restored.current() == rc:break
	assert_true(restored.spells.use_sustained(rc, str(data["id"]), [restored.get_c(t.id)]).ok)

func test_viper_attack_duration_poison_immunity_and_curing() -> void:
	var e := TestCombat.open_field()
	var c := TestCombat.caster_with(e, ["sylunes_viper"], Vector2i(2, 3))
	var t := TestCombat.punching_bag(e, Vector2i(4, 3), 500)
	TestCombat.start_with(e, c)
	assert_true(_cast(e, c, "sylunes_viper").ok)
	assert_eq(c.creature.temp_hp, 15)
	assert_eq(c.creature.speed("climb").total(), c.speed())
	var a := e.spells.sustained_for(c, "sylunes_viper")
	assert_eq(int(a["rounds_left"]), 600)
	TestCombat.next_d20(e, 10)
	assert_true(e.spells.use_sustained(c, str(a["id"]), [t]).ok)
	assert_true(t.creature.has_condition(&"poisoned"))
	assert_true(t.creature.has_condition(&"incapacitated"))
	e.spells.cure(t, &"poisoned")
	assert_false(t.creature.has_condition(&"incapacitated"), "curing the primary condition removes its rider")
	t.creature.base_condition_immunities.append("poisoned")
	c.action_available = true
	c.magic_action_used = false
	TestCombat.next_d20(e, 10)
	assert_true(e.spells.use_sustained(c, str(a["id"]), [t]).ok)
	assert_false(t.creature.has_condition(&"incapacitated"))
	e.deal_damage(t, c, [{"amount": 15, "type": "force"}], false, "test")
	assert_true(e.spells.sustained_for(c, "sylunes_viper").is_empty())
	assert_eq(c.creature.speed("climb").total(), 0)

func test_wail_hearing_death_ward_and_hour_duration() -> void:
	var e := TestCombat.open_field()
	var c := TestCombat.caster_with(e, ["wail_of_the_banshee"], Vector2i(2, 3))
	var weak := TestCombat.punching_bag(e, Vector2i(4, 3), 50)
	var deaf := TestCombat.punching_bag(e, Vector2i(4, 4), 40)
	var warded := TestCombat.punching_bag(e, Vector2i(5, 3), 40)
	var strong := TestCombat.punching_bag(e, Vector2i(5, 4), 500)
	deaf.creature.add_condition(&"deafened", "test")
	warded.creature.add_effect(Effect.new("Death Ward").with_modifier("flag", {"value": "death_ward"}))
	TestCombat.start_with(e, c)
	var conc := weak.creature.begin_concentration("test", "test")
	assert_true(_cast(e, c, "wail_of_the_banshee", [weak, deaf, warded, strong]).ok)
	assert_true(weak.creature.dead)
	assert_true(conc.ended)
	assert_eq(deaf.creature.hp, 40)
	assert_eq(warded.creature.hp, 40)
	assert_false(warded.creature.has_flag("death_ward"))
	assert_true(strong.creature.has_condition(&"deafened"))
	strong.creature.advance_minutes(59)
	assert_true(strong.creature.has_condition(&"deafened"))
	strong.creature.advance_minutes(1)
	assert_false(strong.creature.has_condition(&"deafened"))

func test_waves_caps_total_exhaustion_and_removes_only_its_levels() -> void:
	var e := TestCombat.open_field()
	var c := TestCombat.caster_with(e, ["waves_of_exhaustion"], Vector2i(2, 3))
	var t := TestCombat.punching_bag(e, Vector2i(4, 3), 500)
	t.creature.add_exhaustion(3)
	TestCombat.start_with(e, c)
	assert_true(_cast(e, c, "waves_of_exhaustion").ok)
	var a := e.spells.sustained_for(c, "waves_of_exhaustion")
	assert_true(e.spells.use_sustained(c, str(a["id"]), [], Vector2.INF, Vector2.RIGHT).ok)
	assert_eq(t.creature.exhaustion, 4)
	c.action_available = true
	c.magic_action_used = false
	assert_true(e.spells.use_sustained(c, str(a["id"]), [], Vector2.INF, Vector2.RIGHT).ok)
	assert_eq(t.creature.exhaustion, 4)
	t.creature.add_exhaustion()
	c.creature.concentration.end("test")
	assert_eq(t.creature.exhaustion, 4, "keeps three earlier levels and one later level")

func test_catnap_interruption_completion_and_long_rest_lockout() -> void:
	var e := TestCombat.open_field()
	var c := TestCombat.caster_with(e, ["catnap"], Vector2i(2, 3))
	var ally := TestCombat.hero(e, "ilse_varga", Vector2i(3, 3))
	TestCombat.punching_bag(e, Vector2i(10, 3))
	ally.creature.set_resource("test_short", "Test", 1, "short")
	ally.creature.spend_resource("test_short")
	TestCombat.start_with(e, c)
	assert_true(_cast(e, c, "catnap", [ally]).ok)
	ally.creature.advance_minutes(9)
	assert_eq(ally.creature.resource_left("test_short"), 0)
	e.spells.cure(ally, &"unconscious")
	ally.creature.advance_minutes(1)
	assert_eq(ally.creature.resource_left("test_short"), 0)
	c.action_available = true
	c.magic_action_used = false
	assert_true(_cast(e, c, "catnap", [ally]).ok)
	ally.creature.advance_minutes(10)
	assert_eq(ally.creature.resource_left("test_short"), 1)
	assert_true(ally.creature.has_flag("catnap_rested"))
	c.action_available = true
	c.magic_action_used = false
	assert_false(_cast(e, c, "catnap", [ally]).ok)
	assert_true(c.action_available)
	ally.creature.finish_long_rest()
	assert_false(ally.creature.has_flag("catnap_rested"))

func test_lucubration_validates_selection_and_restores_upcast_slots() -> void:
	var e := TestCombat.open_field()
	var c := TestCombat.caster_with(e, ["mordenkainens_lucubration"], Vector2i(2, 3), 17)
	var ch := c.creature as Character
	TestCombat.punching_bag(e, Vector2i(10, 3))
	TestCombat.start_with(e, c)
	ch.slots_used[1] = 2
	ch.slots_used[2] = 1
	assert_false(_cast(e, c, "mordenkainens_lucubration", [], Vector2.INF, {"choice": "2+3"}).ok)
	assert_eq(ch.slots_used[1], 2)
	assert_true(c.action_available)
	assert_true(_cast(e, c, "mordenkainens_lucubration", [], Vector2.INF, {"choice": "2+2"}).ok)
	assert_eq(ch.slots_used[1], 0)
	assert_eq(ch.slots_used[2], 1)
	c.action_available = true
	c.magic_action_used = false
	assert_true(e.spells.cast_with_numbers(c, "mordenkainens_lucubration", 6, [], Vector2.INF,
		{"dc": Breakdown.new("DC"), "attack": Breakdown.new("Attack"), "mod": 5}, {"choice": "3"}).ok)
	assert_eq(ch.slots_used[2], 0)

func test_new_summon_forms_scale_and_remain_player_controlled() -> void:
	var nums := {"attack": Breakdown.new("Attack").add("test", 12), "dc": Breakdown.new("DC").add("test", 20)}
	for form: String in ["ankylosaur", "triceratops", "tyrannosaur"]:
		var block := SummonBlocks.for_spell("summon_dinosaur", 8, form, nums)
		var creature := Monster.from_data(block)
		assert_eq(creature.max_hp(), 80)
		assert_eq(creature.ac_value(), 21 if form == "ankylosaur" else 19)
		assert_eq(creature.save_bonus(&"str").total(), 9)
		assert_eq(creature.save_bonus(&"con").total(), 6)
		assert_eq(int(((block["actions"] as Array)[0]["multiattack"] as Array)[0]["count"]), 4)
	var e := TestCombat.open_field()
	var c := TestCombat.caster_with(e, ["summon_plant"], Vector2i(1, 3))
	TestCombat.punching_bag(e, Vector2i(10, 3), 500)
	TestCombat.start_with(e, c)
	assert_true(_cast(e, c, "summon_plant", [], Vector2(4.5, 3.5), {"choice": "vine"}).ok)
	var spirit := e.get_c(str((e.spells.summoned[c.id] as Array)[0]))
	assert_true(spirit.is_player_controlled())
	assert_eq(spirit.creature.speed("climb").total(), 40)
	assert_eq(spirit.creature.vulnerability_source(&"slashing"), spirit.creature.base_label)
	assert_eq(e.order.find(spirit), e.order.find(c) + 1)
	c.creature.concentration.end("test")
	e.spells.zones.prune()
	assert_false(spirit.is_alive())

func test_fungus_spores_damage_existing_poison_without_refreshing_it() -> void:
	var block := SummonBlocks.plant_spirit(5, "fungus", 12)
	var fungus := Monster.from_data(block)
	var target := TestChars.dummy(500)
	assert_eq(fungus.extra_damage_dice("spore_spray", target).size(), 0)
	target.add_condition(&"poisoned", "test")
	var dice := fungus.extra_damage_dice("spore_spray", target)
	assert_eq(dice.size(), 1)
	assert_eq(str(dice[0]["dice"]), "3d4")
	var e := TestCombat.open_field()
	var c := e.add(fungus, &"party", Vector2i(2, 3))
	var t := e.add(target, &"enemy", Vector2i(3, 3))
	e.monster_actions.apply_riders(c, t, fungus.action("spore_spray")["on_hit"] as Array, {}, "Spore Spray")
	assert_eq(t.creature.effects.size(), 0, "already Poisoned takes damage instead of refreshing the condition")

func test_pain_checks_hp_before_damage_and_links_all_penalties_to_charm() -> void:
	var e := TestCombat.open_field()
	var c := TestCombat.caster_with(e, ["power_word_pain"], Vector2i(2, 3))
	var t := TestCombat.punching_bag(e, Vector2i(4, 3), 101)
	TestCombat.start_with(e, c)
	assert_true(_cast(e, c, "power_word_pain", [t]).ok)
	assert_true(t.creature.hp < 101)
	assert_false(t.creature.has_condition(&"charmed"), "threshold is before the damage")
	t.creature.hp = 100
	c.action_available = true
	c.magic_action_used = false
	assert_true(_cast(e, c, "power_word_pain", [t]).ok)
	assert_true(t.creature.has_condition(&"charmed"))
	assert_eq(t.creature.speed().total(), 10)
	assert_true((t.creature.d20_sources(["save:all", "save:con"])["disadvantage"] as Array).is_empty())
	assert_false((t.creature.d20_sources(["save:all", "save:wis"])["disadvantage"] as Array).is_empty())
	e.spells.cure(t, &"charmed")
	assert_eq(t.creature.speed().total(), 30)
	assert_false(t.creature.effects.any(func(fx: Effect) -> bool: return fx.data.has("casting_save")))

func test_pain_failed_cast_spends_time_not_slot_or_existing_concentration() -> void:
	var e := TestCombat.open_field()
	var c := TestCombat.caster_with(e, ["magic_missile", "shield"], Vector2i(2, 3))
	var enemy := TestCombat.punching_bag(e, Vector2i(5, 3), 500)
	TestCombat.start_with(e, c)
	var fx := Effect.new("Pain", &"spell", "power_word_pain").with_condition(&"charmed")
	fx.data["casting_save"] = {"ability": "con", "dc": 100}
	c.creature.add_effect(fx)
	var conc := c.creature.begin_concentration("test", "Test")
	var ch := c.creature as Character
	var slots := ch.slots_left(1)
	assert_true(e.spells.cast(c, "magic_missile", 1, [enemy]).ok)
	assert_eq(enemy.creature.hp, 500)
	assert_eq(ch.slots_left(1), slots)
	assert_false(c.action_available)
	assert_false(conc.ended)
	assert_false(e.spells.cast_shield(c))
	assert_false(c.reaction_available)
	assert_eq(ch.slots_left(1), slots)
	assert_false(c.creature.effects.any(func(ef: Effect) -> bool: return ef.source_id == "shield"))

func test_prescience_replaces_failed_d20_but_twenty_is_not_automatic_save_success() -> void:
	var e := TestCombat.open_field()
	var c := _fate_caster(e, "moment_of_prescience")
	TestCombat.punching_bag(e, Vector2i(8, 3))
	TestCombat.start_with(e, c)
	var ch := c.creature as Character
	var slots := ch.slots_left(8)
	var test := D20Test.from_natural(D20Test.Kind.SAVING_THROW, 2, 3, 30)
	e.spells.after_failed_d20(c, test)
	assert_eq(test.kept, 20)
	assert_false(test.success)
	assert_eq(ch.slots_left(8), slots - 1)
	assert_false(c.reaction_available)
	assert_true(c.cast_slot_spell_this_turn)

func test_prescience_can_turn_critical_hit_into_miss_and_never_policy_is_respected() -> void:
	var e := TestCombat.open_field()
	var c := _fate_caster(e, "moment_of_prescience")
	var enemy := TestCombat.punching_bag(e, Vector2i(4, 3), 500)
	TestCombat.start_with(e, enemy)
	var hit := D20Test.from_natural(D20Test.Kind.ATTACK_ROLL, 20, 50, c.creature.ac_value())
	assert_true(e.spells.answer_incoming_roll(c, hit, "moment_of_prescience"))
	assert_eq(hit.kept, 1)
	assert_false(hit.critical)
	assert_false(hit.success)
	c.reset_turn()
	c.reaction_rules["moment_of_prescience"] = "never"
	var fail := D20Test.from_natural(D20Test.Kind.ABILITY_CHECK, 1, 0, 10)
	e.spells.after_failed_d20(c, fail)
	assert_eq(fail.kept, 1)
	assert_true(c.reaction_available)

func test_reweave_fate_adds_advantage_and_grants_thp_only_on_success() -> void:
	var e := TestCombat.open_field()
	var c := _fate_caster(e, "reweave_fate")
	var ally := TestCombat.hero(e, "ilse_varga", Vector2i(3, 3))
	TestCombat.punching_bag(e, Vector2i(8, 3))
	TestCombat.start_with(e, c)
	var test := D20Test.from_natural(D20Test.Kind.SAVING_THROW, 1, 0, 2)
	TestCombat.next_d20(e, 20)
	e.spells.after_failed_d20(ally, test)
	assert_true(test.advantage)
	assert_true(test.success)
	assert_true(ally.creature.temp_hp >= 6 and ally.creature.temp_hp <= 60)
	c.reset_turn()
	ally.creature.temp_hp = 0
	var fail := D20Test.from_natural(D20Test.Kind.SAVING_THROW, 1, 0, 99)
	fail.disadvantage = true
	e.spells.after_failed_d20(ally, fail)
	assert_false(fail.advantage, "new Advantage cancels existing Disadvantage")
	assert_false(fail.disadvantage)
	assert_eq(fail.rolls.size(), 1)
	assert_eq(ally.creature.temp_hp, 0)

func _fate_caster(e: Encounter, spell: String) -> Combatant:
	var ch := TestChars.custom("wizard", "human", 17)
	(ch.spellcasting[0]["prepared"] as Array).append(spell)
	var c := e.add(ch, &"party", Vector2i(2, 3))
	c.reaction_rules[spell] = "auto"
	return c

func test_large_summon_validates_whole_footprint_and_visibility_before_cost() -> void:
	var e := TestCombat.open_field()
	var c := TestCombat.caster_with(e, ["summon_dinosaur"], Vector2i(2, 3))
	TestCombat.punching_bag(e, Vector2i(7, 4))
	TestCombat.start_with(e, c)
	assert_false(_cast(e, c, "summon_dinosaur", [], Vector2(6.5, 3.5)).ok)
	assert_true(c.action_available)
	c.creature.add_condition(&"blinded", "test")
	assert_false(_cast(e, c, "summon_dinosaur", [], Vector2(4.5, 3.5)).ok)
	assert_true(c.action_available)

func test_charge_requires_target_directed_run_and_cannot_reuse_previous_attack_movement() -> void:
	var e := TestCombat.open_field()
	var data := SummonBlocks.dinosaur_spirit(6, "triceratops", 20, 20)
	var c := e.add(Monster.from_data(data), &"party", Vector2i(2, 3))
	var t := TestCombat.punching_bag(e, Vector2i(8, 3), 500)
	TestCombat.start_with(e, c)
	var option := {"action_id": "gore"}
	c.record_step(Vector2i(2, 3), Vector2i(4, 3))
	c.record_step(Vector2i(4, 3), Vector2i(4, 4))
	c.record_step(Vector2i(4, 4), Vector2i(6, 4))
	c.cell = Vector2i(6, 4)
	c.moved = true
	assert_true(e.monster_actions.charge_of(c, t, option).is_empty(), "sideways step breaks the target-directed approach")
	c.clear_run()
	c.cell = Vector2i(2, 3)
	c.record_step(Vector2i(2, 3), Vector2i(6, 3))
	c.cell = Vector2i(6, 3)
	assert_false(e.monster_actions.charge_of(c, t, option).is_empty())
	c.clear_run()
	assert_true(e.monster_actions.charge_of(c, t, option).is_empty())

func test_lucubration_recovers_pact_slots_and_is_available_outside_combat() -> void:
	var ch := TestChars.custom("warlock", "human", 3)
	var e := TestCombat.open_field()
	var c := e.add(ch, &"party", Vector2i(2, 3))
	TestCombat.punching_bag(e, Vector2i(8, 3))
	TestCombat.start_with(e, c)
	assert_true(ch.expend_slot(2))
	assert_true(ch.expend_slot(2))
	assert_eq(ch.pact_slots_used, 2)
	assert_true(_cast(e, c, "mordenkainens_lucubration", [], Vector2.INF, {"choice": "2+2"}).ok)
	assert_eq(ch.pact_slots_used, 0)
	assert_true(FieldCasting.helpful(Compendium.shared().spell_data("mordenkainens_lucubration")))

func test_detonate_bursts_from_target_after_first_damage_and_excludes_it() -> void:
	var e := TestCombat.open_field()
	var c := TestCombat.caster_with(e, ["detonate"], Vector2i(2, 3))
	var center := TestCombat.punching_bag(e, Vector2i(5, 3), 1)
	var nearby := TestCombat.punching_bag(e, Vector2i(6, 3), 500)
	TestCombat.start_with(e, c)
	nearby.creature.drain_events()
	assert_true(_cast(e, c, "detonate", [center]).ok)
	assert_true(center.creature.dead)
	assert_true(nearby.creature.hp < 500)
	var rolls := nearby.creature.drain_events().filter(func(ev: Dictionary) -> bool: return str(ev["type"]) == "d20")
	assert_true(rolls.any(func(ev: Dictionary) -> bool: return "Dexterity" in str(ev["text"]) and "d20 dis" in str(ev["text"])))
	assert_true(c.creature.hp < c.creature.max_hp(), "caster is not exempt from the blast")

func test_detonate_does_not_double_damage_primary_or_burn_magical_objects() -> void:
	var e := TestCombat.open_field()
	var c := TestCombat.caster_with(e, ["detonate"], Vector2i(2, 3))
	var center := TestCombat.punching_bag(e, Vector2i(5, 3), 500)
	var wooden := TestCombat.punching_bag(e, Vector2i(6, 3), 500, "object")
	var magic := TestCombat.punching_bag(e, Vector2i(7, 3), 500, "object")
	var nearby := TestCombat.punching_bag(e, Vector2i(6, 4), 500)
	wooden.creature.add_effect(Effect.new("Wood").with_modifier("flag", {"value": "flammable"}))
	magic.creature.add_effect(Effect.new("Magic").with_modifier("flag", {"value": "magical"}))
	TestCombat.start_with(e, c)
	assert_true(_cast(e, c, "detonate", [center]).ok)
	assert_true(center.creature.hp >= 400 and center.creature.hp <= 490, "only the initial 10d10 hits the primary target")
	assert_true(wooden.creature.hp < 500)
	assert_true(wooden.creature.effects.any(func(fx: Effect) -> bool: return fx.source_id == "burning"))
	assert_eq(magic.creature.hp, 500)
	assert_eq(wooden.creature.hp, nearby.creature.hp, "the burst uses the same damage roll for objects and creatures")
