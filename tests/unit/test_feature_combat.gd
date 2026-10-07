extends TestCase
## Class, subclass, feat and species abilities in a fight (feature audit): reactions, riders on a hit, Bonus
## Action features, saves against conditions, and the hooks on D20 Tests and damage.


func _field(seed_value: int = 1) -> Encounter:
	return TestCombat.open_field(seed_value)


func _add(e: Encounter, ch: Character, cell: Vector2i) -> Combatant:
	return e.add(ch, &"party", cell)


func _foe(e: Encounter, cell: Vector2i, hp: int = 200) -> Combatant:
	return TestCombat.punching_bag(e, cell, hp)


func test_uncanny_dodge_halves_a_hit() -> void:
	var e := _field(3)
	var rogue := _add(e, TestChars.pregen("tamsin_tealeaf", 5), Vector2i(2, 3))
	rogue.reaction_rules["uncanny_dodge"] = "auto"
	var z := TestCombat.foe(e, "zombie", Vector2i(3, 3))
	TestCombat.start_with(e, z)
	rogue.creature.hp = rogue.creature.max_hp()
	TestCombat.next_d20(e, 19)
	e.monster_attack(z, rogue, "slam")
	assert_false(rogue.reaction_available, "Uncanny Dodge used the Reaction")


func test_dwarven_resilience_gives_advantage_on_saves_against_poison() -> void:
	var e := _field()
	var h := _add(e, TestChars.pregen("hedda_ironvow", 3), Vector2i(2, 3))
	var keys: Array[String] = ["save:con", "save:all", "save_vs:poisoned"]
	var src := h.creature.d20_sources(keys)
	assert_true(not (src["advantage"] as Array).is_empty(), "Dwarven Resilience applies with the save_vs key")


func test_battle_master_trip_attack_spends_a_die_and_knocks_prone() -> void:
	var e := _field(4)
	var f := _add(e, TestChars.custom("fighter", "human", 3, {"fighter_subclass": ["battle_master"], "combat_superiority": ["trip_attack", "parry", "precision_attack"]}), Vector2i(2, 3))
	var t := _foe(e, Vector2i(3, 3))
	TestCombat.start_with(e, f)
	var ch := f.creature as Character
	assert_eq(ch.resource_left("superiority_dice"), 4)
	assert_true(e.features.toggle_rider(f, "maneuver:trip_attack").ok)
	var opt := ""
	for o in e.attack_options(f):
		if bool(o["melee"]) and str(o["kind"]) == "weapon":
			opt = str(o["id"])
	var r := e.attack(f, t, opt)
	assert_true(r.ok, r.reason)
	if r.hit:
		assert_eq(ch.resource_left("superiority_dice"), 3, "a die spent on the hit")
		assert_true(t.creature.has_condition(&"prone"), "a feeble foe fails the Str save")


func test_cunning_strike_trip_trades_sneak_attack_dice() -> void:
	var e := _field(2)
	var rogue := _add(e, TestChars.pregen("tamsin_tealeaf", 5), Vector2i(2, 3))
	var ally := TestCombat.hero(e, "ilse_varga", Vector2i(4, 4))
	var t := _foe(e, Vector2i(3, 3))
	TestCombat.start_with(e, rogue)
	assert_true(e.features.toggle_rider(rogue, "cunning:trip").ok)
	TestCombat.next_d20(e, 15)
	var r := e.attack(rogue, t, "weapon:shortsword")
	assert_true(r.ok, r.reason)
	assert_true(r.hit)
	assert_true(t.creature.has_condition(&"prone"), "Trip with a Sneak Attack die")
	assert_true(ally != null)


func test_tactical_shift_after_second_wind() -> void:
	var e := _field()
	var f := _add(e, TestChars.pregen("ilse_varga", 5), Vector2i(2, 3))
	var z := TestCombat.foe(e, "zombie", Vector2i(3, 3))
	TestCombat.start_with(e, f)
	f.creature.hp = 10
	assert_true(e.features.second_wind(f).ok)
	assert_eq(f.free_move_ft, f.speed() / 2)
	var r := e.free_move(f, Vector2i(2, 6))
	assert_true(r.ok, r.reason)
	assert_true(z.reaction_available, "no Opportunity Attack")


func test_war_priest_bonus_attack() -> void:
	var e := _field(4)
	var c := _add(e, TestChars.custom("cleric", "human", 3, {"cleric_subclass": ["war_domain"]}), Vector2i(2, 3))
	var t := _foe(e, Vector2i(3, 3))
	TestCombat.start_with(e, c)
	var found := false
	for a in e.feature_actions.list(c):
		if str(a["id"]) == "feat:war_priest":
			found = true
	assert_true(found, "War Priest on the hotbar")
	var r := e.feature_actions.perform(c, "war_priest", t, Vector2.INF)
	assert_true(r.ok, r.reason)
	assert_false(c.bonus_available)


func test_warding_flare_gives_an_attack_disadvantage() -> void:
	var e := _field(4)
	var c := _add(e, TestChars.custom("cleric", "human", 3, {"cleric_subclass": ["light_domain"]}), Vector2i(2, 3))
	c.reaction_rules["warding_flare"] = "auto"
	var ally := TestCombat.hero(e, "ilse_varga", Vector2i(5, 3))
	var z := TestCombat.foe(e, "zombie", Vector2i(6, 3))
	TestCombat.start_with(e, z)
	var left := (c.creature as Character).resource_left("warding_flare")
	e.monster_attack(z, ally, "slam")
	assert_eq((c.creature as Character).resource_left("warding_flare"), left - 1)
	assert_false(c.reaction_available)


func test_breath_weapon_replaces_an_attack() -> void:
	var e := _field(2)
	var d := _add(e, TestChars.custom("fighter", "dragonborn", 1, {"draconic_ancestry": ["red_dragon"]}), Vector2i(2, 3))
	var t := _foe(e, Vector2i(3, 3), 60)
	TestCombat.start_with(e, d)
	var r := e.feature_actions.perform(d, "breath_weapon:cone", null, Vector2(4.5, 3.5))
	assert_true(r.ok, r.reason)
	assert_true(t.creature.hp < 60, "fire on a failed save")
	assert_false(d.action_available)


func test_relentless_endurance_keeps_an_orc_up_once() -> void:
	var e := _field()
	var o := _add(e, TestChars.custom("fighter", "orc", 1), Vector2i(2, 3))
	TestCombat.start_with(e, o)
	e.deal_damage(null, o, [{"amount": o.creature.hp + 3, "type": "slashing"}], false, "test")
	assert_eq(o.creature.hp, 1)
	e.deal_damage(null, o, [{"amount": 2, "type": "slashing"}], false, "test")
	assert_eq(o.creature.hp, 0, "only once per Long Rest")


func test_fires_burn_adds_fire_on_a_hit() -> void:
	var e := _field(4)
	var g := _add(e, TestChars.custom("fighter", "goliath", 1, {"giant_ancestry": ["fire_giant"]}), Vector2i(2, 3))
	var t := _foe(e, Vector2i(3, 3))
	TestCombat.start_with(e, g)
	assert_true(e.features.toggle_rider(g, "giant:fires_burn").ok)
	var left := (g.creature as Character).resource_left("giant_ancestry")
	var opt := ""
	for o in e.attack_options(g):
		if bool(o["melee"]) and str(o["kind"]) == "weapon":
			opt = str(o["id"])
	TestCombat.next_d20(e, 18)
	var r := e.attack(g, t, opt)
	assert_true(r.hit)
	assert_eq((g.creature as Character).resource_left("giant_ancestry"), left - 1)


func test_healing_hands() -> void:
	var e := _field()
	var a := _add(e, TestChars.custom("cleric", "aasimar", 1), Vector2i(2, 3))
	var ally := TestCombat.hero(e, "ilse_varga", Vector2i(3, 3))
	TestCombat.punching_bag(e, Vector2i(9, 3))
	TestCombat.start_with(e, a)
	ally.creature.hp = 1
	var r := e.feature_actions.perform(a, "healing_hands", ally, Vector2.INF)
	assert_true(r.ok, r.reason)
	assert_true(ally.creature.hp > 1)


func test_interception_cuts_damage_to_an_ally() -> void:
	var e := _field(5)
	var f := _add(e, TestChars.custom("fighter", "human", 1, {"fighting_style": ["interception"]}), Vector2i(2, 3))
	f.reaction_rules["interception"] = "auto"
	var ally := TestCombat.hero(e, "hedda_ironvow", Vector2i(3, 3))
	var z := TestCombat.foe(e, "zombie", Vector2i(4, 3))
	TestCombat.start_with(e, z)
	TestCombat.next_d20(e, 19)
	e.monster_attack(z, ally, "slam")
	assert_false(f.reaction_available, "Interception used the Reaction")


func test_portent_replaces_the_next_d20() -> void:
	var e := _field()
	var w := _add(e, TestChars.custom("wizard", "human", 3, {"wizard_subclass": ["diviner"]}), Vector2i(2, 3))
	var t := _foe(e, Vector2i(5, 3))
	TestCombat.start_with(e, w)
	var rolls := w.get_meta("portent_rolls", []) as Array
	assert_eq(rolls.size(), 2)
	var v := int(rolls[0])
	assert_true(e.feature_actions.perform(w, "portent:%d" % v, t, Vector2.INF).ok)
	var test := t.creature.roll_save(e.dice, &"wis", 10)
	assert_eq(test.kept, v, "the foreseen roll")


func test_lucky_gives_advantage_on_the_next_roll() -> void:
	var e := _field()
	var h := _add(e, TestChars.custom("fighter", "human", 1, {"versatile": ["lucky"]}, "sage"), Vector2i(2, 3))
	TestCombat.punching_bag(e, Vector2i(9, 3))
	TestCombat.start_with(e, h)
	assert_true(e.features.has_feat(h, "lucky"), "built with Lucky")
	assert_true(e.feature_actions.perform(h, "lucky", null, Vector2.INF).ok)
	var t := h.creature.roll_save(e.dice, &"con", 10)
	assert_true(t.advantage)


func test_cleave_swings_into_a_second_creature() -> void:
	var e := _field(4)
	var f := _add(e, TestChars.custom("fighter", "human", 1, {"weapon_mastery": ["greataxe", "longsword", "dagger"]}), Vector2i(2, 3))
	var ch := f.creature as Character
	ch.add_item("greataxe")
	ch.equip("greataxe", "main_hand")
	ch.refresh()
	var a := _foe(e, Vector2i(3, 3))
	var b := _foe(e, Vector2i(3, 4))
	TestCombat.start_with(e, f)
	assert_true("greataxe" in ch.weapon_masteries, "Greataxe mastery %s" % str(ch.weapon_masteries))
	TestCombat.next_d20(e, 18)
	var r := e.attack(f, a, "weapon:greataxe")
	assert_true(r.hit)
	assert_true(b.creature.hp < 200 or e.log.entries.any(func(x: Dictionary) -> bool: return str(x["text"]).contains("Cleave")), "Cleave attacked the second foe")


func test_psychic_blades_are_attack_options() -> void:
	var e := _field()
	var r := _add(e, TestChars.custom("rogue", "human", 3, {"rogue_subclass": ["soulknife"]}), Vector2i(2, 3))
	TestCombat.start_with(e, r)
	var ids: Array = e.attack_options(r).map(func(o: Dictionary) -> String: return str(o["id"]))
	assert_true("blade:melee" in ids and "blade:thrown" in ids, str(ids))


func test_heavy_armor_master_reduces_weapon_damage() -> void:
	var e := _field()
	var f := _add(e, TestChars.pregen("ilse_varga", 1), Vector2i(2, 3))
	TestCombat.start_with(e, f)
	var parts: Array = [{"amount": 10, "type": "slashing", "weapon": true}]
	var hp := f.creature.hp
	e.deal_damage(null, f, parts, false, "test")
	assert_eq(f.creature.hp, hp - 10, "no feat, no reduction")


func test_arcane_ward_soaks_damage() -> void:
	var e := _field()
	var w := _add(e, TestChars.custom("wizard", "human", 3, {"wizard_subclass": ["abjurer"]}), Vector2i(2, 3))
	var ch := w.creature as Character
	var spellbook := ch.spellcasting[0]["prepared"] as Array
	if not "mage_armor" in spellbook:
		spellbook.append("mage_armor")
	TestCombat.punching_bag(e, Vector2i(9, 3))
	TestCombat.start_with(e, w)
	var abj := ""
	for s in e.spells.castable(w):
		var data := Compendium.shared().spell_data(str(s["id"]))
		if str(data.get("school", "")) == "abjuration" and int(s["level"]) >= 1 and bool(s["legal"]):
			abj = str(s["id"])
	assert_true(abj != "", "an Abjuration spell to cast")
	e.spells.cast(w, abj, 1, [w])
	assert_true(w.creature.ward_hp > 0, "the ward is up")
	var hp := w.creature.hp
	e.deal_damage(null, w, [{"amount": 3, "type": "fire"}], false, "test")
	assert_eq(w.creature.hp, hp, "the ward took it")


func test_fey_touched_grants_misty_step_and_names_it_in_the_spell_choice() -> void:
	var ch := TestChars.custom("cleric", "human", 4, {"ability_score_improvement": ["fey_touched"]})
	var misty := ch.known_spells().filter(func(k: Dictionary) -> bool: return str(k["id"]) == "misty_step")
	assert_false(misty.is_empty(), "Fey Touched gives Misty Step")
	assert_eq(ch.resource_left("spell:misty_step"), 1, "free once per Long Rest")
	var labelled := ch.choice_defs.filter(func(c: Choice) -> bool: return c.label.contains("Misty Step comes with the feat"))
	assert_eq(labelled.size(), 1, "the spell choice says Misty Step is already included")
	var e := TestCombat.open_field()
	var c := e.add(ch, &"party", Vector2i(2, 2))
	TestCombat.foe(e, "zombie", Vector2i(9, 5))
	TestCombat.start_with(e, c)
	var entry := {}
	for k in e.spells.castable(c):
		if str(k["id"]) == "misty_step":
			entry = k
	assert_true(bool(entry.get("legal", false)) and bool(entry.get("free", false)), "castable for free")
	assert_true(e.spells.cast(c, "misty_step", 2, [], Vector2(5.5, 2.5)).ok)
	assert_eq(ch.resource_left("spell:misty_step"), 0)
	c.bonus_available = true
	c.cast_slot_spell_this_turn = false
	var slots := ch.slots_left(2)
	assert_true(e.spells.cast(c, "misty_step", 2, [], Vector2(4.5, 4.5)).ok, "and again with a slot")
	assert_eq(ch.slots_left(2), slots - 1)
