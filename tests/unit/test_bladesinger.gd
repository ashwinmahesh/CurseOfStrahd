extends TestCase

var _books: BookContentFixture

func before_each() -> void:
	_books = BookContentFixture.new()

func after_each() -> void:
	_books.restore()

func setup(level: int = 10) -> Dictionary:
	var e := TestCombat.open_field()
	e.default_player_reaction = "never"
	var ch := TestChars.custom("wizard", "human", level, {"wizard_subclass": ["bladesinger"]})
	var c := e.add(ch, &"party", Vector2i(2, 3))
	var enemy := TestChars.custom("fighter", "human", 5, {"fighter_subclass": ["champion"]})
	enemy.inventory.append({"id": "greatsword", "qty": 1, "slot": ""})
	enemy.equip("greatsword", "main_hand")
	var foe := e.add(enemy, &"enemy", Vector2i(3, 3))
	TestCombat.start_with(e, c)
	assert_true(e.feature_recipes.perform(c, "bladesong", []).ok)
	return {"e": e, "c": c, "ch": ch, "foe": foe}

func test_song_of_defense_prompts_for_exact_slot_before_damage() -> void:
	var s := setup()
	var e := s.e as Encounter
	var c := s.c as Combatant
	var ch := s.ch as Character
	var foe := s.foe as Combatant
	c.reaction_rules["song_of_defense"] = "ask"
	e.end_turn()
	var hp := ch.hp
	var first := ch.slots_left(1)
	var third := ch.slots_left(3)
	TestCombat.next_d20(e, 20)
	var r := e.attack(foe, c, "weapon:greatsword")
	assert_true(r.ok)
	assert_true(e.pending != null)
	if e.pending == null:return
	assert_eq(e.pending.kind, "song_of_defense")
	assert_eq(ch.hp, hp, "damage waits for the player's choice")
	assert_true(c.reaction_available)
	assert_eq(ch.slots_left(3), third)
	assert_true(e.pending.target_choices.any(func(x: Dictionary) -> bool: return str(x.id) == "3"))
	e.pending.selected_ids.assign(["3"])
	assert_true(e.answer_reaction(true).ok)
	assert_eq(ch.slots_left(1), first)
	assert_eq(ch.slots_left(3), third - 1)
	assert_false(c.reaction_available)
	assert_false(c.cast_slot_spell_this_turn, "spending a slot on a feature is not casting a spell")

func test_decline_or_invalid_slot_never_spends_or_retries_automatically() -> void:
	var s := setup()
	var e := s.e as Encounter
	var c := s.c as Combatant
	var ch := s.ch as Character
	c.reaction_rules["song_of_defense"] = "ask"
	e.end_turn()
	var slots := ch.slots_left(1)
	TestCombat.next_d20(e, 20)
	e.attack(s.foe as Combatant, c, "weapon:greatsword")
	assert_true(e.pending != null)
	if e.pending == null:return
	e.pending.selected_ids.assign(["9"])
	assert_false(e.answer_reaction(true).ok)
	assert_true(e.pending != null, "a rejected choice leaves the attack pending")
	assert_eq(ch.slots_left(1), slots)
	assert_true(c.reaction_available)
	assert_true(e.answer_reaction(false).ok)
	assert_eq(ch.slots_left(1), slots)
	assert_true(c.reaction_available)

func test_automatic_policy_reduces_mixed_damage_before_resistance_and_temp_hp() -> void:
	var s := setup()
	var e := s.e as Encounter
	var c := s.c as Combatant
	var ch := s.ch as Character
	assert_true(e.damage_responses.set_policy(c, "song_of_defense", "2").ok)
	ch.add_effect(Effect.new("Fire ward").with_modifier("resistance", {"value": "fire"}))
	ch.add_temp_hp(10)
	var hp := ch.hp
	var slots := ch.slots_left(2)
	var parts: Array = [{"amount": 8, "type": "slashing"}, {"amount": 12, "type": "fire"}]
	var r := e.deal_damage(null, c, parts, false, "Hazard")
	assert_eq(r.final, 5, "one 10-point reduction, then Fire Resistance")
	assert_eq(ch.temp_hp, 5)
	assert_eq(ch.hp, hp)
	assert_eq(ch.slots_left(2), slots - 1)
	assert_false(c.reaction_available)
	assert_eq(int(parts[0].amount), 8, "caller-owned damage is not mutated")
	assert_eq(int(parts[1].amount), 12)
	assert_eq(e.deal_damage(null, c, [{"amount": 8, "type": "force"}], false, "Second hazard").final, 8, "one Reaction only")

func test_sync_damage_requires_explicit_automatic_policy_and_exact_available_level() -> void:
	var s := setup()
	var e := s.e as Encounter
	var c := s.c as Combatant
	var ch := s.ch as Character
	var slots := ch.slots_left(1)
	assert_eq(e.deal_damage(null, c, [{"amount": 4, "type": "force"}], false, "Hazard").final, 4)
	assert_eq(ch.slots_left(1), slots)
	assert_true(c.reaction_available)
	assert_true(e.damage_responses.set_policy(c, "song_of_defense", "2").ok)
	while ch.slots_left(2) > 0:
		ch.expend_slot(2)
	assert_eq(e.deal_damage(null, c, [{"amount": 4, "type": "force"}], false, "Hazard").final, 4)
	assert_eq(ch.slots_left(1), slots, "no fallback to another level")
	assert_true(c.reaction_available)
	assert_true(e.damage_responses.set_policy(c, "song_of_defense", "never").ok)

func test_spell_damage_and_concentration_see_the_reduced_amount() -> void:
	var s := setup()
	var e := s.e as Encounter
	var c := s.c as Combatant
	var ch := s.ch as Character
	e.damage_responses.set_policy(c, "song_of_defense", "4")
	ch.begin_concentration("detect_magic", "Detect Magic")
	var foe := s.foe as Combatant
	var ctx := {"c": foe, "nums": {"class_id": "wizard"}}
	var r := e.spells.deal_spell_damage(ctx, c, [{"amount": 40, "type": "force"}], false, "Spell")
	assert_eq(r.final, 20)
	assert_eq(r.concentration_dc, 10)
	assert_false(c.reaction_available)

func test_full_prevention_preserves_concentration_and_prevents_lethal_damage() -> void:
	var s := setup()
	var e := s.e as Encounter
	var c := s.c as Combatant
	var ch := s.ch as Character
	e.damage_responses.set_policy(c, "song_of_defense", "3")
	ch.hp = 1
	ch.begin_concentration("detect_magic", "Detect Magic")
	var r := e.deal_damage(null, c, [{"amount": 15, "type": "force"}], true, "Hazard")
	assert_eq(r.final, 0)
	assert_eq(ch.hp, 1)
	assert_false(ch.dead)
	assert_true(ch.concentration != null)
	assert_eq(r.concentration_dc, 0)

func test_defense_requires_active_song_and_available_reaction() -> void:
	for block: String in ["dismiss", "spent", "no_reactions", "stunned", "zero"]:
		var s := setup()
		var e := s.e as Encounter
		var c := s.c as Combatant
		var ch := s.ch as Character
		e.damage_responses.set_policy(c, "song_of_defense", "1")
		if block == "dismiss":e.feature_recipes.perform(c, "bladesong:dismiss", [])
		elif block == "spent":c.reaction_available = false
		elif block == "no_reactions":ch.add_effect(Effect.new("No reactions").with_modifier("flag", {"value": "no_reactions"}))
		elif block == "stunned":ch.add_condition(&"stunned", "test")
		var before := ch.slots_left(1)
		var amount := 0 if block == "zero" else 3
		assert_eq(e.deal_damage(null, c, [{"amount": amount, "type": "force"}], false, "Hazard").final, amount, block)
		assert_eq(ch.slots_left(1), before, block)

func test_damage_response_is_data_driven_and_accepts_pact_magic_slots() -> void:
	var s := setup()
	var e := s.e as Encounter
	var c := s.c as Combatant
	var ch := s.ch as Character
	for f in ch.features:
		if str(f.id) == "song_of_defense":
			f.id = "test_slot_ward"
			f.name = "Slot Ward"
			f.damage_response = {"reduction_per_slot": 3}
	ch.spellcasting.append({"class_id": "warlock", "progression": "pact", "pact_slots": 1, "pact_level": 2})
	var used := ch.pact_slots_used
	assert_true(e.damage_responses.set_policy(c, "test_slot_ward", "2").ok)
	assert_eq(e.deal_damage(null, c, [{"amount": 10, "type": "force"}], false, "Hazard").final, 4)
	assert_eq(ch.pact_slots_used, used + 1)

func armed(ch: Character) -> void:
	for item: String in ["rapier", "shortsword"]:
		ch.inventory.append({"id": item, "qty": 1, "slot": ""})
	assert_true(ch.equip("rapier", "main_hand"))
	assert_true(ch.equip("shortsword", "off_hand"))

func test_weapon_focus_is_wizard_only_proficient_and_melee() -> void:
	var s := setup(3)
	var ch := s.ch as Character
	assert_true(SpellComponents.focus_source(ch, ch.compendium.item_data("rapier"), "wizard") != "")
	assert_eq(SpellComponents.focus_source(ch, ch.compendium.item_data("rapier"), "cleric"), "")
	assert_eq(SpellComponents.focus_source(ch, ch.compendium.item_data("greatsword"), "wizard"), "")
	assert_eq(SpellComponents.focus_source(ch, ch.compendium.item_data("shortbow"), "wizard"), "")
	assert_eq(SpellComponents.focus_source(ch, {"id": "unarmed_strike"}, "wizard"), "")
	assert_true(SpellComponents.focus_source(ch, ch.compendium.item_data("arcane_focus_staff"), "wizard") != "")
	assert_true(SpellComponents.focus_source(ch, ch.compendium.item_data("spellbook"), "wizard") != "")

func test_focus_supplies_material_and_somatic_together_but_not_somatic_only() -> void:
	var s := setup(3)
	var ch := s.ch as Character
	armed(ch)
	var sm := {"s": true, "m": "a pinch of sand"}
	assert_eq(SpellComponents.hand_reason(ch, sm, "wizard"), "")
	assert_true(SpellComponents.hand_reason(ch, {"s": true}, "wizard") != "")
	assert_true(SpellComponents.hand_reason(ch, {"s": true, "m": "a pearl", "m_cost_gp": 100}, "wizard") != "")
	assert_false(SpellComponents.can_replace_material({"m": "copper pieces", "m_cost_gp": 0.02}), "fractional gold prices are still priced components")
	assert_true(SpellComponents.hand_reason(ch, {"m": "copper pieces", "m_cost_gp": 0.02}, "wizard") != "")
	var priced := {"components": {"s": true, "m": "a weapon", "m_cost_gp": 0.01}}
	assert_eq(float(SpellComponents.effective(priced, ["subtle"]).get("m_cost_gp", 0.0)), 0.01, "Subtle Spell retains even a one-copper Material requirement")
	assert_true(SpellComponents.hand_reason(ch, {"m": "incense", "m_consumed": true}, "wizard") != "")
	ch.add_effect(Effect.new("War Caster").with_modifier("flag", {"value": "war_caster_somatic_components"}))
	assert_eq(SpellComponents.hand_reason(ch, {"s": true}, "wizard"), "")
	assert_true(SpellComponents.hand_reason(ch, {"m": "incense", "m_consumed": true}, "wizard") != "", "War Caster doesn't remove Material components")

func test_casting_obeys_focus_and_rejects_before_spending_action_or_slot() -> void:
	var s := setup(3)
	var e := s.e as Encounter
	var c := s.c as Combatant
	var ch := s.ch as Character
	armed(ch)
	(ch.spellcasting[0].prepared as Array).append("magic_missile")
	(ch.spellcasting[0].prepared as Array).append("sleep")
	c.free_interaction_available = false
	var before := ch.slots_left(1)
	assert_false(e.spells.cast(c, "magic_missile", 1, [s.foe]).ok, "VS spell needs a free hand, even with a weapon focus")
	assert_true(c.action_available)
	assert_eq(ch.slots_left(1), before)
	var r := e.spells.cast(c, "sleep", 1, [], Vector2(3, 3))
	assert_true(r.ok, r.reason)
	assert_eq(ch.slots_left(1), before - 1)

func test_subtle_and_material_omission_keep_costly_or_consumed_requirements() -> void:
	var spell := {"school": "illusion", "components": {"v": true, "s": true, "m": "sand"}}
	assert_true(SpellComponents.effective(spell, ["subtle"]).is_empty())
	spell.components.m_cost_gp = 100
	assert_eq(str(SpellComponents.effective(spell, ["subtle"]).get("m", "")), "sand")
	assert_false(SpellComponents.effective(spell, ["psychic_spells"]).has("s"))
	assert_true(SpellComponents.effective(spell, ["psychic_spells"]).has("m"))
	assert_false(SpellComponents.effective(spell, [], true).has("m"))


func test_casting_can_stow_one_item_and_focus_avoids_that_interaction() -> void:
	var s := setup(3)
	var e := s.e as Encounter
	var c := s.c as Combatant
	var ch := s.ch as Character
	armed(ch)
	(ch.spellcasting[0].prepared as Array).append("magic_missile")
	var before := ch.slots_left(1)
	assert_false(e.spells.cast(c, "magic_missile", 1, []).ok)
	assert_true(c.free_interaction_available, "invalid target doesn't stow equipment")
	assert_eq(str(ch.equipped("off_hand").id), "shortsword")
	assert_eq(ch.slots_left(1), before)
	assert_true(e.spells.cast(c, "magic_missile", 1, [s.foe]).ok)
	assert_false(c.free_interaction_available)
	assert_true(ch.equipped("off_hand").is_empty())
	assert_eq(str(ch.equipped("main_hand").id), "rapier")

func test_immune_or_rounded_to_zero_damage_never_spends_a_slot() -> void:
	var s := setup()
	var e := s.e as Encounter
	var c := s.c as Combatant
	var ch := s.ch as Character
	e.damage_responses.set_policy(c, "song_of_defense", "2")
	ch.add_effect(Effect.new("Immune").with_modifier("immunity", {"value": "fire"}))
	var before := ch.slots_left(2)
	assert_eq(e.deal_damage(null, c, [{"amount": 100, "type": "fire"}], false, "Fire").final, 0)
	assert_eq(ch.slots_left(2), before)
	assert_true(c.reaction_available)
