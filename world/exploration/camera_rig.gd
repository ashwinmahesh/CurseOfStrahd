class_name CameraRig
extends Node3D
## Fixed-pitch exploration camera (plan §4.1): about 40 degrees down, rotates in 90 degree steps,
## zooms, and follows a target smoothly. Sprites are rendered for these 8 headings.

const PITCH_DEG := -40.0
const ZOOM_MIN := 7.0
const ZOOM_MAX := 22.0
## Past the farthest zoom, the wheel tilts the camera toward the horizon over HORIZON_STEPS more steps (owner pick
## 2026-10-07, Improvement Ideas W13): it comes down to HORIZON_HEIGHT, just over the treetops and roofs, and its
## pitch rises to HORIZON_PITCH_DEG, so it looks out over the party (low in the frame) to the sky and the vistas past
## the map's edge across the top. Play zoom is unchanged, distances a tool sets directly never tilt it, and the
## Classic look (frozen) never tilts.
const HORIZON_STEPS := 4
const HORIZON_PITCH_DEG := -8.0
const HORIZON_HEIGHT := 9.0
const HORIZON_BACK := 25.0
const HORIZON_FAR := 900.0
## The tactical view (owner pick 2026-10-09, after Baldur's Gate 3's): steeper and further back, to plan a fight or a
## sneak from above; camera_tactical (O) switches it, eased in and out over about a third of a second.
const TACTICAL_PITCH_DEG := -66.0
const TACTICAL_ZOOM := 1.45
## How far a full shake (shake = 1) jolts the view, in world units, and how fast it dies away (shake per second).
const SHAKE_MAX := 0.16
const SHAKE_FADE := 3.0

var follow: Node3D
var camera: Camera3D
## The pad's right stick turns the camera (a flick left or right is a quarter turn) and zooms it (up and down) while
## this is on: exploring turns it on (game_root); a fight's radial menu aims with the stick instead (U6).
var pad_look := false
var distance := 13.0
var zoom_min := ZOOM_MIN
var zoom_max := ZOOM_MAX
## How far toward the horizon the wheel has taken the camera (0 in play, 1 fully tilted), and how far it shows now.
var horizon := 0.0
var horizon_shown := 0.0
## A shot over the play view for a fight's big moments (G2 combat impact, G3 a boss's entrance; lane 21), tweened by
## CombatImpact and put back when the moment ends: shot_zoom under 1 pushes in, shot_pitch raises the camera's pitch
## by that many degrees (looking flatter, up at a boss), and the view leans toward shot_focus by shot_weight (0 the
## rig's own point, 1 centred on it). shake jolts the view and dies away by itself.
var shot_zoom := 1.0
var shot_pitch := 0.0
var shot_focus := Vector3.ZERO
var shot_weight := 0.0
var shake := 0.0
## Whether the tactical view is on, and how far the camera has eased into it.
var tactical := false
var tactical_shown := 0.0
## What walls, houses and trees clear the view to while a shot is on it (a boss's entrance), instead of the party's
## leader; null the rest of the time (LocationView._process).
var cutaway_focus: Node3D = null
var _shake_rng := RandomNumberGenerator.new()
var _far := 120.0
var _yaw_steps := 0
var _yaw := 0.0


func _init() -> void:
	name = "CameraRig"
	camera = Camera3D.new()
	camera.fov = 32.0
	camera.near = 0.3
	camera.far = _far
	add_child(camera)
	_yaw = deg_to_rad(45.0)


func rotate_step(dir: int) -> void:
	_yaw_steps += dir


## Unit vectors on the ground plane for "screen up" and "screen right", for camera-relative movement.
func ground_basis() -> Array[Vector3]:
	var fwd := -global_transform.basis.z
	fwd.y = 0
	fwd = fwd.normalized()
	var right := global_transform.basis.x
	right.y = 0
	return [fwd, right.normalized()]


func snap_to_target() -> void:
	if follow:
		global_position = follow.global_position
	_yaw = deg_to_rad(45.0) + _yaw_steps * PI / 2.0
	horizon_shown = horizon
	_apply()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and (event as InputEventMouseButton).pressed:
		var mb := event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_WHEEL_UP:
			if horizon > 0.0:
				horizon = maxf(horizon - 1.0 / HORIZON_STEPS, 0.0)
			else:
				distance = clampf(distance - 1.0, zoom_min, zoom_max)
		elif mb.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			if distance >= zoom_max - 0.01 and Look.modern():
				horizon = minf(horizon + 1.0 / HORIZON_STEPS, 1.0)
			else:
				distance = clampf(distance + 1.0, zoom_min, zoom_max)
	if pad_look and event is InputEventJoypadButton:
		return   # exploring, the stick clicks sneak and switch turn-based; the right stick turns the camera
	if event.is_action_pressed(&"camera_tactical"):
		tactical = not tactical
	elif event.is_action_pressed(&"camera_rotate_left"):
		rotate_step(-1)
	elif event.is_action_pressed(&"camera_rotate_right"):
		rotate_step(1)


## How far the right stick must lean to turn the camera, and come back before it turns it again; zoom per second.
const LOOK_FLICK := 0.7
const LOOK_REST := 0.3
const LOOK_ZOOM := 14.0
var _flicked := false


func _process(delta: float) -> void:
	if pad_look:
		_look(delta)
	if follow:
		global_position = global_position.lerp(follow.global_position, clampf(delta * 6.0, 0.0, 1.0))
	var goal := deg_to_rad(45.0) + _yaw_steps * PI / 2.0
	_yaw = lerp_angle(_yaw, goal, clampf(delta * 9.0, 0.0, 1.0))
	horizon_shown = move_toward(horizon_shown, horizon, delta * 1.6)
	tactical_shown = move_toward(tactical_shown, 1.0 if tactical else 0.0, delta * 3.0)
	_shake(delta)
	_apply()


## The right stick (pad_look): a flick turns a quarter, up and down zoom within the play range.
func _look(delta: float) -> void:
	if not InputMap.has_action(&"look_left"):
		return
	var v := Input.get_vector(&"look_left", &"look_right", &"look_up", &"look_down")
	if absf(v.x) >= LOOK_FLICK and not _flicked and absf(v.x) > absf(v.y):
		_flicked = true
		rotate_step(1 if v.x > 0.0 else -1)
	elif absf(v.x) < LOOK_REST:
		_flicked = false
	if absf(v.y) > 0.25 and horizon <= 0.0:
		distance = clampf(distance + v.y * LOOK_ZOOM * delta, zoom_min, zoom_max)


## The shake's jolt for this frame, on the camera's own offsets so the rig's point and the shot stay put.
func _shake(delta: float) -> void:
	if shake <= 0.0:
		if camera.h_offset != 0.0 or camera.v_offset != 0.0:
			camera.h_offset = 0.0
			camera.v_offset = 0.0
		return
	shake = maxf(shake - delta * SHAKE_FADE, 0.0)
	var reach := shake * shake * SHAKE_MAX
	camera.h_offset = _shake_rng.randf_range(-reach, reach)
	camera.v_offset = _shake_rng.randf_range(-reach, reach)


func _apply() -> void:
	rotation = Vector3(0, _yaw, 0)
	var k := smoothstep(0.0, 1.0, horizon_shown)
	var kt := smoothstep(0.0, 1.0, tactical_shown)
	var pitch := lerpf(PITCH_DEG, TACTICAL_PITCH_DEG, kt) + shot_pitch
	var play := deg_to_rad(pitch)
	var d := distance * shot_zoom * lerpf(1.0, TACTICAL_ZOOM, kt)
	var at := Vector3(0, -sin(play) * d, cos(play) * d) + Vector3(0, 0.6, 0)
	if shot_weight > 0.0:
		at += Basis(Vector3.UP, -_yaw) * ((shot_focus - global_position) * shot_weight)
	camera.position = at.lerp(Vector3(0, HORIZON_HEIGHT, HORIZON_BACK), k)
	camera.rotation = Vector3(deg_to_rad(lerpf(pitch, HORIZON_PITCH_DEG, k)), 0, 0)
	var far := lerpf(_far, HORIZON_FAR, k)
	if not is_equal_approx(camera.far, far):
		camera.far = far
