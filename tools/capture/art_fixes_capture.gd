extends Node
## Cosmin on the squires' graves at Argynvostholt (the art-fixes lane's before and after): the map close on him, then his
## words in the dialogue box with his portrait. make capture SCENE=res://tools/capture/art_fixes_capture.tscn
## NAME=art-fixes/cosmin FRAMES=30

var root: Node


func _ready() -> void:
	GameState.reset()
	for id: String in ["godrick_pendlebrook", "liriel_dawnsong", "thistle", "ratatoille"]:
		var ch := Pregens.build(id, 7)
		ch.finish_long_rest()
		GameState.story.party.append(ch)
	GameState.story.location = "argynvostholt"
	root = (load("res://scenes/game.tscn") as PackedScene).instantiate()
	add_child(root)


func _shoot(tool: Node, path: String) -> void:
	await tool.call("wait_frames", 12)
	tool.call("_shot", path)


func capture_shots(tool: Node, out: String) -> void:
	var view := root.get("view") as LocationView
	var hud := root.get("hud") as ExploreHud
	await tool.call("wait_frames", 20)
	hud.close_narration()
	var cosmin := view.npc_tokens.get("argynvostholt_cosmin") as CombatToken
	if cosmin != null:
		view.rig.follow = cosmin
		view.rig.distance = 4.5
		view.rig.snap_to_target()
		await _shoot(tool, out + "_1_map.png")
	root.call("start_dialogue", "argynvostholt/the_squire:cosmin", "argynvostholt_cosmin")
	var d := root.get("dialogue") as DialogueUI
	for i in 8:
		if (d.get("_name") as Label).text == "Cosmin":
			break
		d.call("_advance")
		await tool.call("wait_frames", 2)
	await _shoot(tool, out + "_2_dialogue.png")
