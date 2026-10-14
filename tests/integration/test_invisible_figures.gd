extends TestCase
## An Invisible foe leaves the board (owner, 2026-10-13: "Creatures that go invisible should disappear from the map
## unless the player character targeting them has invisibility"): its figure, ring and bar are off the map and its
## portrait off the turn order while the hero whose turn it is can't see it, it can't be picked with the pointer or the
## next-target key, an Invisible hero stays for its own player see-through, and it all comes back when the invisibility
## ends or the turn passes to a hero who sees it (CombatToken.set_unseen, CombatView._refresh_all, CombatHud._refresh_strip).

var e: Encounter
var view: CombatView
var wizard: Combatant
var hedda: Combatant
var scout: Combatant
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
	wizard = TestCombat.high_caster(e, ["polymorph"], Vector2i(3, 6))
	hedda = TestCombat.hero(e, "hedda_ironvow", Vector2i(5, 3))
	scout = TestCombat.foe(e, "scout", Vector2i(8, 6))
	TestCombat.foe(e, "zombie", Vector2i(11, 6))
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


func _done() -> void:
	_root.queue_free()
	await _frames(1)


func _strip_cards() -> int:
	return view.hud._strip.get_child_count()


func test_an_invisible_foe_leaves_the_map_and_the_order_bar_until_a_hero_sees_it() -> void:
	await _board()
	var tok := view.tokens[scout.id] as CombatToken
	var cards := _strip_cards()
	assert_true(tok.visible and not tok.unseen, "on the map to begin with")
	var fx := Effect.new("Invisible", &"spell", "greater_invisibility").with_condition(&"invisible")
	scout.creature.add_effect(fx)
	view._refresh_all()
	await _frames(2)
	assert_true(tok.unseen and not tok.visible, "off the map")
	assert_eq(_strip_cards(), cards - 1, "and off the turn order")
	# The pointer on its square finds no one.
	view.hover_token = null
	view.hover_cell = scout.cell
	assert_eq(view._target_under(), null, "nothing to click there")
	# Pointing along the ray through it doesn't pick it either.
	view.mode = CombatView.Mode.IDLE
	view._next_target()
	assert_ne(view.cursor_cell, scout.cell, "the next-target key skips it")
	# Another hero who can see it doesn't show it on the wizard's turn: the map follows whose turn it is.
	hedda.creature.add_effect(Effect.new("See Invisibility", &"spell", "see_invisibility").with_modifier("flag", {"value": "see_invisibility"}))
	view._refresh_all()
	assert_true(tok.unseen and not tok.visible, "still gone on the wizard's turn")
	# Her turn: it's on the map, and on the order bar again.
	e.turn_index = e.order.find(hedda)
	e._begin_turn()
	view._refresh_all()
	await _frames(2)
	assert_true(tok.visible and not tok.unseen, "on the map through Hedda's eyes")
	assert_eq(_strip_cards(), cards)
	# A foe's turn keeps the last hero's view; the wizard's turn takes it off again.
	e.turn_index = e.order.find(scout)
	e._begin_turn()
	view._refresh_all()
	assert_true(tok.visible, "a foe's turn keeps Hedda's view")
	e.turn_index = e.order.find(wizard)
	e._begin_turn()
	view._refresh_all()
	assert_true(tok.unseen, "the wizard's turn takes it off again")
	hedda.creature.effects.clear()
	scout.creature.remove_effect(fx)
	view._refresh_all()
	assert_true(tok.visible and not tok.unseen, "visible again once the invisibility is gone")
	await _done()


func test_an_invisible_hero_stays_on_the_map_see_through_for_its_player() -> void:
	await _board()
	var tok := view.tokens[hedda.id] as CombatToken
	assert_true(is_equal_approx(tok.sprite.modulate.a, 1.0))
	hedda.creature.add_effect(Effect.new("Invisible", &"spell", "greater_invisibility").with_condition(&"invisible"))
	view._refresh_all()
	assert_true(tok.visible and not tok.unseen, "her own side is never taken off the map")
	assert_true(is_equal_approx(tok.sprite.modulate.a, 0.5), "but drawn half there: %.2f" % tok.sprite.modulate.a)
	await _done()


func test_the_invisibility_spell_taking_hold_shows_in_the_view_at_once() -> void:
	await _board()
	var spells := TestCombat.high_caster(e, ["invisibility"], Vector2i(2, 8))
	var tok := view.tokens[scout.id] as CombatToken
	var fx := Effect.new("Invisible", &"spell", "invisibility").with_condition(&"invisible")
	scout.creature.add_effect(fx)
	e.events.append({"type": "condition", "id": scout.id})
	await view._play_events()
	assert_true(tok.unseen, "the condition event takes it off the map")
	assert_ne(spells, null)
	await _done()
