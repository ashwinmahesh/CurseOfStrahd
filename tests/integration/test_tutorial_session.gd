extends TestCase
## Disposable practice must leave a campaign, its dice and its save bytes exactly as they were.

class TestMenu extends "res://ui/menu/main_menu.gd":
	var campaign_starts := 0

	func _begin() -> void:
		campaign_starts += 1

var session: TutorialSession
var menu: TestMenu
var _save_dir := ""
var _campaign: Dictionary
var _save_bytes: Dictionary
var _dice_state: Dictionary
var _original_dice: DiceRoller
var _story: StoryState
var _finished: Array[bool] = []


func before_each() -> void:
	InputActions.ensure()
	PadNav.current.reset()
	_finished.clear()
	_save_dir = SaveSystem.save_dir
	SaveSystem.save_dir = _save_dir.path_join("tutorial_session/")
	DirAccess.make_dir_recursive_absolute(SaveSystem.save_dir)
	GameState.reset()
	GameState.story.party.append(Pregens.build("ilse_varga", 1))
	GameState.story.flags["sentinel"] = true
	GameState.story.gold = 173
	GameState.story.location = "village_of_barovia"
	GameState.combat_snapshot = {"sentinel": true}
	SaveSystem.current_slot = "existing_campaign"
	Dice.roller.reseed(3841)
	ModeController.force(ModeController.Mode.EXPLORATION)
	assert_eq(SaveSystem._write(SaveSystem.current_slot, GameState.to_dict()), OK)
	_story = GameState.story
	_original_dice = Dice.roller
	_dice_state = Dice.roller.get_state().duplicate(true)
	_campaign = _campaign_state()
	_save_bytes = _files()


func after_each() -> void:
	get_tree().paused = false
	if is_instance_valid(session):
		session.queue_free()
	session = null
	if is_instance_valid(menu):
		menu.queue_free()
	menu = null
	await _frames(3)
	PadNav.current.reset()
	for file in DirAccess.get_files_at(SaveSystem.save_dir):
		DirAccess.remove_absolute(SaveSystem.save_dir.path_join(file))
	DirAccess.remove_absolute(SaveSystem.save_dir)
	SaveSystem.save_dir = _save_dir
	SaveSystem.current_slot = ""
	GameState.reset()
	ModeController.force(ModeController.Mode.EXPLORATION)


func _frames(count: int) -> void:
	for i in count:
		await get_tree().process_frame


func _campaign_state() -> Dictionary:
	var state := GameState.to_dict().duplicate(true)
	state.erase("saved_at")
	state.erase("dice")
	return state


func _files() -> Dictionary:
	var files := {}
	for file in DirAccess.get_files_at(SaveSystem.save_dir):
		files[file] = FileAccess.get_file_as_bytes(SaveSystem.save_dir.path_join(file))
	return files


func _unchanged(restored: bool = false) -> void:
	assert_true(GameState.story == _story)
	assert_eq(_campaign_state(), _campaign, "campaign state is untouched")
	assert_eq(_original_dice.get_state(), _dice_state, "campaign random sequence is untouched")
	assert_eq(SaveSystem.current_slot, "existing_campaign")
	assert_eq(_files(), _save_bytes, "save filenames and bytes are untouched")
	if restored:
		assert_true(Dice.roller == _original_dice, "original roller reference restored")


func _open(pending: bool = false) -> void:
	session = TutorialSession.new()
	session.pending_campaign = pending
	session.finished.connect(func(start: bool) -> void: _finished.append(start))
	add_child(session)
	await _frames(3)


func _lesson(id: String) -> void:
	var index := TutorialSession.EXPLORATION_IDS.find(id)
	if index < 0:
		index = TutorialSession.EXPLORATION_IDS.size() + TutorialCombat.LESSON_IDS.find(id)
	session.start_lesson(index)
	await _frames(3)
	assert_eq(session.lesson_id(), id)


func test_checks_and_recovery_are_real_and_isolated() -> void:
	await _open()
	assert_true(session.practice != GameState.story)
	assert_true(session.practice.party[0] != GameState.story.party[0])
	await _lesson("check")
	var before := session.roller.get_state().duplicate(true)
	session.roll_practice_check()
	assert_true(session.last_check != null)
	assert_ne(session.roller.get_state(), before, "the check rolled private dice")
	assert_true(session.lesson_complete)
	await _lesson("rest")
	var hp := _practice_hp()
	session.practice_rest()
	await _frames(3)
	assert_true(_practice_hp() > hp)
	assert_false(session.lesson_complete)
	session.close_screen()
	assert_true(session.lesson_complete)
	_unchanged()
	session.leave_tutorial()
	assert_eq(_finished, [false] as Array[bool])
	_unchanged(true)


func _practice_hp() -> int:
	var hp := 0
	for ch in session.practice.party:
		hp += ch.hp
	return hp


func test_exploration_requires_movement_and_retry_resets() -> void:
	await _open()
	await _lesson("explore")
	session.next_lesson()
	await _frames(2)
	assert_eq(session.lesson_id(), "explore")
	var start := session.location.leader().cell
	session.location.set_leader(1)
	await _frames(2)
	assert_false(session.lesson_complete, "selecting another hero isn't moving")
	session.location.set_leader(0)
	assert_true(session.location.walk_to(TutorialSession.EXPLORE_TARGET))
	for i in 30:
		session.location._process(0.3)
		await _frames(1)
		if session.lesson_complete:
			break
	assert_true(session.lesson_complete)
	session.retry_lesson()
	await _frames(3)
	assert_eq(session.lesson_id(), "explore")
	assert_false(session.lesson_complete)
	_unchanged()


func test_sheet_and_inventory_use_real_screens_and_real_loot() -> void:
	await _open()
	await _lesson("sheet")
	session.open_screen("sheet")
	await _frames(3)
	assert_true(session.screen is CharacterSheetScreen)
	assert_false(session.lesson_complete)
	session.advance_sheet_step()
	session.advance_sheet_step()
	session.close_screen()
	assert_true(session.lesson_complete)
	await _lesson("inventory")
	session.open_screen("inventory")
	session.close_screen()
	assert_false(session.lesson_complete)
	session.interact_practice_object()
	for i in 40:
		if session.loot != null:
			break
		session.location._process(0.3)
		await _frames(1)
	assert_true(session.loot is LootWindow)
	if session.loot == null:
		return
	var gold := session.practice.gold
	session.loot._take_all()
	await _frames(3)
	assert_true(session.practice.gold > gold)
	session.open_screen("inventory")
	await _frames(3)
	assert_true(session.screen is InventoryScreen)
	session.close_screen()
	assert_true(session.lesson_complete)
	_unchanged()


func test_skip_and_leave_preserve_campaign_and_restore_mode() -> void:
	await _open(true)
	await _lesson("combat_move")
	assert_true(session.combat != null)
	assert_eq(ModeController.mode, ModeController.Mode.COMBAT)
	var index := session.lesson_index
	session.skip_lesson()
	await _frames(3)
	assert_eq(session.lesson_index, index + 1)
	session.leave_tutorial()
	await _frames(3)
	assert_eq(_finished, [true] as Array[bool])
	assert_eq(ModeController.mode, ModeController.Mode.EXPLORATION)
	assert_false(get_tree().paused)
	_unchanged(true)


func test_freeing_during_combat_opening_cannot_write_a_round_save() -> void:
	await _open()
	await _lesson("combat_reaction")
	session.queue_free()
	session = null
	await _frames(5)
	assert_eq(ModeController.mode, ModeController.Mode.EXPLORATION)
	assert_false(get_tree().paused)
	_unchanged(true)


func _press(button: JoyButton) -> void:
	for down: bool in [true, false]:
		var event := InputEventJoypadButton.new()
		event.button_index = button
		event.pressed = down
		get_viewport().push_input(event, true)
	await _frames(3)


func test_controller_start_opens_tutorial_options_and_back_resumes() -> void:
	await _open()
	await _lesson("explore")
	await _press(JOY_BUTTON_START)
	assert_true(session.coach.menu_open)
	await _press(JOY_BUTTON_B)
	assert_false(session.coach.menu_open)
	assert_eq(session.lesson_id(), "explore")
	_unchanged()


func test_new_game_invitation_and_completed_tutorial_preserve_choices() -> void:
	menu = TestMenu.new()
	add_child(menu)
	await _frames(3)
	var hero := Pregens.build("ilse_varga", 1)
	hero.name = "The player's custom hero"
	var chosen: Array[String] = ["hero", "liriel_dawnsong", "thistle", "ratatoille"]
	menu.set("_hero", hero)
	menu.set("_picked", chosen.duplicate())
	menu.set("_difficulty", "tactician")
	menu.call("_offer_tutorial")
	await _frames(3)
	for title: String in ["Learn the basics", "Start campaign", "Back"]:
		assert_true(_button(menu, title) != null)
	var back := _button(menu, "Back")
	if back != null:
		back.pressed.emit()
	await _frames(3)
	assert_eq(menu.get("_view"), "difficulty")
	menu.call("_offer_tutorial")
	await _frames(3)
	menu.call("_launch_tutorial", true)
	await _frames(3)
	var launched := menu.get("_tutorial") as TutorialSession
	assert_true(launched != null)
	if launched == null:
		return
	launched.start_lesson(launched.lesson_count() - 1)
	launched.next_lesson()
	await _frames(5)
	assert_eq(menu.campaign_starts, 1)
	assert_true(menu.get("_hero") == hero)
	assert_eq(menu.get("_picked"), chosen)
	assert_eq(menu.get("_difficulty"), "tactician")
	assert_true(menu.visible)
	_unchanged(true)


func test_title_replay_returns_without_starting_campaign() -> void:
	menu = TestMenu.new()
	add_child(menu)
	await _frames(3)
	assert_true(_button(menu, "Learn to play") != null)
	menu.call("_launch_tutorial", false)
	await _frames(3)
	var launched := menu.get("_tutorial") as TutorialSession
	assert_true(launched != null)
	if launched == null:
		return
	launched.leave_tutorial()
	await _frames(5)
	assert_eq(menu.campaign_starts, 0)
	assert_eq(menu.get("_view"), "title")
	assert_true(menu.visible)
	_unchanged(true)


static func _button(node: Node, title: String) -> Button:
	for child in node.find_children("*", "Button", true, false):
		var button := child as Button
		if button.text == title and not button.is_queued_for_deletion():
			return button
	return null


func _conversation_options() -> bool:
	for i in 12:
		if session.dialogue == null:
			fail("practice conversation ended before choices")
			return false
		if not session.dialogue.options_shown.is_empty():
			return true
		session.dialogue._advance()
		await _frames(1)
	fail("practice conversation never offered choices")
	return false


func test_conversation_uses_real_choices_speaker_checks_and_branch_feedback() -> void:
	await _open()
	await _lesson("conversation")
	session.start_practice_conversation()
	assert_true(session.dialogue is DialogueUI)
	assert_eq(ModeController.mode, ModeController.Mode.DIALOGUE)
	if not await _conversation_options():
		return
	assert_eq(session.dialogue.options_shown.size(), 4)
	var rolls := session.roller.log.size()
	session.dialogue._choose(2)
	if not await _conversation_options():
		return
	assert_eq(session.roller.log.size(), rolls, "an ordinary question needs no roll")
	assert_false(session.lesson_complete)
	session.dialogue.cycle_speaker()
	var speaker := session.dialogue.runner.speaker
	assert_true(speaker == session.practice.party[1])
	session.roller.reseed(TestChars.seed_for_d20(20))
	session.dialogue._choose(1)
	assert_true(session.dialogue.d20 != null, "native roll presentation")
	assert_true(session.dialogue.runner._last_check["who"] == speaker)
	assert_false(session.lesson_complete, "read the consequence before completing")
	for i in 12:
		if session.dialogue == null:
			break
		session.dialogue._advance()
		await _frames(1)
	assert_true(session.dialogue == null)
	assert_true(session.lesson_complete)
	assert_true(session.last_check.success)
	assert_eq(session.practice.get_flag("tutorial_dialogue_result"), "success")
	assert_eq(ModeController.mode, ModeController.Mode.EXPLORATION)
	_unchanged()


func test_conversation_both_skills_have_real_success_and_failure_branches() -> void:
	for option in 2:
		for roll: int in [2, 20]:
			var state := StoryState.new()
			state.party.append(Pregens.build("ilse_varga", 1))
			var dice := DiceRoller.new(TestChars.seed_for_d20(roll))
			var runner := DialogueRunner.new(state, dice)
			assert_true(runner.start(TutorialSession.CONVERSATION_REF))
			var beat := runner.next()
			for i in 10:
				if str(beat["kind"]) == "options":
					break
				beat = runner.next()
			assert_eq(str(beat["kind"]), "options")
			var checked := runner.choose(option)
			assert_eq(str(checked["kind"]), "check")
			assert_eq(int(checked["kept"]), roll)
			assert_eq(bool(checked["success"]), roll == 20)
			for i in 10:
				if str(runner.next()["kind"]) == "end":
					break
			assert_true(bool(state.get_flag("tutorial_dialogue_checked", false)))
			assert_eq(state.get_flag("tutorial_dialogue_result"), "success" if roll == 20 else "failure")
			assert_eq(state.get_flag("tutorial_dialogue_skill"), "persuasion" if option == 0 else "insight")
	_unchanged(true)


func test_conversation_can_pause_leave_unchecked_and_be_retried() -> void:
	await _open()
	await _lesson("conversation")
	session.start_practice_conversation()
	if not await _conversation_options():
		return
	await _press(JOY_BUTTON_START)
	assert_true(session.coach.menu_open)
	assert_false(session.dialogue.visible)
	await _press(JOY_BUTTON_B)
	assert_false(session.coach.menu_open)
	assert_true(session.dialogue.visible)
	session.dialogue._choose(3)
	await _frames(2)
	assert_false(session.lesson_complete)
	session.start_practice_conversation()
	session.retry_lesson()
	await _frames(3)
	assert_true(session.dialogue == null)
	assert_false(session.lesson_complete)
	session.start_practice_conversation()
	session.leave_tutorial()
	await _frames(3)
	assert_true(session.dialogue == null)
	_unchanged(true)


func test_controller_can_reach_the_lesson_action_in_options() -> void:
	await _open()
	await _lesson("sheet")
	await _press(JOY_BUTTON_START)
	assert_true(session.coach.action_button.is_visible_in_tree())
	session.coach.action_button.grab_focus()
	await _press(JOY_BUTTON_A)
	assert_true(session.screen is CharacterSheetScreen)
	assert_true((session.coach.get("_panel") as Control).visible)
	await _press(JOY_BUTTON_A)
	await _press(JOY_BUTTON_A)
	assert_false((session.coach.get("_panel") as Control).visible)
	await _press(JOY_BUTTON_A)
	assert_true(session.lesson_complete)
	_unchanged()


func test_modal_coach_takes_keyboard_focus_from_the_world() -> void:
	await _open()
	await _lesson("sheet")
	var button := session.hud._bar_buttons.get("inventory") as Button
	button.focus_mode = Control.FOCUS_ALL
	button.grab_focus()
	session.coach.show_menu()
	await _frames(3)
	var focused := get_viewport().gui_get_focus_owner()
	assert_true(session.coach.is_ancestor_of(focused))
	assert_false(focused.focus_next.is_empty(), "modal keyboard focus stays within the coach")
	_unchanged()


func test_welcome_card_shrinks_after_initial_text_layout() -> void:
	await _open()
	await _frames(12)
	var panel := session.coach.get("_panel") as PanelContainer
	assert_true(get_viewport().get_visible_rect().encloses(panel.get_global_rect()))
	assert_true(panel.size.y < get_viewport().get_visible_rect().size.y * 0.75, "welcome must not leave an empty full-height panel")


func _wait_for_training_combat() -> void:
	var deadline := Time.get_ticks_msec() + 15000
	while Time.get_ticks_msec() < deadline:
		if session.combat != null and session.combat.view != null and session.combat.view.mode in [CombatView.Mode.IDLE, CombatView.Mode.PROMPT, CombatView.Mode.OVER]:
			return
		await get_tree().process_frame
	fail("training combat did not finish its presentation")


func test_orientation_waits_for_the_real_combat_opening() -> void:
	await _open()
	await _lesson("combat_orientation")
	assert_false(session.lesson_complete)
	await _wait_for_training_combat()
	await _frames(3)
	assert_true(session.lesson_complete)
	assert_eq(session.combat.view.mode, CombatView.Mode.IDLE)
	assert_false(bool(session.combat.view.get("_opening")))
	assert_false(session.combat.view.hud.has_meta(&"layer_fade"))
	assert_true(session.combat.anchor_rect().has_area())
	_unchanged()


func test_options_pause_a_queued_opponent_turn_until_resumed() -> void:
	await _open()
	await _lesson("combat_end_turn")
	await _wait_for_training_combat()
	var cv := session.combat.view
	cv.hud.end_turn_pressed.emit()
	if cv.hud.confirm_open():
		cv.hud.end_turn_pressed.emit()
	assert_true(session.combat.e.current() == session.combat.opponent)
	session.coach.show_menu()
	await _frames(3)
	var dice := session.combat.e.dice.get_state().duplicate(true)
	var log_entries := session.combat.e.log.entries.duplicate(true)
	assert_false(cv.can_process())
	await get_tree().create_timer(CombatView.AI_PAUSE * GameSettings.combat_pace() + 0.5).timeout
	assert_true(session.combat.e.current() == session.combat.opponent)
	assert_eq(session.combat.e.dice.get_state(), dice)
	assert_eq(session.combat.e.log.entries, log_entries)
	assert_false(session.lesson_complete)
	session.coach.close_menu()
	await _wait_for_training_combat()
	await _frames(3)
	assert_true(session.lesson_complete)
	assert_true(session.combat.e.current() == session.combat.hero)
	_unchanged()


func test_completed_lesson_allows_real_floating_feedback_to_finish() -> void:
	await _open()
	await _lesson("combat_bonus")
	await _wait_for_training_combat()
	var cv := session.combat.view
	var action := cv.catalog.find(session.combat.hero, "second_wind")
	cv.hud.action_chosen.emit(action)
	await _wait_for_training_combat()
	await _frames(3)
	assert_true(session.lesson_complete)
	assert_true(cv.input_locked)
	await get_tree().create_timer(CombatView.FLOAT_TIME + 0.3).timeout
	var floating := cv.get_children().filter(func(child: Node) -> bool: return child is Label3D)
	assert_true(floating.is_empty(), "real healing numbers fade and free")
	_unchanged()


func _click_at(point: Vector2) -> void:
	var motion := InputEventMouseMotion.new()
	motion.position = point
	get_viewport().push_input(motion, true)
	for down: bool in [true, false]:
		var event := InputEventMouseButton.new()
		event.position = point
		event.button_index = MOUSE_BUTTON_LEFT
		event.pressed = down
		get_viewport().push_input(event, true)
	await _frames(4)


func test_spotlight_blocks_unrelated_hud_click_and_allows_the_next_button() -> void:
	await _open()
	await _lesson("sheet")
	var inventory := session.hud._bar_buttons.get("inventory") as Control
	var character := session.hud._bar_buttons.get("sheet") as Control
	assert_false(session.coach.allows_point(TutorialSession._guide_rect(inventory).get_center()))
	await _click_at(TutorialSession._guide_rect(inventory).get_center())
	assert_true(session.screen == null, "the dimmed Inventory button cannot open")
	await _click_at(TutorialSession._guide_rect(character).get_center())
	assert_true(session.screen is CharacterSheetScreen, "the spotlight permits the real Character button")
	await _click_at(TutorialSession._guide_rect(session.coach.action_button).get_center())
	await _click_at(TutorialSession._guide_rect(session.coach.action_button).get_center())
	var back := session.get("_guide_close") as Button
	assert_true(is_instance_valid(back))
	await _click_at(TutorialSession._guide_rect(back).get_center())
	assert_true(session.screen == null)
	assert_true(session.lesson_complete)
	_unchanged()


func test_spotlight_walks_only_to_the_lit_square() -> void:
	await _open()
	await _lesson("explore")
	var start := session.location.leader().cell
	var other := session.location.rig.camera.unproject_position(session.location.board.cell_center(Vector2i(11, 13)))
	assert_false(session.coach.allows_point(other))
	await _click_at(other)
	assert_eq(session.location.leader().cell, start)
	var target := session._practice_cell_rect(TutorialSession.EXPLORE_TARGET).get_center()
	assert_true(session.coach.allows_point(target))
	await _click_at(target)
	for i in 40:
		session.location._process(0.3)
		await _frames(1)
		if session.lesson_complete:
			break
	assert_eq(session.location.leader().cell, TutorialSession.EXPLORE_TARGET)
	assert_true(session.lesson_complete)
	_unchanged()


func test_spotlight_rest_requires_long_rest_then_the_back_button() -> void:
	await _open()
	await _lesson("rest")
	await _click_at(TutorialSession._guide_rect(session.hud._bar_buttons["rest"] as Control).get_center())
	assert_true(session.screen is RestScreen)
	var start := session.practice.total_minutes()
	var back := session.get("_guide_close") as Button
	assert_false(session.coach.allows_point(TutorialSession._guide_rect(back).get_center()))
	await _click_at(TutorialSession._guide_rect(back).get_center())
	assert_true(session.screen != null)
	var rest := TutorialSession._guide_button(session.screen, "Take a Long Rest (8 hours)")
	assert_true(rest != null)
	if rest == null:
		return
	await _click_at(TutorialSession._guide_rect(rest).get_center())
	assert_eq(session.practice.total_minutes(), start + 480)
	back = session.get("_guide_close") as Button
	assert_true(session.coach.allows_point(TutorialSession._guide_rect(back).get_center()))
	await _click_at(TutorialSession._guide_rect(back).get_center())
	assert_true(session.lesson_complete)
	_unchanged()


func test_separate_spotlights_do_not_expose_the_space_between_them() -> void:
	var bounds := Rect2(0, 0, 100, 100)
	var holes: Array[Rect2] = [Rect2(10, 10, 20, 20), Rect2(60, 10, 20, 20)]
	var blocks := TutorialCoach.dim_regions(bounds, holes)
	assert_true(blocks.any(func(rect: Rect2) -> bool: return rect.has_point(Vector2(45, 20))))
	for hole in holes:
		assert_false(blocks.any(func(rect: Rect2) -> bool: return rect.has_point(hole.get_center())))
	assert_eq(TutorialCoach.dim_regions(bounds, []).size(), 1)


func test_readable_regions_are_visible_but_never_clickable() -> void:
	await _open()
	await _lesson("sheet")
	var character := session.hud._bar_buttons["sheet"] as Control
	assert_true(character in PadNav.choices(session.hud))
	await _click_at(TutorialSession._guide_rect(character).get_center())
	await _frames(12)
	var back := session.get("_guide_close") as Button
	var read := session._sheet_read_rects(0)
	assert_eq(read.size(), 2)
	assert_false(session.coach.allows_point(TutorialSession._guide_rect(back).get_center()))
	await _click_at(TutorialSession._guide_rect(back).get_center())
	assert_true(session.screen is CharacterSheetScreen)
	for rect in read:
		var point := rect.get_center()
		assert_false(session.coach.allows_point(point))
		assert_false(session.coach._dim_blocks.any(func(block: ColorRect) -> bool: return block.visible and block.get_global_rect().has_point(point)))
		assert_true(session.coach._read_blocks.any(func(block: Control) -> bool: return block.visible and block.get_global_rect().has_point(point)))
		assert_false(session.coach._panel.get_global_rect().intersects(rect))
	var index := session.lesson_index
	for step in 2:
		await _click_at(TutorialSession._guide_rect(session.coach.action_button).get_center())
		assert_eq(session.lesson_index, index)
		assert_eq(session.get("_sheet_step"), step + 1)
		assert_false(session.lesson_complete)
	back = session.get("_guide_close") as Button
	assert_true(back in PadNav.choices(session.screen))
	await _click_at(TutorialSession._guide_rect(back).get_center())
	assert_true(session.lesson_complete)
	_unchanged()


func test_controller_can_target_and_confirm_bless_with_the_highlighted_button() -> void:
	await _open()
	await _lesson("combat_concentration")
	await _wait_for_training_combat()
	await _frames(3)
	# The real initiative roll can put Ilse first; guide her through End Turn.
	if session.combat.e.current() != session.combat.hero:
		await _press(JOY_BUTTON_Y)
		await _frames(3)
		if session.combat.view.hud.confirm_open():
			assert_eq(PadNav.choices(session.combat.view.hud._confirm), [session.combat.view.hud._confirm_yes])
			await _press(JOY_BUTTON_A)
		await _wait_for_training_combat()
		await _frames(3)
	await _press(JOY_BUTTON_RIGHT_SHOULDER)
	if session.combat.view.hud.menu_open():
		await _press(JOY_BUTTON_A)
	assert_eq(session.combat.view.mode, CombatView.Mode.TARGET)
	await _press(JOY_BUTTON_A)
	assert_eq(str(session.combat.guide_state()["step"]), "confirm_spell")
	assert_true(get_viewport().gui_get_focus_owner() == session.coach.action_button, "Bless confirmation keeps controller focus")
	var button_rect := TutorialSession._guide_rect(session.coach.action_button)
	assert_true((session.coach._targets as Array[Rect2]).any(func(rect: Rect2) -> bool: return rect.has_point(button_rect.get_center())), "the spotlight stays on the confirmation button")
	await _press(JOY_BUTTON_A)
	await _wait_for_training_combat()
	await _frames(3)
	assert_true(session.lesson_complete)
	assert_true(session.combat.hero.creature.concentration != null)
	_unchanged()


func test_controller_reaction_focus_excludes_dimmed_policy() -> void:
	await _open()
	await _lesson("combat_reaction")
	await _wait_for_training_combat()
	session.combat.view._end_turn()
	if session.combat.view.hud.confirm_open():
		session.combat.view._end_turn()
	var deadline := Time.get_ticks_msec() + 15000
	while session.combat.view.mode != CombatView.Mode.PROMPT and Time.get_ticks_msec() < deadline:
		await _frames(1)
	assert_eq(session.combat.view.mode, CombatView.Mode.PROMPT)
	await _frames(3)
	var hud := session.combat.view.hud
	var choices := PadNav.choices(hud._prompt)
	assert_eq(choices.size(), 2)
	assert_true(hud._prompt_use in choices)
	assert_true(hud._prompt_skip in choices)
	assert_false(hud._prompt_rule in choices)
	hud._prompt_skip.grab_focus()
	await _press(JOY_BUTTON_A)
	await _wait_for_training_combat()
	await _frames(3)
	assert_true(session.lesson_complete)
	_unchanged()


func test_practice_does_not_change_turn_based_exploration_preference() -> void:
	var original := GameSettings.turn_based()
	GameSettings.set_turn_based(true)
	await _open()
	assert_false(session.location.planning)
	assert_true(GameSettings.turn_based())
	await _lesson("explore")
	session.retry_lesson()
	await _frames(4)
	assert_false(session.location.planning)
	assert_true(GameSettings.turn_based())
	session.leave_tutorial()
	assert_true(GameSettings.turn_based())
	GameSettings.set_turn_based(original)
	_unchanged(true)


func test_pointer_walkthrough_uses_the_real_hotbar_then_the_highlighted_target() -> void:
	await _open()
	await _lesson("combat_attack")
	await _wait_for_training_combat()
	await _frames(3)
	var cv := session.combat.view
	await _click_at(cv.hud.coach_rects("action", "attack:weapon:greatsword")[0].get_center())
	assert_eq(cv.mode, CombatView.Mode.TARGET)
	var target := cv.rig.camera.unproject_position(cv.board.cell_center(session.combat.opponent.cell) + Vector3(0, 0.6, 0))
	assert_true(session.coach.allows_point(target))
	await _click_at(target)
	await _wait_for_training_combat()
	await _frames(3)
	assert_true(session.lesson_complete)
	_unchanged()
