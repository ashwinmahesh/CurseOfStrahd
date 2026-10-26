extends TestCase
## Eldritch Blast's beams on the board (Ashwin, 2026-10-21 to 24): every beam of the cast shows its own missile and makes its
## own sound, also when Repelling Blast or Grasp of Hadar moves the target between one beam and the next (the push used to
## end the spell's volley, so the later beams showed no missile at all), and the creature that was pushed is still on the map.

var e: Encounter
var view: CombatView
var kip: Combatant
var foe: Combatant
var _root: Node3D


func _frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame


## Kip (a warlock at `level`, Repelling Blast on) 5 squares from a zombie that has Hit Points to spare.
func _board(level: int = 11, wizard: bool = false) -> void:
	_root = Node3D.new()
	add_child(_root)
	var rows: Array = []
	for z in 12:
		rows.append("....................")
	e = TestCombat.encounter(rows)
	kip = TestCombat.high_caster(e, ["scorching_ray"], Vector2i(3, 6)) if wizard else TestCombat.hero(e, "kip_smudgewick", Vector2i(3, 6), level)
	foe = TestCombat.foe(e, "zombie", Vector2i(8, 6))
	foe.creature.hp = 900
	TestCombat.start_with(e, kip)
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


func _cast_and_play() -> void:
	TestCombat.next_d20(e, 19)
	var r := e.spells.cast(kip, "eldritch_blast", 0, [foe])
	assert_true(r.ok, r.reason)
	await view._play_events()
	await _frames(2)


func _beams() -> int:
	return e.spells.specials.beams(kip)


func _rule(id: String, mode: String) -> void:
	var cat := ActionCatalog.new(e)
	assert_true(cat.set_rule(kip, cat.find(kip, "feat:reaction_policy:%s:%s" % [id, mode])).ok, "%s %s" % [id, mode])


func test_every_beam_flies_when_repelling_blast_pushes_between_them() -> void:
	await _board()
	assert_eq(_beams(), 3, "three beams at level 11")
	await _cast_and_play()
	assert_true(foe.cell.x > 8, "the zombie was pushed: %s" % foe.cell)
	assert_eq(view.fx.missiles_flown, 3, "a missile for each beam, the push between them or not")
	_root.queue_free()
	await _frames(1)


func test_every_beam_flies_with_no_push_at_all() -> void:
	await _board()
	_rule("repelling_blast", "never")
	await _cast_and_play()
	assert_eq(foe.cell, Vector2i(8, 6), "nothing moved it")
	assert_eq(view.fx.missiles_flown, 3)
	_root.queue_free()
	await _frames(1)


func test_the_pushed_creature_is_still_on_the_board() -> void:
	await _board()
	await _cast_and_play()
	var tok := view.tokens[foe.id] as CombatToken
	assert_true(tok.visible and tok.sprite.visible, "its figure is showing")
	assert_true(tok.position.distance_to(view.board.cell_center(foe.cell, foe.size_cells)) < 0.05, "standing on the square it was pushed to")
	_root.queue_free()
	await _frames(1)


## Every spell that rolls an attack for each ray works the same way (Ashwin, 2026-10-21: "and other multi-attack spells"):
## Scorching Ray's three rays at its own level, four from a level 3 slot, each with its own missile.
func test_scorching_rays_each_fly_a_missile() -> void:
	await _board(7, true)
	TestCombat.next_d20(e, 19)
	var r := e.spells.cast(kip, "scorching_ray", 2, [foe, foe, foe])
	assert_true(r.ok, r.reason)
	await view._play_events()
	await _frames(2)
	assert_eq(view.fx.missiles_flown, 3, "a missile for each of the three rays")
	_root.queue_free()
	await _frames(1)
