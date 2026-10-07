// A flat ring of light on the ground (world/combat/fx/fx_kit.gd): a shockwave racing out from a blast, a healing
// circle under a friend, or (with `runes`) a circle of glyphs for a summoning or a blessing. Drawn on a plane mesh
// lying on the floor; `radius` and `width` are fractions of the plane's half size.
shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_disabled, shadows_disabled, fog_disabled;

uniform float radius = 0.6;
uniform float width = 0.12;
uniform float fade = 1.0;
uniform float fill = 0.0;
uniform float runes = 0.0;
uniform float spin = 0.0;
uniform float energy = 2.0;
uniform vec3 core : source_color = vec3(1.0);
uniform vec3 glow : source_color = vec3(1.0, 0.7, 0.3);
uniform sampler2D noise_tex : repeat_enable, filter_linear;

void fragment() {
	vec2 p = UV * 2.0 - 1.0;
	float r = length(p);
	float ang = atan(p.y, p.x) + TIME * spin;
	float n = texture(noise_tex, vec2(ang * 0.6, r * 2.0 - TIME * 0.3)).r;
	float band = smoothstep(width, 0.0, abs(r - radius));
	float hot = smoothstep(width * 0.35, 0.0, abs(r - radius));
	float inside = smoothstep(radius + 0.02, radius - width, r) * fill * (0.4 + n * 0.6);
	float glyphs = 0.0;
	if (runes > 0.0) {
		// A second, thinner circle inside and a band of tick-mark glyphs between the two.
		float inner = smoothstep(0.015, 0.0, abs(r - radius * 0.78));
		float seg = fract(ang / 6.28318 * 24.0);
		float mark = step(0.25, seg) * step(seg, 0.75) * step(0.5, fract(sin(floor(ang / 6.28318 * 24.0) * 12.9898) * 437.585) + 0.3);
		float tick_band = smoothstep(0.05, 0.0, abs(r - radius * 0.89)) * mark;
		glyphs = (inner + tick_band) * runes;
	}
	float a = band * (0.6 + n * 0.5) + inside + glyphs;
	ALBEDO = (mix(glow, core, hot) * (band + glyphs) + glow * inside) * energy;
	ALPHA = clamp(a * fade * smoothstep(1.0, 0.92, r), 0.0, 1.0);
}
