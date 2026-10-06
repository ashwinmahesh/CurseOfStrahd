extends TestCase
## Enemy AI v1 (plan §5.3): behavior profiles, target choice, movement and attacks, and turns that pause for the
## player's reactions.


func test_wolf_closes_and_bites() -> void:
	var e := TestCombat.open_field(4)
	var h := TestCombat.hero(e, "hedda_ironvow", Vector2i(2, 3))
	var w := TestCombat.foe(e, "wolf", Vector2i(9, 3))
	TestCombat.start_with(e, w)
	var r := e.run_ai_turn()
	assert_true(r.ok, r.reason)
	assert_eq(e.distance(w, h), 5, "moved next to Hedda")
	assert_false(w.action_available, "and attacked")
	assert_eq(e.current().id, h.id, "the AI ended its turn")


func test_pack_hunter_prefers_a_target_with_an_ally_beside_it() -> void:
	var e := TestCombat.open_field(4)
	var ilse := TestCombat.hero(e, "ilse_varga", Vector2i(3, 1))
	var s := TestCombat.hero(e, "silvain_aster", Vector2i(3, 6))
	TestCombat.foe(e, "wolf", Vector2i(4, 6))
	var w := TestCombat.foe(e, "wolf", Vector2i(7, 3))
	ilse.creature.hp = ilse.creature.max_hp()
	TestCombat.start_with(e, w)
	var plan := e.ai.plan_turn(w)
	assert_eq(str(plan["kind"]), "attack")
	assert_eq((plan["target"] as Combatant).id, s.id, "Pack Tactics against the wizard beats the fighter's AC 17")


func test_zombie_goes_for_the_nearest_enemy() -> void:
	var e := TestCombat.open_field(4)
	var near := TestCombat.hero(e, "ilse_varga", Vector2i(6, 3))
	TestCombat.hero(e, "silvain_aster", Vector2i(1, 3))
	var z := TestCombat.foe(e, "zombie", Vector2i(9, 3))
	TestCombat.start_with(e, z)
	var plan := e.ai.plan_turn(z)
	assert_eq((plan["target"] as Combatant).id, near.id)


func test_far_away_enemies_dash() -> void:
	var e := TestCombat.encounter(["........................"], 4)
	var h := TestCombat.hero(e, "hedda_ironvow", Vector2i(0, 0))
	var z := TestCombat.foe(e, "zombie", Vector2i(23, 0))
	TestCombat.start_with(e, z)
	e.run_ai_turn()
	assert_eq(z.cell, Vector2i(15, 0), "Dash: 40 ft for a 20 ft zombie")
	assert_true(h.is_alive())


func test_ai_turn_waits_for_a_player_opportunity_attack() -> void:
	var e := TestCombat.encounter([".........", "........."], 4)
	var ilse := TestCombat.hero(e, "ilse_varga", Vector2i(2, 0))
	var s := TestCombat.hero(e, "silvain_aster", Vector2i(8, 1))
	var w := TestCombat.foe(e, "wolf", Vector2i(3, 0))
	# The wolf can't see Ilse (hidden), so it goes for Silvain and leaves her reach.
	ilse.hidden = true
	ilse.creature.add_condition(&"invisible", "Hidden")
	s.reaction_rules["shield"] = "never"
	TestCombat.start_with(e, w)
	var r := e.run_ai_turn()
	assert_true(r.is_paused(), "Ilse is asked first")
	assert_eq(r.pending.reactor_id, ilse.id)
	assert_eq(e.current().id, w.id, "the wolf's turn is on hold")
	var r2 := e.answer_reaction(false)
	assert_false(r2.is_paused())
	assert_eq(e.distance(w, s), 5, "the wolf finished its move")
	assert_false(w.action_available, "and its attack")
	assert_ne(e.current().id, w.id, "and ended its turn")


func test_turned_and_commanded_creatures_obey() -> void:
	var e := TestCombat.open_field(4)
	var h := TestCombat.hero(e, "hedda_ironvow", Vector2i(2, 3))
	var w := TestCombat.foe(e, "wolf", Vector2i(3, 3))
	TestCombat.start_with(e, w)
	var halt := Effect.new("Commanded: Halt", &"spell", "command").with_modifier("flag", {"value": "command_halt"})
	halt.caster_id = h.id
	w.creature.add_effect(halt)
	e.run_ai_turn()
	assert_eq(w.cell, Vector2i(3, 3))
	assert_true(w.action_available)
	assert_eq(h.creature.hp, h.creature.max_hp())


func test_profiles_come_from_monster_data() -> void:
	var e := TestCombat.open_field()
	assert_eq(str(TestCombat.foe(e, "wolf", Vector2i(1, 1)).ai_profile), "pack_hunter")
	assert_eq(str(TestCombat.foe(e, "zombie", Vector2i(2, 2)).ai_profile), "mindless")
	assert_eq(str(TestCombat.hero(e, "ilse_varga", Vector2i(3, 3)).controller), "player")
