extends Node
## Traps and the Search (owner, 2026-10-08), on Death House's upper floor: a Search tints the squares it reached for a
## moment, and a found trap's right-click menu offers Set it off (from within 5 ft) beside Disarm.
## make capture SCENE=res://tools/capture/search_reach_capture.tscn NAME=search_reach FRAMES=30

var root: Node


func _ready() -> void:
	GameState.reset()
	for id: String in ["hedda_ironvow", "liriel_dawnsong", "thistle", "ratatoille"]:
		var ch := Pregens.build(id, 3)
		ch.finish_long_rest()
		GameState.story.party.append(ch)
	GameState.story.location = "death_house_upper"
	root = (load("res://scenes/game.tscn") as PackedScene).instantiate()
	add_child(root)


func capture_shots(tool: Node, out: String) -> void:
	var view := root.get("view") as LocationView
	var hud := root.get("hud") as ExploreHud
	var trap_cell := Vector2i(12, 8)
	view.walk_to(Vector2i(13, 7))
	for i in 600:
		if (view.get("_queue") as Array).is_empty():
			break
		await tool.call("wait_frames", 1)
	await tool.call("wait_frames", 20)
	hud.close_narration()
	view.search()
	await tool.call("wait_frames", 6)
	tool.call("_shot", out + "_1_search_reach.png")
	# The floorboard (DC 11): found by the Search, or marked found for the menu shot if the roll fell short.
	var states := GameState.story.loc_state("death_house_upper")["traps"] as Dictionary
	print("search reach capture: the rotten floorboard is %s" % str(states.get("rotten_floorboard", "hidden")))
	if str(states.get("rotten_floorboard", "")) == "":
		for t: Variant in view.loc.get("traps", []):
			if str((t as Dictionary)["id"]) == "rotten_floorboard":
				states["rotten_floorboard"] = "found"
				view.call("_show_trap", t)
	await tool.call("wait_frames", 120)
	hud.close_narration()
	var at := view.rig.camera.unproject_position(view.board.cell_center(trap_cell) + Vector3(0, 0.3, 0))
	root.call("open_world_menu", trap_cell, at)
	await tool.call("wait_frames", 10)
	tool.call("_shot", out + "_2_trap_menu.png")
