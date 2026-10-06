// A round mote (Atmosphere weather): a snowflake, a will-o'-wisp, a firefly or an ember. A disc from the quad's UVs,
// facing the camera, in one or two flat palette tones. `glow` motes are unshaded so they show in the dark; `pulse`
// makes them breathe in and out of sight. Opaque and hard-edged.
shader_type spatial;
render_mode cull_disabled, diffuse_lambert, specular_disabled;

uniform vec3 core : source_color = vec3(0.96, 0.93, 0.84);
uniform vec3 rim : source_color = vec3(0.79, 0.87, 0.91);
uniform bool glow = false;
uniform float pulse = 0.0;

varying float seed;

void vertex() {
	seed = fract(sin(float(INSTANCE_ID) * 91.7 + 3.1) * 43758.5453);
	mat4 world = mat4(normalize(INV_VIEW_MATRIX[0]), normalize(INV_VIEW_MATRIX[1]), normalize(INV_VIEW_MATRIX[2]), MODEL_MATRIX[3]);
	float s = length(MODEL_MATRIX[0].xyz);
	if (pulse > 0.0) {
		s *= clamp(0.5 + 0.9 * sin(TIME * (0.8 + seed * 1.4) * pulse + seed * 6.283), 0.0, 1.0);
	}
	// Motes right by the lens would be blots: they shrink away near the camera.
	s *= smoothstep(2.5, 4.5, distance(MODEL_MATRIX[3].xyz, INV_VIEW_MATRIX[3].xyz));
	MODELVIEW_MATRIX = VIEW_MATRIX * world * mat4(vec4(s, 0.0, 0.0, 0.0), vec4(0.0, s, 0.0, 0.0), vec4(0.0, 0.0, s, 0.0),
		vec4(0.0, 0.0, 0.0, 1.0));
	MODELVIEW_NORMAL_MATRIX = mat3(MODELVIEW_MATRIX);
}

void fragment() {
	float r = length(UV * 2.0 - 1.0);
	if (r > 1.0) {
		discard;
	}
	vec3 c = r < 0.55 ? core : rim;
	if (glow) {
		EMISSION = c;
		ALBEDO = vec3(0.0);
	} else {
		ALBEDO = c;
	}
}
