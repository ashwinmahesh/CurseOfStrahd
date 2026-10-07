extends TestCase
## The Modern look's trees and plants (Improvement Ideas W9, docs/art/plants.md): every set names plants that were
## built, every outdoor mood grows one, the map's own trees and the land's are Flora's in the Modern look and keep
## fading, ground plants stand on the land and keep off the middle of the squares people walk on and off the squares
## a location's things stand on, the wind follows the mood, and the Classic look keeps its old trees.


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


## Where the copies of plants drawn many at once stand (Flora.plant_all keeps them; headless MultiMeshes don't).
func _instances(root: Node, prefix: String) -> PackedVector3Array:
	var out := PackedVector3Array()
	for n in root.find_children(prefix + "*", "MultiMeshInstance3D", true, false):
		for p: Vector3 in n.get_meta("origins", PackedVector3Array()) as PackedVector3Array:
			out.append((n as MultiMeshInstance3D).global_transform * p)
	return out


## Every plant a set names was built (art/plants/manifest.json) and loads, with its far copy where it has one.
func test_sets_name_plants_that_exist() -> void:
	var plants := Flora.manifest()
	assert_true(plants.size() > 10, "the plants are built (%d)" % plants.size())
	for set_id: String in Flora.config()["sets"] as Dictionary:
		var spec := Flora.resolve(set_id)
		var ids: Array[String] = []
		for kind: String in spec.get("trees", {}) as Dictionary:
			for id: Variant in (spec["trees"] as Dictionary)[kind] as Array:
				ids.append(str(id))
		for key: String in ["land", "under", "open", "shore"]:
			for c: Variant in spec.get(key, []) as Array:
				ids.append(str((c as Array)[0]))
		for id in ids:
			assert_true(plants.has(id), "%s's %s is a built plant" % [set_id, id])
			assert_true(Flora.mesh(id) != null, "%s loads" % id)
			var far := str((plants.get(id, {}) as Dictionary).get("far", ""))
			assert_true(far == "" or Flora.mesh(far) != null, "%s's far copy %s loads" % [id, far])


## Every mood names a set that exists, directly or through the mood it is like.
func test_every_outdoor_mood_grows_a_set() -> void:
	var sets := Flora.config()["sets"] as Dictionary
	for id: String in Atmosphere.moods()["moods"] as Dictionary:
		assert_true(sets.has(Flora.set_for(id)), "%s grows the %s set" % [id, Flora.set_for(id)])
	assert_eq(Flora.set_for("svalich_road"), "forest", "the road is forest, like the Svalich woods")
	assert_eq(Flora.set_for("white_sun"), "mountain", "the Pool of the White Sun is mountain, like Krezk")


## The opening road in the Modern look: the map's trees and the land's are Flora's and fade when in front of the
## party, the forest beyond the edge and its undergrowth are drawn many at once, and the map's trees stay 10 to 20 ft.
func test_the_road_grows_the_modern_forest() -> void:
	Look.set_style("modern", false)
	var v := _view("into_the_mists_road")
	var land := v.atmosphere.land
	assert_true(land != null and land.flora != null, "the road's land grows Flora's plants")
	var mine := 0
	for t in v.board.mesh_occluders:
		if not is_instance_valid(t) or not Flora.manifest().has(str(t.get_meta("model", ""))):
			continue
		mine += 1
		var box := AABB()
		var first := true
		for n in t.find_children("*", "MeshInstance3D", true, false):
			var b := (n as MeshInstance3D).global_transform * (n as MeshInstance3D).mesh.get_aabb()
			box = b if first else box.merge(b)
			first = false
		var c := Vector2i(floori(t.global_position.x), floori(t.global_position.z))
		if v.grid.in_bounds(c):
			assert_true(box.size.y > 2.0 and box.size.y < 4.0, "a tree in the map 10 to 20 ft tall (%.2f)" % box.size.y)
	assert_true(mine > 50, "Flora's trees in and around the map fade like the old ones (%d)" % mine)
	assert_true(_instances(land.root, "Trees_").size() > 0, "the forest beyond the edge")
	assert_true(_instances(land.root, "FarTrees_").size() > 0, "lighter copies far out")
	assert_true(_instances(land.root, "Plants_").size() > 200, "undergrowth on the land")
	v.queue_free()


## Ground plants stand on the land mesh, never on the map's own squares.
func test_plants_stand_on_the_land() -> void:
	Look.set_style("modern", false)
	var v := _view("into_the_mists_road")
	var land := v.atmosphere.land
	var checked := 0
	for t in _instances(land.root, "Plants_"):
		var p := Vector2(t.x, t.z)
		assert_true(absf(t.y - (land.surface_y(p) - 0.02)) < 0.02, "a plant at %s stands on the ground" % p)
		var c := Vector2i(floori(p.x), floori(p.y))
		assert_false(v.grid.in_bounds(c) and not v.grid.has_flag(c, CombatGrid.VOID), "no land plant on map square %s" % c)
		checked += 1
	assert_true(checked > 0, "there are plants to check")
	v.queue_free()


## On the map, plants keep off the middle of the squares people walk on (feet and rings stay clear), off squares a
## location's things stand on, and out of the water.
func test_map_plants_keep_clear() -> void:
	Look.set_style("modern", false)
	for loc_id: String in ["into_the_mists_road", "tser_pool"]:
		var v := _view(loc_id)
		var g := v.grid
		var n := 0
		for t in _instances(v.atmosphere.land.root, "MapPlants_"):
			var c := Vector2i(floori(t.x), floori(t.z))
			assert_true(g.in_bounds(c), "%s: a map plant at %s is on the map" % [loc_id, c])
			assert_false(g.has_flag(c, CombatGrid.WATER), "%s: no plant in the water at %s" % [loc_id, c])
			assert_false(v.board.occupied.has(c), "%s: no plant where a location's thing stands (%s)" % [loc_id, c])
			if not g.has_flag(c, CombatGrid.WALL):
				var off := Vector2(t.x - c.x - 0.5, t.z - c.y - 0.5)
				assert_true(off.length() > 0.25, "%s: a plant keeps off the middle of %s (%.2f)" % [loc_id, c, off.length()])
			n += 1
		assert_true(n > 0, "%s has plants on its own ground" % loc_id)
		v.queue_free()


## The wind follows the mood: the castle's storm blows harder than the Svalich woods' breeze.
func test_the_wind_follows_the_mood() -> void:
	Look.set_style("modern", false)
	var v := _view("into_the_mists_road")
	var calm := float(Flora._material("leaf|tree").get_shader_parameter("wind_strength"))
	v.queue_free()
	var g := _view("castle_ravenloft_gates")
	var storm := float(Flora._material("leaf|tree").get_shader_parameter("wind_strength"))
	g.queue_free()
	assert_true(storm > calm + 0.2, "the storm (%.2f) blows harder than the woods (%.2f)" % [storm, calm])


## The Classic look is frozen (owner, 2026-10-07): its trees stay the old models and it grows no plants.
func test_classic_keeps_its_old_trees() -> void:
	Look.set_style("classic", false)
	var v := _view("into_the_mists_road")
	assert_true(v.atmosphere.land.flora == null, "no Flora in Classic")
	assert_eq(_instances(v.atmosphere.land.root, "Plants_").size(), 0, "no undergrowth in Classic")
	assert_eq(_instances(v.atmosphere.land.root, "MapPlants_").size(), 0, "no map plants in Classic")
	for t in v.board.mesh_occluders:
		if is_instance_valid(t) and t.has_meta("model"):
			assert_true(ModelPiece.manifest().has(str(t.get_meta("model"))), "%s is an old tree" % t.get_meta("model"))
	v.queue_free()
