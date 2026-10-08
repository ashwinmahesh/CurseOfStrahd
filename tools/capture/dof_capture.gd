extends Node
## The Modern look's depth of field at each strength (Atmosphere.DOF_STRENGTHS), the same views, for the owner to pick.
## make capture SCENE=res://tools/capture/dof_capture.tscn NAME=dof FRAMES=30 (DOF_ONLY=light,tilt: only these)

var root: Node


func _ready() -> void:
	Look.set_style("modern", false)
	GameSettings.set_value("depth_blur", true, false)   # cache only: never the owner's settings file
	var d := Weather.data().duplicate(true)
	for c: String in d["climates"]:
		d["climates"][c] = {"overcast": 1}   # the same sky every shot, not a fog day
	Weather.use(d)
	GameState.reset()
	for id: String in ["godrick_pendlebrook", "liriel_dawnsong", "thistle", "ratatoille"]:
		var ch := Pregens.build(id, 3)
		ch.finish_long_rest()
		GameState.story.party.append(ch)
	GameState.story.location = "village_of_barovia"
	GameState.story.minute_of_day = 14 * 60
	for c: Dictionary in Cutscenes.all():
		Cutscenes.mark_played(str(c["id"]), GameState.story)   # an arrival's picture would cover the shot
	root = (load("res://scenes/game.tscn") as PackedScene).instantiate()
	add_child(root)


func capture_shots(tool: Node, out: String) -> void:
	var hud := root.get("hud") as ExploreHud
	var only := OS.get_environment("DOF_ONLY").split(",", false)   # e.g. DOF_ONLY=light,tilt
	for strength: String in Atmosphere.DOF_STRENGTHS:
		if not only.is_empty() and not strength in only:
			continue
		Atmosphere.dof_strength = strength
		for where: String in ["village_of_barovia", "tser_pool", "death_house_ground"]:
			root.call("enter_location", where, "default")
			await tool.call("wait_frames", 45)
			hud.close_narration()
			await tool.call("wait_frames", 10)
			tool.call("_shot", "%s_%s_%s.png" % [out, strength, where])
