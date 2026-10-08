// The Modern finish's water (Improvement Ideas W14; Atmosphere._build_water): the same water texture drifting in two
// layers as Classic's water.gdshader, with the same parameters, but lit like the rest of the Modern world. Its colour
// deepens smoothly from the shore out; small ripples move with the current and bend the light, so the moon and the
// lamps leave a glittering path on it and the screen-space reflections (Graphics presets) waver; the sky's light lies
// on it more at a glancing angle; and soft, broken foam laps along the shore. Rain rings it in wet weather (W12).
shader_type spatial;
#include "res://shaders/world/lit_light.gdshaderinc"

uniform sampler2D albedo_tex : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform float tile_units = 3.0;
uniform vec3 deep : source_color = vec3(0.06, 0.1, 0.18);
uniform vec3 shallow : source_color = vec3(0.18, 0.31, 0.47);
uniform vec3 foam : source_color = vec3(0.79, 0.87, 0.91);
uniform vec3 glint : source_color = vec3(0.56, 0.7, 0.81);
uniform float tex_amount : hint_range(0.0, 1.0) = 0.4;
// The sky colour the surface reflects (Atmosphere sets it for the time of day).
uniform vec3 reflection : source_color = vec3(0.1, 0.15, 0.25);
uniform vec2 flow = vec2(0.12, 0.05);
uniform float atmo_time = 0.0;
// Which squares are water (one texel per square, the map's rectangle on the ground): the shore is where it fades.
uniform sampler2D water_mask : filter_linear, repeat_disable;
uniform vec4 map_rect = vec4(0.0, 0.0, 1.0, 1.0);
uniform bool use_mask = false;
// How choppy the ripples are, and how big (world units across).
uniform float ripple_strength : hint_range(0.0, 1.0) = 0.35;
uniform float ripple_size = 0.6;
// Rain on the water (W12): rings spreading where drops land, as wet as the place's weather (world_wet, Atmosphere).

varying vec3 world_pos;

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

// Ripple height at a point: two noise layers drifting with and across the current.
float ripple(vec2 p) {
	vec2 q = p / ripple_size;
	return vnoise(q + flow * atmo_time * 2.0) * 0.6 + vnoise(q * 2.3 - flow.yx * atmo_time * 3.1 + 7.3) * 0.4;
}

// Rings spreading from drops landing on a grid of cells, each cell's drop at its own moment.
float rain_rings(vec2 p) {
	vec2 cell = floor(p * 2.0);
	vec2 f = fract(p * 2.0);
	float h = 0.0;
	for (int j = -1; j <= 1; j++) {
		for (int i = -1; i <= 1; i++) {
			vec2 c = cell + vec2(float(i), float(j));
			float r = hash(c);
			vec2 at = vec2(hash(c + 3.1), hash(c + 7.7));
			float t = fract(atmo_time * 0.9 + r);
			float d = length(f - vec2(float(i), float(j)) - at);
			float ring = sin((d - t * 0.6) * 40.0) * smoothstep(0.0, 0.05, t * 0.6 - d + 0.05) * (1.0 - t);
			h += ring * smoothstep(0.6, 0.0, d);
		}
	}
	return h;
}

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

// How far into the water a point is: 0 at the shore, 1 a couple of squares out.
float depth_at(vec2 p) {
	if (!use_mask) {
		return 1.0;
	}
	vec2 uv = (p - map_rect.xy) / (map_rect.zw - map_rect.xy);
	if (any(lessThan(uv, vec2(0.0))) || any(greaterThan(uv, vec2(1.0)))) {
		return 1.0;
	}
	return texture(water_mask, uv).r;
}

void fragment() {
	vec2 p = world_pos.xz;
	vec3 t1 = texture(albedo_tex, p / tile_units + flow * atmo_time / tile_units).rgb;
	vec3 t2 = texture(albedo_tex, p / (tile_units * 1.7) - flow.yx * atmo_time / tile_units + 0.37).rgb;
	vec3 tex = (t1 + t2) * 0.5;
	float d = depth_at(p);
	float wob = vnoise(p * 1.3 + atmo_time * 0.4) - 0.5;
	float dd = clamp(d + wob * 0.06, 0.0, 1.0);
	// Deeper water darker, smoothly from the shore out.
	vec3 base = mix(shallow, deep, smoothstep(0.15, 0.85, dd));
	base = mix(base, base * tex * 2.2, tex_amount);
	// Ripples: the slope of the ripple height bends the surface.
	float e = 0.05;
	float h0 = ripple(p);
	vec2 slope = vec2(ripple(p + vec2(e, 0.0)) - h0, ripple(p + vec2(0.0, e)) - h0) / e;
	if (world_wet > 0.0) {
		float r0 = rain_rings(p);
		slope += vec2(rain_rings(p + vec2(e, 0.0)) - r0, rain_rings(p + vec2(0.0, e)) - r0) / e * 0.08 * world_wet;
	}
	vec3 wn = normalize(vec3(-slope.x * ripple_strength * 0.25, 1.0, -slope.y * ripple_strength * 0.25));
	NORMAL = normalize((VIEW_MATRIX * vec4(wn, 0.0)).xyz);
	// Foam along the shore: a soft band broken up by noise, lapping in and out.
	float lap = 0.2 + 0.035 * sin(atmo_time * 1.4 + (p.x + p.y) * 0.9);
	float broken = vnoise(p * 3.0 + atmo_time * 0.3);
	float froth = use_mask ? (1.0 - smoothstep(lap - 0.08, lap + 0.02, dd)) * smoothstep(0.25, 0.6, broken + 0.25) : 0.0;
	base = mix(base, foam, froth * 0.75);
	ALBEDO = base;
	// The sky's light on the surface, more of it at a glancing angle (and never black at night).
	float fresnel = pow(1.0 - clamp(dot(normalize(NORMAL), VIEW), 0.0, 1.0), 4.0);
	EMISSION = reflection * (0.2 + 0.3 * smoothstep(0.45, 1.0, dd) + fresnel * 0.8) * (1.0 - froth * 0.6);
	// Under 0.08 marks water for the screen pass (it keeps its own colours through the grade); smooth, so the moon
	// and the lamps leave sharp glints on the ripples. Foam is rough.
	ROUGHNESS = mix(0.05, 0.07, froth);
	METALLIC = 0.0;
}
