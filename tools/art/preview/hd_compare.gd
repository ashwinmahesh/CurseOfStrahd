extends Node3D
## Sprite resolution comparison (art QA): characters side by side through DirectionalSprite under the game's camera and
## screen pass, on a plain ground colour, each named underneath. Args after --:
##   --ids=a,b,… (art/sprites folders)  --labels=A,B,…  --distance=13 (the game's default zoom; 7 is the closest)
##   --dir=1 (eighths clockwise from facing the camera)
## make capture SCENE=res://tools/art/preview/hd_compare.tscn NAME=hd ARGS="--size=1920x1080 --ids=a,b --distance=7"

var _ids: Array[String] = ["godrick_pendlebrook"]
var _labels: Array[String] = []
var _distance := 13.0
var _dir := 1


func _ready() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--ids="):
			_ids.assign(a.substr(6).split(","))
		elif a.begins_with("--labels="):
			_labels.assign(a.substr(9).split(","))
		elif a.begins_with("--distance="):
			_distance = float(a.substr(11))
		elif a.begins_with("--dir="):
			_dir = int(a.substr(6))
	var env := WorldEnvironment.new()
	env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_COLOR
	env.environment.background_color = Look.color("grave")
	add_child(env)
	var rig := CameraRig.new()
	add_child(rig)
	rig.zoom_min = 1.0
	rig.distance = _distance
	rig.snap_to_target()
	var g := rig.ground_basis()
	var across: Vector3 = g[1]
	var angle := _dir * PI / 4.0
	var facing: Vector3 = (-g[0] * cos(angle) + g[1] * sin(angle)).normalized()
	var gap := 1.2 * _distance / 13.0
	for i in _ids.size():
		var id := _ids[i]
		var s := DirectionalSprite.create(DirectionalSprite.frames_for(id), CombatToken.height_for(_ids[0]))
		s.position = across * (i - (_ids.size() - 1) / 2.0) * gap
		add_child(s)
		s.facing = facing
		if i < _labels.size():
			var l := Label3D.new()
			l.text = _labels[i]
			l.font_size = 48
			l.pixel_size = 0.004 * _distance / 13.0
			l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
			l.position = s.position - g[0] * 0.45 + Vector3(0, 0.05, 0)
			l.modulate = Look.color("vellum")
			l.outline_modulate = Look.color("void")
			l.outline_size = 12
			add_child(l)
	add_child(Look.make_post_process())
