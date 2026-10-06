extends TestCase
## The Phase 4 classes' features in a fight (combat/class_features.gd): Rage and Reckless Attack, the Monk's Focus
## actions and Stunning Strike, Lay On Hands and the Aura of Protection, Bardic Inspiration, Wild Shape, Innate
## Sorcery and Font of Magic, Hunter's Prey, and the warlock's invocations.


func _add(e: Encounter, ch: Character, cell: Vector2i) -> Combatant:
	return e.add(ch, &"party", cell)


func _act(e: Encounter, c: Combatant, id: String, t: Combatant = null, point: Vector2 = Vector2.INF) -> CombatResult:
	return e.feature_actions.perform(c, "cf:" + id, t, point)


func _listed(e: Encounter, c: Combatant, id: String) -> Dictionary:
	for a in e.feature_actions.list(c):
		if str(a["id"]) == "feat:cf:" + id:
			return a
	return {}


func _melee(e: Encounter, c: Combatant) -> String:
	for o in e.attack_options(c):
		if bool(o["melee"]) and str(o["kind"]) == "weapon":
			return str(o["id"])
	return "weapon:unarmed_strike"


# --- Barbarian --------------------------------------------------------------------------------------------

func test_rage_resists_weapons_adds_damage_and_ends_without_attacking() -> void:
	var e := TestCombat.open_field(3)
	var b := _add(e, TestChars.custom("barbarian", "human", 3, {"barbarian_subclass": ["path_of_the_berserker"]}), Vector2i(2, 3))
	var z := TestCombat.punching_bag(e, Vector2i(3, 3), 300)
	TestCombat.start_with(e, b)
	var rages := (b.creature as Character).resource_left("rage")
	assert_true(_act(e, b, "rage").ok)
	assert_eq((b.creature as Character).resource_left("rage"), rages - 1)
	assert_true(ClassFeatures.raging(b))
	assert_true(b.creature.resistance_source(&"slashing") != "", "Resistance to Slashing")
	TestCombat.next_d20(e, 19)
	assert_true(e.attack(b, z, _melee(e, b)).hit)
	assert_true(e.log.entries.any(func(x: Dictionary) -> bool:
		return (x.get("details", []) as Array).any(func(d: Variant) -> bool: return str(d).contains("Rage +"))), "Rage Damage on the hit")
	e.end_turn()
	while e.current() != b:
		e.end_turn()
	e.end_turn()
	assert_false(ClassFeatures.raging(b), "a turn without attacking ends the Rage")


func test_reckless_attack_gives_advantage_both_ways() -> void:
	var e := TestCombat.open_field(3)
	var b := _add(e, TestChars.custom("barbarian", "human", 2), Vector2i(2, 3))
	var z := TestCombat.foe(e, "zombie", Vector2i(3, 3))
	TestCombat.start_with(e, b)
	assert_true(_act(e, b, "reckless_attack").ok)
	var opt := e.option_by_id(b, _melee(e, b))
	assert_true("Reckless Attack" in (e.attack_situation(b, z, opt)["advantage"] as Array))
	var zopt := e.attack_options(z)[0]
	assert_true((e.attack_situation(z, b, zopt)["advantage"] as Array).size() > 0, "attacks against the barbarian have Advantage")


# --- Monk ------------------------------------------------------------------------------------------------

func test_flurry_of_blows_spends_focus_for_two_strikes() -> void:
	var e := TestCombat.open_field(3)
	var m := _add(e, TestChars.custom("monk", "human", 5), Vector2i(2, 3))
	var t := TestCombat.punching_bag(e, Vector2i(3, 3), 300)
	TestCombat.start_with(e, m)
	var focus := (m.creature as Character).resource_left("focus_points")
	assert_true(_act(e, m, "flurry_of_blows", t).ok)
	assert_eq((m.creature as Character).resource_left("focus_points"), focus - 1)
	var strikes := e.drain_events().filter(func(x: Dictionary) -> bool: return str(x["type"]) == "attack" and str(x["attacker"]) == m.id)
	assert_eq(strikes.size(), 2)
	assert_false(m.bonus_available)


func test_stunning_strike_stuns_on_a_failed_save() -> void:
	var e := TestCombat.open_field(3)
	var m := _add(e, TestChars.custom("monk", "human", 5), Vector2i(2, 3))
	var t := TestCombat.punching_bag(e, Vector2i(3, 3), 300)
	TestCombat.start_with(e, m)
	assert_true(e.features.toggle_rider(m, "stunning_strike").ok)
	TestCombat.next_d20(e, 19)
	assert_true(e.attack(m, t, "weapon:unarmed_strike").hit)
	assert_true(t.creature.has_condition(&"stunned"))


func test_patient_defense_and_step_of_the_wind() -> void:
	var e := TestCombat.open_field(3)
	var m := _add(e, TestChars.custom("monk", "human", 2), Vector2i(2, 3))
	TestCombat.punching_bag(e, Vector2i(9, 3), 300)
	TestCombat.start_with(e, m)
	var before := m.movement_left
	assert_true(_act(e, m, "step_of_the_wind").ok)
	assert_eq(m.movement_left, before + m.speed())
	m.bonus_available = true
	assert_true(_act(e, m, "patient_defense_focus").ok)
	assert_true(m.disengaged)
	assert_true(m.creature.effects.any(func(fx: Effect) -> bool: return fx.name == "Dodging"))


func test_deflect_attacks_is_offered_against_a_weapon_hit() -> void:
	var e := TestCombat.open_field(3)
	var m := _add(e, TestChars.custom("monk", "human", 3), Vector2i(2, 3))
	var z := TestCombat.foe(e, "zombie", Vector2i(3, 3))
	m.reaction_rules["deflect_attacks"] = "auto"
	TestCombat.start_with(e, z)
	TestCombat.next_d20(e, 19)
	e.attack(z, m, e.attack_options(z)[0]["id"])
	assert_false(m.reaction_available, "Deflect Attacks used")
	assert_true(e.log.entries.any(func(x: Dictionary) -> bool:
		return (x.get("details", []) as Array).any(func(d: Variant) -> bool: return str(d).contains("Deflect Attacks"))))


# --- Paladin ----------------------------------------------------------------------------------------------

func test_lay_on_hands_heals_from_the_pool() -> void:
	var e := TestCombat.open_field(3)
	var p := _add(e, TestChars.custom("paladin", "human", 3), Vector2i(2, 3))
	var a := TestCombat.hero(e, "ilse_varga", Vector2i(3, 3))
	TestCombat.start_with(e, p)
	a.creature.hp = a.creature.max_hp() - 6
	assert_true(_act(e, p, "lay_on_hands", a).ok)
	assert_eq(a.creature.hp, a.creature.max_hp())
	assert_eq((p.creature as Character).resource_left("lay_on_hands"), 15 - 6)


func test_aura_of_protection_adds_charisma_to_nearby_allies_saves() -> void:
	var e := TestCombat.open_field(3)
	var p := _add(e, TestChars.custom("paladin", "human", 6), Vector2i(2, 3))
	var a := TestCombat.hero(e, "ilse_varga", Vector2i(3, 3))
	var far := TestCombat.hero(e, "silvain_aster", Vector2i(10, 7))
	TestCombat.start_with(e, p)
	e.spells.zones.refresh_auras()
	var bonus := maxi(1, p.creature.ability_mod(&"cha"))
	assert_true(a.creature.effects.any(func(fx: Effect) -> bool: return fx.stack_key == "aura:%s" % p.id))
	assert_false(far.creature.effects.any(func(fx: Effect) -> bool: return fx.stack_key.begins_with("aura:")))
	assert_true(a.creature.save_bonus(&"wis").describe().contains("Aura of Protection"), "+%d to saves" % bonus)


# --- Bard -----------------------------------------------------------------------------------------------

func test_bardic_inspiration_gives_an_ally_a_die() -> void:
	var e := TestCombat.open_field(3)
	var b := _add(e, TestChars.custom("bard", "human", 1), Vector2i(2, 3))
	var a := TestCombat.hero(e, "ilse_varga", Vector2i(3, 3))
	TestCombat.start_with(e, b)
	assert_true(_act(e, b, "bardic_inspiration", a).ok)
	assert_eq(a.creature.modifiers_for(&"inspiration_die").size(), 1)
	assert_false(_act(e, b, "bardic_inspiration", b).ok, "not yourself")


# --- Druid ------------------------------------------------------------------------------------------------

func test_wild_shape_turns_the_druid_into_a_beast_and_back() -> void:
	var e := TestCombat.open_field(3)
	var d := _add(e, TestChars.custom("druid", "human", 2), Vector2i(2, 3))
	TestCombat.punching_bag(e, Vector2i(9, 3), 300)
	TestCombat.start_with(e, d)
	var forms := e.class_features.wild_forms(d)
	assert_false(forms.is_empty(), "the druid knows Beast forms")
	var form := str(forms[0]["id"])
	assert_true(_act(e, d, "wild_shape:" + form).ok)
	assert_true(e.shapes.is_shaped(d))
	assert_eq(d.creature.temp_hp, 2, "Temporary Hit Points equal to the Druid level")
	assert_eq(d.creature.ability_score(&"wis"), e.shapes.original(d).ability_score(&"wis"), "keeps its Wisdom")
	d.bonus_available = true
	assert_true(_act(e, d, "revert_shape").ok)
	assert_true(d.creature is Character)


# --- Sorcerer ----------------------------------------------------------------------------------------------

func test_innate_sorcery_raises_the_save_dc_and_font_of_magic_makes_slots() -> void:
	var e := TestCombat.open_field(3)
	var s := _add(e, TestChars.custom("sorcerer", "human", 3), Vector2i(2, 3))
	TestCombat.punching_bag(e, Vector2i(9, 3), 300)
	TestCombat.start_with(e, s)
	var ch := s.creature as Character
	var dc := ch.spell_save_dc("sorcerer").total()
	assert_true(_act(e, s, "innate_sorcery").ok)
	assert_eq(ch.spell_save_dc("sorcerer").total(), dc + 1)
	ch.expend_slot(1)
	var left := ch.slots_left(1)
	s.bonus_available = true
	var made := _act(e, s, "create_slot:1")
	assert_true(made.ok, made.reason)
	assert_eq(ch.slots_left(1), left + 1)


# --- Ranger -----------------------------------------------------------------------------------------------

func test_colossus_slayer_adds_a_d8_to_a_wounded_target() -> void:
	var e := TestCombat.open_field(3)
	var r := _add(e, TestChars.custom("ranger", "human", 3, {"ranger_subclass": ["hunter"], "hunters_prey": ["colossus_slayer"]}), Vector2i(2, 3))
	var t := TestCombat.punching_bag(e, Vector2i(3, 3), 300)
	t.creature.hp = 250
	TestCombat.start_with(e, r)
	TestCombat.next_d20(e, 19)
	assert_true(e.attack(r, t, _melee(e, r)).hit)
	assert_true(e.log.entries.any(func(x: Dictionary) -> bool:
		return (x.get("details", []) as Array).any(func(d: Variant) -> bool: return str(d).contains("Colossus Slayer"))))


# --- Warlock ----------------------------------------------------------------------------------------------

func _warlock(e: Encounter, invs: Array) -> Combatant:
	var ch := TestChars.custom("warlock", "human", 1, {"eldritch_invocations": [invs[0]]})
	# Later invocations (level 2+) added straight to the choice, as levelling up would.
	for cd in ch.choice_defs:
		if cd.kind == "invocation":
			for i in range(1, invs.size()):
				cd.picks.append(str(invs[i]))
			break
	var entry := ch.spellcasting[0] as Dictionary
	if not "eldritch_blast" in (entry["cantrips"] as Array):
		(entry["cantrips"] as Array).append("eldritch_blast")
	return _add(e, ch, Vector2i(2, 3))


func test_invocations_cast_at_will_push_with_eldritch_blast_and_see_in_darkness() -> void:
	var e := TestCombat.open_field(3)
	var w := _warlock(e, ["armor_of_shadows", "repelling_blast", "devils_sight"])
	var t := TestCombat.punching_bag(e, Vector2i(5, 3), 300)
	TestCombat.start_with(e, w)
	assert_true(w.creature.has_flag("devils_sight"))
	var picked := ClassFeatures.picks_of_kind(w, "invocation")
	assert_true("armor_of_shadows" in picked, str(picked))
	var ma := {}
	for sp in e.spells.castable(w):
		if str(sp["id"]) == "mage_armor":
			ma = sp
	assert_true(bool(ma.get("free", false)), "Mage Armor at will")
	TestCombat.next_d20(e, 19)
	assert_true(e.spells.cast(w, "eldritch_blast", 0, [t]).ok)
	assert_true(t.cell.x > 5, "Repelling Blast pushed it: %s" % t.cell)


# --- Archfey and Lore ---------------------------------------------------------------------------------------

func test_cutting_words_can_turn_a_hit_into_a_miss() -> void:
	var e := TestCombat.open_field(3)
	var b := _add(e, TestChars.custom("bard", "human", 3, {"bard_subclass": ["college_of_lore"]}), Vector2i(2, 3))
	var a := TestCombat.hero(e, "ilse_varga", Vector2i(3, 4))
	var z := TestCombat.foe(e, "zombie", Vector2i(4, 4))
	b.reaction_rules["cutting_words"] = "auto"
	TestCombat.start_with(e, z)
	var ac := a.creature.ac_value()
	# A roll that only just hits: the zombie's +3 with a d20 that lands exactly on the AC.
	TestCombat.next_d20(e, clampi(ac - 3, 2, 19))
	e.attack(z, a, e.attack_options(z)[0]["id"])
	assert_false(b.reaction_available, "Cutting Words spent")


# --- The last gaps -------------------------------------------------------------------------------------

func test_psionic_sorcery_casts_with_sorcery_points_instead_of_a_slot() -> void:
	var e := TestCombat.open_field(3)
	var s := _add(e, TestChars.custom("sorcerer", "human", 6, {"sorcerer_subclass": ["aberrant_sorcery"]}), Vector2i(2, 3))
	var t := TestCombat.punching_bag(e, Vector2i(4, 3), 300)
	TestCombat.start_with(e, s)
	var ch := s.creature as Character
	for l in range(1, 4):
		while ch.slots_left(l) > 0:
			ch.expend_slot(l)
	var pts := ch.resource_left("sorcery_points")
	var r := e.spells.cast(s, "dissonant_whispers", 1, [t], Vector2.INF, Vector2.ZERO, {"metamagic": ["psionic_sorcery"]})
	assert_true(r.ok, r.reason)
	assert_eq(ch.resource_left("sorcery_points"), pts - 1)


func test_psychic_spells_turn_eldritch_blast_psychic() -> void:
	var e := TestCombat.open_field(3)
	var ch := TestChars.custom("warlock", "human", 3, {"warlock_subclass": ["great_old_one_patron"]})
	var entry := ch.spellcasting[0] as Dictionary
	if not "eldritch_blast" in (entry["cantrips"] as Array):
		(entry["cantrips"] as Array).append("eldritch_blast")
	var w := _add(e, ch, Vector2i(2, 3))
	var t := TestCombat.punching_bag(e, Vector2i(5, 3), 300)
	TestCombat.start_with(e, w)
	TestCombat.next_d20(e, 19)
	assert_true(e.spells.cast(w, "eldritch_blast", 0, [t], Vector2.INF, Vector2.ZERO, {"metamagic": ["psychic_spells"]}).ok)
	assert_true(e.log.entries.any(func(x: Dictionary) -> bool: return str(x["text"]).contains("Psychic")))


func test_pact_of_the_chain_familiar_attacks_in_place_of_an_attack() -> void:
	var e := TestCombat.open_field(3)
	var w := _warlock(e, ["pact_of_the_chain"])
	var t := TestCombat.punching_bag(e, Vector2i(4, 3), 300)
	TestCombat.start_with(e, w)
	var cast := e.spells.cast(w, "find_familiar", 1, [], Vector2(3.5, 2.5), Vector2.ZERO, {"choice": "imp"})
	assert_true(cast.ok, cast.reason)
	var fam := e.class_features._familiar(w)
	assert_true(fam != null and fam.name().contains("Imp"))
	assert_false(e.attack(fam, t, "monster:sting").ok, "a familiar doesn't attack on its own")
	w.action_available = true
	w.magic_action_used = false
	TestCombat.next_d20(e, 19)
	var r := _act(e, w, "familiar_strike", t)
	assert_true(r.ok, r.reason)
	assert_true(t.creature.hp < 300)


# --- Levels 8 to 11 -------------------------------------------------------------------------------------

func test_brutal_strike_trades_advantage_for_a_blow() -> void:
	var e := TestCombat.open_field(3)
	var b := _add(e, TestChars.custom("barbarian", "human", 9), Vector2i(2, 3))
	var t := TestCombat.punching_bag(e, Vector2i(3, 3), 300)
	TestCombat.start_with(e, b)
	assert_true(_act(e, b, "reckless_attack").ok)
	assert_true(e.features.toggle_rider(b, "brutal:forceful").ok)
	var opt := e.option_by_id(b, _melee(e, b))
	assert_false("Reckless Attack" in (e.attack_situation(b, t, opt)["advantage"] as Array), "Advantage given up")
	TestCombat.next_d20(e, 19)
	assert_true(e.attack(b, t, _melee(e, b)).hit)
	assert_true(t.cell.x >= 5, "Forceful Blow pushed it 15 ft: %s" % t.cell)


func test_relentless_rage_keeps_a_barbarian_up() -> void:
	var e := TestCombat.open_field(3)
	var b := _add(e, TestChars.custom("barbarian", "human", 11), Vector2i(2, 3))
	TestCombat.punching_bag(e, Vector2i(9, 3), 300)
	TestCombat.start_with(e, b)
	assert_true(_act(e, b, "rage").ok)
	b.creature.add_effect(Effect.new("Sure", &"effect", "t").with_modifier("save", {"ability": "con", "value": 30}))
	e.deal_damage(null, b, [{"amount": b.creature.hp + b.creature.temp_hp + 3, "type": "force"}], false, "test")
	assert_eq(b.creature.hp, 22, "twice the Barbarian level")


func test_abjure_foes_frightens() -> void:
	var e := TestCombat.open_field(3)
	var p := _add(e, TestChars.custom("paladin", "human", 9), Vector2i(2, 3))
	var t := TestCombat.punching_bag(e, Vector2i(6, 3), 300)
	TestCombat.start_with(e, p)
	assert_true(_act(e, p, "abjure_foes").ok)
	assert_true(t.creature.has_condition(&"frightened"))


func test_zealous_presence_rouses_allies() -> void:
	var e := TestCombat.open_field(3)
	var b := _add(e, TestChars.custom("barbarian", "human", 10, {"barbarian_subclass": ["path_of_the_zealot"]}), Vector2i(2, 3))
	var a := TestCombat.hero(e, "ilse_varga", Vector2i(3, 3))
	TestCombat.punching_bag(e, Vector2i(9, 3), 300)
	TestCombat.start_with(e, b)
	assert_true(_act(e, b, "zealous_presence").ok)
	assert_true(a.creature.modifiers_for(&"advantage").any(func(m: Modifier) -> bool: return m.source_name == "Zealous Presence"))


func test_thought_shield_reflects_psychic_damage() -> void:
	var e := TestCombat.open_field(3)
	var w := _add(e, TestChars.custom("warlock", "human", 10, {"warlock_subclass": ["great_old_one_patron"]}), Vector2i(2, 3))
	var foe := TestCombat.punching_bag(e, Vector2i(3, 3), 300)
	TestCombat.start_with(e, w)
	e.deal_damage(foe, w, [{"amount": 10, "type": "psychic"}], false, "test")
	assert_true(foe.creature.hp < 300)


func test_spell_breaker_casts_dispel_magic_as_a_bonus_action() -> void:
	var e := TestCombat.open_field(3)
	var w := _add(e, TestChars.custom("wizard", "human", 10, {"wizard_subclass": ["abjurer"]}), Vector2i(2, 3))
	TestCombat.punching_bag(e, Vector2i(9, 3), 300)
	TestCombat.start_with(e, w)
	var dm := {}
	for sp in e.spells.castable(w):
		if str(sp["id"]) == "dispel_magic":
			dm = sp
	assert_eq(str(dm.get("casting", "")), "bonus_action")


func test_moonlight_step_teleports_with_advantage() -> void:
	var e := TestCombat.open_field(3)
	var d := _add(e, TestChars.custom("druid", "human", 10, {"druid_subclass": ["circle_of_the_moon"]}), Vector2i(2, 3))
	TestCombat.punching_bag(e, Vector2i(9, 3), 300)
	TestCombat.start_with(e, d)
	var r := _act(e, d, "moonlight_step", null, Vector2(6.5, 3.5))
	assert_true(r.ok, r.reason)
	assert_eq(d.cell, Vector2i(6, 3))


func test_a_spell_both_prepared_and_granted_keeps_its_free_casting() -> void:
	var e := TestCombat.open_field(3)
	var c := TestCombat.caster_with(e, ["misty_step"], Vector2i(2, 3))
	TestCombat.punching_bag(e, Vector2i(9, 3), 300)
	var ch := c.creature as Character
	ch.granted_spells.append({"id": "misty_step", "at_level": 1, "ability": "int", "source": "test", "uses": 1, "recharge": "long", "class_id": ""})
	ch.set_resource("spell:misty_step", "Misty Step", 1, "long", "test")
	TestCombat.start_with(e, c)
	var ms := {}
	for sp in e.spells.castable(c):
		if str(sp["id"]) == "misty_step":
			ms = sp
	assert_true(bool(ms.get("free", false)), "the free casting survives")
