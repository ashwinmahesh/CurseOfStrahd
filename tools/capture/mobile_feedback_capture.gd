extends "res://tools/capture/mobile_exploration_capture.gd"
## Prepared mobile interaction feedback over a real location; desktop offscreen evidence.

func touch_ready() -> bool:
	return true


func capture_shots(tool: Node, out: String) -> void:
	InputActions.ensure()
	add_to_group(&"touch_world")
	LocationChecks._move_party(view, Vector2i(22, 14))
	var focus := Node3D.new()
	view.add_child(focus)
	focus.position = view.board.cell_center(Vector2i(21, 13))
	view.rig.follow = focus
	view.rig.distance = 11
	view.rig.snap_to_target()
	await tool.call("wait_frames", 30)
	tool.call("_shot", out + "_quiet.png")
	hud.mobile.reveal_button.touch_surface_press(0, hud.mobile.reveal_button.get_global_rect().get_center())
	await tool.call("wait_frames", 4)
	tool.call("_shot", out + "_reveal.png")
	hud.mobile.reveal_button.touch_surface_cancel()
	await tool.call("wait_frames", 4)
	TouchOutline.at(view, Vector2i(22, 12))
	var prop := view.prop_nodes["mists_signpost"] as Node3D
	(prop.get_node("TouchOutline") as TouchOutline).remaining = 60.0
	TouchOutline.flash((view.tokens[view.leader().id] as CombatToken).body)
	((view.tokens[view.leader().id] as CombatToken).body.get_node("TouchOutline") as TouchOutline).remaining = 60.0
	await tool.call("wait_frames", 4)
	tool.call("_shot", out + "_tap_outline.png")
