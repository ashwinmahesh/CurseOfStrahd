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
