extends TestCase
## The pause menu's Settings pages (docs/plans/ui_polish.md): each choice flips with a click and is kept in the
## player's settings file (the test runner's own here), the look switch publishes to the cel shaders, a fast fight
## halves the pace, Escape goes back to the menu, the Display page sets graphics and the interface and text sizes
## (U4, W17), and the Keys page takes a new key (U5).

const SCENE := preload("res://scenes/combat/arena.tscn")

var arena: Node3D


func before_each() -> void:
	Dice.reseed(3)
	arena = SCENE.instantiate() as Node3D
	add_child(arena)
	await _frames(5)


func after_each() -> void:
	get_tree().paused = false
	GameSettings.set_fast_combat(false)
	GameSettings.set_narration_stays(false)
	GameSettings.set_ui_scale(1.0)
	GameSettings.set_text_scale(1.0)
	Graphics.set_preset(Graphics.DEFAULT_PRESET)
	InputActions.reset()
	Look.set_style(Look.DEFAULT_STYLE)
	arena.queue_free()


func _frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame


func _menu(page: String = "Game") -> PauseMenu:
	(arena.get("view") as CombatView).menu_requested.emit()
	await _frames(1)
	var menu := arena.get("screen") as PauseMenu
	menu.call("_show_settings", page)
	await _frames(1)
	return menu


func _choice(menu: PauseMenu, row: String) -> Button:
	return menu.find_child(row, true, false) as Button


func test_choices_flip_and_are_kept() -> void:
	var menu := await _menu()
	assert_false(GameSettings.fast_combat())
	_choice(menu, "Fights").pressed.emit()
	assert_true(GameSettings.fast_combat(), "Fights: Fast")
	assert_eq(GameSettings.combat_pace(), GameSettings.FAST_PACE)
	assert_true(_choice(menu, "Fights").text.contains("Fast"))
	_choice(menu, "Narration").pressed.emit()
	assert_true(GameSettings.narration_stays())
	var cfg := ConfigFile.new()
	assert_eq(cfg.load(GameSettings.path), OK, "written to the settings file")
	assert_eq(bool(cfg.get_value(GameSettings.SECTION, "fast_combat", false)), true)
	assert_ne(GameSettings.path, "user://settings.cfg", "tests never touch the player's own settings")


func test_the_look_switch_reaches_the_shaders() -> void:
	var menu := await _menu()
	Look.set_style("classic")
	menu.call("_set_look", "modern")
	assert_true(Look.modern())
	assert_eq(str(GameSettings.value("look", "")), "modern", "kept for next time")
	# Headless runs have no renderer to read the global back from; with one, the cel shaders now light softly.
	var soft: Variant = RenderingServer.global_shader_parameter_get(&"look_soft")
	if soft != null:
		assert_eq(float(soft), 1.0)


func test_escape_goes_back_to_the_menu() -> void:
	var menu := await _menu()
	var ev := InputEventAction.new()
	ev.action = &"combat_cancel"
	ev.pressed = true
	menu.call("_unhandled_input", ev)
	await _frames(1)
	assert_true(arena.get("screen") is PauseMenu, "still open")
	assert_true(menu.find_child("Fights", true, false) == null, "back on the menu, not the settings")


func test_the_pages_hold_their_rows() -> void:
	var menu := await _menu()
	for row: String in ["Fights", "Narration"]:
		assert_true(_choice(menu, row) != null, "Game: %s" % row)
	assert_true(_choice(menu, "Look") == null, "the look is on Display")
	(menu.find_child("PageDisplay", true, false) as Button).pressed.emit()
	await _frames(1)
	for row: String in ["Look", "Graphics", "Window", "Depth blur", "Interface", "Text"]:
		assert_true(_choice(menu, row) != null, "Display: %s" % row)
	(menu.find_child("PageKeys", true, false) as Button).pressed.emit()
	await _frames(1)
	assert_true(menu.find_child("open_journal", true, false) != null, "Keys lists the journal")


func test_graphics_and_sizes_are_kept() -> void:
	var menu := await _menu("Display")
	assert_eq(Graphics.preset(), "high")
	_choice(menu, "Graphics").pressed.emit()   # High steps round to Low
	assert_eq(Graphics.preset(), "low")
	_choice(menu, "Interface").pressed.emit()
	assert_eq(GameSettings.ui_scale(), 1.1, "100% steps to 110%")
	_choice(menu, "Text").pressed.emit()
	assert_eq(GameSettings.text_scale(), GameSettings.TEXT_SCALES[1])
	assert_eq(UiScale.text(20), roundi(20 * GameSettings.TEXT_SCALES[1]), "reading text grows with it")
	var cfg := ConfigFile.new()
	assert_eq(cfg.load(GameSettings.path), OK)
	assert_eq(str(cfg.get_value(GameSettings.SECTION, "graphics", "")), "low")
	assert_eq(float(cfg.get_value(GameSettings.SECTION, "ui_scale", 0.0)), 1.1)


func test_the_left_arrow_steps_back() -> void:
	var menu := await _menu("Display")
	var b := _choice(menu, "Interface")
	var click := InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_LEFT
	click.pressed = true
	click.position = Vector2(4, b.size.y / 2.0)
	b.gui_input.emit(click)
	b.pressed.emit()
	assert_eq(GameSettings.ui_scale(), 0.85, "100% steps back to 85%")
	assert_true(b.text.contains("85%"))


func test_the_interface_size_applies_only_to_the_play_screen() -> void:
	GameSettings.set_ui_scale(1.2)
	var player := Node.new()
	add_child(player)
	UiScale.playing(player)
	assert_true(is_equal_approx(get_tree().root.content_scale_factor, 1.2), "playing: the player's size")
	var screen := CanvasLayer.new()
	add_child(screen)
	UiScale.full_screen(screen)
	assert_eq(get_tree().root.content_scale_factor, 1.0, "a full screen keeps its design size")
	screen.free()
	assert_true(is_equal_approx(get_tree().root.content_scale_factor, 1.2), "and the play screen gets it back when it closes")
	player.free()
	assert_eq(get_tree().root.content_scale_factor, 1.0, "the title and everything else: 1.0")


func test_a_new_key_on_the_keys_page() -> void:
	var menu := await _menu("Keys")
	var page := menu.find_children("*", "KeysPage", true, false)[0] as KeysPage
	var row := page.find_child("open_journal", true, false)
	(row.find_child("Key", true, false) as Button).pressed.emit()
	assert_true(page.waiting(), "waiting for a key")
	# Escape while waiting keeps the key and the page open.
	page.press(KEY_ESCAPE)
	assert_eq(InputActions.keys(&"open_journal")[0], KEY_J)
	assert_true(arena.get("screen") is PauseMenu, "Escape didn't close the menu")
	(row.find_child("Key", true, false) as Button).pressed.emit()
	page.press(KEY_C)
	assert_eq(InputActions.keys(&"open_journal")[0], KEY_C)
	assert_eq(InputActions.keys(&"open_sheet")[0], KEY_J, "swapped")
	assert_eq((row.find_child("Key", true, false) as Button).text, "C", "the cap shows it")
	var note := menu.get("_note") as Label
	assert_true(note.text.contains("Character"), "the note says what moved: %s" % note.text)
	(menu.find_child("PageKeys", true, false) as Button).pressed.emit()
	await _frames(1)
