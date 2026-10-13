extends TestCase
## Polymorph on foes (2024 rules, owner 2026-10-13: "cast Polymorph on enemies, not only on allies"): it targets friend
## or foe; a foe makes a Wisdom save and, failing, becomes the Beast its caster picks from those its Challenge Rating
## allows, weakest first (SpellSpecials.POLYMORPH_FORM); a shapechanger is no longer immune; and a foe with Polymorph
## (Strahd, Baba Lysaga) casts it on a hero when it's worth more than its other choices (AiSpells).


func _field() -> Encounter:
	return TestCombat.open_field(3)


## The hotbar's Polymorph for `c`.
func _polymorph_action(e: Encounter, c: Combatant) -> Dictionary:
	return ActionCatalog.new(e).find(c, "spell:polymorph")


func _forms_ids(forms: Array[Dictionary]) -> Array[String]:
	var out: Array[String] = []
	for f in forms:
		out.append(str(f["id"]))
	return out


func test_polymorph_and_resilient_sphere_go_on_friend_or_foe() -> void:
	var comp := Compendium.shared()
	assert_eq(ActionCatalog.spell_targeting(comp.spell_data("polymorph")), "creature")
	assert_eq(ActionCatalog.spell_targeting(comp.spell_data("otilukes_resilient_sphere")), "creature")
	assert_eq(ActionCatalog.spell_targeting(comp.spell_data("bless")), "multi", "a plain buff is unchanged")
	assert_eq(ActionCatalog.spell_targeting(comp.spell_data("aid")), "multi")
	var e := _field()
	var c := TestCombat.high_caster(e, ["polymorph"], Vector2i(2, 3))
	var ally := TestCombat.hero(e, "ilse_varga", Vector2i(3, 3))
	var foe := TestCombat.foe(e, "scout", Vector2i(6, 3))
	TestCombat.start_with(e, c)
	var a := _polymorph_action(e, c)
	assert_false(a.is_empty(), "Polymorph on the hotbar")
	var catalog := ActionCatalog.new(e)
	assert_eq(catalog.target_why(c, a, foe), "", "a foe can be chosen")
	assert_eq(catalog.target_why(c, a, ally), "", "and an ally still can")


func test_the_forms_a_target_allows_come_weakest_first_and_in_the_same_order() -> void:
	var forms := ShapeChange.beast_forms(1.0)
	assert_true(forms.size() > 5)
	for i in range(1, forms.size()):
		var a := forms[i - 1]
		var b := forms[i]
		assert_true(float(a["cr"]) <= float(b["cr"]), "%s before %s" % [a["id"], b["id"]])
		if is_equal_approx(float(a["cr"]), float(b["cr"])):
			assert_true(int((a["hp"] as Dictionary)["average"]) <= int((b["hp"] as Dictionary)["average"]), "%s before %s" % [a["id"], b["id"]])
	assert_eq(_forms_ids(ShapeChange.beast_forms(1.0)), _forms_ids(forms), "the same list each time")
	for f in forms:
		assert_true(float(f["cr"]) <= 1.0 and str(f["type"]) == "beast")


func test_a_foe_that_fails_its_save_becomes_the_beast_the_player_picks() -> void:
	var e := _field()
	var c := TestCombat.high_caster(e, ["polymorph"], Vector2i(2, 3))
	var t := TestCombat.foe(e, "scout", Vector2i(5, 3))
	var real := t.creature
	var hp := real.hp
	TestCombat.start_with(e, c)
	TestCombat.next_d20(e, 1)
	var r := e.spells.cast(c, "polymorph", 4, [t])
	assert_true(r.is_paused(), "the form is asked once the save fails (%s)" % r.reason)
	var req := e.pending
	assert_eq(req.kind, SpellSpecials.POLYMORPH_FORM)
	assert_false(req.spends_reaction)
	var allowed := e.spells.specials.polymorph_forms(t)
	assert_eq(req.target_choices.map(func(ch: Dictionary) -> String: return str(ch["id"])), _forms_ids(allowed),
		"every Beast up to the scout's Challenge Rating, weakest first")
	for f in allowed:
		assert_true(float(f["cr"]) <= (real as Monster).cr + 0.001)
	assert_eq(req.selected_ids, [str(allowed[0]["id"])] as Array[String], "the weakest picked to start with")
	assert_true(str(req.target_choices[0]["label"]).contains("CR 0"), str(req.target_choices[0]["label"]))
	var pick := allowed[allowed.size() - 1]
	req.selected_ids.assign([str(pick["id"])])
	e.answer_reaction(true)
	assert_eq(e.pending, null)
	assert_true(e.shapes.is_shaped(t))
	assert_eq(t.creature.name, "%s (%s)" % [real.name, pick["name"]])
	assert_eq(t.creature.hp, hp, "keeps its own Hit Points")
	assert_eq(t.creature.temp_hp, int((pick["hp"] as Dictionary)["average"]), "the Beast's Hit Points as Temporary Hit Points")
	assert_true(c.creature.concentration != null and not c.creature.concentration.ended, "held by the caster's Concentration")
	assert_true(t.creature.has_flag("polymorphed"))


func test_skipping_the_pick_or_a_rule_to_stop_asking_takes_the_weakest_form() -> void:
	var e := _field()
	var c := TestCombat.high_caster(e, ["polymorph"], Vector2i(2, 3))
	var t := TestCombat.foe(e, "scout", Vector2i(5, 3))
	TestCombat.start_with(e, c)
	TestCombat.next_d20(e, 1)
	assert_true(e.spells.cast(c, "polymorph", 4, [t]).is_paused())
	e.answer_reaction(false)
	var weakest := e.spells.specials.polymorph_forms(t)[0]
	assert_true(t.creature.name.ends_with("(%s)" % weakest["name"]), t.creature.name)
	var e2 := _field()
	var c2 := TestCombat.high_caster(e2, ["polymorph"], Vector2i(2, 3))
	var t2 := TestCombat.foe(e2, "scout", Vector2i(5, 3))
	TestCombat.start_with(e2, c2)
	c2.reaction_rules[SpellSpecials.POLYMORPH_FORM] = "auto"
	TestCombat.next_d20(e2, 1)
	var r := e2.spells.cast(c2, "polymorph", 4, [t2])
	assert_true(r.ok and not r.is_paused(), "Always use it: no prompt")
	assert_true(t2.creature.name.ends_with("(%s)" % weakest["name"]), t2.creature.name)


func test_a_form_named_on_the_hotbar_needs_no_prompt_and_an_ally_gets_the_strongest() -> void:
	var e := _field()
	var c := TestCombat.high_caster(e, ["polymorph"], Vector2i(2, 3))
	var t := TestCombat.foe(e, "scout", Vector2i(5, 3))
	TestCombat.start_with(e, c)
	TestCombat.next_d20(e, 1)
	var r := e.spells.cast(c, "polymorph", 4, [t], Vector2.INF, Vector2.ZERO, {"choice": "rat"})
	assert_true(r.ok and not r.is_paused())
	assert_true(t.creature.name.ends_with("(Rat)"), t.creature.name)
	c.creature.concentration.end("test")
	assert_false(e.shapes.is_shaped(t))
	var e2 := _field()
	var c2 := TestCombat.high_caster(e2, ["polymorph"], Vector2i(2, 3))
	var ally := TestCombat.hero(e2, "ilse_varga", Vector2i(3, 4))
	TestCombat.foe(e2, "scout", Vector2i(9, 3))
	TestCombat.start_with(e2, c2)
	var r2 := e2.spells.cast(c2, "polymorph", 4, [ally])
	assert_true(r2.ok and not r2.is_paused(), "an ally isn't asked about")
	var forms := e2.spells.specials.polymorph_forms(ally)
	assert_true(ally.creature.name.ends_with("(%s)" % forms[forms.size() - 1]["name"]), "the strongest form its level allows: %s" % ally.creature.name)


func test_a_foe_that_saves_is_unchanged_and_nothing_is_asked() -> void:
	var e := _field()
	var c := TestCombat.high_caster(e, ["polymorph"], Vector2i(2, 3))
	var t := TestCombat.foe(e, "scout", Vector2i(5, 3))
	TestCombat.start_with(e, c)
	TestCombat.next_d20(e, 20)
	var r := e.spells.cast(c, "polymorph", 4, [t])
	assert_true(r.ok and not r.is_paused())
	assert_false(e.shapes.is_shaped(t))
	assert_true(c.creature.concentration == null or c.creature.concentration.ended, "no one to hold it on")


func test_a_shapechanger_can_be_polymorphed_now() -> void:
	var e := _field()
	var c := TestCombat.high_caster(e, ["polymorph", "true_polymorph"], Vector2i(2, 3))
	var t := TestCombat.foe(e, "mimic", Vector2i(5, 3))
	# The mark the 2014 rule looked for.
	t.creature.add_effect(Effect.new("Shapechanger", &"effect", "test").with_modifier("flag", {"value": "shapechanger"}))
	assert_true(t.creature.has_flag("shapechanger"))
	TestCombat.start_with(e, c)
	TestCombat.next_d20(e, 1)
	var r := e.spells.cast(c, "polymorph", 4, [t], Vector2.INF, Vector2.ZERO, {"choice": "rat"})
	assert_true(r.ok)
	assert_true(e.shapes.is_shaped(t), "the 2024 Polymorph has no shapechanger rule")


func test_a_foe_with_polymorph_casts_it_on_a_hero_and_picks_the_weakest_beast() -> void:
	var e := _field()
	var hero := TestCombat.hero(e, "hedda_ironvow", Vector2i(2, 3), 5)
	var hag := TestCombat.foe(e, "baba_lysaga", Vector2i(7, 3))
	e.difficulty.tactics = "sharp"
	TestCombat.start_with(e, hag)
	var s := Compendium.shared().spell_data("polymorph")
	assert_true(e.ai.spells.worth(hag, s, hero) > 0.0, "Polymorph is worth something against a hero")
	var plan := e.ai.spells._best_use(hag, "polymorph")
	assert_false(plan.is_empty(), "the hag would cast it")
	assert_eq((plan["targets"] as Array)[0], hero)
	TestCombat.next_d20(e, 1)
	var r := e.ai.spells.cast(hag, plan)
	assert_true(r.ok, r.reason)
	if r.is_paused():
		e.answer_reaction(false)   # a hero's own choices on the save (Heroic Inspiration), declined
	assert_true(e.shapes.is_shaped(hero), "the hero fails and is a Beast")
	var weakest := e.spells.specials.polymorph_forms(hero)[0]
	assert_true(hero.creature.name.ends_with("(%s)" % weakest["name"]), "the hag picks the weakest: %s" % hero.creature.name)
	assert_true(hero.is_player_controlled(), "still the player's to move")
	assert_eq(e.shapes.original(hero).character_level(), 5)


func test_the_ai_leaves_a_hero_already_in_a_shape_alone() -> void:
	var e := _field()
	var hero := TestCombat.hero(e, "hedda_ironvow", Vector2i(2, 3), 5)
	var hag := TestCombat.foe(e, "baba_lysaga", Vector2i(7, 3))
	TestCombat.start_with(e, hag)
	var s := Compendium.shared().spell_data("polymorph")
	var before := e.ai.spells.worth(hag, s, hero)
	e.shapes.transform(hero, ShapeChange.beast_forms(0.0)[0], {"temp_hp": 1, "ends_without_temp_hp": true, "label": "Polymorph"})
	assert_true(e.ai.spells.worth(hag, s, hero) < before, "nothing more to take from a Beast")
