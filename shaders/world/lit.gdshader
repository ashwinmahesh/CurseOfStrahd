// The Modern finish's flat-coloured pieces (Improvement Ideas W3): Classic's cel.gdshader with the same parameters,
// lit like painted 3D instead of in flat bands, with a roughness and metal per palette colour (Look.cel) so pewter
// and silver fittings shine, polished wood takes a soft highlight and cloth stays dull.
shader_type spatial;
#include "res://shaders/world/lit_light.gdshaderinc"

uniform vec3 albedo : source_color = vec3(0.36, 0.36, 0.41);
uniform sampler2D albedo_tex : source_color, filter_nearest, repeat_enable;
uniform bool use_texture = false;
uniform vec2 uv_scale = vec2(1.0);
// Grey-box helper: a checker with grid lines every world unit (one 5 ft square).
uniform bool checker = false;
uniform vec3 checker_alt : source_color = vec3(0.30, 0.30, 0.35);
uniform vec3 grid_line : source_color = vec3(0.15, 0.13, 0.18);
uniform vec3 emission : source_color = vec3(0.0);
uniform float roughness : hint_range(0.0, 1.0) = 0.75;
uniform float metallic : hint_range(0.0, 1.0) = 0.0;

varying vec3 world_pos;

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	vec3 base = albedo;
	if (use_texture) {
		base *= texture(albedo_tex, UV * uv_scale).rgb;
	}
	if (checker) {
		vec2 cell = floor(world_pos.xz);
		bool odd = mod(cell.x + cell.y, 2.0) > 0.5;
		base = odd ? checker_alt : base;
		vec2 f = fract(world_pos.xz);
		float line = step(f.x, 0.03) + step(f.y, 0.03);
		base = mix(base, grid_line, clamp(line, 0.0, 1.0));
	}
	ALBEDO = base;
	EMISSION = emission;
	// Never below 0.1: the screen pass reads near-zero roughness as water (strahd_post.gdshader).
	ROUGHNESS = clamp(roughness, 0.1, 1.0);
	METALLIC = metallic;
	SPECULAR = specular;
}
