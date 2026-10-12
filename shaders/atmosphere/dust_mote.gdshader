// A mote of dust in the air indoors (Visual Polish Plan 9; AtmosphereWeather "dust"): invisible in the dark and
// glinting only where a lamp, a candle or a window's shaft catches it, as dust does. Added over the scene: the mote
// takes no ambient light and no moonlight (the key light reaches everywhere indoors), only the lamps' and the shafts'
// light at its own spot, shadows included, so it shows in a lamp's pool and in the beam through a window and nowhere
// else. Each one turns as it drifts, so it twinkles.
shader_type spatial;
render_mode blend_add, cull_disabled, depth_draw_never, ambient_light_disabled, specular_disabled, fog_disabled;

uniform vec3 core : source_color = vec3(0.96, 0.93, 0.84);
// How brightly a mote shows in a lamp's light, the most one light adds (kept under the glow's threshold, so a mote
// never blooms into a halo: owner 2026-10-12, "annoying dots on the screen"), and how much it twinkles (0 = steady).
uniform float gain = 2.5;
uniform float light_cap = 0.45;
uniform float twinkle = 0.7;

varying float seed;

void vertex() {
	seed = fract(sin(float(INSTANCE_ID) * 91.7 + 3.1) * 43758.5453);
	mat4 world = mat4(normalize(INV_VIEW_MATRIX[0]), normalize(INV_VIEW_MATRIX[1]), normalize(INV_VIEW_MATRIX[2]), MODEL_MATRIX[3]);
	float s = length(MODEL_MATRIX[0].xyz);
	// Motes right by the lens would be blots: they shrink away near the camera.
	s *= smoothstep(2.5, 4.5, distance(MODEL_MATRIX[3].xyz, INV_VIEW_MATRIX[3].xyz));
	MODELVIEW_MATRIX = VIEW_MATRIX * world * mat4(vec4(s, 0.0, 0.0, 0.0), vec4(0.0, s, 0.0, 0.0), vec4(0.0, 0.0, s, 0.0),
		vec4(0.0, 0.0, 0.0, 1.0));
	MODELVIEW_NORMAL_MATRIX = mat3(MODELVIEW_MATRIX);
}

void fragment() {
	float r = length(UV * 2.0 - 1.0);
	float dot_ = 1.0 - smoothstep(0.2, 1.0, r);
	// The glint: a slow turn that catches the light now and then.
	float glint = mix(1.0, 0.25 + 1.5 * pow(0.5 + 0.5 * sin(TIME * (1.2 + seed * 2.3) + seed * 6.283), 4.0), twinkle);
	ALBEDO = core * dot_ * glint;
	ROUGHNESS = 1.0;
}

void light() {
	// Lamps, candles, fires and the shafts through windows: not the moon or the day, which reach every room.
	if (!LIGHT_IS_DIRECTIONAL) {
		vec3 c = LIGHT_COLOR / PI * ATTENUATION * gain;
		float peak = max(c.r, max(c.g, c.b));
		DIFFUSE_LIGHT += c * min(1.0, light_cap / max(peak, 0.0001));
	}
}
