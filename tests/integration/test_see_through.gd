extends TestCase
## Walls in the party's way (owner 2026-10-17: walls collapsing from some headings at the Tsolenka guard tower and the
## Amber Temple, and Castle Ravenloft's big walls going see-through whole, "looks really weird"): every wall, house,
## castle piece, town wall, pillar and tower stands whole from every heading, and a window opens round the party in
## what stands nearer the camera (SeeThrough, shaders/world/see_through.gdshaderinc). These check what's marked to
## open, that nothing drops or fades whole, where the window goes, and that the world's shaders cut it.


func before_each() -> void:
	GameState.reset()
	ModeController.force(ModeController.Mode.EXPLORATION)
	for id: String in ["godrick_pendlebrook", "liriel_dawnsong", "thistle", "ratatoille"]:
		var ch := Pregens.build(id, 3)
		ch.finish_long_rest()
		GameState.story.party.append(ch)
	GameState.story.flags["strahd_invitation"] = "accepted"   # (no fight at the castle's gates on arrival)
	Look.set_style("modern", false)


func after_each() -> void:
	Look.set_style(Look.DEFAULT_STYLE, false)
	GameState.reset()


func _view(loc_id: String) -> LocationView:
	var v := LocationView.create(loc_id, GameState.story, null, Dice.roller, "default")
	add_child(v)
	return v


func _frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame


## The places named and the ones like them: the castle's walls, towers and keep, the guard tower's rooms, the Amber
## Temple's walls, book stacks and pillars, Krezk's town wall, a village's houses, Van Richten's tower. Every mesh of
## every wall opens round the party; the floors never do; and none of them fades whole or has a cut-away version.
func test_walls_everywhere_open_round_the_party() -> void:
	for loc: String in ["castle_ravenloft_gates", "tsolenka_pass_guard_tower", "amber_temple_entrance", "amber_temple_library",
			"amber_temple_faceless_god", "castle_ravenloft_main_floor", "krezk", "village_of_barovia", "van_richtens_tower"]:
		var v := _view(loc)
		await _frames(2)
		var board := v.board
		var walls := 0
		var unmarked: Array[String] = []
		for b: Dictionary in board.buildings:
			if b.has("interior"):
				for w: Dictionary in (b["state"] as Dictionary)["walls"]:
					walls += 1
					_check(w["node"] as Node3D, unmarked)
					assert_true(w["low"] == null, "%s: no cut-away wall at %s" % [loc, w["cell"]])
			else:
				walls += 1
				_check(b["root"] as Node3D, unmarked)
		for n: Node in board.get_children():
			# (A yard wall waist high hides nobody and stays whole; a town wall three men high opens.)
			var tall_yard := str(n.name) == "YardWall" and (n as MeshInstance3D).get_aabb().size.y > 1.6
			if str(n.name) in ["Pillar", "WallBlock"] or tall_yard:
				walls += 1
				_check(n as Node3D, unmarked)
		# A building-sized piece standing in for a house (Van Richten's tower) or a statue of stone or timber.
		for n: Node in v.find_children("Model_*", "Node3D", true, false):
			if str(n.get_meta("art", "")) in ["tower_vr", "bell_tower", "windmill", "colossus", "statue_faceless", "hut_lysaga"]:
				walls += 1
				_check(n as Node3D, unmarked)
		assert_true(walls > 0, "%s has walls (%d)" % [loc, walls])
		assert_eq(unmarked, [] as Array[String], "%s: every wall opens round the party" % loc)
		for c: Vector2i in [v.members[0].cell, v.members[v.members.size() - 1].cell]:
			var floor := board.floor_box(c)
			if floor != null:
				assert_false(SeeThrough.marked(floor), "%s: the floor under the party never opens" % loc)
		for t: Node3D in board.mesh_occluders:
			assert_false(str(t.name) in ["Pillar", "YardWall"], "%s: no wall fades whole" % loc)
		v.queue_free()
		await _frames(1)


func _check(n: Node3D, unmarked: Array[String]) -> void:
	var meshes := n.find_children("*", "GeometryInstance3D", true, false)
	if n is GeometryInstance3D:
		meshes.append(n)
	for g in meshes:
		if g is GPUParticles3D or (g as Node).get_parent() is GPUParticles3D:
			continue   # (a chimney's smoke)
		if not SeeThrough.marked(g as GeometryInstance3D) and unmarked.size() < 5:
			unmarked.append(str(n.get_path()).get_slice("ArenaBoard/", 1) + ":" + str(g.name))


## From each of the four headings, with the party in the castle's courtyard and in the guard tower's guardroom, every
## wall stands at its full height, solid (the castle's curtain walls went see-through whole; the tower's dropped to a
## stub toward the camera).
func test_no_wall_drops_or_fades_from_any_heading() -> void:
	for spot: Array in [["castle_ravenloft_gates", Vector2i(30, 12)], ["tsolenka_pass_guard_tower", Vector2i(10, 8)]]:
		var v := _view(str(spot[0]))
		await _frames(2)
		var focus := v.board.cell_center(spot[1] as Vector2i)
		for yaw: int in 4:
			var a := deg_to_rad(45.0 + 90.0 * yaw)
			var camera := focus + Vector3(sin(a) * 10.0, 9.0, cos(a) * 10.0)
			for i in 3:
				v.board.cut_buildings(camera, focus, 1.0)
				v.board.fade_occluders(camera, focus, 1.0)
			for b: Dictionary in v.board.buildings:
				if b.has("interior"):
					for w: Dictionary in (b["state"] as Dictionary)["walls"]:
						var full := w["full"] as Node3D
						assert_true(full.visible and is_equal_approx(full.scale.y, 1.0), "%s: the wall at %s stands (heading %d)" % [spot[0], w["cell"], yaw])
				elif b.has("walls") and b["walls"] != null:
					var walls := b["walls"] as Node3D
					assert_true(walls.visible and is_equal_approx(walls.scale.y, 1.0), "%s: %s stands (heading %d)" % [spot[0], b.get("part", "a house"), yaw])
					for g in walls.find_children("*", "GeometryInstance3D", true, false):
						assert_true(is_zero_approx((g as GeometryInstance3D).transparency), "%s: solid, never see-through whole" % spot[0])
						break
		v.queue_free()
		await _frames(1)


## The window goes where the camera looks at the party: on the leader exploring, on whoever the camera follows in a
## fight, on a boss making an entrance; with no camera there's none.
func test_the_window_follows_the_camera() -> void:
	var v := _view("tsolenka_pass_guard_tower")
	await _frames(2)
	var see := v.get_node_or_null("SeeThrough") as SeeThrough
	assert_true(see != null, "the view has its window")
	if see == null:
		v.queue_free()
		return
	var leader := v.tokens[v.members[0].id] as Node3D
	assert_eq(see.focus(), leader.global_position, "on the leader")
	var other := v.tokens[v.members[2].id] as Node3D
	v.rig.follow = other
	assert_eq(see.focus(), other.global_position, "on whoever the camera follows")
	var boss := Node3D.new()
	v.add_child(boss)
	boss.global_position = v.board.cell_center(Vector2i(3, 3))
	v.rig.cutaway_focus = boss
	assert_eq(see.focus(), boss.global_position, "on a boss making an entrance")
	v.rig.cutaway_focus = null
	v.rig.follow = null
	assert_eq(see.focus(), v.rig.global_position, "else where the camera looks")
	boss.queue_free()
	v.queue_free()
	await _frames(1)
	see = SeeThrough.create(null)
	assert_eq(see.focus(), null, "no camera, no window")
	see.free()


## A wall opens through a copy of its material with see_through on, one copy for every wall drawn with that material;
## the material itself, which the floors and props share, never opens.
func test_marking_shares_one_copy_per_material() -> void:
	var stone := Look.cel_textured("castle/ashlar")
	var a := MeshInstance3D.new()
	a.mesh = BoxMesh.new()
	a.material_override = stone
	var b := MeshInstance3D.new()
	b.mesh = BoxMesh.new()
	b.material_override = stone
	a.add_child(b)
	SeeThrough.mark(a)
	assert_true(SeeThrough.marked(a) and SeeThrough.marked(b), "both open")
	assert_true(a.material_override == b.material_override and a.material_override != stone, "through one shared copy")
	assert_false(SeeThrough._on(stone as ShaderMaterial), "the material itself never opens")
	SeeThrough.mark(a)
	assert_true(a.material_override == b.material_override, "marking twice changes nothing")
	var floor := MeshInstance3D.new()
	floor.mesh = BoxMesh.new()
	floor.material_override = stone
	assert_false(SeeThrough.marked(floor), "an unmarked mesh drawn with it stays whole")
	floor.free()
	a.free()


## Every shader the world's walls are drawn with cuts the window (and only for what's marked: see_through).
func test_the_world_shaders_cut_the_window() -> void:
	var inc := FileAccess.get_file_as_string("res://shaders/world/see_through.gdshaderinc")
	assert_true(inc.contains("uniform bool see_through") and inc.contains("bool see_cut("), "the window's code")
	for sh: Shader in [Look.CEL_SHADER, Look.CEL_WORLD_SHADER, Look.LIT_SHADER, Look.LIT_WORLD_SHADER, ModelPiece.SPRITE_SHADER]:
		assert_true(sh.code.contains("see_through.gdshaderinc") and sh.code.contains("see_cut(VERTEX"), "%s cuts it" % sh.resource_path)
	for name: String in ["see_window", "see_window_eye"]:
		assert_true(ProjectSettings.has_setting("shader_globals/" + name), "%s is a global uniform" % name)
