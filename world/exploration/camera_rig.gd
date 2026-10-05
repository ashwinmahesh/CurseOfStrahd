class_name CameraRig
extends Node3D
## Fixed-pitch exploration camera (plan §4.1): about 40 degrees down, rotates in 90 degree steps,
## zooms, and follows a target smoothly. Sprites are rendered for these 8 headings.

const PITCH_DEG := -40.0
const ZOOM_MIN := 7.0
const ZOOM_MAX := 22.0

var follow: Node3D
var camera: Camera3D
var distance := 13.0
var _yaw_steps := 0
var _yaw := 0.0


func _init() -> void:
	name = "CameraRig"
	camera = Camera3D.new()
	camera.fov = 32.0
	camera.near = 0.3
	camera.far = 120.0
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
	_apply()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and (event as InputEventMouseButton).pressed:
		var mb := event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_WHEEL_UP:
			distance = clampf(distance - 1.0, ZOOM_MIN, ZOOM_MAX)
		elif mb.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			distance = clampf(distance + 1.0, ZOOM_MIN, ZOOM_MAX)
	if event.is_action_pressed(&"camera_rotate_left"):
		rotate_step(-1)
	elif event.is_action_pressed(&"camera_rotate_right"):
		rotate_step(1)


func _process(delta: float) -> void:
	if follow:
		global_position = global_position.lerp(follow.global_position, clampf(delta * 6.0, 0.0, 1.0))
	var goal := deg_to_rad(45.0) + _yaw_steps * PI / 2.0
	_yaw = lerp_angle(_yaw, goal, clampf(delta * 9.0, 0.0, 1.0))
	_apply()


func _apply() -> void:
	rotation = Vector3(0, _yaw, 0)
	var pitch := deg_to_rad(PITCH_DEG)
	camera.position = Vector3(0, -sin(pitch) * distance, cos(pitch) * distance) + Vector3(0, 0.6, 0)
	camera.rotation = Vector3(pitch, 0, 0)
