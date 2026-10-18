extends TestCase
## The building kit (Improvement Ideas W7, docs/art/building_kit.md): towns are put together from Blender modules in
## their region's style instead of textured boxes: Barovia's timber framing, Vallaki's clapboard and palisade, Krezk's
## stone. A door hung on a house makes a door bay; a house in the way stands and opens a window round the party.


var _cut_away: Variant = null
var _rooms_cut: Variant = null


func before_each() -> void:
	_cut_away = BuildingKit.settings().get("cut_away")
	_rooms_cut = (BuildingKit.settings().get("interiors", {}) as Dictionary).get("cut_away")
	GameState.reset()
	ModeController.force(ModeController.Mode.EXPLORATION)
	for id: String in ["ilse_varga", "tamsin_tealeaf", "hedda_ironvow", "silvain_aster"]:
		var ch := Pregens.build(id, 1)
		ch.finish_long_rest()
		GameState.story.party.append(ch)


func after_each() -> void:
	Look.set_style(Look.DEFAULT_STYLE, false)
	BuildingKit.settings()["cut_away"] = _cut_away
	(BuildingKit.settings()["interiors"] as Dictionary)["cut_away"] = _rooms_cut


## The catalog's building_kit "cut_away", on for a test of how a building in the way would cut down (the owner turned
## it off outside, 2026-10-13).
func _cutting() -> void:
	BuildingKit.settings()["cut_away"] = true


func _view(loc_id: String) -> LocationView:
	var v := LocationView.create(loc_id, GameState.story, null, Dice.roller, "default")
	add_child(v)
	return v


func _frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame


## Every module TownBuilder asks for is built, and every surface is a palette colour or a texture that exists.
func test_the_kit_has_every_module() -> void:
	var missing: Array[String] = []
	var cfg := BuildingKit.settings()
	var styles := {}
	for v: Variant in (cfg.get("themes", {}) as Dictionary).values() + (cfg.get("places", {}) as Dictionary).values():
		styles[str(v)] = true
	styles["church"] = true   # the house with a church's doors
	for style: String in styles:
		for part: String in ["low_a", "up_a", "up_win", "door", "door_top", "corner", "foot", "window", "window_lit",
				"window_shut", "yard_arm", "yard_pier"]:
			if style == "church" and part.begins_with("yard"):
				continue   # a churchyard's walls are the town's
			if not BuildingKit.has(BuildingKit.wall_id(style, part)):
				missing.append(BuildingKit.wall_id(style, part))
		var roofs := (cfg.get("roofs", {}) as Dictionary).get(style, {}) as Dictionary
		for kind: Variant in roofs.values():
			for w in range(1, 13):
				for end: bool in [false, true]:
					if BuildingKit.roof_id(style, str(kind), w, end) == "":
						missing.append("%s %s roof w%d%s" % [style, kind, w, " end" if end else ""])
				if not BuildingKit.has("kit_%s_gable_w%d" % [style, w]):
					missing.append("kit_%s_gable_w%d" % [style, w])
	for id: String in ["kit_chimney_cap", "kit_palisade", "kit_town_wall_arm", "kit_town_wall_pier"]:
		if not BuildingKit.has(id):
			missing.append(id)
	assert_eq(missing, [] as Array[String], "kit modules")
	var palette := JSON.parse_string(FileAccess.get_file_as_string(Look.PALETTE_JSON)) as Dictionary
	for id: String in BuildingKit.manifest():
		for m: String in ((BuildingKit.manifest()[id] as Dictionary).get("materials", []) as Array):
			if m.begins_with("pal_") or m.begins_with("glow_"):
				assert_true(palette.has(m.substr(m.find("_") + 1)), "%s's colour %s is in the palette" % [id, m])
			else:
				assert_true(m.begins_with("tex_") and Look.cel_textured(m.trim_prefix("tex_").replace("__", "/")) != null,
					"%s's surface %s exists" % [id, m])
	for paint: Variant in cfg.get("paints", []):
		assert_true(palette.has(str(paint)), "paint %s is in the palette" % paint)


## The village's houses are timber-framed kit houses: walls and roof each one merged mesh, a door bay where each
## house door hangs (its leaf the opening's height), windows over the street, and a few lit ones for the night.
func test_village_houses_are_built_from_the_kit() -> void:
	var v := _view("village_of_barovia")
	await _frames(2)
	var board := v.board
	assert_true(board.buildings.size() >= 8, "the village has its houses")
	var doors := 0
	var lit := 0
	for b: Dictionary in board.buildings:
		assert_true(str(b.get("kit", "")) in ["timber", "church"], "a village house is timber-framed (or the church)")
		var walls := b["walls"] as MeshInstance3D
		assert_true(walls != null and walls.mesh is ArrayMesh and walls.mesh.get_surface_count() >= 3,
			"its walls are the kit's modules, merged")
		assert_true((b["upper"] as Node3D).get_node_or_null("Roof") is MeshInstance3D, "and it has a roof")
		for face: Dictionary in (b["faces"] as Dictionary).values():
			if str(face["door"]) != "":
				doors += 1
	for key: String in board.windows:
		var w := board.windows[key] as Node3D
		if w != null and bool(w.get_meta("lit", false)):
			lit += 1
	assert_true(doors >= 4, "house doors are door bays (%d)" % doors)
	assert_true(lit >= 1, "some windows are lit (%d)" % lit)
	# The mansion's front door: its leaf fills the opening.
	var exit := v.find_child("Exit_mansion_door", true, false) as Node3D
	assert_true(exit != null, "the mansion's door is drawn")
	if exit != null:
		var leaf := exit.find_children("Model_*", "Node3D", true, false)
		assert_true(not leaf.is_empty(), "as a 3D leaf")
		if not leaf.is_empty():
			var box := AABB()
			var first := true
			for mi in (leaf[0] as Node3D).find_children("*", "MeshInstance3D", true, false):
				var b := (mi as MeshInstance3D).global_transform * (mi as MeshInstance3D).mesh.get_aabb()
				box = b if first else box.merge(b)
				first = false
			assert_between(box.size.y, 1.8, 2.0, "the leaf is a door's height")
	v.queue_free()


## With cut_away on, a house between the camera and the party drops to its footing round a floor; it stands again when
## it's clear.
func test_a_kit_house_cuts_away_to_its_footing() -> void:
	_cutting()
	var v := _view("village_of_barovia")
	await _frames(2)
	var board := v.board
	var b0 := board.buildings[0]
	var aabb := b0["aabb"] as AABB
	var behind := aabb.get_center() + Vector3(0, -aabb.size.y / 2.0, -aabb.size.z / 2.0 - 1.0)
	board.cut_buildings(behind + Vector3(0, 5, 12), behind, 1.0)
	board.cut_buildings(behind + Vector3(0, 5, 12), behind, 1.0)
	assert_false((b0["walls"] as Node3D).visible, "its walls go")
	assert_true((b0["stub"] as Node3D).visible, "its footing and a low band stay")
	assert_false((b0["upper"] as Node3D).visible, "with the roof")
	board.cut_buildings(behind + Vector3(0, 5, -14), behind, 1.0)
	assert_true((b0["walls"] as Node3D).visible and not (b0["stub"] as Node3D).visible, "and it stands again")
	v.queue_free()


## Owner decisions (2026-10-13: "why do buildings shrink down ... when I get near them? Same things with walls. Lets
## disable this effect"; 2026-10-17: big walls all round going see-through "looks really weird"): outside, a house or
## Castle Ravenloft's wall between the camera and the party stands whole and solid, roof and all, with every mesh of it
## marked to open a window round the party (SeeThrough), never fading whole.
func test_buildings_and_walls_in_the_way_stand() -> void:
	assert_false(bool(BuildingKit.settings().get("cut_away", false)), "the catalog's cut_away is off")
	var v := _view("village_of_barovia")
	await _frames(2)
	var b0 := v.board.buildings[0]
	var aabb := b0["aabb"] as AABB
	var behind := aabb.get_center() + Vector3(0, -aabb.size.y / 2.0, -aabb.size.z / 2.0 - 1.0)
	for i in 2:
		v.board.cut_buildings(behind + Vector3(0, 5, 12), behind, 1.0)
	assert_true((b0["walls"] as Node3D).visible and is_equal_approx((b0["walls"] as Node3D).scale.y, 1.0), "the house in the way stands")
	assert_false((b0["stub"] as Node3D).visible, "no footing in its place")
	assert_true((b0["upper"] as Node3D).visible, "roof and all")
	assert_true(is_zero_approx(_fade_of(b0["walls"] as Node3D)) and is_zero_approx(_fade_of(b0["upper"] as Node3D)), "solid, never see-through whole")
	assert_true(_all_marked(b0["root"] as Node3D), "every mesh of it opens round the party")
	for i in 2:
		v.board.cut_buildings(behind + Vector3(0, 5, -14), behind, 1.0)
	assert_true(is_zero_approx(_fade_of(b0["walls"] as Node3D)) and (b0["walls"] as Node3D).visible, "and the same once clear")
	var street := v.board.floor_box(v.members[0].cell)
	assert_true(street != null and not SeeThrough.marked(street), "the street never opens")
	v.queue_free()
	await _frames(1)
	var c := _view("castle_ravenloft_gates")
	await _frames(2)
	var focus := c.board.cell_center(Vector2i(19, 18))
	var gate_wall := c.board.buildings[int(c.board.house_cells[Vector2i(18, 22)])] as Dictionary
	for i in 2:
		c.board.cut_buildings(focus + Vector3(0, 12, 12), focus, 1.0)
	assert_true((gate_wall["walls"] as Node3D).visible and not (gate_wall["stub"] as Node3D).visible, "the castle wall in the way stands")
	assert_true(is_equal_approx((gate_wall["walls"] as Node3D).scale.y, 1.0) and is_zero_approx(_fade_of(gate_wall["walls"] as Node3D)),
		"whole and solid")
	var keep := c.board.buildings[int(c.board.house_cells[Vector2i(20, 4)])] as Dictionary
	assert_true(_all_marked(gate_wall["root"] as Node3D) and _all_marked(keep["root"] as Node3D), "the castle's pieces open round the party")
	c.queue_free()


## Whether every mesh under `n` opens round the party (SeeThrough.mark).
func _all_marked(n: Node3D) -> bool:
	var meshes := n.find_children("*", "GeometryInstance3D", true, false)
	if n is GeometryInstance3D:
		meshes.append(n)
	for g in meshes:
		if not (g is GPUParticles3D or (g as Node).get_parent() is GPUParticles3D) and not SeeThrough.marked(g as GeometryInstance3D):
			return false   # (a chimney's smoke aside)
	return not meshes.is_empty()


## The most see-through any mesh under `n` is (GeometryInstance3D.transparency, as ModelPiece.set_fade sets it).
func _fade_of(n: Node3D) -> float:
	var most := (n as GeometryInstance3D).transparency if n is GeometryInstance3D else 0.0
	for g in n.find_children("*", "GeometryInstance3D", true, false):
		most = maxf(most, (g as GeometryInstance3D).transparency)
	return most


## W7: an L-shaped block of wall is one building: its parts share their height, roof and paint, there's no wall or
## window between them, the wing's roof runs into the main roof (no gable there, its ridge under the main one's), and
## the parts cut away together. Two made-up L's: a wing under one house's end, and one beside the other's.
func test_an_l_shaped_block_is_one_building() -> void:
	var rows: Array[String] = ["####################", "#..................#", "#.######.....###...#", "#.######.....###...#",
		"#.######.....###...#", "#....###.....###...#", "#....###.....###...#", "#....###.....###...#",
		"#....###.#######...#", "#........#######...#", "#........#######...#", "#..................#",
		"#..................#", "####################"]
	Compendium.shared().tables["locations"]["kit_l_test"] = {"id": "kit_l_test", "name": "A yard", "region": "village_of_barovia",
		"summary": "", "map": {"theme": "village", "outdoors": true, "rows": rows}, "spawns": {"default": [1, 12]}}
	var v := _view("kit_l_test")
	await _frames(2)
	var board := v.board
	var parts := {}
	for b: Dictionary in board.buildings:
		if b.has("kit"):
			parts[b["rect"]] = b
	var main1 := parts.get(Rect2i(2, 2, 6, 3), {}) as Dictionary
	var wing1 := parts.get(Rect2i(5, 5, 3, 4), {}) as Dictionary
	var main2 := parts.get(Rect2i(13, 2, 3, 9), {}) as Dictionary
	var wing2 := parts.get(Rect2i(9, 8, 4, 3), {}) as Dictionary
	assert_eq(parts.size(), 4, "two L's, two parts each: %s" % [parts.keys()])
	if main1.is_empty() or wing1.is_empty() or main2.is_empty() or wing2.is_empty():
		v.queue_free()
		Compendium.shared().tables["locations"].erase("kit_l_test")
		return
	for pair: Array in [[main1, wing1], [main2, wing2]]:
		var m := pair[0] as Dictionary
		var w := pair[1] as Dictionary
		assert_eq(int(m["group"]), int(w["group"]), "one block")
		assert_eq(float(m["height"]), float(w["height"]), "one height")
		assert_eq(str(m["roof"]), str(w["roof"]), "one roof")
		assert_eq(str(m["paint"]), str(w["paint"]), "one paint")
		assert_true(float(w["rise"]) < float(m["rise"]), "the wing's ridge under the main one's")
	assert_true((wing1["butts"] as Dictionary).has("-z"), "wing 1 runs into its house to the north")
	assert_true((wing2["butts"] as Dictionary).has("+x"), "wing 2 runs into its house to the east")
	for x: int in [5, 6, 7]:
		assert_false((main1["faces"] as Dictionary).has("%d,4,0,1" % x), "no wall of the main house where the wing joins")
		assert_false((wing1["faces"] as Dictionary).has("%d,5,0,-1" % x), "nor of the wing")
	# One part in the way takes the other down with it (cut_away on): the camera west of wing 1, looking past it.
	_cutting()
	var focus := Vector3(8.5, 0, 6.5)
	for i in 2:
		board.cut_buildings(Vector3(0, 8, 6.5), focus, 1.0)
	assert_true(bool(wing1["cut"]), "the wing in the way is cut away")
	assert_true(bool(main1["cut"]), "and its main house with it")
	assert_false(bool(main2["cut"]), "the other L stands")
	v.queue_free()
	await _frames(1)
	Compendium.shared().tables["locations"].erase("kit_l_test")


## The village church and St. Andral's are churches: stone, with a bell tower over their doors.
func test_churches_are_stone_with_a_tower() -> void:
	for loc_id: String in ["village_of_barovia", "vallaki"]:
		var v := _view(loc_id)
		await _frames(2)
		var churches := 0
		for b: Dictionary in v.board.buildings:
			if str(b.get("kit", "")) == "church":
				churches += 1
				assert_true((b["aabb"] as AABB).size.y > float(b["height"]) + 6.0, "%s's church has its tower" % loc_id)
		assert_eq(churches, 1, "%s has its church" % loc_id)
		v.queue_free()
		await _frames(1)


## Vallaki is clapboard behind a palisade of sharpened logs; Krezk is stone, its walls the tall town wall.
func test_each_town_has_its_style() -> void:
	var v := _view("vallaki")
	await _frames(2)
	assert_true(v.board.buildings.size() >= 6, "Vallaki has its houses")
	var paints := {}
	for b: Dictionary in v.board.buildings:
		assert_true(str(b.get("kit", "")) in ["clapboard", "church"], "Vallaki's houses are clapboard (and St. Andral's)")
		if str(b["kit"]) == "clapboard":
			paints[str(b["paint"])] = true
	assert_true(paints.size() >= 3, "painted in several colours (%d)" % paints.size())
	assert_true(v.board.get_node_or_null("Palisade") is MeshInstance3D, "behind its palisade")
	v.queue_free()
	await _frames(1)
	var k := _view("krezk")
	await _frames(2)
	for b: Dictionary in k.board.buildings:
		assert_eq(str(b.get("kit", "")), "stone", "Krezk's houses are stone")
	var walls := 0
	var tall := 0
	for c in k.board.get_children():
		if str(c.name).begins_with("YardWall") and c is MeshInstance3D:
			walls += 1
			if (c as MeshInstance3D).get_aabb().size.y > 2.0:
				tall += 1
	assert_true(walls > 0 and tall == walls, "its walls are the tall town wall (%d of %d)" % [tall, walls])
	k.queue_free()


## Owner report (2026-10-13): "The border wall is missing inside Krezk." Its wall rings the village at the map's edge
## (north, west and south) as it does on the gate's side, not a fringe of pines, and fades as the pines did when it
## stands between the camera and the party.
func test_krezk_is_walled_all_round() -> void:
	var k := _view("krezk")
	await _frames(2)
	var g := k.board.grid
	var edge := 0
	for z in g.depth:
		for x in g.width:
			var c := Vector2i(x, z)
			if not g.has_flag(c, CombatGrid.WALL) or not (x == 0 or z == 0 or x == g.width - 1 or z == g.depth - 1):
				continue
			edge += 1
			var walls: Array[MeshInstance3D] = []
			for n: Node3D in k.board.dressing.get(c, []) as Array:
				assert_false(n in k.board.occluders or n.has_meta("nature"), "no pine at %s" % c)
				if n is MeshInstance3D and (n as MeshInstance3D).get_aabb().size.y > 2.0:
					walls.append(n as MeshInstance3D)
			assert_eq(walls.size(), 1, "the town wall stands tall at %s" % c)
			for w in walls:
				assert_true(Rect2(x, z, 1, 1).has_point(Vector2(w.global_position.x, w.global_position.z)), "placed on its square")
				assert_true(SeeThrough.marked(w) and not w in k.board.mesh_occluders, "and opening round the party when it hides it")
	assert_eq(edge, 91, "the north, west and south walls are all there (the pool lane's gap aside)")
	# It turns the corners and runs on into the wall on the gate's side.
	var ne := ((k.board.dressing[Vector2i(31, 0)] as Array)[0] as MeshInstance3D).get_aabb()
	assert_true(ne.position.x < -0.4 and ne.end.z > 0.4, "the north wall meets the gate's side (%s)" % ne)
	var se := ((k.board.dressing[Vector2i(31, 29)] as Array)[0] as MeshInstance3D).get_aabb()
	assert_true(se.position.x < -0.4 and se.position.z < -0.4, "and so does the south wall (%s)" % se)
	var nw := ((k.board.dressing[Vector2i(0, 0)] as Array)[0] as MeshInstance3D).get_aabb()
	assert_true(nw.end.x > 0.4 and nw.end.z > 0.4, "the north and west walls meet (%s)" % nw)
	# Every square of it, the gate's side too, stands on ground of its own (the gate's side showed the sky at its feet),
	# and none of it counts as a tree (undergrowth, wall decals and big pieces clearing trees leave it be).
	for c: Vector2i in [Vector2i(31, 10), Vector2i(31, 22), Vector2i(0, 12), Vector2i(8, 29)]:
		var ground := 0
		for n in k.board.get_children():
			var box := (n as MeshInstance3D).mesh as BoxMesh if n is MeshInstance3D else null
			if box != null and is_equal_approx(box.size.x, 1.0) and is_equal_approx(box.size.z, 1.0) \
					and Vector2((n as Node3D).position.x, (n as Node3D).position.z).is_equal_approx(Vector2(c) + Vector2(0.5, 0.5)):
				ground += 1
		assert_eq(ground, 1, "ground under the wall at %s" % c)
		assert_false(k.board.is_tree(c), "the wall at %s isn't a tree" % c)
	# Just inside the south wall, with the camera behind it, the wall stands solid (a window opens in it round the
	# party, SeeThrough) instead of fading as the pines there did.
	var south := (k.board.dressing[Vector2i(8, 29)] as Array)[0] as GeometryInstance3D
	var inside := k.board.cell_center(Vector2i(8, 27))
	k.board.fade_occluders(inside + Vector3(-8, 10, 8), inside, 1.0)
	assert_true(is_zero_approx(south.transparency) and SeeThrough.marked(south), "the south wall stands, opening round the party")
	k.queue_free()
	await _frames(1)
	var v := _view("village_of_barovia")
	await _frames(2)
	var trees := 0
	for c: Vector2i in v.board.dressing:
		if c.x == 0 or c.y == 0:
			for n: Node3D in v.board.dressing[c] as Array:
				if n in v.board.mesh_occluders or n in v.board.occluders:
					trees += 1
	assert_true(trees > 0, "an open village still thins into forest at its edge")
	v.queue_free()


## A lone wall square in a room is a pillar in the place's style: the castle's carved piers, the church's columns.
func test_lone_wall_squares_are_pillars() -> void:
	for pair: Array in [["castle_ravenloft_main_floor", Vector2i(22, 5), "castle"], ["village_church", Vector2i(5, 18), "church"],
			["death_house_dungeon_2", Vector2i(19, 12), "dungeon"]]:
		var v := _view(str(pair[0]))
		await _frames(2)
		var cell := pair[1] as Vector2i
		var found := false
		for n: Node in v.board.dressing.get(cell, []):
			if n.name == "Pillar" and n is MeshInstance3D:
				found = true
				assert_true((n as MeshInstance3D).get_aabb().size.y > 2.0, "%s's pillar stands tall" % pair[0])
				assert_true(SeeThrough.marked(n as MeshInstance3D) and not n in v.board.mesh_occluders,
					"and opens round the party when it hides it, never fading whole")
		assert_true(found, "%s has a %s pillar at %s" % [pair[0], pair[2], cell])
		assert_eq(BuildingKit.interior_style(v.board), str(pair[2]))
		v.queue_free()
		await _frames(1)


## W8: a room's walls stand a full storey from every heading (owner 2026-10-17: "walls collapse down when looking from
## certain angles ... I don't like this behavior"): a wall between the camera and the party stands whole and opens a
## window round the party instead (SeeThrough), with no cut-away version built. Past the house's outer walls there's the
## street, a storey below on the Death House's upper floor, and a doorway has wall over it. With the catalog's interiors
## cut_away on, the near walls still drop to the cut-away height, turning with the camera. Classic keeps the low walls.
func test_interiors_have_full_walls_that_stand() -> void:
	var v := _view("death_house_upper")
	await _frames(2)
	var board := v.board
	var st := board.get_meta("interior_walls", {}) as Dictionary
	assert_false(st.is_empty(), "the Death House's upper floor has full walls")
	assert_eq(float(st.get("height", 0.0)), float(InteriorWalls.HEIGHTS["manor"]), "a manor's storey")
	var ground := board.get_node_or_null("OutsideGround") as MeshInstance3D
	assert_true(ground != null, "the street lies outside")
	if ground != null:
		var top := ground.global_position.y + (ground.mesh as BoxMesh).size.y / 2.0
		assert_between(top, -InteriorWalls.STOREY - 0.2, -InteriorWalls.STOREY + 0.1, "a storey below")
	var wall := _north_wall(board, st)
	assert_true(_headers(st) > 0, "doorways have wall over them (%d)" % _headers(st))
	assert_false(wall.is_empty(), "a north wall to look at")
	if wall.is_empty():
		v.queue_free()
		return
	var full := wall["full"] as Node3D
	var tall := AABB()
	for mi: Node in full.find_children("*", "MeshInstance3D", true, false):
		tall = tall.merge((mi as MeshInstance3D).global_transform * (mi as MeshInstance3D).mesh.get_aabb())
	assert_true(tall.size.y > 2.3, "the wall stands a storey (%.2f)" % tall.size.y)
	assert_true(wall["low"] == null and (wall["node"] as Node3D).get_node_or_null("Cut") == null, "with no cut-away version")
	assert_true(_all_marked(wall["node"] as Node3D), "and opens round the party where it hides it")
	var focus := board.cell_center((wall["cell"] as Vector2i) + Vector2i(0, 2))
	# The camera south of the party (the north wall is the far wall), then turned to look south (the near wall).
	for camera: Vector3 in [focus + Vector3(0, 8, 10), focus + Vector3(0, 8, -10), focus + Vector3(0, 8, 10)]:
		for i in 2:
			board.cut_buildings(camera, focus, 1.0)
		assert_true(full.visible and is_equal_approx(full.scale.y, 1.0), "the wall stands from every side")
	for w: Dictionary in st["walls"]:
		assert_true((w["full"] as Node3D).visible and is_equal_approx((w["full"] as Node3D).scale.y, 1.0), "every wall stands")
	v.queue_free()
	await _frames(1)
	(BuildingKit.settings()["interiors"] as Dictionary)["cut_away"] = true
	var cut := _view("death_house_upper")
	await _frames(2)
	var cst := cut.board.get_meta("interior_walls", {}) as Dictionary
	var cw := _north_wall(cut.board, cst)
	var cfull := cw["full"] as Node3D
	var low := cw["low"] as Node3D
	assert_true(low != null, "cutting on: a cut-away version too")
	if low != null:
		focus = cut.board.cell_center((cw["cell"] as Vector2i) + Vector2i(0, 2))
		cut.board.cut_buildings(focus + Vector3(0, 8, 10), focus, 1.0)
		assert_true(cfull.visible and not low.visible, "the far wall stands")
		cut.board.cut_buildings(focus + Vector3(0, 8, -10), focus, 1.0)
		assert_true(low.visible and not cfull.visible, "the near wall is cut away")
		cut.board.cut_buildings(focus + Vector3(0, 8, 10), focus, 1.0)
		assert_true(cfull.visible and not low.visible, "and stands again when the camera turns back")
	cut.queue_free()
	await _frames(1)
	Look.set_style("classic", false)
	var c := _view("death_house_upper")
	await _frames(2)
	assert_false(c.board.has_meta("interior_walls") and not (c.board.get_meta("interior_walls") as Dictionary).is_empty(),
		"Classic keeps its low walls")
	assert_true(c.board.get_node_or_null("InteriorWalls") == null, "with no full walls")
	c.queue_free()


## An outer wall on a room's north side (the room below it, nothing open above it) among the walls in `st`.
func _north_wall(board: ArenaBoard, st: Dictionary) -> Dictionary:
	for w: Dictionary in st.get("walls", []):
		if w.has("flanks"):
			continue
		var c := w["cell"] as Vector2i
		if _open(board, c + Vector2i(0, 1)) and _open(board, c + Vector2i(0, 2)):
			var clear := true
			for k: int in [1, 2, 3, 4, 5]:
				clear = clear and not _open(board, c - Vector2i(0, k))
			if clear:
				return w
	return {}


## How many of the walls in `st` stand over doorways.
func _headers(st: Dictionary) -> int:
	var n := 0
	for w: Dictionary in st.get("walls", []):
		if w.has("flanks"):
			n += 1
	return n


func _open(board: ArenaBoard, c: Vector2i) -> bool:
	return board.grid.in_bounds(c) and not board.grid.has_flag(c, CombatGrid.WALL) and not board.grid.has_flag(c, CombatGrid.VOID)


## W7: a doorway inside is framed in the place's style on each side that opens into a room: jambs that stay as the
## walls cut away, and a head (lintel, arch, cornice) that goes with the wall over the doorway. A door hung there has
## no plain frame of its own; a secret door shows no doorway until it's found. A corridor under the wall over it and
## the aisles between the Amber Temple's book stacks aren't doorways.
func test_doorways_inside_are_framed_in_the_place_style() -> void:
	for spec: Array in [["death_house_ground", Vector2i(21, 6), "manor"], ["castle_ravenloft_main_floor", Vector2i(11, 3), "castle"],
			["village_church", Vector2i(18, 4), "church"], ["vallaki_blue_water_inn", Vector2i(16, 5), "timber"],
			["death_house_dungeon_1", Vector2i(2, 5), "dungeon"], ["amber_temple_library", Vector2i(5, 8), "amber"]]:
		var v := _view(str(spec[0]))
		await _frames(2)
		var board := v.board
		var cell := spec[1] as Vector2i
		var st := board.get_meta("interior_walls", {}) as Dictionary
		assert_eq(str(st.get("style", "")), str(spec[2]), "%s is built in its style" % spec[0])
		var parts := _frame_parts(board, cell)
		assert_eq(parts.size(), 2, "%s's doorway at %s is framed" % [spec[0], cell])
		assert_true(InteriorWalls.frames(board, cell), "and says so")
		if parts.size() == 2:
			var jambs := parts[0] as MeshInstance3D
			var head := parts[1] as MeshInstance3D
			assert_eq(str(jambs.name), "DoorwayJambs")
			assert_true(jambs.get_aabb().size.y > InteriorWalls.CUT - 0.05, "jambs the opening's height")
			assert_true(head.get_aabb().position.y >= InteriorWalls.CUT - 0.15, "the head over the opening")
			for n: Node in board.get_children():
				if str(n.name).begins_with("DoorFrame") and board.grid.cell_at((n as Node3D).global_position) == cell:
					fail("%s's door at %s still has a plain frame" % [spec[0], cell])
					break
			# The camera across the doorway: the wall over it stands with its head and the jambs, all of them opening
			# round the party instead (SeeThrough).
			var at := board.cell_center(cell)
			for i in 2:
				board.cut_buildings(at + Vector3(0, 8, -10), at + Vector3(0, 0, 2), 1.0)
			assert_true(head.is_visible_in_tree() and jambs.is_visible_in_tree(), "%s: the doorway stands" % spec[0])
			assert_true(SeeThrough.marked(head) and SeeThrough.marked(jambs), "%s: and opens round the party" % spec[0])
		v.queue_free()
		await _frames(1)
	# A secret door: no doorway until it's found.
	var c := _view("castle_ravenloft_main_floor")
	await _frames(2)
	var secret := Vector2i(47, 5)
	var hidden := _frame_parts(c.board, secret)
	assert_false(hidden.is_empty(), "the hearth's secret door is in a framed doorway")
	for part in hidden:
		assert_false(part.visible, "hidden while nobody has found it")
	InteriorWalls.show_frame(c.board, secret, true)
	for part in hidden:
		assert_true(part.visible, "shown once it's found")
	c.queue_free()
	await _frames(1)
	# Not doorways: a corridor between walls, and the aisle between a book stack and the wall.
	var d := _view("death_house_dungeon_1")
	await _frames(2)
	assert_false(InteriorWalls.frames(d.board, Vector2i(13, 6)), "a corridor under the wall over it")
	d.queue_free()
	await _frames(1)
	var a := _view("amber_temple_library")
	await _frames(2)
	assert_false(InteriorWalls.frames(a.board, Vector2i(28, 10)), "an aisle between the stacks")
	a.queue_free()


## A framed doorway's jambs and head (InteriorWalls' state), or none.
func _frame_parts(board: ArenaBoard, cell: Vector2i) -> Array[Node3D]:
	var out: Array[Node3D] = []
	var st := board.get_meta("interior_walls", {}) as Dictionary
	for part: Variant in (st.get("frames", {}) as Dictionary).get(cell, []):
		out.append(part as Node3D)
	return out


## W19: Castle Ravenloft from outside. The gates' walls are the castle's: curtain walls six high with their
## battlements, the keep taller, round towers under spires, an arch over the gatehouse with the portcullis in it and
## no frame of its own, cliffs falling into the chasm, and timbers under the drawbridge. A wall in the way of the party
## in the courtyard cuts down to its foot; turned the other way, the keep does. Classic keeps the stone houses.
func test_castle_ravenloft_from_outside() -> void:
	var v := _view("castle_ravenloft_gates")
	await _frames(2)
	var board := v.board
	var parts := {}
	for b: Dictionary in board.buildings:
		if b.has("castle"):
			parts[str(b["part"])] = int(parts.get(str(b["part"]), 0)) + 1
	assert_true(int(parts.get("wall", 0)) >= 20 and int(parts.get("tower", 0)) >= 10 and int(parts.get("gate", 0)) >= 4,
		"the castle's walls, towers and gates (%s)" % str(parts))
	var south := board.buildings[int(board.house_cells.get(Vector2i(10, 22), -1))] as Dictionary
	var keep := board.buildings[int(board.house_cells.get(Vector2i(20, 4), -1))] as Dictionary
	assert_true(south.has("castle") and float(south["height"]) >= 6.0, "the curtain wall stands six high")
	assert_true(keep.has("castle") and float(keep["height"]) >= 10.0, "the keep stands taller")
	assert_true(board.find_children("Spire", "MeshInstance3D", true, false).size() >= 10, "the towers have their spires")
	assert_true(CastleBuilder.frames(board, Vector2i(19, 22)), "the gatehouse is an arch")
	var chasm := board.get_node_or_null("Chasm") as MeshInstance3D
	assert_true(chasm != null and chasm.get_aabb().position.y < -15.0, "cliffs fall into the chasm")
	# The party in the courtyard, the camera to the south (cut_away on): the south wall in the way goes down, the keep
	# stands.
	_cutting()
	var focus := board.cell_center(Vector2i(19, 18))
	var gate_wall := board.buildings[int(board.house_cells[Vector2i(18, 22)])] as Dictionary
	for i in 2:
		board.cut_buildings(focus + Vector3(0, 12, 12), focus, 1.0)
	assert_true((gate_wall["stub"] as Node3D).visible and not (gate_wall["walls"] as Node3D).visible,
		"the wall in the way cuts down to its foot")
	assert_true((keep["walls"] as Node3D).visible, "the keep behind the party stands")
	for i in 2:
		board.cut_buildings(focus + Vector3(0, 12, -12), focus, 1.0)
	assert_true((gate_wall["walls"] as Node3D).visible and not (keep["walls"] as Node3D).visible,
		"turned round, the gate wall stands and the keep goes down")
	v.queue_free()
	await _frames(1)
	# The roofs among the spires: the castle's parapets instead of an interior's walls, towers rising out of the drop.
	var r := _view("castle_ravenloft_spires_roofs")
	await _frames(2)
	assert_true(r.board.house_cells.has(Vector2i(0, 1)) and not r.board.has_meta("interior_walls"), "the roof's parapets")
	assert_true(r.board.find_children("Spire", "MeshInstance3D", true, false).size() >= 4, "spires all round")
	r.queue_free()
	await _frames(1)
	Look.set_style("classic", false)
	var c := _view("castle_ravenloft_gates")
	await _frames(2)
	for b: Dictionary in c.board.buildings:
		assert_false(b.has("castle"), "Classic keeps the stone houses")
	c.queue_free()


## W7: Castle Ravenloft's wall walk and the keep's roof. Along the gate wall each side of the gatehouse, a walk thirty
## feet up that the rules stand on, reached from the courtyard by stairs in five-foot steps (thirty feet of walking,
## nothing climbed), drawn in the castle's stone with no floor of the board's own. The keep has a slated roof inside
## its battlements that goes down with the keep when it's in the way. Classic draws the walk as raised floor.
func test_the_castle_wall_walk_and_the_keep_roof() -> void:
	var v := _view("castle_ravenloft_gates")
	await _frames(2)
	var board := v.board
	var g := board.grid
	var walk: Array[int] = []
	walk.append_array(range(11, 17))
	walk.append_array(range(23, 29))
	for x in walk:
		var c := Vector2i(x, 22)
		assert_eq(g.height(c), 30, "the walk at %s is 30 ft up" % c)
		assert_false(g.has_flag(c, CombatGrid.WALL), "and stood on")
		assert_true(CastleBuilder.walk_at(board, c), "in the castle's stone")
		assert_true(board.floor_box(c) == null, "with no floor of the board's own")
	var none := func(_c: Vector2i) -> bool: return false
	var reach := g.reachable(Vector2i(11, 21), 1, 60, none, none, none)
	assert_eq(int((reach.get(Vector2i(16, 22), {"cost": -1}) as Dictionary)["cost"]), 30, "up the west stairs in steps")
	reach = g.reachable(Vector2i(28, 21), 1, 60, none, none, none)
	assert_eq(int((reach.get(Vector2i(23, 22), {"cost": -1}) as Dictionary)["cost"]), 30, "and the east stairs")
	var roof := {}
	var keep := {}
	for b: Dictionary in board.buildings:
		if b.has("castle") and str(b["part"]) == "keeproof":
			roof = b
	keep = board.buildings[int(board.house_cells[Vector2i(20, 4)])] as Dictionary
	assert_false(roof.is_empty(), "the keep has a roof")
	if not roof.is_empty():
		var mi := (roof["upper"] as Node3D).get_node_or_null("Roof") as MeshInstance3D
		assert_true(mi != null and mi.get_aabb().end.y > float(keep["height"]) + 2.0, "rising over its battlements")
		_cutting()
		var focus := board.cell_center(Vector2i(19, 18))
		for i in 2:
			board.cut_buildings(focus + Vector3(0, 12, -12), focus, 1.0)
		assert_false((roof["upper"] as Node3D).visible, "turned round, the roof goes down with the keep")
		for i in 2:
			board.cut_buildings(focus + Vector3(0, 12, 12), focus, 1.0)
		assert_true((roof["upper"] as Node3D).visible, "and stands again")
	v.queue_free()
	await _frames(1)
	Look.set_style("classic", false)
	var c := _view("castle_ravenloft_gates")
	await _frames(2)
	assert_false(CastleBuilder.walk_at(c.board, Vector2i(12, 22)), "Classic")
	assert_true(c.board.floor_box(Vector2i(12, 22)) != null, "draws the walk as raised floor")
	c.queue_free()


## The loading lane: merging appends each module from its arrays held in memory (BuildingKit.Arrays) instead of reading
## the module's mesh back from the GPU every time; the merged house is the same, vertex for vertex.
func test_merging_from_memory_matches_merging_from_the_mesh() -> void:
	var parts: Array = []
	var ids: Array[String] = ["kit_timber_corner", "kit_clap_low_a", "kit_palisade"]
	for i in ids.size():
		assert_true(BuildingKit.has(ids[i]), "the kit has %s" % ids[i])
		parts.append([ids[i], Transform3D(Basis(Vector3.UP, 0.7 * i), Vector3(i * 2.0, 0.0, 1.0))])
	var cap := BoxMesh.new()
	parts.append([cap, Transform3D(Basis(), Vector3(0, 3, 0)), "pal_bone"])
	var merged := BuildingKit.merge(parts, "crimson")
	# The same merge the old way: SurfaceTool reading each mesh itself.
	var tools := {}
	var order: Array[String] = []
	for part: Array in parts:
		var m: Mesh = part[0] as Mesh if part[0] is Mesh else BuildingKit.mesh(str(part[0]))
		var repaint := "" if part[0] is Mesh else str((BuildingKit.manifest().get(str(part[0]), {}) as Dictionary).get("paint", ""))
		for i in m.get_surface_count():
			var name := str(part[2]) if part[0] is Mesh else (m.surface_get_material(i).resource_name if m.surface_get_material(i) != null else "pal_pewter")
			if repaint != "" and name == repaint:
				name = "paint:crimson"
			if not tools.has(name):
				var st := SurfaceTool.new()
				st.begin(Mesh.PRIMITIVE_TRIANGLES)
				tools[name] = st
				order.append(name)
			(tools[name] as SurfaceTool).append_from(m, i, part[1] as Transform3D)
	var am := merged.mesh as ArrayMesh
	var old := ArrayMesh.new()
	for name in order:
		(tools[name] as SurfaceTool).commit(old)
	assert_eq(am.get_surface_count(), order.size(), "one surface per material")
	for s in order.size():
		var want := old.surface_get_arrays(s)
		var got := am.surface_get_arrays(s)
		assert_eq(got[Mesh.ARRAY_VERTEX], want[Mesh.ARRAY_VERTEX], "%s: the same vertices" % order[s])
		assert_eq(got[Mesh.ARRAY_NORMAL], want[Mesh.ARRAY_NORMAL], "%s: the same normals" % order[s])
		assert_eq(got[Mesh.ARRAY_INDEX], want[Mesh.ARRAY_INDEX], "%s: the same triangles" % order[s])
	merged.free()
