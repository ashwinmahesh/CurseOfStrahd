// A falling leaf (Atmosphere weather "leaves"): drawn from the quad's UVs, so it needs no art. It faces the camera,
// spins with the particle and flutters by narrowing as it turns edge-on. Hard edges keep it in the opaque pass,
// where the screen pass outlines it and snaps it to the palette.
shader_type spatial;
render_mode cull_disabled, diffuse_lambert, specular_disabled;

uniform vec3 colour_a : source_color = vec3(0.42, 0.23, 0.15);
uniform vec3 colour_b : source_color = vec3(0.54, 0.23, 0.07);
uniform vec3 colour_c : source_color = vec3(0.36, 0.29, 0.24);

varying float seed;
varying float side;

void vertex() {
	seed = fract(sin(float(INSTANCE_ID) * 12.9898 + 4.1) * 43758.5453);
	float flutter = sin(TIME * (2.2 + seed * 2.6) + seed * 6.283);
	side = flutter;
	float a = INSTANCE_CUSTOM.x;
	mat4 world = mat4(normalize(INV_VIEW_MATRIX[0]), normalize(INV_VIEW_MATRIX[1]), normalize(INV_VIEW_MATRIX[2]), MODEL_MATRIX[3]);
	world = world * mat4(vec4(cos(a), -sin(a), 0.0, 0.0), vec4(sin(a), cos(a), 0.0, 0.0), vec4(0.0, 0.0, 1.0, 0.0), vec4(0.0, 0.0, 0.0, 1.0));
	// Leaves drifting right past the lens would fill the screen: they shrink away near the camera.
	float s = length(MODEL_MATRIX[0].xyz) * smoothstep(3.0, 5.0, distance(MODEL_MATRIX[3].xyz, INV_VIEW_MATRIX[3].xyz));
	MODELVIEW_MATRIX = VIEW_MATRIX * world * mat4(vec4(s * max(abs(flutter), 0.18), 0.0, 0.0, 0.0), vec4(0.0, s, 0.0, 0.0),
		vec4(0.0, 0.0, s, 0.0), vec4(0.0, 0.0, 0.0, 1.0));
	MODELVIEW_NORMAL_MATRIX = mat3(MODELVIEW_MATRIX);
}

void fragment() {
	vec2 p = UV * 2.0 - 1.0;
	float bend = 0.15 * sin(p.y * 2.4 + seed * 3.0);
	float w = (1.0 - p.y * p.y) * 0.58;
	bool blade = abs(p.x + bend) < w && p.y < 0.92;
	bool stem = abs(p.x + bend) < 0.07 && p.y >= 0.6;
	if (!blade && !stem) {
		discard;
	}
	vec3 c = seed < 0.4 ? colour_a : (seed < 0.75 ? colour_b : colour_c);
	if (abs(p.x + bend) < 0.06) {
		c *= 0.7;
	}
	ALBEDO = c * (side > 0.0 ? 1.0 : 0.78);
}
