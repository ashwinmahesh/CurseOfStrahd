extends TestCase
## The pad's button pictures and words (U6, ui/common/pad_glyphs.gd, pad_prompts.gd): every family has a picture
## for every button the game names, events and actions map to their button, Nintendo's letters sit the other way
## round, hints switch between keys and buttons with the device, the Settings choice fixes the family, the prompt bar
## shows on a screen only while the pad is in use, and the art is credited.

var nav: PadNav


func before_each() -> void:
	InputActions.ensure()
	nav = PadNav.current
	nav.reset()
	GameSettings.set_value("pad_icons", "auto")


func after_each() -> void:
	nav.reset()
	nav.family = "xbox"
	GameSettings.set_value("pad_icons", "auto")


func _frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame


func _pad_on() -> void:
	var ev := InputEventJoypadButton.new()
	ev.button_index = JOY_BUTTON_DPAD_DOWN
	ev.pressed = true
	get_viewport().push_input(ev)
	ev = ev.duplicate() as InputEventJoypadButton
	ev.pressed = false
	get_viewport().push_input(ev)


func test_every_family_has_every_picture() -> void:
	var places := (PadGlyphs.FILES["xbox"] as Dictionary).keys()
	for fam: String in PadGlyphs.FAMILIES:
		var files := PadGlyphs.FILES[fam] as Dictionary
		assert_eq(files.keys().size(), places.size(), "%s names the same buttons as Xbox" % fam)
		for place: String in places:
			assert_true(PadGlyphs.texture(place, fam) != null, "%s has a picture for %s" % [fam, place])
			assert_ne(PadGlyphs.name_of(place, fam), "", "and a name")


func test_events_and_actions_map_to_their_button() -> void:
	var b := InputEventJoypadButton.new()
	b.button_index = JOY_BUTTON_RIGHT_SHOULDER
	assert_eq(PadGlyphs.place_of(b), "rb")
	var m := InputEventJoypadMotion.new()
	m.axis = JOY_AXIS_TRIGGER_LEFT
	assert_eq(PadGlyphs.place_of(m), "lt")
	assert_eq(PadGlyphs.place_for(&"pad_context"), "x")
	assert_eq(PadGlyphs.place_for(&"combat_end_turn"), "y")
	assert_eq(PadGlyphs.place_for(&"ui_cancel"), "b")
	assert_eq(PadGlyphs.place_for(&"open_journal"), "", "a keyboard-only command has none")


func test_nintendo_letters_sit_the_other_way_round() -> void:
	assert_eq(PadGlyphs.name_of("a", "nintendo"), "B", "the bottom button")
	assert_eq(PadGlyphs.name_of("b", "nintendo"), "A")
	assert_eq(PadGlyphs.name_of("a", "playstation"), "Cross")
	assert_eq(PadGlyphs.name_of("a", "xbox"), "A")


func test_hints_switch_with_the_device() -> void:
	var l := Label.new()
	add_child(l)
	PadGlyphs.hint(l, "Esc: close", "{b}: close")
	assert_eq(l.text, "Esc: close", "keys while the keyboard is in use")
	_pad_on()
	assert_eq(l.text, "B: close", "the pad's button once it's used")
	GameSettings.set_value("pad_icons", "playstation")
	PadGlyphs.refresh_hints()
	assert_eq(l.text, "Circle: close", "Settings' family")
	var key := InputEventKey.new()
	key.physical_keycode = KEY_A
	key.pressed = true
	get_viewport().push_input(key)
	assert_eq(l.text, "Esc: close", "back to keys with a key press")
	l.free()
	PadGlyphs.refresh_hints()   # a freed label is just dropped


func test_the_family_follows_settings_else_the_pad() -> void:
	nav.family = "nintendo"
	assert_eq(PadGlyphs.family(), "nintendo", "the pad in use")
	GameSettings.set_value("pad_icons", "xbox")
	assert_eq(PadGlyphs.family(), "xbox", "unless Settings fixes one")


func test_the_prompt_bar_shows_on_a_screen_with_the_pad() -> void:
	var screen := CanvasLayer.new()
	screen.layer = 30
	add_child(screen)
	var tabs := TabContainer.new()
	tabs.position = Vector2(300, 200)
	tabs.size = Vector2(400, 300)
	for t: String in ["One", "Two"]:
		var b := Button.new()
		b.name = t
		b.text = t
		tabs.add_child(b)
	screen.add_child(tabs)
	await _frames(2)
	assert_false(nav.prompts.visible, "hidden while the mouse is in use")
	_pad_on()
	await _frames(2)
	assert_true(nav.prompts.visible, "shown once the pad is used on a screen")
	var shown := PadPrompts.prompts_for(screen, get_viewport().gui_get_focus_owner())
	var places: Array[String] = []
	for p: Array in shown:
		places.append(str(p[0]))
	assert_true("a" in places and "b" in places, "choose and back")
	assert_true("lb+rb" in places, "tabs, since the screen has some")
	assert_false("lt+rt" in places, "no characters on this one")
	screen.queue_free()
	await _frames(2)
	assert_false(nav.prompts.visible, "gone with the screen")


func test_the_art_is_credited() -> void:
	assert_true(FileAccess.file_exists(PadGlyphs.DIR + "License.txt"), "the pack's licence is kept beside it")
	assert_true(FileAccess.get_file_as_string("res://art/credits.json").contains("Input Prompts by Kenney"))
	assert_true(FileAccess.get_file_as_string("res://docs/assets/LICENSES.md").contains("kenney_input_prompts"))


func test_settings_rows_turn_with_the_pad() -> void:
	var st := StoryState.new()
	st.party.append(TestChars.pregen("ilse_varga", 1))
	var menu := PauseMenu.new()
	add_child(menu)
	menu.open(self, st, 0)
	await _frames(1)   # the menu's own focus lands before the page changes
	menu.call("_show_settings", "Game")
	await _frames(2)
	var row := menu.find_child("Button icons", true, false) as Button
	assert_true(row != null, "the Game page has a Button icons row")
	if row != null:
		(row.get_meta(&"pad_adjust") as Callable).call(1)
		assert_eq(str(GameSettings.value("pad_icons", "")), "xbox", "right steps to the next family")
		(row.get_meta(&"pad_adjust") as Callable).call(-1)
		(row.get_meta(&"pad_adjust") as Callable).call(-1)
		assert_eq(str(GameSettings.value("pad_icons", "")), "nintendo", "left wraps round")
	menu.call("_show_menu")
	await _frames(1)
	var slider := menu.find_child("Music", true, false)
	assert_true(slider != null and slider.has_method(&"pad_adjust"), "the volume sliders step with the pad")
	menu.queue_free()
	await _frames(1)


func close_screen() -> void:
	pass
