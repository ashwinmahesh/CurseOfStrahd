extends TestCase
## Exploring on a pad (U6, world/exploration/pad_explore.gd), over a late party at the Amber Temple's doors, with
## synthetic pad events: the nearest thing is marked and the D-pad marks the next, A walks there and uses it, Y opens
## its menu, LB/RB change who leads, L3 sneaks, Back opens the map and Start the menu, D-pad up steps into the HUD's bar
## and B leaves it, and the right stick turns and zooms the camera.

const LATE := "v2_amber_temple.json"

var root: Node
var nav: PadNav


func before_each() -> void:
	InputActions.ensure()
	nav = PadNav.current
	nav.reset()
	DirAccess.make_dir_recursive_absolute(SaveSystem.save_dir)
	var out := FileAccess.open(SaveSystem.slot_path("pad_explore"), FileAccess.WRITE)
	out.store_string(FileAccess.get_file_as_string(GoldenSaves.DIR + LATE))
	out.close()
	assert_eq(SaveSystem.load_slot("pad_explore"), OK)
	SaveSystem.delete_slot("pad_explore")
	root = (load("res://scenes/game.tscn") as PackedScene).instantiate()
	add_child(root)
	await _frames(5)
	(root.get("hud") as ExploreHud).close_narration()
	await _frames(1)


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


func _view() -> LocationView:
	return root.get("view") as LocationView


func _pad() -> PadExplore:
	return root.get("pad") as PadExplore


## Pad mode, with the mark looked for at once.
func _start() -> void:
	await _press(JOY_BUTTON_B)
	_pad().tick(1.0)


func test_the_nearest_thing_is_marked_and_the_d_pad_marks_the_next() -> void:
	await _start()
	var things := _pad().things()
	assert_false(things.is_empty(), "something to use near the doors")
	assert_true(_pad().marked in things, "the nearest is marked")
	var at := _view().leader().cell
	for c: Vector2i in things:
		assert_true(Vector2(c - at).length() >= Vector2(_pad().marked - at).length() - 0.01, "nothing nearer")
	assert_false(PadPrompts.world.is_empty(), "the prompt bar says what the pad does")
	if things.size() > 1:
		var first := _pad().marked
		await _press(JOY_BUTTON_DPAD_RIGHT)
		assert_ne(_pad().marked, first, "D-pad right marks another")
		assert_true(_pad().chosen, "and it stays the player's choice")
		await _press(JOY_BUTTON_DPAD_LEFT)
		assert_eq(_pad().marked, first, "D-pad left goes back")


func test_a_uses_and_y_opens_its_menu() -> void:
	await _start()
	if _pad().marked.x < 0:
		fail("nothing marked")
		return
	await _press(JOY_BUTTON_Y)
	var menu := root.get("menu") as ContextMenu
	assert_true(menu.visible, "Y opens the marked thing's menu")
	menu.hide()
	await _frames(1)
	var before := _view().leader().cell
	await _press(JOY_BUTTON_A)
	await _frames(20)
	assert_true(_view().leader().cell != before or _view().busy or root.get("screen") != null or root.get("dialogue") != null
		or root.get("loot") != null or str(root.get("st").get("location")) != "", "A walks to it and uses it")


func test_shoulders_sticks_back_and_start() -> void:
	await _start()
	var st := root.get("st") as StoryState
	var lead := st.party[0]
	var order := st.party.duplicate()
	await _press(JOY_BUTTON_RIGHT_SHOULDER)
	assert_eq(st.party[0], order[1], "RB: the next leads")
	assert_eq(st.party.back(), lead, "and the one who led goes to the back")
	await _press(JOY_BUTTON_LEFT_SHOULDER)
	assert_eq(st.party, order, "LB: back as it was")
	var sneaking := _view().sneaking
	await _press(JOY_BUTTON_LEFT_STICK)
	assert_ne(_view().sneaking, sneaking, "L3 sneaks")
	await _press(JOY_BUTTON_LEFT_STICK)
	await _press(JOY_BUTTON_BACK)
	assert_true(root.get("screen") is TravelScreen, "Back opens the map")
	root.call("close_screen")
	await _frames(2)
	await _press(JOY_BUTTON_START)
	assert_true(root.get("screen") is PauseMenu, "Start opens the menu")
	root.call("close_screen")
	await _frames(2)


func test_the_hud_bar_on_a_pad() -> void:
	await _start()
	var hud := root.get("hud") as ExploreHud
	await _press(JOY_BUTTON_DPAD_UP)
	await _frames(1)
	assert_true(hud.pad_bar_on(), "D-pad up steps into the bar")
	assert_eq(nav.scope_now(), hud, "which takes the pad")
	var f := get_viewport().gui_get_focus_owner()
	assert_true(f != null and hud.is_ancestor_of(f), "on its first button")
	await _press(JOY_BUTTON_DPAD_RIGHT)
	assert_ne(get_viewport().gui_get_focus_owner(), f, "the D-pad moves along it")
	await _press(JOY_BUTTON_B)
	assert_false(hud.pad_bar_on(), "B leaves it")
	await _press(JOY_BUTTON_DPAD_UP)
	await _frames(1)
	var on := get_viewport().gui_get_focus_owner()
	assert_true(on != null and hud.is_ancestor_of(on), "back on the button it was on")
	await _press(JOY_BUTTON_A)
	await _frames(1)
	assert_true(root.get("screen") != null, "A on a button opens its screen")
	assert_false(hud.pad_bar_on(), "and the bar gives the pad back")
	root.call("close_screen")
	await _frames(2)


func test_the_right_stick_turns_and_zooms_the_camera() -> void:
	await _start()
	var rig := _view().rig
	assert_true(rig.pad_look, "exploring, the right stick is the camera's")
	var yaw := int(rig.get("_yaw_steps"))
	Input.action_press(&"look_right", 1.0)
	rig._look(0.1)
	rig._look(0.1)
	Input.action_release(&"look_right")
	rig._look(0.1)
	assert_eq(int(rig.get("_yaw_steps")), yaw + 1, "a flick turns it a quarter, once")
	var d := rig.distance
	Input.action_press(&"look_down", 1.0)
	rig._look(0.2)
	Input.action_release(&"look_down")
	assert_true(rig.distance > d or is_equal_approx(d, rig.zoom_max), "down zooms out")
	root.call("open_screen", "sheet", 0)
	await _frames(2)
	assert_false(rig.pad_look, "a screen takes the stick")
	root.call("close_screen")
	await _frames(2)


func test_the_mark_goes_when_the_mouse_comes_back() -> void:
	await _start()
	var move := InputEventMouseMotion.new()
	move.relative = Vector2(40, 0)
	get_viewport().push_input(move, true)
	await _frames(2)
	assert_eq(_pad().marked, Vector2i(-1, -1), "no mark for the mouse")
	assert_false(PadPrompts.owns(_pad()), "nor pad prompts")
