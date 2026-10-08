extends TestCase
## What a hero can do with an Opportunity Attack (owner's playtest, 2026-10-08): War Caster's Reactive Spell, picked from
## the prompt in place of the attack, and Divine Smite asked about once the attack hits.


## A level 4 wizard with War Caster (and Chromatic Orb prepared) beside a zombie whose turn it is.
func _war_caster() -> Dictionary:
	var e := TestCombat.open_field(3)
	var ch := TestChars.custom("wizard", "human", 4, {"ability_score_improvement": ["war_caster"]})
	ch.heroic_inspiration = false
	var prepared := (ch.spellcasting[0] as Dictionary)["prepared"] as Array
	if not "chromatic_orb" in prepared:
		prepared.append("chromatic_orb")
	TestCombat.give_components(ch, ["chromatic_orb"])   # its 50 gp diamond, kept
	var w := e.add(ch, &"party", Vector2i(3, 3))
	var z := TestCombat.foe(e, "zombie", Vector2i(4, 3))
	z.creature.hp = 200
	TestCombat.start_with(e, z)
	return {"e": e, "w": w, "z": z}


func _choices(e: Encounter) -> Array:
	return e.pending.target_choices.map(func(x: Dictionary) -> String: return str(x["id"]))


func test_war_caster_offers_its_spells_in_place_of_the_opportunity_attack() -> void:
	var f := _war_caster()
	var e := f["e"] as Encounter
	var w := f["w"] as Combatant
	var z := f["z"] as Combatant
	assert_true(e.features.has_feat(w, "war_caster"), "built with War Caster")
	z.movement_left = 30
	var r := e.move(z, Vector2i(8, 3))
	assert_true(r.is_paused(), "the zombie leaving reach provokes")
	assert_eq(e.pending.kind, "opportunity_attack")
	var ids := _choices(e)
	assert_true("attack" in ids, "the melee attack is still there")
	assert_true("spell:chromatic_orb" in ids, "a levelled spell aimed at one creature: %s" % str(ids))
	assert_false(ids.any(func(i: String) -> bool: return i == "spell:shield" or i == "spell:burning_hands"), "no Reactions or areas")
	var slots := (w.creature as Character).slots_left(1)
	e.pending.selected_ids.assign(["spell:chromatic_orb"])
	e.answer_reaction(true)
	while e.pending != null:
		e.answer_reaction(false)
	assert_false(w.reaction_available, "the Reaction is spent")
	assert_eq((w.creature as Character).slots_left(1), slots - 1, "Chromatic Orb takes its slot")
	assert_true(e.log.texts().any(func(t: String) -> bool: return t.contains("answers with Chromatic Orb (War Caster")))


func test_no_pick_makes_the_melee_attack() -> void:
	var f := _war_caster()
	var e := f["e"] as Encounter
	var w := f["w"] as Combatant
	var z := f["z"] as Combatant
	z.movement_left = 30
	e.move(z, Vector2i(8, 3))
	assert_eq(e.pending.kind, "opportunity_attack")
	var slots := (w.creature as Character).slots_left(1)
	e.answer_reaction(true)
	while e.pending != null:
		e.answer_reaction(false)
	assert_false(w.reaction_available)
	assert_eq((w.creature as Character).slots_left(1), slots, "no spell")
	assert_true(e.log.texts().any(func(t: String) -> bool: return t.contains("makes an Opportunity Attack")))


func test_a_paladin_is_asked_to_smite_on_an_opportunity_attack_hit() -> void:
	var e := TestCombat.open_field(3)
	var ch := TestChars.custom("paladin", "human", 5)
	ch.heroic_inspiration = false
	var p := e.add(ch, &"party", Vector2i(3, 3))
	var z := TestCombat.foe(e, "zombie", Vector2i(4, 3))
	z.creature.hp = 200
	TestCombat.start_with(e, z)
	z.movement_left = 30
	e.move(z, Vector2i(8, 3))
	assert_eq(e.pending.kind, "opportunity_attack")
	TestCombat.next_d20(e, 19)
	e.answer_reaction(true)
	assert_true(e.pending != null and e.pending.kind == "divine_smite", "asked once the attack hits: %s" % (e.pending.kind if e.pending != null else "nothing"))
	var free := ch.resource_left("spell:divine_smite")
	e.answer_reaction(true)
	while e.pending != null:
		e.answer_reaction(false)
	assert_eq(ch.resource_left("spell:divine_smite"), free - 1, "smitten on the Opportunity Attack")
