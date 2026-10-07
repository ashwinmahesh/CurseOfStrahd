extends Node3D
## Sharpness lab (art QA): characters through DirectionalSprite under the game's camera and screen pass, plainly, flashed
## red and half faded (the crisp sprite shader must keep modulate). make capture SCENE=res://tools/art/preview/sharp_lab.tscn

const IDS: Array[String] = ["godrick_pendlebrook", "thistle", "ratatoille", "liriel_dawnsong"]
const TINTS: Array[Color] = [Color.WHITE, Color(1.0, 0.25, 0.25), Color(1, 1, 1, 0.5), Color(1.3, 1.3, 1.3)]


func _ready() -> void:
	var env := WorldEnvironment.new()
	env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_COLOR
	env.environment.background_color = Look.color("grave")
	add_child(env)
	var line := Node3D.new()
	line.rotation.y = deg_to_rad(45.0)
	add_child(line)
	for i in IDS.size():
		var s := DirectionalSprite.create(DirectionalSprite.frames_for(IDS[i]), CombatToken.height_for(IDS[i]))
		s.position = Vector3((i - 1.5) * 1.3, 0, 0)
		s.modulate = TINTS[i]
		line.add_child(s)
	var rig := CameraRig.new()
	add_child(rig)
	rig.distance = 9.0
	rig.snap_to_target()
	add_child(Look.make_post_process())
