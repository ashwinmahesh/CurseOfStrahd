extends TestCase
## Things placed by hand (Natural Maps Plan I3, owner 2026-10-19: "we don't need to draw our real world maps as a battle
## grid"; docs/art/set_dressing.md, "Things placed by hand"): a loose piece indoors (a barrel, a crate, a chair) stands a
## little off its square's middle and a little turned, seeded by its square; pieces people line up (pews, beds, shelves,
## counters) keep their lines; a long run of tables is a few long tables, not a row of short ones. Modern look, interiors.

const LOOSE_PLACES := ["castle_ravenloft_larders", "old_bonegrinder", "bildraths_mercantile", "vallaki_blue_water_inn", "death_house_ground"]


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


## The standing 3D pieces on the board of art in `arts` ("art" meta), not hung on a wall or backed onto one.
func _standing(board: ArenaBoard, arts: Array) -> Array[Node3D]:
	var out: Array[Node3D] = []
	for n in board.find_children("*", "Node3D", true, false):
		var node := n as Node3D
		if node.has_meta("art") and node.has_meta("model") and str(node.get_meta("art")) in arts and not node.has_meta("hung") \
				and not node.has_meta("against_wall") and node.is_visible_in_tree():
			out.append(node)
	return out


## How far `node` stands off the middle of its square (x, z) and how far it is turned off a quarter turn.
func _off(board: ArenaBoard, node: Node3D) -> Array:
	var cell := board.grid.cell_at(node.global_position)
	var d := node.global_position - board.cell_center(cell)
	var quarter := PI / 2.0
	return [Vector2(d.x, d.z), node.global_rotation.y - roundf(node.global_rotation.y / quarter) * quarter, cell]


func test_loose_pieces_stand_a_little_off_their_middle_and_turned() -> void:
	var loose := (SetDressing.catalog().get("hand_placed", {}) as Dictionary).get("loose", []) as Array
	var cfg := SetDressing.catalog().get("hand_placed", {}) as Dictionary
	var reach := float(cfg.get("shift", 0.2))
	var turn_max := deg_to_rad(float(cfg.get("turn", 15.0)))
	var moved := 0
	var turned := 0
	var seen := 0
	for loc_id: String in LOOSE_PLACES:
		var v := _view(loc_id)
		await _frames(2)
		var board := v.board
		for node in _standing(board, loose):
			var info := _off(board, node)
			var off := info[0] as Vector2
			var cell := info[2] as Vector2i
			seen += 1
			assert_true(absf(off.x) <= reach + 0.002 and absf(off.y) <= reach + 0.002, "%s at %s is within %.2f of its middle (%s)" % [node.name, cell, reach, off])
			assert_true(absf(info[1] as float) <= turn_max + 0.002, "%s at %s is turned no more than %d degrees" % [node.name, cell, cfg.get("turn", 15)])
			for d: Vector2i in SetDressing.FACES:
				var n := cell + d
				if board.grid.in_bounds(n) and (board.grid.has_flag(n, CombatGrid.WALL) or board.door_cells.has(n)):
					assert_true(off.x * d.x + off.y * d.y <= 0.002, "%s at %s never moves toward the wall at %s" % [node.name, cell, n])
			moved += 1 if off.length() > 0.02 else 0
			turned += 1 if absf(info[1] as float) > 0.02 else 0
		v.queue_free()
		await _frames(1)
	assert_true(seen >= 20, "loose pieces to look at (%d)" % seen)
	assert_true(moved * 2 >= seen, "most are off their middle (%d of %d)" % [moved, seen])
	assert_true(turned * 2 >= seen, "and turned (%d of %d)" % [turned, seen])


func test_hand_placing_is_the_same_every_time_a_place_is_built() -> void:
	var loose := (SetDressing.catalog().get("hand_placed", {}) as Dictionary).get("loose", []) as Array
	var first := {}
	var v := _view("castle_ravenloft_larders")
	await _frames(2)
	for node in _standing(v.board, loose):
		first[v.board.grid.cell_at(node.global_position)] = [node.global_position, node.global_rotation.y]
	v.queue_free()
	await _frames(1)
	var w := _view("castle_ravenloft_larders")
	await _frames(2)
	var same := 0
	for node in _standing(w.board, loose):
		var cell := w.board.grid.cell_at(node.global_position)
		if first.has(cell):
			assert_true((first[cell][0] as Vector3).is_equal_approx(node.global_position) and is_equal_approx(first[cell][1] as float, node.global_rotation.y),
				"the piece at %s stands as it did" % cell)
			same += 1
	assert_true(same >= 5, "pieces compared (%d)" % same)
	w.queue_free()


func test_lined_up_pieces_keep_their_lines() -> void:
	var v := _view("village_church")
	await _frames(2)
	var pews := _standing(v.board, ["pew"])
	assert_true(pews.size() >= 10, "the church has its pews (%d)" % pews.size())
	for pew in pews:
		var info := _off(v.board, pew)
		assert_true((info[0] as Vector2).length() < 0.002 and absf(info[1] as float) < 0.002, "the pew at %s is on its square's middle, square to the room" % [info[2]])
	v.queue_free()


func test_classic_and_outdoors_keep_their_pieces_where_they_were() -> void:
	Look.set_style("classic", false)
	var c := _view("old_bonegrinder")
	await _frames(2)
	for node in _standing(c.board, (SetDressing.catalog().get("hand_placed", {}) as Dictionary).get("loose", []) as Array):
		assert_true((_off(c.board, node)[0] as Vector2).length() < 0.002, "Classic: %s stands on its square's middle" % node.name)
	c.queue_free()
	await _frames(1)
	Look.set_style(Look.DEFAULT_STYLE, false)
	var outdoors := ""
	for id: String in Compendium.shared().tables["locations"] as Dictionary:
		var map := (Compendium.shared().get_entry("locations", id) as Dictionary).get("map", {}) as Dictionary
		if bool(map.get("outdoors", false)) and str(map.get("theme", "")) in ArenaBoard.TOWNS:
			outdoors = id
			break
	assert_ne(outdoors, "", "a town to look at")
	var t := _view(outdoors)
	await _frames(2)
	assert_false(ModelPiece.loose(t.board, "barrel"), "a barrel outdoors is not set down by hand (the wilds' own pass)")
	t.queue_free()
	await _frames(1)
	var i := _view("old_bonegrinder")
	await _frames(2)
	assert_true(ModelPiece.loose(i.board, "barrel"), "a barrel indoors is")
	assert_false(ModelPiece.loose(i.board, "pew"), "a pew isn't")
	i.queue_free()


## A run of tables along the Argynvostholt hall: a few long tables from end to end, over the run's own squares.
func test_a_long_run_of_tables_is_a_few_long_tables() -> void:
	var v := _view("argynvostholt_hall")
	await _frames(2)
	var board := v.board
	var run := board._low_run(Vector2i(12, 6))
	var cells := (run["cells"] as Array).duplicate()
	cells.sort()
	assert_eq(cells.size(), 12, "the hall's table is twelve squares")
	var pieces: Array[Node3D] = []
	for n in board.find_children("*", "Node3D", true, false):
		if n.has_meta("one_piece") and n.has_meta("model"):
			pieces.append(n as Node3D)
	assert_true(pieces.size() >= 2 and pieces.size() <= 4, "a few tables, not twelve (%d)" % pieces.size())
	var covered := 0.0
	var lo := INF
	var hi := -INF
	for piece in pieces:
		var length := float(piece.get_meta("one_piece"))
		assert_true(length >= 2.0 and length <= 5.0, "each is a long table (%.2f)" % length)
		covered += length
		var at := piece.global_position.x
		lo = minf(lo, at - length / 2.0)
		hi = maxf(hi, at + length / 2.0)
		assert_true(absf(piece.global_position.z - (6.5)) < 0.01, "on the run's line")
	assert_between(lo, 11.9, 12.1, "from the run's first square")
	assert_between(hi, 23.9, 24.1, "to its last")
	assert_between(covered, 11.7, 12.0, "with only the little gaps between them (%.2f)" % covered)
	for k: Vector2i in cells:
		assert_true(board.grid.has_flag(k, CombatGrid.LOW), "every square is still low cover to the rules")
	# Their middle is stretched, their ends as modelled: the top is one length, the legs stand at the ends.
	var box := AABB()
	var first := true
	for mi in pieces[0].find_children("*", "MeshInstance3D", true, false):
		var b := (mi as MeshInstance3D).global_transform * (mi as MeshInstance3D).mesh.get_aabb()
		box = b if first else box.merge(b)
		first = false
	assert_between(box.size.x, float(pieces[0].get_meta("one_piece")) - 0.05, float(pieces[0].get_meta("one_piece")) + 0.05, "a table as long as it says")
	assert_between(box.size.z, 0.5, 0.7, "and as deep as one table")
	v.queue_free()
