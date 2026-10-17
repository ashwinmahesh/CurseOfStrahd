extends Node
## Representative mobile controller states; input is synthetic, not paired hardware.

func capture_shots(tool: Node, out: String) -> void:
	InputActions.ensure()
	var nav := PadNav.current
	var state := StoryState.new()
	state.party.append(Pregens.build("godrick_pendlebrook", 5))
	state.party[0].add_item("potion_of_healing", 2)
	var inventory := InventoryScreen.new()
	add_child(inventory)
	inventory.open(self, state, 0)
	await _press(JOY_BUTTON_DPAD_DOWN)
	await tool.call("wait_frames", 12)
	tool.call("_shot", out + "_inventory.png")
	var field := LineEdit.new()
	inventory.mobile.page.body.add_child(field)
	field.text = "Godrick"
	var keyboard := PadKeyboard.open_for(field)
	await tool.call("wait_frames", 12)
	tool.call("_shot", out + "_keyboard.png")
	keyboard.queue_free()
	inventory.queue_free()
	await tool.call("wait_frames", 3)
	var encounter := TestCombat.open_field()
	var actor := TestCombat.hero(encounter, "godrick_pendlebrook", Vector2i(2, 2), 5)
	TestCombat.foe(encounter, "zombie", Vector2i(6, 2))
	TestCombat.start_with(encounter, actor)
	var actions := MobileActions.new()
	add_child(actions)
	actions.open(ActionCatalog.new(encounter), actor)
	await _press(JOY_BUTTON_DPAD_DOWN)
	await _press(JOY_BUTTON_RIGHT_SHOULDER)
	await tool.call("wait_frames", 12)
	tool.call("_shot", out + "_actions.png")
	var lifecycle := MobileLifecycle.new()
	add_child(lifecycle)
	lifecycle.suspend("Controller disconnected. Reconnect it or use touch, then Continue.")
	await tool.call("wait_frames", 12)
	tool.call("_shot", out + "_disconnect.png")
	lifecycle.resume_play()
	lifecycle.queue_free()
	actions.queue_free()
	nav.reset()
	await tool.call("wait_frames", 3)


func _press(button: JoyButton) -> void:
	for pressed: bool in [true, false]:
		var event := InputEventJoypadButton.new()
		event.device = 7
		event.button_index = button
		event.pressed = pressed
		get_viewport().push_input(event, true)
	await get_tree().process_frame


func close_screen() -> void:
	pass
