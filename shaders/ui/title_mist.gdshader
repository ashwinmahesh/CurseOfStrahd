shader_type canvas_item;
// Drifting mist or cloud over the title screen's key art (ui/menu/title_ambience.gd): smooth value noise, warped so it
// curls, scrolling slowly sideways, and faded to a band of the screen. No grain, no dither.

uniform vec4 tint : source_color = vec4(0.79, 0.87, 0.91, 1.0);
uniform float strength = 0.25;
uniform vec2 drift = vec2(0.012, 0.0);
uniform float scale = 3.0;
uniform float aspect = 1.78;
// The band: fully in from band_in.x to band_in.y, fading out over `soft` either side (in UV.y).
uniform vec2 band_in = vec2(0.6, 1.0);
uniform float soft = 0.15;
// How much of the noise shows: higher keeps only the thickest wisps.
uniform float threshold = 0.45;
uniform float seed = 0.0;

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
	for (int k = 0; k < 5; k++) {
		v += a * noise(p);
		p = p * 2.03 + vec2(1.7, 9.2);
		a *= 0.5;
	}
	return v;
}

void fragment() {
	vec2 p = vec2(UV.x * aspect, UV.y * 1.6) * scale + vec2(seed, seed * 0.37) - TIME * drift * scale;
	float warp = fbm(p * 0.5 + vec2(TIME * 0.015, -TIME * 0.01));
	float n = fbm(p + vec2(warp * 1.4, warp * 0.6));
	float band = smoothstep(band_in.x - soft, band_in.x, UV.y) * (1.0 - smoothstep(band_in.y, band_in.y + soft, UV.y));
	float m = smoothstep(threshold, threshold + 0.35, n) * band;
	COLOR = vec4(tint.rgb, m * strength * tint.a);
}
