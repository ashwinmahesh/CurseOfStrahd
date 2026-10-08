extends Node
## The depth blur as the game draws it now (Atmosphere.EDGE_BLURS at Atmosphere.edge_blur()), for before-and-after
## pairs: Tser Pool exploring from the road, then its brawl a few turns in, with the camera at play distance.
## make capture SCENE=res://tools/capture/blur_capture.tscn NAME=blur/after FRAMES=10

var root: Node


func _ready() -> void:
	Look.set_style("modern", false)
	GameSettings.set_value("depth_blur", true, false)   # cache only: never the owner's settings file
	GameState.reset()
	for id: String in ["godrick_pendlebrook", "liriel_dawnsong", "thistle", "ratatoille"]:
		var ch := Pregens.build(id, 3)
		ch.finish_long_rest()
		GameState.story.party.append(ch)
	GameState.story.minute_of_day = 15 * 60
	GameState.story.location = "tser_pool"
	for c: Dictionary in Cutscenes.all():
		Cutscenes.mark_played(str(c["id"]), GameState.story)   # the arrival picture would cover the shots
	root = (load("res://scenes/game.tscn") as PackedScene).instantiate()
	add_child(root)


func capture_shots(tool: Node, out: String) -> void:
	var hud := root.get("hud") as ExploreHud
	var view := root.get("view") as LocationView
	await tool.call("wait_frames", 45)
	hud.close_narration()
	view.rig.distance = 16.0
	await tool.call("wait_frames", 20)
	tool.call("_shot", out + "_explore.png")
	view.start_encounter("tser_pool_brawl")
	await tool.call("wait_frames", 240)
	tool.call("_shot", out + "_fight.png")
