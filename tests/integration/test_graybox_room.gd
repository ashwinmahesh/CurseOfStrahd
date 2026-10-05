extends TestCase
## The Phase 0 exit scene boots, the leader walks where told, and the party follows in formation.

const SCENE := preload("res://scenes/test/graybox_room.tscn")

var room: Node3D


func before_each() -> void:
	room = SCENE.instantiate() as Node3D
	add_child(room)
	await get_tree().physics_frame


func _party() -> PartyController:
	return room.get("party") as PartyController


func _frames(n: int) -> void:
	for i in n:
		await get_tree().physics_frame


func test_scene_builds_party_of_four() -> void:
	var p := _party()
	assert_eq(p.members.size(), 4)
	assert_eq(p.leader_index, 0)
	assert_true(room.get("post") != null, "post-process quad exists")


func test_leader_walks_to_clicked_point_and_party_follows() -> void:
	var p := _party()
	var goal := Vector3(5.0, 0, -1.0)
	room.call("debug_move_leader", goal)
	await _frames(240)
	var lead := p.leader()
	assert_true(Vector2(lead.global_position.x, lead.global_position.z).distance_to(Vector2(goal.x, goal.z)) < 0.3,
		"leader reached the goal, at %s" % lead.global_position)
	for i in range(1, 4):
		var d := p.members[i].global_position.distance_to(lead.global_position)
		assert_between(d, 0.5, 3.5, "follower %d keeps formation distance" % i)


func test_walls_stop_movement() -> void:
	var p := _party()
	room.call("debug_move_leader", Vector3(0, 0, -30))
	await _frames(300)
	assert_true(p.leader().global_position.z > -7.0, "north wall holds, z=%s" % p.leader().global_position.z)


func test_switching_leader_moves_the_marker_and_state() -> void:
	var p := _party()
	p.set_leader(2)
	assert_eq(GameState.leader_index, 2)
	assert_eq(p.leader().display_name, "Cleric")
	room.call("debug_move_leader", Vector3(-4.0, 0, 0.5))
	await _frames(240)
	assert_true(p.members[2].global_position.distance_to(Vector3(-4.0, p.members[2].global_position.y, 0.5)) < 0.4,
		"new leader moved")
