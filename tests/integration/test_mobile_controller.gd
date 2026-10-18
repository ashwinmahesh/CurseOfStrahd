extends TestCase
## Real viewport joypad events at mobile sizes. Hardware pairing remains a physical-device qualification.

var nav: PadNav
var layer: CanvasLayer
var controls: MobileControls
var lifecycle: MobileLifecycle
var old_size: Vector2i
var old_canvas: Vector2i
var old_factor: float
var prior_controls: MobileControls


func before_each() -> void:
	nav = PadNav.current
	nav.reset()
	old_size = get_tree().root.size
	old_canvas = get_tree().root.content_scale_size
	old_factor = get_tree().root.content_scale_factor
	MobileDevice.test_size = Vector2(844, 390)
	MobileDevice.test_safe = Rect2(47, 8, 750, 361)
	get_tree().root.size = Vector2i(MobileDevice.test_size)
	MobileDevice.current.configure()
	InputActions.ensure()
	layer = CanvasLayer.new()
	layer.layer = 30
	add_child(layer)
	prior_controls = UiFeel.mobile_controls
	controls = MobileControls.new()
	UiFeel.add_child(controls)
	UiFeel.mobile_controls = controls
	lifecycle = MobileLifecycle.new()
	UiFeel.add_child(lifecycle)
	await _frames()


func after_each() -> void:
	if lifecycle.interrupted:
		lifecycle.resume_play()
	lifecycle.queue_free()
	controls._close()
	controls.queue_free()
	UiFeel.mobile_controls = prior_controls
	layer.queue_free()
	for keyboard: Node in get_tree().root.find_children("*", "PadKeyboard", false, false):
		keyboard.queue_free()
	nav.reset()
	UiFeel.touch.cancel()
	await _frames()
	MobileDevice.test_size = Vector2.ZERO
	MobileDevice.test_safe = Rect2()
	get_tree().root.content_scale_size = old_canvas
	get_tree().root.content_scale_factor = old_factor
	get_tree().root.size = old_size


func _frames() -> void:
	for i in 4:
		await get_tree().process_frame


func _press(button: JoyButton, device: int = 7) -> void:
	for down: bool in [true, false]:
		var event := InputEventJoypadButton.new()
		event.device = device
		event.button_index = button
		event.pressed = down
		get_viewport().push_input(event, true)
	await _frames()


func test_mobile_tabs_bumpers_focus_and_touch_takeover() -> void:
	for size_: Vector2 in [Vector2(844, 390), Vector2(1194, 834)]:
		MobileDevice.test_size = size_
		get_tree().root.size = Vector2i(size_)
		MobileDevice.current.configure()
		var body := MobilePage.build(layer, "Inventory")
		var selected := ["Bag"]
		body.add_child(MobileUi.tabs(["Bag", "Equipment", "Stash"], "Bag", func(tab: String) -> void: selected[0] = tab))
		var count := [0]
		var item := MobileUi.button("Inspect", func() -> void: count[0] += 1)
		body.add_child(item)
		await _press(JOY_BUTTON_DPAD_DOWN)
		assert_true(nav.active())
		assert_eq(MobileDevice.current.modality, "controller")
		await _press(JOY_BUTTON_RIGHT_SHOULDER)
		assert_eq(selected[0], "Equipment")
		nav.focus_on(item)
		await _press(JOY_BUTTON_A)
		assert_eq(count[0], 1, "A activates once")
		var direction := InputEventJoypadButton.new()
		direction.button_index = JOY_BUTTON_DPAD_DOWN
		direction.pressed = true
		get_viewport().push_input(direction, true)
		for down: bool in [true, false]:
			var touch := InputEventScreenTouch.new()
			touch.position = item.get_global_rect().get_center()
			touch.pressed = down
			get_viewport().push_input(touch, true)
			await _frames()
		assert_false(nav.active())
		assert_eq(nav._dpad_held, Vector2i.ZERO, "touch cancels repeat even without a D-pad release")
		assert_eq(MobileDevice.current.modality, "touch")
		assert_eq(count[0], 2, "touch still activates once after controller input")
		direction.pressed = false
		get_viewport().push_input(direction, true)
		await _frames()
		assert_false(nav.active(), "releasing an old controller hold cannot steal the current touch session")
		assert_eq(MobileDevice.current.modality, "touch")
		MobileUi.clear(layer)
		nav.reset()
		await _frames()


func test_controller_keyboard_commits_and_cancels_without_closing_the_underlying_page() -> void:
	var closed := [0]
	var body := MobilePage.build(layer, "Name", func() -> void: closed[0] += 1)
	var field := LineEdit.new()
	field.text = "Original"
	body.add_child(field)
	await _press(JOY_BUTTON_DPAD_DOWN)
	nav.focus_on(field)
	await _press(JOY_BUTTON_A)
	var keyboard := nav.scope_now() as PadKeyboard
	assert_true(keyboard != null)
	if keyboard == null:
		return
	var page := keyboard.find_children("*", "MobilePage", true, false)[0] as MobilePage
	assert_true(page.controller_hint.text.contains("Capitals"))
	assert_true(page.controller_hint.text.contains("Done"))
	assert_false(page.controller_hint.text.contains("Tabs"), "keyboard hints describe its actual bumper action")
	await _press(JOY_BUTTON_A)
	await _press(JOY_BUTTON_START)
	assert_true(field.text.length() > "Original".length())
	var committed := field.text
	nav.focus_on(field)
	await _press(JOY_BUTTON_A)
	await _press(JOY_BUTTON_A)
	await _press(JOY_BUTTON_B)
	assert_eq(field.text, committed)
	assert_eq(closed[0], 0)


func test_active_controller_disconnect_pauses_and_requires_explicit_resume() -> void:
	var body := MobilePage.build(layer, "Inventory")
	body.add_child(MobileUi.button("Inspect", func() -> void: pass))
	await _press(JOY_BUTTON_DPAD_DOWN)
	Input.joy_connection_changed.emit(9, false)
	assert_false(lifecycle.interrupted, "another controller leaving cannot pause this player's game")
	Input.action_press(&"move_right")
	Input.joy_connection_changed.emit(7, false)
	await _frames()
	assert_true(lifecycle.interrupted)
	assert_true(get_tree().paused)
	assert_false(Input.is_action_pressed(&"move_right"), "disconnect clears held movement without dispatching commands")
	assert_false(nav.active())
	Input.joy_connection_changed.emit(7, true)
	assert_true(lifecycle.interrupted, "reconnection cannot auto-resume")
	await _press(JOY_BUTTON_DPAD_DOWN)
	assert_eq(nav.scope_now(), lifecycle.resume_layer)
	await _press(JOY_BUTTON_B)
	assert_false(lifecycle.interrupted, "the explicit resume page also accepts controller Back")
	assert_false(get_tree().paused)
	assert_true(is_instance_valid(layer))


func test_mobile_combat_controller_opens_popup_and_back_preserves_resources() -> void:
	var encounter := TestCombat.open_field()
	var actor := TestCombat.hero(encounter, "godrick_pendlebrook", Vector2i(2, 2), 5)
	TestCombat.foe(encounter, "zombie", Vector2i(6, 2))
	TestCombat.start_with(encounter, actor)
	var fight := CombatView.new()
	fight.e = encounter
	fight.catalog = ActionCatalog.new(encounter)
	fight.hud = CombatHud.new()
	layer.add_child(fight.hud)
	fight.hud.build(encounter, fight.catalog)
	fight.hud.refresh()
	var event := InputEventJoypadButton.new()
	event.button_index = JOY_BUTTON_LEFT_SHOULDER
	event.pressed = true
	assert_true(fight.pad.handle(event))
	await _frames()
	var actions := controls.drawer as MobileActions
	assert_true(actions != null)
	if actions != null:
		fight.rig = CameraRig.new()
		fight.rig.pad_look = true
		var cursor := fight.cursor_cell
		Input.action_press(&"cursor_right")
		fight._process(0.2)
		Input.action_release(&"cursor_right")
		assert_eq(fight.cursor_cell, cursor, "an open mobile page blocks continuous cursor input")
		assert_false(fight.rig.pad_look, "camera axes cannot move the world beneath a mobile page")
		fight.rig.free()
		await _press(JOY_BUTTON_DPAD_DOWN)
		assert_eq(nav.scope_now(), actions)
		await _press(JOY_BUTTON_RIGHT_SHOULDER)
		assert_eq(actions.category, ActionCatalog.FAVOURITES)
		for action in fight.catalog.actions_for(actor):
			if str(action["id"]) == "dodge":
				actions.inspect(action)
				break
		await _press(JOY_BUTTON_B)
		assert_true(is_instance_valid(controls.drawer), "B from review returns to the browser")
		assert_true(actions.selected.is_empty())
		await _press(JOY_BUTTON_B)
		assert_true(controls.drawer == null, "B from browsing closes the popup")
		assert_true(actor.action_available, "opening, reviewing and cancelling cannot spend the action")
		assert_false(fight.hud.radial.visible, "no hidden desktop radial is opened")
	fight.free()


func test_exploration_controller_opens_mobile_menu_without_desktop_hud_scope() -> void:
	var state := StoryState.new()
	state.party.append(Pregens.build("godrick_pendlebrook", 3))
	var hud := ExploreHud.new()
	layer.add_child(hud)
	hud.build(state)
	hud.pad_bar(true)
	await _press(JOY_BUTTON_DPAD_DOWN)
	assert_eq(hud.mobile.kind, "menu")
	assert_eq(nav.scope_now(), hud.mobile.sheet)
	assert_false(hud.pad_bar_on())
	await _press(JOY_BUTTON_B)
	assert_true(hud.mobile.sheet == null)
	nav.prompts._process(0.0)
	assert_false(nav.prompts.visible, "controller input does not add a persistent overlay to the quiet world")


func test_inventory_bumpers_switch_real_mobile_sections_without_changing_items() -> void:
	var state := StoryState.new()
	state.party.append(Pregens.build("godrick_pendlebrook", 3))
	state.party[0].add_item("potion_of_healing", 2)
	var inventory := InventoryScreen.new()
	add_child(inventory)
	inventory.open(self, state, 0)
	await _press(JOY_BUTTON_DPAD_DOWN)
	await _press(JOY_BUTTON_RIGHT_SHOULDER)
	assert_eq(inventory.mobile.section, "Equipment")
	await _press(JOY_BUTTON_RIGHT_SHOULDER)
	assert_eq(inventory.mobile.section, "Stash")
	await _press(JOY_BUTTON_LEFT_SHOULDER)
	assert_eq(inventory.mobile.section, "Equipment")
	assert_eq(int(state.party[0].entry_of("potion_of_healing")["qty"]), 2)
	inventory.queue_free()
	await _frames()


func close_screen() -> void:
	pass
