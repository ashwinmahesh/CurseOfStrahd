extends TestCase
## Enemy turns plan on a worker thread (FN-14: a big fight's enemy plan froze the screen for half a second). The plan
## (AiBrain.think) only reads the fight, so the same seed plays the same fight whether it's made in line or on a
## thread, and a Creature read belongs to the thread that opened it: the screen's questions meanwhile are answered
## afresh and leave it alone.

const ARENA := preload("res://scenes/combat/arena.tscn")


func _frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame


## A fight played by the autopilot and the AI, each AI plan made on a worker thread when `aside`; its log.
func _fight_log(aside: bool) -> String:
	var e := TestCombat.open_field(7)
	TestCombat.hero(e, "ilse_varga", Vector2i(1, 2))
	TestCombat.hero(e, "hedda_ironvow", Vector2i(1, 4))
	TestCombat.hero(e, "silvain_aster", Vector2i(0, 3))
	for cell: Vector2i in [Vector2i(8, 1), Vector2i(9, 3), Vector2i(8, 5)]:
		TestCombat.foe(e, "wolf", cell)
	TestCombat.foe(e, "dire_wolf", Vector2i(9, 4))
	e.default_player_reaction = "auto"
	e.start()
	var pilot := PartyAutopilot.new(e)
	for i in 120:
		if e.state != Encounter.State.ACTIVE or e.round_no > 6:
			break
		var c := e.current()
		if c.is_player_controlled():
			pilot.play(c)
			if e.state == Encounter.State.ACTIVE and e.current() == c and e.pending == null:
				e.end_turn()
		elif aside:
			var r := e.begin_ai_turn()
			if r == null:
				var worker := Thread.new()
				worker.start(e.ai.think.bind(c))
				var thought := worker.wait_to_finish() as Dictionary
				e.finish_ai_turn(thought)
		else:
			e.run_ai_turn()
		while e.pending != null:
			e.answer_reaction(true)
	return e.log.dump()


func test_a_plan_made_on_a_worker_thread_plays_the_same_fight() -> void:
	var inline := _fight_log(false)
	var aside := _fight_log(true)
	assert_true(inline.split("\n").size() > 20, "the fight went some rounds")
	assert_eq(aside, inline, "the same seed, the same fight")


func test_a_read_belongs_to_the_thread_that_opened_it() -> void:
	var m := TestChars.dummy(20)
	var opened := Semaphore.new()
	var go_on := Semaphore.new()
	var seen := {}
	var worker := Thread.new()
	worker.start(func() -> void:
		Creature.begin_read()
		seen["before"] = m.has_flag("prone")
		opened.post()
		go_on.wait()
		seen["after"] = m.has_flag("prone")
		Creature.end_read())
	opened.wait()
	# Meanwhile on the main thread: a fresh answer, and its own read pair neither joins nor ends the worker's.
	m.add_condition(&"prone")
	Creature.begin_read()
	assert_true(m.has_flag("prone"), "the main thread's answer is fresh")
	Creature.end_read()
	go_on.post()
	worker.wait_to_finish()
	assert_false(bool(seen["before"]))
	assert_false(bool(seen["after"]), "the worker's read still answers from what it gathered")
	assert_true(m.has_flag("prone"), "once the read is over, everyone sees the change")


## The arena through the combat view: its enemy turns made on a worker thread (as in the game) or in line (as headless
## runs do) give the same fight; returns [log, whether a plan was seen on a thread].
func _arena_log(aside: bool) -> Array:
	Dice.reseed(3)
	var arena := ARENA.instantiate() as Node3D
	add_child(arena)
	var view := arena.get("view") as CombatView
	view.think_aside = aside
	var e := arena.get("e") as Encounter
	var threaded := false
	for i in 20000:
		if e.state != Encounter.State.ACTIVE or e.round_no > 3:
			break
		threaded = threaded or view.get("_thinker") != null
		var hud := view.get("hud") as CombatHud
		if hud.prompt_open():
			hud.answer_prompt(false)
		elif view.mode == CombatView.Mode.IDLE and e.current().is_player_controlled():
			e.end_turn()
			view.call("_advance")
		await get_tree().process_frame
	await _frames(2)
	var out := [e.log.dump(), threaded]
	arena.queue_free()
	await _frames(2)
	return out


func test_the_combat_view_plans_enemy_turns_on_a_worker_thread() -> void:
	var aside := await _arena_log(true)
	var inline := await _arena_log(false)
	assert_true(bool(aside[1]), "an enemy plan ran on the worker thread")
	assert_false(bool(inline[1]))
	assert_eq(str(aside[0]), str(inline[0]), "the same seed, the same fight")
