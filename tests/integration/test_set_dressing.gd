extends TestCase
## The set dressing (docs/art/set_dressing.md): every location's props, containers and doors have art, pieces stand,
## hang and lie where they should, a prop on a tree's square takes its place, and towns are built of houses with
## roofs and yard walls instead of one box per square.


func before_each() -> void:
	GameState.reset()
	for id: String in ["ilse_varga", "tamsin_tealeaf", "hedda_ironvow", "silvain_aster"]:
		var ch := Pregens.build(id, 1)
		ch.finish_long_rest()
		GameState.story.party.append(ch)


func _view(loc_id: String) -> LocationView:
	var v := LocationView.create(loc_id, GameState.story, null, Dice.roller, "default")
	add_child(v)
	return v


func _frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame


## Owner request (2026-10-06): no brown placeholder boxes. Every thing in every location is dressed by the catalog,
## or deliberately left as an invisible spot, and the art it names exists.
func test_every_prop_and_container_has_art() -> void:
	var missing: Array[String] = []
	var locs := Compendium.shared().tables["locations"] as Dictionary
	for loc_id: String in locs:
		var loc := locs[loc_id] as Dictionary
		for key: String in ["props", "containers"]:
			for t: Variant in loc.get(key, []):
				var spec := t as Dictionary
				if SetDressing.look_for(spec, key == "containers").is_empty():
					missing.append("%s/%s (%s)" % [loc_id, spec.get("id", ""), spec.get("model", "")])
		for d: Variant in loc.get("doors", []):
			if not SetDressing.has_art(str(SetDressing.door_look(d as Dictionary).get("art", ""))):
				missing.append("%s door %s" % [loc_id, (d as Dictionary).get("id", "")])
	assert_eq(missing, [] as Array[String], "no art for")


func test_catalog_names_only_art_that_exists() -> void:
	var cat := SetDressing.catalog()
	var named: Array[String] = [str(cat.get("container_default", ""))]
	for table: String in ["models", "ids"]:
		for v: Variant in (cat[table] as Dictionary).values():
			if v is String:
				named.append(str(v))
			elif v is Dictionary:
				named.append(str((v as Dictionary)["art"]))
	for set_name: String in ["low_cover", "difficult"]:
		for arts: Variant in (cat[set_name] as Dictionary).values():
			for a: Variant in arts:
				named.append(str(a))
	for rule: Variant in (cat["doors"] as Dictionary)["rules"]:
		named.append(str((rule as Array)[1]))
	for a in named:
		assert_true(SetDressing.has_art(a), "art exists: " + a)


## Death House: doors are framed leaves in the wall line, the hearth hangs on the wall face, chests are billboards.
func test_death_house_doors_props_and_containers() -> void:
	var v := _view("death_house_ground")
	await _frames(2)
	var door := v.door_nodes["dh_den_door"] as Node3D
	assert_true(door.get_node_or_null("Leaf") is Sprite3D, "the den door has a leaf")
	assert_eq(door.position, v.board.cell_center(Vector2i(9, 5)), "in its square")
	assert_true(is_equal_approx(absf(door.rotation.y), PI / 2.0), "the wall runs north-south, so the leaf faces east-west")
	var hearth := v.prop_nodes["den_hearth"] as Node3D
	var sp := hearth.get_child(0) as Sprite3D
	assert_eq(sp.billboard, BaseMaterial3D.BILLBOARD_DISABLED, "hung flat")
	assert_true(absf(sp.position.z - 1.0) < 0.05, "on the wall's south face (the wall square is row 0)")
	var cabinet := v.container_nodes["den_gun_cabinet"] as Node3D
	assert_true(cabinet.get_child(0) is Sprite3D, "the hunting cabinet is a picture, not a box")
	v.mark_looted("den_gun_cabinet")
	assert_true((cabinet.get_child(0) as Sprite3D).modulate.v < 0.9, "an emptied container dims")
	v.queue_free()


## The signpost stands among the trees on the opening road: the tree on its square hides while it's there.
func test_a_prop_takes_a_trees_square() -> void:
	var v := _view("into_the_mists_road")
	await _frames(2)
	var cell := Vector2i(22, 12)
	var hidden := 0
	for n: Node3D in v.board.dressing.get(cell, []):
		if not n.visible:
			hidden += 1
	assert_true(hidden > 0, "the tree on the signpost's square is hidden")
	(v.prop_nodes["mists_signpost"] as Node).free()
	for n: Node3D in v.board.dressing.get(cell, []):
		assert_true(n.visible, "and comes back when the signpost goes")
	v.queue_free()


## The village is houses with roofs, not one box per wall square; its yard walls are low.
func test_village_houses_and_yard_walls() -> void:
	var v := _view("village_of_barovia")
	await _frames(2)
	var board := v.board
	assert_true(board.buildings.size() >= 8, "the village has its houses (%d)" % board.buildings.size())
	for b: Dictionary in board.buildings:
		assert_true((b["upper"] as Node3D).get_node_or_null("Roof") != null, "each house has a roof")
	assert_true(board.house_cells.has(Vector2i(6, 2)), "the burgomaster's mansion is a house")
	var yard := 0
	for c in board.get_children():
		if str(c.name).contains("YardWall"):
			yard += 1
	assert_true(yard > 0, "yard walls are built")
	# A house between the camera and the party is cut away.
	var b0 := board.buildings[0]
	var aabb := b0["aabb"] as AABB
	var behind := aabb.get_center() + Vector3(0, -aabb.size.y / 2.0, -aabb.size.z / 2.0 - 1.0)
	board.cut_buildings(behind + Vector3(0, 5, 12), behind, 1.0)
	assert_false((b0["upper"] as Node3D).visible, "its roof hides")
	board.cut_buildings(behind + Vector3(0, 5, -14), behind, 1.0)
	assert_true((b0["upper"] as Node3D).visible, "and comes back")
	v.queue_free()
