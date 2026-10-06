class_name DirectionalSprite
extends AnimatedSprite3D
## A billboard that plays the right one of 8 rendered directions for where the character faces
## relative to the camera (art/sprites/<id>/walk.tres from blender/render_walk.py), and its attack
## (attack.tres from blender/render_attack.py) when asked (docs/art/animation.md).

## The attack reached its hit frame (the blow lands): show the hit or miss now.
signal struck
signal attack_finished

## Order matches the rows the Blender script renders.
const DIRECTIONS: Array[String] = ["s", "se", "e", "ne", "n", "nw", "w", "sw"]
## One walk cycle (two steps) covers this many squares, so feet don't skate whatever the step time. Four squares give a
## natural cadence (owner 2026-10-06: three read too fast): about 0.7 s a cycle in exploration, 1 s in combat.
const CELLS_PER_CYCLE := 4.0

var facing := Vector3.BACK
var moving := false
## Playback rate of the walk cycle relative to its sheet (set_step_time).
var walk_speed := 1.0
var _attacking := false
var _struck := false
var _hit_frame := 2

## Merged frames per sprite id: walk.tres plus attack.tres (frames_for).
static var _frames_cache: Dictionary = {}


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
	s._hit_frame = int(frames.get_meta("hit_frame", 2))
	s.frame_changed.connect(s._on_frame_changed)
	s.animation_finished.connect(s._on_animation_finished)
	if cell_px <= 0:
		cell_px = cell_size(frames)
	s.billboard = BaseMaterial3D.BILLBOARD_FIXED_Y
	setup_material(s)
	# The figure fills about 89% of its cell (render_walk.py frames it at 1.12x figure height).
	s.pixel_size = height_units / (cell_px / 1.12)
	s.offset = Vector2(0, cell_px * 0.5 - cell_px * 0.04)
	return s


## The pixel size of one walk frame (sheets are rendered at 192 or 384 px cells): the standing frame's height.
## Attack frames are bigger at the same pixel scale and centred alike, so they size themselves.
static func cell_size(frames: SpriteFrames) -> int:
	if frames.get_frame_count(&"idle_s") > 0:
		return frames.get_frame_texture(&"idle_s", 0).get_height()
	for anim in frames.get_animation_names():
		if frames.get_frame_count(anim) > 0:
			return frames.get_frame_texture(anim, 0).get_height()
	return 192


## The frames for sprite `art_id`: its walk sheet's walk_/idle_ animations plus, when it has an attack sheet,
## attack_<dir> (and the attack's hit frame as metadata). Null when the sprite has no sheet. Cached per id.
static func frames_for(art_id: String) -> SpriteFrames:
	if _frames_cache.has(art_id):
		return _frames_cache[art_id] as SpriteFrames
	var walk_path := "res://art/sprites/%s/walk.tres" % art_id
	if not ResourceLoader.exists(walk_path):
		return null
	var walk := load(walk_path) as SpriteFrames
	var attack_path := "res://art/sprites/%s/attack.tres" % art_id
	var frames := walk
	if walk != null and ResourceLoader.exists(attack_path):
		var attack := load(attack_path) as SpriteFrames
		frames = SpriteFrames.new()
		frames.remove_animation(&"default")
		for source: SpriteFrames in [walk, attack]:
			for anim in source.get_animation_names():
				if anim == &"default":
					continue
				frames.add_animation(anim)
				frames.set_animation_loop(anim, source.get_animation_loop(anim))
				frames.set_animation_speed(anim, source.get_animation_speed(anim))
				for i in source.get_frame_count(anim):
					frames.add_frame(anim, source.get_frame_texture(anim, i), source.get_frame_duration(anim, i))
		frames.set_meta("hit_frame", int(attack.get_meta("hit_frame", 2)))
		frames.set_meta("casts", bool(attack.get_meta("casts", false)))
	_frames_cache[art_id] = frames
	return frames


## Whether these frames have a drawn attack (every direction has one when any does).
static func has_attack(frames: SpriteFrames) -> bool:
	return frames != null and frames.has_animation(&"attack_s")


## Whether the drawn attack is a spell gesture (a wizard's blast, a priest's raised symbol): it plays for spells too.
static func attack_casts(frames: SpriteFrames) -> bool:
	return has_attack(frames) and bool(frames.get_meta("casts", false))


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


## Matches the walk cycle to movement: `seconds` per square moved.
func set_step_time(seconds: float) -> void:
	if seconds <= 0.0 or sprite_frames == null or not sprite_frames.has_animation(&"walk_s"):
		return
	var cycle := float(sprite_frames.get_frame_count(&"walk_s")) / maxf(1.0, sprite_frames.get_animation_speed(&"walk_s"))
	walk_speed = clampf(cycle / (CELLS_PER_CYCLE * seconds), 0.5, 2.5)


## Plays the attack once toward `facing`: `struck` fires on the hit frame, `attack_finished` at the end, then it
## stands idle again. Returns false, playing nothing, when the sprite has no attack sheet.
func attack() -> bool:
	if not has_attack(sprite_frames):
		return false
	var cam := get_viewport().get_camera_3d() if is_inside_tree() else null
	var dir := direction_for(facing, cam.global_basis) if cam != null else "s"
	_attacking = true
	_struck = false
	moving = false
	speed_scale = 1.0
	play(StringName("attack_" + dir))
	return true


func is_attacking() -> bool:
	return _attacking


## The blow of the current (or last) attack has landed.
func has_struck() -> bool:
	return _struck or not _attacking


func _on_frame_changed() -> void:
	if _attacking and not _struck and frame >= _hit_frame:
		_struck = true
		struck.emit()


func _on_animation_finished() -> void:
	if not _attacking:
		return
	_attacking = false
	if not _struck:
		_struck = true
		struck.emit()
	attack_finished.emit()


func _process(delta: float) -> void:
	var cam := get_viewport().get_camera_3d()
	if cam == null:
		return
	_keep_sharp(cam, delta)
	if _attacking:
		if not moving:
			return
		# Moving again cuts the attack short.
		_on_animation_finished()
	speed_scale = walk_speed if moving else 1.0
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
