extends Node
## The controller (U6, docs/ui/controller.md) over a late party, driven by synthetic pad presses: exploring with a thing
## marked and the HUD's bar stepped into (world/exploration/pad_explore.gd); then on screens (ui/common/pad_nav.gd): the pause
## menu with the focus frame on its second button and the prompt bar, the Game settings with focus on a row, the
## character sheet with a row's rules card opened by Y, the inventory after a few D-pad steps and an item's menu (X),
## the travel map with a place picked, and the on-screen keyboard on the cheat code's field. The game is loaded
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


## A press through the engine's Input, as a pad sends it.
func _press(tool: Node, button: JoyButton) -> void:
	for down: bool in [true, false]:
		var ev := InputEventJoypadButton.new()
		ev.button_index = button
		ev.pressed = down
		Input.parse_input_event(ev)
		Input.flush_buffered_events()
	await tool.call("wait_frames", 2)


func _shoot(tool: Node, path: String, frames: int = 10) -> void:
	await tool.call("wait_frames", frames)
	tool.call("_shot", path)


func capture_shots(tool: Node, out: String) -> void:
	(root.get("hud") as ExploreHud).close_narration()
	await tool.call("wait_frames", 10)
	await _press(tool, JOY_BUTTON_DPAD_RIGHT)
	await _shoot(tool, out + "_7_exploring.png", 12)
	await _press(tool, JOY_BUTTON_DPAD_UP)
	await _press(tool, JOY_BUTTON_DPAD_RIGHT)
	await _shoot(tool, out + "_8_hud_bar.png", 8)
	await _press(tool, JOY_BUTTON_B)
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
	await _press(tool, JOY_BUTTON_X)
	await _press(tool, JOY_BUTTON_DPAD_DOWN)
	await _shoot(tool, out + "_4_item_menu.png", 10)
	await _press(tool, JOY_BUTTON_B)
	root.call("close_screen")
	await tool.call("wait_frames", 10)
	root.call("open_travel", false)
	await tool.call("wait_frames", 10)
	for b: JoyButton in [JOY_BUTTON_DPAD_DOWN, JOY_BUTTON_DPAD_LEFT, JOY_BUTTON_DPAD_UP, JOY_BUTTON_A]:
		await _press(tool, b)
	await _shoot(tool, out + "_5_map.png", 20)
	root.call("close_screen")
	await tool.call("wait_frames", 10)
	root.call("open_screen", "menu", 0)
	await tool.call("wait_frames", 6)
	(root.get("screen") as PauseMenu).call("_open_cheats")
	await tool.call("wait_frames", 6)
	await _press(tool, JOY_BUTTON_A)
	for b: JoyButton in [JOY_BUTTON_A, JOY_BUTTON_DPAD_RIGHT, JOY_BUTTON_DPAD_DOWN, JOY_BUTTON_A]:
		await _press(tool, b)
	await _shoot(tool, out + "_6_keyboard.png", 10)
	await _press(tool, JOY_BUTTON_B)
	root.call("close_screen")
