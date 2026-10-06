extends TestCase
## Two owner bugs. Escape didn't open the pause menu in the Combat Arena, so there was no way out: it now opens the
## menu (the fight waits), Escape closes it, and it opens after the fight too. And after quitting a game to the title,
## sometimes no title button answered: the menu had paused the tree in a fight and the pause outlived the scene change.
## Leaving through the menu now unpauses, and the title screen never starts paused.

const SCENE := preload("res://scenes/combat/arena.tscn")

var arena: Node3D


func before_each() -> void:
	Dice.reseed(3)
	arena = SCENE.instantiate() as Node3D
	add_child(arena)
	await _frames(5)


func after_each() -> void:
	get_tree().paused = false
	arena.queue_free()


func _frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame


func _escape() -> InputEventAction:
	var ev := InputEventAction.new()
	ev.action = &"combat_cancel"
	ev.pressed = true
	return ev


func test_escape_opens_and_closes_the_menu() -> void:
	var view := arena.get("view") as CombatView
	view.menu_requested.emit()
	await _frames(1)
	var menu := arena.get("screen") as PauseMenu
	assert_true(menu != null, "the pause menu opened")
	assert_true(get_tree().paused, "the fight waits")
	var quit := menu.find_children("*", "Button", true, false).filter(func(b: Node) -> bool: return (b as Button).text == "Quit to Title")
	assert_eq(quit.size(), 1, "a way out to the title")
	menu.call("_unhandled_input", _escape())
	await _frames(1)
	assert_true(arena.get("screen") == null, "Escape closed it")
	assert_false(get_tree().paused)


func test_escape_after_the_fight() -> void:
	var view := arena.get("view") as CombatView
	view.mode = CombatView.Mode.OVER
	arena.call("_unhandled_input", _escape())
	await _frames(1)
	assert_true(arena.get("screen") is PauseMenu, "the menu opens once the fight is over")
	arena.call("close_screen")


func test_quit_to_title_from_a_paused_fight_unpauses() -> void:
	var view := arena.get("view") as CombatView
	view.menu_requested.emit()
	await _frames(1)
	var menu := arena.get("screen") as PauseMenu
	assert_true(get_tree().paused, "the menu paused the fight")
	var went: Array[String] = []
	menu.scene_changer = func(path: String) -> void: went.append(path)
	var quit := menu.find_children("*", "Button", true, false).filter(func(b: Node) -> bool: return (b as Button).text == "Quit to Title")
	(quit[0] as Button).pressed.emit()
	assert_eq(went, [PauseMenu.TITLE_SCENE] as Array[String], "off to the title")
	assert_false(get_tree().paused, "the title won't start paused")
	arena.call("close_screen")


func test_the_title_answers_even_if_left_paused() -> void:
	get_tree().paused = true
	var title := (load("res://scenes/main_menu.tscn") as PackedScene).instantiate() as Control
	add_child(title)
	await _frames(2)
	assert_false(get_tree().paused, "the title unpauses on arrival")
	var buttons := title.find_children("*", "Button", true, false)
	assert_true(not buttons.is_empty(), "the title has its buttons")
	assert_true((buttons[0] as Button).can_process(), "and they take input")
	title.queue_free()
