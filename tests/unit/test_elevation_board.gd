extends TestCase
## Natural ground drawn (owner, 2026-10-08; world/combat/arena_board.gd): each square's top slopes to meet its natural
## neighbours with no step between them, a cliff shows a rock face, what stands on a hill stands on it, the mouse finds
## the square on a slope, and the shaped ground's skin (GroundRelief) follows the hill.


func _board(rows: Array, elevation: Array, theme: String = "shrine_yard") -> ArenaBoard:
	var b := ArenaBoard.build(CombatGrid.from_rows(rows, elevation), theme)
	add_child(b)
	return b


func test_slopes_meet_their_neighbours() -> void:
	var b := _board(["....", "....", "...."], ["0122", "0122", "0122"])
	assert_true(b.has_terrain())
	for z in 3:
		for x in 4:
			var c := Vector2i(x, z)
			var mid := b.ground_y(Vector2(x + 0.5, z + 0.5))
			assert_between(mid, b.floor_y(c) - 0.5, b.floor_y(c) + 0.5, "the middle of %s within 2.5 ft of its height" % c)
			assert_eq(b.cell_center(c).y, mid, "who stands on %s stands on the ground drawn" % c)
			if x < 3:
				for k: int in [0, 1]:
					assert_eq(b.corner_height(c, Vector2i(1, k)), b.corner_height(c + Vector2i(1, 0), Vector2i(0, k)),
						"%s and the square east of it share their corners" % c)
	assert_between(b.ground_y(Vector2(1.0, 1.5)), 0.2, 1.3, "the edge between 5 ft and 10 ft lies partway up")
	assert_eq(b.ground_normal(Vector2i(3, 1)), Vector3.UP, "the level top")
	assert_eq(b.ground_y(Vector2(3.5, 1.5)), b.floor_y(Vector2i(3, 1)), "level ground at its own height")
	assert_true(b.ground_normal(Vector2i(1, 1)).x < -0.1, "the slope leans back toward the low side")


func test_a_cliff_drops_away_as_a_rock_face() -> void:
	var b := _board(["....", "...."], ["0033", "0033"])
	var low := Vector2i(1, 0)
	var high := Vector2i(2, 0)
	assert_true(b.grid.is_cliff(low, high))
	assert_eq(b.corner_height(high, Vector2i(0, 0)), b.floor_y(high), "the top of the cliff keeps its height")
	assert_eq(b.corner_height(low, Vector2i(1, 0)), b.floor_y(low), "and its foot its own")
	assert_true(b.floor_box(high).has_node("Cliff"), "a rock face under the top")
	assert_false(b.floor_box(low).has_node("Cliff"), "none under the foot")
	assert_false(b.rolling(high), "the skin leaves a cliff's edge to the board")


func test_a_tree_on_a_hill_stands_on_it() -> void:
	var b := _board(["...", ".#.", "..."], ["222", "222", "222"], "forest")
	var flat := _board(["...", ".#.", "..."], [], "forest")
	var c := Vector2i(1, 1)
	var on_hill := b.dressing.get(c, []) as Array
	var on_flat := flat.dressing.get(c, []) as Array
	assert_false(on_hill.is_empty(), "a tree")
	assert_eq(on_hill.size(), on_flat.size())
	for i in on_hill.size():
		assert_between((on_hill[i] as Node3D).position.y - (on_flat[i] as Node3D).position.y, 1.99, 2.01,
			"raised by the hill's 10 ft")
	var ground := 0
	for n in b.get_children():
		if n.has_meta("terrain") and Vector2i(roundi((n as Node3D).position.x), roundi((n as Node3D).position.z)) == c:
			ground += 1
			assert_eq((n as Node3D).position.y, 0.0, "the ground under it isn't raised twice")
	assert_eq(ground, 1, "one piece of ground under the tree")


func test_the_mouse_finds_the_square_on_a_slope() -> void:
	var b := _board([".....", ".....", "....."], ["01234", "01234", "01234"])
	for x in 5:
		var hit: Variant = GridPick.ground_hit(b, Vector3(x + 0.5, 30.0, 1.5), Vector3.DOWN)
		assert_true(hit != null, "straight down onto square %d" % x)
		if hit == null:
			continue
		var p := hit as Vector3
		assert_eq(Vector2i(floori(p.x), floori(p.z)), Vector2i(x, 1))
		var ground := b.ground_y(Vector2(x + 0.5, 1.5))
		assert_between(p.y, ground - 0.02, ground + 0.02, "on the ground drawn")
	# A slanting look from the low side meets the slope where it rises to the eye line, not the floor behind it.
	var from := Vector3(-6.0, 12.0, 1.5)
	var hit2: Variant = GridPick.ground_hit(b, from, (Vector3(3.5, 3.0, 1.5) - from).normalized())
	assert_true(hit2 != null and Vector2i(floori((hit2 as Vector3).x), floori((hit2 as Vector3).z)) == Vector2i(3, 1),
		"the square the eye rests on: %s" % [hit2])
	assert_eq(GridPick.ground_hit(b, Vector3(2.0, 5.0, 1.5), Vector3.UP), null, "looking up meets nothing")


func test_the_shaped_ground_follows_the_hill() -> void:
	var rows: Array = []
	var elevation: Array = []
	for z in 7:
		rows.append("...........")
		elevation.append("00112233666")
	var b := _board(rows, elevation, "forest")
	var r := GroundRelief.build(b, {})
	assert_true(r.skinned(Vector2i(3, 3)), "rolling ground: the skin draws it")
	assert_false(r.skinned(Vector2i(7, 3)), "beside a cliff the board's own column does")
	for x in 7:
		var p := Vector2(x + 0.5, 3.5)
		assert_between(r.height(p), b.ground_y(p) - GroundRelief.DEEPEST - 0.01, b.ground_y(p) + 0.01,
			"square %d: on the hill's slope, no deeper than its hollows" % x)
		assert_between(r.shape(p), -GroundRelief.DEEPEST - 0.01, 0.01, "the skin's own shape stays shallow")


func test_a_raised_prop_is_drawn_from_the_ground() -> void:
	var g := LocationView.grid_for({"map": {"rows": ["......", "......"]},
		"props": [{"id": "platform", "cell": [2, 0], "span": [2, 2], "kind": "decor", "stand_ft": 15}]})
	var b := ArenaBoard.build(g)
	add_child(b)
	var c := Vector2i(2, 1)
	assert_eq(b.floor_y(c), 0.0, "the floor drawn under it is the ground")
	assert_eq(b.cell_center(c).y, 3.0, "who stands on it stands on its top")
	assert_true(b.shaped(), "the mouse follows its top")
	var hit: Variant = GridPick.ground_hit(b, Vector3(2.5, 20.0, 1.5), Vector3.DOWN)
	assert_true(hit != null and is_equal_approx((hit as Vector3).y, 3.0), "pointing at it finds its top: %s" % [hit])


## The ground mist lies over raised ground as it does over level ground: the post shader measures it from the
## ground's height (Atmosphere.ground_heights, one texel per square), so Yester Hill's crest is as misty as its foot.
func test_the_mist_lies_on_the_hill() -> void:
	var b := ArenaBoard.build(LocationView.grid_for(Compendium.shared().get_entry("locations", "yester_hill")), "wilderness")
	add_child(b)
	var img := Atmosphere.ground_heights(b).get_image()
	var crest := Vector2i(20, 3)
	var y := b.cell_center(crest).y
	assert_between(img.get_pixelv(crest).r, y - 0.01, y + 0.01, "the crest's own height")
	assert_true(y > 8.0, "45 ft up the hill")
	assert_true(b.shaped(), "so the mist follows the ground there (Atmosphere._apply_static)")


func test_high_ground_over_a_drop_shows_rock() -> void:
	var b := _board(["...  ", "...  "], ["334..", "334.."])
	assert_true(b.floor_box(Vector2i(2, 0)).has_node("Cliff"), "20 ft up over an empty square: a rock face down to it")
	assert_false(b.floor_box(Vector2i(0, 0)).has_node("Cliff"), "ground with nothing below it keeps its own sides")
