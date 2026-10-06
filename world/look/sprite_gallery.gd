extends Node3D
## Art QA for character animation (docs/art/animation.md): every character sprite in a lineup under the game's
## camera and screen pass, walking in place and attacking in turn, the facing stepping round all 8 directions.
## make capture SCENE=res://scenes/test/sprite_gallery.tscn [-- --ids=wolf,ilse_varga] shoots each phase.

const SPACING := 1.7
const PER_ROW := 8
## Seconds per phase: walk, then attack.
const WALK_TIME := 2.0
const ATTACK_TIME := 1.0

var rig: CameraRig
var sprites: Array[DirectionalSprite] = []
var ids: Array[String] = []
var _t := 0.0
var _facing_step := 0
var _attacking := false


func _ready() -> void:
	InputActions.ensure()
	ids = _ids_from_args()
	var env := WorldEnvironment.new()
	env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_COLOR
	env.environment.background_color = Look.color("void")
	add_child(env)
	var rows := ceili(float(ids.size()) / PER_ROW)
	var floor_mesh := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(PER_ROW * SPACING + 2.0, rows * SPACING + 2.0)
	floor_mesh.mesh = pm
	floor_mesh.material_override = Look.cel("grave")
	add_child(floor_mesh)
	for i in ids.size():
		var frames := DirectionalSprite.frames_for(ids[i])
		var s := DirectionalSprite.create(frames, float(CombatToken.HEIGHTS.get(ids[i], 1.2)))
		var row := floorf(float(i) / PER_ROW)
		s.position = Vector3((i % PER_ROW - (PER_ROW - 1) / 2.0) * SPACING, 0, (row - (rows - 1) / 2.0) * SPACING)
		s.set_step_time(0.18)
		add_child(s)
		sprites.append(s)
		var label := Label3D.new()
		label.text = ids[i]
		label.font_size = 28
		label.pixel_size = 0.006
		label.position = s.position + Vector3(0, -0.05, 0.45)
		label.rotation_degrees = Vector3(-90, 0, 0)
		label.modulate = Look.color("vellum")
		add_child(label)
	rig = CameraRig.new()
	add_child(rig)
	rig.distance = 4.0 + rows * 2.2
	rig.snap_to_target()
	add_child(Look.make_post_process())
	_set_facing()


func _ids_from_args() -> Array[String]:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--ids="):
			var out: Array[String] = []
			for id in a.substr(6).split(",", false):
				out.append(id)
			return out
	var all: Array[String] = []
	for d in DirAccess.get_directories_at("res://art/sprites"):
		if d != "villager_standin" and ResourceLoader.exists("res://art/sprites/%s/walk.tres" % d):
			all.append(d)
	return all


## Each lineup faces one of the 8 directions relative to the camera, a step further each round.
func _set_facing() -> void:
	var ground := rig.ground_basis()
	var angle := _facing_step * PI / 4.0
	# Ground direction `angle` clockwise from "toward the camera".
	var toward := -ground[0]
	var dir := (toward * cos(angle) + ground[1] * sin(angle)).normalized()
	for s in sprites:
		s.facing = dir


func _process(delta: float) -> void:
	_t += delta
	if not _attacking and _t >= WALK_TIME:
		_t = 0.0
		_attacking = true
		for s in sprites:
			s.attack()
	elif _attacking and _t >= ATTACK_TIME:
		_t = 0.0
		_attacking = false
		_facing_step = (_facing_step + 1) % 8
		_set_facing()
	for s in sprites:
		s.moving = not _attacking


## Capture: walking, then the wind-up and the strike of the attack, in two directions.
func capture_shots(tool: Node, out: String) -> void:
	for round_i in 2:
		_t = WALK_TIME * 0.5
		_attacking = false
		await tool.call("wait_frames", 20)
		tool.call("_shot", out + "_%d_walk.png" % round_i)
		_t = WALK_TIME
		await get_tree().process_frame
		await tool.call("wait_frames", 6)
		tool.call("_shot", out + "_%d_windup.png" % round_i)
		await tool.call("wait_frames", 10)
		tool.call("_shot", out + "_%d_strike.png" % round_i)
		await tool.call("wait_frames", 30)
		_facing_step = 2 if round_i == 0 else 1
		_set_facing()
