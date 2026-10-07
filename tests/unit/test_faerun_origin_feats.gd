extends TestCase
## The Heroes of Faerûn and Arcana Unleashed origin feats with rules of their own (combat/faerun_features.gd and the
## data recipes), each taken through its background with the real data, as a player would.


func _hero(e: Encounter, class_id: String, background: String, cell: Vector2i, level: int = 3, picks: Dictionary = {}) -> Combatant:
	return e.add(TestChars.custom(class_id, "human", level, picks, background), &"party", cell)


func _cast(e: Encounter, c: Combatant, id: String, targets: Array = [], point: Vector2 = Vector2.INF, opts: Dictionary = {}) -> CombatResult:
	var data := Compendium.shared().spell_data(id)
	return e.spells.cast_with_numbers(c, id, int(data["level"]), targets, point,
		{"dc": Breakdown.new("DC").add("test", 40), "attack": Breakdown.new("Attack").add("test", 30), "mod": 5}, opts)


func _find(e: Encounter, c: Combatant, id: String) -> Dictionary:
	return ActionCatalog.new(e).find(c, id)


func _perform(e: Encounter, c: Combatant, id: String, targets: Array = [], point: Vector2 = Vector2.INF) -> CombatResult:
	var a := _find(e, c, id)
	if a.is_empty():
		return CombatResult.fail("no action " + id)
	return ActionCatalog.new(e).perform(c, a, targets, point)


func _inspired(c: Combatant) -> bool:
	return (c.creature as Character).heroic_inspiration


func test_every_origin_feat_and_its_background_is_offered() -> void:
	var comp := Compendium.shared()
	var feats := comp.feats_in("origin").map(func(f: Dictionary) -> String: return str(f["id"]))
	var bgs := comp.all_playable("backgrounds").map(func(b: Dictionary) -> String: return str(b["id"]))
	for pair: Array in [["arcane_artist", "phantasmic_circus_trouper"], ["arcane_overload", "crucible_storm_chaser"],
			["arcane_safeguard", "ward_of_the_sheltering_hands"], ["arcane_undertaker", "covenant_of_the_grave_recruit"],
			["portal_jumper", "horizon_weaver_initiate"], ["cult_of_the_dragon_initiate", "dragon_cultist"],
			["emerald_enclave_fledgling", "emerald_enclave_caretaker"], ["harper_agent", "harper"],
			["lords_alliance_agent", "lords_alliance_vassal"], ["purple_dragon_rook", "purple_dragon_squire"],
			["spellfire_spark", "spellfire_initiate"], ["tyro_of_the_gauntlet", "knight_of_the_gauntlet"],
			["zhentarim_ruffian", "zhentarim_mercenary"]]:
		assert_true(str(pair[0]) in feats, "%s offered as an origin feat" % pair[0])
		assert_true(str(pair[1]) in bgs, "%s offered" % pair[1])
		var ch := TestChars.custom("fighter", "human", 1, {}, str(pair[1]))
		assert_true(ch.feats_taken.any(func(f: Dictionary) -> bool: return str(f["id"]) == str(pair[0])), "%s grants %s" % pair)
		for f in ch.features:
			if str(f.get("source", "")).contains(str(comp.feat_data(str(pair[0]))["name"])):
				assert_ne(str(f.get("implemented", "")), "", "%s: %s labelled" % [pair[0], f["id"]])


func test_arcane_artist_inspires_an_ally_after_an_illusion() -> void:
	var e := TestCombat.open_field(2)
	var c := _hero(e, "wizard", "phantasmic_circus_trouper", Vector2i(2, 3))
	var ally := TestCombat.hero(e, "ilse_varga", Vector2i(4, 3))
	TestCombat.punching_bag(e, Vector2i(10, 3))
	TestCombat.start_with(e, c)
	assert_true(_find(e, c, "feat:fr:arcane_artist").is_empty(), "nothing before an Illusion spell")
	(c.creature as Character).spellcasting[0]["prepared"].append("blur")
	assert_true(e.spells.cast(c, "blur", 2).ok)
	assert_false(_find(e, c, "feat:fr:arcane_artist").is_empty(), "offered after casting Blur")
	(ally.creature as Character).heroic_inspiration = false
	assert_true(_perform(e, c, "feat:fr:arcane_artist", [ally]).ok)
	assert_true(_inspired(ally))
	assert_eq((c.creature as Character).resource_left("arcane_artist"), 0, "once per Long Rest")
	assert_true(_find(e, c, "feat:fr:arcane_artist").is_empty())


func test_arcane_overload_adds_proficiency_to_an_armed_evocation_once() -> void:
	var e := TestCombat.open_field(2)
	var c := _hero(e, "wizard", "crucible_storm_chaser", Vector2i(2, 3))
	var t := TestCombat.punching_bag(e, Vector2i(5, 3), 500)
	TestCombat.start_with(e, c)
	var ch := c.creature as Character
	assert_true(_perform(e, c, "feat:fr:arcane_overload").ok)
	e.drain_events()
	TestCombat.next_d20(e, 18)
	assert_true(e.spells.cast(c, "fire_bolt", 0, [t]).ok)
	assert_true(t.creature.hp < 500, "Fire Bolt hit")
	assert_true(str(e.log.entries).contains("Arcane Overload"), "the damage names Arcane Overload")
	assert_eq(ch.resource_left("arcane_overload"), 0, "spent on the Evocation spell")
	assert_true(_find(e, c, "feat:fr:arcane_overload").is_empty(), "gone until a Long Rest")


func test_quick_ward_and_spellfire_flame_cast_cantrips_as_a_bonus_action() -> void:
	for pair: Array in [["ward_of_the_sheltering_hands", "resistance", "arcane_safeguard_quick_ward"],
			["spellfire_initiate", "sacred_flame", "spellfire_flame_bonus"]]:
		var e := TestCombat.open_field(2)
		var c := _hero(e, "fighter", str(pair[0]), Vector2i(2, 3))
		var t := TestCombat.punching_bag(e, Vector2i(4, 3), 500)
		TestCombat.start_with(e, c)
		var ch := c.creature as Character
		var uses := ch.resource_left(str(pair[2]))
		assert_eq(uses, ch.proficiency_bonus(), "%s: Proficiency Bonus uses" % pair[2])
		var a := _find(e, c, "spell:%s:%s" % [pair[1], pair[2]])
		assert_false(a.is_empty(), "%s on the hotbar" % pair[2])
		assert_eq(str(a.get("cost", "")), "bonus")
		var target: Array = [c] if str(pair[1]) == "resistance" else [t]
		var r := ActionCatalog.new(e).perform(c, a, target)
		assert_true(r.ok, "%s: %s" % [pair[2], r.reason])
		assert_false(c.bonus_available, "a Bonus Action")
		assert_true(c.action_available, "the action is left")
		assert_eq(ch.resource_left(str(pair[2])), uses - 1, "a use spent")


func test_magic_absorption_takes_a_d4_off_one_spell_a_turn() -> void:
	var e := TestCombat.open_field(2)
	var c := _hero(e, "fighter", "spellfire_initiate", Vector2i(2, 3))
	var foe := TestCombat.foe(e, "zombie", Vector2i(6, 3))
	TestCombat.start_with(e, c)
	var hp := c.creature.hp
	var ctx := {"c": foe, "nums": {"class_id": ""}, "s": {}}
	var dr := e.spells.deal_spell_damage(ctx, c, [{"amount": 10, "type": "fire"}], false, "Spell")
	assert_true(dr.final < 10 and dr.final >= 6, "1d4 less: %d" % dr.final)
	var dr2 := e.spells.deal_spell_damage(ctx, c, [{"amount": 10, "type": "fire"}], false, "Spell")
	assert_eq(dr2.final, 10, "once per turn")
	assert_eq(c.creature.hp, hp - dr.final - 10)
	e.end_turn()
	var dr3 := e.deal_damage(foe, c, [{"amount": 6, "type": "slashing"}], false, "Claw")
	assert_eq(dr3.final, 6, "not against plain weapon damage")


func test_understanding_of_death_inspires_after_help_stabilizes() -> void:
	var e := TestCombat.open_field(2)
	var c := _hero(e, "cleric", "covenant_of_the_grave_recruit", Vector2i(2, 3))
	var ally := TestCombat.hero(e, "ilse_varga", Vector2i(3, 3))
	TestCombat.punching_bag(e, Vector2i(10, 3))
	TestCombat.start_with(e, c)
	(c.creature as Character).heroic_inspiration = false
	ally.creature.hp = 0
	ally.creature.add_condition(&"unconscious", "0 Hit Points")
	TestCombat.next_d20(e, 19)
	assert_true(e.stabilize(c, ally, false).ok)
	assert_true(ally.creature.stable)
	assert_true(_inspired(c), "Heroic Inspiration")
	assert_eq((c.creature as Character).resource_left("understanding_of_death"), 0)


func test_portal_step_costs_fifteen_feet_once_a_turn() -> void:
	var e := TestCombat.open_field(2)
	var c := _hero(e, "fighter", "horizon_weaver_initiate", Vector2i(2, 3))
	TestCombat.punching_bag(e, Vector2i(10, 3))
	TestCombat.start_with(e, c)
	var ch := c.creature as Character
	var move := c.movement_left
	assert_false(_perform(e, c, "feat:fr:portal_step", [], Vector2(7.5, 3.5)).ok, "more than 15 ft")
	assert_true(_perform(e, c, "feat:fr:portal_step", [], Vector2(5.5, 3.5)).ok)
	assert_eq(c.cell, Vector2i(5, 3))
	assert_eq(c.movement_left, move - 15)
	assert_eq(ch.resource_left("portal_step"), ch.proficiency_bonus() - 1)
	assert_false(_perform(e, c, "feat:fr:portal_step", [], Vector2(6.5, 3.5)).ok, "once per turn")


func test_cult_initiate_speaks_draconic_frightens_and_takes_heart() -> void:
	var ch := TestChars.custom("fighter", "human", 3, {}, "dragon_cultist")
	assert_true(ch.has_proficiency("languages", "draconic"), "Draconic by default")
	var e := TestCombat.open_field(2)
	var c := e.add(ch, &"party", Vector2i(2, 3))
	var t := TestCombat.punching_bag(e, Vector2i(5, 3), 500)
	TestCombat.start_with(e, c)
	ch.heroic_inspiration = false
	TestCombat.next_d20(e, 2)
	assert_true(_perform(e, c, "feat:fr:dragons_terror", [t]).ok)
	assert_true(t.creature.has_condition(&"frightened"), "a failed Wisdom save")
	assert_eq(e.fear_sources(t), [c] as Array[Combatant], "Frightened of the initiate")
	assert_true(ch.heroic_inspiration, "Inspired by Fear")
	assert_eq(ch.resource_left("inspired_by_fear"), 0, "once per rest")
	e.end_turn()
	e.end_turn()
	e.end_turn()
	assert_false(t.creature.has_condition(&"frightened"), "until the end of the initiate's next turn")
	assert_true(c.id in (t.get_meta("dragons_terror_immune", []) as Array), "then immune")
	assert_false(_perform(e, c, "feat:fr:dragons_terror", [t]).ok)


func test_enclave_ritual_lasts_eight_hours_and_tag_team_swaps_after_help() -> void:
	var st := StoryState.new()
	var ch := TestChars.custom("druid", "human", 3, {}, "emerald_enclave_caretaker")
	st.party.assign([ch])
	var before := st.total_minutes()
	assert_true(bool(FieldCasting.cast_utility(st, ch, "speak_with_animals", true)["ok"]))
	assert_true(int((st.active_spells["speak_with_animals"] as Dictionary)["until"]) >= before + 480, "8 hours as a Ritual")
	var e := TestCombat.open_field(2)
	var c := e.add(TestChars.custom("fighter", "human", 3, {}, "emerald_enclave_caretaker"), &"party", Vector2i(2, 3))
	var ally := TestCombat.hero(e, "ilse_varga", Vector2i(2, 4))
	var foe := TestCombat.punching_bag(e, Vector2i(3, 3))
	TestCombat.start_with(e, c)
	assert_true(_find(e, c, "feat:fr:tag_team").is_empty(), "only as part of Help")
	assert_true(e.help_attack(c, foe).ok)
	assert_true(_perform(e, c, "feat:fr:tag_team", [ally]).ok)
	assert_eq(c.cell, Vector2i(2, 4))
	assert_eq(ally.cell, Vector2i(2, 3))


func test_distracting_melody_helps_from_thirty_feet() -> void:
	var e := TestCombat.open_field(2)
	var c := _hero(e, "bard", "harper", Vector2i(1, 3))
	var plain := TestCombat.hero(e, "ilse_varga", Vector2i(1, 5))
	var foe := TestCombat.punching_bag(e, Vector2i(6, 3))
	TestCombat.start_with(e, c)
	assert_true(e.help_attack(c, foe).ok, "25 ft away")
	assert_true(e.has_mark("advantage_against", foe.id))
	plain.action_available = true
	e.turn_index = e.order.find(plain)
	assert_false(e.help_attack(plain, foe).ok, "an ordinary Help reaches 5 ft")


func test_lords_alliance_agent_inspires_on_a_critical_and_answers_for_an_ally() -> void:
	var e := TestCombat.open_field(2)
	var c := _hero(e, "fighter", "lords_alliance_vassal", Vector2i(2, 3))
	var ally := TestCombat.hero(e, "ilse_varga", Vector2i(2, 4))
	var foe := TestCombat.foe(e, "zombie", Vector2i(3, 3))
	TestCombat.start_with(e, c)
	(ally.creature as Character).heroic_inspiration = false
	TestCombat.next_d20(e, 20)
	var opt := str(e.attack_options(c)[0]["id"])
	var r := e.attack(c, foe, opt)
	assert_true(r.ok and r.critical, "a Critical Hit")
	assert_true(_inspired(ally), "Inspiring Strike")
	e.deal_damage(foe, ally, [{"amount": 3, "type": "slashing"}], false, "Slam")
	assert_true(e.marks.any(func(m: Dictionary) -> bool: return str(m["kind"]) == "advantage_against" and str(m.get("attacker", "")) == c.id \
		and str(m["target"]) == foe.id), "Reassert Honor: Advantage on the next attack against it")


func test_rallying_cry_inspires_allies_when_initiative_is_rolled() -> void:
	var e := TestCombat.open_field(2)
	var c := _hero(e, "fighter", "purple_dragon_squire", Vector2i(2, 3))
	var a := TestCombat.hero(e, "ilse_varga", Vector2i(3, 3))
	var b := TestCombat.hero(e, "silvain_aster", Vector2i(4, 4))
	TestCombat.punching_bag(e, Vector2i(10, 3))
	for x: Combatant in [a, b]:
		(x.creature as Character).heroic_inspiration = false
	e.start()
	assert_true(_inspired(a) and _inspired(b), "two allies (Proficiency Bonus 2)")
	assert_eq((c.creature as Character).resource_left("rook_rallying_cry"), 0)
	var policies := _find(e, c, "feat:reaction_policy:rook_rallying_cry:never")
	assert_false(policies.is_empty(), "the class tab can turn it Off")


func test_stand_as_one_stops_a_shove_and_vigilance_follows_ready() -> void:
	var e := TestCombat.open_field(2)
	var c := _hero(e, "fighter", "knight_of_the_gauntlet", Vector2i(2, 3))
	var ally := TestCombat.hero(e, "ilse_varga", Vector2i(3, 3))
	TestCombat.punching_bag(e, Vector2i(10, 3))
	TestCombat.start_with(e, c)
	assert_eq(e.forced_move(ally, Vector2(1.5, 3.5), 10), 0, "Stand as One")
	assert_eq(ally.cell, Vector2i(3, 3))
	assert_false(c.reaction_available, "it costs the Reaction")
	assert_true(e.forced_move(ally, Vector2(1.5, 3.5), 10) > 0, "only while the Reaction lasts")
	var opt := str(e.attack_options(c)[0]["id"])
	assert_true(e.ready_attack(c, opt).ok)
	assert_true(c.creature.modifiers_for(&"attacked_with").any(func(m: Modifier) -> bool: return m.source_name == "Gauntlet Vigilant"),
		"Disadvantage on the next attack against you")


func test_zhentarim_family_first_and_exploit_opening() -> void:
	var e := TestCombat.open_field(2)
	var c := _hero(e, "fighter", "zhentarim_mercenary", Vector2i(2, 3))
	var ally := TestCombat.hero(e, "ilse_varga", Vector2i(3, 4))
	var foe := TestCombat.foe(e, "zombie", Vector2i(3, 3))
	(c.creature as Character).heroic_inspiration = true
	e.start()
	assert_false(_inspired(c), "Heroic Inspiration spent")
	for x: Combatant in [c, ally]:
		assert_true(x.initiative_test.describe().contains("Family First"), "%s rolled with Advantage" % x.name())
	assert_false(foe.initiative_test.describe().contains("Family First"), "not the enemy")
	TestCombat.start_with(e, foe)
	c.reaction_rules["opportunity_attack"] = "auto"
	e.move(foe, Vector2i(6, 3))
	assert_true(e.log.texts().any(func(x: String) -> bool: return x.contains("Opportunity Attack")), "an Opportunity Attack")
	assert_true(e.dice.log.any(func(x: Dictionary) -> bool: return str(x.get("reason", "")).contains("Exploit Opening")), "its damage dice rolled twice")
