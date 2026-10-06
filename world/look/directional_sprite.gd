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
## staying sharp (owner request 2026-10-06). Mipmaps keep them smooth when the camera is far away.
const RENDER_PRIORITY := 6


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
## drawn after the screen pass.
static func setup_material(s: SpriteBase3D) -> void:
	s.alpha_cut = SpriteBase3D.ALPHA_CUT_DISABLED
	s.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
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


func _process(_delta: float) -> void:
	var cam := get_viewport().get_camera_3d()
	if cam == null:
		return
	var anim := StringName(("walk_" if moving else "idle_") + direction_for(facing, cam.global_basis))
	if animation != anim:
		var f := frame
		play(anim)
		frame = f
