// Lake Zarovich stretching away past the map's edge (Vista, Improvement Ideas W13): a still sheet of dark water in
// the haze the screen pass gives the far land (`haze`, matched each frame), paler where it lies flatter to the eye,
// with slow bands of sheen and soft shores. Drawn after the screen pass; nearer land hides its near shore.
shader_type spatial;
render_mode unshaded, cull_disabled, blend_mix, depth_draw_never, fog_disabled, shadows_disabled;

uniform vec3 haze : source_color = vec3(0.4, 0.4, 0.46);
uniform vec3 deep : source_color = vec3(0.05, 0.07, 0.1);
uniform float hazing : hint_range(0.0, 1.0) = 0.55;

varying vec3 wpos;

void vertex() {
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	vec2 p = UV * 2.0 - 1.0;
	float r = length(p);
	if (r > 1.0) {
		discard;
	}
	vec3 eye = normalize(wpos - CAMERA_POSITION_WORLD);
	// Flatter to the eye, more of the sky's haze on it.
	float graze = 1.0 - smoothstep(0.0, 0.35, -eye.y);
	vec3 c = mix(deep, haze, hazing + (1.0 - hazing) * graze * 0.8);
	float bands = sin(wpos.x * 0.6 + wpos.z * 0.15 + TIME * 0.15) * sin(wpos.z * 0.9 - TIME * 0.11);
	c += haze * smoothstep(0.75, 1.0, bands) * 0.12;
	ALBEDO = c;
	ALPHA = 1.0 - smoothstep(0.75, 1.0, r);
}
