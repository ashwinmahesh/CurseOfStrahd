extends Node
## A spell on someone in the overworld (owner, 2026-10-07): Silvain casts Sleep at Gunther Arasek's stall in Vallaki;
## he lies down with "Asleep · Prone" over him and the hover hint says why, then the right-click menu.
## make capture SCENE=res://tools/capture/effects_capture.tscn NAME=effects FRAMES=30

var root: Node
const AT := Vector2i(30, 18)


func _ready() -> void:
	GameState.reset()
	for id: String in ["silvain_aster", "godrick_pendlebrook", "liriel_dawnsong", "thistle"]:
		var ch := Pregens.build(id, 5)
		ch.finish_long_rest()
		GameState.story.party.append(ch)
	GameState.story.location = "vallaki"
	GameState.story.minute_of_day = 10 * 60
	GameState.story.set_flag("vallaki_arrived")
	GameState.story.positions = [Vector2i(27, 19), Vector2i(26, 19), Vector2i(27, 20), Vector2i(26, 20)] as Array[Vector2i]
	Dice.reseed(5)
	root = (load("res://scenes/game.tscn") as PackedScene).instantiate()
	add_child(root)


func _shoot(tool: Node, path: String) -> void:
	await tool.call("wait_frames", 10)
	tool.call("_shot", path)


func capture_shots(tool: Node, out: String) -> void:
	var view := root.get("view") as LocationView
	var hud := root.get("hud") as ExploreHud
	await tool.call("wait_frames", 20)
	hud.close_narration()
	for i in 15:
		view.act(AT, "cast_at:0:sleep")
		if LocationNpcs.is_asleep(view, "gunther_arasek"):
			break
		(GameState.story.party[0] as Character).finish_long_rest()
	await tool.call("wait_frames", 30)
	hud.close_narration()
	var at := view.rig.camera.unproject_position(view.board.cell_center(AT) + Vector3(0, 0.3, 0))
	hud.hint(str(view.thing_at(AT).get("label", "")), at)
	await _shoot(tool, out + "_1_asleep.png")
	hud.hint("", at)
	root.call("open_world_menu", AT, at)
	await _shoot(tool, out + "_2_menu.png")
