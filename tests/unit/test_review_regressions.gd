extends TestCase

var _books: BookContentFixture

func before_each() -> void:
	_books = BookContentFixture.new()

func after_each() -> void:
	_books.restore()

func test_incorporeal_flight_ignores_ground_but_preserves_passage_and_slowing() -> void:
	var grid := CombatGrid.from_rows(["....", ".d#.", "...."])
	grid.set_flag(Vector2i(1, 1), CombatGrid.DIFFICULT)
	var clear := func(_cell: Vector2i) -> bool: return false
	var four := func(_cell: Vector2i) -> int: return 4
	var mode := CombatGrid.MOVE_FLY | CombatGrid.MOVE_INCORPOREAL
	assert_eq(grid.step_cost(Vector2i(0, 1), Vector2i(1, 1), 1, clear, clear, mode), 5)
	assert_eq(grid.step_cost(Vector2i(0, 1), Vector2i(1, 1), 1, clear, clear, CombatGrid.MOVE_INCORPOREAL), 10)
	assert_eq(grid.step_cost(Vector2i(0, 1), Vector2i(1, 1), 1, clear, four, mode), 20)
	assert_eq(grid.step_cost(Vector2i(0, 1), Vector2i(1, 1), 1, clear, four, mode | CombatGrid.MOVE_UNHINDERED), 5)
	assert_eq(grid.step_cost(Vector2i(1, 1), Vector2i(2, 1), 1, clear, clear, mode), 10, "passing through a wall still costs double")
	var occupied := func(_cell: Vector2i) -> bool: return true
	assert_eq(grid.step_cost(Vector2i(0, 1), Vector2i(1, 1), 1, occupied, clear, mode), 10)

func test_charge_accepts_pathfinder_angled_approaches_and_breaks_on_interruptions() -> void:
	for from: Vector2i in [Vector2i(0, 3), Vector2i(0, 0), Vector2i(0, 6), Vector2i(0, 5)]:
		var e := TestCombat.open_field()
		e.default_player_reaction = "never"
		var boar := TestCombat.foe(e, "boar", from)
		var target := TestCombat.hero(e, "ilse_varga", Vector2i(7, 3))
		TestCombat.start_with(e, boar)
		assert_true(e.move(boar, Vector2i(6, 3)).ok)
		assert_eq(boar.cell, Vector2i(6, 3))
		assert_false(e.monster_actions.charge_of(boar, target, {"action_id": "gore"}).is_empty(), str(from))
		boar.clear_run()
		assert_true(e.monster_actions.charge_of(boar, target, {"action_id": "gore"}).is_empty(), "a forced move, teleport or previous attack breaks the approach")

func test_charge_cannot_count_sideways_or_retreating_steps_toward_runup() -> void:
	var e := TestCombat.open_field()
	var boar := TestCombat.foe(e, "boar", Vector2i(1, 1))
	var target := TestCombat.hero(e, "ilse_varga", Vector2i(9, 3))
	TestCombat.start_with(e, boar)
	boar.record_step(Vector2i(1, 1), Vector2i(5, 1))
	boar.record_step(Vector2i(5, 1), Vector2i(5, 3))
	boar.record_step(Vector2i(5, 3), Vector2i(7, 3))
	boar.cell = Vector2i(7, 3)
	boar.moved = true
	assert_true(e.monster_actions.charge_of(boar, target, {"action_id": "gore"}).is_empty())

func fate_setup(id: String) -> Dictionary:
	var e := TestCombat.open_field()
	var ch := TestChars.custom("wizard", "human", 17)
	(ch.spellcasting[0]["prepared"] as Array).append(id)
	var c := e.add(ch, &"party", Vector2i(2, 3))
	TestCombat.punching_bag(e, Vector2i(8, 3))
	TestCombat.start_with(e, c)
	return {"e": e, "c": c, "ch": ch}

func test_reaction_spells_default_to_no_spend_on_failed_rolls_then_honor_public_policy() -> void:
	for id: String in ["reweave_fate", "moment_of_prescience"]:
		var s := fate_setup(id)
		var e := s.e as Encounter
		var c := s.c as Combatant
		var ch := s.ch as Character
		var level := int(ch.compendium.spell_data(id)["level"])
		var slots := ch.slots_left(level)
		var test := D20Test.from_natural(D20Test.Kind.SAVING_THROW, 1, 0, 10)
		e.spells.after_failed_d20(c, test)
		assert_eq(ch.slots_left(level), slots)
		assert_true(c.reaction_available)
		assert_eq(test.kept, 1)
		var catalog := ActionCatalog.new(e)
		var action := catalog.find(c, "feat:reaction_policy:%s:auto" % id)
		assert_false(action.is_empty())
		assert_true(catalog.perform(c, action).ok)
		assert_true(c.action_available)
		assert_true(c.bonus_available)
		e.spells.after_failed_d20(c, test)
		assert_eq(ch.slots_left(level), slots - 1)
		assert_false(c.reaction_available)

func test_reaction_feature_default_preserves_reaction_and_resource() -> void:
	var s := fate_setup("moment_of_prescience")
	var e := s.e as Encounter
	var c := s.c as Combatant
	var ch := s.ch as Character
	ch.features.append({"id": "test_response", "name": "Test response", "roll_response": {"kind": "save", "cost": "reaction", "resource": "test_response", "dice": "1d4"}})
	ch.set_resource("test_response", "Test response", 2, "long")
	var test := D20Test.from_natural(D20Test.Kind.SAVING_THROW, 9, 0, 10)
	e.feature_recipes.after_d20(c, test, ["save:wis"])
	assert_false(test.success)
	assert_true(c.reaction_available)
	assert_eq(ch.resource_left("test_response"), 2)
	assert_true(e.reactions.set_policy(c, "test_response", "auto").ok)
	e.feature_recipes.after_d20(c, test, ["save:wis"])
	assert_true(test.success)
	assert_eq(ch.resource_left("test_response"), 1)
	assert_false(c.reaction_available)

func test_spell_hit_responses_preserve_ask_and_off_policies() -> void:
	var s := fate_setup("moment_of_prescience")
	var e := s.e as Encounter
	var c := s.c as Combatant
	var ch := s.ch as Character
	var foe := TestCombat.caster_with(e, ["fire_bolt"], Vector2i(5, 3))
	var entry := e.spells._entry(foe, "fire_bolt")
	var spell := ch.compendium.spell_data("fire_bolt")
	var ctx := {"c": foe, "s": spell, "nums": e.spells.numbers(foe, entry), "slot": 0, "opts": {}, "conc": null}
	var slots := ch.slots_left(8)
	for mode: String in ["ask", "never"]:
		assert_true(e.reactions.set_policy(c, "moment_of_prescience", mode).ok)
		TestCombat.next_d20(e, 20)
		assert_true(e.spells.spell_attack(ctx, c, CombatResult.new()).success)
		assert_eq(ch.slots_left(8), slots)
		assert_true(c.reaction_available)
	assert_true(e.reactions.set_policy(c, "moment_of_prescience", "auto").ok)
	TestCombat.next_d20(e, 20)
	assert_false(e.spells.spell_attack(ctx, c, CombatResult.new()).success)
	assert_eq(ch.slots_left(8), slots - 1)
