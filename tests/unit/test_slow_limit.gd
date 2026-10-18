extends TestCase
## Slow (2024): "On its turns it can take either an action or a Bonus Action, not both, and if it takes the Attack action
## it can make only one attack." The Attack action itself, a monster's Multiattack included, honours both halves, and a
## Slowed foe the AI plays keeps to its action instead of spending its Bonus Action first. (Coward spirit's
## `action_or_bonus` flag shares the first half.)


func _slow(c: Combatant) -> void:
	c.creature.add_effect(Effect.new("Slowed", &"spell", "slow").with_modifier("flag", {"value": "slowed"}))


func _melee_id(e: Encounter, c: Combatant) -> String:
	for o in e.attack_options(c):
		if bool(o["melee"]):
			return str(o["id"])
	return ""


## Blows a creature struck in the log since `from`: "<name> hits|misses ...".
func _blows(e: Encounter, name: String, from: int) -> int:
	var n := 0
	for i in range(from, e.log.entries.size()):
		var t := str(e.log.entries[i]["text"])
		if t.begins_with(name + " hits") or t.begins_with(name + " misses"):
			n += 1
	return n


func test_a_slowed_hero_cannot_attack_after_a_bonus_action() -> void:
	var e := TestCombat.open_field(3)
	var h := TestCombat.hero(e, "hedda_ironvow", Vector2i(2, 3))
	var bag := TestCombat.punching_bag(e, Vector2i(3, 3), 300)
	TestCombat.start_with(e, h)
	_slow(h)
	h.bonus_available = false   # a Bonus Action taken
	var r := e.attack(h, bag, _melee_id(e, h))
	assert_false(r.ok, "an action or a Bonus Action, not both")
	assert_true(r.reason.contains("not both"), r.reason)
	assert_true(h.action_available, "the action was not spent")


func test_a_slowed_hero_cannot_take_a_bonus_action_after_attacking() -> void:
	var e := TestCombat.open_field(3)
	var h := TestCombat.hero(e, "hedda_ironvow", Vector2i(2, 3))
	var bag := TestCombat.punching_bag(e, Vector2i(3, 3), 300)
	TestCombat.start_with(e, h)
	_slow(h)
	TestCombat.next_d20(e, 15)
	assert_true(e.attack(h, bag, _melee_id(e, h)).ok)
	while e.pending != null:
		e.answer_reaction(false)
	assert_true(e._bonus_check(h).contains("not both"), e._bonus_check(h))


func test_a_slowed_hero_makes_one_attack_with_the_attack_action() -> void:
	var e := TestCombat.open_field(3)
	var h := TestCombat.hero(e, "hedda_ironvow", Vector2i(2, 3), 9)
	var bag := TestCombat.punching_bag(e, Vector2i(3, 3), 300)
	TestCombat.start_with(e, h)
	_slow(h)
	TestCombat.next_d20(e, 15)
	assert_true(e.attack(h, bag, _melee_id(e, h)).ok)
	while e.pending != null:
		e.answer_reaction(false)
	assert_eq(h.attacks_left, 0, "no Extra Attack while Slowed")


func test_a_slowed_monster_cannot_attack_after_a_bonus_action() -> void:
	var e := TestCombat.open_field(3)
	var h := TestCombat.hero(e, "hedda_ironvow", Vector2i(2, 3))
	var w := TestCombat.foe(e, "wolf", Vector2i(3, 3))
	TestCombat.start_with(e, w)
	_slow(w)
	w.bonus_available = false
	var r := e.monster_attack(w, h, "bite")
	assert_false(r.ok)
	assert_true(r.reason.contains("not both"), r.reason)
	assert_true(w.action_available)


func test_a_slowed_multiattack_is_one_attack() -> void:
	var control := TestCombat.open_field(5)
	TestCombat.hero(control, "hedda_ironvow", Vector2i(2, 3), 9)
	var plain := TestCombat.foe(control, "warrior_veteran", Vector2i(3, 3))
	TestCombat.start_with(control, plain)
	var from := control.log.entries.size()
	control.run_ai_turn()
	var plain_blows := _blows(control, "Warrior Veteran", from)
	var e := TestCombat.open_field(5)
	TestCombat.hero(e, "hedda_ironvow", Vector2i(2, 3), 9)
	var slowed := TestCombat.foe(e, "warrior_veteran", Vector2i(3, 3))
	TestCombat.start_with(e, slowed)
	_slow(slowed)
	var start := e.log.entries.size()
	e.run_ai_turn()
	assert_eq(_blows(e, "Warrior Veteran", start), 1, "Slowed: one attack")
	assert_eq(plain_blows, 2, "the Warrior Veteran makes two attacks unslowed")


func test_a_slowed_werewolf_attacks_instead_of_shifting_first() -> void:
	var e := TestCombat.open_field(5)
	TestCombat.hero(e, "hedda_ironvow", Vector2i(2, 3), 9)
	var w := TestCombat.foe(e, "werewolf", Vector2i(3, 3))
	TestCombat.start_with(e, w)
	_slow(w)
	var from := e.log.entries.size()
	e.run_ai_turn()
	assert_false(e.log.texts().slice(from).any(func(t: String) -> bool: return t.contains("twists into")), "no Bonus Action Shape-Shift before its action")
	assert_eq(_blows(e, "Werewolf", from), 1, "and one attack")
