extends TestCase
## Moving the controller's buttons (U6 step 6, InputActions.pad_bind and Settings > Keys > Controller): a new button
## lands in the InputMap and the settings file, a clash in one list swaps the two commands' buttons, the lists never
## clash with each other, B and Start keep their jobs, a trigger can be bound, the prompts and controls follow, and the
## Keys page's Controller view takes the next pad press while a cap waits.

func before_each() -> void:
	InputActions.ensure()
	InputActions.pad_reset()
	PadNav.current.reset()


func after_each() -> void:
	InputActions.pad_reset()
	PadNav.current.reset()
	await _frames(1)


func _frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame


func _button(b: JoyButton) -> InputEventJoypadButton:
	var ev := InputEventJoypadButton.new()
	ev.button_index = b
	ev.pressed = true
	return ev


func test_a_new_button_works_and_is_kept() -> void:
	assert_eq(InputActions.pad_code(&"search"), JOY_BUTTON_X, "search starts on X")
	var note := InputActions.pad_bind(&"search", JOY_BUTTON_RIGHT_STICK)
	assert_true(note.contains("Turn-based"), "R3 was turn-based's, and the note says so: %s" % note)
	assert_true(_button(JOY_BUTTON_RIGHT_STICK).is_action_pressed(&"search"), "R3 searches")
	assert_false(_button(JOY_BUTTON_X).is_action_pressed(&"search"), "X no longer does")
	assert_eq(InputActions.pad_code(&"plan_mode"), JOY_BUTTON_X, "turn-based took X in exchange")
	var saved := GameSettings.value("pad", {}) as Dictionary
	assert_eq(int(saved.get("search", -1)), int(JOY_BUTTON_RIGHT_STICK), "kept in the settings")
	assert_ne(GameSettings.path, "user://settings.cfg", "tests never touch the player's own settings")
	InputActions.pad_reset()
	assert_true(_button(JOY_BUTTON_X).is_action_pressed(&"search"), "reset brings X back")
	assert_false(InputActions.pad_changed())


func test_the_lists_only_clash_inside_themselves() -> void:
	# Y is the fight's End turn; exploring, Y is the marked thing's menu. Searching on Y swaps only with that.
	InputActions.pad_bind(&"search", JOY_BUTTON_Y)
	assert_eq(InputActions.pad_code(&"marked_menu"), JOY_BUTTON_X, "the marked menu takes X")
	assert_eq(InputActions.pad_code(&"combat_end_turn"), JOY_BUTTON_Y, "the fight keeps Y")


func test_b_and_start_keep_their_jobs() -> void:
	assert_ne(InputActions.pad_bind(&"search", JOY_BUTTON_B), "", "refused with a note")
	assert_ne(InputActions.pad_bind(&"open_map", JOY_BUTTON_START), "")
	assert_ne(InputActions.pad_bind(&"pad_explain", JOY_BUTTON_A), "", "A chooses on screens")
	assert_eq(InputActions.pad_code(&"search"), JOY_BUTTON_X)


func test_a_trigger_can_be_bound() -> void:
	InputActions.pad_bind(&"combat_undo", InputActions.PAD_TRIGGER + JOY_AXIS_TRIGGER_LEFT)
	var lt := InputEventJoypadMotion.new()
	lt.axis = JOY_AXIS_TRIGGER_LEFT
	lt.axis_value = 1.0
	assert_true(lt.is_action_pressed(&"combat_undo"), "LT takes back a move")
	assert_true(lt.is_action_pressed(&"combat_slot_prev") == false, "and the hotbar's slot moved to L3 in exchange")
	assert_eq(InputActions.pad_code(&"combat_slot_prev"), JOY_BUTTON_LEFT_STICK)


func test_what_foes_see_moves_with_the_names() -> void:
	InputActions.pad_bind(&"show_names", JOY_BUTTON_RIGHT_SHOULDER)
	assert_true(_button(JOY_BUTTON_RIGHT_SHOULDER).is_action_pressed(&"show_sight"), "both on RB")


func test_prompts_and_controls_follow() -> void:
	InputActions.pad_bind(&"use_marked", JOY_BUTTON_X)
	assert_eq(PadGlyphs.place_for(&"use_marked"), "x")
	assert_true(PadGlyphs.names("{@use_marked} uses it").begins_with(PadGlyphs.name_of("x", PadGlyphs.family())),
		"the controls card names the new button")


func test_the_keys_page_takes_the_next_pad_press() -> void:
	var st := StoryState.new()
	st.party.append(TestChars.pregen("ilse_varga", 1))
	var menu := PauseMenu.new()
	add_child(menu)
	menu.open(self, st, 0)
	await _frames(1)
	menu.call("_show_settings", "Keys")
	await _frames(2)
	var page := menu.find_children("*", "KeysPage", true, false)[0] as KeysPage
	page.show_pad(true)
	await _frames(2)
	for p in LayoutCheck.problems(menu, get_tree().root.get_visible_rect()):
		fail("the controller view spills: %s" % p)
	var row := page.find_child("search", true, false)
	assert_true(row != null, "the controller view lists Search")
	if row == null:
		menu.queue_free()
		return
	(row.find_child("Button", true, false) as Button).pressed.emit()
	assert_true(page.waiting(), "waiting for a button")
	get_viewport().push_input(_button(JOY_BUTTON_LEFT_SHOULDER))
	assert_false(page.waiting(), "the press was taken")
	assert_eq(InputActions.pad_code(&"search"), JOY_BUTTON_LEFT_SHOULDER, "Search is on LB")
	assert_eq(InputActions.pad_code(&"leader_prev"), JOY_BUTTON_X, "and the one before leads on X")
	var cap := row.find_child("Button", true, false) as Button
	assert_eq(cap.text, PadGlyphs.name_of("lb"), "the cap shows it")
	(row.find_child("Button", true, false) as Button).pressed.emit()
	page.press_pad(JOY_BUTTON_B)
	assert_eq(InputActions.pad_code(&"search"), JOY_BUTTON_LEFT_SHOULDER, "B keeps it")
	assert_eq(page.reset_view(), "Every button is back where it started.")
	assert_eq(InputActions.pad_code(&"search"), JOY_BUTTON_X)
	menu.queue_free()


## The pause menu calls this on whatever opened it.
func close_screen() -> void:
	pass
