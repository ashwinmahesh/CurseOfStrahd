extends TestCase
## The controller on screens (Improvement Ideas U6, ui/common/pad_nav.gd), driven by synthetic pad events: the first
## press puts focus on the screen in front and never on the HUD behind it, the D-pad and the stick move to the nearest
## choice that way (one step per lean, repeating while held), a button the mouse can't focus is still a choice, A
## presses buttons and clicks other widgets, X right-clicks, LB/RB step tabs, B is left to the screen, a page over a
## screen takes focus and gives it back when it closes, and the mouse takes over again once it moves.

var nav: PadNav
var hud: CanvasLayer
var screen: CanvasLayer
var grid: Array[Button] = []
var got: Array[String] = []
var closed := 0


class Clickable:
	extends Panel
	var clicks: Array[String] = []

	func _gui_input(event: InputEvent) -> void:
		var mb := event as InputEventMouseButton
		if mb != null and mb.pressed:
			clicks.append("left" if mb.button_index == MOUSE_BUTTON_LEFT else "right")
			accept_event()


class Escapable:
	extends CanvasLayer
	var backs := 0

	func _unhandled_input(event: InputEvent) -> void:
		if event.is_action_pressed(&"ui_cancel"):
			backs += 1
			get_viewport().set_input_as_handled()


func before_each() -> void:
	InputActions.ensure()
	nav = PadNav.current
	nav.reset()
	got.clear()
	grid.clear()
	closed = 0
	hud = CanvasLayer.new()
	hud.layer = 10
	add_child(hud)
	var hb := _button("HUD", Vector2(40, 820))
	hud.add_child(hb)
	screen = Escapable.new()
	screen.layer = 30
	add_child(screen)
	for i in 9:
		var b := _button(str(i), Vector2(400 + (i % 3) * 160, 200 + (i / 3) * 90))
		screen.add_child(b)
		grid.append(b)
	await _frames(2)


func after_each() -> void:
	nav.reset()
	if is_instance_valid(hud):
		hud.queue_free()
	if is_instance_valid(screen):
		screen.queue_free()
	await _frames(1)


## The pause menu's Resume and Escape call this on whatever opened it.
func close_screen() -> void:
	closed += 1


func _button(text: String, at: Vector2) -> Button:
	var b := Button.new()
	b.name = "B" + text
	b.text = text
	b.position = at
	b.size = Vector2(120, 50)
	b.pressed.connect(func() -> void: got.append(text))
	return b


func _frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame


func _press(button: JoyButton) -> void:
	for down: bool in [true, false]:
		var ev := InputEventJoypadButton.new()
		ev.button_index = button
		ev.pressed = down
		get_viewport().push_input(ev)
	await _frames(1)


func _lean(axis: JoyAxis, value: float) -> void:
	var ev := InputEventJoypadMotion.new()
	ev.axis = axis
	ev.axis_value = value
	get_viewport().push_input(ev)


func _focus() -> Control:
	return get_viewport().gui_get_focus_owner()


func test_the_first_press_lands_on_the_screen_in_front() -> void:
	assert_eq(nav.scope_now(), screen, "the screen is in front of the HUD")
	await _press(JOY_BUTTON_DPAD_DOWN)
	assert_true(nav.pad, "a pad press switches to the pad")
	assert_eq(_focus(), grid[0], "focus lands on the first choice, top left")
	assert_true(got.is_empty(), "landing presses nothing")


func test_the_d_pad_moves_to_the_nearest_choice_and_stays_on_the_screen() -> void:
	await _press(JOY_BUTTON_DPAD_DOWN)
	await _press(JOY_BUTTON_DPAD_RIGHT)
	assert_eq(_focus(), grid[1])
	await _press(JOY_BUTTON_DPAD_DOWN)
	assert_eq(_focus(), grid[4])
	await _press(JOY_BUTTON_DPAD_DOWN)
	await _press(JOY_BUTTON_DPAD_DOWN)
	assert_eq(_focus(), grid[7], "the bottom row; the HUD's button below isn't reached")
	await _press(JOY_BUTTON_DPAD_LEFT)
	await _press(JOY_BUTTON_DPAD_LEFT)
	await _press(JOY_BUTTON_DPAD_LEFT)
	assert_eq(_focus(), grid[6], "it stops at the edge")


func test_a_stick_lean_moves_once_until_it_comes_back() -> void:
	await _press(JOY_BUTTON_DPAD_DOWN)
	for v: float in [0.3, 0.6, 0.8, 1.0, 0.9]:
		_lean(JOY_AXIS_LEFT_X, v)
	await _frames(1)
	assert_eq(_focus(), grid[1], "one step for the whole lean")
	_lean(JOY_AXIS_LEFT_X, 0.1)
	_lean(JOY_AXIS_LEFT_X, 0.9)
	await _frames(1)
	assert_eq(_focus(), grid[2], "let go and leaned again: a second step")
	_lean(JOY_AXIS_LEFT_X, 0.0)
	_lean(JOY_AXIS_LEFT_Y, 1.0)
	await _frames(1)
	assert_eq(_focus(), grid[5], "down")
	_lean(JOY_AXIS_LEFT_Y, 0.0)


func test_a_held_direction_repeats() -> void:
	await _press(JOY_BUTTON_DPAD_DOWN)
	var ev := InputEventJoypadButton.new()
	ev.button_index = JOY_BUTTON_DPAD_DOWN
	ev.pressed = true
	get_viewport().push_input(ev)
	assert_eq(_focus(), grid[3])
	nav._repeat(PadNav.REPEAT_DELAY + 0.01)
	assert_eq(_focus(), grid[6], "held past the delay: another step")
	var up := ev.duplicate() as InputEventJoypadButton
	up.pressed = false
	get_viewport().push_input(up)
	nav._repeat(1.0)
	assert_eq(_focus(), grid[6], "let go: no more")


func test_a_presses_buttons_and_clicks_other_widgets() -> void:
	var tile := Clickable.new()
	tile.position = Vector2(400, 480)
	tile.size = Vector2(120, 80)
	screen.add_child(tile)
	await _frames(1)
	await _press(JOY_BUTTON_DPAD_DOWN)
	await _press(JOY_BUTTON_A)
	assert_eq(got, ["0"], "A pressed the button with focus")
	for i in 3:
		await _press(JOY_BUTTON_DPAD_DOWN)
	assert_eq(_focus(), tile, "a clickable panel is a choice too")
	await _press(JOY_BUTTON_A)
	await _press(JOY_BUTTON_X)
	assert_eq(tile.clicks, ["left", "right"], "A clicks it and X right-clicks it")
	assert_true(nav.pad, "the pad's own clicks don't hand control to the mouse")


func test_buttons_the_mouse_cant_focus_are_choices_until_left() -> void:
	grid[1].focus_mode = Control.FOCUS_NONE
	await _press(JOY_BUTTON_DPAD_DOWN)
	await _press(JOY_BUTTON_DPAD_RIGHT)
	assert_eq(_focus(), grid[1], "reached")
	await _press(JOY_BUTTON_A)
	assert_eq(got, ["1"])
	await _press(JOY_BUTTON_DPAD_RIGHT)
	assert_eq(grid[1].focus_mode, Control.FOCUS_NONE, "back to taking no focus once left")


func test_b_is_left_to_the_screen() -> void:
	await _press(JOY_BUTTON_DPAD_DOWN)
	await _press(JOY_BUTTON_B)
	assert_eq((screen as Escapable).backs, 1, "the screen's own Escape ran")


func test_a_page_over_the_screen_takes_focus_and_gives_it_back() -> void:
	await _press(JOY_BUTTON_DPAD_DOWN)
	await _press(JOY_BUTTON_DPAD_RIGHT)
	var page := CanvasLayer.new()
	page.layer = 31
	add_child(page)
	var ok := _button("OK", Vector2(700, 600))
	page.add_child(ok)
	await _frames(2)
	assert_eq(_focus(), ok, "the page in front has focus")
	await _press(JOY_BUTTON_DPAD_UP)
	assert_eq(_focus(), ok, "and keeps it: the screen behind isn't reachable")
	page.queue_free()
	await _frames(2)
	assert_eq(_focus(), grid[1], "back where it was")


func test_a_screen_that_rebuilds_keeps_focus_near_where_it_was() -> void:
	await _press(JOY_BUTTON_DPAD_DOWN)
	await _press(JOY_BUTTON_DPAD_DOWN)
	await _press(JOY_BUTTON_DPAD_RIGHT)
	assert_eq(_focus(), grid[4])
	var at := grid[4].position
	grid[4].free()
	var fresh := _button("new", at)
	screen.add_child(fresh)
	await _frames(2)
	assert_eq(_focus(), fresh, "the new button where the old one was")


func test_shoulders_step_tabs() -> void:
	var tabs := TabContainer.new()
	tabs.position = Vector2(900, 200)
	tabs.size = Vector2(300, 200)
	for t: String in ["One", "Two", "Three"]:
		var b := Button.new()
		b.name = t
		b.text = t
		tabs.add_child(b)
	screen.add_child(tabs)
	await _frames(2)
	await _press(JOY_BUTTON_DPAD_DOWN)
	await _press(JOY_BUTTON_RIGHT_SHOULDER)
	assert_eq(tabs.current_tab, 1)
	await _press(JOY_BUTTON_LEFT_SHOULDER)
	await _press(JOY_BUTTON_LEFT_SHOULDER)
	assert_eq(tabs.current_tab, 2, "wraps round")


func test_the_mouse_takes_over_once_it_moves() -> void:
	await _press(JOY_BUTTON_DPAD_DOWN)
	assert_true(nav.pad)
	var nudge := InputEventMouseMotion.new()
	nudge.relative = Vector2(3, 0)
	get_viewport().push_input(nudge, true)
	assert_true(nav.pad, "a twitch doesn't")
	var move := InputEventMouseMotion.new()
	move.relative = Vector2(40, 10)
	get_viewport().push_input(move, true)
	assert_false(nav.pad, "a real move does")
	await _frames(1)
	assert_false(nav.ring.visible, "and the frame goes")


func test_the_frame_follows_focus() -> void:
	await _press(JOY_BUTTON_DPAD_DOWN)
	await _press(JOY_BUTTON_DPAD_RIGHT)
	await _frames(1)
	assert_true(nav.ring.visible, "shown while the pad is in use")
	assert_true(nav.ring.goal().encloses(PadNav.rect_of(grid[1])), "round the choice with focus")


func test_with_nothing_in_front_the_pad_is_left_to_the_game() -> void:
	screen.queue_free()
	await _frames(1)
	assert_eq(nav.scope_now(), null, "a HUD at layer 10 is no scope")
	await _press(JOY_BUTTON_DPAD_DOWN)
	assert_true(_focus() == null, "nothing takes focus")


func test_the_right_stick_scrolls_the_list_in_focus() -> void:
	var sc := ScrollContainer.new()
	sc.position = Vector2(900, 100)
	sc.size = Vector2(200, 200)
	var col := VBoxContainer.new()
	for i in 20:
		var b := Button.new()
		b.text = "Row %d" % i
		b.custom_minimum_size = Vector2(180, 40)
		col.add_child(b)
	sc.add_child(col)
	screen.add_child(sc)
	await _frames(2)
	await _press(JOY_BUTTON_DPAD_DOWN)
	nav.focus_on(col.get_child(0) as Control)
	Input.action_press(&"pad_scroll_down", 1.0)
	nav._scroll(0.1)
	Input.action_release(&"pad_scroll_down")
	assert_true(sc.scroll_vertical > 0, "scrolled down (%d)" % sc.scroll_vertical)


func test_a_pads_family_from_its_name() -> void:
	assert_eq(PadNav.family_of("DualSense Wireless Controller"), "playstation")
	assert_eq(PadNav.family_of("PS4 Controller"), "playstation")
	assert_eq(PadNav.family_of("Pro Controller"), "nintendo")
	assert_eq(PadNav.family_of("Xbox Wireless Controller"), "xbox")
	assert_eq(PadNav.family_of("Some Pad", 0x054C), "playstation", "Sony's vendor id")
	assert_eq(PadNav.family_of("8BitDo SN30"), "xbox", "anything else reads as Xbox")


func test_the_engine_menus_answer_to_a_and_b() -> void:
	var a := InputEventJoypadButton.new()
	a.button_index = JOY_BUTTON_A
	a.pressed = true
	assert_true(a.is_action_pressed(&"ui_accept"), "A is ui_accept")
	var b := InputEventJoypadButton.new()
	b.button_index = JOY_BUTTON_B
	b.pressed = true
	assert_true(b.is_action_pressed(&"ui_cancel"), "B is ui_cancel")
	assert_true(b.is_action_pressed(&"combat_cancel"), "and the game's Escape")


func test_the_pause_menu_on_a_pad() -> void:
	screen.queue_free()
	var st := StoryState.new()
	st.party.append(TestChars.pregen("ilse_varga", 1))
	var menu := PauseMenu.new()
	add_child(menu)
	menu.open(self, st, 0)
	await _frames(3)
	await _press(JOY_BUTTON_DPAD_DOWN)
	var first := _focus()
	assert_true(first != null and menu.is_ancestor_of(first), "focus is on the menu")
	await _press(JOY_BUTTON_DPAD_DOWN)
	assert_true(_focus() != first and menu.is_ancestor_of(_focus()), "down moves along it")
	await _press(JOY_BUTTON_B)
	assert_eq(closed, 1, "B closes it")
	menu.queue_free()
	await _frames(1)


func test_typing_with_the_on_screen_keyboard() -> void:
	var field := LineEdit.new()
	field.position = Vector2(400, 600)
	field.size = Vector2(300, 40)
	field.placeholder_text = "Name"
	screen.add_child(field)
	var submitted: Array[String] = []
	field.text_submitted.connect(func(t: String) -> void: submitted.append(t))
	await _frames(1)
	await _press(JOY_BUTTON_DPAD_DOWN)
	nav.focus_on(field)
	await _frames(1)
	await _press(JOY_BUTTON_A)
	await _frames(1)
	var boards := get_tree().root.find_children("*", "PadKeyboard", false, false)
	assert_eq(boards.size(), 1, "A on a text field opens the keyboard")
	if boards.size() != 1:
		return
	var board := boards[0] as PadKeyboard
	assert_eq(nav.scope_now(), board, "in front, with focus")
	assert_eq(str(_focus().get_meta(&"letter", "")), "q", "on the letters")
	await _press(JOY_BUTTON_A)
	await _press(JOY_BUTTON_DPAD_RIGHT)
	await _press(JOY_BUTTON_A)
	await _press(JOY_BUTTON_Y)
	await _press(JOY_BUTTON_X)
	await _press(JOY_BUTTON_X)
	assert_eq(board.text, "Q", "A types (a capital first), Y a space, X deletes")
	await _press(JOY_BUTTON_START)
	await _frames(1)
	assert_eq(field.text, "Q", "Start puts it in the field")
	assert_eq(submitted, ["Q"], "as if Enter were pressed there")
	assert_false(is_instance_valid(board) and board.is_inside_tree(), "and the keyboard goes")
	await _press(JOY_BUTTON_A)
	await _frames(1)
	boards = get_tree().root.find_children("*", "PadKeyboard", false, false)
	assert_eq(boards.size(), 1, "again")
	await _press(JOY_BUTTON_A)
	await _press(JOY_BUTTON_B)
	await _frames(1)
	assert_eq(field.text, "Q", "B leaves the field as it was")
	assert_true(get_tree().root.find_children("*", "PadKeyboard", false, false).filter(
		func(n: Node) -> bool: return not n.is_queued_for_deletion()).is_empty(), "and closes it")
	assert_eq(closed, 0, "without closing the screen under it")
