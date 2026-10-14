extends Node3D
## make capture SCENE=res://tools/capture/turn_order_capture.tscn NAME=turn_order FRAMES=10
## The combat HUD's turn order in a fight of 24 (owner, 2026-10-14: the order is wider than the screen): the first
## turn, a turn in the middle of the order, the last turn, the order scrolled by hand with both arrows showing, and a
## creature the pad looked at ringed in white; then a fight of six, whose order is the width it always was.

var e: Encounter
var view: CombatView
var rig: CameraRig
var heroes: Array[Combatant] = []


func _ready() -> void:
	InputActions.ensure()
	ModeController.force(ModeController.Mode.COMBAT)
	(load("res://world/combat/combat_arena.gd") as GDScript).build_environment(self)
	_fight(20)


## Four heroes and `foes` zombies on the open field, the first hero's turn.
func _fight(foes: int) -> void:
	if view != null:
		view.queue_free()
		rig.queue_free()
	e = TestCombat.open_field()
	heroes.clear()
	var ids := ["ilse_varga", "godrick_pendlebrook", "thistle", "tamsin_tealeaf"]
	for k in 4:
		heroes.append(TestCombat.hero(e, ids[k], Vector2i(2, 2 + k), 5))
	for k in foes:
		TestCombat.foe(e, "zombie", Vector2i(5 + k % 7, 1 + int(k / 7.0) * 2))
	TestCombat.start_with(e, heroes[0])
	var board := ArenaBoard.build(e.grid)
	add_child(board)
	var tokens := {}
	for c in e.combatants:
		var token := CombatToken.create(c)
		token.position = board.cell_center(c.cell, c.size_cells)
		add_child(token)
		tokens[c.id] = token
	rig = CameraRig.new()
	add_child(rig)
	rig.distance = 14.0
	rig.camera.current = true
	rig.camera.add_child(Look.make_post_process())
	view = CombatView.new()
	view.input_locked = true
	add_child(view)
	view.begin(e, board, rig, tokens)
	rig.snap_to_target()


func _turn(tool: Node, at: int) -> void:
	e.turn_index = at
	e._begin_turn()
	view.hud.refresh()
	await tool.call("wait_frames", 40)


func capture_shots(tool: Node, out: String) -> void:
	await tool.call("wait_frames", 60)
	tool.call("_shot", "%s_0_first_turn.png" % out)
	await _turn(tool, 12)
	tool.call("_shot", "%s_1_middle_turn.png" % out)
	await _turn(tool, e.order.size() - 1)
	tool.call("_shot", "%s_2_last_turn.png" % out)
	await _turn(tool, 0)
	var strip := view.hud.get("_strip_view") as TurnStrip
	if strip != null:
		strip.scroll_by(420.0, true)
		await tool.call("wait_frames", 10)
		tool.call("_shot", "%s_3_scrolled_by_hand.png" % out)
		view.hud.look_at(e.order[16].id)
		await tool.call("wait_frames", 50)
		tool.call("_shot", "%s_4_looked_at.png" % out)
	_fight(2)
	await tool.call("wait_frames", 60)
	tool.call("_shot", "%s_5_six.png" % out)
