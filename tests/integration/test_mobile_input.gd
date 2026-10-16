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
