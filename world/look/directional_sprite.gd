class_name DirectionalSprite
extends AnimatedSprite3D
## A billboard that plays the right one of 8 rendered directions for where the character faces
## relative to the camera (art/sprites/<id>/walk.tres from blender/render_walk.py), and its attack
## (attack.tres from blender/render_attack.py) when asked (docs/art/animation.md). Sprites with the fuller animation
## set (blender/render_keys.py) also breathe while idle, flinch when hit, fall when they drop, and have poses for
## sneaking, riding a mount and lying down, plus a spell gesture.

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
## The standing pose: "" (on foot), "sneak" (crouched, hidden or sneaking), "ride" (astride a mount) or "down" (lying:
## at 0 Hit Points or Prone). A pose the sheet doesn't have falls back to on foot.
var pose := ""
## Set as a walk ends (PartyGlide): the walk plays on to the next foot-down frame, briefly, before standing still, so
## the figure doesn't snap from mid-stride to standing.
var finish_stride := false
var _stride_t := 0.0
var _attacking := false
var _struck := false
var _hit_frame := 2
## The one-shot animation playing ("attack", "cast", "hurt", "die"...), "" when none.
var _one_shot := ""

## The sheets a sprite folder may hold, merged in this order (a later sheet's animation replaces an earlier one).
const SHEETS: Array[String] = ["walk", "attack", "hurt", "ride", "sneak", "cast"]
## Merged frames per sprite id (frames_for).
static var _frames_cache: Dictionary = {}


## Characters draw after the palette pass at full screen
## resolution: their sheets are already quantized to the palette by the pipeline, so they stay on-model while
## staying sharp (owner request 2026-10-06).
const RENDER_PRIORITY := 6
## Owner feedback (2026-10-06 "blurry", 2026-10-07 "crisp lines and high definition of each character's features"):
## a 384 px sheet shown about 170 px tall was sampled plainly (jagged, broken lines) or through mipmaps (soft). Every
## character sprite now draws through shaders/world/sprite_crisp.gdshader: a 4x4 grid of samples over each screen
## pixel on the full sheet (sharp without jaggies) and an ink outline round the figure at any zoom.
const CRISP := preload("res://shaders/world/sprite_crisp.gdshader")


## `cell_px` is the sheet's cell size; by default it's read from the frames.
static func create(frames: SpriteFrames, height_units: float, cell_px: int = -1) -> DirectionalSprite:
	var s := DirectionalSprite.new()
	s.sprite_frames = frames
	s._hit_frame = int(frames.get_meta("hit_frame", 2))
	s.frame_changed.connect(s._on_frame_changed)
	s.animation_changed.connect(s._bind)
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
## attack_<dir> (and the attack's hit frame as metadata). Null when the sprite has no sheet. Cached per id. A custom
## hero's art id (registered by CombatToken.art_for) gets the paper doll HeroLook puts together.
static func frames_for(art_id: String) -> SpriteFrames:
	if HeroLook.known(art_id):
		return HeroLook.frames_for_art(art_id)
	if _frames_cache.has(art_id):
		return _frames_cache[art_id] as SpriteFrames
	var walk_path := "res://art/sprites/%s/walk.tres" % art_id
	if not ResourceLoader.exists(walk_path):
		return null
	var walk := load(walk_path) as SpriteFrames
	var sources: Array[SpriteFrames] = [walk]
	for sheet: String in SHEETS.slice(1):
		var path := "res://art/sprites/%s/%s.tres" % [art_id, sheet]
		if ResourceLoader.exists(path):
			sources.append(load(path) as SpriteFrames)
	var frames := walk
	if walk != null and sources.size() > 1:
		frames = SpriteFrames.new()
		frames.remove_animation(&"default")
		var hits := {}
		var mirrored := {}
		for source in sources:
			for anim in source.get_animation_names():
				if anim == &"default":
					continue
				if frames.has_animation(anim):
					frames.remove_animation(anim)
				frames.add_animation(anim)
				frames.set_animation_loop(anim, source.get_animation_loop(anim))
				frames.set_animation_speed(anim, source.get_animation_speed(anim))
				for i in source.get_frame_count(anim):
					frames.add_frame(anim, source.get_frame_texture(anim, i), source.get_frame_duration(anim, i))
			hits.merge(source.get_meta("hit_frames", {}) as Dictionary, true)
			mirrored.merge(source.get_meta("mirrored", {}) as Dictionary, true)
			if source.has_meta("hit_frame"):
				frames.set_meta("hit_frame", int(source.get_meta("hit_frame")))
				frames.set_meta("casts", bool(source.get_meta("casts", false)))
		frames.set_meta("hit_frames", hits)
		if not mirrored.is_empty():
			frames.set_meta("mirrored", mirrored)
	_frames_cache[art_id] = frames
	return frames


## The animation that shows `base` facing `dir`, and whether it plays flipped: HD sheets (render_keys.py) leave out the
## directions that are mirror images of others (metadata "mirrored", e.g. {"w": "e"}), shown flipped instead.
static func anim_for(frames: SpriteFrames, base: String, dir: String) -> Array:
	var anim := StringName(base + "_" + dir)
	if frames != null and not frames.has_animation(anim):
		var m := frames.get_meta("mirrored", {}) as Dictionary
		if m.has(dir):
			return [StringName(base + "_" + str(m[dir])), true]
	return [anim, false]


## Whether the frames have animation `base` (in every direction when in one).
static func has_anim(frames: SpriteFrames, base: String) -> bool:
	return frames != null and frames.has_animation(StringName(base + "_s"))


## Whether these frames have a drawn attack (every direction has one when any does).
static func has_attack(frames: SpriteFrames) -> bool:
	return frames != null and frames.has_animation(&"attack_s")


## Whether the drawn attack is a spell gesture (a wizard's blast, a priest's raised symbol): it plays for spells too.
static func attack_casts(frames: SpriteFrames) -> bool:
	return has_attack(frames) and bool(frames.get_meta("casts", false))


## Shared settings for character sprites (also the lying-down view): drawn after the screen pass through the crisp
## sprite shader (CRISP), which samples the current sheet (bind_sheet). Set the sprite's billboard mode first: a
## sprite with billboarding off (the lying view) keeps its own rotation.
static func setup_material(s: SpriteBase3D) -> void:
	s.alpha_cut = SpriteBase3D.ALPHA_CUT_DISABLED
	s.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR
	s.render_priority = RENDER_PRIORITY
	s.shaded = false
	var m := ShaderMaterial.new()
	m.shader = CRISP
	m.render_priority = RENDER_PRIORITY
	m.set_shader_parameter("ink", Look.color("void"))
	# A sprite laid flat (the lying view) keeps its rotation; the walking figures billboard round the Y axis.
	m.set_shader_parameter("billboard", s.billboard != BaseMaterial3D.BILLBOARD_DISABLED)
	s.material_override = m
	if s is Sprite3D:
		bind_sheet(s, (s as Sprite3D).texture)
	elif s is AnimatedSprite3D and (s as AnimatedSprite3D).sprite_frames != null:
		var a := s as AnimatedSprite3D
		var anim := a.animation if a.sprite_frames.has_animation(a.animation) else &"idle_s"
		if a.sprite_frames.has_animation(anim):
			bind_sheet(s, a.sprite_frames.get_frame_texture(anim, 0))


## Points the crisp shader at `tex`'s sheet (an atlas frame's whole sheet: the sprite's UVs already address it).
static func bind_sheet(s: SpriteBase3D, tex: Texture2D) -> void:
	var m := s.material_override as ShaderMaterial
	if m == null or tex == null:
		return
	m.set_shader_parameter("texture_albedo", (tex as AtlasTexture).atlas if tex is AtlasTexture else tex)


func _bind() -> void:
	if sprite_frames != null and sprite_frames.has_animation(animation) and sprite_frames.get_frame_count(animation) > 0:
		bind_sheet(self, sprite_frames.get_frame_texture(animation, clampi(frame, 0, sprite_frames.get_frame_count(animation) - 1)))


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
	walk_speed = clampf(cycle / (CELLS_PER_CYCLE * seconds), 0.3, 2.5)


## Plays the attack once toward `facing` (from the saddle when riding and the sheet has it): `struck` fires on the hit
## frame, `attack_finished` at the end, then it stands idle again. Returns false, playing nothing, when the sprite has
## no attack sheet.
func attack() -> bool:
	if not has_attack(sprite_frames):
		return false
	return _play_once("ride_attack" if pose == "ride" and has_anim(sprite_frames, "ride_attack") else "attack", true)


## The spell gesture (gather, release on the hit frame), like attack(). False when the sheet has none.
func cast() -> bool:
	if not has_anim(sprite_frames, "cast"):
		return false
	return _play_once("cast", true)


## Flinches from a blow and recovers (no hit frame). False when the sheet has no flinch or the figure is lying down.
func hurt() -> bool:
	if not has_anim(sprite_frames, "hurt") or pose == "down" or _attacking or _one_shot == "die":
		return false
	return _play_once("hurt", false)


## Falls (flinch, stagger, collapse) and then lies there (pose "down"). False when the sheet has no fall.
func die() -> bool:
	if not has_anim(sprite_frames, "die") or str(animation).begins_with("down_") or _one_shot == "die":
		return false
	pose = "down"
	return _play_once("die", false)


func _play_once(base: String, lands_a_blow: bool) -> bool:
	var cam := get_viewport().get_camera_3d() if is_inside_tree() else null
	var dir := direction_for(facing, cam.global_basis) if cam != null else "s"
	_one_shot = base
	_attacking = lands_a_blow
	_struck = not lands_a_blow
	_hit_frame = int((sprite_frames.get_meta("hit_frames", {}) as Dictionary).get(base,
		sprite_frames.get_meta("hit_frame", 2) if base == "attack" else 1))
	moving = false
	speed_scale = 1.0
	var shown := anim_for(sprite_frames, base, dir)
	flip_h = bool(shown[1])
	play(shown[0] as StringName)
	return true


## Falling right now (the drawn fall is playing).
func is_dying() -> bool:
	return _one_shot == "die"


func is_attacking() -> bool:
	return _attacking


## The blow of the current (or last) attack has landed.
func has_struck() -> bool:
	return _struck or not _attacking


func _on_frame_changed() -> void:
	_bind()
	if _attacking and not _struck and frame >= _hit_frame:
		_struck = true
		struck.emit()


func _on_animation_finished() -> void:
	_one_shot = ""
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
	if _one_shot != "":
		if not moving or _one_shot == "die":
			return
		# Moving again cuts the attack short.
		_on_animation_finished()
	var base := _loop_for()
	if finish_stride and not moving and _finishing_stride(delta):
		return
	finish_stride = false
	_stride_t = 0.0
	speed_scale = walk_speed if base in ["walk", "sneak_walk"] else 1.0
	var shown := anim_for(sprite_frames, base, direction_for(facing, cam.global_basis))
	var anim := shown[0] as StringName
	flip_h = bool(shown[1])
	if animation != anim:
		var f := frame
		play(anim)
		frame = f if f < sprite_frames.get_frame_count(anim) else 0


## Whether the walk is still playing on to a foot-down frame (half-cycle marks), for at most a fifth of a second.
func _finishing_stride(delta: float) -> bool:
	var a := str(animation)
	if not (a.begins_with("walk_") or a.begins_with("sneak_walk_")) or not is_playing():
		return false
	_stride_t += delta
	var half := maxi(1, sprite_frames.get_frame_count(animation) / 2)
	return frame % half != 0 and _stride_t < 0.2


## The looping animation for the pose and whether the figure is moving.
func _loop_for() -> String:
	match pose:
		"down":
			if has_anim(sprite_frames, "down"):
				return "down"
		"ride":
			if has_anim(sprite_frames, "ride_idle"):
				return "ride_idle"
		"sneak":
			if has_anim(sprite_frames, "sneak_walk"):
				return "sneak_walk" if moving else "sneak_idle"
	return "walk" if moving else "idle"
