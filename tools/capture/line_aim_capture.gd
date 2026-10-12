extends Node3D
## make capture SCENE=res://tools/capture/line_aim_capture.tscn NAME=line_aim/shot FRAMES=10
## A line spell aimed off the grid's eight directions (owner, 2026-10-12: "Allow aiming straight line spells (like
## lightning bolt) in any straight line (not just aligned with squares)"): a level 7 wizard's Lightning Bolt pointed at
## a slant through three zombies (<out>_1_lightning_bolt.png), the same pointed a little higher
## (<out>_2_lightning_bolt_steeper.png), and a 15-ft Burning Hands cone pointed the first way, which still snaps to the
## nearest of the eight (<out>_3_burning_hands.png).

var e: Encounter
var view: CombatView
var rig: CameraRig
var board: ArenaBoard
var wizard: Combatant
var _focus: Node3D


func _ready() -> void:
	InputActions.ensure()
	ModeController.force(ModeController.Mode.COMBAT)
	(load("res://world/combat/combat_arena.gd") as GDScript).build_environment(self)
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
	TestCombat.hero(e, "ilse_varga", Vector2i(2, 9), 6)
	for cell: Vector2i in [Vector2i(8, 4), Vector2i(10, 3), Vector2i(13, 2), Vector2i(9, 6), Vector2i(12, 6), Vector2i(11, 9)]:
		TestCombat.foe(e, "zombie", cell)
	TestCombat.start_with(e, wizard)
	board = ArenaBoard.build(e.grid)
	add_child(board)
	var tokens := {}
	for c in e.combatants:
		var token := CombatToken.create(c)
		token.position = board.cell_center(c.cell, c.size_cells)
		add_child(token)
		tokens[c.id] = token
	rig = CameraRig.new()
	add_child(rig)
	rig.distance = 21.0
	rig.camera.current = true
	rig.camera.add_child(Look.make_post_process())
	view = CombatView.new()
	view.input_locked = true
	add_child(view)
	view.begin(e, board, rig, tokens)
	_focus = Node3D.new()
	add_child(_focus)
	rig.snap_to_target()


func capture_shots(tool: Node, out: String) -> void:
	await tool.call("wait_frames", 120)
	# [spell, the point pointed at (x, z), file name]
	var shots: Array = [["lightning_bolt", Vector2(14.5, 2.0), "1_lightning_bolt"],
		["lightning_bolt", Vector2(12.0, 0.5), "2_lightning_bolt_steeper"], ["burning_hands", Vector2(14.5, 2.0), "3_burning_hands"]]
	for s: Array in shots:
		await _aim(tool, "%s_%s" % [out, str(s[2])], str(s[0]), s[1] as Vector2)


func _look_at(p: Vector2) -> void:
	_focus.position = Vector3(p.x, 0, p.y)
	rig.follow = _focus
	rig.snap_to_target()


## Aims `spell_id` from the wizard with the mouse at `point` and shoots the board as it draws it.
func _aim(tool: Node, name: String, spell_id: String, point: Vector2) -> void:
	e.turn_index = e.order.find(wizard)
	e._begin_turn()
	view.hud.shown = wizard
	view.hud.set_tab(ActionCatalog.SPELLS)
	view.hud.refresh()
	view.mode = CombatView.Mode.IDLE
	var a := view.catalog.find(wizard, "spell:" + spell_id)
	if a.is_empty() or not bool(a["legal"]):
		push_warning("line_aim_capture: %s can't be cast (%s)" % [spell_id, str(a.get("reason", "not known"))])
		return
	view._choose(a)
	view.using_pad = false
	view.hover_world = Vector3(point.x, 0.0, point.y)
	view.hover_cell = Vector2i(floori(point.x), floori(point.y))
	view._update_hover()
	_look_at(Vector2(11.0, 3.5))
	await tool.call("wait_frames", 20)
	tool.call("_shot", name + ".png")
	view._cancel_targeting()
