// One soft puff of the Mists (world/look/mist_bank.gd, lane 28 2026-10-08: the Mists wall had been a hard-edged
// cartoon cloud stood on the road). A camera-facing quad whose round, ragged edge thins to nothing and stirs slowly;
// lit by the sky so it stays pale by day and greys at night. Cosmetic only.
shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, blend_mix, shadows_disabled;

global uniform vec4 world_sky;

uniform vec3 tint : source_color = vec3(0.62, 0.62, 0.66);
uniform float seed = 0.0;
uniform float opacity = 0.85;

float hash(vec2 p) {
	p = fract(p * vec2(123.34, 456.21));
	p += dot(p, p + 45.32);
	return fract(p.x * p.y);
}

float vnoise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), u.x), mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), u.x), u.y);
}

void vertex() {
	// Face the camera, keeping the node's own size.
	vec3 s = vec3(length(MODEL_MATRIX[0].xyz), length(MODEL_MATRIX[1].xyz), length(MODEL_MATRIX[2].xyz));
	MODELVIEW_MATRIX = VIEW_MATRIX * mat4(INV_VIEW_MATRIX[0] * s.x, INV_VIEW_MATRIX[1] * s.y, INV_VIEW_MATRIX[2] * s.z,
		MODEL_MATRIX[3]);
}

void fragment() {
	vec2 c = UV - 0.5;
	float r = length(c) * 2.0;
	vec2 q = UV * 3.0 + vec2(seed * 7.1, seed * 3.3) + vec2(TIME * 0.04, -TIME * 0.025);
	float n = vnoise(q) * 0.6 + vnoise(q * 2.1 + 5.0) * 0.4;
	float a = 1.0 - smoothstep(0.3, 1.0, r + (n - 0.5) * 0.55);
	// Brighter toward the top of the puff, as if lit from above.
	float shade = mix(0.84, 1.04, clamp(1.0 - UV.y + (n - 0.5) * 0.3, 0.0, 1.0));
	float day = clamp(dot(world_sky.rgb, vec3(0.3, 0.59, 0.11)) * 1.6 + 0.25, 0.35, 1.0);
	ALBEDO = tint * shade * day;
	ALPHA = a * opacity;
}
