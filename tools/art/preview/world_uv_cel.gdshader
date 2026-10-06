// Reference for applying the P4-09 texture sets (docs/art/textures.md): the cel lighting of shaders/cel.gdshader
// with the albedo taken from a tileable texture mapped in world space, so boxes of any size share one texel
// density and neighbouring cells line up. Used by tools/art/preview/texture_preview.gd; port the mapping into
// the game's cel shader when wiring the textures in.
shader_type spatial;
render_mode diffuse_lambert, specular_disabled;

uniform sampler2D albedo_tex : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
// World units (5 ft squares) one copy of the tile spans: tile_world_units in art/textures/manifest.json.
uniform float tile_units = 2.0;
uniform vec2 uv_offset = vec2(0.0);
// Wainscot-style walls (wrap x only): side faces map v from the top of the wall (0) to its foot (1).
uniform bool wall_band = false;
uniform float band_top = 1.15;
uniform float band_height = 1.15;
uniform float shadow_floor : hint_range(0.0, 1.0) = 0.18;
uniform float mid_tone : hint_range(0.0, 1.0) = 0.55;

varying vec3 world_pos;
varying vec3 world_normal;

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	world_normal = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
}

void fragment() {
	vec3 n = abs(world_normal);
	vec2 uv;
	if (n.y >= n.x && n.y >= n.z) {
		uv = world_pos.xz;
	} else if (n.x >= n.z) {
		uv = vec2(world_pos.z, -world_pos.y);
	} else {
		uv = vec2(world_pos.x, -world_pos.y);
	}
	uv = uv / tile_units + uv_offset;
	if (wall_band && n.y < 0.5) {
		uv.y = clamp((band_top - world_pos.y) / band_height, 0.0, 0.999);
	}
	ALBEDO = texture(albedo_tex, uv).rgb;
}

void light() {
	float ndl = clamp(dot(NORMAL, LIGHT), 0.0, 1.0);
	float lit = ndl * ATTENUATION;
	float band = lit > 0.5 ? 1.0 : (lit > 0.12 ? mid_tone : (lit > 0.02 ? shadow_floor : 0.0));
	DIFFUSE_LIGHT += band * LIGHT_COLOR / PI;
}
