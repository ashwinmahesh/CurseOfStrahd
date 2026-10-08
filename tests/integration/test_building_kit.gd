extends TestCase
## The building kit (Improvement Ideas W7, docs/art/building_kit.md): towns are put together from Blender modules in
## their region's style instead of textured boxes: Barovia's timber framing, Vallaki's clapboard and palisade, Krezk's
## stone. A door hung on a house makes a door bay; a house in the way is cut down to its footing.


func before_each() -> void:
	GameState.reset()
	ModeController.force(ModeController.Mode.EXPLORATION)
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


## A house between the camera and the party drops to its footing round a floor; it stands again when it's clear.
func test_a_kit_house_cuts_away_to_its_footing() -> void:
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
				assert_true(n in v.board.mesh_occluders, "and fades when it hides the party")
		assert_true(found, "%s has a %s pillar at %s" % [pair[0], pair[2], cell])
		assert_eq(BuildingKit.interior_style(v.board), str(pair[2]))
		v.queue_free()
		await _frames(1)


## W8: a room's walls stand a full storey, and a wall drops to the cut-away height when it stands between the camera
## and the party's room; turning the camera turns which. Past the house's outer walls there's the street, a storey
## below on the Death House's upper floor, and a doorway has wall over it. The Classic look keeps the low walls.
func test_interiors_have_full_walls_that_cut_away() -> void:
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
	var headers := 0
	var wall := {}
	for w: Dictionary in st.get("walls", []):
		if w.has("flanks"):
			headers += 1
			continue
		# An outer wall on the room's north side: the room below it, nothing open above it.
		var c := w["cell"] as Vector2i
		if wall.is_empty() and _open(board, c + Vector2i(0, 1)) and _open(board, c + Vector2i(0, 2)):
			var clear := true
			for k: int in [1, 2, 3, 4, 5]:
				clear = clear and not _open(board, c - Vector2i(0, k))
			if clear:
				wall = w
	assert_true(headers > 0, "doorways have wall over them (%d)" % headers)
	assert_false(wall.is_empty(), "a north wall to look at")
	if wall.is_empty():
		v.queue_free()
		return
	var full := wall["full"] as Node3D
	var low := wall["low"] as Node3D
	var tall := AABB()
	for mi: Node in full.find_children("*", "MeshInstance3D", true, false):
		tall = tall.merge((mi as MeshInstance3D).global_transform * (mi as MeshInstance3D).mesh.get_aabb())
	assert_true(tall.size.y > 2.3, "the wall stands a storey (%.2f)" % tall.size.y)
	var focus := board.cell_center((wall["cell"] as Vector2i) + Vector2i(0, 2))
	# The camera south of the party: the north wall is the far wall, standing.
	board.cut_buildings(focus + Vector3(0, 8, 10), focus, 1.0)
	assert_true(full.visible and not low.visible, "the far wall stands")
	# Turned to look south: it's between the camera and the party, and drops to the cut-away height.
	board.cut_buildings(focus + Vector3(0, 8, -10), focus, 1.0)
	assert_true(low.visible and not full.visible, "the near wall is cut away")
	board.cut_buildings(focus + Vector3(0, 8, 10), focus, 1.0)
	assert_true(full.visible and not low.visible, "and stands again when the camera turns back")
	v.queue_free()
	await _frames(1)
	Look.set_style("classic", false)
	var c := _view("death_house_upper")
	await _frames(2)
	assert_false(c.board.has_meta("interior_walls") and not (c.board.get_meta("interior_walls") as Dictionary).is_empty(),
		"Classic keeps its low walls")
	assert_true(c.board.get_node_or_null("InteriorWalls") == null, "with no full walls")
	c.queue_free()


func _open(board: ArenaBoard, c: Vector2i) -> bool:
	return board.grid.in_bounds(c) and not board.grid.has_flag(c, CombatGrid.WALL) and not board.grid.has_flag(c, CombatGrid.VOID)


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
	# The party in the courtyard, the camera to the south: the south wall in the way goes down, the keep stands.
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
