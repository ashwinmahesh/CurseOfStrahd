extends TestCase
## A polymorphed creature's figure on the board (owner, 2026-10-13: "When an enemy or character is polymorphed, their
## sprite should reflect their transformed shape"): the token wears the Beast's sprite, at the Beast's height and size,
## facing the way it faced, and its own figure comes back when the shape ends, whether its Temporary Hit Points ran
## out, it dropped, or the caster's Concentration broke (ShapeChange's "shape" events, CombatView._swap_shape_art).

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


## The board goes once the spell's effects have played out.
func _done() -> void:
	await get_tree().create_timer(1.5).timeout
	_root.queue_free()
	await _frames(1)


func _wears(tok: CombatToken, art: String) -> bool:
	return tok != null and tok.sprite != null and tok.sprite.sprite_frames == DirectionalSprite.frames_for(art)


func test_a_polymorphed_foe_wears_the_beast_and_its_own_figure_when_the_beast_falls() -> void:
	await _board()
	var own_art := CombatToken.art_id(scout)
	var before := view.tokens[scout.id] as CombatToken
	assert_true(_wears(before, own_art), "the scout as drawn")
	before.sprite.facing = Vector3.LEFT
	TestCombat.next_d20(e, 1)
	assert_true(e.spells.cast(wizard, "polymorph", 4, [scout], Vector2.INF, Vector2.ZERO, {"choice": "rat"}).ok)
	await view._play_events()
	var rat := view.tokens[scout.id] as CombatToken
	assert_true(rat != before, "a new figure")
	assert_true(_wears(rat, "rat"), "the rat's sprite")
	assert_true(is_equal_approx(rat._label.position.y, CombatToken.height_for("rat") + 0.25), "its name over a rat's height")
	assert_eq(rat.sprite.facing, Vector3.LEFT, "facing the way the scout faced")
	assert_eq(rat.scale, Vector3.ONE)
	# Its Temporary Hit Points run out: the spell ends and the scout is back.
	e.deal_damage(wizard, scout, [{"amount": scout.creature.temp_hp + 1, "type": "force"}], false, "test")
	assert_false(e.shapes.is_shaped(scout))
	await view._play_events()
	var back := view.tokens[scout.id] as CombatToken
	assert_true(back != rat and _wears(back, own_art), "the scout's own figure again")
	assert_eq(back.scale, Vector3.ONE)
	await _done()


func test_a_polymorphed_hero_is_a_big_beast_until_the_casters_concentration_breaks() -> void:
	await _board()
	var own := view.tokens[hedda.id] as CombatToken
	assert_true(e.spells.cast(wizard, "polymorph", 4, [hedda]).ok, "an ally: no save, the strongest form")
	assert_true(e.shapes.is_shaped(hedda))
	var form := str((hedda.creature as Monster).data["id"])
	await view._play_events()
	var beast := view.tokens[hedda.id] as CombatToken
	assert_true(beast != own and _wears(beast, form), "Hedda as the %s" % form)
	assert_false(own.visible, "her own figure waits, hidden")
	assert_eq(beast.scale, Vector3.ONE, "built at the beast's size, not scaled again")
	assert_true(beast.position.is_equal_approx(view.board.cell_center(hedda.cell, hedda.size_cells)), "standing over its squares")
	assert_true(is_equal_approx(beast._label.position.y, CombatToken.height_for(form) + 0.25), "its name over the beast")
	wizard.creature.concentration.end("test")
	assert_false(e.shapes.is_shaped(hedda))
	await view._play_events()
	assert_eq(view.tokens[hedda.id], own, "her own figure is back")
	assert_true(own.visible)
	assert_eq(own.scale, Vector3.ONE, "at her own size")
	assert_true(own.position.is_equal_approx(view.board.cell_center(hedda.cell, 1)))
	await _frames(1)
	assert_false(is_instance_valid(beast) and beast.is_inside_tree() and beast.visible, "the beast's figure is gone")
	await _done()


func test_a_foe_that_drops_in_its_beast_shape_falls_as_itself() -> void:
	await _board()
	var own_art := CombatToken.art_id(scout)
	TestCombat.next_d20(e, 1)
	assert_true(e.spells.cast(wizard, "polymorph", 4, [scout], Vector2.INF, Vector2.ZERO, {"choice": "rat"}).ok)
	await view._play_events()
	e.deal_damage(wizard, scout, [{"amount": scout.creature.temp_hp + scout.creature.hp + 5, "type": "force"}], false, "test")
	assert_true(scout.creature.dead, "the scout is slain")
	await view._play_events()
	assert_true(_wears(view.tokens[scout.id] as CombatToken, own_art), "it lies as the scout")
	await _done()
