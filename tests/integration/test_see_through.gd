extends TestCase
## Walls, roofs and the like in the party's way (owner 2026-10-17: walls collapsing from some headings at the Tsolenka guard
## tower and the Amber Temple, and Castle Ravenloft's big walls going see-through whole, "looks really weird"; 2026-10-19: no
## x-ray window, "use the opacity change"): every wall, house, castle piece, town wall, pillar and tower stands whole from every
## heading, and the pieces that hide the party fade to the trees' opacity while they do (SeeThrough). These check what's marked
## to fade, that nothing drops or fades whole when it isn't in the way, which pieces are in the way (and which are not), how
## they fade and come back, where the camera is on, and that no shader cuts a hole any more.


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
## every wall is marked to fade; the floors never are; and none of them fades whole or has a cut-away version.
func test_walls_everywhere_are_marked_to_fade() -> void:
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
			# (A yard wall waist high hides nobody and stays whole; a town wall three men high fades.)
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
		assert_eq(unmarked, [] as Array[String], "%s: every wall fades when it hides the party" % loc)
		for c: Vector2i in [v.members[0].cell, v.members[v.members.size() - 1].cell]:
			var floor := board.floor_box(c)
			if floor != null:
				assert_false(SeeThrough.marked(floor), "%s: the floor under the party never fades" % loc)
		for t: Node3D in board.mesh_occluders:
			assert_false(str(t.name) in ["Pillar", "YardWall"], "%s: no wall fades with the trees" % loc)
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
## stub toward the camera). What fades is SeeThrough's, and only while it hides the party.
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


# --- Which pieces are in the way ------------------------------------------------------------------------------------

## A bare scene: the camera's SeeThrough under a root, a wall piece (marked) at `at` of `size`, a floor (never marked).
func _scene() -> Array:
	var root := Node3D.new()
	add_child(root)
	var see := SeeThrough.create(null)
	root.add_child(see)
	return [root, see]


func _wall(root: Node3D, at: Vector3, size: Vector3 = Vector3(1, 3, 1)) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size
	mi.mesh = bm
	root.add_child(mi)
	mi.position = at + Vector3(0, size.y / 2.0, 0)
	SeeThrough.mark(mi)
	return mi


## The camera looks down from the south at the party standing at the origin; a wall between them is in the way and fades;
## walls beside it, behind it and nearer the camera but off to the side are not; the floor is never marked.
func test_only_the_pieces_between_the_camera_and_the_party_are_in_the_way() -> void:
	var s := _scene()
	var root := s[0] as Node3D
	var see := s[1] as SeeThrough
	var eye := Vector3(0, 6, 8)
	var between := _wall(root, Vector3(0, 0, 3))
	var beside := _wall(root, Vector3(2, 0, 0))
	var behind := _wall(root, Vector3(0, 0, -4))
	var off_to_the_side := _wall(root, Vector3(5, 0, 4))
	var floor := MeshInstance3D.new()
	var fm := BoxMesh.new()
	fm.size = Vector3(20, 0.2, 20)
	floor.mesh = fm
	root.add_child(floor)
	floor.position = Vector3(0, -0.1, 0)
	var in_the_way := see.in_the_way(Vector3.ZERO, eye)
	assert_true(in_the_way.has(between.get_instance_id()), "the wall between them hides the party")
	assert_false(in_the_way.has(beside.get_instance_id()), "the wall beside the party doesn't")
	assert_false(in_the_way.has(behind.get_instance_id()), "nor the one behind it")
	assert_false(in_the_way.has(off_to_the_side.get_instance_id()), "nor one nearer the camera but off to the side")
	assert_false(in_the_way.has(floor.get_instance_id()), "the floor is never marked")
	root.queue_free()


## A piece in the way eases up to the trees' opacity over a quarter of a second, and comes back to solid when the party
## steps out from behind it; then it is let go, its transparency back at nothing.
func test_a_piece_in_the_way_fades_and_comes_back() -> void:
	var s := _scene()
	var root := s[0] as Node3D
	var see := s[1] as SeeThrough
	var wall := _wall(root, Vector3(0, 0, 3))
	var eye := Vector3(0, 6, 8)
	see.look(Vector3.ZERO, eye)
	see.step(0.05)
	assert_true(wall.transparency > 0.0 and wall.transparency < SeeThrough.FADED, "on its way (%s)" % wall.transparency)
	see.step(1.0)
	assert_true(is_equal_approx(wall.transparency, SeeThrough.FADED), "as faded as the trees (%s)" % wall.transparency)
	assert_true(is_equal_approx(SeeThrough.faded(wall), SeeThrough.FADED))
	see.look(Vector3(6, 0, 0), eye)   # the party steps aside
	see.step(0.05)
	assert_true(wall.transparency < SeeThrough.FADED and wall.transparency > 0.0, "coming back")
	see.step(1.0)
	assert_eq(wall.transparency, 0.0, "solid again")
	assert_true(see._fading.is_empty(), "and let go")
	root.queue_free()


## The rest of the party exploring is kept in sight too: a wall that hides only the second hero fades.
func test_the_rest_of_the_party_is_kept_in_sight() -> void:
	var s := _scene()
	var root := s[0] as Node3D
	var see := s[1] as SeeThrough
	var eye := Vector3(0, 6, 8)
	var hides_second := _wall(root, Vector3(2.4, 0, 2))   # on the way to the second hero, not to the leader
	assert_false(see.in_the_way(Vector3.ZERO, eye).has(hides_second.get_instance_id()), "not the leader's")
	assert_true(see.in_the_way(Vector3.ZERO, eye, [Vector3(4, 0, -2)]).has(hides_second.get_instance_id()), "the second hero's")
	root.queue_free()


## A wall the party stands against, behind them, never hides them; a figure's feet count: a half-height wall across the way
## to the feet alone still fades.
func test_a_wall_the_party_stands_against_does_not_hide_it_and_a_low_one_does() -> void:
	var s := _scene()
	var root := s[0] as Node3D
	var see := s[1] as SeeThrough
	var eye := Vector3(0, 6, 8)
	var against := _wall(root, Vector3(0, 0, -0.8))
	var low := _wall(root, Vector3(0, 0, 2), Vector3(1, 1.5, 1))
	var found := see.in_the_way(Vector3.ZERO, eye)
	assert_false(found.has(against.get_instance_id()), "the wall behind the party")
	assert_true(found.has(low.get_instance_id()), "a low wall that hides the feet")
	root.queue_free()


## A big hollow piece (a house's walls, a castle wall) is in the way only where one of its faces is, not whenever the
## party is inside the box round it: the camera inside a ring of walls with the party sees them; outside it does not.
func test_a_big_hollow_piece_is_in_the_way_only_where_a_face_is() -> void:
	var s := _scene()
	var root := s[0] as Node3D
	var see := s[1] as SeeThrough
	var st := SurfaceTool.new()
	for wall: Array in [[Vector3(0, 1.5, 4), Vector3(8, 3, 0.4)], [Vector3(0, 1.5, -4), Vector3(8, 3, 0.4)],
			[Vector3(4, 1.5, 0), Vector3(0.4, 3, 8)], [Vector3(-4, 1.5, 0), Vector3(0.4, 3, 8)]]:
		var bm := BoxMesh.new()
		bm.size = wall[1] as Vector3
		st.append_from(bm, 0, Transform3D(Basis(), wall[0] as Vector3))
	var ring := MeshInstance3D.new()
	ring.mesh = st.commit()
	root.add_child(ring)
	SeeThrough.mark(ring)
	assert_true(ring.get_aabb().size.x > SeeThrough.LARGE, "a big piece")
	assert_true(see.in_the_way(Vector3.ZERO, Vector3(0, 4, 7)).has(ring.get_instance_id()), "from outside, its south wall hides the party")
	assert_false(see.in_the_way(Vector3.ZERO, Vector3(0, 6, 2.5)).has(ring.get_instance_id()), "from inside the ring, nothing does")
	root.queue_free()


## A piece of glass with a shader of its own (the Amber Temple's tall blocks) fades by its material's `see_fade`, since
## transparency would not reach its alpha; the transparency stays nothing.
func test_glass_fades_by_its_uniform() -> void:
	var s := _scene()
	var root := s[0] as Node3D
	var see := s[1] as SeeThrough
	var glass := _wall(root, Vector3(0, 0, 3))
	var m := ShaderMaterial.new()
	m.shader = load("res://shaders/world/amber.gdshader") as Shader
	glass.material_override = m
	SeeThrough.mark_glass(glass)
	assert_true(m.shader.code.contains("uniform float see_fade"), "the shader has the uniform")
	see.look(Vector3.ZERO, Vector3(0, 6, 8))
	see.step(1.0)
	assert_true(is_equal_approx(float(m.get_shader_parameter(&"see_fade")), SeeThrough.FADED), "faded by the uniform")
	assert_eq(glass.transparency, 0.0, "not by transparency")
	assert_true(is_equal_approx(SeeThrough.faded(glass), SeeThrough.FADED))
	see.look(Vector3(8, 0, 0), Vector3(0, 6, 8))
	see.step(1.0)
	assert_eq(float(m.get_shader_parameter(&"see_fade")), 0.0, "and whole again")
	root.queue_free()


## Taking the view away puts every piece back to solid.
func test_closing_the_view_makes_every_piece_whole() -> void:
	var s := _scene()
	var root := s[0] as Node3D
	var see := s[1] as SeeThrough
	var wall := _wall(root, Vector3(0, 0, 3))
	see.look(Vector3.ZERO, Vector3(0, 6, 8))
	see.step(1.0)
	assert_true(is_equal_approx(wall.transparency, SeeThrough.FADED))
	root.remove_child(see)
	assert_eq(wall.transparency, 0.0, "whole again with the view gone")
	see.free()
	root.queue_free()


## Marking says which pieces fade, once however often it is asked; smoke is left alone.
func test_marking_registers_the_pieces() -> void:
	var root := Node3D.new()
	var a := MeshInstance3D.new()
	a.mesh = BoxMesh.new()
	var b := MeshInstance3D.new()
	b.mesh = BoxMesh.new()
	a.add_child(b)
	var smoke := GPUParticles3D.new()
	root.add_child(a)
	root.add_child(smoke)
	SeeThrough.mark(root)
	SeeThrough.mark(root)
	assert_true(SeeThrough.marked(a) and SeeThrough.marked(b), "both fade")
	assert_false(SeeThrough.marked(smoke), "smoke doesn't")
	var floor := MeshInstance3D.new()
	assert_false(SeeThrough.marked(floor), "an unmarked mesh stays whole")
	floor.free()
	root.free()


## The window is gone: no shader the world draws with cuts a hole, and nothing draws the oval.
func test_no_shader_cuts_a_window_any_more() -> void:
	for sh: Shader in [Look.CEL_SHADER, Look.CEL_WORLD_SHADER, Look.LIT_SHADER, Look.LIT_WORLD_SHADER, ModelPiece.SPRITE_SHADER,
			load("res://shaders/world/amber.gdshader") as Shader]:
		assert_false(sh.code.contains("see_cut") or sh.code.contains("see_through.gdshaderinc"), "%s has no window" % sh.resource_path)
	assert_false(FileAccess.file_exists("res://shaders/world/see_through.gdshaderinc"), "the window's code is gone")


# --- Where the camera is on --------------------------------------------------------------------------------------

## The fade goes where the camera looks at the party: on the leader exploring, on whoever the camera follows in a fight,
## on a boss making an entrance; with no camera there's none.
func test_the_fade_follows_the_camera() -> void:
	var v := _view("tsolenka_pass_guard_tower")
	await _frames(2)
	var see := v.get_node_or_null("SeeThrough") as SeeThrough
	assert_true(see != null, "the view has its see-through")
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
	assert_eq(see.focus(), null, "no camera, none")
	see.free()


## The rest of the party is given to it while exploring (the feet of whoever is up), and none in a fight.
func test_the_view_gives_it_the_rest_of_the_party_exploring_only() -> void:
	var v := _view("tsolenka_pass_guard_tower")
	await _frames(2)
	var see := v.get_node_or_null("SeeThrough") as SeeThrough
	assert_true(see != null and see.also.is_valid(), "it has them")
	var feet := see.also.call() as Array
	assert_eq(feet.size(), v.members.size(), "all four exploring")
	v.in_combat = true
	assert_true((see.also.call() as Array).is_empty(), "none in a fight: the camera is on the one acting")
	v.in_combat = false
	v.queue_free()
	await _frames(1)
