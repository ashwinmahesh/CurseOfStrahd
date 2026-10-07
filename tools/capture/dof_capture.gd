extends Node
## The Modern look's depth of field at each strength (Atmosphere.DOF_STRENGTHS), the same views, for the owner to pick.
## make capture SCENE=res://tools/capture/dof_capture.tscn NAME=dof FRAMES=30

var root: Node


func _ready() -> void:
	Look.set_style("modern", false)
	GameState.reset()
	for id: String in ["godrick_pendlebrook", "liriel_dawnsong", "thistle", "ratatoille"]:
		var ch := Pregens.build(id, 3)
		ch.finish_long_rest()
		GameState.story.party.append(ch)
	GameState.story.location = "village_of_barovia"
	root = (load("res://scenes/game.tscn") as PackedScene).instantiate()
	add_child(root)


func capture_shots(tool: Node, out: String) -> void:
	var hud := root.get("hud") as ExploreHud
	for strength: String in Atmosphere.DOF_STRENGTHS:
		Atmosphere.dof_strength = strength
		for where: String in ["village_of_barovia", "tser_pool", "death_house_ground"]:
			root.call("enter_location", where, "default")
			await tool.call("wait_frames", 45)
			hud.close_narration()
			await tool.call("wait_frames", 10)
			tool.call("_shot", "%s_%s_%s.png" % [out, strength, where])
