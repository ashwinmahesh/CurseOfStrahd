class_name PropView
extends Sprite3D
## A standing prop with a fixed place and facing in the world (owner request 2026-10-06: environment pieces keep
## their real orientation when the camera turns instead of turning with it). It is drawn twice, from the front and
## from behind, each picture with that side toward the lower right; the camera's heading picks the picture and
## whether to mirror it, so the camera always sees the side of the prop that faces it.

var front: Texture2D
var back: Texture2D
var front_pixel := 0.01
var back_pixel := 0.01
## Where the prop's front points, on the ground plane (a unit vector, usually one of the four compass directions).
var facing := Vector3(0, 0, 1)
var _shown := -1


static func create(front_tex: Texture2D, front_px: float, back_tex: Texture2D, back_px: float, faces: Vector3) -> PropView:
	var p := PropView.new()
	p.front = front_tex
	p.back = back_tex
	p.front_pixel = front_px
	p.back_pixel = back_px
	p.facing = faces.normalized()
	p.billboard = BaseMaterial3D.BILLBOARD_FIXED_Y
	p.alpha_cut = SpriteBase3D.ALPHA_CUT_DISCARD
	p.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	p.shaded = true
	p._show(true, false)
	return p


func _process(_delta: float) -> void:
	var cam := get_viewport().get_camera_3d()
	if cam != null:
		update_view(cam.global_position, cam.global_basis.x)


## Picks the picture for a camera at `camera_pos` whose screen-right is `camera_right`.
func update_view(camera_pos: Vector3, camera_right: Vector3) -> void:
	var to_cam := camera_pos - global_position
	to_cam.y = 0.0
	var right := Vector3(camera_right.x, 0.0, camera_right.z)
	var see_front := facing.dot(to_cam) >= 0.0
	var face := facing if see_front else -facing
	var mirror := face.dot(right) < 0.0
	var state := (1 if see_front else 0) + (2 if mirror else 0)
	if state != _shown:
		_shown = state
		_show(see_front, mirror)


## Which picture is showing: true for the front.
func shows_front() -> bool:
	return _shown < 0 or _shown % 2 == 1


func _show(see_front: bool, mirror: bool) -> void:
	texture = front if see_front else back
	pixel_size = front_pixel if see_front else back_pixel
	offset = Vector2(0, texture.get_height() / 2.0)
	flip_h = mirror
