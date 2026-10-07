// The wind the Modern look's trees and plants move in (Flora, docs/art/plants.md). A plant bends from its foot as a
// whole, more the higher a point stands (`stiffness`: little for a spruce's trunk, a lot for a blade of grass), leans
// downwind and rocks as gusts roll across the land in waves; its cards also flutter on their own, each with its own
// phase (UV2: x how free a vertex is, y its phase). The bark and the leaves of one tree share this, so they move
// together, and the shadow pass runs the same code, so shadows sway with them.

uniform vec2 wind_dir = vec2(0.9, 0.35);
// 0 still air, 0.3 a breeze, 0.7 a storm, 1 a gale.
uniform float wind_strength : hint_range(0.0, 1.0) = 0.3;
uniform float stiffness = 0.012;
uniform float flutter_amount = 0.035;

// Where a vertex goes in the wind: `root` is the plant's foot in the world, `local` the vertex above it (world units,
// already scaled and turned), `free`/`phase` its UV2.
vec3 wind_offset(vec3 root, vec3 local, float free, float phase, float t) {
	vec2 d = normalize(wind_dir + vec2(1e-4, 0.0));
	float h = max(local.y, 0.0);
	float seed = fract(sin(dot(root.xz, vec2(12.9898, 78.233))) * 43758.5453);
	// Gusts: broad waves sweeping downwind across the land.
	float gust = 0.55 + 0.45 * sin(dot(root.xz, d) * 0.18 - t * (0.9 + wind_strength * 0.8) + seed * 0.6);
	float rock = sin(t * (1.1 + seed * 0.5) + seed * 6.283) * 0.35;
	float bend = wind_strength * stiffness * h * h * (gust * 0.8 + rock);
	vec3 off = vec3(d.x, 0.0, d.y) * bend;
	// Bending shortens the plant a little rather than stretching it.
	off.y -= bend * bend / max(2.0 * h, 0.05);
	// Flutter: each card shivers on its own, more toward its tip.
	float f = free * flutter_amount * (0.3 + wind_strength) * gust;
	float w = t * (5.0 + seed * 2.0) + phase * 6.283;
	off += vec3(sin(w) * 0.6 + d.x * 0.4, cos(w * 1.3) * 0.5, cos(w * 0.9) * 0.6 + d.y * 0.4) * f;
	return off;
}
