// A waterfall's falling sheet (world/look/waterfall.gd, lane 28 2026-10-08: "the River Ivlis goes over the edge in one
// long white fall"): streaks of white water racing down over darker water, foam at the lip, thinning to spray at the
// foot where the mist swallows it. Lit like the world, with a little of the sky's light in the foam so it stays white
// at dusk; cosmetic only.
shader_type spatial;
render_mode cull_disabled, depth_draw_opaque;

global uniform vec4 world_sky;

uniform vec3 deep : source_color = vec3(0.11, 0.18, 0.3);
uniform vec3 foam : source_color = vec3(0.79, 0.87, 0.91);
// How fast the water falls (texture lengths a second) and how many streaks run across it.
uniform float speed = 1.6;
uniform float streaks = 9.0;

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

void fragment() {
	// UV.x across the fall, UV.y down it (0 at the lip, 1 at the foot).
	vec2 q = vec2(UV.x * streaks, UV.y * 3.0 - TIME * speed);
	float s = vnoise(q * vec2(1.0, 0.35)) * 0.65 + vnoise(q * vec2(2.3, 0.8) + 3.1) * 0.35;
	float white = smoothstep(0.42, 0.62, s);
	// Foam where it tips over the lip, and spray at the foot.
	white = max(white, 1.0 - smoothstep(0.0, 0.14, UV.y));
	white = max(white, smoothstep(0.78, 1.0, UV.y) * 0.85);
	vec3 c = mix(deep, foam, white);
	ALBEDO = c;
	ROUGHNESS = mix(0.15, 0.6, white);
	EMISSION = foam * white * 0.25 * clamp(dot(world_sky.rgb, vec3(0.3, 0.59, 0.11)) * 2.0 + 0.3, 0.3, 1.0);
	// Ragged at its sides and gone into spray at the foot.
	float edge = min(UV.x, 1.0 - UV.x);
	float rag = vnoise(vec2(UV.y * 8.0 - TIME * speed * 2.0, UV.x * 3.0)) * 0.08;
	if (edge < rag + 0.02 || UV.y > 0.97 - rag) {
		discard;
	}
}
