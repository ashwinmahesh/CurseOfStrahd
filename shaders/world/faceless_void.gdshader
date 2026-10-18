// The faceless god's face (Amber Temple Look Plan step 7, FacelessGod): a smooth void where its face would be, a dark
// disc that takes the light in, with a faint violet corona turning slowly round it. A quad that stands upright and turns
// to the camera about the vertical as the statue's own pictures do, and is drawn a little toward the camera so it lies
// over the face and not inside the head. One material per statue, no instance uniforms.
shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_never, cull_disabled, fog_disabled;

// The corona's colour (a palette violet) and how bright it burns.
uniform vec3 corona : source_color = vec3(0.45, 0.28, 0.75);
uniform float corona_strength : hint_range(0.0, 3.0) = 1.6;
// The void's half width and half height (a share of the quad).
uniform vec2 disc = vec2(0.14, 0.19);
// How far toward the camera it is drawn (view space), so it lies in front of the face.
uniform float lift = 0.45;
// Fades the whole thing (the statue out of sight, or fading with the walls).
uniform float opacity : hint_range(0.0, 1.0) = 1.0;

void vertex() {
	vec3 up = vec3(0.0, 1.0, 0.0);
	vec3 to_cam = INV_VIEW_MATRIX[3].xyz - MODEL_MATRIX[3].xyz;
	to_cam.y = 0.0;
	vec3 back = normalize(to_cam + vec3(1e-4, 0.0, 0.0));
	vec3 right = normalize(cross(up, back));
	mat4 world = mat4(vec4(right, 0.0), vec4(up, 0.0), vec4(back, 0.0), MODEL_MATRIX[3]);
	MODELVIEW_MATRIX = VIEW_MATRIX * world * mat4(vec4(length(MODEL_MATRIX[0].xyz), 0.0, 0.0, 0.0),
		vec4(0.0, length(MODEL_MATRIX[1].xyz), 0.0, 0.0), vec4(0.0, 0.0, 1.0, 0.0), vec4(0.0, 0.0, 0.0, 1.0));
	MODELVIEW_MATRIX[3].z += lift;
}

void fragment() {
	vec2 p = UV - 0.5;
	float r = length(p / disc);
	// The void: a hard dark middle with a soft edge that the light seems to fall into.
	float hole = 1.0 - smoothstep(0.85, 1.0, r);
	// The corona: a thin ring just outside it, broken into slow bands that turn about the face.
	float a = atan(p.y / disc.y, p.x / disc.x);
	float turn = TIME * 0.12;
	float bands = 0.35 + 0.65 * (0.5 + 0.5 * sin(a * 5.0 + turn * 6.0) * sin(a * 3.0 - turn * 4.0 + 1.3));
	float ring = smoothstep(1.0, 1.1, r) * (1.0 - smoothstep(1.1, 1.75, r));
	float breath = 0.8 + 0.2 * sin(TIME * 0.7);
	float glow = ring * bands * breath * corona_strength;
	ALBEDO = mix(corona, vec3(0.0), hole);
	ALPHA = clamp(max(hole * 0.97, glow * 0.75), 0.0, 1.0) * opacity;
}
