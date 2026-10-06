extends Node
## Interaction fixes for captures, in the Death House attic: a click on the locked children's door (the Locked notice)
## with its right-click menu, the Narrator's box with its portrait, the dollhouse description with the Narrator's
## portrait, the Investigation check with the roller's portrait and the Continue button, and the loot window's Take
## gold. make capture SCENE=res://tools/capture/interaction_capture.tscn NAME=interactions FRAMES=30

var root: Node


func _ready() -> void:
	GameState.reset()
	for id: String in ["ilse_varga", "tamsin_tealeaf", "hedda_ironvow", "silvain_aster"]:
		var ch := Pregens.build(id, 3)
		ch.finish_long_rest()
		GameState.story.party.append(ch)
	GameState.story.location = "death_house_attic"
	root = (load("res://scenes/game.tscn") as PackedScene).instantiate()
	add_child(root)


func _shoot(tool: Node, path: String) -> void:
	await tool.call("wait_frames", 10)
	tool.call("_shot", path)


func capture_shots(tool: Node, out: String) -> void:
	var view := root.get("view") as LocationView
	var hud := root.get("hud") as ExploreHud
	var door := Vector2i(18, 9)
	view.walk_to(Vector2i(18, 8))
	for i in 600:
		if (view.get("_queue") as Array).is_empty():
			break
		await tool.call("wait_frames", 1)
	await tool.call("wait_frames", 20)
	hud.close_narration()
	view.interact(view.thing_at(door))
	await tool.call("wait_frames", 4)
	var at := view.rig.camera.unproject_position(view.board.cell_center(door) + Vector3(0, 0.6, 0))
	root.call("open_world_menu", door, at)
	await _shoot(tool, out + "_1_locked_door.png")
	(root.get("menu") as ContextMenu).hide()
	hud.narrate("Dust lies thick on everything up here, and the air is colder than it should be. Somewhere below, a door closes softly.")
	await _shoot(tool, out + "_2_narrator_box.png")
	hud.close_narration()
	root.call("start_dialogue", "death_house/attic:dollhouse", "")
	var d := root.get("dialogue") as DialogueUI
	for i in 6:
		var name_ := (d.get("_name") as Label).text
		if name_ == "Narrator" and bool(d.get("_waiting_continue")):
			break
		d.call("_advance")
		await tool.call("wait_frames", 2)
	await _shoot(tool, out + "_3_narrator_line.png")
	for i in 6:
		if not d.options_shown.is_empty():
			break
		d.call("_advance")
		await tool.call("wait_frames", 2)
	d.call("_choose", 0)
	await _shoot(tool, out + "_4_check.png")
	d.queue_free()
	root.set("dialogue", null)
	hud.visible = true
	root.call("_open_loot", "capture_chest", [{"id": "dagger", "qty": 1}, {"id": "candle", "qty": 2}], 12.0)
	await _shoot(tool, out + "_5_loot.png")
