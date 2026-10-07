extends TestCase
## Ground with shape in the Modern look (Improvement Ideas W11, docs/art/atmosphere.md "Ground with shape"): on an
## outdoor wild map the walked ground is a shaped skin that never rises above floor level (so tokens, overlays and
## templates keep standing on the grid) with the board's flat boxes quiet under it, roads run between the ways out, the
## woods' ground rises into banks that the land past the edge carries on from, hidden squares and traps are left as
## they should be, a place comes back the same from what was kept, towns stay as they are, and Classic stays flat.


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
## the board's boxes there stop drawing themselves, roads run between its ways out (for the surfaces lane's rut
## decals), and every square's floor level is unchanged.
func test_the_walked_ground_is_shaped_but_stays_on_the_grid() -> void:
	Look.set_style("modern", false)
	var v := _view("svalich_crossroads")
	var relief := v.atmosphere.land.relief
	assert_true(relief != null, "the crossroads' ground is shaped")
	var skinned := 0
	for z in v.grid.depth:
		for x in v.grid.width:
			var c := Vector2i(x, z)
			assert_eq(v.board.floor_y(c), v.grid.height(c) / float(CombatGrid.FEET), "%s's floor level is the rules'" % c)
			if not relief.skinned(c):
				continue
			skinned += 1
			var box := v.board.floor_box(c)
			assert_eq(box.layers, 0, "%s's flat box no longer draws itself: the skin draws its ground" % c)
			for k in 9:
				var p := Vector2(x + (k % 3) * 0.5, z + (k / 3) * 0.5)
				var h := relief.height(p)
				assert_true(h <= 0.0 and h >= -GroundRelief.DEEPEST - 0.001, "the ground at %s stays at or just under floor level (%.3f)" % [p, h])
	assert_true(skinned > 100, "the walked ground is drawn by the skin (%d squares)" % skinned)
	assert_true(relief.roads().size() >= 2, "roads run between the ways out (%d)" % relief.roads().size())
	assert_true(v.atmosphere.land.root.find_child("Walked0", true, false) != null, "the walked ground is drawn")
	assert_true(v.atmosphere.land.root.find_child("Banks", true, false) != null, "the woods' banks are drawn")
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
	assert_eq(r.board.floor_box(Vector2i(10, 12)).layers, 1, "Classic's floor boxes draw themselves")
	assert_true(r.board.floor_box(Vector2i(10, 12)).get_child_count() == 0, "with no shaped ground on them")
	r.queue_free()


## Hidden until found: the shaped ground and the land's plants leave out squares that are hidden (as HiddenAreas hides
## the board's own pieces), and a trap's square keeps its floor box (a pit opens it) and grows no plant.
func test_hidden_squares_stay_hidden() -> void:
	Look.set_style("modern", false)
	var v := _view("into_the_mists_road")
	var land := v.atmosphere.land
	var relief := land.relief
	var walked := Vector2i(-1, -1)
	var tree := Vector2i(-1, -1)
	for z in v.grid.depth:
		for x in v.grid.width:
			var c := Vector2i(x, z)
			if relief.skinned(c) and walked.x < 0:
				walked = c
			if v.board.is_tree(c) and tree.x < 0 and z > 2 and x > 2:
				tree = c
	var hidden := {}
	for c: Vector2i in [walked, tree]:
		for dz in range(-1, 2):
			for dx in range(-1, 2):
				hidden[c + Vector2i(dx, dz)] = true
	land.respect_hidden(hidden)
	for name: String in ["Banks", "Walked0"]:
		var mi := land.root.find_child(name, true, false) as MeshInstance3D
		assert_true(mi != null, "%s is drawn" % name)
		var faces := mi.mesh.get_faces()
		for i in range(0, faces.size(), 3):
			var mid := (faces[i] + faces[i + 1] + faces[i + 2]) / 3.0
			var c := Vector2i(floori(mid.x), floori(mid.z))
			assert_false(c == tree or c == walked, "%s draws nothing on hidden square %s" % [name, c])
	for n in land.root.find_children("MapPlants_*", "MultiMeshInstance3D", true, false):
		if not is_instance_valid(n) or n.is_queued_for_deletion():
			continue
		for p: Vector3 in n.get_meta("origins", PackedVector3Array()) as PackedVector3Array:
			assert_false(hidden.has(Vector2i(floori(p.x), floori(p.z))), "no plant on hidden square at %s" % p)
	var loc := Compendium.shared().get_entry("locations", "into_the_mists_road")
	for c: Vector2i in AtmosphereLand._trap_cells(loc):
		assert_false(land.flora.map_items.has(c), "no plant grows on the trap at %s" % c)
		assert_false(relief.skinned(c), "the trap at %s keeps its floor box for a pit to open" % c)
	v.queue_free()


## A place built a second time comes out the same, from what the first build kept, and quicker.
func test_a_place_comes_back_the_same() -> void:
	Look.set_style("modern", false)
	var a := _view("svalich_crossroads")
	var first := a.atmosphere.land
	var trees := first.root.find_children("Trees_*", "MultiMeshInstance3D", true, false).size()
	var h := first.surface_y(Vector2(-3.5, 4.5))
	a.queue_free()
	var b := _view("svalich_crossroads")
	var again := b.atmosphere.land
	assert_eq(again.root.find_children("Trees_*", "MultiMeshInstance3D", true, false).size(), trees, "the same forest")
	assert_eq(again.surface_y(Vector2(-3.5, 4.5)), h, "the same ground")
	assert_true(float(again.build_ms.get("land_trees", 0.0)) < 20.0, "drawn again from what was kept (%s)" % again.build_ms)
	b.queue_free()
