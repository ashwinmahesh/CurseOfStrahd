extends TestCase
## How the world's surfaces take the light (Improvement Ideas W3, docs/art/textures.md): the Modern finish lights them
## like painted 3D with a roughness and metal per surface and without ink lines (W15), Classic keeps its cel bands and
## lines, and whatever darkens a piece finds its colour either way.

var _was := ""


func before_each() -> void:
	_was = Look.style()


func after_each() -> void:
	Look.set_style(_was, false)


func test_modern_surfaces_take_the_light() -> void:
	Look.set_style("modern", false)
	var marble := Look.cel_textured("interior/marble_floor")
	var cobbles := Look.cel_textured("village/cobbles")
	var plaster := Look.cel_textured("interior/plaster_wall")
	for m: ShaderMaterial in [marble, cobbles, plaster]:
		assert_eq(m.shader, Look.LIT_WORLD_SHADER, "Modern surfaces use the lit world shader")
		assert_true(float(m.get_shader_parameter("normal_strength")) > 0.0, "with relief")
	var r := func(m: ShaderMaterial) -> float: return float(m.get_shader_parameter("roughness"))
	assert_true(r.call(marble) < r.call(cobbles) and r.call(cobbles) < r.call(plaster),
		"polished marble is smoother than cobbles, cobbles than plaster")
	var pewter := Look.cel("pewter")
	assert_eq(pewter.shader, Look.LIT_SHADER, "flat colours are lit too")
	assert_true(float(pewter.get_shader_parameter("metallic")) > 0.5, "pewter is metal")
	assert_eq(float(Look.cel("blood").get_shader_parameter("metallic")), 0.0, "cloth isn't")


func test_classic_keeps_its_cel_bands() -> void:
	Look.set_style("classic", false)
	assert_eq(Look.cel_textured("village/cobbles").shader, Look.CEL_WORLD_SHADER, "Classic surfaces stay cel")
	assert_eq(Look.cel("pewter").shader, Look.CEL_SHADER, "and its flat colours")


## A surface's own "material" in the texture manifest wins over the table, and an unknown surface is plain stone.
func test_material_settings_resolve() -> void:
	assert_eq(float(Look.material_for("castle/black_marble")["roughness"]), 0.3, "marble by its name")
	assert_eq(float(Look.material_for("nowhere/unknown")["roughness"]), 0.8, "an unknown surface is matte")


func test_the_colour_key_is_found_in_either_finish() -> void:
	for s: String in ["modern", "classic"]:
		Look.set_style(s, false)
		assert_eq(Look.tint_key(Look.cel("walnut")), "albedo", "%s flat colour" % s)
		assert_eq(Look.tint_key(Look.cel_textured("village/cobbles")), "tint", "%s texture" % s)


## The world's ink lines (W15): Classic keeps them; Modern leaves them to the characters.
func test_world_ink_lines_only_in_classic() -> void:
	var mat := ShaderMaterial.new()
	mat.shader = Look.POST_SHADER
	Look.set_style("modern", false)
	Look.style_post(mat)
	assert_false(bool(mat.get_shader_parameter("outlines")), "no ink lines on the Modern world")
	Look.set_style("classic", false)
	Look.style_post(mat)
	assert_true(bool(mat.get_shader_parameter("outlines")), "Classic keeps them")


## Edge-matched variants (W4): a surface listing variants gets one picked per tile, its own tile as layer 0.
func test_variants_become_layers() -> void:
	Look.set_style("modern", false)
	var m := ShaderMaterial.new()
	m.shader = Look.LIT_WORLD_SHADER
	var info := {"variants": [{"file": "art/textures/village/mud_road_hd.png"}]}
	Look._set_variants(m, info, "res://art/textures/village/cobbles_hd.png")
	assert_eq(int(m.get_shader_parameter("layer_count")), 2, "the tile and its variant")
	var arr := m.get_shader_parameter("albedo_layers") as Texture2DArray
	assert_true(arr != null and arr.get_layers() == 2, "as one texture array")
	assert_true(m.get_shader_parameter("normal_layers") is Texture2DArray, "with normal maps made for each")
	var plain := ShaderMaterial.new()
	plain.shader = Look.LIT_WORLD_SHADER
	Look._set_variants(plain, {}, "res://art/textures/village/cobbles_hd.png")
	assert_eq(int(plain.get_shader_parameter("layer_count") if plain.get_shader_parameter("layer_count") != null else 0), 0,
		"no variants, no layers")


## Broad patches (W4) only where the texture manifest names the noise to draw them from.
func test_no_macro_without_its_noise() -> void:
	Look.set_style("modern", false)
	if str(Look.textures().get("macro_file", "")) != "":
		return
	var m := Look.cel_textured("village/cobbles")
	var s: Variant = m.get_shader_parameter("macro_strength")
	assert_true(s == null or float(s) == 0.0, "no macro noise, no patches")
