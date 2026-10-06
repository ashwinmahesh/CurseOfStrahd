// A puff of chimney smoke (Atmosphere weather "chimney_smoke"): a lumpy round shape from the quad's UVs in two flat
// tones, lit side up. Hard edges keep it in the opaque pass, so the screen pass outlines it like a cartoon cloud.
shader_type spatial;
render_mode cull_disabled, diffuse_lambert, specular_disabled;

uniform vec3 light_tone : source_color = vec3(0.54, 0.54, 0.59);
uniform vec3 dark_tone : source_color = vec3(0.36, 0.36, 0.41);

varying float seed;

void vertex() {
	seed = fract(sin(float(INSTANCE_ID) * 78.233 + 1.7) * 43758.5453);
	mat4 world = mat4(normalize(INV_VIEW_MATRIX[0]), normalize(INV_VIEW_MATRIX[1]), normalize(INV_VIEW_MATRIX[2]), MODEL_MATRIX[3]);
	float s = length(MODEL_MATRIX[0].xyz);
	MODELVIEW_MATRIX = VIEW_MATRIX * world * mat4(vec4(s, 0.0, 0.0, 0.0), vec4(0.0, s, 0.0, 0.0), vec4(0.0, 0.0, s, 0.0),
		vec4(0.0, 0.0, 0.0, 1.0));
	MODELVIEW_NORMAL_MATRIX = mat3(MODELVIEW_MATRIX);
}

void fragment() {
	vec2 p = UV * 2.0 - 1.0;
	float a = atan(p.y, p.x);
	float edge = 0.78 + 0.13 * sin(a * 5.0 + seed * 6.283) + 0.07 * sin(a * 9.0 + seed * 11.0);
	if (length(p) > edge) {
		discard;
	}
	// UV y runs down the quad: the upper left is the lit side.
	bool lit = dot(p - vec2(0.12, 0.12), normalize(vec2(-0.6, -0.8))) > 0.0;
	ALBEDO = lit ? light_tone : dark_tone;
}
