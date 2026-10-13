extends TestCase
## Striking what you can't see (2024, unseen targets): a creature whose square is known (not Hidden) can be attacked
## there at Disadvantage, as the player can by clicking it. The AI and the party's autopilot do so too: an Invisible
## hero beside a wolf, a Blinded wolf, a scout's arrow at an Invisible hero across the room. A Hidden creature's square
## isn't known, so it isn't struck.


func _dis(e: Encounter, c: Combatant, t: Combatant, option_id: String) -> Array:
	return e.attack_situation(c, t, e.option_by_id(c, option_id))["disadvantage"] as Array


func test_a_foe_strikes_an_invisible_hero_beside_it_at_disadvantage() -> void:
	var e := TestCombat.open_field(4)
	var ilse := TestCombat.hero(e, "ilse_varga", Vector2i(3, 3))
	var w := TestCombat.foe(e, "wolf", Vector2i(4, 3))
	ilse.creature.add_condition(&"invisible", "test")
	TestCombat.start_with(e, w)
	assert_false(e.can_see(w, ilse))
	var plan := e.ai.plan_turn(w)
	assert_eq(str(plan["kind"]), "attack", "it goes for where she is")
	assert_eq(plan["target"], ilse)
	assert_true(_dis(e, w, ilse, str(plan["option"])).has("you can't see the target"))
	e.run_ai_turn()
	assert_false(w.action_available, "and bit")


func test_a_hidden_hero_isnt_struck() -> void:
	var e := TestCombat.open_field(4)
	var ilse := TestCombat.hero(e, "ilse_varga", Vector2i(3, 3))
	var w := TestCombat.foe(e, "wolf", Vector2i(4, 3))
	ilse.hidden = true
	ilse.stealth_total = 30
	ilse.creature.add_condition(&"invisible", "Hidden")
	TestCombat.start_with(e, w)
	assert_ne(str(e.ai.plan_turn(w)["kind"]), "attack", "her square isn't known")


func test_a_blinded_foe_still_bites() -> void:
	var e := TestCombat.open_field(4)
	var hedda := TestCombat.hero(e, "hedda_ironvow", Vector2i(3, 3))
	var w := TestCombat.foe(e, "wolf", Vector2i(4, 3))
	w.creature.add_condition(&"blinded", "test")
	TestCombat.start_with(e, w)
	var plan := e.ai.plan_turn(w)
	assert_eq(str(plan["kind"]), "attack")
	assert_eq(plan["target"], hedda)


func test_a_scout_shoots_at_an_invisible_hero_across_the_room() -> void:
	var e := TestCombat.open_field(4)
	var ilse := TestCombat.hero(e, "ilse_varga", Vector2i(1, 3))
	var s := TestCombat.foe(e, "scout", Vector2i(9, 3))
	ilse.creature.add_condition(&"invisible", "test")
	TestCombat.start_with(e, s)
	var plan := e.ai.plan_turn(s)
	assert_eq(str(plan["kind"]), "attack")
	assert_eq(plan["target"], ilse)
	var option := e.option_by_id(s, str(plan["option"]))
	assert_false(bool(option["melee"]), "with its bow, from range")


## The party's autopilot (balance series) swings at an Invisible foe beside it rather than stand there.
func test_the_autopilot_strikes_an_invisible_foe_beside_it() -> void:
	var e := TestCombat.open_field(4)
	var hedda := TestCombat.hero(e, "hedda_ironvow", Vector2i(3, 3))
	var w := TestCombat.foe(e, "wolf", Vector2i(4, 3))
	w.creature.name = "Unseen Wolf"
	w.creature.add_condition(&"invisible", "test")
	TestCombat.start_with(e, hedda)
	assert_false(e.can_see(hedda, w))
	PartyAutopilot.new(e).play(hedda)
	assert_true(e.log.texts().any(func(t: String) -> bool: return t.contains("Unseen Wolf") and (t.contains(" hits ") or t.contains(" misses "))),
		"Hedda swung at it")
