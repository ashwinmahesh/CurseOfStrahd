// The Modern finish's world surfaces (Improvement Ideas W3): the same seamless world-mapped textures as Classic's
// cel_world.gdshader, lit like painted 3D instead of in flat bands, so a surface catches the light. Lamps and the moon
// leave highlights; roughness varies across the texture (worn tops smoother than grout and cracks), so highlights
// break up into glints; a normal map gives relief; polished and wet floors reflect what stands on them (the
// environment's screen-space reflections). Look.cel_textured sets it up from the surface's entry in
// art/textures/manifest.json and Look.MATERIALS (docs/art/textures.md "How a surface takes the light").
shader_type spatial;
#include "res://shaders/world/world_map.gdshaderinc"
#include "res://shaders/world/lit_light.gdshaderinc"

uniform sampler2D albedo_tex : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
// Multiplies the texture (an emptied container darkens, ModelPiece.dim).
uniform vec3 tint : source_color = vec3(1.0);
// World units (5 ft squares) one copy of the tile spans (tile_world_units in art/textures/manifest.json).
uniform float tile_units = 2.0;
uniform vec2 uv_offset = vec2(0.0);
// Wainscot-style walls (wrap x only): side faces map v once from the top of the wall to its foot.
uniform bool wall_band = false;
uniform float band_top = 1.15;
uniform float band_height = 1.15;
// A faint line around each square on top faces (0 = none).
uniform float grid_strength : hint_range(0.0, 1.0) = 0.0;
uniform vec3 grid_line : source_color = vec3(0.15, 0.13, 0.18);
// Relief: the surface's own normal map, or one made from the texture's brightness (Look.normal_map); 0 = flat.
uniform sampler2D normal_tex : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;
uniform float normal_strength : hint_range(0.0, 2.0) = 0.0;
// Occlusion, roughness and metal in one map (glTF's order: red, green, blue), where the surface has one.
uniform sampler2D orm_tex : hint_default_white, filter_linear_mipmap_anisotropic, repeat_enable;
uniform bool use_orm = false;
// Without a map: how rough the surface is (0 a mirror, 1 chalk), how metallic, and how much rougher the dark of the
// texture is than its light. (`specular`, the strength of a non-metal's reflection, is in lit_light.gdshaderinc.)
uniform float roughness : hint_range(0.0, 1.0) = 0.8;
uniform float metallic : hint_range(0.0, 1.0) = 0.0;
uniform float roughness_spread : hint_range(0.0, 1.0) = 0.35;
// Edge-matched variants of the surface (W4), one picked per tile so a floor doesn't repeat: layer 0 is the surface's
// own tile, and every layer shares the same border so any mix of them tiles seamlessly. 0 layers keeps the single
// textures above. The ORM layers are used when use_orm is on.
uniform sampler2DArray albedo_layers : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2DArray normal_layers : filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2DArray orm_layers : filter_linear_mipmap_anisotropic, repeat_enable;
uniform int layer_count = 0;
// Broad, soft light and dark patches across the surface (W4) so one tile doesn't read as a grid: a tileable noise
// spread over `macro_units` squares, darkening and lightening the surface and its roughness by `macro_strength`.
uniform sampler2D macro_tex : hint_default_white, filter_linear_mipmap, repeat_enable;
uniform float macro_units = 9.0;
uniform float macro_strength = 0.0;

varying vec3 world_pos;
varying vec3 world_normal;

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	world_normal = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
}

// Which variant a tile takes: an integer hash of the tile it's in.
int tile_layer(vec2 uv) {
	ivec2 t = ivec2(floor(uv));
	int h = (t.x * 73856093) ^ (t.y * 19349663);
	h = h ^ (h >> 13);
	return abs(h) % max(layer_count, 1);
}

void fragment() {
	vec2 uv = world_uv(world_pos, world_normal, tile_units, uv_offset, wall_band, band_top, band_height);
	float layer = float(tile_layer(uv));
	bool layered = layer_count > 0;
	vec3 base = (layered ? texture(albedo_layers, vec3(uv, layer)).rgb : texture(albedo_tex, uv).rgb) * tint;
	float macro = 0.5;
	if (macro_strength > 0.0) {
		macro = texture(macro_tex, world_axes(world_pos, world_normal) / macro_units).r;
		base *= mix(1.0, 0.72 + 0.56 * macro, macro_strength);
	}
	if (world_top(world_normal) && grid_strength > 0.0) {
		vec2 f = fract(world_pos.xz);
		float line = step(f.x, 0.02) + step(f.y, 0.02);
		base = mix(base, grid_line, clamp(line, 0.0, 1.0) * grid_strength);
	}
	ALBEDO = base;
	if (normal_strength > 0.0) {
		vec3 map = layered ? texture(normal_layers, vec3(uv, layer)).rgb : texture(normal_tex, uv).rgb;
		vec3 wn = world_relief(world_normal, map, normal_strength);
		NORMAL = normalize((VIEW_MATRIX * vec4(wn, 0.0)).xyz);
	}
	float r = roughness + (0.45 - dot(base, vec3(0.299, 0.587, 0.114))) * roughness_spread;
	float m = metallic;
	if (use_orm) {
		vec3 orm = layered ? texture(orm_layers, vec3(uv, layer)).rgb : texture(orm_tex, uv).rgb;
		AO = orm.r;
		r = orm.g;
		m = orm.b;
	}
	r += (macro - 0.5) * 0.3 * macro_strength;
	// Never below 0.1: the screen pass reads near-zero roughness as water (strahd_post.gdshader).
	ROUGHNESS = clamp(r, 0.1, 1.0);
	METALLIC = m;
	SPECULAR = specular;
}
