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

## The world's finish (docs/plans/ui_polish.md, docs/art/style_bible.md), the player's choice (GameSettings,
## user://settings.cfg): "classic" is the 1990s cartoon pass (every pixel snapped to the palette, light in hard bands,
## frozen as it was on 2026-10-07); "modern" is the HD-2D look: the same art, the characters inked, the world lit like
## painted 3D without ink lines, with filmic tone, bloom on flames and lanterns, soft shadows and haze. Places built
## after a change use it.
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


## A flat-coloured world material: Classic's cel bands, or in the Modern finish lit like painted 3D with the colour's
## own roughness and metal (COLOUR_MATERIALS).
static func cel(albedo_name: String) -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = LIT_SHADER if modern() else CEL_SHADER
	m.set_shader_parameter("albedo", color(albedo_name))
	if modern():
		var spec := COLOUR_MATERIALS.get(albedo_name, {}) as Dictionary
		m.set_shader_parameter("roughness", float(spec.get("roughness", 0.75)))
		m.set_shader_parameter("metallic", float(spec.get("metallic", 0.0)))
	return m


## The Modern finish's lit world shaders (Improvement Ideas W3); Classic keeps CEL_SHADER and CEL_WORLD_SHADER.
const LIT_SHADER := preload("res://shaders/world/lit.gdshader")
const LIT_WORLD_SHADER := preload("res://shaders/world/lit_world.gdshader")

## Flat palette colours that aren't matte, for the Modern finish (the rest take roughness 0.75): metal fittings shine,
## bone and ivory and polished dark wood take a soft highlight, cloth stays dull.
const COLOUR_MATERIALS := {
	"silver": {"roughness": 0.3, "metallic": 0.9},
	"pewter": {"roughness": 0.4, "metallic": 0.8},
	"ivory": {"roughness": 0.45},
	"bone": {"roughness": 0.55},
	"walnut": {"roughness": 0.5},
	"void": {"roughness": 0.5},
	"ink": {"roughness": 0.5},
	"slate": {"roughness": 0.55},
	"leather": {"roughness": 0.6},
	"blood": {"roughness": 0.9},
	"blood_deep": {"roughness": 0.9},
	"crimson": {"roughness": 0.9},
	"vampire_red": {"roughness": 0.9},
	"plum": {"roughness": 0.9},
	"moss": {"roughness": 0.95},
}


## The parameter a world material is coloured by: "albedo" for a flat colour, "tint" over a texture, "" for another
## kind of material (an emptied container darkens it, ModelPiece.dim).
static func tint_key(m: ShaderMaterial) -> String:
	if m.shader in [CEL_SHADER, LIT_SHADER]:
		return "albedo"
	if m.shader in [CEL_WORLD_SHADER, LIT_WORLD_SHADER]:
		return "tint"
	return ""


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
	m.shader = LIT_WORLD_SHADER if modern() else CEL_WORLD_SHADER
	m.set_shader_parameter("albedo_tex", load(path) as Texture2D)
	m.set_shader_parameter("tile_units", float(info.get("tile_world_units", 2.0)))
	m.set_shader_parameter("wall_band", str(info.get("wrap", "xy")) == "x")
	m.set_shader_parameter("grid_strength", grid)
	m.set_shader_parameter("grid_line", color("ink"))
	m.set_meta("surface", surface)   # what the ground is, for footprints (Atmosphere)
	if modern():
		var spec := material_for(surface)
		var relief := MODERN_RELIEF * float(spec.get("relief", 1.0))
		var nm: Texture2D = null
		if info.has("normal_file") and ResourceLoader.exists("res://" + str(info["normal_file"])):
			nm = load("res://" + str(info["normal_file"])) as Texture2D
		else:
			nm = normal_map(path)
		if nm != null:
			m.set_shader_parameter("normal_tex", nm)
			m.set_shader_parameter("normal_strength", relief)
		if info.has("orm_file") and ResourceLoader.exists("res://" + str(info["orm_file"])):
			m.set_shader_parameter("orm_tex", load("res://" + str(info["orm_file"])) as Texture2D)
			m.set_shader_parameter("use_orm", true)
		m.set_shader_parameter("roughness", float(spec.get("roughness", 0.8)))
		m.set_shader_parameter("metallic", float(spec.get("metallic", 0.0)))
		m.set_shader_parameter("roughness_spread", float(spec.get("spread", 0.35)))
		_set_variants(m, info, path)
		var macro := str(textures().get("macro_file", ""))
		if macro != "" and ResourceLoader.exists("res://" + macro) and float(spec.get("macro", MACRO_STRENGTH)) > 0.0:
			m.set_shader_parameter("macro_tex", load("res://" + macro) as Texture2D)
			m.set_shader_parameter("macro_strength", float(spec.get("macro", MACRO_STRENGTH)))
	_textured[key] = m
	return m


## How strongly broad light and dark patches break up a surface in the Modern finish (W4), unless its material says.
const MACRO_STRENGTH := 0.35


## A surface's edge-matched variants (W4: the manifest entry's "variants", each {"file", "normal_file", "orm_file"}):
## one is picked per tile. Layer 0 is the surface's own tile. Normal maps a layer lacks are made from its tile; ORM
## layers only when every layer has one. Variants that don't match the first tile's size and format are left out.
static func _set_variants(m: ShaderMaterial, info: Dictionary, path: String) -> void:
	var variants := info.get("variants", []) as Array
	if variants.is_empty():
		return
	var albedo: Array[Image] = []
	var normal: Array[Image] = []
	var orm: Array[Image] = []
	var all_orm := true
	var layers: Array[Dictionary] = [{"file": path.trim_prefix("res://"), "normal_file": info.get("normal_file", ""),
		"orm_file": info.get("orm_file", "")}]
	for v: Variant in variants:
		layers.append(v as Dictionary)
	for layer: Dictionary in layers:
		var a := _layer_image("res://" + str(layer.get("file", "")))
		if a == null or (not albedo.is_empty() and not _same_shape(a, albedo[0])):
			continue
		var n := _layer_image("res://" + str(layer.get("normal_file", "")))
		if n == null:
			var made := normal_map("res://" + str(layer.get("file", "")))
			n = made.get_image() if made != null else null
		if n == null or (not normal.is_empty() and not _same_shape(n, normal[0])):
			continue
		var o := _layer_image("res://" + str(layer.get("orm_file", "")))
		if o == null or (not orm.is_empty() and not _same_shape(o, orm[0])):
			all_orm = false
		albedo.append(a)
		normal.append(n)
		if o != null:
			orm.append(o)
	if albedo.size() < 2:
		return
	var a_arr := Texture2DArray.new()
	var n_arr := Texture2DArray.new()
	if a_arr.create_from_images(albedo) != OK or n_arr.create_from_images(normal) != OK:
		return
	m.set_shader_parameter("albedo_layers", a_arr)
	m.set_shader_parameter("normal_layers", n_arr)
	m.set_shader_parameter("layer_count", albedo.size())
	if all_orm and orm.size() == albedo.size():
		var o_arr := Texture2DArray.new()
		if o_arr.create_from_images(orm) == OK:
			m.set_shader_parameter("orm_layers", o_arr)
			m.set_shader_parameter("use_orm", true)


static func _layer_image(res: String) -> Image:
	if res == "res://" or not ResourceLoader.exists(res):
		return null
	var tex := load(res) as Texture2D
	return tex.get_image() if tex != null else null


static func _same_shape(a: Image, b: Image) -> bool:
	return a.get_size() == b.get_size() and a.get_format() == b.get_format() and a.has_mipmaps() == b.has_mipmaps()


## How deep the modern finish's relief reads (lit_world.gdshader normal_strength, times the surface's `relief`).
const MODERN_RELIEF := 0.9

## How each world surface takes the light in the Modern finish (W3), by the first word of this list its name holds
## ("interior/marble_floor" is marble): roughness (0 a mirror, 1 chalk), how much rougher its dark is than its light
## (`spread`), how deep its relief reads (`relief`) and metal; `macro` (W4) is how strongly broad patches break it up
## (MACRO_STRENGTH unless set). A surface's own "material" in art/textures/manifest.json wins over this, and its own
## "normal_file" and "orm_file" (occlusion, roughness, metal) over both.
const MATERIALS: Array[Array] = [
	["marble", {"roughness": 0.3, "spread": 0.3, "relief": 0.5}],
	["black_stone", {"roughness": 0.32, "spread": 0.4, "relief": 0.6}],
	["amber", {"roughness": 0.28, "spread": 0.3, "relief": 0.5}],
	["tile", {"roughness": 0.36, "spread": 0.5, "relief": 0.8}],
	["parquet", {"roughness": 0.3, "spread": 0.5, "relief": 0.6}],
	["panel", {"roughness": 0.4, "spread": 0.5, "relief": 0.9}],
	["wainscot", {"roughness": 0.45, "spread": 0.5, "relief": 0.8}],
	["cobble", {"roughness": 0.4, "spread": 0.9, "relief": 1.2}],
	["flag", {"roughness": 0.5, "spread": 0.8, "relief": 1.1}],
	["courtyard", {"roughness": 0.55, "spread": 0.8, "relief": 1.0}],
	["roof_slate", {"roughness": 0.45, "spread": 0.7, "relief": 0.9}],
	["mud", {"roughness": 0.35, "spread": 0.7, "relief": 0.8}],
	["water", {"roughness": 0.1, "spread": 0.0, "relief": 0.3}],
	["snow", {"roughness": 0.55, "spread": 0.4, "relief": 0.6}],
	["planks", {"roughness": 0.6, "spread": 0.6, "relief": 0.9}],
	["boards", {"roughness": 0.65, "spread": 0.6, "relief": 0.9}],
	["logs", {"roughness": 0.75, "spread": 0.5, "relief": 1.0}],
	["brick", {"roughness": 0.7, "spread": 0.6, "relief": 1.0}],
	["ashlar", {"roughness": 0.65, "spread": 0.6, "relief": 1.0}],
	["stone", {"roughness": 0.65, "spread": 0.6, "relief": 1.0}],
	["rock", {"roughness": 0.75, "spread": 0.5, "relief": 1.1}],
	["cliff", {"roughness": 0.75, "spread": 0.5, "relief": 1.1}],
	["scree", {"roughness": 0.8, "spread": 0.4, "relief": 1.0}],
	["terracotta", {"roughness": 0.65, "spread": 0.5, "relief": 0.8}],
	["plaster", {"roughness": 0.9, "spread": 0.2, "relief": 0.7}],
	["whitewash", {"roughness": 0.9, "spread": 0.2, "relief": 0.6}],
	["wallpaper", {"roughness": 0.8, "spread": 0.2, "relief": 0.5}],
	["damask", {"roughness": 0.7, "spread": 0.3, "relief": 0.5}],
	["house_wall", {"roughness": 0.85, "spread": 0.3, "relief": 0.9}],
	["rug", {"roughness": 1.0, "spread": 0.0, "relief": 0.6}],
	["carpet", {"roughness": 1.0, "spread": 0.0, "relief": 0.6}],
	["thatch", {"roughness": 1.0, "spread": 0.0, "relief": 1.0}],
	["grass", {"roughness": 0.8, "spread": 0.4, "relief": 0.8}],
	["earth", {"roughness": 0.85, "spread": 0.3, "relief": 0.9}],
]


## The light-taking settings for a surface ("village/cobbles"): MATERIALS by name, under its own manifest "material".
static func material_for(surface: String) -> Dictionary:
	var out := {"roughness": 0.8, "spread": 0.35, "relief": 1.0, "metallic": 0.0}
	for row: Array in MATERIALS:
		if surface.contains(str(row[0])):
			out.merge(row[1] as Dictionary, true)
			break
	var parts := surface.split("/")
	if parts.size() == 2:
		var info := (((textures().get("themes", {}) as Dictionary).get(parts[0], {}) as Dictionary).get(parts[1], {})) as Dictionary
		out.merge(info.get("material", {}) as Dictionary, true)
	return out
static var _normals: Dictionary = {}


## A normal map made from a texture's own brightness (dark ink lines and mortar read as grooves), softened first so
## it gives bevels rather than noise. Made once per texture and kept, in memory and on disk (user://look_cache: every
## first visit made them on the spot, up to 290 ms in the castle, P3; now only the first ever does), as two channels
## (the shader rebuilds z). Null if the image can't be read.
static func normal_map(path: String) -> Texture2D:
	if _normals.has(path):
		return _normals[path] as Texture2D
	var cached := _cached_normal(path)
	if cached != null:
		_normals[path] = cached
		return cached
	var tex := load(path) as Texture2D
	var img := _normal_image(tex.get_image() if tex != null else null)
	var out: ImageTexture = ImageTexture.create_from_image(img) if img != null else null
	_normals[path] = out
	if out != null:
		DirAccess.make_dir_recursive_absolute(NORMAL_CACHE)
		ResourceSaver.save(out, _normal_cache_path(path))
	return out


const NORMAL_CACHE := "user://look_cache/normals/"


## The normal map image for a texture's image: decompressed, softened, turned to normals, mipmapped and compressed to
## two channels.
static func _normal_image(src: Image) -> Image:
	if src == null:
		return null
	var img := src.duplicate() as Image
	if img.is_compressed() and img.decompress() != OK:
		return null
	img.clear_mipmaps()
	var w := img.get_width()
	var h := img.get_height()
	img.convert(Image.FORMAT_L8)
	# A cheap blur: down to a third and back up, so lines become soft grooves.
	img.resize(maxi(8, w / 3), maxi(8, h / 3), Image.INTERPOLATE_BILINEAR)
	img.resize(w, h, Image.INTERPOLATE_CUBIC)
	img.bump_map_to_normal_map(6.0)
	img.generate_mipmaps()
	# Two channels (RGTC) for a normal map. Only the editor's binary can compress at run time: an exported build keeps the
	# map uncompressed (the same look, more video memory) rather than raise an error the player sees.
	if OS.has_feature("editor"):
		img.compress(Image.COMPRESS_S3TC, Image.COMPRESS_SOURCE_NORMAL)
	return img


## Where a texture's normal map is kept on disk: by its path and when its image last changed.
static func _normal_cache_path(path: String) -> String:
	var stamp := FileAccess.get_modified_time(path)
	return NORMAL_CACHE + "%s_%d.res" % [path.md5_text(), stamp]


static func _cached_normal(path: String) -> Texture2D:
	var file := _normal_cache_path(path)
	if not FileAccess.file_exists(file):
		return null
	return ResourceLoader.load(file, "", ResourceLoader.CACHE_MODE_IGNORE) as Texture2D


static func cel_checker(a: String, b: String, line: String) -> ShaderMaterial:
	var m := cel(a)
	m.set_shader_parameter("checker", true)
	m.set_shader_parameter("checker_alt", color(b))
	m.set_shader_parameter("grid_line", color(line))
	return m


static var _noise: ImageTexture = null


## A 256 x 256 tile of random values for the screen pass's noise in the Modern finish (strahd_post.gdshader
## fast_noise): its own fixed seed, so the mist is the same from run to run (cosmetic, never Dice).
static func noise_texture() -> ImageTexture:
	if _noise == null:
		var rng := RandomNumberGenerator.new()
		rng.seed = 0x5742A
		var img := Image.create(256, 256, false, Image.FORMAT_R8)
		for y in 256:
			for x in 256:
				var v := rng.randf()
				img.set_pixel(x, y, Color(v, v, v))
		_noise = ImageTexture.create_from_image(img)
	return _noise


## Where the screen pass draws among blended things: before all of them (they draw at 0 and above).
const POST_PRIORITY := -1


## A full-screen quad that runs the outline + palette pass. Parent it to the active camera.
static func make_post_process() -> MeshInstance3D:
	var quad := QuadMesh.new()
	quad.size = Vector2(2, 2)
	var mat := ShaderMaterial.new()
	mat.shader = POST_SHADER
	# First in the transparent pass: the pass redraws the whole screen from the copy taken before that pass, so
	# anything blended drawn ahead of it would be painted over (a 3D piece fading in front of the party vanished
	# instead of ghosting). Everything blended now draws over the finished picture.
	mat.render_priority = POST_PRIORITY
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
## Modern draws no ink lines on the world (Improvement Ideas W15, the approved target frames): only the 2D characters
## keep their ink (their own shader), so they stand apart from the lit 3D world. The post shader can still draw light
## silhouettes only (`outline_creases` off, `outline_strength` under 1) should the world want a little line back.
static func style_post(mat: ShaderMaterial) -> void:
	var m := modern()
	mat.set_shader_parameter("quantize", not m)
	mat.set_shader_parameter("soft_bands", m)
	mat.set_shader_parameter("keep_hdr", m)
	mat.set_shader_parameter("outlines", not m)
	mat.set_shader_parameter("tone_split", m)
	mat.set_shader_parameter("fast_noise", m)
	if m:
		mat.set_shader_parameter("noise_tex", noise_texture())
	mat.set_shader_parameter("outline_width", 1.2 if m else 1.5)
