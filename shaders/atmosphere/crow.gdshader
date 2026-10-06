// Crows circling high over a place (Atmosphere weather "crows"): each instance flies its own circle around the
// flock's centre, flapping now and then and gliding the rest. The bird is a dark silhouette drawn from the quad's
// UVs, seen from below and slightly behind, so it reads from the game camera. No art needed.
shader_type spatial;
render_mode unshaded, cull_disabled;

uniform vec3 colour : source_color = vec3(0.05, 0.04, 0.07);
uniform float radius = 7.0;
uniform float span = 0.55;

varying float flap;

void vertex() {
	float id = float(INSTANCE_ID);
	float seed = fract(sin(id * 12.9898) * 43758.5453);
	float r = radius * (0.55 + seed * 0.6);
	float speed = (0.18 + seed * 0.12) * (mod(id, 2.0) < 1.0 ? 1.0 : -1.0);
	float a = TIME * speed + seed * 6.283;
	vec3 centre = MODEL_MATRIX[3].xyz + vec3(cos(a) * r, sin(TIME * 0.3 + seed * 4.0) * 0.6 + seed * 1.5, sin(a) * r);
	// Flap for a while, then glide.
	float beat = sin(TIME * 9.0 + seed * 20.0);
	float gliding = step(0.35, fract(TIME * 0.2 + seed));
	flap = mix(beat, 0.25, gliding);
	vec3 right = normalize(INV_VIEW_MATRIX[0].xyz);
	vec3 up = normalize(INV_VIEW_MATRIX[1].xyz);
	vec3 world = centre + right * VERTEX.x * span + up * VERTEX.y * span * 0.6;
	POSITION = PROJECTION_MATRIX * VIEW_MATRIX * vec4(world, 1.0);
}

void fragment() {
	vec2 p = UV * 2.0 - 1.0;
	p.y = -p.y;
	float x = abs(p.x);
	// Wings: a curve from the body out to the tips, raised or lowered by the flap.
	float wing_y = flap * 0.55 * x - 0.35 * x * x + 0.05;
	bool wing = x < 0.96 && abs(p.y - wing_y) < 0.16 * (1.0 - x * 0.8);
	bool body = length(vec2(p.x * 2.2, p.y + 0.02)) < 0.32;
	bool tail = abs(p.x) < 0.12 && p.y < -0.1 && p.y > -0.5;
	if (!(wing || body || tail)) {
		discard;
	}
	ALBEDO = colour;
}
