extends Node
## The controller on screens (U6, ui/common/pad_nav.gd) over a late party, driven by synthetic pad presses: the pause
## menu with the focus frame on its second button and the prompt bar, the Game settings with focus on a row, the
## character sheet with a row's rules card opened by Y, and the inventory after a few D-pad steps. The game is loaded
## in the capture's own save folder (tools/capture/capture.gd), and its settings go to a file of its own, so a row the
## pad touches never changes the owner's.
## make capture SCENE=res://tools/capture/pad_capture.tscn NAME=pad FRAMES=30

const LATE := "v2_amber_temple.json"

var root: Node


func _ready() -> void:
	GameSettings.path = "user://capture_saves/%d/settings.cfg" % OS.get_process_id()
	var out := FileAccess.open(SaveSystem.slot_path("capture_game"), FileAccess.WRITE)
	out.store_string(FileAccess.get_file_as_string(GoldenSaves.DIR + LATE))
	out.close()
	SaveSystem.load_slot("capture_game")
	SaveSystem.delete_slot("capture_game")
	root = (load("res://scenes/game.tscn") as PackedScene).instantiate()
	add_child(root)


func _press(tool: Node, button: JoyButton) -> void:
	for down: bool in [true, false]:
		var ev := InputEventJoypadButton.new()
		ev.button_index = button
		ev.pressed = down
		get_viewport().push_input(ev)
	await tool.call("wait_frames", 2)


func _shoot(tool: Node, path: String, frames: int = 10) -> void:
	await tool.call("wait_frames", frames)
	tool.call("_shot", path)


func capture_shots(tool: Node, out: String) -> void:
	(root.get("hud") as ExploreHud).close_narration()
	await tool.call("wait_frames", 10)
	root.call("open_screen", "menu", 0)
	await tool.call("wait_frames", 10)
	await _press(tool, JOY_BUTTON_DPAD_DOWN)
	await _press(tool, JOY_BUTTON_DPAD_DOWN)
	await _shoot(tool, out + "_0_menu.png")
	(root.get("screen") as PauseMenu).call("_show_settings", "Game")
	await tool.call("wait_frames", 4)
	for b: JoyButton in [JOY_BUTTON_DPAD_UP, JOY_BUTTON_DPAD_UP, JOY_BUTTON_DPAD_UP]:
		await _press(tool, b)
	await _shoot(tool, out + "_3_settings.png")
	root.call("close_screen")
	await tool.call("wait_frames", 10)
	root.call("open_screen", "sheet", 0)
	await tool.call("wait_frames", 10)
	for b: JoyButton in [JOY_BUTTON_DPAD_DOWN, JOY_BUTTON_DPAD_DOWN, JOY_BUTTON_DPAD_DOWN, JOY_BUTTON_DPAD_RIGHT]:
		await _press(tool, b)
	await _press(tool, JOY_BUTTON_Y)
	await _shoot(tool, out + "_1_sheet.png", 20)
	root.call("close_screen")
	await tool.call("wait_frames", 10)
	root.call("open_screen", "inventory", 0)
	await tool.call("wait_frames", 10)
	for b: JoyButton in [JOY_BUTTON_DPAD_DOWN, JOY_BUTTON_DPAD_DOWN, JOY_BUTTON_DPAD_RIGHT, JOY_BUTTON_DPAD_RIGHT]:
		await _press(tool, b)
	await _shoot(tool, out + "_2_inventory.png", 20)
	root.call("close_screen")
