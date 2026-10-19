extends TestCase
## Mount Baratok's look (the vault's "Mount Baratok Look Plan"): the stone hut stands at its real size next to the
## party, and the fights, exits and finds the map holds keep their squares.

const HUT := "baratok_hut"


func before_each() -> void:
	GameState.reset()
	for id: String in ["ilse_varga", "tamsin_tealeaf", "hedda_ironvow", "silvain_aster"]:
		var ch := Pregens.build(id, 3)
		ch.finish_long_rest()
		GameState.story.party.append(ch)


func _view() -> LocationView:
	var v := LocationView.create("mount_baratok", GameState.story, null, Dice.roller, "default")
	add_child(v)
	return v


func _frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame


## The world box around everything a model draws.
func _bounds(n: Node3D) -> AABB:
	var box := AABB()
	var first := true
	for c in n.find_children("*", "MeshInstance3D", true, false):
		var mi := c as MeshInstance3D
		var b := mi.global_transform * mi.mesh.get_aabb()
		box = b if first else box.merge(b)
		first = false
	return box


## Owner report (2026-10-19): "the stone hut sprite is tiny". The cottage was shrunk to keep clear of its own door
## square (ModelPiece.big_fit counts the exit as something standing there) to about half its size, a 7 ft hut the party
## stood taller than. It now stands a row back, against the rock, drawn at its `scale` times the modelled cottage.
func test_the_hut_stands_at_its_real_size() -> void:
	var v := _view()
	await _frames(2)
	var hut := v.prop_nodes.get(HUT) as Node3D
	assert_true(hut != null, "the hut is built")
	if hut == null:
		return
	var held := hut.find_children("Model_*", "Node3D", true, false)
	assert_false(held.is_empty(), "the hut is a 3D piece")
	if held.is_empty():
		return
	var model := held[0] as Node3D
	var size := (ModelPiece.manifest()[str(model.get_meta("model"))] as Dictionary)["size"] as Array
	var want := 1.0
	for p: Variant in (Compendium.shared().get_entry("locations", "mount_baratok") as Dictionary)["props"] as Array:
		if str((p as Dictionary)["id"]) == HUT:
			want = float((p as Dictionary).get("scale", 1.0))
	assert_true(want >= 1.0, "the hut asks for at least the cottage's own size (%.2f)" % want)
	var box := _bounds(model)
	assert_true(box.size.x >= float(size[0]) * want * 0.95, "the hut is as wide as asked (%.2f of %.2f)" % [box.size.x, float(size[0]) * want])
	assert_true(box.size.y >= float(size[1]) * want * 0.95, "and as tall (%.2f of %.2f)" % [box.size.y, float(size[1]) * want])
	# A party member is 1.2 units tall: the door stands over them, the eaves too.
	assert_true(box.size.y > 3.0, "the hut stands well over a person (%.2f units)" % box.size.y)
	# Its door side stays clear of the exit's square: the way in is the square in front of it.
	var door := Vector2i(25, 10)
	assert_false(Rect2(box.position.x, box.position.z, box.size.x, box.size.z).intersects(Rect2(door.x, door.y, 1, 1).grow(-0.12)),
		"the hut doesn't stand on its own doorstep")
	v.queue_free()
	await _frames(1)
