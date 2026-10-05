class_name PartyController
extends Node3D
## Exploration control of the whole party (plan §5.2). The player moves the leader (WASD relative to
## the camera, or click a spot); the others hold formation slots behind the leader. Followers only
## path to their slot — they never choose where to go. Tab or 1-4 changes the leader.

## Formation slots in the leader's local space (x right, z behind), in marching order.
const FORMATION: Array[Vector3] = [Vector3(0, 0, 0), Vector3(-0.8, 0, 1.1), Vector3(0.8, 0, 1.1), Vector3(0, 0, 2.2)]

var members: Array[PartyMember] = []
var rig: CameraRig
var leader_index := 0
var _formation_facing := Vector3.FORWARD


func add_member(m: PartyMember) -> void:
	members.append(m)
	add_child(m)


func leader() -> PartyMember:
	return members[leader_index]


func set_leader(index: int) -> void:
	if members.is_empty():
		return
	leader_index = posmod(index, members.size())
	for i in members.size():
		members[i].set_leader_marker(i == leader_index)
	_formation_facing = leader().facing
	if rig:
		rig.follow = leader()
	GameState.leader_index = leader_index
	EventBus.leader_changed.emit(leader_index)


## Where member `i` should stand, by marching order counted from the leader.
func slot_position(i: int) -> Vector3:
	var order := posmod(i - leader_index, members.size())
	var f := _formation_facing
	var right := Vector3(-f.z, 0, f.x)
	var off := FORMATION[order]
	return leader().global_position + right * off.x - f * off.z


func command_move(point: Vector3) -> void:
	leader().move_to(point)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(&"cycle_leader"):
		set_leader(leader_index + 1)
	for i in 4:
		if event.is_action_pressed(StringName("select_member_%d" % (i + 1))) and i < members.size():
			set_leader(i)
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT:
			var hit: Variant = _ground_point(mb.position)
			if hit != null:
				command_move(hit as Vector3)


func _ground_point(screen_pos: Vector2) -> Variant:
	if rig == null:
		return null
	var cam := rig.camera
	var from := cam.project_ray_origin(screen_pos)
	var dir := cam.project_ray_normal(screen_pos)
	var q := PhysicsRayQueryParameters3D.create(from, from + dir * 200.0)
	var hit := get_world_3d().direct_space_state.intersect_ray(q)
	if hit.is_empty():
		var plane := Plane(Vector3.UP, 0.0)
		return plane.intersects_ray(from, dir)
	return hit["position"]


func _physics_process(delta: float) -> void:
	if members.is_empty():
		return
	var input := Input.get_vector(&"move_left", &"move_right", &"move_back", &"move_forward")
	var dir := Vector3.ZERO
	if input != Vector2.ZERO and rig:
		var b := rig.ground_basis()
		dir = (b[0] * input.y + b[1] * input.x).normalized()
	var lead := leader()
	lead.step(delta, dir)
	# Formation turns only when the leader really travels, so followers don't spin on the spot.
	if Vector3(lead.velocity.x, 0, lead.velocity.z).length() > 1.0:
		_formation_facing = _formation_facing.slerp(lead.facing, clampf(delta * 4.0, 0.0, 1.0)).normalized()
	for i in members.size():
		if i == leader_index:
			continue
		var slot := slot_position(i)
		if members[i].global_position.distance_to(slot) > 0.25:
			members[i].move_to(slot)
		members[i].step(delta)


func positions() -> Array[Vector3]:
	var out: Array[Vector3] = []
	for m in members:
		out.append(m.global_position)
	return out


func restore_positions(points: Array[Vector3]) -> void:
	for i in mini(points.size(), members.size()):
		members[i].global_position = points[i]
		members[i].stop()
