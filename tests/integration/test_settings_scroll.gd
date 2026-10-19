extends TestCase
## Settings, Game: more rows than fit between the tabs and the Back button, so they scroll in a window of their own with
## Back and Resume pinned below (owner report 2026-10-18: the last row was clipped behind Back). The wheel, Page Up and
## Down, Home and End and a row that takes focus (the pad's, a Tab) all scroll; the scroll bar shows; nothing is cut at the
## window's edges or runs into another row.

var root: Node


func _frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame


func after_each() -> void:
	if root != null:
		root.queue_free()
		root = null
	GameState.reset()
	SaveSystem.current_slot = ""


func _open_game_page() -> Node:
	DirAccess.make_dir_recursive_absolute(SaveSystem.save_dir)
	var out := FileAccess.open(SaveSystem.slot_path("settings_scroll"), FileAccess.WRITE)
	out.store_string(FileAccess.get_file_as_string(GoldenSaves.DIR + "v2_amber_temple.json"))
	out.close()
	assert_eq(SaveSystem.load_slot("settings_scroll"), OK)
	SaveSystem.delete_slot("settings_scroll")
	root = (load("res://scenes/game.tscn") as PackedScene).instantiate()
	add_child(root)
	await _frames(5)
	root.call("open_screen", "menu", 0)
	await _frames(1)
	root.get("screen").call("_show_settings", "Game")
	await _frames(3)
	return root.get("screen") as Node


func _scroll(menu: Node) -> ScrollContainer:
	return menu.find_child("GameRows", true, false) as ScrollContainer


## The choice rows (their buttons) and the respec box, top to bottom, all inside the scrolling window.
func _items(menu: Node) -> Array[Control]:
	var out: Array[Control] = []
	for n in _scroll(menu).find_children("*", "Control", true, false):
		var c := n as Control
		if (c is Button and (c as Button).text.begins_with("‹")) or c is CheckBox:
			out.append(c)
	out.sort_custom(func(a: Control, b: Control) -> bool: return a.get_global_rect().position.y < b.get_global_rect().position.y)
	return out


func _button(menu: Node, text: String) -> Button:
	for n in menu.find_children("*", "Button", true, false):
		if (n as Button).text == text and (n as Button).is_visible_in_tree():
			return n as Button
	return null


## The middle of a control in the window's own pixels (the game draws at 1600 x 900 and stretches), where the mouse would be.
func _middle(c: Control) -> Vector2:
	return get_tree().root.get_final_transform() * (c.get_global_transform_with_canvas() * (c.size / 2.0))


func _wheel(at: Vector2, down: bool) -> void:
	# The pointer comes to the spot, then the wheel turns, through the engine's own input (a window sees both).
	var move := InputEventMouseMotion.new()
	move.position = at
	move.global_position = at
	Input.parse_input_event(move)
	var ev := InputEventMouseButton.new()
	ev.button_index = MOUSE_BUTTON_WHEEL_DOWN if down else MOUSE_BUTTON_WHEEL_UP
	ev.pressed = true
	ev.position = at
	ev.global_position = at
	Input.parse_input_event(ev)


func _key(code: Key) -> void:
	var ev := InputEventKey.new()
	ev.keycode = code
	ev.pressed = true
	get_tree().root.push_input(ev)


func test_the_rows_scroll_in_a_window_above_back_and_resume() -> void:
	var menu := await _open_game_page()
	var sc := _scroll(menu)
	assert_true(sc != null, "the Game page's rows are in a scrolling window")
	var back := _button(menu, "Back")
	var resume := _button(menu, "Resume")
	assert_true(back != null and resume != null, "Back and Resume are there")
	assert_true(sc.get_global_rect().end.y <= back.get_global_rect().position.y, "the window ends above Back")
	assert_true(sc.get_v_scroll_bar().visible, "the scroll bar shows")
	assert_true(sc.get_v_scroll_bar().max_value > sc.get_v_scroll_bar().page, "and there is more below")
	assert_eq(sc.horizontal_scroll_mode, ScrollContainer.SCROLL_MODE_DISABLED, "nothing scrolls sideways")
	var back_at := back.get_global_rect().position
	sc.scroll_vertical = 100000
	await _frames(2)
	assert_eq(back.get_global_rect().position, back_at, "Back stays where it was while the rows scroll")
	assert_eq(sc.scroll_vertical, int(sc.get_v_scroll_bar().max_value - sc.get_v_scroll_bar().page), "to the end")


func test_no_row_is_cut_at_the_sides_or_runs_into_another() -> void:
	var menu := await _open_game_page()
	var sc := _scroll(menu)
	var bar := sc.get_v_scroll_bar()
	var items := _items(menu)
	assert_true(items.size() >= 9, "the rows are there: %d" % items.size())
	var right := sc.get_global_rect().end.x - bar.size.x
	for it in items:
		var r := it.get_global_rect()
		assert_true(r.end.x <= right + 0.5, "%s ends before the scroll bar (%d, bar at %d)" % [it.name, r.end.x, right])
		assert_true(r.position.x >= sc.get_global_rect().position.x, "%s starts inside the window" % it.name)
	for i in range(1, items.size()):
		assert_true(items[i - 1].get_global_rect().end.y <= items[i].get_global_rect().position.y + 1.0, "row %d clears row %d" % [i, i - 1])


func test_every_row_can_be_scrolled_whole_into_view() -> void:
	var menu := await _open_game_page()
	var sc := _scroll(menu)
	for it in _items(menu):
		sc.ensure_control_visible(it)
		await _frames(1)
		var view := sc.get_global_rect()
		var r := it.get_global_rect()
		assert_true(r.position.y >= view.position.y - 1.0 and r.end.y <= view.end.y + 1.0, "%s is whole in the window (%s in %s)" % [it.name, r, view])
	var last := _items(menu).back() as Control
	assert_true(last is CheckBox, "the respec box is the last, and reachable")


func test_the_wheel_scrolls_over_a_label_a_choice_and_the_respec_box() -> void:
	var menu := await _open_game_page()
	var sc := _scroll(menu)
	var label: Control = null
	for n in sc.find_children("*", "Label", true, false):
		label = n as Control
		break
	var spots: Array[Control] = [label, _items(menu)[1], _items(menu).back() as Control]
	for at in spots:
		sc.ensure_control_visible(at)
		await _frames(2)
		var top := int(sc.get_v_scroll_bar().max_value - sc.get_v_scroll_bar().page)
		var from := sc.scroll_vertical
		var down := from + 2 < top
		_wheel(_middle(at), down)
		await _frames(2)
		if down:
			assert_true(sc.scroll_vertical > from, "the wheel over %s scrolls down (%d to %d)" % [at.name, from, sc.scroll_vertical])
		else:
			assert_true(sc.scroll_vertical < from, "the wheel over %s scrolls up (%d to %d)" % [at.name, from, sc.scroll_vertical])


func test_page_keys_home_and_end_scroll() -> void:
	var menu := await _open_game_page()
	var sc := _scroll(menu)
	_key(KEY_PAGEDOWN)
	await _frames(2)
	assert_true(sc.scroll_vertical > 0, "Page Down")
	_key(KEY_END)
	await _frames(2)
	assert_eq(sc.scroll_vertical, int(sc.get_v_scroll_bar().max_value - sc.get_v_scroll_bar().page), "End")
	_key(KEY_PAGEUP)
	await _frames(2)
	assert_true(sc.scroll_vertical < int(sc.get_v_scroll_bar().max_value - sc.get_v_scroll_bar().page), "Page Up")
	_key(KEY_HOME)
	await _frames(2)
	assert_eq(sc.scroll_vertical, 0, "Home")


func test_a_row_that_takes_focus_scrolls_into_view() -> void:
	var menu := await _open_game_page()
	var sc := _scroll(menu)
	var last := _items(menu).back() as Control
	last.focus_mode = Control.FOCUS_ALL   # as the pad's tracker gives one (PadNav.focus_on)
	last.grab_focus()
	await _frames(3)
	var view := sc.get_global_rect()
	assert_true(last.get_global_rect().end.y <= view.end.y + 1.0, "the focused last row is in the window (%s in %s)" % [last.get_global_rect(), view])
	assert_true(sc.scroll_vertical > 0)


func test_the_pad_can_reach_and_change_the_last_choice() -> void:
	# The pad's tracker moves focus to a row (it brings it into view) and its left and right turn it.
	var menu := await _open_game_page()
	var sc := _scroll(menu)
	var rows: Array[Button] = []
	for it in _items(menu):
		if it is Button and (it as Button).text.begins_with("‹"):
			rows.append(it as Button)
	var last := rows.back() as Button
	assert_true(last.has_meta(&"pad_adjust"), "turns with left and right")
	var pad := PadNav.new()
	add_child(pad)
	pad.focus_on(last)
	await _frames(2)
	assert_true(last.get_global_rect().end.y <= sc.get_global_rect().end.y + 1.0, "in view after the pad focuses it")
	pad.queue_free()


func test_nothing_in_the_window_swallows_the_wheel() -> void:
	# A Control that stops the mouse keeps the wheel from the window, so a row's parts pass it on (a Button's click stays
	# its own). The window's own scroll bars take it as theirs.
	var menu := await _open_game_page()
	var sc := _scroll(menu)
	var stoppers: Array[String] = []
	for n in sc.find_children("*", "Control", true, false):
		var c := n as Control
		if c.mouse_filter == Control.MOUSE_FILTER_STOP and not c is ScrollBar:
			stoppers.append(str(c.name))
	assert_true(stoppers.is_empty(), "these stop the wheel: %s" % ", ".join(stoppers))


func test_a_click_on_a_row_still_turns_it_inside_the_window() -> void:
	var menu := await _open_game_page()
	var row := menu.find_child("Fights", true, false) as Button
	var before := row.text
	row.pressed.emit()
	assert_true(row.text != before, "%s -> %s" % [before, row.text])
	GameSettings.set_fast_combat(false)
