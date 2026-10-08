extends TestCase
## The spells' secondary effects (spell audit, docs/contracts/spells.md): pushes and pulls, lingering areas,
## spell objects and the actions they grant, effect durations, reactions, summons, sight.


func _setup(spells: Array, seed_value: int = 1) -> Encounter:
	var e := TestCombat.open_field(seed_value)
	TestCombat.caster_with(e, spells, Vector2i(2, 3))
	return e


func _caster(e: Encounter) -> Combatant:
	return e.combatants[0]


func test_thunderwave_pushes_a_pack_back_farthest_first() -> void:
	var e := TestCombat.open_field(3)
	var s := TestCombat.hero(e, "silvain_aster", Vector2i(3, 3))
	var a := TestCombat.punching_bag(e, Vector2i(4, 3))
	var b := TestCombat.punching_bag(e, Vector2i(5, 3))
	TestCombat.start_with(e, s)
	var r := e.spells.cast(s, "thunderwave", 1, [], Vector2.INF, Vector2.RIGHT)
	assert_true(r.ok, r.reason)
	assert_eq(b.cell, Vector2i(7, 3), "the back wolf is pushed first")
	assert_eq(a.cell, Vector2i(6, 3), "so the front one isn't blocked by it")
	var moves := e.drain_events().filter(func(ev: Dictionary) -> bool: return str(ev["type"]) == "move" and bool(ev.get("forced", false)))
	assert_true(moves.size() >= 4, "the scene animates every pushed square")


func test_thorn_whip_pulls_toward_the_caster() -> void:
	var e := _setup(["thorn_whip"], 2)
	var c := _caster(e)
	var t := TestCombat.punching_bag(e, Vector2i(7, 3))
	TestCombat.start_with(e, c)
	assert_true(e.spells.cast(c, "thorn_whip", 0, [t]).ok)
	assert_eq(t.cell, Vector2i(5, 3), "pulled 10 ft closer")


func test_spiritual_weapon_is_an_object_on_the_field_with_its_own_bonus_action() -> void:
	var e := TestCombat.open_field(13)
	var h := TestCombat.hero(e, "hedda_ironvow", Vector2i(1, 3))
	var w := TestCombat.punching_bag(e, Vector2i(6, 3), 200)
	TestCombat.start_with(e, h)
	var r := e.spells.cast(h, "spiritual_weapon", 2, [w])
	assert_true(r.ok, r.reason)
	var weapon := e.spells.weapon_of(h)
	assert_true(weapon != null, "a weapon on the battlefield")
	assert_eq(weapon.kind, FieldObject.Kind.WEAPON)
	assert_true(e.grid.distance_ft(weapon.cell, 1, w.cell, 1) <= 5, "it appears beside the target")
	var cat := ActionCatalog.new(e)
	var strike := {}
	for a in cat.actions_for(h):
		if str(a["kind"]) == "sustain":
			strike = a
	assert_false(strike.is_empty(), "the hotbar offers the weapon's strike")
	assert_false(bool(strike["legal"]), "not on the turn it was cast")
	e.end_turn()
	e.end_turn()
	strike = cat.find(h, str(strike["id"]))
	assert_true(bool(strike["legal"]), str(strike["reason"]))
	w.cell = Vector2i(9, 5)
	var r2 := cat.perform(h, strike, [w])
	assert_true(r2.ok, r2.reason)
	assert_false(h.bonus_available)
	assert_true(e.grid.distance_ft(e.spells.weapon_of(h).cell, 1, w.cell, 1) <= 5, "the weapon flew to the target")
	h.creature.concentration.end("test")
	e.spells.zones.prune()
	assert_true(e.spells.weapon_of(h) == null, "gone when Concentration ends")


func test_spiritual_weapon_can_be_placed_on_an_empty_square() -> void:
	var e := TestCombat.open_field(13)
	var h := TestCombat.hero(e, "hedda_ironvow", Vector2i(1, 3))
	TestCombat.punching_bag(e, Vector2i(9, 3))
	TestCombat.start_with(e, h)
	var r := e.spells.cast(h, "spiritual_weapon", 2, [], Vector2(4.5, 4.5))
	assert_true(r.ok, r.reason)
	assert_eq(e.spells.weapon_of(h).cell, Vector2i(4, 4))


func test_spirit_guardians_lingers_spares_allies_and_hurts_enemies_ending_turns_inside() -> void:
	var e := _setup(["spirit_guardians"], 4)
	var c := _caster(e)
	var ally := TestCombat.hero(e, "ilse_varga", Vector2i(3, 3))
	var foe := TestCombat.punching_bag(e, Vector2i(4, 3))
	var far := TestCombat.punching_bag(e, Vector2i(9, 3))
	TestCombat.start_with(e, c)
	var r := e.spells.cast(c, "spirit_guardians", 3)
	assert_true(r.ok, r.reason)
	assert_true(c.creature.concentration != null, "Concentration holds")
	assert_eq(e.spells.zones.live().size(), 1)
	var hp_ally := ally.creature.hp
	var hp_foe := foe.creature.hp
	e.end_turn()   # caster's turn ends; each creature's own turn end triggers the aura
	while e.current() != c:
		e.end_turn()
	assert_eq(ally.creature.hp, hp_ally, "allies are spared")
	assert_true(foe.creature.hp < hp_foe, "an enemy ending its turn inside takes damage")
	# Moving the aura onto a creature counts.
	var hp_far := far.creature.hp
	c.movement_left = 60
	e.move(c, Vector2i(6, 3))
	assert_true(far.creature.hp < hp_far, "the aura moved into its space")


## Owner's playtest (2026-10-08): foes already inside when Spirit Guardians is cast take its damage then (the spirits
## appearing count as the Emanation entering their space); after that a foe saves when it enters, when the aura moves
## onto it and when it ends its turn inside, at most once a turn.
func test_spirit_guardians_hurts_foes_inside_as_it_appears_and_once_a_turn_after() -> void:
	var e := _setup(["spirit_guardians"], 4)
	var c := _caster(e)
	var ally := TestCombat.hero(e, "ilse_varga", Vector2i(3, 3))
	var near := TestCombat.punching_bag(e, Vector2i(4, 3))
	var far := TestCombat.punching_bag(e, Vector2i(9, 3))
	TestCombat.start_with(e, c)
	var hp_ally := ally.creature.hp
	var hp_near := near.creature.hp
	var hp_far := far.creature.hp
	assert_true(e.spells.cast(c, "spirit_guardians", 3).ok)
	assert_true(near.creature.hp < hp_near, "the foe inside takes the damage as the spirits appear")
	assert_eq(far.creature.hp, hp_far, "not the foe outside")
	assert_eq(ally.creature.hp, hp_ally, "the ally is spared")
	e.end_turn()
	while e.current() != far:
		e.end_turn()
	far.movement_left = 30
	e.move(far, Vector2i(5, 4))
	var entered := far.creature.hp
	assert_true(entered < hp_far, "entering the aura")
	e.end_turn()
	assert_eq(far.creature.hp, entered, "ending the same turn inside: no second save that turn")


func test_spirit_guardians_counts_as_difficult_terrain_for_enemies_only() -> void:
	var e := _setup(["spirit_guardians"])
	var c := _caster(e)
	var foe := TestCombat.punching_bag(e, Vector2i(6, 3))
	var ally := TestCombat.hero(e, "ilse_varga", Vector2i(2, 5))
	TestCombat.start_with(e, c)
	e.spells.cast(c, "spirit_guardians", 3)
	assert_true(e.spells.zones.difficult_cells(foe).has(Vector2i(3, 3)))
	assert_false(e.spells.zones.difficult_cells(ally).has(Vector2i(3, 3)))


func test_cloud_of_daggers_hurts_on_cast_and_can_be_teleported() -> void:
	var e := _setup(["cloud_of_daggers"], 6)
	var c := _caster(e)
	var a := TestCombat.punching_bag(e, Vector2i(5, 3))
	var b := TestCombat.punching_bag(e, Vector2i(8, 3))
	TestCombat.start_with(e, c)
	assert_true(e.spells.cast(c, "cloud_of_daggers", 2, [], Vector2(5.5, 3.5)).ok)
	assert_true(a.creature.hp < a.creature.max_hp(), "daggers on the creature inside")
	e.end_turn()
	while e.current() != c:
		e.end_turn()
	var move := e.spells.sustained_for(c, "cloud_of_daggers")
	assert_false(move.is_empty())
	var r := e.spells.use_sustained(c, str(move["id"]), [], Vector2(8.5, 3.5))
	assert_true(r.ok, r.reason)
	assert_true(b.creature.hp < b.creature.max_hp(), "the Cube moved into its space")


func test_web_restrains_with_an_escape_check_and_slows_movement() -> void:
	var e := _setup(["web"], 2)
	var c := _caster(e)
	var foe := TestCombat.punching_bag(e, Vector2i(6, 3))
	TestCombat.start_with(e, c)
	assert_true(e.spells.cast(c, "web", 2, [], Vector2(6.5, 3.5)).ok)
	assert_true(foe.creature.has_condition(&"restrained"))
	assert_true(e.spells.zones.difficult_cells(foe).has(Vector2i(6, 3)))
	var esc: Effect = null
	for fx: Effect in foe.creature.effects:
		if not fx.escape.is_empty():
			esc = fx
	assert_true(esc != null, "an escape check against the spell DC")
	assert_eq(str(esc.escape["skill"]), "athletics")


func test_grease_knocks_prone_and_prone_outlasts_the_spell() -> void:
	var e := _setup(["grease"], 2)
	var c := _caster(e)
	var foe := TestCombat.punching_bag(e, Vector2i(6, 3))
	TestCombat.start_with(e, c)
	assert_true(e.spells.cast(c, "grease", 1, [], Vector2(6.5, 3.5)).ok)
	assert_true(foe.creature.has_condition(&"prone"), "Prone as a plain condition")
	e.spells.zones.end_spell(c.id, "grease")
	assert_true(foe.creature.has_condition(&"prone"), "until it stands up")


func test_witch_bolt_arcs_again_with_a_bonus_action() -> void:
	var e := _setup(["witch_bolt"], 5)
	var c := _caster(e)
	var foe := TestCombat.punching_bag(e, Vector2i(6, 3))
	TestCombat.start_with(e, c)
	assert_true(e.spells.cast(c, "witch_bolt", 1, [foe]).ok)
	assert_true(c.creature.concentration != null, "Concentration lasts past the first bolt")
	e.end_turn()
	while e.current() != c:
		e.end_turn()
	var hp := foe.creature.hp
	var arc := e.spells.sustained_for(c, "witch_bolt")
	var r := e.spells.use_sustained(c, str(arc["id"]))
	assert_true(r.ok, r.reason)
	assert_true(foe.creature.hp < hp, "1d12 with no roll")
	assert_false(c.bonus_available)


func test_hellish_rebuke_answers_damage() -> void:
	var e := TestCombat.open_field(7)
	var c := TestCombat.caster_with(e, ["hellish_rebuke"], Vector2i(2, 3))
	c.reaction_rules["hellish_rebuke"] = "auto"
	var z := TestCombat.foe(e, "zombie", Vector2i(3, 3))
	z.creature.hp = 100
	TestCombat.start_with(e, z)
	c.creature.hp = c.creature.max_hp()
	for i in 6:
		if e.current() != z:
			e.end_turn()
			continue
		TestCombat.next_d20(e, 19)
		e.monster_attack(z, c, "slam")
		break
	assert_false(c.reaction_available, "the Reaction went on Hellish Rebuke")
	assert_true(z.creature.hp < 100)


func test_color_spray_blinds_until_the_end_of_the_casters_next_turn() -> void:
	var e := _setup(["color_spray"], 2)
	var c := _caster(e)
	var foe := TestCombat.punching_bag(e, Vector2i(4, 3))
	TestCombat.start_with(e, c)
	assert_true(e.spells.cast(c, "color_spray", 1, [], Vector2.INF, Vector2.RIGHT).ok)
	assert_true(foe.creature.has_condition(&"blinded"))
	e.end_turn()
	while e.current() != c:
		e.end_turn()
	assert_true(foe.creature.has_condition(&"blinded"), "still Blinded during the caster's next turn")
	e.end_turn()
	assert_false(foe.creature.has_condition(&"blinded"), "gone after it")


func test_mind_sliver_penalty_is_used_up_by_the_next_save() -> void:
	var e := _setup(["mind_sliver"], 2)
	var c := _caster(e)
	var foe := TestCombat.punching_bag(e, Vector2i(5, 3))
	TestCombat.start_with(e, c)
	assert_true(e.spells.cast(c, "mind_sliver", 0, [foe]).ok)
	assert_eq(foe.creature.modifiers_for(&"penalty_die").size(), 1)
	foe.creature.roll_save(e.dice, &"con", 10)
	assert_eq(foe.creature.modifiers_for(&"penalty_die").size(), 0)


func test_ice_knife_bursts_around_its_target() -> void:
	var e := _setup(["ice_knife"], 4)
	var c := _caster(e)
	var t := TestCombat.punching_bag(e, Vector2i(6, 3))
	var near := TestCombat.punching_bag(e, Vector2i(7, 3))
	TestCombat.start_with(e, c)
	assert_true(e.spells.cast(c, "ice_knife", 1, [t]).ok)
	assert_true(near.creature.hp < near.creature.max_hp(), "the cold burst hits a creature beside the target")


func test_chromatic_orb_uses_the_chosen_damage_type() -> void:
	var e := _setup(["chromatic_orb"], 4)
	var c := _caster(e)
	var t := TestCombat.punching_bag(e, Vector2i(6, 3))
	t.creature.base_immunities.append("acid")
	TestCombat.start_with(e, c)
	assert_true(e.spells.cast(c, "chromatic_orb", 1, [t], Vector2.INF, Vector2.ZERO, {"choice": "fire"}).ok)
	assert_true(t.creature.hp < t.creature.max_hp(), "Fire, not the default Acid")


func test_misty_step_teleports_without_opportunity_attacks() -> void:
	var e := _setup(["misty_step"])
	var c := _caster(e)
	var z := TestCombat.foe(e, "zombie", Vector2i(3, 3))
	TestCombat.start_with(e, c)
	var r := e.spells.cast(c, "misty_step", 2, [], Vector2(7.5, 3.5))
	assert_true(r.ok, r.reason)
	assert_eq(c.cell, Vector2i(7, 3))
	assert_true(z.reaction_available)


func test_haste_gives_an_extra_action_and_lethargy_when_it_ends() -> void:
	var e := _setup(["haste"])
	var c := _caster(e)
	var ally := TestCombat.hero(e, "ilse_varga", Vector2i(3, 3))
	TestCombat.punching_bag(e, Vector2i(9, 3))
	TestCombat.start_with(e, c)
	var walk := ally.speed()
	assert_true(e.spells.cast(c, "haste", 3, [ally]).ok)
	assert_eq(ally.speed(), walk * 2, "Speed doubled")
	while e.current() != ally:
		e.end_turn()
	assert_true(ally.haste_action)
	var r := e.haste_action_use(ally, "dash", null, "")
	assert_true(r.ok, r.reason)
	assert_true(ally.action_available, "the normal action is still there")
	c.creature.concentration.end("test")
	assert_true(ally.creature.has_condition(&"incapacitated"), "lethargy")


func test_slow_limits_reactions_and_attacks() -> void:
	var e := _setup(["slow"], 2)
	var c := _caster(e)
	var z := TestCombat.punching_bag(e, Vector2i(7, 3))
	TestCombat.start_with(e, c)
	assert_true(e.spells.cast(c, "slow", 3, [], Vector2(7.5, 3.5)).ok)
	assert_true(z.creature.has_flag("slowed"))
	assert_false(e.spells.can_react(z))
	assert_eq(e.attacks_per_action(z), 1)


func test_invisibility_ends_when_the_target_attacks() -> void:
	var e := _setup(["invisibility"])
	var c := _caster(e)
	var ally := TestCombat.hero(e, "ilse_varga", Vector2i(3, 3))
	var z := TestCombat.punching_bag(e, Vector2i(4, 3))
	TestCombat.start_with(e, c)
	assert_true(e.spells.cast(c, "invisibility", 2, [ally]).ok)
	assert_true(ally.creature.has_condition(&"invisible"))
	assert_false(e.can_see(z, ally))
	while e.current() != ally:
		e.end_turn()
	e.attack(ally, z, "weapon:greatsword")
	assert_false(ally.creature.has_condition(&"invisible"), "attacking ends it")


func test_fog_cloud_blocks_sight_through_it() -> void:
	var e := _setup(["fog_cloud"])
	var c := _caster(e)
	var z := TestCombat.punching_bag(e, Vector2i(10, 3))
	TestCombat.start_with(e, c)
	assert_true(e.can_see(c, z))
	assert_true(e.spells.cast(c, "fog_cloud", 1, [], Vector2(6.5, 3.5)).ok)
	assert_false(e.can_see(c, z), "Heavily Obscured between them")


func test_darkness_beats_darkvision() -> void:
	var e := _setup(["darkness"])
	var c := _caster(e)
	var z := TestCombat.foe(e, "wolf", Vector2i(6, 3))
	TestCombat.start_with(e, c)
	assert_true(e.spells.cast(c, "darkness", 2, [], Vector2(2.5, 3.5)).ok)
	assert_false(e.can_see(z, c), "the wolf's Darkvision can't see into magical Darkness")


func test_light_lets_a_creature_be_seen_in_the_dark() -> void:
	var e := _setup(["light"])
	e.ambient_light = "dark"
	var c := _caster(e)
	var ally := TestCombat.hero(e, "ilse_varga", Vector2i(3, 3))
	var z := TestCombat.punching_bag(e, Vector2i(8, 3))
	TestCombat.start_with(e, c)
	assert_false(e.can_see(z, ally), "no Darkvision, no light")
	assert_true(e.spells.cast(c, "light", 0, [ally]).ok)
	assert_true(e.can_see(z, ally))


func test_mirror_image_duplicates_soak_hits() -> void:
	var e := _setup(["mirror_image"], 3)
	var c := _caster(e)
	var z := TestCombat.foe(e, "zombie", Vector2i(3, 3))
	TestCombat.start_with(e, c)
	assert_true(e.spells.cast(c, "mirror_image", 2).ok)
	assert_true(c.creature.has_flag("mirror_image"))
	var redirected := 0
	for i in 6:
		if e.mirror_image_takes(c, z, 15):
			redirected += 1
	assert_true(redirected >= 1 and redirected <= 3, "duplicates take hits and run out (%d)" % redirected)


func test_false_life_and_blur_apply_to_the_caster() -> void:
	var e := _setup(["false_life", "blur"])
	var c := _caster(e)
	TestCombat.punching_bag(e, Vector2i(8, 3))
	TestCombat.start_with(e, c)
	assert_true(e.spells.cast(c, "false_life", 1).ok)
	assert_true(c.creature.temp_hp >= 6)
	e.end_turn()
	while e.current() != c:
		e.end_turn()
	assert_true(e.spells.cast(c, "blur", 2).ok)
	assert_eq(c.creature.modifiers_for(&"attacked_with").size(), 1)


func test_melfs_acid_arrow_burns_again_at_the_end_of_the_targets_next_turn() -> void:
	var e := _setup(["melfs_acid_arrow"], 4)
	var c := _caster(e)
	var t := TestCombat.punching_bag(e, Vector2i(6, 3), 200)
	TestCombat.start_with(e, c)
	assert_true(e.spells.cast(c, "melfs_acid_arrow", 2, [t]).ok)
	var hp := t.creature.hp
	assert_true(hp < 200)
	while e.current() != t:
		e.end_turn()
	e.end_turn()
	assert_true(t.creature.hp < hp, "the acid keeps burning")


func test_summon_undead_appears_on_the_party_side_after_its_caster() -> void:
	var e := _setup(["summon_undead"])
	var c := _caster(e)
	TestCombat.punching_bag(e, Vector2i(9, 3))
	TestCombat.start_with(e, c)
	var n := e.combatants.size()
	var r := e.spells.cast(c, "summon_undead", 3, [], Vector2(4.5, 3.5), Vector2.ZERO, {"choice": "skeletal"})
	assert_true(r.ok, r.reason)
	assert_eq(e.combatants.size(), n + 1)
	var spirit := e.combatants[n]
	assert_true(spirit.is_player_controlled())
	assert_eq(e.order[e.order.find(c) + 1], spirit, "acts right after its caster")
	assert_eq(spirit.creature.ac_value(), 14, "AC 11 + level 3")
	c.creature.concentration.end("test")
	assert_true(spirit.creature.dead, "it vanishes with the spell")


func test_tashas_laughter_repeats_the_save_when_damaged() -> void:
	var e := _setup(["tashas_hideous_laughter"], 2)
	var c := _caster(e)
	var t := TestCombat.punching_bag(e, Vector2i(5, 3))
	TestCombat.start_with(e, c)
	assert_true(e.spells.cast(c, "tashas_hideous_laughter", 1, [t]).ok)
	var fx: Effect = null
	for x: Effect in t.creature.effects:
		if x.source_id == "tashas_hideous_laughter":
			fx = x
	assert_true(fx != null, "expected a value")
	assert_true(bool(fx.repeat_save.get("on_damage", false)))


func test_command_approach_walks_the_target_to_the_caster() -> void:
	var e := TestCombat.open_field(2)
	var h := TestCombat.hero(e, "hedda_ironvow", Vector2i(1, 3))
	var t := TestCombat.punching_bag(e, Vector2i(7, 3))
	TestCombat.start_with(e, h)
	TestCombat.next_d20(e, 2)
	assert_true(e.spells.cast(h, "command", 1, [t], Vector2.INF, Vector2.ZERO, {"word": "approach"}).ok)
	assert_true(t.creature.has_flag("command_approach"))
	e.end_turn()
	if e.current() == t:
		e.run_ai_turn()
	assert_true(e.distance(h, t) <= 5, "it came to the caster")


func test_resistance_reduces_the_chosen_damage_type_once_per_turn() -> void:
	var e := TestCombat.open_field(5)
	var h := TestCombat.caster_with(e, ["resistance"], Vector2i(1, 3), 3, "hedda_ironvow")
	var ally := TestCombat.hero(e, "ilse_varga", Vector2i(2, 3))
	TestCombat.punching_bag(e, Vector2i(9, 3))
	TestCombat.start_with(e, h)
	assert_true(e.spells.cast(h, "resistance", 0, [ally], Vector2.INF, Vector2.ZERO, {"choice": "fire"}).ok)
	var hp := ally.creature.hp
	e.deal_damage(null, ally, [{"amount": 10, "type": "fire"}], false, "test")
	assert_true(ally.creature.hp > hp - 10, "1d4 less")
	var hp2 := ally.creature.hp
	e.deal_damage(null, ally, [{"amount": 10, "type": "fire"}], false, "test")
	assert_eq(ally.creature.hp, hp2 - 10, "once per turn")


func test_a_readied_spell_goes_off_when_an_enemy_comes_in_range() -> void:
	var rows: Array[String] = []
	for z in 6:
		rows.append(".".repeat(32))
	var e := TestCombat.encounter(rows, 3)
	var s := TestCombat.hero(e, "silvain_aster", Vector2i(1, 3))
	s.reaction_rules["readied_attack"] = "auto"
	var w := TestCombat.foe(e, "wolf", Vector2i(28, 3))
	w.creature.hp = 100
	TestCombat.start_with(e, s)
	var r := e.ready_spell(s, "fire_bolt", 0)
	assert_true(r.ok, r.reason)
	assert_true(s.creature.concentration != null, "held with Concentration")
	e.end_turn()
	w.movement_left = 60
	e.move(w, Vector2i(20, 3))
	assert_false(s.reaction_available, "released with the Reaction")
	assert_true(s.creature.concentration == null)


func test_a_spell_readied_for_an_attack_waits_for_one() -> void:
	var rows: Array[String] = []
	for z in 6:
		rows.append(".".repeat(32))
	var e := TestCombat.encounter(rows, 3)
	var s := TestCombat.hero(e, "silvain_aster", Vector2i(1, 3))
	s.reaction_rules["readied_attack"] = "auto"
	var ilse := TestCombat.hero(e, "ilse_varga", Vector2i(12, 3))
	(ilse.creature as Character).heroic_inspiration = false
	var w := TestCombat.foe(e, "wolf", Vector2i(28, 3))
	w.creature.hp = 100
	TestCombat.start_with(e, s)
	var r := e.ready_spell(s, "fire_bolt", 0, "attack")
	assert_true(r.ok, r.reason)
	while e.current() != w:
		e.end_turn()
	w.movement_left = 90
	e.move(w, Vector2i(11, 3))
	assert_true(s.reaction_available, "coming within range isn't the trigger")
	e.monster_attack(w, ilse, "bite")
	while e.pending != null:   # a choice of the wolf's target (none expected) is declined
		e.answer_reaction(false)
	assert_false(s.reaction_available, "released at the wolf once its bite was done")
	assert_true(s.creature.concentration == null)
	assert_true(e.log.texts().any(func(t: String) -> bool: return t.contains("releases the readied Fire Bolt at Wolf")))


## Ilse with an attack readied for a spell (her rule for it: `rule`) beside an enemy mage whose turn it is.
func _readied_for_a_spell(rule: String) -> Dictionary:
	var e := TestCombat.open_field(3)
	var ilse := TestCombat.hero(e, "ilse_varga", Vector2i(2, 3))
	ilse.reaction_rules["readied_attack"] = rule
	var mage := TestCombat.caster_with(e, ["mage_armor"], Vector2i(3, 3))
	mage.side = &"enemy"
	mage.controller = &"ai"
	TestCombat.start_with(e, ilse)
	assert_true(e.ready_attack(ilse, str(e.best_melee_option(ilse, null)["id"]), "spell").ok)
	while e.current() != mage:
		e.end_turn()
	return {"e": e, "ilse": ilse, "mage": mage}


func test_an_attack_readied_for_a_spell_goes_off_after_it() -> void:
	var f := _readied_for_a_spell("auto")
	var e := f["e"] as Encounter
	var ilse := f["ilse"] as Combatant
	var mage := f["mage"] as Combatant
	assert_true(e.spells.cast(mage, "mage_armor", 1, [mage]).ok)
	assert_false(ilse.reaction_available, "the readied attack went off")
	assert_true(e.log.texts().any(func(t: String) -> bool: return t.contains("readied attack goes off against")))


func test_a_readied_trigger_can_be_ignored() -> void:
	var f := _readied_for_a_spell("ask")
	var e := f["e"] as Encounter
	var ilse := f["ilse"] as Combatant
	var mage := f["mage"] as Combatant
	var r := e.spells.cast(mage, "mage_armor", 1, [mage])
	assert_true(r.is_paused())
	assert_eq(e.pending.kind, "readied_attack")
	assert_true(e.pending.text.contains("casts a spell"), e.pending.text)
	e.answer_reaction(false)
	assert_true(ilse.reaction_available, "ignored")
	assert_false(ilse.readied.is_empty(), "still readied for the next one")


func test_a_saved_fight_keeps_lingering_spells_and_summons() -> void:
	var e := _setup(["spirit_guardians", "summon_undead"], 4)
	var c := _caster(e)
	TestCombat.punching_bag(e, Vector2i(9, 3))
	TestCombat.start_with(e, c)
	assert_true(e.spells.cast(c, "spirit_guardians", 3).ok)
	var d := EncounterSnapshot.capture(e)
	var json := JSON.stringify(d)
	var back := JSON.parse_string(json) as Dictionary
	var e2 := EncounterSnapshot.restore(back, DiceRoller.new(4))
	assert_eq(e2.spells.zones.live().size(), 1, "Spirit Guardians is still on the field")
	var c2 := e2.get_c(c.id)
	assert_true(c2.creature.concentration != null and c2.creature.concentration.source_id == "spirit_guardians")
