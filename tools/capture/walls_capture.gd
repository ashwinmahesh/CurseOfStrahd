extends Node
## Walls in the party's way, from every side (the walls lane, 2026-10-17): each named place built as in the game with
## the party on the named square, shot from the camera's four headings at the play distance once the walls in the way
## have settled. Not part of the game.
##   WALLS_SPOTS="tsolenka_pass_guard_tower@10,8|amber_temple_vault@20,12" \
##     make capture SCENE=res://tools/capture/walls_capture.tscn NAME=walls/before FRAMES=10
## Shots are <out>_<place>_<x>_<z>_<heading>.png, the heading as kit_capture's yaw steps (0 from the south-west, 1 from
## the south-east, 2 from the north-east, m1 from the north-west).
## Environment: WALLS_SPOTS (places split by |, a place and its squares by @, as interiors_capture's INTERIORS_SPOTS);
## WALLS_YAWS=0,2 (default 0,1,2,-1); WALLS_DIST=13 (the play distance); WALLS_HOUR=12; WALLS_FLAGS=a,b=value (story
## flags set first); WALLS_LIT=1 (a work light, for a dark room); WALLS_LOAD=<folder> (a save.json there, such as a bug
## report's, shot where its party stands, named <out>_save_<heading>.png; read only). To find what draws something:
## WALLS_HIDE=Clutter,Surround (hides nodes whose names hold those), WALLS_NOSNOW=1 (no snow lying on surfaces).

const PARTY: Array[String] = ["godrick_pendlebrook", "liriel_dawnsong", "thistle", "ratatoille"]

var view: LocationView = null


func _ready() -> void:
	InputActions.ensure()


func capture_shots(tool: Node, out: String) -> void:
	var yaws: Array[int] = [0, 1, 2, -1]
	if OS.get_environment("WALLS_YAWS") != "":
		yaws.clear()
		for y: String in OS.get_environment("WALLS_YAWS").split(",", false):
			yaws.append(int(y))
	var dist := float(OS.get_environment("WALLS_DIST")) if OS.get_environment("WALLS_DIST") != "" else 13.0
	var hour := int(OS.get_environment("WALLS_HOUR")) if OS.get_environment("WALLS_HOUR") != "" else 12
	if OS.get_environment("WALLS_LOAD") != "":
		for yaw in yaws:
			_load(OS.get_environment("WALLS_LOAD"))
			await _shoot(tool, yaw, dist, "%s_save" % out)
	for part: String in OS.get_environment("WALLS_SPOTS").split("|", false):
		var bits := part.split("@", false)
		for b: String in bits.slice(1):
			var c := Vector2i(int(b.get_slice(",", 0)), int(b.get_slice(",", 1)))
			for yaw in yaws:
				_build(bits[0], c, hour)
				await _shoot(tool, yaw, dist, "%s_%s_%d_%d" % [out, bits[0], c.x, c.y])
	if view != null:
		view.queue_free()
		view = null


func _shoot(tool: Node, yaw: int, dist: float, name: String) -> void:
	for part: String in OS.get_environment("WALLS_HIDE").split(",", false):
		for n in view.find_children("*" + part + "*", "Node3D", true, false):
			(n as Node3D).visible = false
	if OS.get_environment("WALLS_NOSNOW") != "":
		view.atmosphere.set_process(false)
		RenderingServer.global_shader_parameter_set(&"world_snow", 0.0)
	view.rig.distance = dist
	view.rig.rotate_step(yaw)
	view.rig.snap_to_target()
	await tool.call("wait_frames", 45)
	tool.call("_shot", "%s_%s.png" % [name, "m%d" % -yaw if yaw < 0 else str(yaw)])


## The game in save.json in `dir`, at the place and squares it was saved at.
func _load(dir: String) -> void:
	if view != null:
		view.queue_free()
		view = null
	GameState.reset()
	SaveSystem.load_from(dir, "save")
	view = LocationView.create(GameState.story.location, GameState.story, Narrator.new(), Dice.roller, "")
	add_child(view)
	view.update_daylight()
	view.atmosphere.settle()
	_light()


func _build(loc_id: String, at: Vector2i, hour: int) -> void:
	if view != null:
		view.queue_free()
		view = null
	GameState.reset()
	for id: String in PARTY:
		var ch := Pregens.build(id, 3)
		ch.finish_long_rest()
		GameState.story.party.append(ch)
	GameState.story.minute_of_day = hour * 60
	for flag: String in OS.get_environment("WALLS_FLAGS").split(",", false):
		if flag.contains("="):
			GameState.story.flags[flag.get_slice("=", 0)] = flag.get_slice("=", 1)   # (a fight that would start on arrival, kept off)
		else:
			GameState.story.set_flag(flag)
	# The party arrives on the named square (a spawn of the shot's own), the others round it as on any arrival.
	var loc := Compendium.shared().get_entry("locations", loc_id)
	(loc["spawns"] as Dictionary)["walls_shot"] = [at.x, at.y]
	view = LocationView.create(loc_id, GameState.story, Narrator.new(), Dice.roller, "walls_shot")
	add_child(view)
	view.update_daylight()
	view.atmosphere.settle()
	_light()


func _light() -> void:
	if OS.get_environment("WALLS_LIT") != "":
		var env := view.get("_env") as Environment
		if env != null:
			env.ambient_light_energy = 2.2
		var lamp := OmniLight3D.new()
		lamp.light_color = Look.color("bone")
		lamp.omni_range = 16.0
		lamp.light_energy = 2.0
		view.rig.add_child(lamp)
		lamp.position = Vector3(0, 5, 0)
