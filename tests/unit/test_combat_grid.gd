extends TestCase
## The combat grid (2024 PHB "Playing on a Grid", "Cover", "Areas of Effect"; ADR 0007).


func _none(_c: Vector2i) -> bool:
	return false


func test_diagonals_cost_five_feet() -> void:
	var g := CombatGrid.from_rows(["......", "......", "......", "......"])
	assert_eq(g.distance_ft(Vector2i(0, 0), 1, Vector2i(3, 3), 1), 15)
	assert_eq(g.distance_ft(Vector2i(0, 0), 1, Vector2i(5, 1), 1), 25)
	assert_eq(g.step_cost(Vector2i(0, 0), Vector2i(1, 1), 1, _none, _none), 5)


func test_large_creatures_measure_from_the_nearest_square() -> void:
	var g := CombatGrid.from_rows(["......", "......", "......", "......"])
	# A Large creature at (0,0) fills (0..1, 0..1); a creature at (2,1) is adjacent.
	assert_eq(g.distance_ft(Vector2i(0, 0), 2, Vector2i(2, 1), 1), 5)
	assert_eq(g.distance_ft(Vector2i(0, 0), 2, Vector2i(4, 3), 1), 15)


func test_difficult_terrain_costs_double() -> void:
	var g := CombatGrid.from_rows([".~.", "...", "..."])
	assert_eq(g.step_cost(Vector2i(0, 0), Vector2i(1, 0), 1, _none, _none), 10)
	var reach := g.reachable(Vector2i(0, 0), 1, 10, _none, _none, _none)
	assert_eq(int((reach[Vector2i(1, 0)] as Dictionary)["cost"]), 10)
	assert_eq(int((reach[Vector2i(2, 0)] as Dictionary)["cost"]), 10, "around the rubble is as cheap")


func test_no_cutting_wall_corners() -> void:
	var g := CombatGrid.from_rows(["..", "..", "#."])
	assert_eq(g.step_cost(Vector2i(0, 0), Vector2i(1, 1), 1, _none, _none), 5)
	var g2 := CombatGrid.from_rows([".#", ".."])
	assert_eq(g2.step_cost(Vector2i(0, 0), Vector2i(1, 1), 1, _none, _none), -1, "a wall at the corner blocks the diagonal")
	assert_eq(g2.step_cost(Vector2i(0, 0), Vector2i(1, 0), 1, _none, _none), -1, "can't enter a wall")


func test_climbing_onto_a_platform_costs_extra() -> void:
	var g := CombatGrid.from_rows([".2", ".."])
	# 10 ft up: 5 ft for the square plus the 10 ft climbed at 2 ft per foot (1 extra, 2024 Climbing).
	assert_eq(g.step_cost(Vector2i(0, 0), Vector2i(1, 0), 1, _none, _none), 25)
	assert_eq(g.step_cost(Vector2i(1, 0), Vector2i(0, 0), 1, _none, _none), 25, "climbing down 10 ft costs the same")


func test_reachable_and_path() -> void:
	var g := CombatGrid.from_rows([".....", ".###.", "....."])
	var reach := g.reachable(Vector2i(0, 1), 1, 30, _none, _none, _none)
	assert_true(reach.has(Vector2i(4, 1)), "around the wall in 30 ft")
	var path := CombatGrid.path_to(reach, Vector2i(4, 1))
	assert_eq(path[0], Vector2i(0, 1))
	assert_eq(path[path.size() - 1], Vector2i(4, 1))
	# No cutting the wall's corners: up, along the top and back down is 30 ft.
	assert_eq(int((reach[Vector2i(4, 1)] as Dictionary)["cost"]), 30)
	var short := g.reachable(Vector2i(0, 1), 1, 25, _none, _none, _none)
	assert_false(short.has(Vector2i(4, 1)))


func test_walls_give_cover_by_corner_lines() -> void:
	var open := CombatGrid.from_rows([".....", ".....", "....."])
	assert_eq(int(open.cover_between(Vector2i(0, 1), 1, Vector2i(4, 1), 1)["cover"]), CombatGrid.Cover.NONE)
	var wall := CombatGrid.from_rows(["..#..", "..#..", "..#.."])
	assert_eq(int(wall.cover_between(Vector2i(0, 1), 1, Vector2i(4, 1), 1)["cover"]), CombatGrid.Cover.TOTAL)
	assert_false(wall.can_see(Vector2i(0, 1), 1, Vector2i(4, 1), 1))
	# A wall stub beside the target: some lines blocked.
	var stub := CombatGrid.from_rows([".....", "...#.", "....."])
	var c := int(stub.cover_between(Vector2i(0, 2), 1, Vector2i(4, 1), 1)["cover"])
	assert_true(c == CombatGrid.Cover.HALF or c == CombatGrid.Cover.THREE_QUARTERS, "partial wall gives partial cover")


func test_standing_beside_something_isnt_cover() -> void:
	# A target with a wall or a crate next to it, not between it and the attacker: no cover.
	var beside_wall := CombatGrid.from_rows([".......", ".......", "....#..", "......."])
	assert_eq(int(beside_wall.cover_between(Vector2i(0, 1), 1, Vector2i(4, 1), 1)["cover"]), CombatGrid.Cover.NONE, "wall below the target")
	var beside_crate := CombatGrid.from_rows([".......", ".....=.", ".......", "......."])
	assert_eq(int(beside_crate.cover_between(Vector2i(0, 1), 1, Vector2i(4, 1), 1)["cover"]), CombatGrid.Cover.NONE, "crate behind the target")
	# Diagonal attackers: a wall square at the target's side corner clips one line at most.
	var corner := CombatGrid.from_rows(["....#..", ".......", ".......", "......."])
	assert_eq(int(corner.cover_between(Vector2i(0, 3), 1, Vector2i(4, 1), 1)["cover"]), CombatGrid.Cover.NONE, "a wall on the target's far side")
	# A creature next to the target but not in the way gives nothing; one in the way gives Half.
	var open := CombatGrid.from_rows([".......", ".......", ".......", "......."])
	assert_eq(int(open.cover_between(Vector2i(0, 1), 1, Vector2i(4, 1), 1, {Vector2i(4, 2): "Zombie"})["cover"]), CombatGrid.Cover.NONE)
	assert_eq(int(open.cover_between(Vector2i(0, 1), 1, Vector2i(4, 1), 1, {Vector2i(3, 1): "Zombie"})["cover"]), CombatGrid.Cover.HALF)


func test_low_walls_and_creatures_give_half_cover() -> void:
	var g := CombatGrid.from_rows([".....", "..=..", "....."])
	var cov := g.cover_between(Vector2i(0, 1), 1, Vector2i(4, 1), 1)
	assert_eq(int(cov["cover"]), CombatGrid.Cover.HALF)
	var open := CombatGrid.from_rows([".....", ".....", "....."])
	var by := open.cover_between(Vector2i(0, 1), 1, Vector2i(4, 1), 1, {Vector2i(2, 1): "Zombie"})
	assert_eq(int(by["cover"]), CombatGrid.Cover.HALF)
	assert_eq(str(by["by"]), "Zombie")


func test_high_ground_sees_over_low_walls() -> void:
	var g := CombatGrid.from_rows(["2....", "..=..", "....."])
	g.set_height(Vector2i(0, 1), 10)
	assert_eq(int(g.cover_between(Vector2i(0, 1), 1, Vector2i(4, 1), 1)["cover"]), CombatGrid.Cover.NONE)


func test_sphere_area() -> void:
	var g := CombatGrid.from_rows([".........", ".........", ".........", ".........", ".........", "........."])
	var cells := g.area_cells("sphere", 10, Vector2(4, 3))
	# A 10 ft radius from a grid point covers the 4x4 block around it minus the far corners: 12 squares.
	assert_eq(cells.size(), 12)
	assert_true(Vector2i(3, 2) in cells and Vector2i(4, 3) in cells)
	assert_false(Vector2i(2, 1) in cells, "corner squares fall outside the circle")


func test_cube_cone_and_line_areas() -> void:
	var g := CombatGrid.from_rows([".........", ".........", ".........", ".........", "........."])
	var cube := g.area_cells("cube", 15, Vector2(2, 2.5), Vector2.RIGHT)
	assert_eq(cube.size(), 9)
	var cone := g.area_cells("cone", 15, Vector2(2, 2.5), Vector2.RIGHT)
	assert_true(Vector2i(2, 2) in cone and Vector2i(4, 1) in cone and Vector2i(4, 3) in cone)
	assert_false(Vector2i(2, 1) in cone)
	var line := g.area_cells("line", 30, Vector2(0, 2.5), Vector2.RIGHT)
	assert_eq(line.size(), 6)


## Lines aimed at any angle (owner, 2026-10-12: "Allow aiming straight line spells (like lightning bolt) in any straight
## line (not just aligned with squares)"): a square is in one when at least half of it is (2024 DMG).
func test_a_line_starts_where_its_aim_leaves_the_casters_space() -> void:
	assert_eq(CombatGrid.line_origin(Vector2i(5, 5), 1, Vector2.RIGHT), Vector2(6, 5.5), "straight out: the middle of the facing edge")
	assert_eq(CombatGrid.line_origin(Vector2i(5, 5), 1, Vector2(1, 1)), Vector2(6, 6), "diagonally: the corner")
	assert_true(CombatGrid.line_origin(Vector2i(5, 5), 1, Vector2(2, 1)).distance_to(Vector2(6, 5.75)) < 0.001,
		"at a slant: where the line from the middle crosses the edge")
	assert_eq(CombatGrid.line_origin(Vector2i(5, 5), 1, Vector2.RIGHT, 10), Vector2(6, 6),
		"10 ft wide from one square, straight: half a square aside, so its edges run along grid lines")
	assert_eq(CombatGrid.line_origin(Vector2i(4, 4), 2, Vector2.UP), Vector2(5.5, 4), "5 ft wide from a Large space: down a column")


func test_a_line_at_a_slant_takes_a_band_of_squares_as_wide_as_it_is() -> void:
	var rows: Array = []
	for i in 12:
		rows.append("................")
	var g := CombatGrid.from_rows(rows)
	var me := Vector2i(3, 6)
	var aim := Vector2(14.5, 2.0) - Vector2(3.5, 6.5)
	var bolt := g.area_cells("line", 100, CombatGrid.line_origin(me, 1, aim), aim)
	for want: Vector2i in [Vector2i(4, 6), Vector2i(8, 4), Vector2i(10, 3), Vector2i(13, 2)]:
		assert_true(want in bolt, "%s on the slant" % want)
	for not_hit: Vector2i in [me, Vector2i(9, 6), Vector2i(12, 6), Vector2i(8, 6)]:
		assert_false(not_hit in bolt, "%s off it" % not_hit)
	# Squares that run off the board are lost, so count only up to where it leaves the board (x = 16 at about 13.5 sq).
	var short := g.area_cells("line", 50, CombatGrid.line_origin(me, 1, aim), aim)
	assert_between(short.size(), 9, 11, "a 50-ft line covers about ten squares' area, so about ten squares")
	for cell in short:
		var x_band := Vector2(cell) + Vector2(0.5, 0.5) - CombatGrid.line_origin(me, 1, aim)
		assert_true(absf(x_band.dot(Vector2(-aim.normalized().y, aim.normalized().x))) < 1.0, "%s close to the line" % cell)
	var diagonal := g.area_cells("line", 30, CombatGrid.line_origin(Vector2i(2, 2), 1, Vector2(1, 1)), Vector2(1, 1))
	assert_eq(diagonal.size(), 4, "diagonally: the squares on the diagonal it crosses")
	for cell in diagonal:
		assert_eq(cell.x, cell.y, "%s on the diagonal, none beside it" % cell)
	var mirror := g.area_cells("line", 50, CombatGrid.line_origin(me, 1, Vector2(aim.x, -aim.y)), Vector2(aim.x, -aim.y))
	assert_eq(mirror.size(), short.size(), "aimed the other way round the row: the same shape mirrored")
	for cell in short:
		assert_true(Vector2i(cell.x, 2 * me.y - cell.y) in mirror, "%s mirrored" % cell)


func test_a_10_ft_line_straight_from_one_square_is_two_rows_wide() -> void:
	var rows: Array = []
	for i in 9:
		rows.append("................")
	var g := CombatGrid.from_rows(rows)
	var me := Vector2i(2, 4)
	var gust := g.area_cells("line", 60, CombatGrid.line_origin(me, 1, Vector2.RIGHT, 10), Vector2.RIGHT, 10)
	assert_eq(gust.size(), 24, "12 squares long, 2 wide")
	for cell in gust:
		assert_true(cell.y in [4, 5] and cell.x >= 3 and cell.x <= 14, "%s in the two rows" % cell)


func test_a_line_aims_anywhere_but_settles_on_a_row_or_diagonal_when_close() -> void:
	assert_eq(CombatGrid.line_aim(Vector2(10, 0.2)), Vector2.RIGHT, "a degree off a row: along the row")
	assert_eq(CombatGrid.line_aim(Vector2(-3, -3.05)), Vector2(-1, -1).normalized(), "close to a diagonal: along it")
	var slant := CombatGrid.line_aim(Vector2(11, -4.5))
	assert_true(slant.distance_to(Vector2(11, -4.5).normalized()) < 0.0001, "anywhere else: just where it's pointed")


func test_a_15_ft_cone_is_an_even_wedge_in_all_eight_directions() -> void:
	var rows: Array = []
	for i in 11:
		rows.append("...........")
	var g := CombatGrid.from_rows(rows)
	var me := Vector2i(5, 5)
	var straight := g.cone_from(me, 1, Vector2(9.5, 5.5), 15)
	assert_eq(straight.size(), 7, "straight out: 1, then 3, then 3 squares")
	for want: Vector2i in [Vector2i(6, 5), Vector2i(7, 4), Vector2i(7, 5), Vector2i(7, 6), Vector2i(8, 4), Vector2i(8, 5), Vector2i(8, 6)]:
		assert_true(want in straight, "%s in the cone" % want)
	var diagonal := g.cone_from(me, 1, Vector2(9.5, 9.5), 15)
	assert_eq(diagonal.size(), 6)
	for cell in diagonal:
		assert_true(Vector2i(cell.y, cell.x) in diagonal, "a diagonal cone is mirror-symmetric (no L)")
	# Every direction gives the same number of squares; a slightly-off aim points where it's aimed (owner, 2026-10-18:
	# "we should be able to aim them freely"), so it no longer takes the straight cone's squares.
	for aim: Vector2 in [Vector2(1.5, 5.5), Vector2(5.5, 1.5), Vector2(5.5, 9.5), Vector2(1.5, 1.5), Vector2(9.5, 1.5), Vector2(1.5, 9.5)]:
		var n := g.cone_from(me, 1, aim, 15).size()
		assert_true(n == 7 or n == 6, "%s: %d squares" % [aim, n])
	assert_ne(g.cone_from(me, 1, Vector2(9.5, 7.5), 15), straight, "aimed between the row and the diagonal, it turns that way")


func test_walls_stop_areas() -> void:
	var g := CombatGrid.from_rows([".......", "...#...", "...#...", "...#...", "......."])
	var cells := g.area_cells("sphere", 15, Vector2(2, 2.5))
	assert_false(Vector2i(4, 2) in cells, "behind the wall from the origin")
	assert_true(Vector2i(1, 2) in cells)


func test_an_emanation_is_round() -> void:
	# Everything within its reach of the creature's space, measured straight (owner, 2026-10-12: "round the rule too").
	var g := CombatGrid.from_rows([".........", ".........", ".........", ".........", ".........", ".........", ".........", ".........", "........."])
	var me := Vector2i(4, 4)
	var five := g.area_cells("emanation", 5, Vector2(4.5, 4.5), Vector2.RIGHT, 5, me, 1)
	assert_eq(five.size(), 8, "5 ft: every square touching it, the diagonals too")
	var ten := g.area_cells("emanation", 10, Vector2(4.5, 4.5), Vector2.RIGHT, 5, me, 1)
	assert_eq(ten.size(), 20, "10 ft: the 5x5 block less its own square and the four far corners")
	assert_true(Vector2i(6, 5) in ten and Vector2i(4, 2) in ten)
	assert_false(Vector2i(6, 6) in ten, "a far corner square is past 10 ft measured straight")
	var big := g.area_cells("emanation", 5, Vector2(4, 4), Vector2.RIGHT, 5, Vector2i(3, 3), 2)
	assert_eq(big.size(), 12, "a Large creature's 5 ft: every square touching its 2x2")


func test_a_creature_is_in_an_emanation_when_one_of_its_squares_is() -> void:
	var g := CombatGrid.from_rows([".........", ".........", ".........", ".........", ".........", ".........", ".........", ".........", "........."])
	var me := Vector2i(4, 4)
	assert_true(g.in_emanation(me, 1, 10, Vector2i(6, 5), 1), "two squares out, one across")
	assert_false(g.in_emanation(me, 1, 10, Vector2i(6, 6), 1), "a far corner")
	assert_false(g.in_emanation(me, 1, 10, Vector2i(1, 4), 1), "three squares off")
	assert_true(g.in_emanation(me, 1, 10, Vector2i(1, 4), 2), "a Large creature there has a square two off")
	assert_true(g.in_emanation(me, 1, 5, Vector2i(5, 5), 1), "5 ft takes the diagonal")
	assert_true(g.in_emanation(me, 1, 10, me, 1, 0, 10), "straight above, 10 ft up")
	assert_false(g.in_emanation(me, 1, 10, Vector2i(5, 4), 1, 0, 10), "10 ft up and a square across is further")


func test_area_outlines_match_their_shapes() -> void:
	var sphere := CombatGrid.area_outline("sphere", 20, Vector2(4, 3))
	assert_eq(sphere["circle"], Vector2(4, 3))
	assert_eq(float(sphere["radius"]), 4.0, "a 20 ft radius is four squares")
	assert_eq(CombatGrid.area_outline("cylinder", 10, Vector2(1, 1))["radius"], 2.0)
	var em := CombatGrid.area_outline("emanation", 10, Vector2(4.5, 4.5), Vector2.RIGHT, 5, Vector2i(4, 4), 1)
	assert_eq(em["rect"], Rect2(4, 4, 1, 1), "round the creature's own square")
	assert_eq(float(em["radius"]), 2.0)
	var cone := CombatGrid.area_outline("cone", 15, Vector2(2, 2.5), Vector2.RIGHT)["points"] as PackedVector2Array
	assert_eq(cone, PackedVector2Array([Vector2(2, 2.5), Vector2(5, 1), Vector2(5, 4)]), "a triangle as wide as it is long")
	var cube := CombatGrid.area_outline("cube", 15, Vector2(2, 2.5), Vector2.RIGHT)["points"] as PackedVector2Array
	assert_eq(cube, PackedVector2Array([Vector2(2, 1), Vector2(5, 1), Vector2(5, 4), Vector2(2, 4)]))
	var line := CombatGrid.area_outline("line", 30, Vector2(0, 2.5), Vector2.RIGHT)["points"] as PackedVector2Array
	assert_eq(line, PackedVector2Array([Vector2(0, 2), Vector2(6, 2), Vector2(6, 3), Vector2(0, 3)]))
	assert_true(CombatGrid.area_outline("ring", 10, Vector2.ZERO).is_empty(), "nothing for a shape it doesn't know")
