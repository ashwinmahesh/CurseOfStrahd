extends TestCase
## Natural shores (the vault's Natural Maps Plan, N3; world/look/shores.gd): in the Modern look the edge of a map's water
## is a smooth, wandering contour, not the staircase of its water squares. What must stay true: the contour keeps within a
## half a square of the grid line so the middle of every walkable square beside water stays dry and level, a square a
## prop or a build stands on keeps its edge, convex corners round off, the edge wanders, the ground reaches out over the
## water squares beside it and dips under the water, the water shader's mask follows the contour, the rules never see it
## and Classic keeps its squares.

## Places with flat banks at the water's level, each with water the shore draws.
const SIDES: Array[Vector2i] = [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]
const PLACES: Array[String] = ["zarovich_reed_island", "tser_pool", "bog_causeway", "lake_zarovich", "berez", "road_ravine",
	"berez_marsh_track", "barrow_moor", "lake_inlet"]


func before_each() -> void:
	GameState.reset()
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


func _shore(v: LocationView) -> Shores:
	var relief := v.atmosphere.land.relief
	return relief.shore if relief != null else null


## The walkable squares with water beside them (eight ways).
func _banks(v: LocationView) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	for z in v.grid.depth:
		for x in v.grid.width:
			var c := Vector2i(x, z)
			if v.grid.has_flag(c, CombatGrid.WATER) or v.grid.has_flag(c, CombatGrid.WALL) or v.grid.has_flag(c, CombatGrid.VOID):
				continue
			for d: Vector2i in CombatGrid.DIRS:
				if v.grid.in_bounds(c + d) and v.grid.has_flag(c + d, CombatGrid.WATER):
					out.append(c)
					break
	return out


## The middle of every walkable square beside water stays dry and level, and every grid line between a walkable square
## and water has the contour within about half a square of it: in every place with flat banks.
func test_the_contour_keeps_within_half_a_square_of_the_grid_line() -> void:
	Look.set_style("modern", false)
	for id: String in PLACES:
		var v := _view(id)
		var shore := _shore(v)
		assert_true(shore != null, "%s has a shore" % id)
		if shore == null:
			v.queue_free()
			continue
		var checked := 0
		for c in _banks(v):
			var mid := Vector2(c.x + 0.5, c.y + 0.5)
			assert_true(shore.distance_at(mid) <= -0.17, "%s: the middle of %s is dry (%.2f)" % [id, c, shore.distance_at(mid)])
			for d: Vector2i in SIDES:
				if v.grid.in_bounds(c + d) and v.grid.has_flag(c + d, CombatGrid.WATER):
					var edge := mid + Vector2(d) * 0.5
					assert_true(absf(shore.distance_at(edge)) <= Shores.MAX_SHIFT + 0.12, "%s: the shore at the edge of %s is within half a square of the line (%.2f)" % [id, c, shore.distance_at(edge)])
					checked += 1
		assert_true(checked > 8, "%s: edges between walkable squares and water were checked (%d)" % [id, checked])
		v.queue_free()


## The ground in the middle of a walkable square beside water is where a token stands (within 0.05).
func test_the_ground_beside_water_is_level_where_people_stand() -> void:
	Look.set_style("modern", false)
	for id: String in ["zarovich_reed_island", "tser_pool", "bog_causeway"]:
		var v := _view(id)
		var relief := v.atmosphere.land.relief
		var shore := _shore(v)
		assert_true(shore != null, "%s has a shore" % id)
		for c in _banks(v):
			if not relief.skinned(c):
				continue
			var mid := Vector2(c.x + 0.5, c.y + 0.5)
			assert_true(absf(relief.height(mid) - v.board.ground_y(mid)) <= 0.05 + GroundRelief.DEEPEST, "%s: the ground in the middle of %s is within 0.15 of the floor (%.3f)" % [id, c, relief.height(mid) - v.board.ground_y(mid)])
		v.queue_free()


## The edge wanders: along a straight shore the contour is on the water's side of the grid line in places and on the land's
## in others, and a convex corner of land is cut.
func test_the_edge_wanders_and_corners_round() -> void:
	Look.set_style("modern", false)
	var v := _view("zarovich_reed_island")
	var shore := _shore(v)
	var out := 0
	var inward := 0
	var total := 0.0
	var n := 0
	for c in _banks(v):
		for d: Vector2i in SIDES:
			if v.grid.in_bounds(c + d) and v.grid.has_flag(c + d, CombatGrid.WATER):
				var dist := shore.distance_at(Vector2(c.x + 0.5, c.y + 0.5) + Vector2(d) * 0.5)
				total += absf(dist)
				n += 1
				if dist > 0.08:
					inward += 1   # (water past the grid line, over the walkable square)
				elif dist < -0.08:
					out += 1   # (land past it, over the water square)
	assert_true(out > 3 and inward > 3, "the contour lies on both sides of the grid line (%d out over the water, %d in over the land)" % [out, inward])
	assert_true(total / maxf(n, 1.0) > 0.06, "and wanders (%.2f from the line on average)" % (total / maxf(n, 1.0)))
	# A convex corner of land: a grid point with one walkable square and three water ones round it.
	var cut := 0
	var corners := 0
	for z in range(1, v.grid.depth):
		for x in range(1, v.grid.width):
			var land := 0
			for q: Vector2i in [Vector2i(x - 1, z - 1), Vector2i(x, z - 1), Vector2i(x - 1, z), Vector2i(x, z)]:
				if not v.grid.has_flag(q, CombatGrid.WATER):
					land += 1
			if land == 1:
				corners += 1
				if shore.distance_at(Vector2(x, z)) > 0.05:
					cut += 1
	assert_true(corners > 2, "the island has convex corners (%d)" % corners)
	assert_true(cut * 4 >= corners * 3, "and the water cuts most of them (%d of %d)" % [cut, corners])
	v.queue_free()


## The ground reaches out over the water squares beside it and dips under the water; the board's water boxes stay under
## the water squares and a skirt of water goes under the walkable squares beside them.
func test_the_ground_dips_into_the_water() -> void:
	Look.set_style("modern", false)
	var v := _view("tser_pool")
	var relief := v.atmosphere.land.relief
	var shore := _shore(v)
	var drawn := 0
	for c: Vector2i in shore.water_squares():
		assert_true(relief.draws(c), "the ground draws the water square %s it reaches over" % c)
		assert_true(v.grid.has_flag(c, CombatGrid.WATER), "%s is still water to the rules" % c)
		drawn += 1
	assert_true(drawn > 8, "water squares beside the land are drawn by the ground (%d)" % drawn)
	var under := 0
	var over := 0
	for z in v.grid.depth * 4:
		for x in v.grid.width * 4:
			var p := Vector2((x + 0.5) / 4.0, (z + 0.5) / 4.0)
			var wet := shore.is_wet(p)
			var h := relief.height(p)
			if wet and shore.distance_at(p) > 0.4:
				assert_true(h < Shores.WATER_Y, "%s is under the water: the ground is below its level (%.2f)" % [p, h])
				under += 1
			elif shore.distance_at(p) < -0.1 and v.grid.has_flag(Vector2i(floori(p.x), floori(p.y)), CombatGrid.WATER) and shore.water_squares().has(Vector2i(floori(p.x), floori(p.y))):
				assert_true(h > Shores.WATER_Y, "%s is dry land over a water square: the ground is above the water (%.2f)" % [p, h])
				over += 1
	assert_true(under > 0 and over > 0, "some ground is under the water (%d) and some reaches out over water squares (%d)" % [under, over])
	assert_true(v.atmosphere.land.root.find_child("ShoreWater", true, false) != null, "water goes under the bank's dip")
	var boxes := 0
	for n in v.board.get_children():
		if n is MeshInstance3D and (n as MeshInstance3D).mesh is BoxMesh and absf((n as Node3D).position.y + 0.18) < 0.001:
			boxes += 1
	assert_eq(boxes, 72, "the board's 72 water boxes stay")
	v.queue_free()


## The water shader's mask follows the contour: nothing on land, rising from the contour out into the water.
func test_the_foam_follows_the_contour() -> void:
	Look.set_style("modern", false)
	var v := _view("tser_pool")
	var shore := _shore(v)
	var mask := shore.mask()
	var img := mask.get_image()
	assert_eq(img.get_width(), v.grid.width * Shores.RES, "a texel for a third of a square")
	var land := 0
	var shallow := 0
	var deep := 0
	for z in v.grid.depth:
		for x in v.grid.width:
			for k in Shores.RES * Shores.RES:
				var px := Vector2i(x * Shores.RES + k % Shores.RES, z * Shores.RES + k / Shores.RES)
				var p := Vector2((px.x + 0.5) / Shores.RES, (px.y + 0.5) / Shores.RES)
				var d := shore.distance_at(p)
				var value := img.get_pixel(px.x, px.y).r
				if d < -0.1:
					assert_eq(value, 0.0, "the mask is 0 on land at %s" % p)
					land += 1
				elif d > 0.02 and d < 0.3:
					assert_true(value > 0.0 and value < 0.3, "the mask is small just inside the contour at %s (%.2f)" % [p, value])
					shallow += 1
				elif d > 1.5:
					assert_true(value > 0.4, "and larger further out at %s (%.2f)" % [p, value])
					deep += 1
	assert_true(land > 50 and shallow > 5 and deep > 5, "the mask has land, shallows and deep water (%d, %d, %d)" % [land, shallow, deep])
	v.queue_free()


## A place comes back the same from what was kept.
func test_a_place_comes_back_the_same() -> void:
	Look.set_style("modern", false)
	var a := _view("zarovich_reed_island")
	var sa := _shore(a)
	var probes: Array[float] = []
	for k in 40:
		probes.append(sa.distance_at(Vector2(3.0 + k * 0.4, 5.0 + (k % 7) * 0.9)))
	a.queue_free()
	await get_tree().process_frame
	var b := _view("zarovich_reed_island")
	var sb := _shore(b)
	for k in 40:
		assert_eq(sb.distance_at(Vector2(3.0 + k * 0.4, 5.0 + (k % 7) * 0.9)), probes[k], "the same contour at probe %d" % k)
	b.queue_free()


## The Classic look is frozen: its water stays a box a square, and nothing else draws.
func test_classic_keeps_its_squares() -> void:
	Look.set_style("classic", false)
	var v := _view("zarovich_reed_island")
	assert_true(v.atmosphere.land == null or v.atmosphere.land.relief == null or _shore(v) == null, "no shore in Classic")
	assert_true(v.board.find_child("ShoreWater", true, false) == null, "no skirt of water in Classic")
	v.queue_free()


## A bank raised above the water keeps its edge (a step or a cliff is for the cliffs): Van Richten's lake has none of it
## drawn as a shore where its banks stand 15 to 20 ft over the water.
func test_a_raised_bank_keeps_its_face() -> void:
	Look.set_style("modern", false)
	var v := _view("van_richtens_tower")
	var shore := _shore(v)
	if shore != null:
		for c in _banks(v):
			if absf(v.board.floor_y(c)) > Shores.LOW_BANK:
				assert_false(shore.water_squares().has(c), "no water square is drawn beside the raised bank %s" % c)
	v.queue_free()
