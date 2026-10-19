// The Modern finish's blended ground (Natural Maps plan N2, docs/art/atmosphere.md "Blended ground"): lit_world.gdshader's
// surface taking light, for ground drawn as one mesh with up to four surfaces on it that melt into each other instead of
// meeting along a square's edge. `control` holds one texel per map square, one channel per surface (A to D) set where that
// square's ground is that surface; the weights come from reading it between the squares' middles (so they ramp over a
// square), broken up by noise so a patch of mud or a path of flags has a ragged, wandering edge, and steepened so each
// surface stays itself over most of its own ground. The middle 60% of every square is always its own surface alone.
// GroundRelief.meshes sets it up (Look.blend_ground) from the surfaces' own materials, so a layer is exactly what its
// square's floor was: the same tile, variants, normal and ORM maps, tint, light-taking settings and macro patches.
// Keep the end of fragment() in step with lit_world.gdshader (weather, puddles, snow).
shader_type spatial;
#include "res://shaders/world/world_map.gdshaderinc"
#include "res://shaders/world/lit_light.gdshaderinc"
#include "res://shaders/world/weather_surface.gdshaderinc"

uniform sampler2D control : filter_linear, repeat_disable, hint_default_black;
// The map's squares across and down: the control map covers them, a square's middle on its texel's.
uniform vec2 grid_size = vec2(32.0, 20.0);
// How far noise moves an edge (in the weights), how steeply it is cut (higher is a sharper but still soft edge), and how
// much of every square's middle is always its own surface (a half-width, squares): 0.3, the middle 60%, for a square of
// difficult ground, which has to read as one, and `core_plain` for the rest, which difficult ground may spill into.
uniform float edge_noise : hint_range(0.0, 1.0) = 0.7;
uniform float edge_sharp : hint_range(1.0, 8.0) = 2.2;
uniform float core_half : hint_range(0.0, 0.5) = 0.3;
uniform float core_plain : hint_range(0.0, 0.5) = 0.12;
// Which surfaces are difficult ground (1 in its channel), which spills out over the squares round it by up to `spill`
// (times noise): mud, drifts and litter creep into the ground beside them, up to half a square, as natural edges do.
uniform vec4 difficult = vec4(0.0);
uniform float spill : hint_range(0.0, 8.0) = 3.0;
// Broad light and dark patches over every surface (W4), as lit_world.gdshader's.
uniform sampler2D macro_tex : hint_default_white, filter_linear_mipmap, repeat_enable;
uniform float macro_units = 9.0;

// Each surface: its tile, normal and ORM maps (every variant a layer of the arrays), how many layers, the tile's size in
// squares, its tint, how deep its relief reads, and how it takes light.
uniform sampler2DArray albedo_a : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2DArray normal_a : filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2DArray orm_a : filter_linear_mipmap_anisotropic, repeat_enable;
uniform int layers_a = 1;
uniform float tile_a = 2.0;
uniform vec3 tint_a : source_color = vec3(1.0);
uniform float relief_a = 0.0;
uniform bool use_orm_a = false;
uniform vec4 light_a = vec4(0.8, 0.0, 0.35, 1.0);   // roughness, metallic, roughness spread, roughness cap
uniform float macro_a = 0.0;

uniform sampler2DArray albedo_b : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2DArray normal_b : filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2DArray orm_b : filter_linear_mipmap_anisotropic, repeat_enable;
uniform int layers_b = 1;
uniform float tile_b = 2.0;
uniform vec3 tint_b : source_color = vec3(1.0);
uniform float relief_b = 0.0;
uniform bool use_orm_b = false;
uniform vec4 light_b = vec4(0.8, 0.0, 0.35, 1.0);
uniform float macro_b = 0.0;

uniform sampler2DArray albedo_c : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2DArray normal_c : filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2DArray orm_c : filter_linear_mipmap_anisotropic, repeat_enable;
uniform int layers_c = 1;
uniform float tile_c = 2.0;
uniform vec3 tint_c : source_color = vec3(1.0);
uniform float relief_c = 0.0;
uniform bool use_orm_c = false;
uniform vec4 light_c = vec4(0.8, 0.0, 0.35, 1.0);
uniform float macro_c = 0.0;

uniform sampler2DArray albedo_d : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2DArray normal_d : filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2DArray orm_d : filter_linear_mipmap_anisotropic, repeat_enable;
uniform int layers_d = 1;
uniform float tile_d = 2.0;
uniform vec3 tint_d : source_color = vec3(1.0);
uniform float relief_d = 0.0;
uniform bool use_orm_d = false;
uniform vec4 light_d = vec4(0.8, 0.0, 0.35, 1.0);
uniform float macro_d = 0.0;

varying vec3 world_pos;
varying vec3 world_normal;

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	world_normal = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
}

// Which variant a tile takes: an integer hash of the tile it's in (as lit_world.gdshader).
int pick_layer(vec2 uv, int count) {
	ivec2 t = ivec2(floor(uv));
	int h = (t.x * 73856093) ^ (t.y * 19349663);
	h = h ^ (h >> 13);
	return abs(h) % max(count, 1);
}

struct Layer {
	vec3 base;
	vec3 normal;
	float rough;
	float metal;
	float ao;
};

// One surface at this point: its colour (with the broad patches), its normal, how rough and metallic it is, its occlusion.
Layer layer_of(sampler2DArray albedo, sampler2DArray nrm, sampler2DArray orm, int count, float tile, vec3 tint, float relief,
		bool use_orm, vec4 light, float macro_k, float macro, vec3 wn, vec2 xz, vec2 gx, vec2 gy) {
	vec2 uv = xz / tile;
	vec2 dx = gx / tile;
	vec2 dy = gy / tile;
	vec3 at = vec3(uv, float(pick_layer(uv, count)));
	Layer l;
	l.base = textureGrad(albedo, at, dx, dy).rgb * tint;
	l.base *= mix(1.0, 0.72 + 0.56 * macro, macro_k);
	l.normal = wn;
	if (relief > 0.0) {
		l.normal = world_relief(wn, textureGrad(nrm, at, dx, dy).rgb, relief);
	}
	float r = light.x + (0.45 - dot(l.base, vec3(0.299, 0.587, 0.114))) * light.z;
	float m = light.y;
	l.ao = 1.0;
	if (use_orm) {
		vec3 o = textureGrad(orm, at, dx, dy).rgb;
		l.ao = o.r;
		r = o.g;
		m = o.b;
	}
	r += (macro - 0.5) * 0.3 * macro_k;
	l.rough = min(r, light.w);
	l.metal = m;
	return l;
}

void fragment() {
	vec2 xz = world_pos.xz;
	vec2 gx = dFdx(xz);
	vec2 gy = dFdy(xz);
	// Which surfaces lie here: the squares' own, read between their middles.
	ivec2 cell = clamp(ivec2(floor(xz)), ivec2(0), ivec2(grid_size) - ivec2(1));
	vec4 own = texelFetch(control, cell, 0);
	vec4 w = texture(control, xz / grid_size);
	// Noise moves each surface's edge on its own, most where it is half there and not at all where it is wholly there or
	// not at all, so a patch has a wandering, ragged edge and no surface appears where its squares aren't.
	vec4 n = vec4(
		ws_noise(xz * 1.7 + vec2(3.1, 8.2)) * 0.65 + ws_noise(xz * 5.3 + vec2(1.7, 4.4)) * 0.35,
		ws_noise(xz * 1.7 + vec2(17.7, 2.3)) * 0.65 + ws_noise(xz * 5.3 + vec2(9.1, 6.2)) * 0.35,
		ws_noise(xz * 1.7 + vec2(41.3, 12.9)) * 0.65 + ws_noise(xz * 5.3 + vec2(2.8, 13.7)) * 0.35,
		ws_noise(xz * 1.7 + vec2(73.9, 5.5)) * 0.65 + ws_noise(xz * 5.3 + vec2(6.6, 21.1)) * 0.35);
	vec4 v = max(w * (1.0 + difficult * spill * n) + (n - 0.5) * edge_noise * 4.0 * w * (1.0 - w), vec4(0.0));
	v = pow(v, vec4(edge_sharp));
	float total = v.r + v.g + v.b + v.a;
	float own_total = max(own.r + own.g + own.b + own.a, 0.0001);
	vec4 b = total > 0.00001 ? v / total : own / own_total;
	// The middle 60% of a square of difficult ground is its own surface (the middle quarter of any other).
	vec2 f = abs(fract(xz) - 0.5);
	float half_core = dot(own, difficult) > 0.5 ? core_half : core_plain;
	float core = 1.0 - smoothstep(half_core, half_core + 0.07, max(f.x, f.y));
	b = mix(b, own / own_total, core);
	// Drop the surfaces that barely show, and keep the rest whole.
	b *= vec4(greaterThan(b, vec4(0.004)));
	b /= max(b.r + b.g + b.b + b.a, 0.0001);

	float macro = texture(macro_tex, xz / macro_units).r;
	vec3 wn0 = normalize(world_normal);
	vec3 base = vec3(0.0);
	vec3 wn = vec3(0.0);
	float r = 0.0;
	float m = 0.0;
	float occ = 0.0;
	if (b.r > 0.0) {
		Layer l = layer_of(albedo_a, normal_a, orm_a, layers_a, tile_a, tint_a, relief_a, use_orm_a, light_a, macro_a, macro, wn0, xz, gx, gy);
		base += l.base * b.r;
		wn += l.normal * b.r;
		r += l.rough * b.r;
		m += l.metal * b.r;
		occ += l.ao * b.r;
	}
	if (b.g > 0.0) {
		Layer l = layer_of(albedo_b, normal_b, orm_b, layers_b, tile_b, tint_b, relief_b, use_orm_b, light_b, macro_b, macro, wn0, xz, gx, gy);
		base += l.base * b.g;
		wn += l.normal * b.g;
		r += l.rough * b.g;
		m += l.metal * b.g;
		occ += l.ao * b.g;
	}
	if (b.b > 0.0) {
		Layer l = layer_of(albedo_c, normal_c, orm_c, layers_c, tile_c, tint_c, relief_c, use_orm_c, light_c, macro_c, macro, wn0, xz, gx, gy);
		base += l.base * b.b;
		wn += l.normal * b.b;
		r += l.rough * b.b;
		m += l.metal * b.b;
		occ += l.ao * b.b;
	}
	if (b.a > 0.0) {
		Layer l = layer_of(albedo_d, normal_d, orm_d, layers_d, tile_d, tint_d, relief_d, use_orm_d, light_d, macro_d, macro, wn0, xz, gx, gy);
		base += l.base * b.a;
		wn += l.normal * b.a;
		r += l.rough * b.a;
		m += l.metal * b.a;
		occ += l.ao * b.a;
	}
	wn = normalize(wn);
	AO = occ;
	// The weather (W12), as lit_world.gdshader: rain darkening and glossing, puddles in the low places, snow settled on
	// what faces up.
	float puddle = 0.0;
	if (world_wet > 0.0) {
		base *= 1.0 - world_wet * 0.45 * smoothstep(0.2, 0.9, r);
		float wl = dot(base, vec3(0.299, 0.587, 0.114));
		base = max(mix(vec3(wl), base, 1.0 + world_wet * 0.25), vec3(0.0));
		r = mix(r, 0.2, world_wet * 0.8);
		puddle = ws_puddle(world_pos, true);
		if (puddle > 0.0) {
			vec2 ripple = ws_rain_slope(world_pos.xz) * 0.05;
			wn = normalize(mix(wn, vec3(0.0, 1.0, 0.0), puddle) + vec3(ripple.x, 0.0, ripple.y) * puddle);
			base = mix(base, base * 0.25, puddle);
			r = mix(r, 0.1, puddle);
		}
	}
	float snow = ws_snow(world_pos, world_normal);
	if (snow > 0.0) {
		float detail = clamp(dot(base, vec3(0.299, 0.587, 0.114)) * 2.2, 0.0, 1.0);
		base = mix(base, WS_SNOW * mix(0.8, 1.05, detail), snow);
		r = mix(r, 0.65, snow);
		m = mix(m, 0.0, snow);
		wn = normalize(mix(wn, normalize(world_normal), snow * 0.5));
	}
	ALBEDO = base;
	NORMAL = normalize((VIEW_MATRIX * vec4(wn, 0.0)).xyz);
	if (puddle > 0.0) {
		float glance = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), 3.0);
		EMISSION = world_sky.rgb * puddle * (0.04 + glance * 0.3);
	}
	// Never below 0.1: the screen pass reads near-zero roughness as water (strahd_post.gdshader).
	ROUGHNESS = clamp(r, 0.1, 1.0);
	METALLIC = m;
	SPECULAR = specular;
}
