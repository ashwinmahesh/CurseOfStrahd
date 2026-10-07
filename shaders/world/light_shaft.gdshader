// A shaft of light falling through a window (Improvement Ideas W5; Atmosphere._window_shaft): a cone of glowing haze
// added over the scene, brightest through its middle and fading at its edges, where it comes in and where it reaches
// the floor, with motes of dust drifting through it. Drawn after the screen pass (render priority 1) and before the
// character sprites, so the pass can't paint over it and the party stays in front.
shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_back, shadows_disabled, fog_disabled;

uniform vec3 colour : source_color = vec3(0.62, 0.7, 0.86);
uniform float strength = 0.25;
// The cone's length (world units), from the window (local top) to the floor (local bottom).
uniform float shaft_length = 3.0;
uniform float mote_strength = 0.9;

varying float along;
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

void fragment() {
	float facing = abs(dot(normalize(NORMAL), normalize(VIEW)));
	float core = pow(facing, 2.5);
	float ends = smoothstep(0.0, 0.18, along) * (1.0 - smoothstep(0.6, 1.0, along));
	// Dust: sparse specks on a fine grid drifting slowly down and across the beam, each twinkling as it turns.
	vec3 q = world_pos * 14.0 + vec3(TIME * 0.35, -TIME * 0.6, TIME * 0.2);
	float speck = step(0.992, hash(floor(q)));
	float twinkle = 0.5 + 0.5 * sin(TIME * 2.0 + hash(floor(q) + 7.0) * 6.28);
	vec3 glow = colour * (strength * core + mote_strength * speck * twinkle * core) * ends;
	ALBEDO = glow;
}
