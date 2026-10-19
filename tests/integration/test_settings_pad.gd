extends TestCase
## Settings on a pad (Ashwin, 2026-10-19): the Game page's rows scroll in a window of their own (PauseMenu.GAME_SCROLL), and
## the D-pad has to walk all of them. A row scrolled out of that window keeps its place in the window's content, which
## lies over the page tabs and Back/Resume on the frame; PadNav.out_of_sight keeps it from catching steps meant for them.
## So whichever way the window is scrolled, the tabs (Keys among them) and Back are reachable, and walking down the rows
## scrolls each into view, then reaches Back; walking up comes back the same way.

var root: Node
var nav: PadNav


func before_each() -> void:
	InputActions.ensure()
	nav = UiFeel.pad   # the game's own tracker (an autoload's), whatever another test did to PadNav.current
	nav.reset()


func after_each() -> void:
	nav.reset()
	get_tree().paused = false
	if root != null:
		root.queue_free()
		root = null
	GameState.reset()
	SaveSystem.current_slot = ""
	await _frames(1)


func _frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame


func _press(button: JoyButton) -> void:
	for down: bool in [true, false]:
		var ev := InputEventJoypadButton.new()
		ev.button_index = button
		ev.pressed = down
		get_viewport().push_input(ev)
	await _frames(2)


## The settings' Game page, open on a pad, in front.
func _game_page() -> Node:
	DirAccess.make_dir_recursive_absolute(SaveSystem.save_dir)
	var out := FileAccess.open(SaveSystem.slot_path("settings_pad"), FileAccess.WRITE)
	out.store_string(FileAccess.get_file_as_string(GoldenSaves.DIR + "v2_amber_temple.json"))
	out.close()
	assert_eq(SaveSystem.load_slot("settings_pad"), OK)
	SaveSystem.delete_slot("settings_pad")
	root = (load("res://scenes/game.tscn") as PackedScene).instantiate()
	add_child(root)
	await _frames(5)
	(root.get("hud") as ExploreHud).close_narration()
	await _frames(1)
	root.call("open_screen", "menu", 0)
	await _frames(2)
	root.get("screen").call("_show_settings", "Game")
	await _frames(3)
	await _press(JOY_BUTTON_DPAD_DOWN)   # the first press puts focus on the screen
	await _press(JOY_BUTTON_DPAD_UP)
	return root.get("screen") as Node


func _window(menu: Node) -> ScrollContainer:
	return menu.find_child("GameRows", true, false) as ScrollContainer


## The page's rows (the choice buttons and the respec box), top to bottom as laid out with the window at its top.
func _rows(menu: Node) -> Array[Control]:
	var out: Array[Control] = []
	for n in _window(menu).find_children("*", "Control", true, false):
		var c := n as Control
		if (c is Button and (c as Button).text.begins_with("‹")) or c is CheckBox:
			out.append(c)
	out.sort_custom(func(a: Control, b: Control) -> bool: return a.position.y + (a.get_parent() as Control).position.y < b.position.y + (b.get_parent() as Control).position.y)
	return out


func _named(menu: Node, text: String) -> Button:
	for n in menu.find_children("*", "Button", true, false):
		if (n as Button).text == text and (n as Button).is_visible_in_tree():
			return n as Button
	return null


func _focus() -> Control:
	return get_viewport().gui_get_focus_owner()


## Every choice on the screen reached from the one with focus by the pad's own neighbour rule (as test_pad_screens walks it).
func _unreached(scope: Node) -> Array[String]:
	var list := PadNav.choices(scope)
	var start := nav.focus_in(scope)
	assert_true(start != null, "focus is on the screen")
	var seen := {start: true}
	var queue: Array[Control] = [start]
	while not queue.is_empty():
		var c: Control = queue.pop_back()
		for d: Vector2i in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
			if d.y == 0 and (c is Range or c.has_method(&"pad_adjust") or c.has_meta(&"pad_adjust")):
				continue
			var n := PadNav.neighbour(c, d, list)
			if n != null and not seen.has(n):
				seen[n] = true
				queue.append(n)
	var missed: Array[String] = []
	for c in list:
		if not seen.has(c):
			missed.append(c.name)
	return missed


func test_every_choice_is_in_reach_whichever_way_the_window_is_scrolled() -> void:
	var menu := await _game_page()
	var scroll := _window(menu)
	assert_true(scroll != null and scroll.has_meta(&"pad_clip"), "the window is one the pad treats as clipping")
	var end := int(scroll.get_v_scroll_bar().max_value)
	assert_true(end > 0, "there is something to scroll")
	for at: int in [0, roundi(end * 0.5), end]:
		scroll.scroll_vertical = at
		await _frames(2)
		nav.focus_on(_named(menu, "Back"))
		var missed := _unreached(nav.scope_now())
		assert_true(missed.is_empty(), "scrolled to %d of %d: out of the D-pad's reach: %s" % [at, end, ", ".join(missed)])


func test_the_tabs_are_not_stepped_past_by_rows_scrolled_over_them() -> void:
	var menu := await _game_page()
	var scroll := _window(menu)
	scroll.scroll_vertical = int(scroll.get_v_scroll_bar().max_value)
	await _frames(2)
	var list := PadNav.choices(nav.scope_now())
	var game := menu.find_child("PageGame", true, false) as Control
	var display := menu.find_child("PageDisplay", true, false) as Control
	var keys := menu.find_child("PageKeys", true, false) as Control
	assert_eq(PadNav.neighbour(game, Vector2i.RIGHT, list), display, "Game, then Display")
	assert_eq(PadNav.neighbour(display, Vector2i.RIGHT, list), keys, "Display, then Keys")
	assert_eq(PadNav.neighbour(keys, Vector2i.LEFT, list), display, "and back")
	var below := PadNav.neighbour(keys, Vector2i.DOWN, list)
	assert_true(below != null and scroll.is_ancestor_of(below), "down from a tab is a row in the window")
	assert_true(PadNav.rect_of(scroll).intersects(PadNav.rect_of(below)), "one that can be seen")


func test_down_the_rows_scrolls_each_into_view_and_reaches_back() -> void:
	var menu := await _game_page()
	var scroll := _window(menu)
	var rows := _rows(menu)
	assert_true(rows.size() >= 8, "the page's rows (%d)" % rows.size())
	scroll.scroll_vertical = 0
	await _frames(2)
	nav.focus_on(rows[0])
	await _frames(1)
	for i in range(1, rows.size()):
		await _press(JOY_BUTTON_DPAD_DOWN)
		await _frames(1)
		assert_eq(_focus(), rows[i], "down to row %d (%s)" % [i, rows[i].name])
		var seen := PadNav.rect_of(scroll).intersects(PadNav.rect_of(rows[i]))
		assert_true(seen, "row %d is scrolled into view" % i)
	await _press(JOY_BUTTON_DPAD_DOWN)
	var below := _focus()
	assert_true(below is Button and (below as Button).text in ["Back", "Resume"], "past the last row: Back or Resume (%s)" % below)
	await _press(JOY_BUTTON_DPAD_UP)
	assert_eq(_focus(), rows[rows.size() - 1], "up from there: the last row again")
	for i in range(rows.size() - 2, -1, -1):
		await _press(JOY_BUTTON_DPAD_UP)
		await _frames(1)
		assert_eq(_focus(), rows[i], "up to row %d" % i)
	await _press(JOY_BUTTON_DPAD_UP)
	var tab := _focus()
	assert_true(tab != null and tab.name.begins_with("Page"), "above the first row: a page tab (%s)" % tab)


## The page with one more row than it has now (it has grown before): a row that sits below Back when the window is scrolled
## to the top used to be the D-pad's step down from Back, so the first press scrolled the window to its end and put the rows
## over the tabs. Down from Back is Resume, and Keys stays in reach.
func test_a_row_below_back_in_the_layout_is_not_a_step_down_from_back() -> void:
	var menu := await _game_page()
	var scroll := _window(menu)
	var host := _rows(menu)[0].get_parent() as Control
	var back := _named(menu, "Back")
	var resume := _named(menu, "Resume")
	scroll.scroll_vertical = 0
	await _frames(2)
	var extra := Button.new()
	extra.name = "ExtraRow"
	extra.text = "‹ Extra ›"
	extra.size = Vector2(120, 30)
	host.add_child(extra)
	# Its middle a little below Back's, between Back and Resume, as a tenth row would be.
	extra.global_position = Vector2(PadNav.rect_of(back).get_center().x - 60.0, PadNav.rect_of(back).get_center().y + 4.0)
	host.custom_minimum_size.y = maxf(host.custom_minimum_size.y, extra.position.y + 40.0)
	await _frames(2)
	scroll.scroll_vertical = 0
	await _frames(2)
	var list := PadNav.choices(nav.scope_now())
	assert_true(extra in list, "the extra row is a choice")
	assert_eq(PadNav.neighbour(back, Vector2i.DOWN, list), resume, "down from Back is Resume, not a row scrolled out of sight")
	nav.focus_on(back)
	await _press(JOY_BUTTON_DPAD_DOWN)
	assert_eq(_focus(), resume, "and so is a press of the D-pad")
	assert_eq(scroll.scroll_vertical, 0, "which leaves the window where it was")
	nav.focus_on(back)
	var missed := _unreached(nav.scope_now())
	assert_true(missed.is_empty(), "out of the D-pad's reach: %s" % ", ".join(missed))
