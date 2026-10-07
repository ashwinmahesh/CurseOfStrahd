class_name Look
extends RefCounted
## One place that builds the game's look: cel materials, the post-process pass and the palette.
## Colours come from art/palette/palette.json so nothing invents its own (style bible rule).

const CEL_SHADER := preload("res://shaders/cel.gdshader")
const POST_SHADER := preload("res://shaders/post/strahd_post.gdshader")
const PALETTE_TEX := preload("res://art/palette/strahd_palette.png")
const PALETTE_JSON := "res://art/palette/palette.json"
## Menu-only colours (crimson, black and gilt): never in the strip, so the world's palette pass doesn't change.
const UI_PALETTE_JSON := "res://art/palette/ui_palette.json"

static var _palette: Dictionary = {}
static var _colours: Dictionary = {}

## The world's finish (docs/plans/ui_polish.md), the player's choice (GameSettings, user://settings.cfg):
## "classic" is the 1990s cartoon pass (every pixel snapped to the palette, light in hard bands); "modern" keeps the
## ink lines and the same art but lights it smoothly, with filmic tone, bloom on flames and lanterns, deeper contact
## shadows and soft mist. Places built after a change use it.
const STYLES: Array[String] = ["modern", "classic"]
## The owner picked Modern as the default (2026-10-07); Classic stays in Settings.
const DEFAULT_STYLE := "modern"
static var _style := ""


static func style() -> String:
	if _style == "":
		var saved := str(GameSettings.value("look", DEFAULT_STYLE))
		_style = saved if saved in STYLES else DEFAULT_STYLE
		_publish()
	return _style


static func modern() -> bool:
	return style() == "modern"


static func set_style(s: String, save: bool = true) -> void:
	if not s in STYLES:
		return
	_style = s
	_publish()
	if save:
		GameSettings.set_value("look", s)


## The cel shaders read the style through a global uniform (look_soft, project.godot [shader_globals]).
static func _publish() -> void:
	RenderingServer.global_shader_parameter_set(&"look_soft", 1.0 if _style == "modern" else 0.0)


static func color(name: String) -> Color:
	if _palette.is_empty():
		_palette = JSON.parse_string(FileAccess.get_file_as_string(PALETTE_JSON)) as Dictionary
		_colours = _palette.duplicate()
		_colours.merge(JSON.parse_string(FileAccess.get_file_as_string(UI_PALETTE_JSON)) as Dictionary)
	assert(_colours.has(name), "Unknown palette colour: %s" % name)
	return Color(str(_colours[name]))


static func palette_size() -> int:
	color("void")
	return _palette.size()


static func cel(albedo_name: String) -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = CEL_SHADER
	m.set_shader_parameter("albedo", color(albedo_name))
	return m


const CEL_WORLD_SHADER := preload("res://shaders/cel_world.gdshader")
const TEXTURES_JSON := "res://art/textures/manifest.json"
static var _textures: Dictionary = {}
static var _textured: Dictionary = {}


## The environment texture sets (art/textures/manifest.json, docs/art/textures.md).
static func textures() -> Dictionary:
	if _textures.is_empty() and FileAccess.file_exists(TEXTURES_JSON):
		_textures = JSON.parse_string(FileAccess.get_file_as_string(TEXTURES_JSON)) as Dictionary
	return _textures


## The surface a board theme uses for a part ("floor", "wall", "roof" ...), e.g. "interior/wood_planks", or "".
static func theme_surface(theme: String, part: String) -> String:
	var themes := textures().get("arena_themes", {}) as Dictionary
	return str((themes.get(theme, {}) as Dictionary).get(part, ""))


## A cel material with a seamless world-mapped texture ("village/cobbles"), or null if the surface doesn't exist.
## `grid` draws a faint square grid on top faces.
static func cel_textured(surface: String, grid: float = 0.0) -> ShaderMaterial:
	var key := "%s|%.2f|%s" % [surface, grid, style()]   # a change of look gets fresh materials
	if _textured.has(key):
		return _textured[key] as ShaderMaterial
	var parts := surface.split("/")
	if parts.size() != 2:
		return null
	var info := (((textures().get("themes", {}) as Dictionary).get(parts[0], {}) as Dictionary).get(parts[1], {})) as Dictionary
	var path := "res://" + str(info.get("file", ""))
	if info.is_empty() or not ResourceLoader.exists(path):
		return null
	# The Modern look's smooth tile of the same set, where it's been made (make textures HD=1).
	if modern() and info.has("hd_file") and ResourceLoader.exists("res://" + str(info["hd_file"])):
		path = "res://" + str(info["hd_file"])
	var m := ShaderMaterial.new()
	m.shader = CEL_WORLD_SHADER
	m.set_shader_parameter("albedo_tex", load(path) as Texture2D)
	m.set_shader_parameter("tile_units", float(info.get("tile_world_units", 2.0)))
	m.set_shader_parameter("wall_band", str(info.get("wrap", "xy")) == "x")
	m.set_shader_parameter("grid_strength", grid)
	m.set_shader_parameter("grid_line", color("ink"))
	if modern():
		var nm := normal_map(path)
		if nm != null:
			m.set_shader_parameter("normal_tex", nm)
			m.set_shader_parameter("normal_strength", MODERN_RELIEF)
	_textured[key] = m
	return m


## How deep the modern finish's relief reads (cel_world.gdshader normal_strength).
const MODERN_RELIEF := 0.9
static var _normals: Dictionary = {}


## A normal map made from a texture's own brightness (dark ink lines and mortar read as grooves), softened first so
## it gives bevels rather than noise; made once per texture and kept. Null if the image can't be read.
static func normal_map(path: String) -> Texture2D:
	if _normals.has(path):
		return _normals[path] as Texture2D
	var tex := load(path) as Texture2D
	var img := tex.get_image() if tex != null else null
	if img == null:
		_normals[path] = null
		return null
	img = img.duplicate() as Image
	if img.is_compressed() and img.decompress() != OK:
		_normals[path] = null
		return null
	img.clear_mipmaps()
	var w := img.get_width()
	var h := img.get_height()
	img.convert(Image.FORMAT_L8)
	# A cheap blur: down to a quarter and back up, so lines become soft grooves.
	img.resize(maxi(8, w / 3), maxi(8, h / 3), Image.INTERPOLATE_BILINEAR)
	img.resize(w, h, Image.INTERPOLATE_CUBIC)
	img.bump_map_to_normal_map(6.0)
	img.generate_mipmaps()
	var out := ImageTexture.create_from_image(img)
	_normals[path] = out
	return out


static func cel_checker(a: String, b: String, line: String) -> ShaderMaterial:
	var m := cel(a)
	m.set_shader_parameter("checker", true)
	m.set_shader_parameter("checker_alt", color(b))
	m.set_shader_parameter("grid_line", color(line))
	return m


## A full-screen quad that runs the outline + palette pass. Parent it to the active camera.
static func make_post_process() -> MeshInstance3D:
	var quad := QuadMesh.new()
	quad.size = Vector2(2, 2)
	var mat := ShaderMaterial.new()
	mat.shader = POST_SHADER
	mat.set_shader_parameter("palette_tex", PALETTE_TEX)
	mat.set_shader_parameter("palette_size", palette_size())
	mat.set_shader_parameter("outline_color", color("void"))
	# Owner feedback (2026-10-06): the 2x pixel grid and ordered dithering read as grain. The palette snap and the
	# outlines stay; every pixel is its own and no dither pattern is added.
	mat.set_shader_parameter("pixel_size", 1.0)
	mat.set_shader_parameter("dither_strength", 0.0)
	style_post(mat)
	quad.material = mat
	var mi := MeshInstance3D.new()
	mi.name = "PostProcess"
	mi.mesh = quad
	mi.extra_cull_margin = 16384.0
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return mi


## The post pass for the current style: the palette snap and flat bands for classic, smooth and HDR for modern.
static func style_post(mat: ShaderMaterial) -> void:
	var m := modern()
	mat.set_shader_parameter("quantize", not m)
	mat.set_shader_parameter("soft_bands", m)
	mat.set_shader_parameter("keep_hdr", m)
	mat.set_shader_parameter("outline_width", 1.2 if m else 1.5)
