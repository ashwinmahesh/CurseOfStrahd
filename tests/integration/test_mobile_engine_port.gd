extends TestCase
## The engine port keeps current-main inventory semantics at both touch sizes.

var old_size: Vector2i
var old_canvas: Vector2i
var old_factor: float


func before_each() -> void:
	old_size = get_tree().root.size
	old_canvas = get_tree().root.content_scale_size
	old_factor = get_tree().root.content_scale_factor


func after_each() -> void:
	UiFeel.touch.cancel()
	MobileDevice.test_size = Vector2.ZERO
	MobileDevice.test_safe = Rect2()
	get_tree().root.content_scale_size = old_canvas
	get_tree().root.content_scale_factor = old_factor
	get_tree().root.size = old_size


func _frames() -> void:
	for frame in 4:
		await get_tree().process_frame


func _tap(page: MobilePage, control: BaseButton) -> void:
	page.scroll.ensure_control_visible(control)
	await _frames()
	var point := control.get_global_rect().get_center()
	assert_true(page.scroll.get_global_rect().has_point(point), "the touch target is inside the scroll viewport")
	for down: bool in [true, false]:
		var event := InputEventScreenTouch.new()
		event.position = point
		event.pressed = down
		get_tree().root.push_input(event, true)
		await _frames()


func _button(node: Node, caption: String) -> Button:
	for button: Button in node.find_children("*", "Button", true, false):
		if not button.is_queued_for_deletion() and button.text == caption:
			return button
	return null


func test_touch_rarity_filters_can_recover_an_empty_bag_without_mutating_items() -> void:
	for size_: Vector2 in [Vector2(844, 390), Vector2(1194, 834)]:
		MobileDevice.test_size = size_
		MobileDevice.test_safe = Rect2(Vector2(12, 16), size_ - Vector2(24, 32))
		get_tree().root.size = Vector2i(size_)
		MobileDevice.current.configure()
		var state := StoryState.new()
		state.party.append(Pregens.build("godrick_pendlebrook", 3))
		state.party[0].add_item("potion_of_healing", 3)
		var inventory := InventoryScreen.new()
		add_child(inventory)
		inventory.open(self, state, 0)
		var before := state.to_dict()
		inventory.mobile.filters_open = true
		inventory.mobile.draw()
		await _frames()
		var legendary: CheckButton
		for option: CheckButton in inventory.find_children("*", "CheckButton", true, false):
			if not option.is_queued_for_deletion() and option.text == "Legendary":
				legendary = option
		assert_true(legendary != null, "main's rarity filters are reachable on mobile")
		if legendary != null:
			await _tap(inventory.mobile.page, legendary)
		assert_eq(inventory.rarities, ["legendary"] as Array[String])
		var apply := _button(inventory, "Show filtered items")
		assert_true(apply != null)
		if apply != null:
			await _tap(inventory.mobile.page, apply)
		assert_true(inventory.shown_ids().is_empty())
		var reset := _button(inventory, "Show all items")
		assert_true(reset != null, "a rarity-only empty result must offer recovery")
		if reset != null:
			await _tap(inventory.mobile.page, reset)
		assert_true(inventory.rarities.is_empty())
		assert_true(inventory.shown_ids().has("potion_of_healing"))
		assert_eq(state.to_dict(), before, "filtering and recovery cannot use, equip or move any item")
		inventory.queue_free()
		await _frames()


func test_shared_native_export_names_follow_the_host_project() -> void:
	var title: Variant = ProjectSettings.get_setting("application/config/name")
	ProjectSettings.set_setting("application/config/name", "Another Campaign")
	assert_eq(MobileNative.transfer_path("save"), "user://transfers/AnotherCampaign-save.json")
	assert_eq(MobileNative.transfer_path("diagnostics"), "user://transfers/AnotherCampaign-diagnostics.json")
	ProjectSettings.set_setting("application/config/name", title)
