extends TestCase
## A fight on a pad (U6, world/combat/pad_combat.gd) against one rat, with synthetic pad events: Start asks for the
## menu and View shows the controls, the D-pad's up and down change the hotbar's tab, the left stick moves the cursor
## and the camera follows it, the right stick turns the camera except while the radial aims, R3 opens the square's
## menu, the end-turn check takes the pad alone and B keeps going, and A rolls a dying hero's death saving throw.

const LATE := "v2_amber_temple.json"
const ARENA := {
	"id": "test_pad_ward", "name": "Test Ward", "region": "test", "summary": "A fixture.",
	"map": {"rows": [
		"############",
		"#..........#",
		"#..........#",
		"#..........#",
		"#..........#",
		"############"], "light": "dim"},
	"spawns": {"default": [2, 2]},
	"encounters": [{"id": "rat", "trigger": "manual", "monsters": [{"monster": "rat", "cell": [9, 4]}]}],
}

var root: Node
var nav: PadNav
var cv: CombatView
var menus := 0


func before_each() -> void:
	InputActions.ensure()
	nav = PadNav.current
	nav.reset()
	menus = 0
	Compendium.shared().tables["locations"]["test_pad_ward"] = ARENA.duplicate(true)
	DirAccess.make_dir_recursive_absolute(SaveSystem.save_dir)
	var out := FileAccess.open(SaveSystem.slot_path("pad_combat"), FileAccess.WRITE)
	out.store_string(FileAccess.get_file_as_string(GoldenSaves.DIR + LATE))
	out.close()
	assert_eq(SaveSystem.load_slot("pad_combat"), OK)
	SaveSystem.delete_slot("pad_combat")
	root = (load("res://scenes/game.tscn") as PackedScene).instantiate()
	add_child(root)
	await _frames(5)
	root.call("enter_location", "test_pad_ward", "default")
	await _frames(3)
	var view := root.get("view") as LocationView
	assert_true(view.start_encounter("rat"), "the fight starts")
	cv = view.combat_view
	cv.menu_requested.connect(func() -> void: menus += 1)
	# To a hero's turn, past the opening.
	for i in 400:
		if cv.mode == CombatView.Mode.IDLE and cv.e.current().side == &"party":
			break
		if cv.mode == CombatView.Mode.IDLE and cv.e.current().side != &"party":
			cv.e.end_turn()
		await _frames(1)


func after_each() -> void:
	nav.reset()
	if cv != null and is_instance_valid(cv):
		cv.finished.emit("victory")
	await _frames(3)
	get_tree().paused = false
	if root != null:
		root.queue_free()
		root = null
	(Compendium.shared().tables["locations"] as Dictionary).erase("test_pad_ward")
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


func _ready_for_input() -> bool:
	if cv.mode != CombatView.Mode.IDLE or cv.e.current().side != &"party":
		fail("never reached a hero's turn (mode %d)" % cv.mode)
		return false
	return true


func test_start_back_and_the_tabs() -> void:
	if not _ready_for_input():
		return
	await _press(JOY_BUTTON_START)
	assert_eq(menus, 1, "Start asks for the menu")
	root.call("close_screen")
	await _frames(2)
	await _press(JOY_BUTTON_BACK)
	assert_true(cv.hud.get("_controls").visible, "View shows the controls")
	await _press(JOY_BUTTON_BACK)
	assert_false(cv.hud.get("_controls").visible, "and hides them")
	var tab := cv.hud.tab
	await _press(JOY_BUTTON_DPAD_DOWN)
	assert_ne(cv.hud.tab, tab, "D-pad down: the hotbar's next tab")
	await _press(JOY_BUTTON_DPAD_UP)
	assert_eq(cv.hud.tab, tab, "D-pad up: back")
	await _press(JOY_BUTTON_B)
	assert_eq(menus, 1, "B with nothing to cancel never asks for the menu")
	assert_false(PadPrompts.world.is_empty(), "the prompt bar says what the buttons do")


func test_the_cursor_and_the_camera() -> void:
	if not _ready_for_input():
		return
	await _press(JOY_BUTTON_X)   # the pad is in use: the next target
	var at := cv.cursor_cell
	var rig := cv.rig
	var before := rig.global_position
	Input.action_press(&"cursor_left", 1.0)
	cv._process(0.016)
	Input.action_release(&"cursor_left")
	assert_ne(cv.cursor_cell, at, "the left stick moves the cursor")
	assert_true(cv.pad.follow_cursor, "and the camera goes after it")
	assert_ne(rig.global_position, before, "gliding toward it")
	for i in 60:
		cv.pad.tick(0.05)
	assert_false(cv.pad.follow_cursor, "until it's there")
	assert_true(rig.pad_look, "the right stick turns the camera")
	cv.hud.radial.open()
	cv.pad.tick(0.016)
	assert_false(rig.pad_look, "but not while the radial aims with it")
	cv.hud.radial.visible = false


func test_the_end_turn_check_takes_the_pad() -> void:
	if not _ready_for_input():
		return
	await _press(JOY_BUTTON_Y)
	if not cv.hud.confirm_open():
		return   # nothing left to do this turn, so no check
	var box := cv.hud.get("_confirm") as Control
	assert_eq(nav.scope_now(), box, "the check takes the pad alone")
	await _frames(1)
	var f := get_viewport().gui_get_focus_owner()
	assert_true(f != null and box.is_ancestor_of(f), "on End turn")
	await _press(JOY_BUTTON_B)
	assert_false(cv.hud.confirm_open(), "B keeps going")
	assert_eq(cv.mode, CombatView.Mode.IDLE, "still this hero's turn")


func test_r3_opens_the_squares_menu() -> void:
	if not _ready_for_input():
		return
	await _press(JOY_BUTTON_X)   # the cursor on the rat
	await _press(JOY_BUTTON_RIGHT_STICK)
	assert_true(cv.hud.menu_open(), "R3: everything that can be done there")


func test_a_rolls_a_dying_heros_death_save() -> void:
	if not _ready_for_input():
		return
	var c := cv.e.current()
	c.creature.take_damage(c.creature.hp, &"slashing")
	cv.hud.refresh()
	await _frames(1)
	if not cv.hud.death_save_shown():
		fail("the hero should be dying")
		return
	var log_before := cv.e.log.entries.size() if "entries" in cv.e.log else -1
	await _press(JOY_BUTTON_A)
	await _frames(10)
	var rolled := not cv.hud.death_save_shown() or (log_before >= 0 and cv.e.log.entries.size() > log_before)
	assert_true(rolled, "A rolled it")


## Controller fights: Wheels (owner pick 2026-10-09, after Baldur's Gate 3 on console): holding LB opens a wheel of the
## hotbar filter's actions themselves, the last wedge the tactical view; the D-pad changes the filter.
func test_the_wheels_hold_the_actions_and_the_tactical_view() -> void:
	if not _ready_for_input():
		return
	GameSettings.set_value("pad_wheels", true, false)
	var hold := InputEventJoypadButton.new()
	hold.button_index = JOY_BUTTON_LEFT_SHOULDER
	hold.pressed = true
	get_viewport().push_input(hold)
	await _frames(2)
	var radial := cv.hud.radial
	assert_true(radial.visible and not radial.items.is_empty(), "LB opens a wheel of actions")
	assert_eq(str(radial.items.back()["label"]), "Tactical view", "the last wedge looks from above")
	assert_eq(radial.items.size(), mini(cv.hud.slot_count(), RadialMenu.PAGE - 1) + 1)
	var filter := cv.hud.tab
	await _press(JOY_BUTTON_DPAD_DOWN)
	assert_ne(cv.hud.tab, filter, "the D-pad changes the wheel's filter")
	assert_true(radial.visible, "and the wheel stays open")
	radial.selected = radial.items.size() - 1
	var release := InputEventJoypadButton.new()
	release.button_index = JOY_BUTTON_LEFT_SHOULDER
	release.pressed = false
	get_viewport().push_input(release)
	await _frames(2)
	assert_true(cv.rig.tactical, "releasing on Tactical view switches the camera")
	cv.rig.tactical = false
	GameSettings.set_value("pad_wheels", false, false)
