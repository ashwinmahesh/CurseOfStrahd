shader_type canvas_item;
// Fog of war on the travel map (docs/ui/travel_map.md): drifting mist over everything the party hasn't learned of.
// `reveal` is a small mask over the whole map art (1 = in sight: around known places and along known roads); the
// panel's pan and zoom map each pixel onto it, so the clearings move with the map. Smooth value noise, no grain.

uniform sampler2D reveal : filter_linear, repeat_disable;
uniform vec2 panel_size = vec2(1152.0, 768.0);
uniform vec2 pan = vec2(0.0);
uniform vec2 art_size = vec2(1152.0, 768.0);
uniform vec4 mist : source_color = vec4(0.74, 0.74, 0.78, 0.94);
uniform vec4 mist_dark : source_color = vec4(0.36, 0.36, 0.41, 0.94);
uniform float time_s = 0.0;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), u.x), mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), u.x), u.y);
}

float fbm(vec2 p) {
	float v = 0.0;
	float a = 0.5;
	for (int k = 0; k < 4; k++) {
		v += a * noise(p);
		p *= 2.03;
		a *= 0.5;
	}
	return v;
}

void fragment() {
	vec2 art_uv = (UV * panel_size - pan) / art_size;
	vec2 q = art_uv * vec2(7.5, 5.0);
	// The clearings' edges are pushed about by slow noise, so they curl like mist rather than read as circles.
	vec2 warp = vec2(fbm(q * 0.8 + vec2(time_s * 0.02, 0.0)), fbm(q * 0.8 + vec2(5.2, 1.3) - vec2(0.0, time_s * 0.02))) - 0.5;
	float seen = texture(reveal, clamp(art_uv + warp * 0.045, vec2(0.0), vec2(1.0))).r;
	float n = fbm(q + vec2(time_s * 0.025, time_s * 0.012));
	float n2 = fbm(q * 1.7 - vec2(time_s * 0.018, 0.0));
	float fog = smoothstep(0.18, 0.85, (1.0 - seen) + (n - 0.5) * 0.4);
	vec3 col = mix(mist_dark.rgb, mist.rgb, smoothstep(0.25, 0.85, n2));
	COLOR = vec4(col, fog * mist.a);
}
