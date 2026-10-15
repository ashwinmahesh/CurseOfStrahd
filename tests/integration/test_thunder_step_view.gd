extends TestCase
## Aiming Thunder Step and Far Step on the board: the hotbar asks for a square; Thunder Step also draws the boom's edge
## round the space the caster would leave and lists who it would catch in the area panel; once the square is picked, a
## willing ally within 5 ft can be picked to come along (a click, or the next-target key and A on a pad; Y goes alone).

var e: Encounter
var view: CombatView
var wizard: Combatant
var buddy: Combatant
var foe: Combatant
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
	wizard = TestCombat.caster_with(e, ["thunder_step", "far_step"], Vector2i(3, 6))
	buddy = TestCombat.hero(e, "ilse_varga", Vector2i(4, 6))
	foe = TestCombat.foe(e, "zombie", Vector2i(3, 8))
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


func _point_at(cell: Vector2i) -> void:
	view.using_pad = false
	view.hover_world = view.board.cell_center(cell)
	view.hover_cell = cell
	view.hover_token = null
	var o := e.occupant_at(cell)
	if o != null:
		view.hover_token = view.tokens.get(o.id) as CombatToken
	view._update_hover()


func test_pointing_at_a_square_draws_the_boom_round_where_the_caster_stands() -> void:
	await _board()
	_aim("thunder_step")
	assert_eq(str(view.selected["targeting"]), "place")
	_point_at(Vector2i(12, 3))
	assert_true(view.overlay.is_showing_outline(), "the boom's edge, round the caster's square, not the landing")
	assert_true(view.hud._area_panel.visible, "who it would catch, in the area panel")
	view._cancel_targeting()
	assert_false(view.overlay.is_showing_outline(), "gone when the aim is called off")
	_root.queue_free()
	await _frames(1)


func test_far_step_has_no_boom_to_draw() -> void:
	await _board()
	_aim("far_step")
	_point_at(Vector2i(10, 3))
	assert_false(view.overlay.is_showing_outline())
	assert_false(view.hud._area_panel.visible)
	view._cancel_targeting()
	_root.queue_free()
	await _frames(1)


func test_picking_the_square_asks_who_comes_along_and_a_pad_can_answer() -> void:
	await _board()
	_aim("thunder_step")
	_point_at(Vector2i(12, 3))
	view._confirm_target(wizard, null)
	assert_true(view.picker.active(), "a willing ally beside the caster: asked")
	assert_eq(view.picker.step, "companion")
	assert_eq(view.mode, CombatView.Mode.TARGET)
	assert_eq(wizard.cell, Vector2i(3, 6), "nothing has happened yet")
	assert_true(view.overlay.is_showing_outline(), "the boom's edge stays while asking")
	# The next-target key goes to the ally who could come, not to the foe.
	view._next_target()
	assert_eq(view.cursor_cell, buddy.cell, "the ally")
	# Backing out picks another square.
	assert_true(view._undo_pick())
	assert_false(view.picker.active())
	assert_eq(view.mode, CombatView.Mode.TARGET)
	view._cancel_targeting()
	_root.queue_free()
	await _frames(1)


func test_with_nobody_to_bring_there_is_nobody_to_ask() -> void:
	await _board()
	buddy.cell = Vector2i(9, 9)   # out of reach
	_aim("thunder_step")
	assert_false(view.picker.bring_along(wizard, view.selected, Vector2(12.5, 3.5), view.slot_level), "the cast goes ahead as it is")
	assert_false(view.picker.active())
	view._cancel_targeting()
	_root.queue_free()
	await _frames(1)


func test_dimension_door_asks_the_same_way() -> void:
	await _board()
	_aim("dimension_door")
	_point_at(Vector2i(12, 3))
	view._confirm_target(wizard, null)
	assert_true(view.picker.active(), "a willing ally beside the caster: asked")
	assert_eq(view.picker.step, "companion")
	view._next_target()
	assert_eq(view.cursor_cell, buddy.cell, "the ally")
	assert_true(view._undo_pick())
	view._cancel_targeting()
	_root.queue_free()
	await _frames(1)
