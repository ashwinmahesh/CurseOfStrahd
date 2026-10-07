extends Node
## Offalia asleep on the bakery floor after her mother's dream pastry (owner report 2026-10-07): her figure lying down
## with its conditions over her, the hover hint, then the Alt plates.
## make capture SCENE=res://tools/capture/sleeping_capture.tscn NAME=sleeping FRAMES=30

var root: Node


func _ready() -> void:
	GameState.reset()
	for id: String in ["godrick_pendlebrook", "liriel_dawnsong", "thistle", "ratatoille"]:
		var ch := Pregens.build(id, 5)
		ch.finish_long_rest()
		GameState.story.party.append(ch)
	GameState.story.location = "old_bonegrinder"
	GameState.story.set_flag("offalia_met")
	GameState.story.set_flag("offalia_asleep")
	root = (load("res://scenes/game.tscn") as PackedScene).instantiate()
	add_child(root)


func _shoot(tool: Node, path: String) -> void:
	await tool.call("wait_frames", 10)
	tool.call("_shot", path)


func capture_shots(tool: Node, out: String) -> void:
	var view := root.get("view") as LocationView
	var hud := root.get("hud") as ExploreHud
	var her := Vector2i(14, 12)
	view.walk_to(LocationInteraction._adjacent_free(view, her))
	for i in 600:
		if (view.get("_queue") as Array).is_empty():
			break
		await tool.call("wait_frames", 1)
	await tool.call("wait_frames", 20)
	hud.close_narration()
	var at := view.rig.camera.unproject_position(view.board.cell_center(her) + Vector3(0, 0.3, 0))
	hud.hint(str(view.thing_at(her).get("label", "")), at)
	await _shoot(tool, out + "_1_asleep_hover.png")
	hud.hint("", at)
	hud.thing_labels.pinned = true
	await _shoot(tool, out + "_2_alt_plates.png")
	hud.thing_labels.pinned = false
