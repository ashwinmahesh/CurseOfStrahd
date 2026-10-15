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


## The turn order's portraits (owner, 2026-10-12): a click on one sends the camera gliding over to that creature; on a
## pad, X while the radial is held steps the camera along the order.
func test_the_turn_order_points_the_camera() -> void:
	if not _ready_for_input():
		return
	var rat: Combatant = null
	for c in cv.e.combatants:
		if c.side == &"enemy":
			rat = c
	var rat_tok := cv.tokens[rat.id] as CombatToken
	var card: Control = null
	for n: Node in (cv.hud.get("_strip") as Node).get_children():
		if n is Control and (n as Control).tooltip_text == "Click to look at %s" % rat.name():
			card = n as Control
	assert_true(card != null, "the rat's portrait says what a click does")
	var click := InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_LEFT
	click.pressed = true
	card.gui_input.emit(click)
	assert_eq(cv.rig.follow, rat_tok, "a click on its portrait: the camera goes to the rat")
	var before := cv.rig.global_position.distance_to(rat_tok.global_position)
	await _frames(6)
	var after := cv.rig.global_position.distance_to(rat_tok.global_position)
	assert_true(after < before and (before < 0.1 or after > 0.01), "gliding there, not jumping (%.2f, then %.2f)" % [before, after])
	cv.hud.radial.open()
	await _press(JOY_BUTTON_X)
	assert_true(cv.rig.follow != rat_tok and cv.rig.follow != null, "X with the radial held: the next in the turn order")
	assert_eq((cv.rig.follow as CombatToken).combatant, cv.e.order[(cv.e.order.find(rat) + 1) % cv.e.order.size()])
	# The order on the HUD rings who the camera went to (and scrolls to them, when it is long: test_turn_strip), and the
	# right bumper with the radial held looks back along it, to the rat again.
	var strip := cv.hud.get("_strip_view") as TurnStrip
	assert_eq(strip.looked, (cv.rig.follow as CombatToken).combatant.id, "the turn order rings the creature looked at")
	await _press(JOY_BUTTON_RIGHT_SHOULDER)
	assert_eq(cv.rig.follow, rat_tok, "RB with the radial held: back along the turn order")
	assert_eq(strip.looked, rat.id, "and the ring goes back with it")
	cv.hud.radial.visible = false


## Hiding the action bar (owner, 2026-10-12): H (or LB + Y, or its button) shrinks it to a slim strip, it stays so from
## refresh to refresh, and it comes back for a prompt or a step through the slots. Y while the radial is held never
## ends the turn.
func test_the_action_bar_hides_and_comes_back() -> void:
	if not _ready_for_input():
		return
	var hud := cv.hud
	CombatHud.actions_hidden = false
	hud.toggle_actions()
	hud.toggle_actions()
	var tall := (hud.get("_hot_panel") as Control).size.y
	var key := InputEventKey.new()
	key.physical_keycode = KEY_H
	key.keycode = KEY_H
	key.pressed = true
	get_viewport().push_input(key)
	await _frames(2)
	assert_true(CombatHud.actions_hidden, "H hides the actions")
	assert_false((hud.get("_hot_body") as Control).visible, "the slots are gone")
	assert_true((hud.get("_hot_panel") as Control).size.y < tall * 0.6, "down to a slim strip (%.0f of %.0f)" % [(hud.get("_hot_panel") as Control).size.y, tall])
	assert_eq(roundi((hud.get("_hot_panel") as Control).size.x), 1160, "the strip keeps the bar's width (nothing spills out)")
	hud.refresh()
	assert_true(CombatHud.actions_hidden, "and it stays hidden through a refresh (a new turn)")
	var who := cv.e.current()
	hud.radial.open()
	await _press(JOY_BUTTON_Y)
	assert_false(CombatHud.actions_hidden, "LB + Y shows them again")
	assert_eq(cv.e.current(), who, "without ending the turn")
	assert_false(hud.confirm_open(), "or asking to")
	hud.radial.visible = false
	hud.toggle_actions()
	hud.move_focus(1)
	assert_false(CombatHud.actions_hidden, "a step through the slots brings them back")
	hud.toggle_actions()
	var req := ReactionRequest.new("opportunity_attack", who.id, who.id)
	req.title = "A test prompt?"
	hud.show_prompt(req)
	assert_false(CombatHud.actions_hidden, "and so does a prompt")
	hud.hide_prompt()
	CombatHud.actions_hidden = false


## Preserve Life's prompt on a pad: the D-pad reaches each creature's slider, left and right give and take points, the
## count of what is left follows, and Heal (A) confirms.
func test_dividing_a_pool_on_the_pad() -> void:
	if not _ready_for_input():
		return
	var who := cv.e.current()
	var req := ReactionRequest.new("preserve_life", who.id, who.id)
	req.title = "Preserve Life"
	req.text = "Share 20 Hit Points."
	req.spends_reaction = false
	req.pool = 20
	req.target_choices.assign([{"id": "a", "name": "Ilse", "label": "Ilse · 4 of 40 Hit Points · up to 16", "room": 16},
		{"id": "b", "name": "Tamsin", "label": "Tamsin · 6 of 30 Hit Points · up to 9", "room": 9}])
	req.amounts = {"a": 0, "b": 0}
	var got: Array = []
	var ref: WeakRef = weakref(req)
	req.continuation = func(use: bool) -> CombatResult:
		if use:
			got.append((ref.get_ref() as ReactionRequest).amounts.duplicate())
		return CombatResult.new()
	cv.e.pending = req
	cv.mode = CombatView.Mode.PROMPT
	cv.hud.show_prompt(req)
	await _frames(2)
	var box := cv.hud.get("_prompt") as Control
	assert_eq(nav.scope_now(), box, "the prompt takes the pad alone")
	assert_eq(PadNav.choices(box).filter(func(c: Control) -> bool: return c is HSlider).size(), 2, "a slider for each creature can be reached")
	var sliders := cv.hud.get("_prompt_sliders") as Dictionary
	var on := func(id: String) -> bool: return get_viewport().gui_get_focus_owner() == sliders[id]
	for i in 6:
		if on.call("b"):
			break
		await _press(JOY_BUTTON_DPAD_UP)
	assert_true(on.call("b"), "up from Heal to Tamsin's slider (on %s)" % get_viewport().gui_get_focus_owner())
	for i in 3:
		await _press(JOY_BUTTON_DPAD_RIGHT)
	assert_eq(int(req.amounts["b"]), 3, "right gives a point at a time")
	assert_eq(req.unspent(), 17, "and the count goes down")
	assert_true((cv.hud.get("_prompt_pool") as Label).text.contains("17 of 20"), (cv.hud.get("_prompt_pool") as Label).text)
	await _press(JOY_BUTTON_DPAD_LEFT)
	assert_eq(int(req.amounts["b"]), 2, "left takes one back")
	for i in 6:
		if on.call("a"):
			break
		await _press(JOY_BUTTON_DPAD_UP)
	assert_true(on.call("a"), "up again to Ilse's slider")
	for i in 5:
		await _press(JOY_BUTTON_DPAD_RIGHT)
	assert_eq(int(req.amounts["a"]), 5)
	assert_eq(req.unspent(), 13)
	var use := cv.hud.get("_prompt_use") as Control
	use.grab_focus()
	await _press(JOY_BUTTON_A)
	await _frames(2)
	assert_eq(got.size(), 1, "A on Heal confirms")
	assert_eq(int((got[0] as Dictionary)["a"]), 5)
	assert_eq(int((got[0] as Dictionary)["b"]), 2)


## A hero's Reactions on one prompt (owner report 2026-10-12): the D-pad reaches each of them, A picks one and goes on
## to Use Reaction, and A there takes it.
func test_a_list_of_reactions_on_the_pad() -> void:
	if not _ready_for_input():
		return
	var who := cv.e.current()
	var req := cv.e.reactions.chooser(who, who.id)
	req.target_choices.assign([{"id": "now:0", "label": "Protection", "text": "The shield goes up.", "cost": "Reaction"},
		{"id": "later:sentinel", "label": "Sentinel, if the attack hits", "text": "A strike back once it hits.", "cost": "Reaction, only if it hits"}])
	req.selected_ids.assign(["now:0"])
	var picked: Array[String] = []
	var ref: WeakRef = weakref(req)
	req.continuation = func(use: bool) -> CombatResult:
		if use:
			picked.assign((ref.get_ref() as ReactionRequest).selected_ids)
		return CombatResult.new()
	cv.e.pending = req
	cv.mode = CombatView.Mode.PROMPT
	cv.hud.show_prompt(req)
	await _frames(2)
	var box := cv.hud.get("_prompt") as Control
	assert_eq(nav.scope_now(), box, "the prompt takes the pad alone")
	assert_eq(PadNav.choices(box).filter(func(c: Control) -> bool: return c is CheckButton).size(), 2, "both Reactions can be reached")
	var sentinel := func() -> bool:
		var f := get_viewport().gui_get_focus_owner()
		return f is CheckButton and (f as CheckButton).text.begins_with("Sentinel")
	for i in 4:
		if sentinel.call():
			break
		await _press(JOY_BUTTON_DPAD_UP)
	assert_true(sentinel.call(), "up from Use Reaction to Sentinel (on %s)" % get_viewport().gui_get_focus_owner())
	await _press(JOY_BUTTON_A)
	assert_eq(req.selected_ids, ["later:sentinel"] as Array[String], "A picks it")
	assert_true((cv.hud.get("_prompt_text") as Label).text.contains("A strike back"), "and its words show")
	var use := cv.hud.get("_prompt_use") as Control
	assert_eq(get_viewport().gui_get_focus_owner(), use, "and goes on to Use Reaction")
	await _press(JOY_BUTTON_A)
	await _frames(2)
	assert_eq(picked, ["later:sentinel"] as Array[String], "the picked Reaction is the one used")
