extends TestCase
## Aiming a Line on the board (owner, 2026-10-12: "Allow aiming straight line spells (like lightning bolt) in any straight
## line (not just aligned with squares)"): the mouse points it at any angle and the stick does on a pad; a cone still
## takes the nearest of the eight directions.

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
	for z in 12:
		rows.append("................")
	e = TestCombat.encounter(rows)
	var ch := TestChars.custom("wizard", "human", 7)
	var prepared := (ch.spellcasting[0] as Dictionary)["prepared"] as Array
	for id: String in ["lightning_bolt", "burning_hands"]:
		if not id in prepared:
			prepared.append(id)
	ch.finish_long_rest()
	wizard = e.add(ch, &"party", Vector2i(3, 6))
	for cell: Vector2i in [Vector2i(8, 4), Vector2i(10, 3), Vector2i(13, 2), Vector2i(9, 6)]:
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


func test_the_mouse_points_a_line_at_any_angle() -> void:
	await _board()
	_aim("lightning_bolt")
	view.using_pad = false
	view.hover_world = Vector3(14.5, 0.0, 2.0)
	view.hover_cell = Vector2i(14, 2)
	view._update_hover()
	var dir: Vector2 = view._aim_dir(wizard)
	assert_true(dir.distance_to(Vector2(11, -4.5).normalized()) < 0.0001, "straight at the pointer: %s" % dir)
	var pv := view.catalog.spell_preview(wizard, view.selected, view._aim_point(), dir, view.slot_level)
	assert_eq((pv["creatures"] as Array).size(), 3, "the three zombies on the slant")
	assert_true(view.overlay.is_showing_outline(), "its edge drawn")
	_aim("burning_hands")
	var cone: Vector2 = view._aim_dir(wizard)
	assert_true(cone.distance_to(Vector2.RIGHT) < 0.0001, "a cone still snaps to the nearest of the eight: %s" % cone)
	view._cancel_targeting()
	_root.queue_free()
	await _frames(1)


func test_the_stick_points_a_line_at_any_angle() -> void:
	await _board()
	_aim("lightning_bolt")
	var basis := view.rig.ground_basis()
	var want := Vector2(11, -4.5).normalized()
	# The stick that points that way on the ground, given the camera's turn (the inverse of _pad_line_aim's mapping).
	var up := Vector2(basis[0].x, basis[0].z)
	var right := Vector2(basis[1].x, basis[1].z)
	var stick := Vector2(want.dot(right), -want.dot(up))
	view._pad_line_aim(wizard, stick, 100)
	var dir: Vector2 = view._aim_dir(wizard)
	assert_true(dir.distance_to(want) < 0.01, "the line points the way the stick does: %s" % dir)
	assert_true(e.grid.in_bounds(view.cursor_cell), "the cursor at its far end, on the board")
	var pv := view.catalog.spell_preview(wizard, view.selected, view._aim_point(), dir, view.slot_level)
	assert_eq((pv["creatures"] as Array).size(), 3)
	view._cancel_targeting()
	_root.queue_free()
	await _frames(1)
