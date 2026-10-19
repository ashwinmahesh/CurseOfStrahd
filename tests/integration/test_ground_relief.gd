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
			var rules := v.grid.height(c) / float(CombatGrid.FEET)
			if v.grid.has_flag(c, CombatGrid.NATURAL):
				# Natural ground (lane 3) draws its slope smoothed: its middle lies between the heights round it.
				var lo := rules
				var hi := rules
				for dz in range(-1, 2):
					for dx in range(-1, 2):
						var o := c + Vector2i(dx, dz)
						if v.grid.in_bounds(o):
							lo = minf(lo, v.grid.height(o) / float(CombatGrid.FEET))
							hi = maxf(hi, v.grid.height(o) / float(CombatGrid.FEET))
				assert_between(v.board.floor_y(c), lo - 0.001, hi + 0.001, "%s's floor lies within the slope round it" % c)
			else:
				assert_eq(v.board.floor_y(c), rules, "%s's floor level is the rules'" % c)
			if not relief.skinned(c):
				continue
			skinned += 1
			var box := v.board.floor_box(c)
			assert_eq(box.layers, 0, "%s's flat box no longer draws itself: the skin draws its ground" % c)
			for k in 9:
				var p := Vector2(x + (k % 3) * 0.5, z + (k / 3) * 0.5)
				# The skin's own shape, over the ground's (natural elevation, lane 3: the crossroads has hills).
				if relief.shore != null and relief.shore.touches(p):
					continue   # (a shore meets the water there: Shores lowers it on purpose, test_shores checks it)
				var h := relief.shape(p)
				assert_true(h <= 0.0 and h >= -GroundRelief.DEEPEST - 0.001, "the ground at %s stays at or just under floor level (%.3f)" % [p, h])
				assert_true(absf(relief.height(p) - h - v.board.ground_y(p)) < 0.2, "on the ground's own height at %s" % p)
	assert_true(skinned > 100, "the walked ground is drawn by the skin (%d squares)" % skinned)
	assert_true(relief.roads().size() >= 2, "roads run between the ways out (%d)" % relief.roads().size())
	assert_true(v.atmosphere.land.root.find_child("Ground", true, false) != null, "the walked ground and the woods' banks are drawn")
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
			# Measured from the ground's own height (natural elevation, lane 3: the road has banks and a knoll).
			if v.board.is_tree(c):
				highest = maxf(highest, relief.shape(Vector2(x + 0.5, z + 0.5)))
			elif relief.skinned(c) or relief.is_flat(c):
				# Its corners, shared with any tree square beside it, are at floor level or a hollow below it.
				assert_true(relief.shape(Vector2(x, z)) <= 0.0, "a flat square's corner %s stays at floor level" % c)
	assert_true(highest > 0.2, "the woods' ground rises (%.2f)" % highest)
	# The land's first corner past a wooded edge starts on the bank.
	var p := Vector2(0.0, 3.0)
	assert_true(absf(land.surface_y(p) - relief.height(p)) < 0.03, "the land carries on from the bank at the edge")
	v.queue_free()


## Towns get the shaped ground too (N2) but keep their streets: cobbles stay flat, only where paving meets earth do the
## surfaces blend. And Classic stays flat, with no shaped ground.
func test_towns_blend_their_streets_flat_and_classic_stays_flat() -> void:
	Look.set_style("modern", false)
	var v := _view("village_of_barovia")
	var relief := v.atmosphere.land.relief
	assert_true(relief != null and not relief.slots().is_empty(), "the village's ground is blended")
	var surfaces: Array[String] = []
	for m in relief.slots():
		surfaces.append(str(m.get_meta("surface")))
	assert_true("village/cobbles" in surfaces, "its cobbles are one of the surfaces (%s)" % [surfaces])
	var paved := 0
	for z in v.grid.depth:
		for x in v.grid.width:
			var c := Vector2i(x, z)
			if relief.skinned(c) and relief.surface_at(Vector2(x + 0.5, z + 0.5)) == "village/cobbles":
				paved += 1
				assert_eq(relief.shape(Vector2(x + 0.5, z + 0.5)), 0.0, "the street's cobbles at %s are flat" % c)
	assert_true(paved > 200, "the streets are in the blend (%d)" % paved)
	v.queue_free()
	Look.set_style("classic", false)
	var r := _view("svalich_crossroads")
	assert_true(r.atmosphere.land.relief == null, "no shaped ground in Classic")
	assert_eq(r.board.floor_box(Vector2i(10, 12)).layers, 1, "Classic's floor boxes draw themselves")
	assert_true(r.board.floor_box(Vector2i(10, 12)).get_child_count() == 0, "with no shaped ground on them")
	r.queue_free()


## One ground: the walked squares and the woods' banks are a single mesh in a single blended material, the surfaces in it
## the place's own floor, its difficult ground and the bank ground, at most four.
func test_the_ground_is_one_blended_mesh() -> void:
	Look.set_style("modern", false)
	var v := _view("svalich_crossroads")
	var land := v.atmosphere.land
	var grounds := land.root.find_children("Ground", "MeshInstance3D", true, false)
	assert_eq(grounds.size(), 1, "one mesh draws the ground")
	assert_true(land.root.find_child("Walked0", true, false) == null and land.root.find_child("Banks", true, false) == null, "not a mesh a surface")
	var mat := (grounds[0] as MeshInstance3D).material_override as ShaderMaterial
	assert_true(mat != null and mat.shader == Look.LIT_BLEND_SHADER, "in the blend material")
	var relief := land.relief
	assert_true(relief.slots().size() >= 2 and relief.slots().size() <= Look.BLEND_SLOTS, "two to four surfaces (%d)" % relief.slots().size())
	var surfaces: Array[String] = []
	for m in relief.slots():
		surfaces.append(str(m.get_meta("surface")))
	assert_true("village/grass" in surfaces and "village/mud_road" in surfaces, "its grass and its mud (%s)" % [surfaces])
	assert_eq(mat.get_meta("blend_surfaces")[0], surfaces[0], "the first slot is the first surface")
	v.queue_free()


## Each layer of the blend is exactly what its surface's floor was: its variants (or its one tile), its tile size and
## its tint, and a mood that tints a surface tints the blend made from it.
func test_the_blend_takes_its_layers_from_the_floors() -> void:
	Look.set_style("modern", false)
	var v := _view("svalich_crossroads")
	var relief := v.atmosphere.land.relief
	var mat := (v.atmosphere.land.root.find_child("Ground", true, false) as MeshInstance3D).material_override as ShaderMaterial
	for i in relief.slots().size():
		var src := relief.slots()[i]
		var k := str(Look.BLEND_LETTERS[i])
		var layers := int(src.get_shader_parameter("layer_count")) if src.get_shader_parameter("layer_count") != null else 0
		assert_eq(int(mat.get_shader_parameter("layers_" + k)), maxi(layers, 1), "%s: a layer for each variant" % src.get_meta("surface"))
		assert_eq(float(mat.get_shader_parameter("tile_" + k)), float(src.get_shader_parameter("tile_units")), "%s: its tile's size" % src.get_meta("surface"))
		assert_true(mat.get_shader_parameter("albedo_" + k) is Texture2DArray, "%s: its tiles as an array" % src.get_meta("surface"))
	var surface := str(relief.slots()[0].get_meta("surface"))
	Look.set_surface_tints({surface: Color(0.5, 0.6, 0.7)})
	assert_eq(mat.get_shader_parameter("tint_a"), Color(0.5, 0.6, 0.7), "the blend is tinted with its surface")
	Look.set_surface_tints({})
	assert_eq(mat.get_shader_parameter("tint_a"), Color.WHITE, "and put back")
	v.queue_free()


## A difficult square still reads as one: its own surface is the middle 60% of it, wherever the noise moves its edge, and
## the squares beside it blend into it over their edge (the control map has one texel a square).
func test_a_difficult_square_reads_as_one() -> void:
	Look.set_style("modern", false)
	var v := _view("svalich_crossroads")
	var relief := v.atmosphere.land.relief
	var checked := 0
	for z in v.grid.depth:
		for x in v.grid.width:
			var c := Vector2i(x, z)
			if not relief.skinned(c) or not v.grid.has_flag(c, CombatGrid.DIFFICULT):
				continue
			var own := relief.surface_at(Vector2(x + 0.5, z + 0.5))
			assert_eq(own, "village/mud_road", "%s is mud" % c)
			for off: Vector2 in [Vector2(0.3, 0.0), Vector2(-0.3, 0.0), Vector2(0.0, 0.3), Vector2(0.0, -0.3), Vector2(0.28, 0.28), Vector2(-0.28, -0.28)]:
				assert_eq(relief.surface_at(Vector2(x + 0.5, z + 0.5) + off), own, "%s's middle 60%% (%s) is its own" % [c, off])
			checked += 1
	assert_true(checked >= 10, "difficult squares to look at (%d)" % checked)
	v.queue_free()


## Built floors stay as built: an outdoor dungeon map (the Amber Temple's doors, Daern's roof, a tower roof) has no skin,
## and a board a place doesn't name (the arena) none either.
func test_built_floors_keep_their_boxes() -> void:
	Look.set_style("modern", false)
	for loc_id: String in ["amber_temple_entrance", "daerns_fortress_roof", "tsolenka_pass_guard_tower_roof", "castle_ravenloft_spires_roofs"]:
		var v := _view(loc_id)
		var relief := v.atmosphere.land.relief if v.atmosphere.land != null else null
		assert_true(relief == null or relief.slots().is_empty(), "%s keeps its built floors" % loc_id)
		for z in v.grid.depth:
			for x in v.grid.width:
				assert_true(relief == null or not relief.skinned(Vector2i(x, z)), "%s: %s isn't skin" % [loc_id, Vector2i(x, z)])
		v.queue_free()


## Footprints and puffs ask the ground what shows at the point: across a square's edge from mud into grass, it changes
## where the blend does, and never reaches past a square's own middle.
func test_the_ground_says_what_shows_at_a_point() -> void:
	Look.set_style("modern", false)
	var v := _view("svalich_crossroads")
	var relief := v.atmosphere.land.relief
	var found := false
	for z in v.grid.depth:
		for x in v.grid.width - 1:
			var a := Vector2i(x, z)
			var b := Vector2i(x + 1, z)
			if relief.skinned(a) and relief.skinned(b) and v.grid.has_flag(a, CombatGrid.DIFFICULT) and not v.grid.has_flag(b, CombatGrid.DIFFICULT):
				assert_eq(relief.surface_at(Vector2(x + 0.5, z + 0.5)), "village/mud_road")
				assert_eq(relief.surface_at(Vector2(x + 1.5, z + 0.5)), "village/grass")
				assert_eq(relief.surface_at(Vector2(x + 0.7, z + 0.5)), "village/mud_road", "a bit past the middle is still the mud")
				found = true
				break
		if found:
			break
	assert_true(found, "a mud square beside grass")
	v.queue_free()


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
	for name: String in ["Ground"]:
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
