extends Node3D
## make capture SCENE=res://tools/capture/flight_capture.tscn NAME=flight FRAMES=10
## F4 part 2, flying with a height off the floor: Silvain casts Fly and rises 15 ft out of a zombie's reach (it swings
## as he leaves), then flies over a low wall; a wraith hovers 15 ft up. Each creature in the air has a dark disc on the
## floor under it, and the HUD's chips say how high it is.

var e: Encounter
var silvain: Combatant
var view: CombatView
var rig: CameraRig
var board: ArenaBoard


func _ready() -> void:
	InputActions.ensure()
	ModeController.force(ModeController.Mode.COMBAT)
	(load("res://world/combat/combat_arena.gd") as GDScript).build_environment(self)
	var rows: Array[String] = []
	for z in 8:
		rows.append(".....=......" if z >= 1 and z <= 5 else "............")
	e = TestCombat.encounter(rows)
	silvain = TestCombat.caster_with(e, ["fly"], Vector2i(3, 3))
	TestCombat.foe(e, "zombie", Vector2i(4, 3))
	var wraith := TestCombat.foe(e, "wraith", Vector2i(9, 2))
	wraith.altitude = 15
	TestCombat.start_with(e, silvain)
	board = ArenaBoard.build(e.grid)
	add_child(board)
	var tokens := {}
	for c in e.combatants:
		var token := CombatToken.create(c)
		token.position = board.cell_center(c.cell, c.size_cells) + Vector3(0, c.altitude / float(CombatGrid.FEET), 0)
		add_child(token)
		tokens[c.id] = token
	rig = CameraRig.new()
	add_child(rig)
	rig.distance = 12.0
	rig.camera.current = true
	rig.camera.add_child(Look.make_post_process())
	view = CombatView.new()
	view.input_locked = true
	add_child(view)
	view.begin(e, board, rig, tokens)
	rig.snap_to_target()


func capture_shots(tool: Node, out: String) -> void:
	await tool.call("wait_frames", 150)
	var r := e.spells.cast(silvain, "fly", 3, [silvain])
	print("flight capture: Fly %s" % ("cast" if r.ok else r.reason))
	view._refresh_all()
	_frame()
	# Up 15 ft from the hotbar's Fly up, 5 ft at a time; the zombie swings as he leaves its reach.
	for i in 3:
		view._perform(view.catalog.find(silvain, "fly:up"), [], Vector2.INF, Vector2.ZERO)
		await tool.call("wait_frames", 60)
	print("flight capture: Silvain %d ft up, %d ft of movement left" % [silvain.altitude, silvain.movement_left])
	tool.call("_shot", out + "_1_up_out_of_reach.png")
	# Over the low wall, keeping his height.
	view.hover_cell = Vector2i(7, 3)
	view._confirm_at()
	await tool.call("wait_frames", 120)
	print("flight capture: Silvain at %s, %d ft up" % [str(silvain.cell), silvain.altitude])
	_frame()
	await tool.call("wait_frames", 20)
	tool.call("_shot", out + "_2_over_the_wall.png")


## The camera across the low wall, from the zombie to the wraith.
func _frame() -> void:
	rig.follow = null
	rig.position = board.cell_center(Vector2i(6, 3), 1)
	rig.distance = 13.0
