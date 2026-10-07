extends Node3D
## Lighting lab for character sprites (art QA, Improvement Ideas W6): figures on a lit floor at night under the moon,
## one with a torch behind it (the rim), one beside a warm lamp, one in the open, one in shadow; the Modern finish.
## Args after --: --classic (the Classic finish instead) --day --distance=9 --flash (a lightning flash)
## --motion: the figures stand, pace across, turn and are struck in turn, then it quits (motion between frames, G12;
## record with Godot's movie writer through tools/godot)
## make capture SCENE=res://tools/art/preview/lit_lab.tscn NAME=lit ARGS="--size=1920x1080"

const IDS: Array[String] = ["godrick_pendlebrook", "ireena", "villager", "wolf"]

var rig: CameraRig
var _sprites: Array[DirectionalSprite] = []


func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	Look.set_style("classic" if "--classic" in args else "modern", false)
	var day := "--day" in args
	var flash := "--flash" in args
	var distance := 9.0
	for a in args:
		if a.begins_with("--distance="):
			distance = float(a.substr(11))
	var env := WorldEnvironment.new()
	env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_COLOR
	env.environment.background_color = Look.color("void")
	env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.environment.ambient_light_color = Look.color("moon_blue") if not day else Look.color("vellum")
	env.environment.ambient_light_energy = (0.25 if not day else 0.7) * (3.5 if flash else 1.0)
	env.environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	add_child(env)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-50, 35, 0)
	sun.light_color = Look.color("frost") if not day else Look.color("vellum")
	sun.light_energy = (0.35 if not day else 1.1) * (4.0 if flash else 1.0)
	sun.shadow_enabled = true
	add_child(sun)
	var ground := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(40, 40)
	ground.mesh = pm
	ground.material_override = Look.cel("grave")
	add_child(ground)
	rig = CameraRig.new()
	add_child(rig)
	rig.distance = distance
	rig.snap_to_target()
	var g := rig.ground_basis()
	var across: Vector3 = g[1]
	var toward: Vector3 = -g[0]
	for i in IDS.size():
		var id := IDS[i]
		var s := DirectionalSprite.create(DirectionalSprite.frames_for(id), CombatToken.height_for(id))
		s.position = across * (i - 1.5) * 1.6
		add_child(s)
		s.facing = toward
		s.set_step_time(0.26)
		_sprites.append(s)
	# A torch behind the first figure (its rim), a warm lamp in front and to the side of the second.
	_lamp(across * (-1.5 * 1.6) - toward * 1.2 + Vector3(0, 1.2, 0), Look.color("flame"), 3.0)
	_lamp(across * (-0.5 * 1.6 + 0.9) + toward * 0.8 + Vector3(0, 1.0, 0), Look.color("candle"), 2.0)
	add_child(Look.make_post_process())
	if "--motion" in args:
		_motion(across, toward)


func _wait(seconds: float) -> void:
	await get_tree().create_timer(seconds).timeout


func _motion(across: Vector3, toward: Vector3) -> void:
	await _wait(2.5)   # standing: breathing
	for s in _sprites:
		s.facing = across
		s.moving = true
		create_tween().tween_property(s, "position", s.position + across * 1.2, 1.4)
	await _wait(1.4)
	for s in _sprites:
		s.moving = false
		s.facing = -across
	await _wait(1.0)
	for s in _sprites:
		s.facing = toward
	await _wait(1.0)
	for i in _sprites.size():
		_sprites[i].hurt()
		await _wait(0.5)
	await _wait(1.5)
	get_tree().quit()


func _lamp(at: Vector3, colour: Color, energy: float) -> void:
	var l := OmniLight3D.new()
	l.position = at
	l.light_color = colour
	l.light_energy = energy
	l.omni_range = 4.0
	l.shadow_enabled = true
	add_child(l)
