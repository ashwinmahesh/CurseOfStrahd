class_name SpriteReflection
extends Sprite3D
## A character's reflection (Visual Polish Plan 1, docs/art/atmosphere.md "Reflections"): the figure mirrored under its
## feet, shown where it stands by water, in a rain puddle or on polished stone (shaders/world/sprite_reflection.gdshader
## reads the surface per pixel, so nothing else has to know about it). A child of its DirectionalSprite, which hands it
## its motion between frames each frame (mirror); it follows the figure's frame, flip and fade itself. Only in the
## Modern finish, where the graphics preset has reflections (Medium and High). It changes nothing the rules see.

const SHADER := preload("res://shaders/world/sprite_reflection.gdshader")
## After the screen pass, before the rings, grid and markers on the floor and the figures themselves
## (DirectionalSprite.RENDER_PRIORITY).
const PRIORITY := 0
## Every reflection on screen, so a switch shows at once, paused or not.
const GROUP := &"sprite_reflections"
## Captures and the perf probe turn reflections off to compare (look_capture's LOOK_OFF=reflections, perf_run.py's
## --effects SpriteReflection).
static var enabled := true

var _figure: DirectionalSprite
var _mat: ShaderMaterial
var _sheet: Texture2D = null


static func create(figure: DirectionalSprite, height_units: float) -> SpriteReflection:
	var r := SpriteReflection.new()
	r.name = "Reflection"
	r._figure = figure
	r.billboard = BaseMaterial3D.BILLBOARD_DISABLED   # the shader turns it to the camera, as the figure's does
	r.alpha_cut = SpriteBase3D.ALPHA_CUT_DISABLED
	r.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR
	r.shaded = false
	r.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	r.render_priority = PRIORITY
	r._mat = ShaderMaterial.new()
	r._mat.shader = SHADER
	r._mat.render_priority = PRIORITY
	r._mat.set_shader_parameter("height", height_units)
	r.material_override = r._mat
	r.visible = shown()
	return r


static func set_enabled(on: bool) -> void:
	enabled = on
	var tree := Engine.get_main_loop() as SceneTree
	if tree != null:
		for n in tree.get_nodes_in_group(GROUP):
			(n as SpriteReflection)._refresh()


## Whether reflections show now: the Modern finish with a preset that has reflections.
static func shown() -> bool:
	return enabled and Look.modern() and Graphics.reflection_steps() > 0


## The figure's motion between frames and the way it faces this frame (DirectionalSprite._move_between_frames).
func mirror(sq: Vector2, lean: float, lift: float, push: float, face: Vector3) -> void:
	if not visible:
		return
	_mat.set_shader_parameter("squash", sq)
	_mat.set_shader_parameter("lean", lean)
	_mat.set_shader_parameter("lift", lift)
	_mat.set_shader_parameter("push", push)
	_mat.set_shader_parameter("face", face)


## The figure's shader settings that rarely change (lit, its light floor and glow, a ghost's wash), copied when the
## reflection is made and each time it shows again.
func copy_look() -> void:
	var m := _figure.material_override as ShaderMaterial
	if m == null:
		return
	for p: String in ["lit", "light_floor", "glow", "light_cap", "ghost", "ghost_tint", "billboard"]:
		_mat.set_shader_parameter(p, m.get_shader_parameter(p))


func _ready() -> void:
	add_to_group(GROUP)
	# The frame follows the figure's as it changes (signals, so it holds while the game is paused too).
	_figure.frame_changed.connect(_follow_frame)
	_figure.animation_changed.connect(_follow_frame)
	copy_look()
	_follow_frame()
	_refresh()


func _process(_delta: float) -> void:
	_refresh()
	if visible:
		flip_h = _figure.flip_h
		modulate = _figure.modulate


## Shown or hidden as the finish, the preset and the figure say.
func _refresh() -> void:
	var on := shown() and _figure.visible and _figure.pose != "down"
	if on != visible:
		visible = on
		if on:
			copy_look()
			_follow_frame()


## The frame the figure shows now.
func _follow_frame() -> void:
	var frames := _figure.sprite_frames
	if frames == null or not frames.has_animation(_figure.animation):
		return
	var count := frames.get_frame_count(_figure.animation)
	if count == 0:
		return
	var tex := frames.get_frame_texture(_figure.animation, clampi(_figure.frame, 0, count - 1))
	if tex == texture:
		return
	texture = tex
	var sheet := (tex as AtlasTexture).atlas if tex is AtlasTexture else tex
	if sheet != _sheet:
		_sheet = sheet
		_mat.set_shader_parameter("texture_albedo", sheet)
	flip_h = _figure.flip_h
	pixel_size = _figure.pixel_size
	offset = _figure.offset
	modulate = _figure.modulate
