extends Node
## The Modern look's edge blur at each setting (Atmosphere.EDGE_BLURS) and with it off, the same views with the HUD
## showing, for the owner to pick.
## make capture SCENE=res://tools/capture/dof_capture.tscn NAME=blur/edge FRAMES=30 ARGS=--size=1920x1080
## (BLUR_ONLY=off,edges: only these; BLUR_AT=vallaki,krezk: these places instead of the Village of Barovia's)

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
	GameState.story.minute_of_day = 12 * 60 + 15
	for c: Dictionary in Cutscenes.all():
		Cutscenes.mark_played(str(c["id"]), GameState.story)   # an arrival's picture would cover the shot
	root = (load("res://scenes/game.tscn") as PackedScene).instantiate()
	add_child(root)


func capture_shots(tool: Node, out: String) -> void:
	var hud := root.get("hud") as ExploreHud
	var only := OS.get_environment("BLUR_ONLY").split(",", false)   # e.g. BLUR_ONLY=off,edges
	var places := OS.get_environment("BLUR_AT").split(",", false)
	if places.is_empty():
		places = PackedStringArray(["village_of_barovia"])
	var settings: Array = ["off"]
	settings.append_array(Atmosphere.EDGE_BLURS.keys())
	for where: String in places:
		root.call("enter_location", where, "default")
		await tool.call("wait_frames", 45)
		hud.close_narration()
		for setting: String in settings:
			if not only.is_empty() and not setting in only:
				continue
			GameSettings.set_value("depth_blur", setting != "off", false)   # cache only, as above
			GameSettings.set_value("blur_reach", "" if setting == "off" else setting, false)
			await tool.call("wait_frames", 10)
			tool.call("_shot", "%s_%s_%s.png" % [out, where, setting])
