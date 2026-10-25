extends TestCase
## Cones, Thunderwave's cube and the other areas aimed from a creature point at any angle (owner, 2026-10-18: "For AoE
## spells like cone of cold, we should be able to aim them freely (not have it locked to certain boxes)"). A cone starts
## where its aim leaves the caster's space and takes every square at least a quarter inside its triangle; Thunderwave's
## cube turns about the caster and takes every square whose middle is inside it. Straight out and diagonally they take
## the same squares as before. Foes' cones point straight at their target the same way (owner, 2026-10-18: "Opponents
## can free aim too").

const ANGLES: Array[float] = [0.0, 10.0, 22.5, 30.0, 45.0, 63.0, 100.0, 200.0, 290.0, 333.0]


func _grid(w: int = 30, d: int = 30) -> CombatGrid:
	var rows: Array = []
	for z in d:
		rows.append(".".repeat(w))
	return CombatGrid.from_rows(rows)


func _field() -> Encounter:
	var rows: Array = []
	for z in 16:
		rows.append("....................")
	return TestCombat.encounter(rows)


func _wizard(e: Encounter, cell: Vector2i) -> Combatant:
	var ch := TestChars.custom("wizard", "human", 9)
	var prepared := (ch.spellcasting[0] as Dictionary)["prepared"] as Array
	for id: String in ["cone_of_cold", "burning_hands", "thunderwave", "lightning_bolt", "fireball"]:
		if not id in prepared:
			prepared.append(id)
	ch.finish_long_rest()
	return e.add(ch, &"party", cell)


## A point 5 squares from the middle of a `size`-square space at `me`, `deg` degrees round from straight along +x.
func _toward(me: Vector2i, size: int, deg: float) -> Vector2:
	return Vector2(me.x + size / 2.0, me.y + size / 2.0) + Vector2.from_angle(deg_to_rad(deg)) * 5.0


## A cone's triangle: from its origin, `r` squares long, as wide at its end as it is long.
func _triangle(origin: Vector2, dir: Vector2, r: float) -> PackedVector2Array:
	var side := Vector2(-dir.y, dir.x)
	var far := origin + dir * r
	return PackedVector2Array([origin, far - side * r / 2.0, far + side * r / 2.0])


## How much of `cell` lies inside `poly`, from a 10 x 10 grid of points in it (apart from the game's own clipping).
func _share(cell: Vector2i, poly: PackedVector2Array) -> float:
	var n := 0
	for i in 10:
		for j in 10:
			if Geometry2D.is_point_in_polygon(Vector2(cell.x + (i + 0.5) / 10.0, cell.y + (j + 0.5) / 10.0), poly):
				n += 1
	return n / 100.0


## The squares near `poly` (its bounding box and one more all round) on the grid.
func _near(g: CombatGrid, poly: PackedVector2Array) -> Array[Vector2i]:
	var lo := Vector2(INF, INF)
	var hi := Vector2(-INF, -INF)
	for p in poly:
		lo = lo.min(p)
		hi = hi.max(p)
	var out: Array[Vector2i] = []
	for z in range(floori(lo.y) - 1, ceili(hi.y) + 1):
		for x in range(floori(lo.x) - 1, ceili(hi.x) + 1):
			if g.in_bounds(Vector2i(x, z)):
				out.append(Vector2i(x, z))
	return out


## `cells` mirrored across the row whose doubled index is `row2`, sorted.
func _mirror_row(cells: Array, row2: int) -> Array:
	var out: Array = []
	for c: Vector2i in cells:
		out.append(Vector2i(c.x, row2 - c.y))
	out.sort()
	return out


func _sorted(cells: Array) -> Array:
	var out: Array = []
	out.append_array(cells)
	out.sort()
	return out


func test_a_cone_points_exactly_where_it_is_aimed() -> void:
	for deg in ANGLES:
		var aim := CombatGrid.cone_aim(Vector2i(14, 14), 1, _toward(Vector2i(14, 14), 1, deg))
		assert_true((aim[1] as Vector2).distance_to(Vector2.from_angle(deg_to_rad(deg))) < 0.0001,
			"%s degrees: no snapping to the eight directions (%s)" % [deg, aim[1]])


func test_it_starts_where_the_aim_leaves_the_casters_space() -> void:
	assert_eq(CombatGrid.cone_aim(Vector2i(5, 5), 1, Vector2(9.5, 5.5))[0], Vector2(6, 5.5), "straight out: the middle of the facing edge")
	assert_eq(CombatGrid.cone_aim(Vector2i(5, 5), 1, Vector2(9.5, 9.5))[0], Vector2(6, 6), "diagonally: the corner")
	assert_true((CombatGrid.cone_aim(Vector2i(5, 5), 1, Vector2(9.5, 7.5))[0] as Vector2).distance_to(Vector2(6, 5.75)) < 0.0001,
		"at a slant: where the line from the middle crosses the edge")
	assert_eq(CombatGrid.cone_aim(Vector2i(4, 4), 2, Vector2(5, 0))[0], Vector2(5, 4), "a Large space, straight up: the middle of its top edge")
	for size: int in [1, 2, 3]:
		for deg in ANGLES:
			var me := Vector2i(10, 10)
			var o := CombatGrid.cone_aim(me, size, _toward(me, size, deg))[0] as Vector2
			var off := o - Vector2(me.x + size / 2.0, me.y + size / 2.0)
			assert_true(absf(maxf(absf(off.x), absf(off.y)) - size / 2.0) < 0.0001, "%d squares, %s degrees: on the edge of the space" % [size, deg])


func test_a_cone_takes_the_squares_its_triangle_covers_at_any_angle() -> void:
	var g := _grid()
	for size: int in [1, 2]:
		var me := Vector2i(14, 14)
		for ft: int in [15, 30, 60]:
			for deg in ANGLES:
				var toward := _toward(me, size, deg)
				var aim := CombatGrid.cone_aim(me, size, toward)
				var tri := _triangle(aim[0] as Vector2, aim[1] as Vector2, ft / 5.0)
				var cells := g.cone_from(me, size, toward, ft)
				var own := CombatGrid.footprint(me, size)
				for cell in _near(g, tri):
					if cell in own:
						assert_false(cell in cells, "never the caster's own square")
						continue
					var share := _share(cell, tri)
					if share >= 0.3:
						assert_true(cell in cells, "%d ft from %d squares at %s degrees: %s is %d%% inside" % [ft, size, deg, cell, roundi(share * 100)])
					elif share <= 0.2:
						assert_false(cell in cells, "%d ft from %d squares at %s degrees: %s is only %d%% inside" % [ft, size, deg, cell, roundi(share * 100)])


func test_straight_and_diagonal_cones_keep_their_squares() -> void:
	# The squares cones took when they could only point eight ways (so fights tuned with them don't move).
	var g := _grid()
	var me := Vector2i(14, 14)
	var counts := {15: [7, 6], 30: [24, 20], 60: [84, 81]}
	for ft: int in counts:
		var straight := g.cone_from(me, 1, _toward(me, 1, 0.0), ft)
		for k in 8:
			var n := g.cone_from(me, 1, _toward(me, 1, k * 45.0), ft).size()
			assert_eq(n, int((counts[ft] as Array)[k % 2]), "%d ft at %d degrees" % [ft, k * 45])
		assert_true(Vector2i(15, 14) in straight and not Vector2i(14, 14) in straight)
	var hands := g.cone_from(me, 1, _toward(me, 1, 0.0), 15)
	for want: Vector2i in [Vector2i(15, 14), Vector2i(16, 13), Vector2i(16, 14), Vector2i(16, 15), Vector2i(17, 13), Vector2i(17, 14), Vector2i(17, 15)]:
		assert_true(want in hands, "%s: 1, then 3, then 3 squares" % want)


func test_a_cone_mirrors_across_its_row_and_its_diagonal() -> void:
	var g := _grid()
	var me := Vector2i(14, 14)
	for deg: float in [12.0, 20.0, 33.0]:
		var up := g.cone_from(me, 1, _toward(me, 1, -deg), 30)
		var down := g.cone_from(me, 1, _toward(me, 1, deg), 30)
		assert_eq(_mirror_row(up, 2 * me.y), _sorted(down), "%s degrees either side of the row" % deg)
		var across := g.cone_from(me, 1, _toward(me, 1, 90.0 - deg), 30)
		var swapped: Array = []
		for c: Vector2i in down:
			swapped.append(Vector2i(c.y, c.x))
		swapped.sort()
		assert_eq(swapped, _sorted(across), "%s degrees either side of the diagonal" % deg)


func test_cone_of_cold_hits_what_its_outline_and_preview_show() -> void:
	var e := _field()
	var c := _wizard(e, Vector2i(2, 12))
	TestCombat.start_with(e, c)
	var s := Compendium.shared().spell_data("cone_of_cold")
	var aim := Vector2.from_angle(deg_to_rad(-33.0))
	var cells := e.spells.area_for(c, s, Vector2.INF, aim, 5)
	var snapped := e.spells.area_for(c, s, Vector2.INF, Vector2.RIGHT, 5)
	var outline := e.spells.targeting.area_outline(c, s, Vector2.INF, aim, 5)["points"] as PackedVector2Array
	assert_eq(outline.size(), 3, "a triangle")
	assert_true((outline[0] - CombatGrid.cone_aim(c.cell, 1, e.center_of(c) + aim)[0]).length() < 0.0001, "from where the aim leaves the square")
	for cell in cells:
		assert_true(_share(cell, outline) >= 0.2, "%s inside the outline" % cell)
	# Foes inside the turned cone, and one the old row-wise cone would have taken.
	var inside: Array[Combatant] = []
	for cell: Vector2i in [Vector2i(6, 9), Vector2i(9, 7), Vector2i(12, 6)]:
		assert_true(cell in cells, "%s in the cone aimed up and right" % cell)
		inside.append(TestCombat.punching_bag(e, cell, 200))
	var left_out := Vector2i(12, 13)
	assert_true(left_out in snapped and not left_out in cells, "%s only in the row-wise cone" % left_out)
	var spared := TestCombat.punching_bag(e, left_out, 200)
	var cat := ActionCatalog.new(e)
	var pv := cat.spell_preview(c, cat.find(c, "spell:cone_of_cold"), Vector2.INF, aim, 5)
	var shown := (pv["creatures"] as Array).map(func(w: Dictionary) -> String: return str(w["id"]))
	assert_eq(shown.size(), 3, "the preview lists the three in the cone")
	for v in inside:
		assert_true(v.id in shown, "%s shown" % v.name())
	e.events.clear()
	var r := e.spells.cast(c, "cone_of_cold", 5, [], Vector2.INF, aim)
	assert_true(r.ok, r.reason)
	for v in inside:
		assert_true(v.creature.hp < 200, "%s frozen" % v.name())
	assert_eq(spared.creature.hp, 200, "the one along the row untouched")
	var cast := e.events.filter(func(ev: Dictionary) -> bool: return str(ev["type"]) == "spell")
	assert_eq(_sorted((cast[0] as Dictionary)["cells"]), _sorted(cells), "the cast takes the squares the preview showed")


func test_thunderwave_turns_with_the_aim() -> void:
	var e := _field()
	var c := _wizard(e, Vector2i(6, 8))
	TestCombat.start_with(e, c)
	var s := Compendium.shared().spell_data("thunderwave")
	for deg: float in [0.0, 30.0, 45.0, 110.0, 250.0]:
		var aim := Vector2.from_angle(deg_to_rad(deg))
		var square := e.spells.targeting.area_outline(c, s, Vector2.INF, aim)["points"] as PackedVector2Array
		assert_eq(square.size(), 4)
		var start := e.center_of(c) + aim * 0.5
		assert_true(((square[0] + square[3]) / 2.0).distance_to(start) < 0.0001, "%s degrees: its back face at the caster" % deg)
		assert_true(((square[1] + square[2]) / 2.0).distance_to(start + aim * 3.0) < 0.0001, "15 ft that way")
		var cells := e.spells.area_for(c, s, Vector2.INF, aim)
		assert_false(c.cell in cells, "never the caster's own square")
		for cell in _near(e.grid, square):
			# Where its middle is, along the aim and across it, from the back face's middle (a middle right on an edge is
			# a tie either way).
			var v := Vector2(cell.x + 0.5, cell.y + 0.5) - start
			var along := v.dot(aim)
			var across := absf(v.dot(Vector2(-aim.y, aim.x)))
			if cell == c.cell or absf(across - 1.5) < 0.001 or absf(along) < 0.001 or absf(along - 3.0) < 0.001:
				continue
			var inside := along > 0.0 and along < 3.0 and across < 1.5
			assert_eq(cell in cells, inside, "%s degrees: %s in it exactly when its middle is" % [deg, cell])
		assert_between(cells.size(), 7, 11, "%s degrees: about its 9 squares" % deg)
	assert_eq(e.spells.area_for(c, s, Vector2.INF, Vector2.RIGHT).size(), 9, "straight out: still its 3 x 3 squares")


func test_a_foes_cone_goes_straight_at_its_target() -> void:
	var e := _field()
	var c := _wizard(e, Vector2i(2, 12))
	TestCombat.start_with(e, c)
	var act := {"area": {"shape": "cone", "size": 30}, "targets": {}}
	# Aimed about 22 degrees up from the row, which it used to turn along.
	var target := TestCombat.foe(e, "zombie", Vector2i(7, 10))
	var beside := TestCombat.foe(e, "zombie", Vector2i(4, 11))
	var below := TestCombat.foe(e, "zombie", Vector2i(6, 13))
	var caught := e.monster_actions.save_victims(c, act, target)
	assert_true(target in caught and beside in caught, "the one aimed at and the one on the way")
	assert_false(below in caught, "not the one below the row that the row-wise cone took")
	# The mage's cone, with no zombie of its own side in the way (a cone through them is never cast).
	var e2 := _field()
	var c2 := _wizard(e2, Vector2i(2, 12))
	TestCombat.start_with(e2, c2)
	var mage := TestCombat.foe(e2, "mage", Vector2i(16, 4))
	var plan := e2.ai.spells._best_use(mage, "cone_of_cold")
	assert_false(plan.is_empty(), "a mage weighs its Cone of Cold")
	if not plan.is_empty():
		var d := plan["direction"] as Vector2
		var at := (e2.center_of(c2) - e2.center_of(mage)).normalized()
		assert_true(d.distance_to(at) < 0.0001, "straight at the wizard, not along a diagonal (%s)" % d)


func test_the_test_autopilot_keeps_its_eight_directions() -> void:
	# The fights were tuned with its cones along a row, column or diagonal (PartyAutopilot._cone_dir).
	assert_eq(CombatGrid.grid_aim(Vector2(5, -2)), Vector2.RIGHT)
	assert_eq(CombatGrid.grid_aim(Vector2(-3, -3.4)), Vector2(-1, -1).normalized())
	assert_eq(CombatGrid.grid_aim(Vector2.ZERO), Vector2.RIGHT)


func test_a_dragonborns_cone_breath_goes_where_it_is_pointed() -> void:
	var e := _field()
	var d := e.add(TestChars.custom("fighter", "dragonborn", 5, {"draconic_ancestry": ["red_dragon"]}), &"party", Vector2i(2, 12))
	var aimed := TestCombat.punching_bag(e, Vector2i(5, 11), 80)
	var below := TestCombat.punching_bag(e, Vector2i(5, 13), 80)
	TestCombat.start_with(e, d)
	var r := e.feature_actions.perform(d, "breath_weapon:cone", null, e.center_of(aimed))
	assert_true(r.ok, r.reason)
	assert_true(aimed.creature.hp < 80, "the one it was pointed at")
	assert_eq(below.creature.hp, 80, "not the one below the row that the row-wise cone took")


func test_how_far_each_aimed_area_reaches() -> void:
	var e := _field()
	var c := _wizard(e, Vector2i(2, 12))
	TestCombat.start_with(e, c)
	var cat := ActionCatalog.new(e)
	assert_eq(cat.aim_ft(c, cat.find(c, "spell:lightning_bolt")), 100)
	assert_eq(cat.aim_ft(c, cat.find(c, "spell:cone_of_cold")), 60)
	assert_eq(cat.aim_ft(c, cat.find(c, "spell:burning_hands")), 15)
	assert_eq(cat.aim_ft(c, cat.find(c, "spell:thunderwave")), 15)
	assert_eq(cat.aim_ft(c, cat.find(c, "spell:fireball")), 0, "placed at a point, not aimed from the caster")
	assert_eq(cat.aim_ft(c, {"id": "feat:breath_weapon:cone", "targeting": "direction"}), 15)
	assert_eq(cat.aim_ft(c, {"id": "feat:breath_weapon:line", "targeting": "direction"}), 30)


func test_cones_and_lines_are_the_size_the_rules_give() -> void:
	# Owner, 2026-10-18: "Is the cone of cold 60ft cone accurate? It seems small". A Cone is as wide at its end as it is
	# long (2024 rules glossary): Cone of Cold's 60 ft is 12 squares out and 12 across at the far end.
	var e := _field()
	var c := _wizard(e, Vector2i(2, 8))
	TestCombat.start_with(e, c)
	var cold := Compendium.shared().spell_data("cone_of_cold")
	var tri := e.spells.targeting.area_outline(c, cold, Vector2.INF, Vector2.RIGHT)["points"] as PackedVector2Array
	assert_eq(tri, PackedVector2Array([Vector2(3, 8.5), Vector2(15, 2.5), Vector2(15, 14.5)]), "12 squares long, 12 wide at its end")
	var g := _grid(40, 30)
	var me := Vector2i(14, 14)
	var cone := g.cone_from(me, 1, _toward(me, 1, 0.0), 60)
	var columns := {}
	for cell in cone:
		columns[cell.x] = int(columns.get(cell.x, 0)) + 1
	assert_eq(columns.keys().size(), 12, "it reaches 12 squares out")
	assert_eq(columns.keys().min(), 15, "from the square in front of the caster")
	assert_eq(int(columns[26]), 13, "the last of them 13 squares across (12, and the squares the edges cut a quarter of)")
	assert_eq(cone.size(), 84, "84 squares in all; the cone's own area is 72")
	for spell: Array in [["burning_hands", 3], ["fear", 6], ["color_spray", 3], ["prismatic_spray", 12], ["conjure_barrage", 12]]:
		var s := Compendium.shared().spell_data(str(spell[0]))
		var pts := e.spells.targeting.area_outline(c, s, Vector2.INF, Vector2.RIGHT)["points"] as PackedVector2Array
		var n := float(spell[1])
		assert_true(absf(pts[1].x - pts[0].x - n) < 0.001 and absf(pts[2].y - pts[1].y - n) < 0.001, "%s: %d long, %d wide at its end" % [spell[0], int(n), int(n)])
	var bolt := g.area_cells("line", 100, CombatGrid.line_origin(Vector2i(5, 14), 1, Vector2.RIGHT), Vector2.RIGHT)
	assert_eq(bolt.size(), 20, "Lightning Bolt: 100 ft, 20 squares in a row")
	for cell in bolt:
		assert_eq(cell.y, 14, "one square wide")
