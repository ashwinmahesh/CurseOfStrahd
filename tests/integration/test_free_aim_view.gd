extends TestCase
## Aiming a cone or Thunderwave on the board (owner, 2026-10-18: "For AoE spells like cone of cold, we should be able to
## aim them freely (not have it locked to certain boxes)"): the mouse points it at any angle, the stick does on a pad in
## one-degree steps, and the edge drawn and the creatures listed are what it would take.

var e: Encounter
var view: CombatView
var wizard: Combatant
var _root: Node3D


func _frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame


func _board() -> void:
	_root = Node3D.new()
	add_child(_root)
	var rows: Array = []
	for z in 16:
		rows.append("....................")
	e = TestCombat.encounter(rows)
	var ch := TestChars.custom("wizard", "human", 9)
	var prepared := (ch.spellcasting[0] as Dictionary)["prepared"] as Array
	for id: String in ["cone_of_cold", "burning_hands", "thunderwave"]:
		if not id in prepared:
			prepared.append(id)
	ch.finish_long_rest()
	wizard = e.add(ch, &"party", Vector2i(2, 12))
	# Three up and to the right of the wizard, one along its row where cones used to turn.
	for cell: Vector2i in [Vector2i(6, 9), Vector2i(9, 7), Vector2i(12, 6), Vector2i(12, 13)]:
		TestCombat.foe(e, "zombie", cell)
	TestCombat.start_with(e, wizard)
	var board := ArenaBoard.build(e.grid)
	_root.add_child(board)
	var tokens := {}
	for c in e.combatants:
		var token := CombatToken.create(c)
		token.position = board.cell_center(c.cell, c.size_cells)
		_root.add_child(token)
		tokens[c.id] = token
	var rig := CameraRig.new()
	_root.add_child(rig)
	view = CombatView.new()
	view.input_locked = true
	_root.add_child(view)
	view.begin(e, board, rig, tokens)
	await _frames(2)


func _aim(spell_id: String) -> void:
	view.mode = CombatView.Mode.IDLE
	view._choose(view.catalog.find(wizard, "spell:" + spell_id))


func _done() -> void:
	view._cancel_targeting()
	_root.queue_free()
	await _frames(1)


func _names(pv: Dictionary) -> Array:
	var out: Array = (pv["creatures"] as Array).map(func(w: Dictionary) -> String: return str(w["id"]))
	out.sort()
	return out


func _ids(cells: Array[Vector2i]) -> Array:
	var out: Array = e.spells.creatures_in(cells).map(func(o: Combatant) -> String: return o.id)
	out.sort()
	return out


func test_the_mouse_points_a_cone_at_any_angle() -> void:
	await _board()
	_aim("cone_of_cold")
	view.using_pad = false
	var want := Vector2.from_angle(deg_to_rad(-33.0))
	var at := e.center_of(wizard) + want * 6.0
	view.hover_world = Vector3(at.x, 0.0, at.y)
	view.hover_cell = Vector2i(floori(at.x), floori(at.y))
	view._update_hover()
	var dir: Vector2 = view._aim_dir(wizard)
	assert_true(dir.distance_to(want) < 0.0001, "straight at the pointer: %s" % dir)
	var s := Compendium.shared().spell_data("cone_of_cold")
	var pv := view.catalog.spell_preview(wizard, view.selected, view._aim_point(), dir, view.slot_level)
	assert_eq(pv["outline"], e.spells.targeting.area_outline(wizard, s, Vector2.INF, dir, view.slot_level), "the edge drawn is the cone's")
	assert_true(view.overlay.is_showing_outline(), "and it's drawn")
	assert_eq(_names(pv), _ids(e.spells.area_for(wizard, s, Vector2.INF, dir, view.slot_level)), "the ones listed are the ones it takes")
	assert_eq((pv["creatures"] as Array).size(), 3, "the three up and to the right, not the one along the row")
	# A hair off the row, it lies along it.
	view.hover_world = Vector3(e.center_of(wizard).x + 8.0, 0.0, e.center_of(wizard).y + 0.2)
	assert_eq(view._aim_dir(wizard), Vector2.RIGHT)
	await _done()


func test_thunderwave_turns_with_the_pointer() -> void:
	await _board()
	_aim("thunderwave")
	view.using_pad = false
	var want := Vector2.from_angle(deg_to_rad(-40.0))
	var at := e.center_of(wizard) + want * 3.0
	view.hover_world = Vector3(at.x, 0.0, at.y)
	view.hover_cell = Vector2i(floori(at.x), floori(at.y))
	view._update_hover()
	var dir: Vector2 = view._aim_dir(wizard)
	assert_true(dir.distance_to(want) < 0.0001, "no snapping to the diagonal: %s" % dir)
	await _done()


func test_the_stick_points_a_cone_in_one_degree_steps() -> void:
	await _board()
	_aim("cone_of_cold")
	var basis := view.rig.ground_basis()
	var want := Vector2.from_angle(deg_to_rad(-33.4))
	# The stick that points that way on the ground, given the camera's turn (the inverse of _pad_aim's mapping).
	var up := Vector2(basis[0].x, basis[0].z)
	var right := Vector2(basis[1].x, basis[1].z)
	var stick := Vector2(want.dot(right), -want.dot(up))
	view._pad_aim(wizard, stick, view.catalog.aim_ft(wizard, view.selected))
	var dir: Vector2 = view._aim_dir(wizard)
	assert_true(dir.distance_to(Vector2.from_angle(deg_to_rad(-33.0))) < 0.001, "-33.4 degrees on the stick: -33 (%s)" % rad_to_deg(dir.angle()))
	assert_true(e.grid.in_bounds(view.cursor_cell), "the cursor at its far end, on the board")
	var pv := view.catalog.spell_preview(wizard, view.selected, view._aim_point(), dir, view.slot_level)
	assert_eq((pv["creatures"] as Array).size(), 3)
	await _done()
