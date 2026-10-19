extends TestCase
## Walls as thick as walls (Natural Maps Plan I1, owner 2026-10-19: "we don't need to draw our real world maps as a
## battle grid ... a real natural map that we just overlay a grid on top afterwards"; docs/art/building_kit.md, "Thin
## walls"): the side of a wall square that faces a room is drawn set back into the square (catalog interiors
## "thin_walls", 0.35), so a wall between two rooms is 0.3 of a square thick, the floor runs on to its face, a doorway's
## frame and everything hung on a wall or backed onto it follow, and the rules grid stays what it was.

const DEATH_HOUSE := "death_house_ground"


func before_each() -> void:
	GameState.reset()
	ModeController.force(ModeController.Mode.EXPLORATION)
	for id: String in ["ilse_varga", "tamsin_tealeaf", "hedda_ironvow", "silvain_aster"]:
		var ch := Pregens.build(id, 1)
		ch.finish_long_rest()
		GameState.story.party.append(ch)


func after_each() -> void:
	Look.set_style(Look.DEFAULT_STYLE, false)


func _view(loc_id: String) -> LocationView:
	var v := LocationView.create(loc_id, GameState.story, null, Dice.roller, "default")
	add_child(v)
	return v


func _frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame


## The solid boxes of a wall node (the walls' own, a storey tall; not their caps or modules), in world space.
func _slabs(node: Node3D) -> Array[AABB]:
	var out: Array[AABB] = []
	for n in node.find_children("*", "MeshInstance3D", true, false):
		var mi := n as MeshInstance3D
		if mi.mesh is BoxMesh and (mi.mesh as BoxMesh).size.y > 1.0:
			out.append(mi.global_transform * mi.mesh.get_aabb())
	return out


func _merged(boxes: Array[AABB]) -> AABB:
	var box := boxes[0]
	for b in boxes:
		box = box.merge(b)
	return box


## The node InteriorWalls built for wall square `c` (a room wall or a block), or null.
func _wall_node(board: ArenaBoard, c: Vector2i) -> Node3D:
	for w: Dictionary in (board.get_meta("interior_walls", {}) as Dictionary).get("walls", []):
		if w["cell"] == c and not w.has("flanks"):
			return w["node"] as Node3D
	for n: Node in board.dressing.get(c, []):
		if n is Node3D and not n is MeshInstance3D and not _slabs(n as Node3D).is_empty():
			return n as Node3D   # (a block)
	return null


func _open(board: ArenaBoard, c: Vector2i) -> bool:
	return board.grid.in_bounds(c) and not board.grid.has_flag(c, CombatGrid.WALL) and not board.grid.has_flag(c, CombatGrid.VOID)


func test_a_wall_between_two_rooms_is_a_foot_and_a_half_thick() -> void:
	var v := _view(DEATH_HOUSE)
	await _frames(2)
	var board := v.board
	var st := board.get_meta("interior_walls", {}) as Dictionary
	var inset := float(st.get("inset", 0.0))
	assert_eq(inset, 0.35, "the Death House's walls are set back 0.35 of a square")
	assert_eq(board.wall_inset, -inset, "and the board says so, for what is hung on them")
	var found := 0
	for z in board.grid.depth:
		for x in board.grid.width:
			var c := Vector2i(x, z)
			if not board.grid.has_flag(c, CombatGrid.WALL) or (st["outside"] as Dictionary).has(c):
				continue
			var node := _wall_node(board, c)
			if node == null:
				continue   # a pillar, or a wall some piece took the square of
			var slabs := _slabs(node)
			if slabs.is_empty():
				continue
			var box := _merged(slabs)
			# A room on each of two opposite sides and walls on the others: a thin wall, the whole length of its square.
			var we := InteriorWalls.cuts(board, c, Vector2i(1, 0)) and InteriorWalls.cuts(board, c, Vector2i(-1, 0)) \
				and not _open(board, c + Vector2i(0, 1)) and not _open(board, c + Vector2i(0, -1))
			var ns := InteriorWalls.cuts(board, c, Vector2i(0, 1)) and InteriorWalls.cuts(board, c, Vector2i(0, -1)) \
				and not _open(board, c + Vector2i(1, 0)) and not _open(board, c + Vector2i(-1, 0))
			if (we or ns) and found < 6:
				var thick := box.size.x if we else box.size.z
				var length := box.size.z if we else box.size.x
				assert_between(thick, 1.0 - 2.0 * inset - 0.01, 1.0 - 2.0 * inset + 0.01, "the wall at %s is thin (%.2f)" % [c, thick])
				assert_between(length, 0.99, 1.01, "and the whole length of its square at %s" % c)
				found += 1
	assert_true(found >= 3, "the Death House has walls between rooms (%d)" % found)
	v.queue_free()


## Walls with no room beside them, not even at a corner, stay whole blocks: thick masonry.
func test_thick_masonry_stays_a_whole_block() -> void:
	var v := _view("castle_ravenloft_main_floor")
	await _frames(2)
	var board := v.board
	var st := board.get_meta("interior_walls", {}) as Dictionary
	assert_eq(float(st.get("inset", 0.0)), 0.35, "the castle's walls are thin too")
	var whole := 0
	for z in board.grid.depth:
		for x in board.grid.width:
			var c := Vector2i(x, z)
			if not board.grid.has_flag(c, CombatGrid.WALL) or (st["outside"] as Dictionary).has(c) \
					or not InteriorWalls._open_faces(board, c).is_empty() or whole >= 6:
				continue
			var corner := false
			for dz: int in [-1, 1]:
				for dx: int in [-1, 1]:
					corner = corner or _open(board, c + Vector2i(dx, dz))
			var node := _wall_node(board, c)
			if corner or node == null or _slabs(node).is_empty():
				continue
			var box := _merged(_slabs(node))
			assert_between(box.size.x, 0.99, 1.01, "the block at %s is a whole square" % c)
			assert_between(box.size.z, 0.99, 1.01, "both ways")
			whole += 1
	assert_true(whole >= 3, "the castle has thick masonry (%d)" % whole)
	v.queue_free()


## A room's inside corner: the wall square there has no room beside it, only one at its diagonal, and loses just that
## corner; the walls running into it keep their faces in line with it.
func test_a_rooms_corner_keeps_a_notch_and_its_faces_meet() -> void:
	var v := _view("castle_ravenloft_main_floor")
	await _frames(2)
	var board := v.board
	var inset := float((board.get_meta("interior_walls", {}) as Dictionary)["inset"])
	var checked := 0
	for z in range(1, board.grid.depth - 1):
		for x in range(1, board.grid.width - 1):
			var c := Vector2i(x, z)
			if not board.grid.has_flag(c, CombatGrid.WALL) or not InteriorWalls._open_faces(board, c).is_empty():
				continue
			var diag: Array[Vector2i] = []
			for dz: int in [-1, 1]:
				for dx: int in [-1, 1]:
					if _open(board, c + Vector2i(dx, dz)):
						diag.append(Vector2i(dx, dz))
			var node := _wall_node(board, c)
			if diag.size() != 1 or node == null or _slabs(node).is_empty() or checked >= 3:
				continue
			var area := 0.0
			for b in _slabs(node):
				area += b.size.x * b.size.z
			assert_between(area, 1.0 - inset * inset - 0.01, 1.0 - inset * inset + 0.01, "the corner at %s loses one corner of its square" % c)
			checked += 1
	assert_true(checked >= 1, "the castle has inside corners (%d)" % checked)
	v.queue_free()


## The room's floor runs on to the wall's face: under each band a thin wall leaves of its square, a floor piece of the
## floor beside it.
func test_the_floor_runs_on_to_the_walls_face() -> void:
	var v := _view(DEATH_HOUSE)
	await _frames(2)
	var board := v.board
	var inset := float((board.get_meta("interior_walls", {}) as Dictionary)["inset"])
	var checked := 0
	for z in range(1, board.grid.depth - 1):
		for x in range(1, board.grid.width - 1):
			var c := Vector2i(x, z)
			if not board.grid.has_flag(c, CombatGrid.WALL) or checked >= 8:
				continue
			for d: Vector2i in SetDressing.FACES:
				var n := c + d
				if not InteriorWalls.cuts(board, c, d) or board.floor_box(n) == null:
					continue
				var feet: Array[MeshInstance3D] = []
				for node: Node in board.dressing.get(c, []):
					if node.has_meta("wall_foot"):
						feet.append(node as MeshInstance3D)
				if feet.is_empty():
					continue   # (a wall that a prop has taken the square of keeps none: nothing to see)
				var band := false
				for foot in feet:
					var box := foot.global_transform * foot.mesh.get_aabb()
					var centre := board.cell_center(c)
					var toward := (box.get_center() - centre) * Vector3(d.x, 0, d.y)
					if toward.x + toward.z > 0.5 - inset and absf(box.end.y - board.floor_y(n)) < 0.01 \
							and foot.material_override == board.floor_box(n).material_override:
						band = true
				assert_true(band, "the floor beside %s runs on under the wall's face toward %s" % [n, d])
				checked += 1
				break
	assert_true(checked >= 4, "the Death House's walls have floor to their faces (%d)" % checked)
	v.queue_free()


## At a doorway the wall runs on to the opening's edge, the wall over it is as thin as the walls beside it, and what
## hangs on a wall or stands against it follows only the sides that were set back.
func test_a_doorway_cuts_through_a_thin_wall() -> void:
	var v := _view(DEATH_HOUSE)
	await _frames(2)
	var board := v.board
	var st := board.get_meta("interior_walls", {}) as Dictionary
	var inset := float(st["inset"])
	var n := Vector2i(21, 6)   # the service door
	var header: Dictionary = {}
	for w: Dictionary in st["walls"]:
		if w.has("flanks") and w["cell"] == n:
			header = w
	assert_false(header.is_empty(), "the wall over the doorway at %s is built" % n)
	if header.is_empty():
		v.queue_free()
		return
	var along := (header["flanks"] as Array)[1] as Vector2i - n
	var perp := Vector2i(along.y, along.x)
	var beside := n - along
	assert_eq(board.wall_inset_at(beside, along), 0.0, "a wall's end at a doorway stands at the grid line")
	assert_false(InteriorWalls.cuts(board, beside, along), "the doorway doesn't set it back")
	assert_eq(board.wall_inset_at(beside, perp), -inset, "while its faces into the rooms are set back")
	var node := _wall_node(board, beside)
	assert_true(node != null, "the wall beside the doorway is built")
	if node != null:
		var box := _merged(_slabs(node))
		var length := box.size.x * absf(along.x) + box.size.z * absf(along.y)
		assert_between(length, 0.99, 1.01, "it runs the whole square, to the opening's edge (%.2f)" % length)
	var hb := _merged(_slabs(header["node"] as Node3D))
	var thick := hb.size.x if along.y != 0 else hb.size.z
	assert_between(thick, 1.0 - 2.0 * inset - 0.01, 1.0 - 2.0 * inset + 0.01, "the wall over it is as thin as the walls beside it (%.2f)" % thick)
	var span := hb.size.x if along.y == 0 else hb.size.z
	assert_between(span, 0.99, 1.01, "and as wide as the opening")
	v.queue_free()


## Which walls the setting reaches: tents keep their canvas, the caves keep their blocks (their own pass), Classic its low
## walls, and Castle Ravenloft's roofs their own.
func test_where_walls_stay_whole() -> void:
	var tent := _view("tser_pool_eva_tent")
	await _frames(2)
	assert_true(tent.board.wall_inset > 0.0, "a tent's canvas stands in from its square, as before")
	assert_eq(float((tent.board.get_meta("interior_walls", {}) as Dictionary).get("inset", -1.0)), 0.0, "a tent has no thin walls")
	tent.queue_free()
	await _frames(1)
	for id: String in ["werewolf_den_caves", "ghakis_lair", "amber_deep", "castle_ravenloft_spires_roofs"]:
		var v := _view(id)
		await _frames(2)
		var st := v.board.get_meta("interior_walls", {}) as Dictionary
		assert_eq(float(st.get("inset", 0.0)), 0.0, "%s keeps its whole walls" % id)
		assert_eq(v.board.wall_inset, 0.0, "%s's pieces stand on the grid line" % id)
		v.queue_free()
		await _frames(1)
	Look.set_style("classic", false)
	var c := _view(DEATH_HOUSE)
	await _frames(2)
	assert_eq(c.board.wall_inset, 0.0, "Classic keeps its low walls")
	assert_true((c.board.get_meta("interior_walls", {}) as Dictionary).is_empty(), "with no full walls")
	c.queue_free()


## Everything hung on a thin wall hangs on its face: a model's back, a stain's decal, a 2D picture.
func test_pieces_hang_on_the_set_back_face() -> void:
	var v := _view(DEATH_HOUSE)
	await _frames(2)
	var board := v.board
	var inset := float((board.get_meta("interior_walls", {}) as Dictionary)["inset"])
	var checked := 0
	for z in range(1, board.grid.depth - 1):
		for x in range(1, board.grid.width - 1):
			var c := Vector2i(x, z)
			if not board.grid.has_flag(c, CombatGrid.WALL) or checked >= 4:
				continue
			for d: Vector2i in SetDressing.FACES:
				if InteriorWalls.cuts(board, c, d) and not InteriorWalls.short_face(board, c, d):
					assert_eq(board.wall_inset_at(c, d), -inset, "the face of %s toward %s is set back" % [c, d])
					# A wall stain's decal spot lies on that face.
					for spot: Variant in Clutter._spots(board, c, "wall"):
						var s := spot as Dictionary
						if (s["normal"] as Vector3).is_equal_approx(Vector3(d.x, 0, d.y)):
							var from_centre := ((s["at"] as Vector3) - board.cell_center(c)) * Vector3(d.x, 0, d.y)
							assert_between(from_centre.x + from_centre.z, 0.5 - inset - 0.001, 0.5 - inset + 0.001, "a decal's spot on that face")
					checked += 1
					break
	assert_true(checked >= 3, "faces to check (%d)" % checked)
	# Models hung on a wall have their backs on its face.
	var hung := 0
	for m in board.find_children("*", "Node3D", true, false):
		var node := m as Node3D
		if not node.has_meta("hung") or not node.has_meta("model") or hung >= 12:
			continue
		var info := ModelPiece.manifest()[str(node.get_meta("model"))] as Dictionary
		if str(info.get("mount", "wall")) != "wall" or not node.is_visible_in_tree():
			continue
		var n := node.global_basis.z.normalized()
		var wall := board.grid.cell_at(node.global_position - n * 0.1)
		var normal := Vector2i(roundi(n.x), roundi(n.z))
		var face := (board.cell_center(wall) + Vector3(n.x, 0, n.z) * (0.5 + board.wall_inset_at(wall, normal)))
		var back := INF
		for mi in node.find_children("*", "MeshInstance3D", true, false):
			back = minf(back, _lowest_along((mi as MeshInstance3D).global_transform * (mi as MeshInstance3D).mesh.get_aabb(), n))
		assert_between(back - (face.x * n.x + face.z * n.z), -0.05, 0.05, "%s hung at %s has its back on the wall's face" % [node.get_meta("model"), wall])
		hung += 1
	assert_true(hung >= 1, "the Death House has models hung on its walls (%d)" % hung)
	v.queue_free()


## The lowest point of `box` along the horizontal unit axis `n` (a piece's back, as it faces along `n`).
func _lowest_along(box: AABB, n: Vector3) -> float:
	var lo := INF
	for x: float in [box.position.x, box.end.x]:
		for z: float in [box.position.z, box.end.z]:
			lo = minf(lo, x * n.x + z * n.z)
	return lo
