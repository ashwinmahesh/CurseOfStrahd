extends Node
## A fight on a pad (U6, world/combat/pad_combat.gd) against two wolves on a small field, driven by synthetic pad
## presses: X puts the cursor on a target (the camera following it, the prompt bar saying what the buttons do), and Y
## brings up the end-turn check, which takes the pad alone. The game is loaded in the capture's own save folder and
## settings file (tools/capture/capture.gd), so nothing of the owner's changes.
## make capture SCENE=res://tools/capture/pad_fight_capture.tscn NAME=pad_fight FRAMES=30

const LATE := "v2_amber_temple.json"
const FIELD := {
	"id": "pad_capture_field", "name": "A Clearing", "region": "svalich_woods", "summary": "A capture's field.",
	"map": {"rows": [
		"..............",
		"..............",
		"..............",
		"..............",
		"..............",
		".............."], "light": "day"},
	"spawns": {"default": [3, 3]},
	"encounters": [{"id": "wolves", "trigger": "manual", "monsters": [{"monster": "wolf", "cell": [10, 2]},
		{"monster": "wolf", "cell": [11, 4]}]}],
}

var root: Node


func _ready() -> void:
	GameSettings.path = "user://capture_saves/%d/settings.cfg" % OS.get_process_id()
	Compendium.shared().tables["locations"]["pad_capture_field"] = FIELD.duplicate(true)
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
		Input.parse_input_event(ev)
		Input.flush_buffered_events()
	await tool.call("wait_frames", 2)


func capture_shots(tool: Node, out: String) -> void:
	(root.get("hud") as ExploreHud).close_narration()
	root.call("enter_location", "pad_capture_field", "default")
	await tool.call("wait_frames", 20)
	var view := root.get("view") as LocationView
	if not view.start_encounter("wolves"):
		return
	var cv := view.combat_view
	for i in 600:
		if cv.mode == CombatView.Mode.IDLE and cv.e.current().side == &"party":
			break
		if cv.mode == CombatView.Mode.IDLE:
			cv.e.end_turn()
		await tool.call("wait_frames", 1)
	await _press(tool, JOY_BUTTON_X)
	await tool.call("wait_frames", 30)
	tool.call("_shot", out + "_0_target.png")
	await _press(tool, JOY_BUTTON_Y)
	await tool.call("wait_frames", 10)
	tool.call("_shot", out + "_1_end_turn_check.png")
	await _press(tool, JOY_BUTTON_B)
	await _press(tool, JOY_BUTTON_BACK)
	await tool.call("wait_frames", 6)
	tool.call("_shot", out + "_2_controls.png")
	cv.finished.emit("victory")
