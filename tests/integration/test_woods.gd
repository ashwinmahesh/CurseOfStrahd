extends TestCase
## Natural woods (the vault's Natural Maps Plan, N4; world/look/woods.gd): in the Modern look a map's woods are a
## scatter of trees, not one tree a square in rows, and a wood's edge wanders over the grid line. What must stay true:
## every wood square keeps a crown over its middle (it still reads as the wall the rules make it), a trunk stands at
## most a quarter of a square into the open square beside it, trees keep their 10 to 20 ft, every tree belongs to its
## square (a prop on the square takes them all) and fades, the feathered edge keeps off the middle of the open squares
## and stays within half a square of the wood, and the Classic look keeps its one tree.

const W := 22
const D := 16
## The clearing: open squares x 5..16, z 4..11, in a wood.
const CLEAR := Rect2i(5, 4, 12, 8)


func after_each() -> void:
	Look.set_style(Look.DEFAULT_STYLE, false)


func _rows() -> Array:
	var rows := []
	for z in D:
		var row := ""
		for x in W:
			row += "." if CLEAR.has_point(Vector2i(x, z)) else "#"
		rows.append(row)
	return rows


func _board() -> ArenaBoard:
	var b := ArenaBoard.build(CombatGrid.from_rows(_rows()), "forest")
	add_child(b)
	return b


func _trees(b: ArenaBoard, c: Vector2i) -> Array[Node3D]:
	var out: Array[Node3D] = []
	for n: Variant in b.dressing.get(c, []):
		if (n as Node).has_meta("nature"):
			out.append(n as Node3D)
	return out


## A tree's crown radius, from its model and its scale.
func _crown(t: Node3D) -> float:
	return Woods.crown(str(t.get_meta("model")), (t.get_child(0) as Node3D).scale.x)


func _wall_squares() -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	for z in D:
		for x in W:
			if not CLEAR.has_point(Vector2i(x, z)):
				out.append(Vector2i(x, z))
	return out


## Every wood square keeps a crown over its middle, so it still reads as the wall it is.
func test_every_wood_square_stays_under_a_crown() -> void:
	Look.set_style("modern", false)
	var b := _board()
	for c in _wall_squares():
		var mid := Vector2(c.x + 0.5, c.y + 0.5)
		var covered := false
		for t in _trees(b, c):
			if Vector2(t.position.x, t.position.z).distance_to(mid) <= _crown(t):
				covered = true
		assert_true(covered, "the middle of wood square %s is under a crown" % c)
	b.queue_free()


## A trunk stands at most a quarter of a square into an open square (a token in its middle and its ring stay clear).
func test_trunks_stand_a_quarter_square_into_the_open_at_most() -> void:
	Look.set_style("modern", false)
	var b := _board()
	for c in _wall_squares():
		for t in _trees(b, c):
			var p := Vector2(t.position.x, t.position.z)
			assert_true(Rect2(Vector2(c), Vector2.ONE).grow(0.25).has_point(p), "a trunk of %s stands at %s" % [c, p])
	b.queue_free()


## The edge isn't a line: along the clearing's west side the trunks are spread over the grid line, not strung on it.
func test_the_edge_wanders() -> void:
	Look.set_style("modern", false)
	var b := _board()
	var xs: Array[float] = []
	for z in range(CLEAR.position.y + 1, CLEAR.end.y - 1):
		for t in _trees(b, Vector2i(CLEAR.position.x - 1, z)):
			xs.append(t.position.x + _crown(t))   # where the crown's edge reaches along the open side
	xs.sort()
	assert_true(xs.size() >= 6, "trees stand along the edge (%d)" % xs.size())
	assert_true(xs[-1] - xs[0] > 0.35, "the crowns' edge varies by %.2f of a square" % (xs[-1] - xs[0]))
	var line := float(CLEAR.position.x)
	var over := 0
	var back := 0
	for x in xs:
		if x > line + 0.15:
			over += 1
		if x < line + 0.2:
			back += 1
	assert_true(over > 0 and back > 0, "some crowns hang over the open square (%d) and some draw back (%d)" % [over, back])
	b.queue_free()


## Sizes, leans and kinds vary, and the trees stand off the middles of their squares by more than a hand's breadth.
func test_the_trees_vary() -> void:
	Look.set_style("modern", false)
	var b := _board()
	var heights := {}
	var kinds := {}
	var leaning := 0
	var far := 0
	var count := 0
	for c in _wall_squares():
		var mid := Vector2(c.x + 0.5, c.y + 0.5)
		for t in _trees(b, c):
			count += 1
			kinds[str(t.get_meta("model"))] = true
			heights[snappedf(Flora.height_of(str(t.get_meta("model"))) * (t.get_child(0) as Node3D).scale.x, 0.15)] = true
			if t.basis.y.y < 0.9999:
				leaning += 1
			if Vector2(t.position.x, t.position.z).distance_to(mid) > 0.2:
				far += 1
	assert_true(heights.size() >= 6, "sizes vary (%d)" % heights.size())
	assert_true(kinds.size() >= 3, "kinds vary (%d)" % kinds.size())
	assert_true(leaning > count / 2, "most trees lean a little (%d of %d)" % [leaning, count])
	assert_true(far > count / 3, "many stand well off their square's middle (%d of %d)" % [far, count])
	assert_true(count > _wall_squares().size(), "more trees than wood squares (%d)" % count)
	b.queue_free()


## Trees in the map stay 10 to 20 ft (they don't wall in the squares beside them), leaning or not.
func test_trees_keep_their_height() -> void:
	Look.set_style("modern", false)
	var b := _board()
	for c in _wall_squares():
		for t in _trees(b, c):
			var box := AABB()
			var first := true
			for n in t.find_children("*", "MeshInstance3D", true, false):
				var a := (n as MeshInstance3D).global_transform * (n as MeshInstance3D).mesh.get_aabb()
				box = a if first else box.merge(a)
				first = false
			assert_true(box.size.y > 2.0 and box.size.y < 4.0, "a tree of %s is 10 to 20 ft (%.2f)" % [c, box.size.y])
	b.queue_free()


## Every tree belongs to its square and fades: a prop on the square hides them all and gives them back.
func test_a_prop_takes_all_of_a_squares_trees() -> void:
	Look.set_style("modern", false)
	var b := _board()
	var edge := Vector2i(CLEAR.position.x - 1, CLEAR.position.y + 2)
	var many := Vector2i(-1, -1)
	for c in _wall_squares():
		if _trees(b, c).size() > 1:
			many = c
			break
	assert_true(many.x >= 0, "some wood square has more than one tree")
	for c: Vector2i in [edge, many]:
		for t in _trees(b, c):
			assert_true(t in b.mesh_occluders, "the tree at %s fades in the party's way" % t.position)
		b.clear_cell(c)
		for t in _trees(b, c):
			assert_false(t.visible, "hidden with the square's prop at %s" % c)
		b.restore_cell(c)
		for t in _trees(b, c):
			assert_true(t.visible, "and back when it goes")
	b.queue_free()


## A place comes out the same every time it is built.
func test_the_same_wood_every_time() -> void:
	Look.set_style("modern", false)
	var a := _board()
	var b := _board()
	for c in _wall_squares():
		var ta := _trees(a, c)
		var tb := _trees(b, c)
		assert_eq(ta.size(), tb.size(), "the same number of trees at %s" % c)
		for i in mini(ta.size(), tb.size()):
			assert_true(ta[i].position.is_equal_approx(tb[i].position), "the same tree at %s" % c)
	a.queue_free()
	b.queue_free()


## A trunk doesn't lean into a square a location's things stand on.
func test_open_sides_skip_what_a_location_stands_on() -> void:
	Look.set_style("modern", false)
	var b := _board()
	var c := Vector2i(CLEAR.position.x - 1, CLEAR.position.y + 2)
	assert_true(Woods.open_sides(b, c).has(Vector2i(1, 0)), "the clearing is open beside the wood")
	b.occupied[c + Vector2i(1, 0)] = "props"
	assert_false(Woods.open_sides(b, c).has(Vector2i(1, 0)), "but not where a prop stands")
	b.queue_free()


## The edge is feathered: plants, saplings and fallen trees reach out into the open ground by up to half a square, the
## reach wanders, they keep off the middle of the open squares, and none is further from the wood than that.
func test_the_edge_is_feathered() -> void:
	Look.set_style("modern", false)
	var b := _board()
	var f := Flora.new()
	f.set_id = "forest"
	f.spec = Flora.resolve("forest")
	f.rng.seed = 11
	f.dress_map(b, func(_p: Vector2) -> float: return 0.0)
	var reach := {}
	for c: Vector2i in f.map_items:
		if not CLEAR.has_point(c):
			continue
		var boxes: Array[Rect2] = []
		for d: Vector2i in CombatGrid.DIRS:
			if b.grid.in_bounds(c + d) and b.is_tree(c + d):
				boxes.append(Rect2(Vector2(c + d), Vector2.ONE))
		var per := f.map_items[c] as Dictionary
		for id: String in per:
			for it: Array in per[id] as Array:
				var p := Vector2((it[0] as Transform3D).origin.x, (it[0] as Transform3D).origin.z)
				var mid := Vector2(c.x + 0.5, c.y + 0.5)
				assert_true(p.distance_to(mid) >= Woods.MIDDLE_CLEAR - 0.001, "%s at %s keeps off the middle of %s" % [id, p, c])
				if not boxes.is_empty():
					var gap := Woods._gap(boxes, p)
					assert_true(gap <= Woods.FEATHER_REACH + 0.001, "%s at %s is within half a square of the wood" % [id, p])
					reach[c] = maxf(float(reach.get(c, 0.0)), gap)
	assert_true(reach.size() > 10, "the edge's open squares carry plants (%d)" % reach.size())
	var saplings := 0
	var fallen := 0
	for c: Vector2i in f.map_items:
		if not CLEAR.has_point(c):
			continue
		var per2 := f.map_items[c] as Dictionary
		for id: String in per2:
			if str((Flora.manifest()[id] as Dictionary).get("kind", "")) not in ["tree", "dead", "broadleaf"]:
				continue
			for it: Array in per2[id] as Array:
				var up := (it[0] as Transform3D).basis.y.normalized().y
				if up < 0.3:
					fallen += 1
				elif (it[0] as Transform3D).basis.get_scale().y * Flora.height_of(id) < 2.0:
					saplings += 1
	assert_true(saplings > 0, "saplings stand against the wood's edge (%d)" % saplings)
	assert_true(fallen > 0, "and a dead tree lies fallen along it (%d)" % fallen)
	var lo := 1.0
	var hi := 0.0
	for c: Vector2i in reach:
		if c.x == CLEAR.position.x and c.y > CLEAR.position.y and c.y < CLEAR.end.y - 1:
			lo = minf(lo, float(reach[c]))
			hi = maxf(hi, float(reach[c]))
	assert_true(hi > 0.25, "the plants reach well into the open square (%.2f)" % hi)
	assert_true(hi - lo > 0.12, "and the reach wanders along the edge (%.2f to %.2f)" % [lo, hi])
	b.queue_free()


## The Classic look is frozen: one tree a square, within a hand's breadth of the middle, as before.
func test_classic_keeps_one_tree_a_square() -> void:
	Look.set_style("classic", false)
	var b := _board()
	for c in _wall_squares():
		var nodes: Array = b.dressing.get(c, [])
		assert_true(nodes.size() >= 1 and nodes.size() <= 2, "one tree at %s (%d pieces)" % [c, nodes.size()])
		for n: Variant in nodes:
			var p := (n as Node3D).position
			assert_true(absf(p.x - c.x - 0.5) <= 0.13 and absf(p.z - c.y - 0.5) <= 0.13, "and no further off the middle than before")
	b.queue_free()
