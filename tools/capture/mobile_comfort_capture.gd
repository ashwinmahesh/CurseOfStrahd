extends "res://tools/capture/mobile_exploration_capture.gd"
## Prepared offscreen settings and keyboard-safe layouts; motion behavior is verified by regression tests.


func capture_shots(tool: Node, out: String) -> void:
	var menu := PauseMenu.new()
	add_child(menu)
	menu.open(self, hud.st, 0)
	menu._show_settings("Display")
	await tool.call("wait_frames", 12)
	tool.call("_shot", out + "_display.png")
	menu.queue_free()
	await tool.call("wait_frames", 4)
	var inventory := InventoryScreen.new()
	add_child(inventory)
	inventory.open(self, hud.st, 0)
	inventory.search = "healing"
	inventory._draw()
	for field: LineEdit in inventory.find_children("*", "LineEdit", true, false):
		if field.placeholder_text == "Search items":
			field.grab_focus()
	var points := MobileDevice.logical_size()
	MobileDevice.test_keyboard_height = minf(300, points.y * 0.43)
	await tool.call("wait_frames", 12)
	tool.call("_shot", out + "_keyboard_layout.png")
	MobileDevice.test_keyboard_height = 0
	MobileDevice.test_size = points
	MobileDevice.test_safe = Rect2(Vector2(8, 8), points - Vector2(90, 29))
	await tool.call("wait_frames", 12)
	tool.call("_shot", out + "_opposite_safe_area.png")
	inventory.queue_free()
	MobileDevice.test_size = Vector2.ZERO
	MobileDevice.test_safe = Rect2()
