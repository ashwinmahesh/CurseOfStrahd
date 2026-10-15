extends TestCase
## A fight can end while its view is still playing a beat of it: the story takes the fight back (and a story bot, which
## plays the whole fight on the encounter in one go and then ends it, does so all the time), and the caller frees the
## fight's tokens at once. The beat the view is on (an attack's lunge, then its hit) uses the attacker's and the
## defender's tokens when it resumes, so a defender freed under it was a script error ("Invalid type in function 'on_hit'
## in base 'Node3D (SpellFx)'. The Object-derived class of argument 2 (previously freed)", batch 291's logcheck, in the
## Vallaki faction fight of test_phase4_exit). The fight's foes now go when the view does.

var e: Encounter
var view: CombatView
var _root: Node3D


func _frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame


func _play_then(done: Array) -> void:
	await view._play_events()
	done[0] = true


func test_a_fight_ended_mid_attack_leaves_its_beat_the_tokens_it_uses() -> void:
	await _attack_then_end_the_fight(false)


## The foe is the attacker this time, felled as it strikes (a riposte, a reaction): the batch's error named the
## attacker's token.
func test_the_same_when_the_attacker_is_a_foe_that_falls_to_the_blow_after() -> void:
	await _attack_then_end_the_fight(true)


## `foe_strikes`: the foe attacks the hero; otherwise the hero kills the foe.
func _attack_then_end_the_fight(foe_strikes: bool) -> void:
	var rows: Array = []
	for z in 8:
		rows.append("............")
	e = TestCombat.encounter(rows)
	var hedda := TestCombat.hero(e, "hedda_ironvow", Vector2i(3, 4))
	var foe := TestCombat.foe(e, "scout", Vector2i(4, 4))
	TestCombat.hero(e, "ilse_varga", Vector2i(2, 6))
	TestCombat.start_with(e, foe if foe_strikes else hedda)
	_root = Node3D.new()
	add_child(_root)
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
	var waited := 0.0
	while view._opening and waited < 4.0:
		await get_tree().process_frame
		waited += get_process_delta_time()
	await view._play_events()
	var striker := foe if foe_strikes else hedda
	var struck := hedda if foe_strikes else foe
	if not foe_strikes:
		foe.creature.hp = 1   # the blow fells it
	TestCombat.next_d20(e, 20)
	var r := e.attack(striker, struck, str(e.attack_options(striker)[0]["id"]))
	assert_true(r.hit, "the blow lands")
	if foe_strikes:
		foe.creature.dead = true   # a riposte or a reaction felled the attacker as the blow landed
	assert_true(foe.creature.dead, "the scout is dead: it fell to the blow, or struck and fell to what answered it")
	var foe_token := tokens[foe.id] as CombatToken
	var striker_token := tokens[striker.id] as CombatToken
	var home := striker_token.position
	var done := [false]
	_play_then(done)
	# The attacker winds up and steps in on the blow: the story ends the fight in that step, with the view (which frees
	# itself a third of a second after it is closed) still there: its foes' tokens are disposed of and the view closed,
	# as LocationFights._end_encounter does.
	var frames := 0
	while striker_token.position.is_equal_approx(home) and frames < 240:
		await get_tree().process_frame
		frames += 1
	assert_true(frames < 240, "the attacker stepped in")
	LocationFights._drop_token(foe_token, view)
	view.close_softly()
	await get_tree().create_timer(1.6, true).timeout
	assert_true(bool(done[0]), "the beat finished (or gave up) with nothing freed under it")
	assert_false(is_instance_valid(foe_token), "and the foe's token went once the view had")
	_root.queue_free()
	await _frames(1)
