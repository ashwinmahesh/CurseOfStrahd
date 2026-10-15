extends TestCase
## The order the screen shows a hit in (owner, 2026-10-14: "concentration checks or saves after being attacked should
## prompt or show after the attack animation and damage dealt displays"): the blow, its damage number, then the hero's
## big d20 for the Concentration save or the hit's rider save, then any prompt about the roll. CombatView.moment_shown
## reports each beat as it reaches the screen.

var e: Encounter
var view: CombatView
var hero: Combatant
var ghoul: Combatant
var _root: Node3D
var beats: Array[String] = []
var held_log_at_damage: Array[bool] = []


func _frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame


## `fighter`: the hero is a level 9 Champion, whose Indomitable can answer a failed save.
func _board(dc: int, ghouls_turn: Callable, fighter: bool = false) -> void:
	_root = Node3D.new()
	add_child(_root)
	var rows: Array = []
	for z in 8:
		rows.append("................")
	e = TestCombat.encounter(rows, 3)
	if fighter:
		hero = e.add(TestChars.custom("fighter", "human", 9, {"fighter_subclass": ["champion"]}), &"party", Vector2i(4, 3))
	else:
		hero = TestCombat.hero(e, "ilse_varga", Vector2i(4, 3), 5)
	(hero.creature as Character).heroic_inspiration = false
	if fighter:
		dc = hero.creature.save_bonus(&"con").total() + 20   # out of reach of the d20 shown, in reach of a reroll
	var data := Compendium.shared().monster_data("ghoul").duplicate(true)
	for a: Variant in data["actions"]:
		var act := a as Dictionary
		if str(act["id"]) == "claw":
			(act["attack"] as Dictionary)["bonus"] = 40
			((act["on_hit"] as Array)[0]["save"] as Dictionary)["dc"] = dc
	ghoul = e.add(Monster.from_data(data), &"enemy", Vector2i(5, 3))
	TestCombat.start_with(e, ghoul)
	var board := ArenaBoard.build(e.grid)
	_root.add_child(board)
	var tokens := {}
	for c in e.combatants:
		var token := CombatToken.create(c)
		token.position = board.cell_center(c.cell, c.size_cells)
		_root.add_child(token)
		tokens[c.id] = token
	var rig := CameraRig.new()
	_root.add_child(rig)
	view = CombatView.new()
	view.input_locked = true
	view.opponent_turn = ghouls_turn
	_root.add_child(view)
	beats.clear()
	held_log_at_damage.clear()
	view.moment_shown.connect(func(kind: String, id: String) -> void:
		beats.append("%s:%s" % [kind, "hero" if id == hero.id else "ghoul"])
		if kind == "damage":
			held_log_at_damage.append(view._log_held))
	view.begin(e, board, rig, tokens)


## Frames until the ghoul's turn has been played out and the screen has gone on (to the hero's turn, or a prompt).
func _played() -> void:
	for i in 900:
		await get_tree().create_timer(0.05).timeout
		if view.mode in [CombatView.Mode.PROMPT, CombatView.Mode.IDLE, CombatView.Mode.TARGET] and not beats.is_empty():
			break
	await _frames(3)


func _done() -> void:
	_root.queue_free()
	await _frames(1)


func test_the_d20_for_a_concentration_save_comes_after_the_damage_number() -> void:
	await _board(1, func(_c: Combatant) -> CombatResult:
		hero.creature.begin_concentration("bless", "Bless")
		view._concentrating[hero.id] = "bless"
		e.events.append({"type": "attack", "attacker": ghoul.id, "target": hero.id, "hit": true, "critical": false, "action": "claw"})
		TestCombat.next_d20(e, 1)   # the Concentration save fails
		e.deal_damage(ghoul, hero, [{"amount": 6, "type": "slashing"}], false, "claw")
		e.end_turn()
		return CombatResult.new())
	await _played()
	assert_eq(beats.slice(0, 3), ["damage:hero", "save:hero", "concentration:hero"] as Array[String], "the damage number, the roll, then the spell breaking: %s" % str(beats))
	assert_eq(held_log_at_damage, [true] as Array[bool], "the log waits for the end of the action")
	assert_false(view._log_held, "and is released after")
	await _done()


func test_a_riders_save_shows_after_the_damage_and_the_prompt_after_both() -> void:
	await _board(0, func(c: Combatant) -> CombatResult:
		TestCombat.next_d20(e, 10)
		return e.monster_attack(c, hero, "claw"), true)
	await _played()
	assert_eq(view.mode, CombatView.Mode.PROMPT, "asked about the failed roll (%s, %s)" % [str(beats), e.pending.kind if e.pending != null else "no prompt"])
	assert_eq(e.pending.kind, "indomitable")
	assert_eq(beats.slice(0, 2), ["damage:hero", "save:hero"] as Array[String], "the damage number, then the d20, and only then the prompt: %s" % str(beats))
	e.answer_reaction(false)   # an open prompt left behind would leak
	await _done()


func test_a_foes_concentration_is_told_once_its_damage_number_has_shown() -> void:
	await _board(5, func(_c: Combatant) -> CombatResult:
		ghoul.creature.begin_concentration("bless", "Bless")
		view._concentrating[ghoul.id] = "bless"
		TestCombat.next_d20(e, 1)
		e.deal_damage(hero, ghoul, [{"amount": 6, "type": "slashing"}], false, "test")
		e.end_turn()
		return CombatResult.new())
	await _played()
	assert_eq(beats.slice(0, 2), ["damage:ghoul", "concentration:ghoul"] as Array[String], str(beats))
	await _done()


func test_saves_made_with_no_events_to_show_them_in_still_show_up_front() -> void:
	await _board(5, func(_c: Combatant) -> CombatResult:
		hero.creature.roll_save(e.dice, &"wis", 10)
		e.events.clear()   # a roll whose "save" event never reached the screen (drained elsewhere)
		e.end_turn()
		return CombatResult.new())
	await _played()
	assert_eq(beats.filter(func(b: String) -> bool: return b == "save:hero"), ["save:hero"] as Array[String], "the old way: shown before whatever follows, never lost, and once: %s" % str(beats))
	await _done()


func test_a_closed_view_never_hangs_on_a_save() -> void:
	await _board(5, func(_c: Combatant) -> CombatResult: return CombatResult.new())
	await _frames(2)
	e.drain_events()
	hero.creature.roll_save(e.dice, &"wis", 10)
	view._closed = true
	await view._play_events()
	assert_true(beats.is_empty(), "nothing shown, nothing stuck")
	view._closed = false
	await _done()
