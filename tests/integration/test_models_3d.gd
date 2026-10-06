extends TestCase
## 3D set pieces (docs/art/models.md, owner request 2026-10-06): the Death House upper floor is the pilot. Its
## furniture, hearths, panelled walls, doors and stairs are Blender models standing where the 2D pieces stood, each
## inside its own square, pickable, and every other place keeps its 2D pieces until the owner signs off.


func before_each() -> void:
	GameState.reset()
	for id: String in ["ilse_varga", "tamsin_tealeaf", "hedda_ironvow", "silvain_aster"]:
		var ch := Pregens.build(id, 1)
		ch.finish_long_rest()
		GameState.story.party.append(ch)


func _view(loc_id: String) -> LocationView:
	var v := LocationView.create(loc_id, GameState.story, null, Dice.roller, "default")
	add_child(v)
	return v


func _frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame


func _models(n: Node) -> Array[Node3D]:
	var out: Array[Node3D] = []
	for c in n.find_children("Model_*", "Node3D", true, false):
		if c.has_meta("art"):
			out.append(c as Node3D)
	return out


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


## The catalog names only models that were built, for art that exists.
func test_catalog_models_exist() -> void:
	var cfg := ModelPiece.settings()
	assert_false((cfg.get("places", []) as Array).is_empty(), "the pilot names its places")
	for art: String in cfg.get("art", {}):
		assert_true(SetDressing.has_art(art), "it stands in for art that exists: " + art)
		assert_true(ModelPiece.has_model(str((cfg["art"] as Dictionary)[art])), "model built for " + art)
	for surface: String in cfg.get("walls", {}):
		assert_true(Look.cel_textured(surface) != null, "wall surface exists: " + surface)
		assert_true(ModelPiece.has_model(str((cfg["walls"] as Dictionary)[surface])), "model built for " + surface)
	var palette := JSON.parse_string(FileAccess.get_file_as_string(Look.PALETTE_JSON)) as Dictionary
	for id: String in ModelPiece.manifest():
		for m: String in ((ModelPiece.manifest()[id] as Dictionary).get("materials", []) as Array):
			if m.begins_with("pal_") or m.begins_with("glow_"):
				assert_true(palette.has(m.substr(m.find("_") + 1)), "%s's colour %s is in the palette" % [id, m])
			else:
				assert_true(m.begins_with("tex_") and Look.cel_textured(m.trim_prefix("tex_").replace("__", "/")) != null,
					"%s's surface %s exists" % [id, m])


## The library: its bookcases, desk, chair, hearth and furniture are models; its walls are panelled; the bookcase in
## front of the secret door stands flush with it, facing into the room (owner report 2026-10-06: it stood at an angle).
func test_the_library_is_built_of_models() -> void:
	var v := _view("death_house_upper")
	await _frames(2)
	var odd := _models(v.prop_nodes["library_odd_shelf"] as Node)
	assert_eq(odd.size(), 1, "the odd bookcase is a model")
	var shelf := odd[0]
	assert_eq(str(shelf.get_meta("model")), "bookcase")
	assert_true(shelf.global_basis.z.normalized().is_equal_approx(Vector3(0, 0, -1)), "it faces north, into the room")
	var box := _bounds(shelf)
	assert_true(absf(box.end.z - 9.0) < 0.02, "its back is on the secret door's face (z %.3f)" % box.end.z)
	assert_true(box.size.x < 1.0 and box.size.x > 0.85, "about a square wide")
	assert_true(absf(box.size.y - 1.4) < 0.05, "7 ft tall")
	for id: String in ["library_histories", "library_hearth", "library_chair"]:
		assert_eq(_models(v.prop_nodes[id] as Node).size(), 1, id + " is a model")
	assert_eq(_models(v.container_nodes["library_desk"] as Node).size(), 1, "the desk is a model")
	var hearth := _models(v.prop_nodes["library_hearth"] as Node)[0]
	assert_true(absf(_bounds(hearth).position.z - 1.0) < 0.02, "the hearth stands on the north wall's face")
	assert_true(hearth.find_children("*", "Sprite3D", true, false).size() > 0, "with a fire in it")
	var leaf := (v.door_nodes["library_door"] as Node3D).get_node_or_null("Leaf")
	assert_true(leaf != null and leaf.has_meta("model"), "the library door's leaf is a model")
	var panelled := 0
	for n in v.board.get_children():
		if n.name.begins_with("WallModules") and Rect2(0, 0, 10, 10).has_point(Vector2((n as Node3D).position.x, (n as Node3D).position.z)):
			panelled += 1
	assert_true(panelled >= 20, "the library's walls are panelled (%d wall squares)" % panelled)
	for id: String in ["stairs_down", "stairs_up"]:
		assert_eq(_models(v.exit_nodes[id] as Node).size(), 1, id + " are a model")
	v.queue_free()


## A model stands inside its own square (furniture against a wall reaches the wall face, a hearth stands out from
## its wall), so the 3D pieces never cut into a wall or each other.
func test_models_stay_in_their_square() -> void:
	var problems: Array[String] = []
	for loc_id: String in ModelPiece.settings().get("places", []):
		if loc_id == "*":
			continue
		var v := _view(loc_id)
		await _frames(1)
		for m in _models(v.board):
			if not m.is_visible_in_tree():
				continue
			var box := _bounds(m)
			var mount := str((ModelPiece.manifest()[str(m.get_meta("model"))] as Dictionary)["mount"])
			var cell := v.grid.cell_at(m.global_position)
			var room := Rect2(cell.x - 0.03, cell.y - 0.03, 1.06, 1.06)
			if mount == "wall":
				var n := m.global_basis.z.normalized()
				var front := v.grid.cell_at(m.global_position + n * 0.5)
				room = Rect2(front.x - 0.06, front.y - 0.06, 1.12, 1.12)
			var flat := Rect2(box.position.x, box.position.z, box.size.x, box.size.z)
			if not room.encloses(flat):
				problems.append("%s: %s at %s spills out of its square (%s)" % [loc_id, m.get_meta("model"), cell, flat])
		v.queue_free()
		await _frames(1)
	assert_eq(problems, [] as Array[String], "models in their squares")


## The pilot stays a pilot: places not listed keep their 2D pieces.
func test_other_places_keep_their_2d_pieces() -> void:
	var v := _view("death_house_ground")
	await _frames(1)
	assert_false("death_house_ground" in (ModelPiece.settings().get("places", []) as Array))
	assert_eq(_models(v.board).size(), 0, "no models on the ground floor")
	assert_true(v.board.find_children("WallModules*", "Node3D", false, false).is_empty(), "no 3D panelling")
	v.queue_free()


## Pointing at the top of the tall bookcase picks the bookcase's square, not the floor behind it.
func test_pointing_at_a_model_picks_it() -> void:
	var v := _view("death_house_upper")
	await _frames(2)
	var cam := v.rig.camera
	var shelf := _models(v.prop_nodes["library_histories"] as Node)[0]
	var box := _bounds(shelf)
	var high := box.get_center() + Vector3(0, box.size.y * 0.4, 0)
	var screen := cam.unproject_position(high)
	assert_ne(GridPick.cell_under(cam, v.grid, screen), Vector2i(2, 1), "the floor under that point is another square")
	assert_eq(v.pick_cell(cam, screen), Vector2i(2, 1), "pointing at the bookcase's top picks it")
	v.queue_free()


## An emptied container dims, models included.
func test_a_looted_desk_dims() -> void:
	var v := _view("death_house_upper")
	await _frames(1)
	var desk := v.container_nodes["library_desk"] as Node3D
	var mi := desk.find_children("*", "MeshInstance3D", true, false)[0] as MeshInstance3D
	var before := (mi.get_surface_override_material(0) as ShaderMaterial).get_shader_parameter("albedo") as Color
	SetDressing.mark_looted(desk)
	var after := (mi.get_surface_override_material(0) as ShaderMaterial).get_shader_parameter("albedo") as Color
	assert_true(after.v < before.v, "darker once looted")
	v.queue_free()
