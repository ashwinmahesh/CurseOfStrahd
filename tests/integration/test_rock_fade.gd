extends TestCase
## Cliff columns fade like trees (UI QA W-01, 2026-10-08): on Mount Baratok, the Tsolenka Pass and at the Werewolf Den
## the party arrived behind a wall of rock (catalog place_looks "rock_walls") and couldn't be seen at all.

var view: LocationView


func before_each() -> void:
	GameState.reset()
	for id: String in ["godrick_pendlebrook", "liriel_dawnsong", "thistle", "ratatoille"]:
		var ch := Pregens.build(id, 3)
		ch.finish_long_rest()
		GameState.story.party.append(ch)


func after_each() -> void:
	if view != null:
		view.queue_free()
		view = null
	GameState.reset()


func test_a_rock_between_the_camera_and_the_party_fades() -> void:
	view = LocationView.create("mount_baratok", GameState.story, null, Dice.roller, "default")
	add_child(view)
	for i in 2:
		await get_tree().process_frame
	var rocks: Array[Node3D] = []
	for n in view.board.mesh_occluders:
		# The columns are the board's own boxes (a tree is a model under its own node); duplicates lose their name.
		if is_instance_valid(n) and n is MeshInstance3D and n.get_parent() == view.board:
			rocks.append(n)
	assert_true(rocks.size() > 20, "the mountain's rock columns fade (%d)" % rocks.size())
	if rocks.is_empty():
		return
	# Stand the party just behind one rock, the camera beyond it on the other side.
	var rock := rocks[rocks.size() / 2]
	var focus := rock.global_position + Vector3(0, 0, -2.0)
	focus.y = 0.0
	var camera := rock.global_position + Vector3(0, 12.0, 10.0)
	for i in 10:
		view.board.fade_occluders(camera, focus, 0.2)
	assert_true((rock as GeometryInstance3D).transparency > 0.5, "the rock in the way is see-through (%.2f)" % (rock as GeometryInstance3D).transparency)
	# One well behind the party stays solid.
	var behind: Node3D = null
	for r in rocks:
		var rel := Vector2(r.global_position.x - focus.x, r.global_position.z - focus.z)
		if rel.length() > 6.0:
			behind = r
			break
	if behind != null:
		assert_eq((behind as GeometryInstance3D).transparency, 0.0, "a rock out of the way stays solid")
