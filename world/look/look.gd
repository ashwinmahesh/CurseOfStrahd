class_name Look
extends RefCounted
## One place that builds the game's look: cel materials, the post-process pass and the palette.
## Colours come from art/palette/palette.json so nothing invents its own (style bible rule).

const CEL_SHADER := preload("res://shaders/cel.gdshader")
const POST_SHADER := preload("res://shaders/post/strahd_post.gdshader")
const PALETTE_TEX := preload("res://art/palette/strahd_palette.png")
const PALETTE_JSON := "res://art/palette/palette.json"

static var _palette: Dictionary = {}


static func color(name: String) -> Color:
	if _palette.is_empty():
		var data: Variant = JSON.parse_string(FileAccess.get_file_as_string(PALETTE_JSON))
		_palette = data as Dictionary
	assert(_palette.has(name), "Unknown palette colour: %s" % name)
	return Color(str(_palette[name]))


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
	var key := "%s|%.2f" % [surface, grid]
	if _textured.has(key):
		return _textured[key] as ShaderMaterial
	var parts := surface.split("/")
	if parts.size() != 2:
		return null
	var info := (((textures().get("themes", {}) as Dictionary).get(parts[0], {}) as Dictionary).get(parts[1], {})) as Dictionary
	var path := "res://" + str(info.get("file", ""))
	if info.is_empty() or not ResourceLoader.exists(path):
		return null
	var m := ShaderMaterial.new()
	m.shader = CEL_WORLD_SHADER
	m.set_shader_parameter("albedo_tex", load(path) as Texture2D)
	m.set_shader_parameter("tile_units", float(info.get("tile_world_units", 2.0)))
	m.set_shader_parameter("wall_band", str(info.get("wrap", "xy")) == "x")
	m.set_shader_parameter("grid_strength", grid)
	m.set_shader_parameter("grid_line", color("ink"))
	_textured[key] = m
	return m


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
	quad.material = mat
	var mi := MeshInstance3D.new()
	mi.name = "PostProcess"
	mi.mesh = quad
	mi.extra_cull_margin = 16384.0
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return mi
