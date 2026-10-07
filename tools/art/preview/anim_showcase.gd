extends Node3D
## Before/after of the fuller animation set (docs/art/animation.md): the old sheets of one character on the left
## (art/sprites/<id>_before, a copy of the earlier sheets made for the comparison) and the new ones on the right, under
## the game's camera and screen pass, through idle, walk, attack, a hit and a fall; then the new poses alone (riding a
## mount, sneaking, casting). Recorded with Godot's movie writer:
##   tools/godot --path . --write-movie out.avi --fixed-fps 30 --resolution 1280x720 \
##     res://tools/art/preview/anim_showcase.tscn -- --id=godrick_pendlebrook --mount=otherworldly_steed

const HEIGHT := 1.5

var rig: CameraRig
var before: DirectionalSprite
var after: DirectionalSprite
var mount: DirectionalSprite
var title: Label
var tags: Array[Label3D] = []
var _lying: Sprite3D
var _id := "godrick_pendlebrook"
var _mount_id := "otherworldly_steed"
## --labels=Before,After names the two figures; --short stops after walking and attacking (a frames comparison).
var _labels: Array[String] = ["Before", "After"]
var _short := false


func _ready() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--id="):
			_id = a.substr(5)
		elif a.begins_with("--mount="):
			_mount_id = a.substr(8)
		elif a.begins_with("--labels="):
			_labels.assign(a.substr(9).split(","))
		elif a == "--short":
			_short = true
	var env := WorldEnvironment.new()
	env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_COLOR
	env.environment.background_color = Look.color("void")
	add_child(env)
	var ground := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(40, 40)
	ground.mesh = pm
	ground.material_override = Look.cel("grave")
	add_child(ground)
	var line := Node3D.new()
	line.rotation.y = deg_to_rad(45.0)
	add_child(line)
	before = _sprite(_id + "_before", Vector3(-1.4, 0, 0), line)
	after = _sprite(_id, Vector3(1.4, 0, 0), line)
	_lying = Sprite3D.new()
	_lying.texture = before.sprite_frames.get_frame_texture(&"idle_s", 0)
	_lying.pixel_size = before.pixel_size
	DirectionalSprite.setup_material(_lying)
	_lying.rotation_degrees = Vector3(-90, 0, -90)
	_lying.position = before.position + Vector3(0, 0.03, 0)
	_lying.visible = false
	line.add_child(_lying)
	tags.append(_tag(_labels[0], before.position, line))
	tags.append(_tag(_labels[1], after.position, line))
	rig = CameraRig.new()
	add_child(rig)
	rig.distance = 6.5
	rig.snap_to_target()
	add_child(Look.make_post_process())
	var ui := CanvasLayer.new()
	ui.layer = 20
	add_child(ui)
	title = Label.new()
	title.position = Vector2(0, 24)
	title.size = Vector2(1280, 60)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 36)
	title.add_theme_color_override("font_color", Look.color("vellum"))
	title.add_theme_color_override("font_outline_color", Look.color("void"))
	title.add_theme_constant_override("outline_size", 8)
	ui.add_child(title)
	_run()


func _sprite(id: String, at: Vector3, parent: Node3D) -> DirectionalSprite:
	var s := DirectionalSprite.create(DirectionalSprite.frames_for(id), HEIGHT)
	s.position = at
	s.set_step_time(0.18)
	parent.add_child(s)
	return s


func _tag(text: String, at: Vector3, parent: Node3D) -> Label3D:
	var l := Label3D.new()
	l.text = text
	l.font_size = 28 if _short else 40
	l.pixel_size = 0.006
	l.position = at + Vector3(0, 0.02, 0.9)
	l.rotation_degrees = Vector3(-90, 0, 0)
	l.modulate = Look.color("vellum")
	l.render_priority = 10
	parent.add_child(l)
	return l


## Ground direction for "facing `steps` eighths clockwise from the camera".
func _dir(steps: int) -> Vector3:
	var g := rig.ground_basis()
	var angle := steps * PI / 4.0
	return (-g[0] * cos(angle) + g[1] * sin(angle)).normalized()


func _face(steps: int) -> void:
	for s: DirectionalSprite in [before, after]:
		s.facing = _dir(steps)


func _wait(seconds: float) -> void:
	await get_tree().create_timer(seconds).timeout


func _run() -> void:
	await _wait(0.3)
	title.text = "Standing: the new set breathes"
	_face(1)
	await _wait(3.0)
	title.text = "Walking"
	for steps: int in [1, 2, 3]:
		_face(steps)
		before.moving = true
		after.moving = true
		await _wait(1.8)
	before.moving = false
	after.moving = false
	title.text = "Attacking"
	for steps: int in [1, 2, 7]:
		_face(steps)
		await _wait(0.4)
		before.attack()
		after.attack()
		await _wait(1.4)
	if _short:
		title.text = "Walking, up close"
		rig.distance = 4.5
		for steps: int in [2, 1]:
			_face(steps)
			before.moving = true
			after.moving = true
			await _wait(2.5)
		before.moving = false
		after.moving = false
		title.text = "Attacking, up close"
		for steps: int in [2, 1]:
			_face(steps)
			await _wait(0.4)
			before.attack()
			after.attack()
			await _wait(1.4)
		get_tree().quit()
		return
	title.text = "Taking a hit"
	_face(1)
	for i in 2:
		await _wait(0.5)
		_flash(before)
		_flash(after)
		after.hurt()
		await _wait(1.0)
	title.text = "Falling"
	await _wait(0.4)
	_old_fall()
	after.die()
	await _wait(2.5)
	title.text = "New poses: riding a Phantom Steed, sneaking, casting"
	_lying.visible = false
	before.visible = false
	tags[0].visible = false
	after.pose = ""
	after.visible = true
	await _poses()
	get_tree().quit()


## The old fall: the figure crumples and the front view drops flat (CombatToken.fall without drawn frames).
func _old_fall() -> void:
	var tw := create_tween()
	tw.tween_property(before, "scale", Vector3(1.15, 0.15, 1.0), 0.22).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_QUAD)
	tw.tween_callback(func() -> void:
		before.visible = false
		_lying.visible = true)


func _flash(s: DirectionalSprite) -> void:
	var tw := create_tween()
	for i in 3:
		tw.tween_property(s, "modulate", Look.color("vampire_red"), 0.05)
		tw.tween_property(s, "modulate", Color.WHITE, 0.05)


func _poses() -> void:
	var frames := DirectionalSprite.frames_for(_mount_id)
	if frames != null:
		mount = DirectionalSprite.create(frames, float(CombatToken.HEIGHTS.get(_mount_id, 1.7)))
		mount.position = after.position
		after.get_parent().add_child(mount)
		mount.facing = _dir(2)
		after.position = mount.position + Vector3(0, float(CombatToken.HEIGHTS.get(_mount_id, 1.7)) * 0.8, 0)
		after.pose = "ride"
		for steps: int in [2, 1, 3]:
			mount.facing = _dir(steps)
			after.facing = _dir(steps)
			await _wait(1.2)
			after.attack()
			await _wait(1.3)
		mount.queue_free()
		after.position.y = 0.0
	after.pose = "sneak"
	for steps: int in [1, 2]:
		after.facing = _dir(steps)
		after.moving = true
		await _wait(2.0)
	after.moving = false
	await _wait(1.0)
	after.pose = ""
	for steps: int in [1, 2]:
		after.facing = _dir(steps)
		await _wait(0.5)
		after.cast()
		await _wait(1.5)
	await _wait(0.5)
