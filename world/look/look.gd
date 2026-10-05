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
