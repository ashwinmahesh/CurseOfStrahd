// What a found trap of the Amber Temple glows with (Amber Temple Look Plan step 13, TrapGlow): the line of warding glyphs
// pulses along the floor, the faceless god's gaze is a slow violet ring of light on the squares it looks at, and the frost
// vent breathes pale wisps. A flat quad on each square, added over the scene, never lit; the red dashed border TrapSight
// draws still frames it. One material per kind.
shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_disabled, fog_disabled;

// 0 warding glyphs, 1 the god's gaze, 2 the frost vent.
uniform int kind = 0;
uniform vec3 colour : source_color = vec3(1.0, 0.8, 0.4);
uniform float strength : hint_range(0.0, 3.0) = 1.0;

varying vec3 wp;

void vertex() {
	wp = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

float hash12(vec2 p) {
	vec3 q = fract(vec3(p.xyx) * 0.1031);
	q += dot(q, q.yzx + 33.33);
	return fract((q.x + q.y) * q.z);
}

void fragment() {
	vec2 p = UV - 0.5;
	float t = TIME;
	float a = 0.0;
	if (kind == 0) {
		// A line of runes across the square: a thin bright line, tick marks along it, a faint halo, pulsing along its length.
		float pulse = 0.55 + 0.45 * sin(t * 1.6 + wp.x * 2.3 + wp.z * 1.7);
		float line = smoothstep(0.03, 0.0, abs(p.y)) * pulse;
		float ticks = 0.0;
		for (int k = 0; k < 4; k++) {
			float x = -0.33 + float(k) * 0.22;
			ticks += smoothstep(0.022, 0.0, abs(p.x - x)) * smoothstep(0.13, 0.0, abs(p.y));
		}
		a = line + ticks * 0.8 * pulse + smoothstep(0.36, 0.0, abs(p.y)) * 0.12 * pulse;
	} else if (kind == 1) {
		// A ring of cold violet light turning slowly, with a lightless middle.
		float r = length(p) * 2.0;
		float ang = atan(p.y, p.x);
		float ring = smoothstep(0.1, 0.0, abs(r - 0.72 - 0.03 * sin(t * 0.8)));
		float bands = 0.5 + 0.5 * sin(ang * 6.0 + t * 0.5);
		a = ring * (0.4 + 0.6 * bands) + smoothstep(0.95, 0.5, r) * smoothstep(0.3, 0.55, r) * 0.18;
	} else {
		// Pale wisps rising out of the crack, and specks of frost.
		vec2 g = (UV + vec2(0.0, t * 0.07)) * vec2(5.0, 7.0);
		vec2 id = floor(g);
		float on = step(0.6, hash12(id));
		float wisp = on * smoothstep(0.5, 0.0, length(fract(g) - 0.5)) * (0.5 + 0.5 * sin(t + hash12(id + 2.0) * 6.28));
		a = wisp * 0.6 + smoothstep(0.5, 0.0, length(p)) * 0.12;
	}
	ALBEDO = colour * a * strength;
}
