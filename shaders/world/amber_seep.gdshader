// Amber seeping out of the weeping crack in the vault floor (Amber Temple Look Plan step 11): a soft pool of honey light
// that swells and ebbs slowly, with a few specks of it lifting out of the crack. Flat on the floor, added over the scene,
// never lit. One material per crack.
shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_disabled, fog_disabled;

uniform vec3 colour : source_color = vec3(1.0, 0.62, 0.18);
uniform float strength : hint_range(0.0, 3.0) = 0.9;

float hash12(vec2 p) {
	vec3 q = fract(vec3(p.xyx) * 0.1031);
	q += dot(q, q.yzx + 33.33);
	return fract((q.x + q.y) * q.z);
}

void fragment() {
	vec2 p = (UV - 0.5) * 2.0;
	// A ragged pool, longer along the crack (x), swelling and ebbing.
	float edge = 0.62 + 0.18 * sin(atan(p.y, p.x) * 5.0 + TIME * 0.5) + 0.08 * sin(p.x * 9.0 - TIME * 0.7);
	float r = length(p * vec2(0.8, 1.35));
	float pool = smoothstep(edge, 0.0, r);
	float breath = 0.65 + 0.35 * sin(TIME * 0.9);
	// Specks lifting out of it.
	vec2 g = (UV + vec2(0.0, TIME * 0.06)) * vec2(7.0, 9.0);
	vec2 id = floor(g);
	float on = step(0.86, hash12(id));
	float speck = on * smoothstep(0.3, 0.05, length(fract(g) - 0.5)) * (0.5 + 0.5 * sin(TIME * 1.7 + hash12(id + 3.0) * 6.28));
	ALBEDO = colour * strength * (pool * pool * breath + speck * pool * 1.2);
}
