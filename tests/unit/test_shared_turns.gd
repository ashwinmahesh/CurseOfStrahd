extends TestCase
## Shared party turns (owner 2026-10-09, after Baldur's Gate 3; deviations.md): heroes next to each other in the order
## take their turns together, the player switching between them; each hero's own turn still starts and ends once.


## Starts the fight with the order exactly `order` (first to act first).
func _start(e: Encounter, order: Array[Combatant]) -> void:
	e.start()
	while e.pending != null:
		e.answer_reaction(false)
	for i in order.size():
		order[i].initiative = 30 - i
	e.order.sort_custom(func(a: Combatant, b: Combatant) -> bool: return a.initiative > b.initiative)
	e.shared.clear()
	e.shared_started.clear()
	e.shared_ended.clear()
	e.turn_index = 0
	e._begin_turn()


## How often "<name>'s turn" was logged since entry `from`.
func _turn_lines(e: Encounter, c: Combatant, from: int) -> int:
	return e.log.entries.slice(from).filter(func(en: Dictionary) -> bool: return str(en["text"]) == "%s's turn" % c.name()).size()


func test_heroes_next_to_each_other_share_the_turn() -> void:
	var e := TestCombat.open_field()
	var ilse := TestCombat.hero(e, "ilse_varga", Vector2i(2, 2), 5)
	var god := TestCombat.hero(e, "godrick_pendlebrook", Vector2i(2, 4), 5)
	var thistle := TestCombat.hero(e, "thistle", Vector2i(2, 6), 5)
	var z := TestCombat.foe(e, "zombie", Vector2i(9, 2))
	_start(e, [ilse, god, z, thistle])
	assert_eq(e.shared, [ilse.id, god.id] as Array[String], "Ilse and Godrick share; the zombie splits Thistle off")
	assert_eq(e.shared_heroes(), [ilse, god] as Array[Combatant])
	assert_false(e.switch_to(thistle).ok, "Thistle's turn comes after the zombie's")


func test_switching_lets_another_hero_act_first_and_come_back() -> void:
	var e := TestCombat.open_field()
	var ilse := TestCombat.hero(e, "ilse_varga", Vector2i(2, 2), 5)
	var god := TestCombat.hero(e, "godrick_pendlebrook", Vector2i(2, 4), 5)
	var z := TestCombat.foe(e, "zombie", Vector2i(3, 2))
	z.creature.hp = 200
	_start(e, [ilse, god, z])
	var from := e.log.entries.size() - 1   # Ilse's turn line, as the order was set
	assert_true(e.move(ilse, Vector2i(2, 3)).ok, "Ilse moves 5 ft")
	assert_true(e.switch_to(god).ok, "then the player takes Godrick")
	assert_eq(e.current(), god)
	assert_true(e.dash(god).ok, "Godrick dashes")
	assert_true(e.switch_to(ilse).ok, "and goes back to Ilse")
	assert_eq(ilse.movement_left, ilse.speed() - 5, "Ilse's turn went on where it was left")
	assert_true(ilse.action_available, "her Action still waiting")
	assert_true(e.attack(ilse, z, "weapon:greatsword").ok)
	assert_true(e.end_turn().ok)
	assert_eq(e.current(), god, "Godrick's turn goes on")
	assert_false(god.action_available, "his Dash still spent: his turn didn't start again")
	assert_eq(_turn_lines(e, god, from), 1, "Godrick's turn started once")
	assert_eq(_turn_lines(e, ilse, from), 1, "and Ilse's")
	assert_true(e.end_turn().ok)
	assert_eq(e.current(), z, "both done: the zombie's turn")
	assert_true(e.shared.is_empty())


func test_the_turn_order_goes_on_as_before_without_a_switch() -> void:
	var e := TestCombat.open_field()
	var ilse := TestCombat.hero(e, "ilse_varga", Vector2i(2, 2), 5)
	var god := TestCombat.hero(e, "godrick_pendlebrook", Vector2i(2, 4), 5)
	var z := TestCombat.foe(e, "zombie", Vector2i(9, 2))
	_start(e, [ilse, god, z])
	assert_true(e.end_turn().ok)
	assert_eq(e.current(), god)
	assert_true(god.action_available, "Godrick's turn starts as Ilse's ends")
	assert_true(e.end_turn().ok)
	assert_eq(e.current(), z)
	e.run_ai_turn()
	assert_eq(e.round_no, 2)
	assert_eq(e.current(), ilse)
	assert_eq(e.shared, [ilse.id, god.id] as Array[String], "the next round shares again")


func test_one_at_a_time_when_the_option_is_off() -> void:
	var e := TestCombat.open_field()
	e.shared_turns = false
	var ilse := TestCombat.hero(e, "ilse_varga", Vector2i(2, 2), 5)
	var god := TestCombat.hero(e, "godrick_pendlebrook", Vector2i(2, 4), 5)
	var z := TestCombat.foe(e, "zombie", Vector2i(9, 2))
	_start(e, [ilse, god, z])
	assert_true(e.shared.is_empty())
	assert_false(e.switch_to(god).ok, "no switching: one creature at a time")


func test_a_foe_between_heroes_splits_the_turn() -> void:
	var e := TestCombat.open_field()
	var ilse := TestCombat.hero(e, "ilse_varga", Vector2i(2, 2), 5)
	var god := TestCombat.hero(e, "godrick_pendlebrook", Vector2i(2, 4), 5)
	var z := TestCombat.foe(e, "zombie", Vector2i(9, 2))
	_start(e, [ilse, z, god])
	assert_true(e.shared.is_empty(), "a foe between them: each alone")


func test_an_order_re_sorted_by_hand_drops_the_stale_group() -> void:
	# The fight starts with the two heroes side by side (a shared turn); then the order is re-sorted with a foe between
	# them and no turn begun, as some tests and features do: ending the turn must go to the foe, not the other hero.
	var e := TestCombat.open_field()
	var ilse := TestCombat.hero(e, "ilse_varga", Vector2i(2, 2), 5)
	var god := TestCombat.hero(e, "godrick_pendlebrook", Vector2i(2, 4), 5)
	var z := TestCombat.foe(e, "zombie", Vector2i(9, 2))
	_start(e, [ilse, god, z])
	assert_eq(e.shared.size(), 2)
	ilse.initiative = 30
	z.initiative = 20
	god.initiative = 10
	e.order.sort_custom(func(a: Combatant, b: Combatant) -> bool: return a.initiative > b.initiative)
	e.turn_index = 0
	assert_true(e.shared_heroes().is_empty(), "the group no longer matches the order")
	assert_true(e.end_turn().ok)
	assert_eq(e.current(), z, "the zombie's turn, as the order says")
