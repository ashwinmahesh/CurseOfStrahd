extends TestCase
## Ground with shape in the Modern look (Improvement Ideas W11, docs/art/atmosphere.md "Ground with shape"): on an
## outdoor wild map the walked ground is a shaped skin that never rises above floor level (so tokens, overlays and
## templates keep standing on the grid) with the board's flat boxes lowered under it, wheel ruts run between the ways
## out, the woods' ground rises into banks that the land past the edge carries on from, towns stay as they are, and
## Classic stays flat.


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


## The crossroads: its walked ground is drawn by the skin, never above floor level and never deeper than DEEPEST,
## the board's boxes there sit under it, ruts run between its ways out, and every square's floor level is unchanged.
func test_the_walked_ground_is_shaped_but_stays_on_the_grid() -> void:
	Look.set_style("modern", false)
	var v := _view("svalich_crossroads")
	var relief := v.atmosphere.land.relief
	assert_true(relief != null, "the crossroads' ground is shaped")
	var skinned := 0
	var rut := false
	for z in v.grid.depth:
		for x in v.grid.width:
			var c := Vector2i(x, z)
			assert_eq(v.board.floor_y(c), v.grid.height(c) / float(CombatGrid.FEET), "%s's floor level is the rules'" % c)
			if not relief.skinned(c):
				continue
			skinned += 1
			var box := v.board.floor_box(c)
			assert_true(box.position.y + 0.1 < -GroundRelief.DEEPEST, "%s's flat box sits under the skin" % c)
			for k in 9:
				var p := Vector2(x + (k % 3) * 0.5, z + (k / 3) * 0.5)
				var h := relief.height(p)
				assert_true(h <= 0.0 and h >= -GroundRelief.DEEPEST - 0.001, "the ground at %s stays at or just under floor level (%.3f)" % [p, h])
				rut = rut or relief._road_distance(p) < 0.3
	assert_true(skinned > 100, "the walked ground is drawn by the skin (%d squares)" % skinned)
	assert_true(rut, "wheel ruts run between the ways out")
	assert_true(v.atmosphere.land.root.find_child("Relief", true, false) != null, "the shaped ground is drawn")
	v.queue_free()


## Under the woods the ground rises into banks, meeting the walked ground at floor level, and the land past the edge
## starts where the banks leave off.
func test_the_woods_rise_into_banks() -> void:
	Look.set_style("modern", false)
	var v := _view("into_the_mists_road")
	var land := v.atmosphere.land
	var relief := land.relief
	var highest := 0.0
	for z in v.grid.depth:
		for x in v.grid.width:
			var c := Vector2i(x, z)
			if v.board.is_tree(c):
				highest = maxf(highest, relief.height(Vector2(x + 0.5, z + 0.5)))
			elif relief.skinned(c) or relief.is_flat(c):
				# Its corners, shared with any tree square beside it, are at floor level or a hollow below it.
				assert_true(relief.height(Vector2(x, z)) <= 0.0, "a flat square's corner %s stays at floor level" % c)
	assert_true(highest > 0.2, "the woods' ground rises (%.2f)" % highest)
	# The land's first corner past a wooded edge starts on the bank.
	var p := Vector2(0.0, 3.0)
	assert_true(absf(land.surface_y(p) - relief.height(p)) < 0.03, "the land carries on from the bank at the edge")
	v.queue_free()


## Towns keep their streets as the board draws them, and Classic stays flat.
func test_towns_and_classic_stay_flat() -> void:
	Look.set_style("modern", false)
	var v := _view("village_of_barovia")
	if v.atmosphere.land != null and v.atmosphere.land.relief != null:
		for z in v.grid.depth:
			for x in v.grid.width:
				assert_false(v.atmosphere.land.relief.skinned(Vector2i(x, z)), "the village's streets aren't reshaped")
	v.queue_free()
	Look.set_style("classic", false)
	var r := _view("svalich_crossroads")
	assert_true(r.atmosphere.land.relief == null, "no shaped ground in Classic")
	assert_true(absf(r.board.floor_box(Vector2i(10, 12)).position.y + 0.1) < 0.001, "Classic's floor boxes stay where the board put them")
	r.queue_free()
