extends TestCase
## Striking what you can't see. A creature that is Invisible, to one without See Invisibility or the like, can't be
## picked out at all (owner, 2026-10-13: "They shouldn't be targetable outside of AoE spells", which replaced the 2024
## reading this file first held, that its known square could be struck at Disadvantage): an Invisible hero beside a
## wolf, a scout's arrow across the room, and the party's autopilot beside an Invisible wolf all go unstruck (a creature
## that is only Blinded, or fought in the dark, is still struck at Disadvantage), and a Hidden creature's square isn't
## known, so it isn't struck either (test_invisible_unseen has the rest).


func test_a_foe_cannot_pick_out_an_invisible_hero_beside_it() -> void:
	var e := TestCombat.open_field(4)
	var ilse := TestCombat.hero(e, "ilse_varga", Vector2i(3, 3))
	var w := TestCombat.foe(e, "wolf", Vector2i(4, 3))
	ilse.creature.add_condition(&"invisible", "test")
	TestCombat.start_with(e, w)
	assert_false(e.can_see(w, ilse))
	var plan := e.ai.plan_turn(w)
	assert_true(str(plan["kind"]) != "attack" or plan["target"] != ilse, "it doesn't go for where she is")
	e.run_ai_turn()
	assert_eq(ilse.creature.hp, ilse.creature.max_hp(), "and doesn't bite her")


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


func test_a_scout_does_not_shoot_at_an_invisible_hero_across_the_room() -> void:
	var e := TestCombat.open_field(4)
	var ilse := TestCombat.hero(e, "ilse_varga", Vector2i(1, 3))
	var s := TestCombat.foe(e, "scout", Vector2i(9, 3))
	ilse.creature.add_condition(&"invisible", "test")
	TestCombat.start_with(e, s)
	var plan := e.ai.plan_turn(s)
	assert_true(str(plan["kind"]) != "attack" or plan["target"] != ilse, "no arrow at what it can't see")
	e.run_ai_turn()
	assert_eq(ilse.creature.hp, ilse.creature.max_hp())


## The party's autopilot (balance series) can't pick out an Invisible foe beside it either.
func test_the_autopilot_does_not_strike_an_invisible_foe_beside_it() -> void:
	var e := TestCombat.open_field(4)
	var hedda := TestCombat.hero(e, "hedda_ironvow", Vector2i(3, 3))
	var w := TestCombat.foe(e, "wolf", Vector2i(4, 3))
	w.creature.name = "Unseen Wolf"
	w.creature.add_condition(&"invisible", "test")
	TestCombat.start_with(e, hedda)
	assert_false(e.can_see(hedda, w))
	PartyAutopilot.new(e).play(hedda)
	assert_false(e.log.texts().any(func(t: String) -> bool: return t.contains("Unseen Wolf") and (t.contains(" hits ") or t.contains(" misses "))),
		"Hedda didn't swing at it")
