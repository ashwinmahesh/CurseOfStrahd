extends TestCase
## Pipes of the Sewers (The Lantern in the Roadhouse): a wind-instrument player calls a Swarm of Rats per charge, sways a
## swarm with a Charisma check against its Wisdom check, keeps it only by playing each round, and rats leave the
## attuned piper alone until the piper turns on rats.


func _piper(e: Encounter, id: String, cell: Vector2i) -> Combatant:
	var c := TestCombat.hero(e, id, cell, 3)
	var ch := c.creature as Character
	ch.add_item("pipes_of_the_sewers")
	assert_true(ch.attune("pipes_of_the_sewers"))
	return c


func _swarms(e: Encounter) -> Array[Combatant]:
	var out: Array[Combatant] = []
	for o in e.living():
		if o.creature is Monster and str((o.creature as Monster).data.get("id", "")) == "swarm_of_rats":
			out.append(o)
	return out


func _sure(o: Combatant, value: int) -> void:
	var fx := Effect.new("Test", &"item", "test")
	fx.modifiers.append(Modifier.of("check", {"ability": "wis", "value": value}, "Test", &"item"))
	o.creature.add_effect(fx)


func test_only_a_wind_instrument_player_can_use_them() -> void:
	var e := TestCombat.open_field()
	var c := _piper(e, "ilse_varga", Vector2i(2, 2))
	TestCombat.start_with(e, c)
	var r := e.items.use(c, "pipes_of_the_sewers", "play", [], Vector2.INF, Vector2.ZERO, 0, {"choice": "one"})
	assert_false(r.ok)
	assert_true("wind instrument" in r.reason, r.reason)


func test_each_charge_calls_a_swarm() -> void:
	var e := TestCombat.open_field()
	var c := _piper(e, "wren_featherfoot", Vector2i(5, 5))
	var ch := c.creature as Character
	TestCombat.start_with(e, c)
	assert_true(e.items.use(c, "pipes_of_the_sewers", "play", [], Vector2.INF, Vector2.ZERO, 0, {"choice": "two"}).ok)
	assert_eq(ch.charges_left("pipes_of_the_sewers"), 1, "a charge a swarm")
	assert_eq(_swarms(e).size(), 2)
	for s in _swarms(e):
		assert_true(s.side in [&"guest", &"enemy"], "swayed, or wild: %s" % s.side)
		assert_eq(s.side == &"guest", str(s.get_meta("pipes_piper", "")) == c.id)
	TestCombat.start_with(e, c)
	assert_false(e.items.use(c, "pipes_of_the_sewers", "play", [], Vector2.INF, Vector2.ZERO, 0, {"choice": "two"}).ok, "one charge left")


func test_a_swayed_swarm_obeys_only_while_the_piping_lasts() -> void:
	var e := TestCombat.open_field()
	var c := _piper(e, "wren_featherfoot", Vector2i(5, 5))
	var wild := TestCombat.foe(e, "swarm_of_rats", Vector2i(7, 5))
	var stubborn := TestCombat.foe(e, "swarm_of_rats", Vector2i(5, 7))
	_sure(wild, -30)
	_sure(stubborn, 30)
	TestCombat.start_with(e, c)
	assert_true(e.items.use(c, "pipes_of_the_sewers", "keep", [], Vector2.INF).ok)
	assert_eq(wild.side, &"guest", "the music sways it")
	assert_eq(wild.controller, c.controller, "and it takes the piper's orders")
	assert_eq(stubborn.side, &"enemy")
	assert_true(stubborn.has_meta("pipes_refused"), "a lost contest: it can't be swayed again")
	e.items.specials._pipes_turn(wild)
	assert_eq(wild.side, &"guest", "the piper played since its last turn")
	e.items.specials._pipes_turn(wild)
	assert_eq(wild.side, &"enemy", "no playing this round: it slips control")
	assert_true(wild.has_meta("pipes_refused"))


func test_rats_leave_the_piper_alone_until_threatened() -> void:
	var e := TestCombat.open_field()
	var c := _piper(e, "wren_featherfoot", Vector2i(2, 2))
	var rat := TestCombat.foe(e, "giant_rat", Vector2i(3, 2))
	TestCombat.start_with(e, rat)
	var bite := e.attack_options(rat)[0]
	assert_true("Rats leave" in e.attack_legal(rat, c, bite), e.attack_legal(rat, c, bite))
	e.items.after_attack(c, rat, {}, false)
	assert_eq(e.attack_legal(rat, c, bite), "", "an attack on a rat ends it")
