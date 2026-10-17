extends "res://tools/capture/mobile_exploration_capture.gd"
## Research-driven UX improvements, prepared offscreen mobile states rather than native E2E.

func touch_ready() -> bool:
	return true


func capture_shots(tool: Node, out: String) -> void:
	add_to_group(&"touch_world")
	LocationChecks._move_party(view, Vector2i(22, 14))
	var focus := Node3D.new()
	view.add_child(focus)
	focus.position = view.board.cell_center(Vector2i(21, 13))
	view.rig.follow = focus
	view.rig.distance = 11
	view.rig.snap_to_target()
	await tool.call("wait_frames", 24)
	hud.mobile.reveal_button.touch_surface_press(0, hud.mobile.reveal_button.get_global_rect().get_center())
	await tool.call("wait_frames", 4)
	tool.call("_shot", out + "_held_reveal.png")
	hud.mobile.reveal_button.touch_surface_cancel()
	hud.mobile.nearby()
	await tool.call("wait_frames", 8)
	tool.call("_shot", out + "_nearby.png")
	hud.mobile.nearby_query = "zzzz"
	hud.mobile.nearby()
	await tool.call("wait_frames", 8)
	tool.call("_shot", out + "_nearby_empty_search.png")
	hud.mobile.close()
	var inventory := InventoryScreen.new()
	add_child(inventory)
	hud.st.party[0].add_item("potion_of_healing", 3)
	inventory.open(self, hud.st, 0)
	inventory.search = "zzzz"
	inventory._draw()
	await tool.call("wait_frames", 8)
	tool.call("_shot", out + "_inventory_empty_search.png")
	inventory.mobile.reset_filters()
	await tool.call("wait_frames", 8)
	tool.call("_shot", out + "_inventory_recovered.png")
	inventory.queue_free()
	await tool.call("wait_frames", 4)
	var encounter := TestCombat.open_field()
	var actor := TestCombat.hero(encounter, "godrick_pendlebrook", Vector2i(2, 2), 5)
	TestCombat.start_with(encounter, actor)
	var actions := MobileActions.new()
	add_child(actions)
	actions.category = ActionCatalog.FAVOURITES
	actions.open(ActionCatalog.new(encounter), actor)
	await tool.call("wait_frames", 8)
	tool.call("_shot", out + "_actions_empty_favourites.png")
	actions.query = "zzzz"
	actions.browse()
	await tool.call("wait_frames", 8)
	tool.call("_shot", out + "_actions_empty_search.png")
	actions.category = "All"
	actions.query = ""
	actions.browse()
	await tool.call("wait_frames", 8)
	tool.call("_shot", out + "_actions_recovered.png")
	actions.queue_free()
