extends TestCase
## Taking back a move (EncounterUndo): a player's creature can undo its moves on its own turn, one at a time, while
## nothing came of them: no die rolled, no reaction offered, nothing new seen, nothing else done since.


## Ends turns until it's `c`'s.
static func _turn_of(e: Encounter, c: Combatant) -> void:
	for i in 8:
		if e.current() == c:
			return
		e.end_turn()


static func _undo_events(e: Encounter) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for ev in e.drain_events():
		if str(ev["type"]) == "move" and bool(ev.get("undo", false)):
			out.append(ev)
	return out


static func _has_aura(c: Combatant, key: String) -> bool:
	return c.creature.effects.any(func(fx: Effect) -> bool: return fx.stack_key == key)


func test_undo_puts_the_mover_back_with_its_movement() -> void:
	var e := TestCombat.open_field()
	var ilse := TestCombat.hero(e, "ilse_varga", Vector2i(1, 1))
	TestCombat.foe(e, "zombie", Vector2i(11, 7))
	TestCombat.start_with(e, ilse)
	assert_false(e.can_undo_move(ilse), "nothing to take back yet")
	assert_eq(e.undo_move(ilse).reason, "No move to take back")
	assert_true(e.move(ilse, Vector2i(3, 1)).ok)
	assert_eq(ilse.movement_left, 20)
	assert_true(e.can_undo_move(ilse), "nothing came of the move")
	e.drain_events()
	var r := e.undo_move(ilse)
	assert_true(r.ok, r.reason)
	assert_eq(ilse.cell, Vector2i(1, 1))
	assert_eq(ilse.movement_left, 30, "the movement comes back")
	assert_false(ilse.moved)
	var back := _undo_events(e)
	assert_eq(back.size(), 1, "one token goes back")
	if back.size() == 1:
		assert_eq(back[0]["id"], ilse.id)
		assert_eq(back[0]["from"], Vector2i(3, 1))
		assert_eq(back[0]["to"], Vector2i(1, 1))
	assert_eq(str(e.log.entries.back()["text"]), "%s takes back the move" % ilse.name())
	assert_false(e.can_undo_move(ilse), "that was the only move")


func test_a_move_that_stood_up_undoes_to_prone_with_the_movement_back() -> void:
	var e := TestCombat.open_field()
	var ilse := TestCombat.hero(e, "ilse_varga", Vector2i(1, 1))
	TestCombat.foe(e, "zombie", Vector2i(11, 7))
	TestCombat.start_with(e, ilse)
	ilse.creature.add_condition(&"prone", "test")
	assert_true(e.move(ilse, Vector2i(3, 1)).ok)
	assert_false(ilse.creature.has_condition(&"prone"), "stood up first")
	assert_eq(ilse.movement_left, 5, "15 ft to stand, 10 to walk")
	assert_true(e.can_undo_move(ilse), "standing up is part of the move")
	assert_true(e.undo_move(ilse).ok)
	assert_true(ilse.creature.has_condition(&"prone"), "Prone again")
	assert_false(ilse.stood_up)
	assert_eq(ilse.movement_left, 30)
	assert_eq(ilse.cell, Vector2i(1, 1))


func test_moves_come_back_one_at_a_time() -> void:
	var e := TestCombat.open_field()
	var ilse := TestCombat.hero(e, "ilse_varga", Vector2i(1, 1))
	TestCombat.foe(e, "zombie", Vector2i(11, 7))
	TestCombat.start_with(e, ilse)
	assert_true(e.move(ilse, Vector2i(3, 1)).ok)
	assert_true(e.move(ilse, Vector2i(5, 1)).ok)
	assert_eq(ilse.movement_left, 10)
	assert_true(e.undo_move(ilse).ok)
	assert_eq(ilse.cell, Vector2i(3, 1), "the last move first")
	assert_eq(ilse.movement_left, 20)
	assert_true(e.can_undo_move(ilse), "then the one before it")
	assert_true(e.undo_move(ilse).ok)
	assert_eq(ilse.cell, Vector2i(1, 1))
	assert_eq(ilse.movement_left, 30)
	assert_false(e.can_undo_move(ilse), "back to the start of the turn")
	assert_true(e.move(ilse, Vector2i(1, 3)).ok)
	assert_true(e.can_undo_move(ilse), "a new move can be taken back too")


func test_settings_and_riders_chosen_after_a_move_dont_stop_it_coming_back() -> void:
	var e := TestCombat.open_field()
	var ilse := TestCombat.hero(e, "ilse_varga", Vector2i(1, 1))
	TestCombat.foe(e, "zombie", Vector2i(11, 7))
	TestCombat.start_with(e, ilse)
	assert_true(e.move(ilse, Vector2i(3, 1)).ok)
	ilse.reaction_rules["opportunity_attack"] = "never"
	assert_true(e.features.toggle_rider(ilse, "maneuver:trip_attack").ok)
	assert_true(e.can_undo_move(ilse))
	assert_true(e.undo_move(ilse).ok)
	assert_eq(ilse.reaction_rules.get("opportunity_attack"), "never", "the rule stays")
	assert_true("maneuver:trip_attack" in ilse.armed, "the rider stays armed")


func test_no_undo_after_another_action_or_on_the_next_turn() -> void:
	var e := TestCombat.open_field()
	var ilse := TestCombat.hero(e, "ilse_varga", Vector2i(1, 1))
	var z := TestCombat.foe(e, "zombie", Vector2i(11, 7))
	TestCombat.start_with(e, ilse)
	assert_true(e.move(ilse, Vector2i(3, 1)).ok)
	assert_true(e.dodge(ilse).ok)
	assert_false(e.can_undo_move(ilse), "Dodge came after the move")
	assert_eq(e.undo_move(ilse).reason, "No move to take back")
	assert_true(e.move(ilse, Vector2i(5, 1)).ok)
	assert_true(e.undo_move(ilse).ok, "a move after the action can be taken back")
	assert_eq(ilse.cell, Vector2i(3, 1))
	assert_false(e.can_undo_move(ilse), "but not past the action")
	assert_true(e.move(ilse, Vector2i(3, 3)).ok)
	e.end_turn()
	assert_eq(e.current(), z)
	assert_false(e.can_undo_move(ilse), "not on someone else's turn")
	e.end_turn()
	assert_eq(e.current(), ilse)
	assert_false(e.can_undo_move(ilse), "not on her next turn")


func test_the_ai_never_takes_back_a_move() -> void:
	var e := TestCombat.open_field()
	TestCombat.hero(e, "ilse_varga", Vector2i(1, 1))
	var z := TestCombat.foe(e, "zombie", Vector2i(11, 7))
	TestCombat.start_with(e, z)
	assert_true(e.move(z, Vector2i(9, 7)).ok)
	assert_false(e.can_undo_move(z))
	assert_false(e.undo_move(z).ok)


func test_no_undo_once_an_opportunity_attack_was_offered_and_declined() -> void:
	var e := TestCombat.open_field(7)
	var ilse := TestCombat.hero(e, "ilse_varga", Vector2i(2, 2))
	var w := TestCombat.foe(e, "wolf", Vector2i(3, 2))
	w.controller = &"player"   # asked, as a player's creature would be
	TestCombat.start_with(e, ilse)
	var r := e.move(ilse, Vector2i(0, 2))
	assert_true(r.is_paused(), "the wolf is asked about its Opportunity Attack")
	assert_false(e.can_undo_move(ilse), "not while the prompt waits")
	assert_false(e.answer_reaction(false).is_paused())
	assert_eq(ilse.cell, Vector2i(0, 2), "the move finished")
	assert_true(w.reaction_available, "declined")
	assert_false(e.can_undo_move(ilse), "the chance to react was offered")
	assert_true(e.undo_move(ilse).reason.contains("react"), "the banner says why")


func test_no_undo_when_the_ai_passed_up_an_opportunity_attack() -> void:
	var e := TestCombat.open_field(7)
	var ilse := TestCombat.hero(e, "ilse_varga", Vector2i(2, 2))
	var w := TestCombat.foe(e, "wolf", Vector2i(3, 2))
	w.ai_profile = &"cowardly"
	w.creature.hp = 3   # Bloodied: a coward lets her go
	TestCombat.start_with(e, ilse)
	var r := e.move(ilse, Vector2i(0, 2))
	assert_true(r.ok and not r.is_paused())
	assert_true(w.reaction_available, "it passed the chance up")
	assert_false(e.can_undo_move(ilse), "it still had the chance")


func test_no_undo_after_a_readied_attack_went_off() -> void:
	var e := TestCombat.open_field(7)
	var ilse := TestCombat.hero(e, "ilse_varga", Vector2i(0, 2))
	var w := TestCombat.foe(e, "wolf", Vector2i(4, 2))
	TestCombat.start_with(e, ilse)
	w.readied = {"option": "monster:bite"}
	var r := e.move(ilse, Vector2i(3, 2))
	assert_true(r.ok and not r.is_paused())
	assert_false(w.reaction_available, "the readied bite went off")
	assert_false(e.can_undo_move(ilse))


func test_no_undo_after_a_move_that_rolled_dice() -> void:
	var e := TestCombat.open_field()
	var c := TestCombat.caster_with(e, ["spike_growth"], Vector2i(0, 0))
	var ilse := TestCombat.hero(e, "ilse_varga", Vector2i(0, 4))
	TestCombat.foe(e, "zombie", Vector2i(11, 7))
	TestCombat.start_with(e, c)
	assert_true(e.spells.cast(c, "spike_growth", 2, [], Vector2(6.0, 4.0)).ok)
	_turn_of(e, ilse)
	assert_eq(e.current(), ilse)
	var hp := ilse.creature.hp
	assert_true(e.move(ilse, Vector2i(3, 4)).ok)
	assert_true(ilse.creature.hp < hp, "the spikes hurt")
	assert_false(e.can_undo_move(ilse))
	assert_true(e.undo_move(ilse).reason.contains("dice"), "the banner says why")


func test_no_undo_after_a_move_that_brought_a_foe_into_sight() -> void:
	var e := TestCombat.encounter(["........", "...#....", "...#....", "...#....", "........"])
	var ilse := TestCombat.hero(e, "ilse_varga", Vector2i(1, 2))
	var w := TestCombat.foe(e, "wolf", Vector2i(5, 2))
	TestCombat.start_with(e, ilse)
	assert_false(e.can_see(ilse, w), "behind the wall")
	assert_true(e.move(ilse, Vector2i(1, 3)).ok)
	assert_true(e.can_undo_move(ilse), "still out of sight")
	assert_true(e.move(ilse, Vector2i(4, 4)).ok)
	assert_true(e.can_see(ilse, w))
	assert_false(e.can_undo_move(ilse), "the wolf is in sight now")
	assert_true(e.undo_move(ilse).reason.contains("sight"))


func test_no_undo_after_a_move_that_found_a_hidden_foe() -> void:
	var e := TestCombat.open_field()
	var ilse := TestCombat.hero(e, "ilse_varga", Vector2i(1, 1))
	var w := TestCombat.foe(e, "wolf", Vector2i(5, 1))
	TestCombat.start_with(e, ilse)
	ilse.creature.base_senses["blindsight"] = 10
	w.hidden = true
	assert_false(e.can_see(ilse, w), "hidden")
	assert_true(e.move(ilse, Vector2i(3, 1)).ok)
	assert_true(e.can_see(ilse, w), "within her blindsight")
	assert_false(e.can_undo_move(ilse))


func test_no_undo_after_the_mover_was_spotted() -> void:
	var e := TestCombat.encounter(["........", "..#.....", "..#.....", "..#.....", "........"])
	var t := TestCombat.hero(e, "tamsin_tealeaf", Vector2i(1, 2))
	TestCombat.foe(e, "zombie", Vector2i(5, 2))
	TestCombat.start_with(e, t)
	t.hidden = true
	t.creature.add_condition(&"invisible", "Hidden")
	assert_true(e.move(t, Vector2i(1, 3)).ok)
	assert_true(t.hidden, "still behind the wall")
	assert_true(e.can_undo_move(t), "moving unseen")
	assert_true(e.move(t, Vector2i(3, 4)).ok)
	assert_false(t.hidden, "the zombie spots her")
	assert_false(e.can_undo_move(t))
	assert_true(e.undo_move(t).reason.contains("spotted"))


func test_a_mounted_move_undoes_rider_and_mount_together() -> void:
	var e := TestCombat.open_field()
	var ilse := TestCombat.hero(e, "ilse_varga", Vector2i(1, 1))
	var steed := e.add(TestCombat.monster("dire_wolf"), &"party", Vector2i(2, 1))
	TestCombat.foe(e, "zombie", Vector2i(11, 7))
	TestCombat.start_with(e, ilse)
	assert_true(e.mount(ilse, steed).ok)
	steed.movement_left = steed.speed()
	var left := ilse.movement_left
	assert_true(e.move(ilse, Vector2i(6, 1)).ok)
	assert_eq(steed.cell, Vector2i(6, 1), "the steed carries her")
	assert_eq(ilse.cell, Vector2i(6, 1))
	e.drain_events()
	assert_true(e.undo_move(ilse).ok)
	assert_eq(steed.cell, Vector2i(2, 1))
	assert_eq(ilse.cell, Vector2i(2, 1), "the rider comes back with it")
	assert_eq(steed.movement_left, steed.speed())
	assert_eq(ilse.movement_left, left)
	assert_eq(e.mount_of(ilse), steed, "still riding")
	var ids: Array[String] = []
	for ev in _undo_events(e):
		ids.append(str(ev["id"]))
	assert_true(ilse.id in ids and steed.id in ids, "both tokens go back")


func test_feature_movement_and_a_jump_come_back() -> void:
	var e := TestCombat.open_field()
	var ilse := TestCombat.hero(e, "ilse_varga", Vector2i(1, 1))
	TestCombat.foe(e, "zombie", Vector2i(11, 7))
	TestCombat.start_with(e, ilse)
	ilse.free_move_ft = 10
	assert_true(e.free_move(ilse, Vector2i(3, 1)).ok)
	assert_eq(ilse.free_move_ft, 0)
	assert_true(e.undo_move(ilse).ok)
	assert_eq(ilse.cell, Vector2i(1, 1))
	assert_eq(ilse.free_move_ft, 10, "the free movement comes back")
	ilse.creature.add_effect(Effect.new("Jump", &"spell", "jump").with_modifier("flag", {"value": "jump"}))
	assert_true(e.jump(ilse, Vector2i(5, 1)).ok)
	assert_eq(ilse.movement_left, 20)
	assert_true(e.undo_move(ilse).ok)
	assert_eq(ilse.cell, Vector2i(1, 1))
	assert_eq(ilse.movement_left, 30)
	assert_false(ilse.has_meta("jumped_round"), "the leap can be made again")
	assert_true(e.jump(ilse, Vector2i(5, 1)).ok)


func test_auras_follow_a_move_taken_back() -> void:
	var e := TestCombat.open_field(3)
	var p := e.add(TestChars.custom("paladin", "human", 6), &"party", Vector2i(2, 3))
	var a := TestCombat.hero(e, "ilse_varga", Vector2i(3, 3))
	TestCombat.foe(e, "zombie", Vector2i(11, 7))
	TestCombat.start_with(e, p)
	e.spells.zones.refresh_auras()
	var key := "aura:%s" % p.id
	assert_true(_has_aura(a, key))
	assert_true(e.move(p, Vector2i(8, 3)).ok)
	assert_false(_has_aura(a, key), "out of the Aura of Protection")
	assert_true(e.can_undo_move(p), "an aura moving with its paladin is part of the move")
	assert_true(e.undo_move(p).ok)
	assert_true(_has_aura(a, key), "back in it")
