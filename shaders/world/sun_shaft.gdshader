// A beam of sun or moonlight slanting down out of doors (Visual Polish Plan 2; SunShafts): an open cone along the key
// light, brightest through its middle and soft at its edges, fading in from high up and out as it reaches the ground,
// with faint streaks drifting across it and motes turning in it. Drawn after the screen pass, added over the scene
// like the window shafts indoors (light_shaft.gdshader), before the floor's rings and the figures.
shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_back, shadows_disabled, fog_disabled;

uniform vec3 colour : source_color = vec3(0.95, 0.82, 0.62);
// SunShafts sets it every frame: the time of day, the weather and the fade in or out.
uniform float strength = 0.0;
uniform float mote_strength = 0.7;
// Each beam's own offset, so their streaks don't move together.
uniform float seed = 0.0;
// The beam's length (world units), from its top (local +y) to where it meets the ground.
uniform float shaft_length = 8.0;
// The patch of light where the beam lands (a flat quad on the ground) instead of the beam.
uniform bool pool = false;

varying float along;   // 0 at the top of the beam, 1 where it meets the ground
varying vec3 world_pos;

void vertex() {
	along = clamp(0.5 - VERTEX.y / max(shaft_length, 0.01), 0.0, 1.0);
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

float hash(vec3 p) {
	p = fract(p * vec3(0.1031, 0.1030, 0.0973));
	p += dot(p, p.yxz + 33.33);
	return fract((p.x + p.y) * p.z);
}

float hash1(float n) {
	return fract(sin(n) * 43758.5453);
}

float noise1(float x) {
	float i = floor(x);
	float f = fract(x);
	return mix(hash1(i), hash1(i + 1.0), f * f * (3.0 - 2.0 * f));
}

void fragment() {
	if (pool) {
		// The light where the beam lands: a soft patch, brightest in its middle, with the beam's streaks across it.
		float r = length(UV * 2.0 - 1.0);
		float soft = 1.0 - smoothstep(0.25, 1.0, r);
		float bands = 0.7 + 0.3 * noise1(UV.x * 7.0 + seed * 17.0 + TIME * 0.12);
		float edge = 1.0 - smoothstep(0.6, 1.25, length((SCREEN_UV - 0.5) * 2.0));
		ALBEDO = colour * strength * soft * soft * bands * edge;
	} else {
		float facing = abs(dot(normalize(NORMAL), normalize(VIEW)));
		float core = pow(facing, 3.0);
		float ends = smoothstep(0.0, 0.4, along) * (1.0 - smoothstep(0.75, 1.0, along));
		// Rays: thin bands round the beam drifting slowly, as light breaks through moving leaves and cloud.
		float round_ = UV.x * 14.0 + seed * 17.0;
		float rays = smoothstep(0.25, 0.85, noise1(round_ + TIME * 0.1) * 0.6 + noise1(round_ * 2.3 - TIME * 0.06 + 5.0) * 0.4);
		float streak = 0.3 + 1.3 * rays;
		// Motes: sparse specks drifting down and across the beam, each twinkling as it turns.
		vec3 q = world_pos * 12.0 + vec3(TIME * 0.25, -TIME * 0.4, TIME * 0.15);
		float speck = step(0.993, hash(floor(q)));
		float twinkle = 0.5 + 0.5 * sin(TIME * 1.7 + hash(floor(q) + 7.0) * 6.28);
		// The play camera's depth blur softens the screen's edges (strahd_post.gdshader), which this draws after: the
		// beams fade out there instead of standing sharp in a blurred corner.
		float edge = 1.0 - smoothstep(0.6, 1.25, length((SCREEN_UV - 0.5) * 2.0));
		ALBEDO = colour * (strength * core * streak + mote_strength * strength * speck * twinkle * core) * ends * edge;
	}
}
