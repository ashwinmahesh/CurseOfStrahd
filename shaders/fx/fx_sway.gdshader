// Things a lingering spell grows out of the floor (world/combat/fx/fx_zones.gd): Entangle's vines, Evard's tentacles,
// Spike Growth's thorns, Web's strands. Lit like the world (so the palette pass and its outlines treat them as part of
// the place), coloured from `base` at the root to `tip`, and swaying from the root up: each instance in its own time.
shader_type spatial;
render_mode cull_disabled, diffuse_lambert, specular_disabled;

uniform vec3 base : source_color = vec3(0.15, 0.25, 0.2);
uniform vec3 tip : source_color = vec3(0.4, 0.6, 0.25);
// How far (world units) the top of a 1-unit stalk swings, and how fast.
uniform float sway = 0.12;
uniform float speed = 1.6;
// The mesh's height, so the swing grows from 0 at the root to `sway` at the tip.
uniform float height = 1.0;
uniform float grow = 1.0;
// A little of their own colour shows even in the dark (fights are mostly at night).
uniform float glow = 0.35;

varying float up;

void vertex() {
	float seed = fract(sin(float(INSTANCE_ID) * 12.9898 + 4.1) * 43758.5453);
	up = clamp(VERTEX.y / max(height, 0.001) + 0.5, 0.0, 1.0);
	float bend = up * up;
	VERTEX.x += sin(TIME * speed + seed * 6.283) * sway * bend;
	VERTEX.z += cos(TIME * speed * 0.8 + seed * 4.1) * sway * 0.7 * bend;
	VERTEX *= grow;
}

void fragment() {
	ALBEDO = mix(base, tip, smoothstep(0.0, 1.0, up));
	EMISSION = ALBEDO * glow;
}
