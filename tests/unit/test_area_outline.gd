extends TestCase
## An area spell's edge drawn on the floor while it's aimed and as it goes off, in place of its squares painted orange
## (owner, 2026-10-12: "for AoE spells, don't make the floor orange. Instead show a circular border which shows the area
## that would be affected"; Fireball, Hypnotic Pattern, Thunderwave, Burning Hands and the like): a circle round a
## radius, the rounded edge of an emanation, a cone's triangle, a cube's square (SpellTargeting.area_outline), and the
## line it's drawn along (GridOverlay.outline_loops).


func _wizard(e: Encounter, cell: Vector2i) -> Combatant:
	var ch := TestChars.custom("wizard", "human", 7)
	var prepared := (ch.spellcasting[0] as Dictionary)["prepared"] as Array
	for id: String in ["fireball", "burning_hands", "thunderwave", "hypnotic_pattern", "wall_of_fire"]:
		if not id in prepared:
			prepared.append(id)
	ch.finish_long_rest()
	return e.add(ch, &"party", cell)


func _spell(id: String) -> Dictionary:
	return Compendium.shared().spell_data(id)


func _centre(cell: Vector2i) -> Vector2:
	return Vector2(cell.x + 0.5, cell.y + 0.5)


func test_a_fireball_shows_a_circle_round_its_point() -> void:
	var e := TestCombat.open_field()
	var c := _wizard(e, Vector2i(1, 1))
	TestCombat.start_with(e, c)
	var cat := ActionCatalog.new(e)
	var pv := cat.spell_preview(c, cat.find(c, "spell:fireball"), Vector2(6, 4), Vector2.ZERO)
	var outline := pv["outline"] as Dictionary
	assert_eq(outline.get("circle"), Vector2(6, 4), "round the point it's aimed at")
	assert_eq(float(outline.get("radius", 0.0)), 4.0, "20 ft")
	assert_false((pv["cells"] as Array).is_empty())
	for cell: Vector2i in pv["cells"]:
		assert_true(_centre(cell).distance_to(Vector2(6, 4)) <= 4.001, "%s inside the circle" % cell)


func test_cubes_and_cones_keep_their_shapes() -> void:
	var e := TestCombat.open_field()
	var c := _wizard(e, Vector2i(2, 2))
	TestCombat.start_with(e, c)
	var t := e.spells.targeting
	# Thunderwave: a 15-ft cube from the caster's side, the way it's aimed.
	var wave := t.area_outline(c, _spell("thunderwave"), Vector2.INF, Vector2.RIGHT)
	var square := wave["points"] as PackedVector2Array
	assert_eq(square, PackedVector2Array([Vector2(3, 1), Vector2(6, 1), Vector2(6, 4), Vector2(3, 4)]))
	for cell in t.area_for(c, _spell("thunderwave"), Vector2.INF, Vector2.RIGHT):
		assert_true(Geometry2D.is_point_in_polygon(_centre(cell), square), "%s inside the square" % cell)
	# Burning Hands: a 15-ft cone from the middle of the caster's side.
	var hands := t.area_outline(c, _spell("burning_hands"), Vector2.INF, Vector2.RIGHT)["points"] as PackedVector2Array
	assert_eq(hands, PackedVector2Array([Vector2(3, 2.5), Vector2(6, 1), Vector2(6, 4)]), "a triangle")
	# Hypnotic Pattern: a 30-ft cube at a point.
	var pattern := t.area_outline(c, _spell("hypnotic_pattern"), Vector2(8, 5), Vector2.RIGHT)["points"] as PackedVector2Array
	assert_eq(pattern.size(), 4)
	for cell in t.area_for(c, _spell("hypnotic_pattern"), Vector2(8, 5), Vector2.RIGHT):
		assert_true(Geometry2D.is_point_in_polygon(_centre(cell), pattern), "%s inside the square" % cell)


func test_an_emanation_shows_its_round_edge() -> void:
	var e := TestCombat.open_field()
	var c := TestCombat.hero(e, "hedda_ironvow", Vector2i(4, 4), 5)
	TestCombat.start_with(e, c)
	var outline := e.spells.targeting.area_outline(c, _spell("spirit_guardians"), Vector2.INF, Vector2.ZERO)
	assert_eq(outline.get("rect"), Rect2(4, 4, 1, 1), "round the caster's own square")
	assert_eq(float(outline.get("radius", 0.0)), 3.0, "15 ft")
	var cells := e.spells.area_for(c, _spell("spirit_guardians"), Vector2.INF, Vector2.ZERO)
	assert_false(Vector2i(7, 7) in cells, "the far corner is outside the round edge, and outside the area")
	assert_true(Vector2i(7, 5) in cells)


func test_a_wall_shows_its_squares_edges() -> void:
	var e := TestCombat.open_field()
	var c := _wizard(e, Vector2i(1, 1))
	TestCombat.start_with(e, c)
	var cat := ActionCatalog.new(e)
	var wall := cat.find(c, "spell:wall_of_fire")
	assert_false(wall.is_empty())
	if wall.is_empty():
		return
	var pv := cat.spell_preview(c, wall, Vector2(6, 4), Vector2.RIGHT)
	assert_true((pv["outline"] as Dictionary).is_empty(), "no shape: the board outlines its squares")


func test_the_cast_carries_its_edge_for_the_board() -> void:
	var e := TestCombat.open_field()
	var c := _wizard(e, Vector2i(1, 1))
	TestCombat.start_with(e, c)
	e.events.clear()
	assert_true(e.spells.cast(c, "fireball", 3, [], Vector2(7, 4)).ok)
	var cast := e.events.filter(func(ev: Dictionary) -> bool: return str(ev["type"]) == "spell")
	assert_eq(cast.size(), 1)
	assert_eq((cast[0] as Dictionary)["outline"], {"circle": Vector2(7, 4), "radius": 4.0})


func test_the_line_runs_smoothly_round_a_circle() -> void:
	var loops := GridOverlay.outline_loops({"circle": Vector2(5, 5), "radius": 4.0})
	assert_eq(loops.size(), 1)
	var ring := loops[0]
	assert_true(ring.size() >= 200, "enough points to look round (%d)" % ring.size())
	for p in ring:
		assert_between(p.distance_to(Vector2(5, 5)), 3.999, 4.001)
	for i in ring.size():
		assert_true(ring[i].distance_to(ring[(i + 1) % ring.size()]) <= GridOverlay.OUTLINE_STEP + 0.001)


func test_an_emanations_line_is_round_with_straight_sides() -> void:
	var loops := GridOverlay.outline_loops({"rect": Rect2(3, 3, 2, 2), "radius": 1.0})
	assert_eq(loops.size(), 1)
	for p in loops[0]:
		var gap := Vector2(maxf(0.0, absf(p.x - 4.0) - 1.0), maxf(0.0, absf(p.y - 4.0) - 1.0))
		assert_between(gap.length(), 0.999, 1.001, "every point 5 ft from the Large creature's squares")


func test_squares_without_a_shape_are_outlined_round_their_outer_edge() -> void:
	var block := GridOverlay.outline_loops({}, [Vector2i(0, 0), Vector2i(1, 0), Vector2i(0, 1), Vector2i(1, 1)])
	assert_eq(block.size(), 1, "one line round a block")
	for p in block[0]:
		assert_true(p.x <= 0.0001 or p.x >= 1.9999 or p.y <= 0.0001 or p.y >= 1.9999, "on the block's edge, never through it")
	var apart := GridOverlay.outline_loops({}, [Vector2i(0, 0), Vector2i(5, 5)])
	assert_eq(apart.size(), 2, "a line round each patch")
	assert_true(GridOverlay.outline_loops({}, []).is_empty())
