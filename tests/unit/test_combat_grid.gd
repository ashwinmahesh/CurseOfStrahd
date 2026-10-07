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
	# 10 ft up: 5 ft for the square plus 2 ft per foot of rise beyond the first 5 (the climb).
	assert_eq(g.step_cost(Vector2i(0, 0), Vector2i(1, 0), 1, _none, _none), 25)
	assert_eq(g.step_cost(Vector2i(1, 0), Vector2i(0, 0), 1, _none, _none), 5, "dropping 10 ft is allowed")


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
	# Every direction gives the same number of squares, and a slightly-off aim snaps to the nearest direction.
	for aim: Vector2 in [Vector2(1.5, 5.5), Vector2(5.5, 1.5), Vector2(5.5, 9.5), Vector2(1.5, 1.5), Vector2(9.5, 1.5), Vector2(1.5, 9.5)]:
		var n := g.cone_from(me, 1, aim, 15).size()
		assert_true(n == 7 or n == 6, "%s: %d squares" % [aim, n])
	assert_eq(g.cone_from(me, 1, Vector2(9.5, 6.3), 15), straight, "aim snaps to the nearest of the eight directions")


func test_walls_stop_areas() -> void:
	var g := CombatGrid.from_rows([".......", "...#...", "...#...", "...#...", "......."])
	var cells := g.area_cells("sphere", 15, Vector2(2, 2.5))
	assert_false(Vector2i(4, 2) in cells, "behind the wall from the origin")
	assert_true(Vector2i(1, 2) in cells)
