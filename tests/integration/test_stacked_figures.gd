extends TestCase
## Foes sharing a square (owner, 2026-10-19): creatures standing in one square each stand a little to one side, the mouse
## points at the figure it is over, and on a controller the next-target button (and the cursor staying put) walks through
## everyone there; a tooltip says who else shares the square, and an Invisible foe in it neither shows nor shifts the
## others (CombatView._stack_at, _hover_on_stack, _stack_note, _share_offset, _next_target).

var e: Encounter
var view: CombatView
var hedda: Combatant
var a: Combatant
var b: Combatant
var far: Combatant
var scout: Combatant
var _root: Node3D

const STACK := Vector2i(8, 3)


func _frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame


func _board() -> void:
	_root = Node3D.new()
	add_child(_root)
	var rows: Array = []
	for z in 10:
		rows.append("................")
	e = TestCombat.encounter(rows)
	e.default_player_reaction = "never"
	hedda = TestCombat.hero(e, "hedda_ironvow", Vector2i(3, 3), 5)
	a = TestCombat.foe(e, "zombie", STACK)
	b = TestCombat.foe(e, "zombie", STACK)
	far = TestCombat.foe(e, "zombie", Vector2i(12, 7))
	scout = TestCombat.foe(e, "scout", Vector2i(8, 6))
	TestCombat.start_with(e, hedda)
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


func _done() -> void:
	_root.queue_free()
	await _frames(1)


func _hide(c: Combatant) -> Effect:
	var fx := Effect.new("Invisible", &"spell", "greater_invisibility").with_condition(&"invisible")
	c.creature.add_effect(fx)
	view._refresh_all()
	return fx


func test_creatures_in_one_square_stand_side_by_side_and_can_be_told_apart() -> void:
	await _board()
	var here := view._stack_at(STACK)
	assert_eq(here.size(), 2, "both zombies are in the square")
	assert_true(a in here and b in here)
	var pa := view._token_spot(a, STACK)
	var pb := view._token_spot(b, STACK)
	assert_true(pa.distance_to(pb) > 0.3, "each stands a little to one side")
	assert_eq(view._stack_at(Vector2i(3, 3)).size(), 1, "a lone hero is a stack of one")
	assert_eq(view._stack_at(Vector2i(0, 0)).size(), 0)
	await _done()


func test_the_next_target_button_walks_through_everyone_in_a_shared_square() -> void:
	await _board()
	view.mode = CombatView.Mode.IDLE
	var seen: Array[Combatant] = []
	for i in 4:
		view._next_target()
		assert_true(view.hover_token != null, "the cursor lands on a figure")
		var who := view.hover_token.combatant
		assert_eq(view.cursor_cell, who.cell, "and on its square")
		seen.append(who)
	# Four foes in the fight (scout too): each press is the next, and the first is back after the fourth.
	var ids := {}
	for c in seen:
		ids[c.id] = true
	assert_eq(ids.size(), 4, "four different creatures in four presses (the shared pair among them)")
	assert_true(a in seen and b in seen, "both of the pair were reached, not the first one twice")
	await _done()


func test_the_cursor_keeps_its_figure_while_it_stays_on_the_square() -> void:
	await _board()
	view.cursor_cell = STACK
	view._pad_hover(b)
	assert_eq(view.hover_token.combatant, b, "the one asked for")
	view._pad_hover()
	assert_eq(view.hover_token.combatant, b, "and it stays there")
	view.cursor_cell = Vector2i(9, 3)
	view._pad_hover()
	assert_eq(view.hover_token, null, "an empty square has no one")
	view.cursor_cell = STACK
	view._pad_hover()
	assert_eq(view.hover_token.combatant, a, "back on the square: the first")
	await _done()


func test_an_invisible_foe_in_the_square_neither_shows_nor_shifts_the_others() -> void:
	await _board()
	scout.cell = STACK
	view._refresh_all()
	assert_eq(view._stack_at(STACK).size(), 3, "all three seen")
	_hide(scout)
	var here := view._stack_at(STACK)
	assert_false(scout in here, "the unseen one isn't in the stack")
	assert_eq(here.size(), 2)
	view.mode = CombatView.Mode.IDLE
	for i in 6:
		view._next_target()
		assert_ne(view.hover_token.combatant, scout, "the next-target button skips it")
	# Alone with it, a visible foe doesn't stand aside for it (that would give it away).
	b.cell = Vector2i(2, 7)
	view._refresh_all()
	assert_eq(view._share_offset(a, STACK), Vector3.ZERO, "no nudge for an Invisible neighbour")
	await _done()


func test_a_tooltip_says_who_else_shares_the_square() -> void:
	await _board()
	var note := view._stack_note(a)
	assert_eq(note.size(), 1)
	assert_true(str(note[0]).begins_with("Shares the square with %s" % b.name()), str(note[0]))
	assert_true(str(note[0]).contains("for the next"), str(note[0]))
	assert_eq(view._stack_note(far).size(), 0, "nothing for a creature alone")
	await _done()
