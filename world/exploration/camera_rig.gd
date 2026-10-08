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

var follow: Node3D
var camera: Camera3D
var distance := 13.0
var zoom_min := ZOOM_MIN
var zoom_max := ZOOM_MAX
## How far toward the horizon the wheel has taken the camera (0 in play, 1 fully tilted), and how far it shows now.
var horizon := 0.0
var horizon_shown := 0.0
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
	if event.is_action_pressed(&"camera_rotate_left"):
		rotate_step(-1)
	elif event.is_action_pressed(&"camera_rotate_right"):
		rotate_step(1)


func _process(delta: float) -> void:
	if follow:
		global_position = global_position.lerp(follow.global_position, clampf(delta * 6.0, 0.0, 1.0))
	var goal := deg_to_rad(45.0) + _yaw_steps * PI / 2.0
	_yaw = lerp_angle(_yaw, goal, clampf(delta * 9.0, 0.0, 1.0))
	horizon_shown = move_toward(horizon_shown, horizon, delta * 1.6)
	_apply()


func _apply() -> void:
	rotation = Vector3(0, _yaw, 0)
	var k := smoothstep(0.0, 1.0, horizon_shown)
	var play := deg_to_rad(PITCH_DEG)
	var at := Vector3(0, -sin(play) * distance, cos(play) * distance) + Vector3(0, 0.6, 0)
	camera.position = at.lerp(Vector3(0, HORIZON_HEIGHT, HORIZON_BACK), k)
	camera.rotation = Vector3(deg_to_rad(lerpf(PITCH_DEG, HORIZON_PITCH_DEG, k)), 0, 0)
	var far := lerpf(_far, HORIZON_FAR, k)
	if not is_equal_approx(camera.far, far):
		camera.far = far
