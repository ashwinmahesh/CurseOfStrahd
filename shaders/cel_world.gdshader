// The cel lighting of cel.gdshader with its albedo from a seamless texture mapped in world space (docs/art/textures.md):
// boxes of any size share one texel density and neighbouring squares line up. Floors can keep a faint square grid so
// the 5 ft cells stay readable. The palette pass snaps the result afterwards.
shader_type spatial;
render_mode diffuse_lambert, specular_disabled;
#include "res://shaders/cel_light.gdshaderinc"

uniform sampler2D albedo_tex : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
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
uniform float shadow_floor : hint_range(0.0, 1.0) = 0.18;
// The modern finish (Look.modern): relief from a normal map made from the texture itself (its ink lines read as
// grooves), so cobbles and bricks catch a lantern's light; 0 = flat.
uniform sampler2D normal_tex : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;
uniform float normal_strength : hint_range(0.0, 2.0) = 0.0;
uniform float mid_tone : hint_range(0.0, 1.0) = 0.55;

varying vec3 world_pos;
varying vec3 world_normal;

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	world_normal = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
}

void fragment() {
	vec3 n = abs(world_normal);
	bool top = n.y >= n.x && n.y >= n.z;
	vec2 uv;
	if (top) {
		uv = world_pos.xz;
	} else if (n.x >= n.z) {
		uv = vec2(world_pos.z, -world_pos.y);
	} else {
		uv = vec2(world_pos.x, -world_pos.y);
	}
	uv = uv / tile_units + uv_offset;
	if (wall_band && !top) {
		uv.y = clamp((band_top - world_pos.y) / band_height, 0.0, 0.999);
	}
	vec3 base = texture(albedo_tex, uv).rgb * tint;
	if (normal_strength > 0.0) {
		// The texture's own axes in the world for the face it's projected on, then into view space.
		vec3 wn = normalize(world_normal);
		vec3 t;
		vec3 b;
		if (top) {
			t = vec3(1.0, 0.0, 0.0);
			b = vec3(0.0, 0.0, 1.0);
		} else if (n.x >= n.z) {
			t = vec3(0.0, 0.0, 1.0);
			b = vec3(0.0, -1.0, 0.0);
		} else {
			t = vec3(1.0, 0.0, 0.0);
			b = vec3(0.0, -1.0, 0.0);
		}
		vec3 nm = texture(normal_tex, uv).rgb * 2.0 - 1.0;
		nm.xy *= normal_strength;
		vec3 pw = normalize(t * nm.x + b * nm.y + wn * max(nm.z, 0.05));
		NORMAL = normalize((VIEW_MATRIX * vec4(pw, 0.0)).xyz);
	}
	if (top && grid_strength > 0.0) {
		vec2 f = fract(world_pos.xz);
		float line = step(f.x, 0.02) + step(f.y, 0.02);
		base = mix(base, grid_line, clamp(line, 0.0, 1.0) * grid_strength);
	}
	ALBEDO = base;
}

void light() {
	float ndl = clamp(dot(NORMAL, LIGHT), 0.0, 1.0);
	float lit = ndl * ATTENUATION;
	float band = cel_band(lit, mid_tone, shadow_floor);
	DIFFUSE_LIGHT += band * LIGHT_COLOR / PI;
}
