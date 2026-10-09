// An aura on the ground (world/look/aura_fx.gd), drawn on a plane lying on the floor under a figure. `style` 0: the
// shadow Strahd stands in, a dark pool whose edge creeps and sends out tendrils, mixed over the floor; `surge` (0..1)
// throws it wider; its crimson rim flickers with the flames. `style` 1: a paladin's aura, the area it really covers
// (a rounded square: 10 ft is two squares every way on the grid), a faint warm fill and edge, added. The plane's half
// size is the aura's reach.
shader_type spatial;
render_mode unshaded, blend_premul_alpha, depth_draw_never, cull_disabled, shadows_disabled, fog_disabled;

uniform int style = 0;
uniform float strength = 1.0;
uniform float surge = 0.0;
uniform float fade = 1.0;
// Style 1: the corner rounding, as a share of the half size.
uniform float corner = 0.18;
uniform vec3 shadow_col : source_color = vec3(0.05, 0.02, 0.08);
uniform vec3 edge_col : source_color = vec3(0.6, 0.05, 0.1);
uniform vec3 glow_col : source_color = vec3(1.0, 0.75, 0.35);
uniform sampler2D noise_tex : repeat_enable, filter_linear;
uniform float seed = 0.0;

void fragment() {
	vec2 p = UV * 2.0 - 1.0;
	float t = TIME + seed * 17.0;
	// The same unsteady flicker as the flames above (aura_halo.gdshader), so the floor breathes with the fire.
	float flick = 0.82 + 0.1 * sin(t * 11.3 + seed * 6.0) + 0.06 * sin(t * 23.9 + seed * 2.0)
		+ (texture(noise_tex, vec2(seed * 3.1, t * 0.9)).r - 0.5) * 0.35;
	if (style == 0) {
		float r = length(p);
		float ang = atan(p.y, p.x) / 6.28318;
		float n = texture(noise_tex, vec2(ang * 2.0 + t * 0.05 + seed, r * 1.2 - t * 0.35)).r;
		float edge = 0.5 + (n - 0.5) * 0.4 + surge * 0.35;
		float pool = smoothstep(edge, edge - 0.45, r);
		float n2 = texture(noise_tex, vec2(ang * 5.0 - seed, r * 0.6 - t * 0.12)).r;
		float tendrils = smoothstep(0.62, 0.8, n2) * smoothstep(0.95 + surge * 0.05, 0.45, r) * smoothstep(0.15, 0.45, r);
		float alpha = clamp((pool * 0.62 + tendrils * 0.42) * strength * fade, 0.0, 0.8);
		float rim = smoothstep(0.06, 0.0, abs(r - edge + 0.08)) * (0.25 + surge * 0.8) * flick;
		ALBEDO = shadow_col * alpha + edge_col * rim * strength * fade * 0.5;
		ALPHA = alpha;
	} else {
		vec2 q = abs(p) - vec2(1.0 - corner - 0.03);
		float d = length(max(q, vec2(0.0))) + min(max(q.x, q.y), 0.0) - corner;
		float n = texture(noise_tex, UV * 1.5 + vec2(t * 0.02, -t * 0.03) + seed).r;
		float line = smoothstep(0.035, 0.0, abs(d + 0.01));
		float fill = smoothstep(0.02, -0.3, d) * (0.6 + 0.4 * n);
		float breathe = 0.85 + 0.15 * sin(t * 1.1);
		ALBEDO = glow_col * (line * 0.32 + fill * 0.1) * breathe * mix(1.0, flick, 0.6) * (1.0 + surge) * strength * fade;
		ALPHA = 0.0;
	}
}
