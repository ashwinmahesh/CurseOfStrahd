// The ring of snow a colossus's footfall throws along the ground (StepDown): a pale band that spreads out from where the
// foot came down, ragged round its edge, and fades as it goes. One quad on the ground, never lit.
shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_never, cull_disabled, fog_disabled;

// A bright leading edge on a bluer shadow of dust that trails inside it, so it shows on snow as well as on dark stone.
uniform float progress : hint_range(0.0, 1.0) = 0.0;
uniform float strength : hint_range(0.0, 1.0) = 0.9;

void fragment() {
	vec2 p = UV - 0.5;
	float r = length(p) * 2.0;
	float ang = atan(p.y, p.x);
	// The front runs out fast and slows.
	float front = mix(0.12, 0.96, 1.0 - pow(1.0 - progress, 2.2));
	float edge = smoothstep(0.07, 0.0, abs(r - front));
	float wake = smoothstep(0.32, 0.0, front - r) * step(r, front) * smoothstep(0.0, 0.2, r);
	float ragged = 0.65 + 0.35 * sin(ang * 11.0 + progress * 4.0) * sin(ang * 5.0 - 1.3);
	ALBEDO = mix(vec3(0.55, 0.66, 0.84), vec3(1.0), edge);
	ALPHA = (edge * 0.9 + wake * 0.4) * ragged * (1.0 - progress) * strength;
}
