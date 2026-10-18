extends TestCase
## The faceless god in the great hall (Amber Temple Look Plan step 7, FacelessGod): the 2 x 2 block of wall it stands on is
## three steps of black stone (the squares still block), the statue stands on the top step facing south, a void takes its
## face, a cold shaft falls on the offerings at its feet, and six pilgrims' candles burn there; Classic keeps the block.


func before_each() -> void:
	GameState.reset()
	for id: String in ["ilse_varga", "tamsin_tealeaf", "hedda_ironvow", "silvain_aster"]:
		var ch := Pregens.build(id, 1)
		ch.finish_long_rest()
		GameState.story.party.append(ch)
	Look.set_style("modern", false)


func after_each() -> void:
	Look.set_style(Look.DEFAULT_STYLE, false)


func _view() -> LocationView:
	var v := LocationView.create("amber_temple_faceless_god", GameState.story, null, Dice.roller, "default")
	add_child(v)
	return v


func _frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame


func test_the_block_is_three_steps_and_still_blocks() -> void:
	var v := _view()
	await _frames(3)
	var steps := v.board.find_children("Step*", "MeshInstance3D", true, false)
	assert_eq(steps.size(), FacelessGod.STEPS.size(), "three steps")
	var top := 0.0
	for s: Vector2 in FacelessGod.STEPS:
		top += s.y
	assert_true(top > 1.0 and top < 1.6, "low enough to see the whole god over (%.2f)" % top)
	for cell: Vector2i in [Vector2i(19, 8), Vector2i(20, 8), Vector2i(19, 9), Vector2i(20, 9)]:
		assert_true(v.grid.has_flag(cell, CombatGrid.WALL), "%s still blocks" % cell)
		assert_true(is_equal_approx(FacelessGod.top_at(v.board, cell), top), "%s is part of the steps" % cell)
	assert_true(is_zero_approx(FacelessGod.top_at(v.board, Vector2i(19, 10))), "the offerings' square is not")
	var widest := 0.0
	for s in steps:
		widest = maxf(widest, ((s as MeshInstance3D).mesh as BoxMesh).size.x)
	assert_true(widest <= 2.001, "no step reaches past the block (%.2f)" % widest)
	for s in steps:
		assert_true((s as MeshInstance3D).is_visible_in_tree(), "%s shows (the statue's prop on the block's first square doesn't clear it)" % s.name)
	v.queue_free()


func test_the_statue_stands_on_the_steps_with_a_void_for_a_face() -> void:
	var v := _view()
	await _frames(3)
	var statue := v.prop_nodes.get("faceless_statue") as Node3D
	assert_true(statue != null, "the god is drawn")
	var model := statue.find_children("Model_*", "Node3D", false, false)
	assert_eq(model.size(), 1, "as one statue")
	var piece := model[0] as Node3D
	var top := FacelessGod.top_at(v.board, Vector2i(19, 8))
	assert_true(is_equal_approx(piece.position.y, v.board.cell_center(Vector2i(19, 8)).y + top), "on the top step (y %.2f)" % piece.position.y)
	assert_true(absf(piece.position.x - 20.0) < 0.01 and absf(piece.position.z - 9.0) < 0.01, "over the middle of the block (%s)" % piece.position)
	var face := statue.get_node_or_null("VoidFace") as MeshInstance3D
	assert_true(face != null, "a void takes its face")
	if face != null:
		assert_true(face.position.y > piece.position.y + 3.0 and face.position.y < piece.position.y + 5.0, "at the head (%.2f)" % (face.position.y - piece.position.y))
		assert_true(absf(face.position.x - piece.position.x) < 0.05, "in the middle")
	assert_true(statue.get_node_or_null("GodShaft") != null and statue.get_node_or_null("GodShaftPool") != null, "a shaft of light and its pool")
	v.queue_free()


func test_six_pilgrims_candles_burn_at_its_feet() -> void:
	var v := _view()
	await _frames(3)
	var count := 0
	for i in range(1, 7):
		var node := v.prop_nodes.get("pilgrim_candles_%d" % i) as Node3D
		assert_true(node != null, "candle cluster %d is drawn" % i)
		if node != null:
			count += 1
	assert_eq(count, 6, "six")
	# What keeps the gaze step and the offerings reachable: none of them stands on them.
	for p: Variant in v.loc["props"]:
		if str((p as Dictionary)["id"]).begins_with("pilgrim_candles_"):
			var cell := LocationView._cell((p as Dictionary)["cell"])
			assert_false(v.grid.has_flag(cell, CombatGrid.WALL) or v.grid.has_flag(cell, CombatGrid.LOW), "%s stands on open floor" % str((p as Dictionary)["id"]))
			assert_true(not cell in [Vector2i(19, 10), Vector2i(19, 11), Vector2i(20, 11)], "and not on the offerings or the gaze step")
	v.queue_free()


func test_classic_keeps_the_block() -> void:
	Look.set_style("classic", false)
	var v := _view()
	await _frames(3)
	assert_eq(v.board.find_children("Step*", "MeshInstance3D", true, false).size(), 0, "no steps in Classic")
	assert_true(is_zero_approx(FacelessGod.top_at(v.board, Vector2i(19, 8))), "the statue is not lifted")
	var statue := v.prop_nodes.get("faceless_statue") as Node3D
	assert_true(statue == null or statue.get_node_or_null("VoidFace") == null, "and has its face")
	# The block is its own stone, not painted wood (a plinth style must not paint the wall it leaves in Classic).
	var painted := BuildingKit.painted("crimson")
	for n in v.board.find_children("*", "MeshInstance3D", true, false):
		assert_true((n as MeshInstance3D).material_override != painted or painted == null, "nothing on the board is the wagon's crimson (%s)" % n.name)
	v.queue_free()
