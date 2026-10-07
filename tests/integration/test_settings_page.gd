extends TestCase
## The pause menu's Settings page (docs/plans/ui_polish.md): each choice flips with a click and is kept in the
## player's settings file (the test runner's own here), the look switch publishes to the cel shaders, a fast fight
## halves the pace, and Escape goes back to the menu.

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
	Look.set_style(Look.DEFAULT_STYLE)
	arena.queue_free()


func _frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame


func _menu() -> PauseMenu:
	(arena.get("view") as CombatView).menu_requested.emit()
	await _frames(1)
	var menu := arena.get("screen") as PauseMenu
	menu.call("_show_settings")
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
