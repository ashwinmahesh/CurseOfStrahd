extends TestCase
## Exercises use the ordinary HUD/view pipeline and complete from actual encounter results.

var lesson: TutorialCombat
var met := 0
var feedback := ""
var _global_dice: Dictionary


func before_each() -> void:
	met = 0
	feedback = ""
	_global_dice = Dice.roller.get_state().duplicate(true)


func after_each() -> void:
	if is_instance_valid(lesson):
		lesson.queue_free()
	lesson = null
	for i in 4:
		await get_tree().process_frame
	assert_eq(Dice.roller.get_state(), _global_dice, "standalone training never rolls campaign dice")


func _open(id: String) -> void:
	lesson = TutorialCombat.new()
	lesson.configure(id, DiceRoller.new(73))
	lesson.objective_met.connect(func(text: String) -> void:
		met += 1
		feedback = text)
	add_child(lesson)
	await _hero_or_prompt()


func _hero_or_prompt() -> void:
	var deadline := Time.get_ticks_msec() + 15000
	while Time.get_ticks_msec() < deadline:
		if lesson.view != null and lesson.e != null:
			var cv := lesson.view
			if cv.mode in [CombatView.Mode.PROMPT, CombatView.Mode.OVER]:
				return
			if cv.mode == CombatView.Mode.IDLE:
				if lesson.e.current() == lesson.hero:
					return
				if not lesson.is_guided() and lesson.hero in lesson.e.shared_heroes():
					cv._switch(lesson.hero)
				else:
					cv.hud.end_turn_pressed.emit()
					if cv.hud.confirm_open():
						cv.hud.end_turn_pressed.emit()
		await get_tree().process_frame
	fail("training did not reach a usable turn or prompt")


func _settled() -> void:
	var deadline := Time.get_ticks_msec() + 15000
	while Time.get_ticks_msec() < deadline:
		if lesson.view.mode in [CombatView.Mode.IDLE, CombatView.Mode.PROMPT, CombatView.Mode.OVER]:
			return
		await get_tree().process_frame
	fail("combat presentation never settled")


func _use(id: String, target: Combatant = null) -> void:
	var action := lesson.view.catalog.find(lesson.e.current(), id)
	assert_false(action.is_empty(), "real catalog action " + id)
	if action.is_empty():
		return
	lesson.view.hud.action_chosen.emit(action)
	if target != null:
		assert_eq(lesson.view.mode, CombatView.Mode.TARGET)
		lesson.view.hover_cell = target.cell
		lesson.view.call("_confirm_target", lesson.e.current(), lesson.view.tokens[target.id] as CombatToken)
		if lesson.view.mode == CombatView.Mode.TARGET:
			lesson.view.confirm_early()
	await _settled()


func test_movement_requires_an_actual_move() -> void:
	await _open("combat_move")
	await _use("dodge")
	assert_eq(met, 0, "an unrelated valid action is not progress")
	var before := lesson.hero.movement_left
	lesson.view.hover_cell = Vector2i(4, 3)
	lesson.view.hover_token = null
	lesson.view.call("_confirm_at")
	await _settled()
	assert_eq(lesson.hero.cell, Vector2i(4, 3))
	assert_true(lesson.hero.movement_left < before)
	assert_eq(met, 1)


func test_a_miss_completes_the_attack_lesson() -> void:
	await _open("combat_attack")
	TestCombat.next_d20(lesson.e, 1)
	await _use("attack:weapon:greatsword", lesson.opponent)
	assert_eq(met, 1)
	assert_true(feedback.contains("missed"))
	assert_false(lesson.hero.action_available)


func test_a_hit_also_completes_the_attack_lesson() -> void:
	await _open("combat_attack")
	var seed_value := 0
	for n in range(1, 100000):
		var trial := DiceRoller.new(n)
		var rolls := trial.roll(20, 2)
		if rolls[0] == 20 and rolls[1] == 20:
			seed_value = n
			break
	assert_true(seed_value > 0)
	lesson.e.dice.reseed(seed_value)
	await _use("attack:weapon:greatsword", lesson.opponent)
	assert_eq(met, 1)
	assert_true(feedback.contains("attack hit"))


func test_second_wind_uses_real_hp_bonus_action_and_charge() -> void:
	await _open("combat_bonus")
	var ch := lesson.hero.creature as Character
	var hp := ch.hp
	var uses := ch.resource_left("second_wind")
	await _use("second_wind")
	assert_true(ch.hp > hp)
	assert_eq(ch.resource_left("second_wind"), uses - 1)
	assert_false(lesson.hero.bonus_available)
	assert_true(lesson.hero.action_available)
	assert_eq(met, 1)


func test_end_turn_observes_the_opponent_and_refresh() -> void:
	await _open("combat_end_turn")
	assert_eq(met, 0)
	lesson.view.hud.end_turn_pressed.emit()
	if lesson.view.hud.confirm_open():
		lesson.view.hud.end_turn_pressed.emit()
	await _hero_or_prompt()
	assert_true(lesson.hero.action_available)
	assert_eq(met, 1)


func _reaction(use: bool) -> void:
	await _open("combat_reaction")
	if lesson.e.pending == null:
		lesson.view.hud.end_turn_pressed.emit()
		if lesson.view.hud.confirm_open():
			lesson.view.hud.end_turn_pressed.emit()
		await _hero_or_prompt()
	assert_true(lesson.e.pending != null, "a real encounter decision must be waiting")
	if lesson.e.pending == null:
		return
	assert_eq(lesson.e.pending.kind, "opportunity_attack")
	assert_eq(met, 0, "merely seeing the prompt isn't completion")
	lesson.view.hud.answer_prompt(use)
	await _settled()
	assert_true(lesson.e.pending == null)
	assert_eq(met, 1)
	assert_true(feedback.contains("uses its Reaction" if use else "holds its Reaction"))


func test_a_real_reaction_can_be_accepted() -> void:
	await _reaction(true)


func test_a_real_reaction_can_be_declined() -> void:
	await _reaction(false)


func test_a_successful_enemy_save_still_completes_the_cantrip() -> void:
	await _open("combat_cantrip")
	var hp := lesson.opponent.creature.hp
	var slots := (lesson.hero.creature as Character).slots_left(1)
	TestCombat.next_d20(lesson.e, 20)
	await _use("spell:sacred_flame", lesson.opponent)
	assert_eq(lesson.opponent.creature.hp, hp)
	assert_eq((lesson.hero.creature as Character).slots_left(1), slots)
	assert_eq(met, 1)


func test_healing_requires_the_wounded_ally_and_spends_a_slot() -> void:
	await _open("combat_heal")
	var hp := lesson.partner.creature.hp
	var slots := (lesson.hero.creature as Character).slots_left(1)
	await _use("spell:cure_wounds", lesson.partner)
	assert_true(lesson.partner.creature.hp > hp)
	assert_eq((lesson.hero.creature as Character).slots_left(1), slots - 1)
	assert_eq(met, 1)


func test_bless_uses_real_targeting_and_concentration() -> void:
	await _open("combat_concentration")
	assert_true(lesson.hero.creature.concentration == null)
	await _use("spell:bless", lesson.hero)
	assert_true(lesson.hero.creature.concentration != null)
	if lesson.hero.creature.concentration != null:
		assert_eq(lesson.hero.creature.concentration.source_id, "bless")
	assert_eq(met, 1)


func test_widgets_provide_visible_highlight_rectangles() -> void:
	await _open("combat_bonus")
	await get_tree().process_frame
	var rect := lesson.anchor_rect()
	assert_true(rect.has_area(), "Second Wind highlights the real action button")
	assert_true(get_viewport().get_visible_rect().encloses(rect))
	assert_false(lesson.view.hud.coach_anchor("unknown").has_area())


func test_leaving_during_presentation_is_safe() -> void:
	await _open("combat_move")
	lesson.view.hover_cell = Vector2i(4, 3)
	lesson.view.hover_token = null
	lesson.view.call("_confirm_at")
	assert_eq(lesson.view.mode, CombatView.Mode.BUSY)
	lesson.queue_free()
	lesson = null
	await get_tree().create_timer(0.5).timeout
	assert_eq(met, 0)


func test_self_healing_after_ally_second_wind_does_not_complete_the_healing_lesson() -> void:
	await _open("combat_heal")
	# Exercise the outcome observer independently of the walkthrough input gate.
	lesson.view.command_filter = Callable()
	for attempt in 8:
		if lesson.e.current() == lesson.partner:
			break
		if lesson.partner in lesson.e.shared_heroes():
			lesson.view._switch(lesson.partner)
		else:
			lesson.view.hud.end_turn_pressed.emit()
			if lesson.view.hud.confirm_open():
				lesson.view.hud.end_turn_pressed.emit()
		await _settled()
	assert_true(lesson.e.current() == lesson.partner)
	if lesson.e.current() != lesson.partner:
		return
	var ally_hp := lesson.partner.creature.hp
	await _use("second_wind")
	assert_true(lesson.partner.creature.hp > ally_hp)
	assert_eq(met, 0)
	await _hero_or_prompt()
	var slots := (lesson.hero.creature as Character).slots_left(1)
	await _use("spell:cure_wounds", lesson.hero)
	assert_eq((lesson.hero.creature as Character).slots_left(1), slots - 1)
	assert_eq(met, 0, "a spell on the wrong target cannot complete this lesson")


func _practice_end_turn() -> void:
	lesson.view.hud.end_turn_pressed.emit()
	if lesson.view.hud.confirm_open():
		lesson.view.hud.end_turn_pressed.emit()
	await _settled()


func _practice_act() -> void:
	var c := lesson.e.current()
	if c == null or not c.can_act():
		await _practice_end_turn()
		return
	var catalog := lesson.view.catalog
	if c == lesson.hero and c.creature.hp <= c.creature.max_hp() / 2:
		var wind := catalog.find(c, "second_wind")
		if not wind.is_empty() and bool(wind["legal"]):
			await _use("second_wind")
	if c == lesson.partner:
		var heal := catalog.find(c, "spell:healing_word")
		var wounded := lesson.hero if lesson.hero.creature.hp < lesson.hero.creature.max_hp() / 2 else lesson.partner
		if wounded.creature.hp < wounded.creature.max_hp() / 2 and not heal.is_empty() and bool(heal["legal"]) and catalog.target_why(c, heal, wounded) == "":
			await _use("spell:healing_word", wounded)
	var attack_id := "attack:weapon:greatsword" if c == lesson.hero else "spell:sacred_flame"
	var attack := catalog.find(c, attack_id)
	if c == lesson.hero and not attack.is_empty() and bool(attack["legal"]) and catalog.target_why(c, attack, lesson.opponent) != "":
		var destination := c.cell
		var distance := lesson.e.grid.distance_ft(c.cell, c.size_cells, lesson.opponent.cell, lesson.opponent.size_cells)
		var reach := lesson.e.reachable_for(c)
		for cell: Vector2i in reach:
			if bool((reach[cell] as Dictionary).get("occupied", false)):
				continue
			var closer := lesson.e.grid.distance_ft(cell, c.size_cells, lesson.opponent.cell, lesson.opponent.size_cells)
			if closer < distance:
				distance = closer
				destination = cell
		if destination != c.cell:
			lesson.view.hover_cell = destination
			lesson.view.hover_token = null
			lesson.view.call("_confirm_at")
			await _settled()
	attack = catalog.find(c, attack_id)
	if not attack.is_empty() and bool(attack["legal"]) and catalog.target_why(c, attack, lesson.opponent) == "":
		await _use(attack_id, lesson.opponent)
	if lesson.view.mode == CombatView.Mode.IDLE and lesson.e.state == Encounter.State.ACTIVE:
		await _practice_end_turn()


func test_final_practice_can_be_won_through_real_controls_against_normal_ai() -> void:
	await _open("combat_practice")
	await _use("dodge")
	await _practice_end_turn()
	for turn in 30:
		if lesson.e.state == Encounter.State.OVER:
			break
		await _settled()
		if lesson.view.mode == CombatView.Mode.PROMPT:
			lesson.view.hud.answer_prompt(true)
			await _settled()
		elif lesson.view.mode == CombatView.Mode.IDLE:
			await _practice_act()
	assert_false(lesson.e.ai.last_plan.is_empty())
	assert_eq(lesson.e.state, Encounter.State.OVER)
	assert_eq(lesson.e.outcome, "victory")
	assert_eq(lesson.view.mode, CombatView.Mode.OVER)
	assert_eq(met, 1)
	assert_true(lesson.completed)


func test_guidance_blocks_unrelated_actions_and_direct_board_attacks() -> void:
	await _open("combat_attack")
	var enemy_hp := lesson.opponent.creature.hp
	lesson.view.hud.action_chosen.emit(lesson.view.catalog.find(lesson.hero, "dodge"))
	assert_true(lesson.hero.action_available)
	lesson.view.hover_token = lesson.view.tokens[lesson.opponent.id] as CombatToken
	lesson.view.hover_cell = lesson.opponent.cell
	lesson.view._confirm_at()
	assert_eq(lesson.view.mode, CombatView.Mode.IDLE)
	assert_eq(lesson.opponent.creature.hp, enemy_hp)
	assert_eq(met, 0)
	await _use("attack:weapon:greatsword", lesson.opponent)
	assert_eq(met, 1)


func test_guided_movement_rejects_other_legal_squares() -> void:
	await _open("combat_move")
	var start := lesson.hero.cell
	var movement := lesson.hero.movement_left
	lesson.view.hover_token = null
	lesson.view.hover_cell = Vector2i(3, 4)
	lesson.view._confirm_at()
	assert_eq(lesson.hero.cell, start)
	assert_eq(lesson.hero.movement_left, movement)
	lesson.view.hover_cell = Vector2i(4, 3)
	lesson.view._confirm_at()
	await _settled()
	assert_eq(lesson.hero.cell, Vector2i(4, 3))
	assert_eq(met, 1)


func test_bless_guidance_requires_self_target_then_explicit_confirmation() -> void:
	await _open("combat_concentration")
	var slots := (lesson.hero.creature as Character).slots_left(1)
	lesson.view.hud.action_chosen.emit(lesson.view.catalog.find(lesson.hero, "spell:bless"))
	assert_eq(str(lesson.guide_state()["step"]), "target")
	lesson.view._confirm_target(lesson.hero, lesson.view.tokens[lesson.opponent.id] as CombatToken)
	assert_true(lesson.view.picked.is_empty())
	lesson.view._confirm_target(lesson.hero, lesson.view.tokens[lesson.hero.id] as CombatToken)
	assert_eq(str(lesson.guide_state()["step"]), "confirm_spell")
	assert_eq(lesson.view.picked, [lesson.hero])
	assert_true(lesson.hero.creature.concentration == null)
	assert_eq((lesson.hero.creature as Character).slots_left(1), slots)
	lesson.confirm_guided_cast()
	await _settled()
	assert_eq(met, 1)
	assert_true(lesson.hero.creature.concentration != null)


func test_wrong_hotbar_group_cannot_open_a_dead_end_menu() -> void:
	await _open("combat_attack")
	for action in lesson.view.hud._slot_actions:
		if bool(action.get("group", false)) and not lesson.view.hud._coach_matches(action):
			lesson.view.hud.use_action(action)
			assert_false(lesson.view.hud.menu_open())
	assert_eq(lesson.view.mode, CombatView.Mode.IDLE)
