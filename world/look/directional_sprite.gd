class_name DirectionalSprite
extends AnimatedSprite3D
## A billboard that plays the right one of 8 rendered directions for where the character faces
## relative to the camera (art/sprites/<id>/walk.tres from blender/render_walk.py).

## Order matches the rows the Blender script renders.
const DIRECTIONS: Array[String] = ["s", "se", "e", "ne", "n", "nw", "w", "sw"]

var facing := Vector3.BACK
var moving := false


## Characters draw after the palette pass at full screen
## resolution: their sheets are already quantized to the palette by the pipeline, so they stay on-model while
## staying sharp (owner request 2026-10-06).
const RENDER_PRIORITY := 6
## Owner feedback (2026-10-06, "they still look really blurry"): a 384 px sheet shown about 110 px tall picked up
## mostly the 96 px mipmap and went soft. Sprites now sample the full sheet; mipmaps take over only when the camera
## is so far out (a figure under ~60 px tall) that sampling the full sheet would shimmer.
const SHARP_DOWN_TO := 0.18
var _filter_check := 0.0


## `cell_px` is the sheet's cell size; by default it's read from the frames.
static func create(frames: SpriteFrames, height_units: float, cell_px: int = -1) -> DirectionalSprite:
	var s := DirectionalSprite.new()
	s.sprite_frames = frames
	if cell_px <= 0:
		cell_px = cell_size(frames)
	s.billboard = BaseMaterial3D.BILLBOARD_FIXED_Y
	setup_material(s)
	# The figure fills about 89% of its cell (render_walk.py frames it at 1.12x figure height).
	s.pixel_size = height_units / (cell_px / 1.12)
	s.offset = Vector2(0, cell_px * 0.5 - cell_px * 0.04)
	return s


## The pixel size of one frame (sheets are rendered at 192 or 384 px cells).
static func cell_size(frames: SpriteFrames) -> int:
	for anim in frames.get_animation_names():
		if frames.get_frame_count(anim) > 0:
			return frames.get_frame_texture(anim, 0).get_height()
	return 192


## Shared settings for character sprites (also the lying-down view): hard alpha edges, mipmapped filtering, and
## drawn after the screen pass, sampled sharp (see SHARP_DOWN_TO).
static func setup_material(s: SpriteBase3D) -> void:
	s.alpha_cut = SpriteBase3D.ALPHA_CUT_DISABLED
	s.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR
	s.render_priority = RENDER_PRIORITY
	s.shaded = false


## Which of the 8 directions to show. `facing` is the world-space ground direction the character
## faces; s means facing the camera, e means facing screen-right.
static func direction_for(facing_dir: Vector3, camera_basis: Basis) -> String:
	var fwd := -camera_basis.z
	fwd.y = 0.0
	var right := camera_basis.x
	right.y = 0.0
	if fwd.length_squared() < 0.0001 or facing_dir.length_squared() < 0.0001:
		return "s"
	fwd = fwd.normalized()
	right = right.normalized()
	var x := facing_dir.dot(right)
	var toward := -facing_dir.dot(fwd)
	var angle := atan2(x, toward)
	var idx := posmod(roundi(angle / (PI / 4.0)), 8)
	return DIRECTIONS[idx]


func _process(delta: float) -> void:
	var cam := get_viewport().get_camera_3d()
	if cam == null:
		return
	_keep_sharp(cam, delta)
	var anim := StringName(("walk_" if moving else "idle_") + direction_for(facing, cam.global_basis))
	if animation != anim:
		var f := frame
		play(anim)
		frame = f


## How many screen pixels one sheet pixel covers decides the filter: sharp while it's above SHARP_DOWN_TO, mipmapped
## below (checked a few times a second; changing the filter rebuilds the material, so only on a change).
func _keep_sharp(cam: Camera3D, delta: float) -> void:
	_filter_check -= delta
	if _filter_check > 0.0:
		return
	_filter_check = 0.25
	var vp := get_viewport()
	var h := float((vp as SubViewport).size.y) if vp is SubViewport else float(get_window().size.y)
	var d := maxf(cam.global_position.distance_to(global_position), 0.01)
	var on_screen := h / (2.0 * d * tan(deg_to_rad(cam.fov) / 2.0)) * pixel_size
	var want := BaseMaterial3D.TEXTURE_FILTER_LINEAR if on_screen >= SHARP_DOWN_TO else BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	if texture_filter != want:
		texture_filter = want
