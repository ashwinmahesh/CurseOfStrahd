extends TestCase
## 3D set pieces (docs/art/models.md, owner request 2026-10-06; everywhere after the Death House upper floor pilot):
## furniture, containers, hearths, panelled walls, doors and stairs are Blender models standing where the 2D pieces
## stood, each inside its own square and pickable; a place left out of the catalog keeps its 2D pieces.


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
		var entry: Variant = (cfg["art"] as Dictionary)[art]
		var ids: Array = []
		for v: Variant in ((entry as Dictionary).values() if entry is Dictionary else [entry]):
			ids.append_array(v as Array if v is Array else [v])
		for id: Variant in ids:
			assert_true(ModelPiece.has_model(str(id)), "model %s built for %s" % [id, art])
	for surface: String in cfg.get("walls", {}):
		assert_true(Look.cel_textured(surface) != null, "wall surface exists: " + surface)
		assert_true(ModelPiece.has_model(str((cfg["walls"] as Dictionary)[surface])), "model built for " + surface)
	var palette := JSON.parse_string(FileAccess.get_file_as_string(Look.PALETTE_JSON)) as Dictionary
	for id: String in ModelPiece.manifest():
		for m: String in ((ModelPiece.manifest()[id] as Dictionary).get("materials", []) as Array):
			if m.begins_with("pal_") or m.begins_with("glow_"):
				assert_true(palette.has(m.substr(m.find("_") + 1)), "%s's colour %s is in the palette" % [id, m])
			elif m.begins_with("spr_"):
				assert_true(SetDressing.has_art(m.trim_prefix("spr_")), "%s is painted with 2D art that exists: %s" % [id, m])
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
		if n.has_meta("wall_modules") and Rect2(0, 0, 10, 10).has_point(Vector2((n as Node3D).position.x, (n as Node3D).position.z)):
			panelled += 1
	assert_true(panelled >= 20, "the library's walls are panelled (%d wall squares)" % panelled)
	for id: String in ["stairs_down", "stairs_up"]:
		assert_eq(_models(v.exit_nodes[id] as Node).size(), 1, id + " are a model")
	var floors := 0
	for n in v.board.get_children():
		if ModelPiece._is_floor_box(v.board, n, Vector2i(17, 3)):
			floors += 1
			assert_false((n as Node3D).visible, "the stairwell opens the floor of its square")
	assert_eq(floors, 1, "the stairwell's square has its floor box")
	v.queue_free()


## A model stands inside its own square (furniture against a wall reaches the wall face, a hearth stands out from
## its wall), so the 3D pieces never cut into a wall or each other.
func test_models_stay_in_their_square() -> void:
	var problems: Array[String] = []
	var places := ModelPiece.settings().get("places", []) as Array
	if "*" in places:
		places = (Compendium.shared().tables["locations"] as Dictionary).keys()
	for loc_id: String in places:
		var v := _view(loc_id)
		await _frames(1)
		for m in _models(v.board):
			if not m.is_visible_in_tree():
				continue
			var box := _bounds(m)
			var info := ModelPiece.manifest()[str(m.get_meta("model"))] as Dictionary
			if bool(info.get("turns", false)):
				continue   # nature (trees, brambles, boulders) grows over its square's edges, as the 2D pieces did
			if bool(info.get("big", false)):
				continue   # building-sized pieces (a wagon) stand over several squares, clearing trees as the 2D ones do
			var mount := str(info["mount"])
			var cell := v.grid.cell_at(m.global_position)
			var room := Rect2(cell.x - 0.03, cell.y - 0.03, 1.06, 1.06)
			if m.has_meta("hung"):
				var n := m.global_basis.z.normalized()
				var front := v.grid.cell_at(m.global_position + n * 0.5)
				room = Rect2(front.x - 0.06, front.y - 0.06, 1.12, 1.12)
			var flat := Rect2(box.position.x, box.position.z, box.size.x, box.size.z)
			if not room.encloses(flat):
				problems.append("%s: %s at %s spills out of its square (%s)" % [loc_id, m.get_meta("model"), cell, flat])
		v.queue_free()
		await _frames(1)
	assert_eq(problems, [] as Array[String], "models in their squares")


## Owner report (2026-10-06): "ensure we are sizing resources according to how big they should be." Every 3D piece
## stands at about its real height (catalog "feet": a person is 6 ft, 1.2 units), its flames and pictures included.
## The feet of low, deep things (beds, tables) count their top seen from above, so a piece may stand down to half of
## it; nothing may be bigger than a third over.
func test_models_are_their_real_size() -> void:
	var feet := SetDressing.catalog().get("feet", {}) as Dictionary
	var problems: Array[String] = []
	var places: Array = ["death_house_upper", "death_house_ground", "village_of_barovia", "vallaki", "tser_pool", "old_bonegrinder",
		"krezk", "berez_baba_lysagas_hut", "yester_hill"]
	for loc_id: String in Compendium.shared().tables["locations"] as Dictionary:
		if loc_id.begins_with("castle_ravenloft"):
			places.append(loc_id)
	for loc_id: String in places:
		var v := _view(loc_id)
		await _frames(1)
		for m in _models(v.board):
			var art := str(m.get_meta("art"))
			var mount := str((ModelPiece.manifest()[str(m.get_meta("model"))] as Dictionary).get("mount", ""))
			if not feet.has(art) or mount.begins_with("stairs") or not m.is_visible_in_tree():
				continue   # stairs climb a full 7.5 ft storey (test_set_dressing checks them)
			var tall := _bounds_all(m).size.y
			var real := float(feet[art]) / 5.0
			if tall < real * 0.5 or tall > real * 1.35:
				var msg := "%s: %s %.2f units tall, really %.2f" % [loc_id, art, tall, real]
				if not msg in problems:
					problems.append(msg)
		v.queue_free()
		await _frames(1)
	assert_eq(problems, [] as Array[String], "off scale")


## The world box round everything a piece draws, its meshes and its sprites.
func _bounds_all(n: Node3D) -> AABB:
	var box := AABB()
	var first := true
	for c in n.find_children("*", "VisualInstance3D", true, false):
		var vi := c as VisualInstance3D
		if not vi.is_visible_in_tree() or vi is Light3D:
			continue
		var b := vi.global_transform * vi.get_aabb()
		box = b if first else box.merge(b)
		first = false
	return box


## Owner reports (2026-10-06): no piece overlaps another or a wall. In every location, by their real footprints: no
## two 3D pieces overlap, no 3D piece overlaps a standing 2D piece, and no 3D piece reaches into a wall or tree beside
## it (furniture against a wall and wall pieces touch its face; building-sized pieces clear the trees they stand
## among, as the 2D ones do). Nature (trees, brambles, boulders) may grow into each other, as it did in 2D.
func test_3d_pieces_dont_overlap() -> void:
	var problems: Array[String] = []
	var locs := Compendium.shared().tables["locations"] as Dictionary
	for loc_id: String in locs:
		var v := _view(loc_id)
		await _frames(1)
		var board := v.board
		var rects: Array[Array] = []   # [model id, cell, footprint, big]
		for m in _models(board):
			if not m.is_visible_in_tree() or m.has_meta("nature") or m.has_meta("ground_cover"):
				continue
			var info := ModelPiece.manifest()[str(m.get_meta("model"))] as Dictionary
			if str(info.get("mount", "")).begins_with("stairs") or str(info.get("mount", "")) == "door":
				continue   # stairs and door leaves fill their own square in the wall line
			var b := _bounds(m)
			rects.append([str(m.get_meta("model")), board.grid.cell_at(m.global_position), Rect2(b.position.x, b.position.z, b.size.x, b.size.z),
				bool(info.get("big", false))])
		for i in rects.size():
			var a := _shrink(rects[i][2] as Rect2)
			for j in range(i + 1, rects.size()):
				if a.intersects(_shrink(rects[j][2] as Rect2)):
					problems.append("%s: %s at %s overlaps %s at %s" % [loc_id, rects[i][0], rects[i][1], rects[j][0], rects[j][1]])
			if bool(rects[i][3]):
				continue
			for dx: int in [-1, 0, 1]:
				for dz: int in [-1, 0, 1]:
					var c := (rects[i][1] as Vector2i) + Vector2i(dx, dz)
					if (dx != 0 or dz != 0) and board.grid.in_bounds(c) and board.grid.has_flag(c, CombatGrid.WALL) \
							and not board.door_cells.has(c) and _drawn(board, c) and a.intersects(Rect2(c.x, c.y, 1, 1)):
						problems.append("%s: %s at %s reaches into the wall at %s" % [loc_id, rects[i][0], rects[i][1], c])
		for n in board.find_children("*", "Sprite3D", true, false):
			var sp := n as Sprite3D
			if not sp.is_visible_in_tree() or sp.has_meta("ground_cover") or sp in board.occluders or sp.axis != Vector3.AXIS_Z \
					or sp.billboard == BaseMaterial3D.BILLBOARD_DISABLED or _in_model(sp):
				continue
			var r := sp.texture.get_width() * sp.pixel_size * sp.global_basis.x.length() / 2.0 * 0.8
			var at := Vector2(sp.global_position.x, sp.global_position.z)
			for rect: Array in rects:
				var f := rect[2] as Rect2
				var near := Vector2(clampf(at.x, f.position.x, f.end.x), clampf(at.y, f.position.y, f.end.y))
				if near.distance_to(at) < r - 0.05:
					problems.append("%s: %s at %s overlaps the 2D %s" % [loc_id, rect[0], rect[1], sp.texture.resource_path.get_file()])
		v.queue_free()
		await _frames(1)
	assert_eq(problems, [] as Array[String], "overlaps")


## A footprint less 0.03 all round (touching isn't overlapping), never below a sliver.
func _shrink(r: Rect2) -> Rect2:
	var dx := minf(0.03, r.size.x / 2.0 - 0.001)
	var dz := minf(0.03, r.size.y / 2.0 - 0.001)
	return r.grow_individual(-dx, -dz, -dx, -dz)


func _drawn(board: ArenaBoard, c: Vector2i) -> bool:
	for n: Node3D in board.dressing.get(c, []):
		if n.visible:
			return true
	return false


func _in_model(node: Node) -> bool:
	var p := node.get_parent()
	while p != null:
		if p.has_meta("model"):
			return true
		p = p.get_parent()
	return false


## A place left out of the catalog's models3d places keeps its 2D pieces (how the pilot was shown, and how a place
## can stay 2D).
func test_a_place_left_out_keeps_its_2d_pieces() -> void:
	var cfg := ModelPiece.settings()
	var was: Variant = cfg.get("places", [])
	cfg["places"] = ["death_house_upper"]
	var v := _view("death_house_ground")
	await _frames(1)
	cfg["places"] = was
	assert_eq(_models(v.board).size(), 0, "no models on the ground floor")
	for n in v.board.get_children():
		assert_false(n.has_meta("wall_modules"), "no 3D panelling")
	v.queue_free()


## Owner request (2026-10-07): everything but the characters in 3D. The woods are 3D trees, as tall as the 2D ones
## were, in the map and in the land around it, and they fade when they stand between the camera and the party.
func test_the_woods_are_3d_trees() -> void:
	var v := _view("into_the_mists_road")
	await _frames(2)
	assert_eq(v.board.occluders.size(), 0, "no billboard trees left")
	assert_true(v.board.mesh_occluders.size() > 50, "3D trees in and around the map (%d)" % v.board.mesh_occluders.size())
	var tree := v.board.mesh_occluders[0]
	var box := AABB()
	for n in tree.find_children("*", "MeshInstance3D", true, false):
		box = box.merge((n as MeshInstance3D).global_transform * (n as MeshInstance3D).mesh.get_aabb())
	assert_true(box.size.y > 2.0 and box.size.y < 4.0, "a tree 10 to 20 ft tall (%.2f)" % box.size.y)
	var far := 0
	for n in v.find_children("Trees_*", "MultiMeshInstance3D", true, false):
		far += (n as MultiMeshInstance3D).multimesh.instance_count
		assert_true((n as MultiMeshInstance3D).multimesh.mesh is ArrayMesh, "the far trees are 3D meshes")
	assert_true(far > 0, "the forest beyond the edge is there")
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
	var before: Array[Material] = []
	for i in mi.mesh.get_surface_count():
		before.append(mi.get_surface_override_material(i))
	SetDressing.mark_looted(desk)
	for i in mi.mesh.get_surface_count():
		var m := mi.get_surface_override_material(i) as ShaderMaterial
		var key := "albedo" if Look.tint_key(m) == "albedo" else "tint"
		var a := ModelPiece.colour_of((before[i] as ShaderMaterial).get_shader_parameter(key))
		var b := ModelPiece.colour_of(m.get_shader_parameter(key))
		assert_true(b.v < a.v, "surface %d is darker once looted" % i)
	v.queue_free()
