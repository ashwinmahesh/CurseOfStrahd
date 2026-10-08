extends TestCase
## The set dressing (docs/art/set_dressing.md): every location's props, containers and doors have art, pieces stand,
## hang and lie where they should, a prop on a tree's square takes its place, and towns are built of houses with
## roofs and yard walls instead of one box per square.


func before_each() -> void:
	GameState.reset()
	ModeController.force(ModeController.Mode.EXPLORATION)   # building a place can start a fight in it
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


## Owner request (2026-10-06): no brown placeholder boxes. Every thing in every location is dressed by the catalog,
## or deliberately left as an invisible spot, and the art it names exists.
func test_every_prop_and_container_has_art() -> void:
	var missing: Array[String] = []
	var locs := Compendium.shared().tables["locations"] as Dictionary
	for loc_id: String in locs:
		var loc := locs[loc_id] as Dictionary
		for key: String in ["props", "containers"]:
			for t: Variant in loc.get(key, []):
				var spec := t as Dictionary
				if SetDressing.look_for(spec, key == "containers").is_empty():
					missing.append("%s/%s (%s)" % [loc_id, spec.get("id", ""), spec.get("model", "")])
		for d: Variant in loc.get("doors", []):
			if not SetDressing.has_art(str(SetDressing.door_look(d as Dictionary).get("art", ""))):
				missing.append("%s door %s" % [loc_id, (d as Dictionary).get("id", "")])
	assert_eq(missing, [] as Array[String], "no art for")


func test_catalog_names_only_art_that_exists() -> void:
	var cat := SetDressing.catalog()
	var named: Array[String] = [str(cat.get("container_default", ""))]
	for table: String in ["models", "ids"]:
		for v: Variant in (cat[table] as Dictionary).values():
			if v is String:
				named.append(str(v))
			elif v is Dictionary:
				named.append(str((v as Dictionary)["art"]))
	for set_name: String in ["low_cover", "difficult"]:
		for arts: Variant in (cat[set_name] as Dictionary).values():
			for a: Variant in arts:
				named.append(str(a))
	for rule: Variant in (cat["doors"] as Dictionary)["rules"]:
		named.append(str((rule as Array)[1]))
	for a in named:
		assert_true(SetDressing.has_art(a), "art exists: " + a)


## Death House: doors are framed leaves in the wall line, the hearth hangs on the wall face, chests are billboards.
func test_death_house_doors_props_and_containers() -> void:
	var v := _view("death_house_ground")
	await _frames(2)
	var door := v.door_nodes["dh_den_door"] as Node3D
	var leaf := door.get_node_or_null("Leaf")
	assert_true(leaf is Sprite3D or (leaf != null and leaf.has_meta("model")), "the den door has a leaf (2D, or a 3D model)")
	assert_eq(door.position, v.board.cell_center(Vector2i(9, 5)), "in its square")
	assert_true(is_equal_approx(absf(door.rotation.y), PI / 2.0), "the wall runs north-south, so the leaf faces east-west")
	var hearth := v.prop_nodes["den_hearth"] as Node3D
	var piece := hearth.get_child(0) as Node3D
	if piece is Sprite3D:
		assert_eq((piece as Sprite3D).billboard, BaseMaterial3D.BILLBOARD_DISABLED, "hung flat")
	else:
		assert_true(piece.has_meta("model") and piece.global_basis.z.normalized().is_equal_approx(Vector3(0, 0, 1)),
			"a 3D hearth (docs/art/models.md) facing into the room")
	assert_true(absf(piece.position.z - 1.0) < 0.05, "on the wall's south face (the wall square is row 0)")
	var cabinet := v.container_nodes["den_gun_cabinet"] as Node3D
	var models := cabinet.find_children("Model_*", "Node3D", true, false)
	if not models.is_empty():
		# A 3D cabinet (docs/art/models.md): its back on the den's west wall face, facing east into the room.
		var box := _world_box(models[0] as Node3D)
		assert_true(absf(box.position.x - 1.0) < 0.02, "its back on the west wall's face (x %.3f)" % box.position.x)
		assert_true((models[0] as Node3D).global_basis.z.normalized().is_equal_approx(Vector3(1, 0, 0)), "facing into the room")
		var mi := (models[0] as Node3D).find_children("*", "MeshInstance3D", true, false)[0] as MeshInstance3D
		var was: Variant = (mi.get_surface_override_material(0) as ShaderMaterial).get_shader_parameter("albedo")
		v.mark_looted("den_gun_cabinet")
		var now: Variant = (mi.get_surface_override_material(0) as ShaderMaterial).get_shader_parameter("albedo")
		assert_true(ModelPiece.colour_of(now).v < ModelPiece.colour_of(was).v, "an emptied container dims")
		v.queue_free()
		return
	var pictures := cabinet.find_children("*", "Sprite3D", true, false)
	assert_false(pictures.is_empty(), "the hunting cabinet is a picture, not a box")
	var front := pictures[0] as Sprite3D
	assert_eq(front.billboard, BaseMaterial3D.BILLBOARD_DISABLED, "it stands flat against the den's west wall")
	assert_true(absf(front.global_position.x - (1.0 + 0.4)) < 0.05, "its front a little way out from the wall face")
	v.mark_looted("den_gun_cabinet")
	assert_true(front.modulate.v < 0.9, "an emptied container dims")
	v.queue_free()


## The signpost stands among the trees on the opening road: the tree on its square hides while it's there.
func test_a_prop_takes_a_trees_square() -> void:
	var v := _view("into_the_mists_road")
	await _frames(2)
	var cell := Vector2i(22, 12)
	var hidden := 0
	for n: Node3D in v.board.dressing.get(cell, []):
		if not n.visible:
			hidden += 1
	assert_true(hidden > 0, "the tree on the signpost's square is hidden")
	(v.prop_nodes["mists_signpost"] as Node).free()
	for n: Node3D in v.board.dressing.get(cell, []):
		assert_true(n.visible, "and comes back when the signpost goes")
	v.queue_free()


## The village is houses with roofs, not one box per wall square; its yard walls are low.
func test_village_houses_and_yard_walls() -> void:
	var v := _view("village_of_barovia")
	await _frames(2)
	var board := v.board
	assert_true(board.buildings.size() >= 8, "the village has its houses (%d)" % board.buildings.size())
	for b: Dictionary in board.buildings:
		assert_true((b["upper"] as Node3D).get_node_or_null("Roof") != null, "each house has a roof")
	assert_true(board.house_cells.has(Vector2i(6, 2)), "the burgomaster's mansion is a house")
	var yard := 0
	for c in board.get_children():
		if str(c.name).contains("YardWall"):
			yard += 1
	assert_true(yard > 0, "yard walls are built")
	# A house between the camera and the party is cut away.
	var b0 := board.buildings[0]
	var aabb := b0["aabb"] as AABB
	var behind := aabb.get_center() + Vector3(0, -aabb.size.y / 2.0, -aabb.size.z / 2.0 - 1.0)
	board.cut_buildings(behind + Vector3(0, 5, 12), behind, 1.0)
	assert_false((b0["upper"] as Node3D).visible, "its roof hides")
	board.cut_buildings(behind + Vector3(0, 5, -14), behind, 1.0)
	assert_true((b0["upper"] as Node3D).visible, "and comes back")
	v.queue_free()


## Owner request (2026-10-06): a piece keeps its facing when the camera turns. Seen from in front it shows its front
## (mirrored for the other front corner); from behind, its back.
func test_props_keep_their_facing() -> void:
	var front_tex := PlaceholderTexture2D.new()
	front_tex.size = Vector2(40, 30)
	var back_tex := PlaceholderTexture2D.new()
	back_tex.size = Vector2(40, 32)
	var p := PropView.create(front_tex, 0.01, back_tex, 0.01, Vector3(0, 0, 1))
	add_child(p)
	p.update_view(Vector3(-5, 5, 5), Vector3(1, 0, 1).normalized())   # the opening camera, south-west
	assert_eq(p.texture, front_tex, "from the south it shows its front")
	var first_flip := p.flip_h
	p.update_view(Vector3(5, 5, 5), Vector3(1, 0, -1).normalized())    # turned: south-east
	assert_eq(p.texture, front_tex)
	assert_ne(p.flip_h, first_flip, "from the other front corner, mirrored")
	p.update_view(Vector3(5, 5, -5), Vector3(-1, 0, -1).normalized())  # north-east: behind it
	assert_eq(p.texture, back_tex, "from behind it shows its back")
	p.queue_free()


## Owner report (2026-10-06): pointing at the top of a tall piece picked the square behind it. The hunting cabinet
## stands against the den's west wall; its upper half covers squares further back, and pointing there picks it.
func test_pointing_at_a_tall_piece_picks_it() -> void:
	var v := _view("death_house_ground")
	await _frames(2)
	var cam := v.rig.camera
	var cabinet := v.container_nodes["den_gun_cabinet"] as Node3D
	var high: Vector3
	var models := cabinet.find_children("Model_*", "Node3D", true, false)
	if not models.is_empty():
		var box := _world_box(models[0] as Node3D)   # a 3D cabinet: the top of its front
		high = Vector3(box.end.x, box.position.y + box.size.y * 0.85, box.get_center().z)
	else:
		var front := cabinet.find_children("*", "Sprite3D", true, false)[0] as Sprite3D
		var tall := front.texture.get_height() * front.pixel_size
		high = front.global_position + Vector3(0, tall * 0.85, 0)
	var screen := cam.unproject_position(high)
	assert_ne(GridPick.cell_under(cam, v.grid, screen), Vector2i(1, 9), "the floor under that point is another square")
	assert_eq(v.pick_cell(cam, screen), Vector2i(1, 9), "pointing at the cabinet's top picks the cabinet")
	assert_eq(str(v.thing_at(v.pick_cell(cam, screen)).get("kind", "")), "container")
	v.queue_free()


## Owner report (2026-10-06): some pieces overlapped walls or each other. In every location, no two standing pieces
## on different squares overlap, a piece wider than its square has open floor all round it, and no two pieces hang on
## the same wall face.
func test_no_piece_overlaps_another_or_a_wall() -> void:
	var problems: Array[String] = []
	var locs := Compendium.shared().tables["locations"] as Dictionary
	for loc_id: String in locs:
		var v := _view(loc_id)
		await _frames(1)
		var board := v.board
		var standing: Array[Sprite3D] = []
		var hung := {}
		for n in board.find_children("*", "Sprite3D", true, false):
			var sp := n as Sprite3D
			if not sp.is_visible_in_tree() or sp.has_meta("ground_cover") or sp in board.occluders or sp.axis != Vector3.AXIS_Z:
				continue
			if _in_model(sp):
				continue   # the painted part of a 3D piece (docs/art/models.md); test_models_3d keeps models in their squares
			if sp.billboard == BaseMaterial3D.BILLBOARD_DISABLED:
				if sp.get_parent().name.begins_with("AgainstWall") or sp.get_parent().name.begins_with("Door") or sp.name == "Leaf":
					continue
				var key := "%.2f,%.2f,%.2f" % [sp.global_position.x, sp.global_position.z, sp.global_rotation.y]
				if hung.has(key):
					problems.append("%s: two pieces hung at %s" % [loc_id, key])
				hung[key] = true
				continue
			standing.append(sp)
		for i in standing.size():
			var a := standing[i]
			var ra := a.texture.get_width() * a.pixel_size * a.global_basis.x.length() / 2.0
			var ca := board.grid.cell_at(a.global_position)
			if board.grid.has_flag(ca, CombatGrid.WALL):
				continue   # it stands in for the wall block itself (a camp's wagons)
			# A building-sized piece (a cottage, a dead tree over a yard wall) may reach past walls; it clears the
			# trees it stands among instead.
			if ra > 0.55 and not (a.has_meta("art") and SetDressing.is_big(str(a.get_meta("art")))):
				for dx: int in [-1, 0, 1]:
					for dy: int in [-1, 0, 1]:
						var nb := ca + Vector2i(dx, dy)
						if (dx != 0 or dy != 0) and board.grid.in_bounds(nb) and board.grid.has_flag(nb, CombatGrid.WALL) \
								and not board.house_cells.has(nb) and _drawn(board, nb):
							var msg := "%s: %s at %s is %.2f wide beside a wall" % [loc_id, a.texture.resource_path.get_file(), ca, ra * 2.0]
							if not msg in problems:
								problems.append(msg)
			for j in range(i + 1, standing.size()):
				var b := standing[j]
				var cb := board.grid.cell_at(b.global_position)
				if ca == cb or board.grid.has_flag(cb, CombatGrid.WALL) or not b.is_visible_in_tree():
					continue
				var rb := b.texture.get_width() * b.pixel_size * b.global_basis.x.length() / 2.0
				var d := Vector2(a.global_position.x - b.global_position.x, a.global_position.z - b.global_position.z).length()
				if d < ra + rb - 0.15:
					problems.append("%s: %s at %s overlaps %s at %s" % [loc_id, a.texture.resource_path.get_file(), ca,
						b.texture.resource_path.get_file(), cb])
		v.queue_free()
		await _frames(1)
	assert_eq(problems, [] as Array[String], "overlaps")


## Rooms have their own surfaces (owner request 2026-10-06): every surface the catalog's room rules and place looks
## name, and every area's own `floor` and `walls`, is a texture that exists.
func test_room_and_place_surfaces_exist() -> void:
	var cat := SetDressing.catalog()
	var named: Array[String] = []
	for rule: Variant in cat.get("rooms", []):
		for v: Variant in ((rule as Array)[1] as Dictionary).values():
			named.append(str(v))
	for look: Variant in (cat.get("place_looks", {}) as Dictionary).values():
		for k: String in look:
			if k != "keep":   # `keep` says the look holds in every room; it isn't a surface
				named.append(str((look as Dictionary)[k]))
	var locs := Compendium.shared().tables["locations"] as Dictionary
	for loc_id: String in locs:
		for a: Variant in (locs[loc_id] as Dictionary).get("areas", []):
			for key: String in ["floor", "walls"]:
				if (a as Dictionary).has(key):
					named.append(str((a as Dictionary)[key]))
	for s in named:
		assert_true(Look.cel_textured(s) != null, "texture exists: " + s)


## A bathroom reads as a bathroom: its tiles come from the room rules by the area's name.
func test_a_bathroom_has_tiles() -> void:
	var v := _view("death_house_third")
	await _frames(2)
	var tiles := Look.cel_textured("interior/tile_floor", 0.22)
	var found := false
	for n in v.board.get_children():
		if n is MeshInstance3D and (n as MeshInstance3D).material_override == tiles:
			found = true
			break
	assert_true(found, "the bathroom's floor is tiled")
	v.queue_free()


## Death House book check: the attic's secret stair down isn't drawn until it's found, and is once it is. A door that's
## only barred stays drawn.
func test_a_secret_stair_shows_only_once_found() -> void:
	var v := _view("death_house_attic")
	await _frames(2)
	var stair := v.exit_nodes.get("secret_stair_down", null) as Node3D
	assert_true(stair != null, "the secret stair has a piece")
	if stair == null:
		return
	assert_false(stair.visible, "not drawn before anyone finds it")
	GameState.story.set_flag("death_house_secret_stair_found")
	v.refresh_exits()
	assert_true(stair.visible, "drawn once found")
	v.queue_free()
	var village := _view("village_of_barovia")
	await _frames(2)
	var door := village.exit_nodes.get("mansion_door", null) as Node3D
	assert_true(door != null and door.visible, "the burgomaster's barred door is still drawn")
	village.queue_free()


## Whether a wall square's scenery is drawn (a big piece hides the trees it stands among).
func _drawn(board: ArenaBoard, c: Vector2i) -> bool:
	for n: Node3D in board.dressing.get(c, []):
		if n.visible:
			return true
	return false


## Owner report (2026-10-06): the opening road's cottage was drawn far too small. Every standing piece with a real
## height (catalog "feet") is drawn close to it in every location, people being 6 ft (1.2 units).
func test_pieces_are_drawn_at_their_real_size() -> void:
	var feet := SetDressing.catalog().get("feet", {}) as Dictionary
	var problems: Array[String] = []
	var locs := Compendium.shared().tables["locations"] as Dictionary
	for loc_id: String in locs:
		var v := _view(loc_id)
		await _frames(1)
		for n in v.board.find_children("*", "Node3D", true, false):
			if not n.has_meta("art") or not feet.has(str(n.get_meta("art"))):
				continue
			var art := str(n.get_meta("art"))
			if n.has_meta("model"):
				continue   # a 3D piece is built at its real size (docs/art/models.md); test_models_3d checks it
			var sp: Sprite3D = n as Sprite3D if n is Sprite3D else null
			if sp == null:
				var inner := n.find_children("*", "Sprite3D", true, false)
				if inner.is_empty():
					continue
				sp = inner[0] as Sprite3D
			var info := SetDressing.manifest()[art] as Dictionary
			var px := (sp as PropView).front_pixel if sp is PropView else sp.pixel_size
			var drawn := float(info["world_height"]) * px / float(info["pixel_size"]) * sp.global_basis.y.length()
			var real := float(feet[art]) / 5.0
			if drawn < real * 0.7 or drawn > real * 1.35:
				var msg := "%s: %s drawn %.2f units tall, really %.2f" % [loc_id, art, drawn, real]
				if not msg in problems:
					problems.append(msg)
		v.queue_free()
		await _frames(1)
	assert_eq(problems, [] as Array[String], "off scale")
	# The opening road's cottage in particular: full size, and the trees around it cleared.
	var road := _view("into_the_mists_road")
	await _frames(1)
	var cottage := road.prop_nodes["edge_cottage_shutters"] as Node3D
	var models := cottage.find_children("Model_*", "Node3D", true, false)
	if not models.is_empty():
		assert_true(_world_box(models[0] as Node3D).size.y > 3.0, "the 3D cottage stands about 16 ft tall")
	else:
		var pic := cottage.find_children("*", "Sprite3D", true, false)[0] as Sprite3D
		assert_true(pic.texture.get_height() * pic.pixel_size > 3.0, "the cottage stands about 16 ft tall")
	for d: Vector2i in [Vector2i(-1, 0), Vector2i(0, 1), Vector2i(-1, 1)]:
		assert_false(_drawn(road.board, Vector2i(6, 9) + d), "no tree in front of the cottage at %s" % (Vector2i(6, 9) + d))
	road.queue_free()


## Owner report (2026-10-06): a bookcase stood at an angle instead of flat against its wall. In every location, a
## piece hung on a wall or standing against one is square to it with the wall behind it, and furniture that has a
## front view is never drawn as a turning billboard.
func test_wall_pieces_sit_flush_with_their_wall() -> void:
	var problems: Array[String] = []
	var locs := Compendium.shared().tables["locations"] as Dictionary
	for loc_id: String in locs:
		var v := _view(loc_id)
		await _frames(1)
		var board := v.board
		for n in board.find_children("*", "Node3D", true, false):
			var node := n as Node3D
			if node is Sprite3D and _in_model(node):
				continue   # a 3D piece's painted part (docs/art/models.md): the piece itself is checked through its holder
			var against := node.has_meta("against_wall")
			if against or node.has_meta("hung") or (node is Sprite3D and (node as Sprite3D).billboard == BaseMaterial3D.BILLBOARD_DISABLED \
					and (node as Sprite3D).axis == Vector3.AXIS_Z and node.name != "Leaf" and not node.get_parent().has_meta("against_wall") \
					and not node.get_parent().has_meta("door") and not node.get_parent().name == "Upper"):
				var yaw := node.global_rotation.y
				if absf(yaw / (PI / 2.0) - roundf(yaw / (PI / 2.0))) > 0.01:
					problems.append("%s: %s turned %.0f degrees off its wall" % [loc_id, node.name, rad_to_deg(yaw)])
					continue
				var facing := node.global_basis.z
				# (A tent's pieces stand off its canvas, which stands in from the wall square's face: ArenaBoard.wall_inset.)
				var behind := node.global_position - Vector3(facing.x, 0, facing.z).normalized() * ((0.55 if against else 0.05) + board.wall_inset)
				var c := board.grid.cell_at(behind)
				var backed := board.grid.has_flag(c, CombatGrid.WALL) or board.door_cells.has(c)
				if against and SetDressing.backing_side(board, board.grid.cell_at(node.global_position)) == Vector2i.ZERO:
					backed = true   # free-standing furniture, back to the north
				if not backed:
					problems.append("%s: %s at %s has no wall behind it" % [loc_id, node.name, board.grid.cell_at(node.global_position)])
			elif node is Sprite3D and (node as Sprite3D).billboard != BaseMaterial3D.BILLBOARD_DISABLED and node.has_meta("art") \
					and SetDressing.front_of(str(node.get_meta("art"))) != "":
				problems.append("%s: %s drawn as a billboard" % [loc_id, node.get_meta("art")])
		v.queue_free()
		await _frames(1)
	assert_eq(problems, [] as Array[String], "not flush")


## Is this node part of a 3D model (ModelPiece)?
func _in_model(node: Node) -> bool:
	var p := node.get_parent()
	while p != null:
		if p.has_meta("model"):
			return true
		p = p.get_parent()
	return false


## Owner report (2026-10-06): stairs looked too small and the stairwell down like an odd icon. Stairs are steps now:
## a flight up climbs most of a storey, a stairwell down opens the floor.
func test_stairs_are_steps_at_full_size() -> void:
	var v := _view("death_house_ground")
	await _frames(2)
	# Built steps (Stairs) or a 3D stair model (ModelPiece, docs/art/models.md): either way, real steps at full size.
	var up := _stair_piece(v.exit_nodes["stairs_up"] as Node3D, "StairsUp")
	assert_true(up != null, "the stairs up are a flight of steps")
	var top := _world_box(up).end.y - v.board.floor_y(v.grid.cell_at(up.global_position))
	assert_true(top >= 1.4, "about 7 ft high or more (%.2f)" % top)
	v.queue_free()
	var low := _view("death_house_dungeon_1")
	await _frames(2)
	var down := _stair_piece(low.exit_nodes["stairs_down"] as Node3D, "StairsDown")
	assert_true(down != null, "the stairs down are a stairwell")
	var depth := low.board.floor_y(low.grid.cell_at(down.global_position)) - _world_box(down).position.y
	assert_true(depth >= 1.3, "about 7 ft deep (%.2f)" % depth)
	low.queue_free()


## The built steps named `built`, or a 3D stair model, under an exit's piece; null if neither.
func _stair_piece(root: Node3D, built: String) -> Node3D:
	var found := root.find_children(built, "Node3D", true, false)
	if not found.is_empty():
		return found[0] as Node3D
	for n in root.find_children("Model_*", "Node3D", true, false):
		if n.has_meta("art") and str(n.get_meta("model", "")).begins_with("stairs"):
			return n as Node3D
	return null


func _world_box(n: Node3D) -> AABB:
	var box := AABB()
	var first := true
	for c in n.find_children("*", "MeshInstance3D", true, false):
		var mi := c as MeshInstance3D
		var b := mi.global_transform * mi.get_aabb()
		box = b if first else box.merge(b)
		first = false
	return box


## Owner report (2026-10-06): thin brown boards lay on the carpet among the party: their health bars. Out of a fight
## they're hidden.
func test_health_bars_only_in_fights() -> void:
	var v := _view("death_house_ground")
	await _frames(3)
	var tok := v.tokens[v.members[0].id] as CombatToken
	var bar := tok.get("_bar_back") as MeshInstance3D
	assert_false(bar.visible, "no health bar while exploring")
	v.queue_free()


## Owner report (2026-10-06): props in the secret study showed in the dark before the study was found. They stay
## hidden, also after the location's props are rebuilt (after a conversation).
func test_props_in_an_undiscovered_room_stay_hidden() -> void:
	var v := _view("death_house_upper")
	await _frames(3)
	var letter := v.prop_nodes.get("strahd_letter", null) as Node3D
	assert_true(letter != null and not letter.is_visible_in_tree(), "the letter in the secret study is hidden")
	v.refresh_npcs()
	await _frames(1)
	letter = v.prop_nodes.get("strahd_letter", null) as Node3D
	assert_true(letter != null and not letter.is_visible_in_tree(), "and stays hidden after the props are rebuilt")
	v.queue_free()


## Room rules are for rooms: Lake Zarovich's fishing landing isn't floored with a manor's marble, and its jetty is
## planks, not grass running into the lake.
func test_outdoor_areas_keep_outdoor_ground() -> void:
	var v := _view("lake_zarovich")
	await _frames(2)
	var marble := Look.cel_textured("interior/marble_floor", 0.22)
	var planks := Look.cel_textured("interior/wood_planks", 0.22)
	var saw_planks := false
	for n in v.board.get_children():
		if n is MeshInstance3D:
			var m := (n as MeshInstance3D).material_override
			assert_false(m == marble, "no marble floor outdoors")
			saw_planks = saw_planks or m == planks
	assert_true(saw_planks, "the jetty is planks")
	v.queue_free()
