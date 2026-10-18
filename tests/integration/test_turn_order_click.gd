extends TestCase
## A click on a portrait in the turn order is the order's alone (owner, 2026-10-18: "When i click on the character in the
## initiative in combat to switch (if players are adjacent), the character I switch to also moves to the spot under where
## the mouse when clicking the character portrait"): it takes the hero's share of the turn, or looks at whoever it is,
## and the board never reads it as a click on the square behind the card.

## What hover_cell holds until the board reads a click (CombatView._pick_from_mouse resets it).
const UNTOUCHED := Vector2i(-7, -7)

var e: Encounter
var view: CombatView
var ilse: Combatant
var godrick: Combatant
var zombie: Combatant
var _root: Node3D


func _frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame


## Ilse and Godrick next to each other in the order, so they share the turn (Ilse's first), then a zombie; the board
## and its HUD on screen, taking input.
func _board() -> void:
	_root = Node3D.new()
	add_child(_root)
	var rows: Array = []
	for z in 12:
		rows.append("................")
	e = TestCombat.encounter(rows)
	ilse = TestCombat.hero(e, "ilse_varga", Vector2i(3, 6), 5)
	godrick = TestCombat.hero(e, "godrick_pendlebrook", Vector2i(3, 8), 5)
	zombie = TestCombat.foe(e, "zombie", Vector2i(12, 6))
	e.start()
	while e.pending != null:
		e.answer_reaction(false)
	for pair: Array in [[ilse, 30], [godrick, 29], [zombie, 28]]:
		(pair[0] as Combatant).initiative = int(pair[1])
	e.order.sort_custom(func(a: Combatant, b: Combatant) -> bool: return a.initiative > b.initiative)
	e.shared.clear()
	e.shared_started.clear()
	e.shared_ended.clear()
	e.turn_index = 0
	e._begin_turn()
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
	_root.add_child(view)
	view.begin(e, board, rig, tokens)
	# The fight's opening plays out first (the view is busy till then, and takes no clicks).
	for i in 900:
		if view.mode == CombatView.Mode.IDLE:
			break
		await _frames(1)
	await _frames(2)


func _click(at: Vector2) -> void:
	for down: bool in [true, false]:
		var ev := InputEventMouseButton.new()
		ev.button_index = MOUSE_BUTTON_LEFT
		ev.pressed = down
		ev.position = at
		ev.global_position = at
		get_viewport().push_input(ev, true)
	await _frames(2)


func _card(c: Combatant) -> Control:
	var strip := view.hud.get("_strip_view") as TurnStrip
	return (strip.get("_cards") as Dictionary).get(c.id) as Control


func _done() -> void:
	view.input_locked = true
	_root.queue_free()
	await _frames(1)


func test_a_click_on_a_portrait_takes_the_turn_and_no_square() -> void:
	await _board()
	assert_eq(view.mode, CombatView.Mode.IDLE, "the board waits for the player")
	assert_eq(e.shared_heroes(), [ilse, godrick] as Array[Combatant], "the two share the turn")
	var card := _card(godrick)
	assert_true(card != null and card.is_visible_in_tree(), "Godrick's card in the order")
	if card == null:
		await _done()
		return
	var from := godrick.cell
	view.hover_cell = UNTOUCHED
	await _click(card.get_global_rect().get_center())
	assert_eq(e.current(), godrick, "the click takes Godrick's share of the turn")
	assert_eq(godrick.cell, from, "and he stays where he stood")
	assert_eq(view.hover_cell, UNTOUCHED, "the board never read the click")
	await _done()


func test_a_click_on_a_foes_portrait_only_looks_at_it() -> void:
	await _board()
	var card := _card(zombie)
	assert_true(card != null, "the zombie's card in the order")
	if card == null:
		await _done()
		return
	var from := ilse.cell
	view.hover_cell = UNTOUCHED
	await _click(card.get_global_rect().get_center())
	assert_eq(e.current(), ilse, "still Ilse's turn")
	assert_eq(ilse.cell, from, "and she hasn't moved")
	assert_eq(view.hover_cell, UNTOUCHED, "the board never read the click")
	await _done()
