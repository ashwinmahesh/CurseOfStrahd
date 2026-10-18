extends TestCase
## The model of Castle Ravenloft on the table in Exethanter's study (Amber Temple Look Plan step 12, CastleModel): built in
## code from the castle's own kit pieces, small enough for its table and standing on it, with its examine line in the
## Narrator's file; Classic keeps the table's picture.


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
	var v := LocationView.create("amber_temple_library", GameState.story, null, Dice.roller, "default")
	add_child(v)
	return v


func test_the_model_stands_on_its_table() -> void:
	var v := _view()
	await get_tree().process_frame
	var node := v.prop_nodes.get("castle_model") as Node3D
	assert_true(node != null, "the study has the model")
	var castle := node.find_child("CastleRavenloft", true, false) as MeshInstance3D
	assert_true(castle != null and castle.mesh != null, "the castle is one mesh built from the kit")
	var table := node.find_child("TableTop", true, false) as MeshInstance3D
	assert_true(table != null, "on a table")
	var box := castle.global_transform * castle.mesh.get_aabb()
	assert_true(box.size.x < CastleModel.TABLE_TOP.x and box.size.z < CastleModel.TABLE_TOP.z, "it fits the table (%.2f by %.2f)" % [box.size.x, box.size.z])
	assert_true(box.size.x > 0.5, "and is most of it across (%.2f)" % box.size.x)
	assert_true(box.size.y > 0.2 and box.size.y < 0.6, "its keep and towers stand up from it (%.2f)" % box.size.y)
	assert_true(box.position.y >= table.global_position.y - 0.05, "it stands on the table, not through it")
	assert_true(castle.mesh.get_surface_count() >= 2, "walls, spires and windows in their own materials")
	v.queue_free()


func test_the_line_is_in_the_narrators_file() -> void:
	var line := Narrator.new().line("examine:castle_model", GameState.story)
	assert_true(line.contains("Castle Ravenloft"), "the Narrator describes the model")
	assert_true(not "—" in line and line.split(" ", false).size() <= 45, "in a line or two, with no em-dash")


func test_classic_keeps_the_tables_picture() -> void:
	Look.set_style("classic", false)
	var v := _view()
	await get_tree().process_frame
	var node := v.prop_nodes.get("castle_model") as Node3D
	assert_true(node == null or node.find_child("CastleRavenloft", true, false) == null, "no model in Classic")
	v.queue_free()
