// Water (Atmosphere, docs/art/atmosphere.md): the water texture drifting in two layers, deeper water darker, a band
// of foam along the shore that laps in and out, thin highlight lines that move with the current, and the sky's light
// on the surface. Cel-lit in flat bands like everything else; the palette pass snaps it.
shader_type spatial;
render_mode diffuse_lambert, specular_disabled;

uniform sampler2D albedo_tex : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform float tile_units = 3.0;
uniform vec3 deep : source_color = vec3(0.06, 0.1, 0.18);
uniform vec3 shallow : source_color = vec3(0.18, 0.31, 0.47);
uniform vec3 foam : source_color = vec3(0.79, 0.87, 0.91);
uniform vec3 glint : source_color = vec3(0.56, 0.7, 0.81);
uniform float tex_amount : hint_range(0.0, 1.0) = 0.55;
// The sky colour the surface reflects (Atmosphere sets it for the time of day).
uniform vec3 reflection : source_color = vec3(0.1, 0.15, 0.25);
uniform vec2 flow = vec2(0.12, 0.05);
uniform float atmo_time = 0.0;
// Which squares are water (one texel per square, the map's rectangle on the ground): the shore is where it fades.
uniform sampler2D water_mask : filter_linear, repeat_disable;
uniform vec4 map_rect = vec4(0.0, 0.0, 1.0, 1.0);
uniform bool use_mask = false;
uniform float shadow_floor : hint_range(0.0, 1.0) = 0.3;
uniform float mid_tone : hint_range(0.0, 1.0) = 0.65;

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
	vec3 base = mix(shallow, deep, step(0.45, dd + wob * 0.15));
	base = mix(base, base * tex * 2.2, tex_amount);
	// Thin highlight lines riding the current.
	float ridge = sin((p.x * 0.8 + p.y * 1.7) * 1.6 + vnoise(p * 0.7 + atmo_time * 0.25) * 6.0 - atmo_time * 1.1);
	if (ridge > 0.985 && dd > 0.45) {
		base = mix(base, glint, 0.45);
	}
	// Foam where the water meets the shore, lapping in and out.
	// The mask is 0 on land and 0.25 a square out, so the shore itself sits at about 0.12.
	float lap = 0.2 + 0.035 * sin(atmo_time * 1.4 + (p.x + p.y) * 0.9);
	if (use_mask && dd < lap) {
		base = mix(base, foam, dd < lap - 0.04 ? 0.7 : 0.4);
	}
	ALBEDO = base;
	// The sky's light lying on the surface, so open water never sinks to black at night.
	EMISSION = reflection * (0.25 + 0.35 * smoothstep(0.45, 1.0, dd));
	// Marks water for the screen pass (it reads roughness from the normal buffer): water keeps its own colours
	// through the place's grade instead of turning the colour of the road.
	ROUGHNESS = 0.0;
}

void light() {
	float ndl = clamp(dot(NORMAL, LIGHT), 0.0, 1.0);
	float lit = ndl * ATTENUATION;
	float band = lit > 0.5 ? 1.0 : (lit > 0.12 ? mid_tone : (lit > 0.02 ? shadow_floor : 0.0));
	DIFFUSE_LIGHT += band * LIGHT_COLOR / PI;
}
