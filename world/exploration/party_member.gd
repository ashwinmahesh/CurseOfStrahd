class_name PartyMember
extends CharacterBody3D
## One adventurer in exploration. Moves only where the player (directly, or through formation
## following) sends it — never on its own judgment (plan pillar 2). Placeholder body until the
## Blender sprite pipeline delivers billboards.

const SPEED := 4.0
const ARRIVE := 0.12

var display_name := ""
var target: Vector3
var has_target := false
var facing := Vector3.FORWARD
var _ring: MeshInstance3D


static func create(name_: String, body_colour: String, trim_colour: String) -> PartyMember:
	var m := PartyMember.new()
	m.name = name_.to_pascal_case()
	m.display_name = name_
	var shape := CollisionShape3D.new()
	var cap := CapsuleShape3D.new()
	cap.radius = 0.28
	cap.height = 1.2
	shape.shape = cap
	shape.position.y = 0.6
	m.add_child(shape)

	var body := MeshInstance3D.new()
	var cm := CapsuleMesh.new()
	cm.radius = 0.26
	cm.height = 1.0
	body.mesh = cm
	body.position.y = 0.5
	body.material_override = Look.cel(body_colour)
	m.add_child(body)

	var head := MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = 0.2
	sm.height = 0.4
	head.mesh = sm
	head.position.y = 1.15
	head.material_override = Look.cel("skin")
	m.add_child(head)

	# A nose-like wedge so facing reads from any camera angle.
	var nose := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(0.14, 0.14, 0.22)
	nose.mesh = bm
	nose.position = Vector3(0, 0.75, -0.28)
	nose.material_override = Look.cel(trim_colour)
	m.add_child(nose)

	var label := Label3D.new()
	label.text = name_
	label.position.y = 1.6
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.font_size = 40
	label.pixel_size = 0.006
	label.outline_size = 10
	label.modulate = Look.color("vellum")
	label.outline_modulate = Look.color("void")
	label.no_depth_test = true
	# Draw after the post-process quad so names stay crisp and unquantized, like UI.
	label.render_priority = 10
	m.add_child(label)

	m._ring = MeshInstance3D.new()
	var tm := TorusMesh.new()
	tm.inner_radius = 0.36
	tm.outer_radius = 0.44
	m._ring.mesh = tm
	m._ring.position.y = 0.03
	m._ring.material_override = Look.cel("flame")
	(m._ring.material_override as ShaderMaterial).set_shader_parameter("emission", Look.color("candle"))
	m._ring.visible = false
	m.add_child(m._ring)
	return m


func set_leader_marker(on: bool) -> void:
	_ring.visible = on


func move_to(point: Vector3) -> void:
	target = Vector3(point.x, global_position.y, point.z)
	has_target = true


func stop() -> void:
	has_target = false
	velocity = Vector3.ZERO


## Moves with an explicit direction (keyboard), or toward the target, sliding along walls.
func step(delta: float, direction: Vector3 = Vector3.ZERO) -> void:
	var dir := direction
	if dir == Vector3.ZERO and has_target:
		var to := target - global_position
		to.y = 0
		if to.length() <= ARRIVE:
			stop()
		else:
			dir = to.normalized() * clampf(to.length() / 0.4, 0.35, 1.0)
	elif dir != Vector3.ZERO:
		has_target = false
	velocity.x = dir.x * SPEED
	velocity.z = dir.z * SPEED
	velocity.y = 0.0 if is_on_floor() else velocity.y - 20.0 * delta
	move_and_slide()
	var flat := Vector3(velocity.x, 0, velocity.z)
	if flat.length() > 0.2:
		facing = flat.normalized()
		var goal := atan2(-facing.x, -facing.z)
		rotation.y = lerp_angle(rotation.y, goal, clampf(delta * 14.0, 0.0, 1.0))
