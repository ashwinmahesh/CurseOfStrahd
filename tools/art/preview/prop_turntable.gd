extends Node3D
## Art QA for how set-dressing pieces sit in the world (docs/art/set_dressing.md): a small lit room with furniture
## against its north wall and free-standing pieces in the middle, shot from the four camera headings, so a piece that
## turned with the camera instead of keeping its facing shows up at once. Not part of the game.
##   make capture SCENE=res://tools/art/preview/prop_turntable.tscn NAME=turntable FRAMES=20
## Godot args after --: --arts=a,b,c (the free-standing pieces) --wall=a,b,c (against the wall)

const ROWS := ["############", "#..........#", "#..........#", "#..........#", "#..........#", "#..........#", "############"]

var board: ArenaBoard
var rig: CameraRig


func _ready() -> void:
	InputActions.ensure()
	var stand := ["chest", "table_set", "bed", "cart_broken", "statue_saint", "settee", "pew", "signpost"]
	var wall := ["book_shelf", "wardrobe", "sideboard", "desk", "cabinet_glass"]
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--arts="):
			stand.assign(Array(a.get_slice("=", 1).split(",", false)))
		elif a.begins_with("--wall="):
			wall.assign(Array(a.get_slice("=", 1).split(",", false)))
	board = ArenaBoard.build(CombatGrid.from_rows(ROWS), "manor", "turntable")
	add_child(board)
	for i in wall.size():
		SetDressing.stand_piece(board, board, wall[i], Vector2i(1 + i * 2, 1))
	for i in stand.size():
		SetDressing.stand_piece(board, board, stand[i], Vector2i(1 + (i % 5) * 2, 3 + (i / 5) * 2))
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Look.color("ash_violet")
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Look.color("mist_blue")
	env.ambient_light_energy = 1.4
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)
	var sun := DirectionalLight3D.new()
	sun.light_color = Look.color("frost")
	sun.light_energy = 1.0
	sun.rotation_degrees = Vector3(-55, 35, 0)
	add_child(sun)
	rig = CameraRig.new()
	add_child(rig)
	rig.distance = 12.0
	rig.global_position = Vector3(6, 0, 3.5)
	rig.camera.current = true
	rig.camera.add_child(Look.make_post_process())
	rig.snap_to_target()


func capture_shots(tool: Node, out: String) -> void:
	for yaw in 4:
		rig.snap_to_target()
		await tool.call("wait_frames", 12)
		tool.call("_shot", out + "_yaw%d.png" % yaw)
		rig.rotate_step(1)
