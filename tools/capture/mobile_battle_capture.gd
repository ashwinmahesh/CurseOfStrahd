extends "res://tools/capture/combat_hud_capture.gd"
## Actual battlefield with prepared combat states; layout evidence, not gameplay E2E.

func capture_shots(tool: Node, out: String) -> void:
	await tool.call("wait_frames", 150)
	view.input_locked = false
	view.set_process(false)
	view.set_process_unhandled_input(false)
	view.mode = CombatView.Mode.IDLE
	view.hover_cell = Vector2i(-1, -1)
	view.hover_token = null
	view.hud.hide_tooltip()
	view.hud.refresh()
	var controls := UiFeel.mobile_controls
	controls.set_process(false)
	controls.show()
	controls.show_commands(view.mobile_command_state())
	await tool.call("wait_frames", 12)
	tool.call("_shot", out + "_closed.png")
	controls._actions(view)
	await tool.call("wait_frames", 12)
	tool.call("_shot", out + "_actions.png")
	(controls.drawer as MobileActions).dismiss()
	view.hover_cell = Vector2i(4, 2)
	view._update_hover()
	controls.show_commands(view.mobile_command_state())
	await tool.call("wait_frames", 12)
	tool.call("_shot", out + "_movement.png")
	view.hud.mobile.menu()
	await tool.call("wait_frames", 12)
	tool.call("_shot", out + "_menu.png")
	view.hud.mobile.close()
