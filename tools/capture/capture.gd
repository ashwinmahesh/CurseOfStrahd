extends Node
## Loads a scene in a real window, waits, and saves screenshots (rendering needs a window).
## Args after --: --scene=res://... --out=/abs/path/prefix --frames=N [--size=1600x900]
## The window stays out of sight (make capture launches it so it never takes focus): it moves far off screen and the
## frames are drawn from here, since macOS stops drawing a window it can't see.
## If the scene has debug_move_leader(), a second shot is taken after walking the leader. A scene with
## capture_shots(tool, out) runs its own sequence instead (tool.wait_frames(n), tool._shot(path)).

func _ready() -> void:
	var args := {}
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--") and a.contains("="):
			args[a.substr(2, a.find("=") - 2)] = a.get_slice("=", 1)
	var scene_path := str(args.get("scene", "res://scenes/test/graybox_room.tscn"))
	var out := str(args.get("out", "user://capture"))
	var frames := int(args.get("frames", "90"))
	DirAccess.make_dir_recursive_absolute(out.get_base_dir())
	# make capture opens the window small in a corner; off screen it can take the capture size unseen.
	var win := get_window()
	win.borderless = true
	win.position = Vector2i(-20000, -20000)
	var size := str(args.get("size", "1600x900")).split("x")
	win.size = Vector2i(int(size[0]), int(size[1]))
	get_tree().process_frame.connect(_draw_unseen)
	var scene := (load(scene_path) as PackedScene).instantiate()
	add_child(scene)
	for i in frames:
		await get_tree().process_frame
	if scene.has_method("capture_shots"):
		# The scene drives its own sequence of shots (the combat arena: start, targeting, reactions, the end).
		await scene.call("capture_shots", self, out)
		get_tree().quit()
		return
	_shot(out + "_1.png")
	var focus := str(args.get("focus", ""))
	if focus != "":
		# Close-up on one node (e.g. --focus=villager), with shots spread around its walk.
		var cam_rig := scene.get("rig") as CameraRig
		cam_rig.follow = scene.get(focus) as Node3D
		cam_rig.distance = 7.0
		for i in 6:
			for f in frames / 2:
				await get_tree().process_frame
			_shot(out + "_focus_%d.png" % i)
		get_tree().quit()
		return
	if scene.has_method("debug_move_leader"):
		scene.call("debug_move_leader", Vector3(5.5, 0, -1.5))
		for i in frames * 2:
			await get_tree().process_frame
		_shot(out + "_2.png")
		var cam_rig := scene.get("rig") as CameraRig
		if cam_rig:
			cam_rig.rotate_step(1)
			for i in frames:
				await get_tree().process_frame
			_shot(out + "_3.png")
	get_tree().quit()


## The render loop skips a window macOS reports as not visible; draw it anyway (before this frame's shots are read).
func _draw_unseen() -> void:
	if not DisplayServer.window_can_draw():
		RenderingServer.force_draw(false, get_process_delta_time())


func wait_frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame


func _shot(path: String) -> void:
	var img := get_viewport().get_texture().get_image()
	img.save_png(path)
	print("capture: ", path)
