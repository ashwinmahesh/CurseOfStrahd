extends Node3D
## Sprite resolution comparison (art QA): characters side by side through DirectionalSprite under the game's camera and
## screen pass, on a plain ground colour, each named underneath. Args after --:
##   --ids=a,b,… (art/sprites folders)  --labels=A,B,…  --distance=13 (the game's default zoom; 7 is the closest)
##   --dir=1 (eighths clockwise from facing the camera)  --show (a short show for the movie writer: standing, walking
##   round through the directions, attacking, then quits)
## make capture SCENE=res://tools/art/preview/hd_compare.tscn NAME=hd ARGS="--size=1920x1080 --ids=a,b --distance=7"

var _ids: Array[String] = ["godrick_pendlebrook"]
var _labels: Array[String] = []
var _distance := 13.0
var _dir := 1
var _show := false
## --sharpen=0,0.6,…: the crisp shader's sharpen per figure (a test of the setting).
var _sharpen: Array[float] = []
var _sprites: Array[DirectionalSprite] = []
var _rig: CameraRig


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
		elif a == "--show":
			_show = true
		elif a.begins_with("--sharpen="):
			for v: String in a.substr(10).split(","):
				_sharpen.append(float(v))
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
		# A copy of a sheet for comparison (zz_<id>_before) stands as tall as the character.
		var hid := id.trim_prefix("zz_").trim_suffix("_before")
		hid = "godrick_pendlebrook" if hid == "godrick" else hid
		var s := DirectionalSprite.create(DirectionalSprite.frames_for(id), CombatToken.height_for(hid))
		s.position = across * (i - (_ids.size() - 1) / 2.0) * gap
		add_child(s)
		s.facing = facing
		s.set_step_time(0.18)
		_sprites.append(s)
		if i < _sharpen.size():
			(s.material_override as ShaderMaterial).set_shader_parameter("sharpen", _sharpen[i])
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
	_rig = rig
	if _show:
		_run_show()


func _face(steps: int) -> void:
	var g := _rig.ground_basis()
	var angle := steps * PI / 4.0
	for s in _sprites:
		s.facing = (-g[0] * cos(angle) + g[1] * sin(angle)).normalized()


func _run_show() -> void:
	await get_tree().create_timer(1.5).timeout
	for steps: int in [1, 2, 3, 5, 6, 7, 0]:
		_face(steps)
		for s in _sprites:
			s.moving = true
		await get_tree().create_timer(1.4).timeout
	for s in _sprites:
		s.moving = false
	for steps: int in [1, 7]:
		_face(steps)
		await get_tree().create_timer(0.5).timeout
		for s in _sprites:
			s.attack()
		await get_tree().create_timer(1.6).timeout
	get_tree().quit()
