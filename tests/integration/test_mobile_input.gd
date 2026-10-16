extends TestCase
## End-to-end raw touch events through the real viewport and shared router, at device point sizes.

var root: CanvasLayer
var old_size: Vector2i
var old_canvas: Vector2i
var old_factor: float


func before_each() -> void:
	old_size = get_tree().root.size
	old_canvas = get_tree().root.content_scale_size
	old_factor = get_tree().root.content_scale_factor
	MobileDevice.test_size = Vector2(844, 390)
	MobileDevice.test_safe = Rect2(47, 8, 750, 361)
	get_tree().root.size = Vector2i(MobileDevice.test_size)
	MobileDevice.current.configure()
	root = CanvasLayer.new()
	root.layer = 40
	add_child(root)


func after_each() -> void:
	UiFeel.touch.cancel()
	root.queue_free()
	MobileDevice.test_keyboard_height = 0.0
	MobileDevice.test_size = Vector2.ZERO
	MobileDevice.test_safe = Rect2()
	get_tree().root.content_scale_size = old_canvas
	get_tree().root.content_scale_factor = old_factor
	get_tree().root.size = old_size


func _frames() -> void:
	for i in 3:
		await get_tree().process_frame


func _touch(at: Vector2, down: bool, canceled: bool = false) -> void:
	var event := InputEventScreenTouch.new()
	event.position = at
	event.pressed = down
	event.canceled = canceled
	get_tree().root.push_input(event, true)


func test_iphone_and_ipad_buttons_activate_once_after_a_tap_not_a_drag() -> void:
	for size_: Vector2 in [Vector2(844, 390), Vector2(1194, 834)]:
		MobileDevice.test_size = size_
		MobileDevice.test_safe = Rect2(Vector2(47, 8), size_ - Vector2(94, 29))
		get_tree().root.size = Vector2i(size_)
		MobileDevice.current.configure()
		var count := [0]
		var button := UiKit.button("Tap once", func() -> void: count[0] = int(count[0]) + 1)
		button.position = Vector2(100, 100)
		button.size = Vector2(180, 44)
		root.add_child(button)
		await _frames()
		var at := button.get_global_rect().get_center()
		_touch(at, true)
		await _frames()
		assert_eq(int(count[0]), 0, "press alone cannot commit")
		_touch(at, false)
		await _frames()
		assert_eq(int(count[0]), 1, "one touch produces one activation")
		_touch(at, true)
		await _frames()
		var drag := InputEventScreenDrag.new()
		drag.position = at + Vector2(0, 50)
		drag.relative = Vector2(0, 50)
		get_tree().root.push_input(drag, true)
		_touch(at, false)
		await _frames()
		assert_eq(int(count[0]), 1, "dragging back onto a button does not click")
		button.queue_free()
		await _frames()


func test_modal_change_cancels_the_old_contact() -> void:
	var count := [0]
	var button := UiKit.button("Old screen", func() -> void: count[0] = int(count[0]) + 1)
	button.position = Vector2(100, 100)
	root.add_child(button)
	await _frames()
	var at := button.get_global_rect().get_center()
	_touch(at, true)
	await _frames()
	button.hide()
	_touch(at, false)
	await _frames()
	assert_eq(int(count[0]), 0)


func test_inventory_touch_opens_details_without_using_the_item_and_back_preserves_search() -> void:
	var state := StoryState.new()
	state.party.append(Pregens.build("godrick_pendlebrook", 3))
	state.party[0].add_item("potion_of_healing", 3)
	var inventory := InventoryScreen.new()
	add_child(inventory)
	inventory.open(self, state, 0)
	inventory.search = "potion"
	inventory._draw()
	await _frames()
	var entry := state.party[0].entry_of("potion_of_healing")
	var quantity := int(entry["qty"])
	var row := inventory._grid.get_child(0) as Control
	var at := row.get_global_rect().get_center()
	_touch(at, true)
	await _frames()
	_touch(at, false)
	await _frames()
	assert_true(inventory.mobile.detail, "a raw touch opens the item's mobile detail page")
	assert_eq(int(entry["qty"]), quantity, "inspection never drinks or transfers an item")
	inventory.mobile.back()
	await _frames()
	assert_false(inventory.mobile.detail)
	assert_eq(inventory.search, "potion", "Back preserves the bag filter")
	assert_eq(inventory.shown_ids(), ["potion_of_healing"])
	inventory.queue_free()
	await _frames()


func test_action_review_requires_commit_and_rechecks_resources() -> void:
	var encounter := TestCombat.open_field()
	var actor := TestCombat.hero(encounter, "ilse_varga", Vector2i(2, 2), 3)
	TestCombat.foe(encounter, "zombie", Vector2i(6, 2))
	TestCombat.start_with(encounter, actor)
	var catalog := ActionCatalog.new(encounter)
	var panel := MobileActions.new()
	add_child(panel)
	panel.open(catalog, actor)
	var emitted: Array[Dictionary] = []
	panel.chosen.connect(func(action: Dictionary, _level: int) -> void: emitted.append(action))
	var dodge := {}
	for action in catalog.actions_for(actor):
		if str(action["id"]) == "dodge":
			dodge = action
	assert_false(dodge.is_empty())
	panel.inspect(dodge)
	await _frames()
	assert_true(emitted.is_empty(), "opening an immediate action only inspects it")
	panel.back()
	assert_true(emitted.is_empty(), "Back cancels review without a command")
	panel.inspect(dodge)
	# Another command spends the action while this review is open.
	actor.action_available = false
	panel.commit()
	assert_true(emitted.is_empty(), "stale legality cannot authorize a spent action")
	actor.action_available = true
	panel.inspect(dodge)
	panel.commit()
	panel.commit()
	assert_eq(emitted.size(), 1, "explicit commitment emits once even if tapped twice")
	panel.queue_free()
	await _frames()


func test_interruption_discards_already_queued_touch_events() -> void:
	var count := [0]
	var control := UiKit.button("Interrupted", func() -> void: count[0] = int(count[0]) + 1)
	control.position = Vector2(100, 100)
	root.add_child(control)
	await _frames()
	var at := control.get_global_rect().get_center()
	_touch(at, true)
	_touch(at, false)
	UiFeel.touch.cancel()
	await _frames()
	assert_eq(int(count[0]), 0, "deferred events from the old screen or focus epoch cannot activate a new screen")


func test_mobile_reaction_only_commits_after_valid_selection_once() -> void:
	var encounter := TestCombat.open_field()
	var actor := TestCombat.hero(encounter, "godrick_pendlebrook", Vector2i(2, 2), 5)
	TestCombat.foe(encounter, "zombie", Vector2i(6, 2))
	TestCombat.start_with(encounter, actor)
	var hud := CombatHud.new()
	root.add_child(hud)
	hud.build(encounter, ActionCatalog.new(encounter))
	hud.refresh()
	var answers: Array = []
	hud.reaction_answered.connect(func(use: bool, rule: String) -> void: answers.append([use, rule]))
	var req := ReactionRequest.new("shield", actor.id, "foe")
	req.title = "Choose a target"
	req.min_targets = 1
	req.max_targets = 1
	req.target_choices = [{"id": actor.id, "label": actor.name()}]
	hud.show_prompt(req)
	await _frames()
	hud.answer_prompt(true)
	assert_true(answers.is_empty(), "invalid selection cannot commit")
	var check := hud._prompt_targets.get_child(0) as CheckButton
	(hud._prompt_targets.get_parent() as ScrollContainer).ensure_control_visible(check)
	hud.mobile.page.scroll.ensure_control_visible(hud._prompt_targets.get_parent() as Control)
	await _frames()
	var at := check.get_global_rect().get_center()
	_touch(at, true)
	await _frames()
	_touch(at, false)
	await _frames()
	assert_eq(req.selected_ids.size(), 1)
	assert_true(answers.is_empty(), "selection itself spends no reaction")
	at = hud._prompt_use.get_global_rect().get_center()
	_touch(at, true)
	await _frames()
	_touch(at, false)
	await _frames()
	assert_eq(answers.size(), 1)
	assert_eq(answers[0], [true, "ask"])
	hud.answer_prompt(true)
	assert_eq(answers.size(), 1, "duplicate confirmation cannot spend twice")
	assert_false(hud.prompt_open())
	assert_true(hud.mobile.sheet == null)


func test_mobile_option_picker_uses_touch_and_keeps_disabled_options_disabled() -> void:
	var option := OptionButton.new()
	option.position = Vector2(100, 100)
	option.size = Vector2(240, 48)
	option.add_item("First")
	option.add_item("Second")
	option.add_item("Unavailable")
	option.set_item_disabled(2, true)
	root.add_child(option)
	var chosen: Array[int] = []
	option.item_selected.connect(func(i: int) -> void: chosen.append(i))
	await _frames()
	var at := option.get_global_rect().get_center()
	_touch(at, true)
	await _frames()
	_touch(at, false)
	await _frames()
	assert_true(UiFeel.touch.selection_sheet != null)
	var second: Button
	for node in UiFeel.touch.selection_sheet.find_children("*", "Button", true, false):
		var button := node as Button
		if button.text == "Second":
			second = button
		if button.text == "Unavailable":
			assert_true(button.disabled)
	assert_true(second != null)
	at = second.get_global_rect().get_center()
	_touch(at, true)
	await _frames()
	_touch(at, false)
	await _frames()
	assert_eq(option.selected, 1)
	assert_eq(chosen.size(), 1)
	assert_true(UiFeel.touch.selection_sheet == null)


func test_accessibility_only_activates_current_visible_enabled_controls() -> void:
	var body := MobilePage.build(root, "Accessible controls", func() -> void: pass)
	var count := [0]
	var enabled := MobileUi.button("Commit action", func() -> void: count[0] = int(count[0]) + 1)
	body.add_child(enabled)
	var disabled := MobileUi.button("Unavailable action", func() -> void: count[0] = 999)
	disabled.disabled = true
	body.add_child(disabled)
	await _frames()
	var access := MobileAccessibility.new()
	var projection := access.snapshot(get_tree().root)
	assert_false(projection.is_empty())
	var command := str(projection["revision"]) + ":" + str(enabled.get_instance_id())
	access.activate("access_activate", str(projection["revision"]) + ":" + str(disabled.get_instance_id()))
	assert_eq(int(count[0]), 0)
	access.activate("access_activate", command)
	assert_eq(int(count[0]), 1)
	enabled.text = "Changed action"
	access.snapshot(get_tree().root)
	access.activate("access_activate", command)
	assert_eq(int(count[0]), 1, "a native action from the previous UI revision is discarded")
	enabled.hide()
	access.snapshot(get_tree().root)
	assert_false(access.controls.has(str(enabled.get_instance_id())))


func test_mobile_keyboard_avoidance_preserves_text_and_returns_page_geometry() -> void:
	var body := MobilePage.build(root, "Name", func() -> void: pass)
	var page := body.get_parent().get_parent().get_parent() as MobilePage
	var input := LineEdit.new()
	input.text = "My adventurer"
	body.add_child(input)
	await _frames()
	var original := page.get_global_rect()
	MobileDevice.test_keyboard_height = 170
	page.reflow()
	await _frames()
	assert_true(page.keyboard_done.visible)
	assert_true(page.get_global_rect().end.y <= MobileDevice.logical_size().y - 170)
	assert_eq(input.text, "My adventurer")
	MobileDevice.test_keyboard_height = 0
	page.reflow()
	await _frames()
	assert_false(page.keyboard_done.visible)
	assert_eq(page.get_global_rect(), original)


func test_mobile_interruption_preserves_prior_pause_and_cancels_input() -> void:
	var lifecycle := MobileLifecycle.new()
	add_child(lifecycle)
	var prior_audio := Audio.process_mode
	for paused: bool in [false, true]:
		get_tree().paused = paused
		VoiceOver.set_paused(paused)
		lifecycle.suspend()
		lifecycle.suspend()
		assert_true(get_tree().paused)
		assert_true(VoiceOver.is_paused())
		assert_eq(Audio.process_mode, Node.PROCESS_MODE_DISABLED)
		assert_true(is_instance_valid(lifecycle.resume_layer))
		lifecycle.resume_play()
		lifecycle.resume_play()
		assert_eq(get_tree().paused, paused, "resuming does not dismiss a pre-existing pause menu")
		assert_eq(VoiceOver.is_paused(), paused)
		assert_eq(Audio.process_mode, prior_audio)
	get_tree().paused = false
	VoiceOver.set_paused(false)
	lifecycle.queue_free()
	await _frames()


func test_mobile_choice_inspection_rechecks_legality_and_commits_once() -> void:
	var choice := Choice.new()
	choice.key = "test.skill"
	choice.kind = "skill"
	choice.label = "Choose a skill"
	choice.options = [ChoiceOption.make("athletics", "Athletics", "Climb and swim.")]
	var body := MobilePage.build(root, "Choose", func() -> void: pass)
	var widget := ChoiceWidget.create(choice)
	body.add_child(widget)
	var changes: Array = []
	widget.picks_changed.connect(func(_key: String, picks: Array) -> void: changes.append(picks))
	await _frames()
	var button := widget._mobile_list.get_child(0) as Button
	_touch(button.get_global_rect().get_center(), true)
	await _frames()
	_touch(button.get_global_rect().get_center(), false)
	await _frames()
	assert_true(is_instance_valid(widget._mobile_sheet))
	assert_true(changes.is_empty(), "opening details cannot change a build")
	var confirm: Button
	for candidate: Button in widget._mobile_sheet.find_children("*", "Button", true, false):
		if candidate.text == "Choose":
			confirm = candidate
	assert_true(confirm != null)
	choice.options[0].legal = false
	confirm.pressed.emit()
	assert_true(changes.is_empty(), "a choice invalidated while inspected cannot commit")
	choice.options[0].legal = true
	confirm.pressed.emit()
	confirm.pressed.emit()
	assert_eq(changes.size(), 1, "a stale double activation cannot toggle the choice twice")
	assert_eq(changes[0], ["athletics"])


func test_mobile_service_review_cannot_spend_and_purchase_is_once() -> void:
	var state := StoryState.new()
	state.party.append(Pregens.build("godrick_pendlebrook", 5))
	state.party[0].hp = 1
	state.gold = 1000
	var screen := ServicesScreen.new()
	add_child(screen)
	screen.open_for(self, state, "father_lucian")
	var line := Services.offered(state, "father_lucian")[0]
	var before := state.to_dict()
	var rng := Dice.roller.get_state()
	screen._mobile_confirm(line)
	await _frames()
	assert_eq(state.to_dict(), before, "reviewing does not heal or charge")
	assert_eq(Dice.roller.get_state(), rng, "inspection never rolls")
	var confirm: Button
	for candidate: Button in screen._mobile_review.find_children("*", "Button", true, false):
		if candidate.text.begins_with("Buy for"):
			confirm = candidate
	assert_true(confirm != null)
	confirm.pressed.emit()
	confirm.pressed.emit()
	assert_eq(state.gold, 1000.0 - Services.cost(line))
	assert_true(state.party[0].hp > 1)
	screen.queue_free()
	await _frames()


func test_mobile_map_pan_pinch_and_route_review_never_travel_until_commit() -> void:
	var state := StoryState.from_dict(AtomicJson.read("res://tests/saves/v2_amber_temple.json")["story"] as Dictionary)
	var screen := TravelScreen.new()
	add_child(screen)
	state.visited["village_of_barovia"] = true
	screen.open_map(state, "village_of_barovia", true)
	var departures: Array[String] = []
	screen.travel_chosen.connect(func(id: String) -> void: departures.append(id))
	await _frames()
	screen.zoom = 2.0
	screen.pan = -TravelScreen.MAP_SIZE / 2.0
	var before := state.to_dict()
	var at := screen._map.get_global_rect().intersection(MobileDevice.safe_rect()).get_center()
	var pan_before := screen.pan
	_touch(at, true)
	await _frames()
	var drag := InputEventScreenDrag.new()
	drag.position = at + Vector2(40, 0)
	drag.relative = Vector2(40, 0)
	get_tree().root.push_input(drag, true)
	await _frames()
	_touch(drag.position, false)
	await _frames()
	assert_true(screen.pan != pan_before, "a map-owned drag pans the map")
	assert_eq(screen._target, "", "a drag cannot select a destination")
	_touch(at - Vector2(30, 0), true)
	await _frames()
	var second := InputEventScreenTouch.new()
	second.index = 1
	second.position = at + Vector2(30, 0)
	second.pressed = true
	get_tree().root.push_input(second, true)
	await _frames()
	drag.index = 1
	drag.position = at + Vector2(60, 0)
	drag.relative = Vector2(30, 0)
	get_tree().root.push_input(drag, true)
	await _frames()
	assert_true(screen.zoom > 2.0, "a two-finger map gesture zooms")
	second.pressed = false
	second.position = drag.position
	get_tree().root.push_input(second, true)
	_touch(at - Vector2(30, 0), false)
	await _frames()
	assert_eq(screen._target, "", "pinch release cannot choose a destination")
	var destination := ""
	for place in Travel.known(state):
		if not Travel.route("village_of_barovia", str(place["id"]), state).is_empty():
			destination = str(place["id"])
			break
	assert_true(destination != "")
	screen.select(destination)
	await _frames()
	assert_true(departures.is_empty(), "route inspection cannot travel")
	assert_eq(state.to_dict(), before)
	screen._mobile_depart(destination)
	screen._mobile_depart(destination)
	assert_eq(departures, [destination], "only explicit confirmation departs, once")
	await _frames()


func test_mobile_skirmish_placement_preview_apply_erase_and_undo() -> void:
	var old_setup := SkirmishScreen.current
	var old_tab := SkirmishScreen.kept_tab
	SkirmishScreen.current = SkirmishSetup.new()
	SkirmishScreen.current.add_hero(Pregens.build("godrick_pendlebrook", 3))
	SkirmishScreen.kept_tab = "Field"
	var screen := SkirmishScreen.new()
	add_child(screen)
	await _frames()
	var grid := screen.setup.grid()
	var cell := Vector2i(-1, -1)
	for y in grid.depth:
		for x in grid.width:
			var at := Vector2i(x, y)
			if screen.setup.place_problem(grid, "foe", -1, at, "zombie") == "" and screen.setup.piece_at(screen.setup.placements(grid), at).is_empty():
				cell = at
				break
		if cell.x >= 0:
			break
	assert_true(cell.x >= 0)
	screen.brush = {"kind": "new", "monster": "zombie"}
	var before := screen.setup.to_dict()
	screen.mobile.pick_cell(cell)
	assert_eq(screen.setup.to_dict(), before, "tapping a square only previews")
	screen.mobile.commit_cell()
	screen.mobile.commit_cell()
	assert_eq(screen.setup.foes.size(), 1, "one Apply adds exactly one foe")
	screen.mobile.erase = true
	screen.mobile.pick_cell(cell)
	assert_eq(screen.setup.foes.size(), 1, "erase also requires Apply")
	screen.mobile.commit_cell()
	assert_true(screen.setup.foes.is_empty())
	screen.mobile.undo_edit()
	assert_eq(screen.setup.foes.size(), 1, "undo restores the removed piece and its square")
	screen.mobile.undo_edit()
	assert_eq(screen.setup.to_dict(), before, "undo restores the complete pre-edit setup")
	screen.queue_free()
	await _frames()
	SkirmishScreen.current = old_setup
	SkirmishScreen.kept_tab = old_tab


func test_mobile_tutorial_sheet_and_combat_keep_real_progress_and_command_guards() -> void:
	var controls := MobileControls.new()
	UiFeel.add_child(controls)
	UiFeel.mobile_controls = controls
	var campaign_dice := Dice.roller
	var dice_state := campaign_dice.get_state()
	var session := TutorialSession.new()
	add_child(session)
	await _frames()
	session.start_lesson(TutorialSession.EXPLORATION_IDS.find("sheet"))
	await _frames()
	session.coach.action_button.pressed.emit()
	await _frames()
	assert_true(session.screen is CharacterSheetScreen)
	assert_true(session._guide_close != null)
	session._guide_close.pressed.emit()
	await _frames()
	assert_eq((session.screen as CharacterSheetScreen).mobile_section, "Abilities")
	session._guide_close.pressed.emit()
	await _frames()
	session._guide_close.pressed.emit()
	await _frames()
	assert_true(session.lesson_complete, "the mobile reading steps finish the same sheet lesson")
	session.start_lesson(TutorialSession.EXPLORATION_IDS.size() + TutorialCombat.LESSON_IDS.find("combat_move"))
	var deadline := Time.get_ticks_msec() + 15000
	while Time.get_ticks_msec() < deadline and (session.combat.view.mode != CombatView.Mode.IDLE or session.combat.e.current() != session.combat.hero):
		await get_tree().process_frame
	var fight := session.combat.view
	assert_true(fight.touch_ready(), "guided combat accepts touch previews without an absent key event")
	var before := session.combat.hero.cell
	fight.hover_cell = Vector2i(7, 7)
	fight.hover_token = null
	fight._confirm_at()
	assert_eq(session.combat.hero.cell, before, "touch readiness does not bypass the lesson's command guard")
	fight.touch_tap(session.combat.rig.camera.unproject_position(session.combat.board.cell_center(Vector2i(4, 3))), false)
	assert_eq(fight.hover_cell, Vector2i(4, 3), "the ground tap previews the intended square")
	assert_eq(session.combat.hero.cell, before, "touch preview does not move")
	fight.touch_confirm()
	deadline = Time.get_ticks_msec() + 15000
	while not session.lesson_complete and Time.get_ticks_msec() < deadline:
		await get_tree().process_frame
	assert_true(session.lesson_complete, "Confirm completes the actual movement exercise")
	assert_eq(session.combat.hero.cell, Vector2i(4, 3))
	session.queue_free()
	controls.queue_free()
	UiFeel.mobile_controls = null
	await _frames()
	assert_true(Dice.roller == campaign_dice)
	assert_eq(campaign_dice.get_state(), dice_state, "mobile practice leaves campaign dice unchanged")


func test_two_fingers_on_buttons_cancel_both_activations() -> void:
	var count := [0]
	var body := MobilePage.build(root, "Two contacts", func() -> void: pass)
	var first := MobileUi.button("First action", func() -> void: count[0] = int(count[0]) + 1)
	var second := MobileUi.button("Second action", func() -> void: count[0] = int(count[0]) + 1)
	body.add_child(first)
	body.add_child(second)
	await _frames()
	_touch(first.get_global_rect().get_center(), true)
	await _frames()
	var finger := InputEventScreenTouch.new()
	finger.index = 1
	finger.position = second.get_global_rect().get_center()
	finger.pressed = true
	get_tree().root.push_input(finger, true)
	await _frames()
	finger.pressed = false
	get_tree().root.push_input(finger, true)
	_touch(first.get_global_rect().get_center(), false)
	await _frames()
	assert_eq(int(count[0]), 0, "neither contact can activate a button after a second finger joins")


func test_accessibility_scroll_revision_and_readonly_slider_are_enforced() -> void:
	var body := MobilePage.build(root, "Reading", func() -> void: pass)
	var page := body.get_parent().get_parent().get_parent() as MobilePage
	var slider := HSlider.new()
	slider.tooltip_text = "Text size"
	slider.custom_minimum_size = Vector2(200, 48)
	slider.value = 50
	slider.editable = false
	body.add_child(slider)
	for i in 20:
		body.add_child(MobileUi.text("Reading paragraph %d" % i))
	await _frames()
	var access := MobileAccessibility.new()
	var projection := access.snapshot(get_tree().root)
	var command := str(projection["revision"]) + ":" + str(slider.get_instance_id())
	access.activate("access_increment", command)
	assert_eq(slider.value, 50.0, "read-only values cannot be adjusted by VoiceOver")
	access.activate("access_scroll", "0:down")
	assert_eq(page.scroll.scroll_vertical, 0, "stale native scrolling cannot affect the new page")
	access.activate("access_scroll", str(projection["revision"]) + ":down")
	assert_true(page.scroll.scroll_vertical > 0)
	page.scroll.scroll_vertical = 0
	slider.editable = true
	await _frames()
	projection = access.snapshot(get_tree().root)
	command = str(projection["revision"]) + ":" + str(slider.get_instance_id())
	access.activate("access_activate", command)
	assert_eq(slider.value, 50.0, "activation does not silently increment a slider")
	access.activate("access_increment", command)
	assert_true(slider.value > 50.0)
