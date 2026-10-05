// Flat two- to three-step cel lighting for environment geometry and placeholder characters
// (plan §4.1). The palette pass snaps the result to the Strahd palette afterwards.
shader_type spatial;
render_mode diffuse_lambert, specular_disabled;

uniform vec3 albedo : source_color = vec3(0.36, 0.36, 0.41);
uniform sampler2D albedo_tex : source_color, filter_nearest, repeat_enable;
uniform bool use_texture = false;
uniform vec2 uv_scale = vec2(1.0);
// Grey-box helper: a checker with grid lines every world unit (one 5 ft square).
uniform bool checker = false;
uniform vec3 checker_alt : source_color = vec3(0.30, 0.30, 0.35);
uniform vec3 grid_line : source_color = vec3(0.15, 0.13, 0.18);
uniform float shadow_floor : hint_range(0.0, 1.0) = 0.18;
uniform float mid_tone : hint_range(0.0, 1.0) = 0.55;
uniform vec3 emission : source_color = vec3(0.0);

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
}

void light() {
	float ndl = clamp(dot(NORMAL, LIGHT), 0.0, 1.0);
	float lit = ndl * ATTENUATION;
	float band = lit > 0.5 ? 1.0 : (lit > 0.12 ? mid_tone : (lit > 0.02 ? shadow_floor : 0.0));
	DIFFUSE_LIGHT += band * LIGHT_COLOR / PI;
}
