// A spell's explosion (world/combat/fx/fx_kit.gd): a sphere churned by 3D noise that swells and cools as `progress`
// runs from 0 to 1, from the flavour's white-hot core through its glow and edge colours to smoke, while the noise eats
// it away from the inside out. Fireball's fireball; tinted, the same body serves every burst.
shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_never, cull_back, shadows_disabled, fog_disabled;

uniform float progress = 0.0;
uniform float displace = 0.35;
uniform float energy = 3.0;
uniform vec3 core : source_color = vec3(1.0, 0.95, 0.7);
uniform vec3 glow : source_color = vec3(1.0, 0.65, 0.2);
uniform vec3 edge : source_color = vec3(0.85, 0.35, 0.1);
uniform vec3 smoke : source_color = vec3(0.15, 0.08, 0.05);
uniform sampler3D noise3 : repeat_enable, filter_linear;

varying vec3 local;
varying float bump;

void vertex() {
	local = VERTEX;
	float n = texture(noise3, VERTEX * 0.9 + vec3(0.0, -progress * 0.8, progress * 0.3)).r;
	bump = n;
	VERTEX += NORMAL * (n - 0.45) * displace * (0.6 + progress);
}

void fragment() {
	float n = texture(noise3, local * 1.7 + vec3(0.0, -progress * 1.4, 0.0)).r;
	float facing = abs(dot(NORMAL, VIEW));
	// Hot where it faces the camera (the middle), cooler round the rim and as it ages.
	float heat = clamp(facing * 0.95 - progress * 1.3 + (n - 0.5) * 1.1 + 0.2, 0.0, 1.0);
	vec3 col = mix(smoke, edge, smoothstep(0.08, 0.32, heat));
	col = mix(col, glow, smoothstep(0.32, 0.6, heat));
	col = mix(col, core, smoothstep(0.82, 1.0, heat));
	float lit = 0.75 + smoothstep(0.45, 1.0, heat) * energy;
	ALBEDO = col * lit;
	// Burns away from the inside out: the noise threshold climbs with progress.
	float eat = smoothstep(progress * 1.05 - 0.05, progress * 1.05 + 0.12, n * 0.8 + bump * 0.35 + facing * 0.15);
	ALPHA = clamp(eat * smoothstep(0.0, 0.08, progress + 0.02), 0.0, 1.0);
}
