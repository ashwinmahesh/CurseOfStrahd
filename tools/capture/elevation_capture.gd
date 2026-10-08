extends Node3D
## make capture SCENE=res://tools/capture/elevation_capture.tscn NAME=elevation FRAMES=10
## Natural ground in a fight (owner, 2026-10-08): a grassy slope up to a ledge of high ground 20 ft up, with a cliff on
## its south side. Ilse's walk up the slope (the trail and ring lie along it), then, from the edge, the square below
## offers "Jump down", and she jumps and takes the fall.

var e: Encounter
var ilse: Combatant
var view: CombatView
var rig: CameraRig
var board: ArenaBoard


func _ready() -> void:
	InputActions.ensure()
	ModeController.force(ModeController.Mode.COMBAT)
	(load("res://world/combat/combat_arena.gd") as GDScript).build_environment(self)
	var rows: Array[String] = []
	var elevation: Array[String] = []
	for z in 10:
		rows.append("#..........#" if z != 1 else "#.......#..#")
		elevation.append("000112344444" if z <= 4 else "000000000000")
	e = TestCombat.encounter(rows)
	e.grid.apply_elevation(elevation)
	ilse = TestCombat.hero(e, "ilse_varga", Vector2i(2, 3))
	TestCombat.foe(e, "zombie", Vector2i(10, 8))
	TestCombat.start_with(e, ilse)
	board = ArenaBoard.build(e.grid, "forest")
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


func capture_shots(tool: Node, out: String) -> void:
	await tool.call("wait_frames", 150)
	_frame()
	# Up the slope: the trail and the ring where she'd stop lie along the ground.
	view.hover_cell = Vector2i(7, 4)
	view._update_hover()
	await tool.call("wait_frames", 30)
	tool.call("_shot", out + "_1_up_the_slope.png")
	view._confirm_at()
	await tool.call("wait_frames", 150)
	print("elevation capture: Ilse at %s, %d ft up, %d ft of movement left" % [str(ilse.cell), e.grid.height(ilse.cell),
		ilse.movement_left])
	# The square below the cliff offers the jump.
	var below := Vector2i(8, 5)
	var shown: Array[Dictionary] = []
	for it in view.catalog.square_actions(ilse, below):
		shown.append({"id": it["id"], "label": it["label"], "enabled": it.get("enabled", true), "why": it.get("why", "")})
	view.hud.open_square_menu("This square", shown, rig.camera.unproject_position(board.cell_center(below)))
	print("elevation capture: menu %s" % [shown.map(func(d: Dictionary) -> String: return str(d["label"]))])
	await tool.call("wait_frames", 20)
	tool.call("_shot", out + "_2_jump_down_offered.png")
	view.hud._menu.hide()
	var hp := ilse.creature.hp
	# Picked from the square menu, as a click would.
	view._menu_cell = below
	view._menu_items = view.catalog.square_actions(ilse, below)
	view._square_picked("act:jump_down:%d:%d" % [below.x, below.y])
	await tool.call("wait_frames", 150)
	print("elevation capture: Ilse at %s, %d damage" % [str(ilse.cell), hp - ilse.creature.hp])
	tool.call("_shot", out + "_3_after_the_jump.png")


## The camera from the south-west, over the slope to the ledge and the cliff below it.
func _frame() -> void:
	rig.follow = null
	rig.position = board.cell_center(Vector2i(6, 4), 1)
	rig.distance = 15.0
