// A glint on a heap of gold (Amber Temple Look Plan step 10): a small four-pointed star that turns to the camera and
// flashes, each on its own beat (taken from where it hangs, so no instance uniform is needed), added over the scene.
shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_disabled, fog_disabled;

uniform vec3 colour : source_color = vec3(1.0, 0.88, 0.55);
uniform float strength : hint_range(0.0, 3.0) = 1.4;

varying float seed;

void vertex() {
	seed = fract(sin(dot(MODEL_MATRIX[3].xyz, vec3(12.9898, 78.233, 37.719))) * 43758.5453);
	MODELVIEW_MATRIX = VIEW_MATRIX * mat4(INV_VIEW_MATRIX[0], INV_VIEW_MATRIX[1], INV_VIEW_MATRIX[2], MODEL_MATRIX[3]);
	MODELVIEW_MATRIX = MODELVIEW_MATRIX * mat4(vec4(length(MODEL_MATRIX[0].xyz), 0.0, 0.0, 0.0),
		vec4(0.0, length(MODEL_MATRIX[1].xyz), 0.0, 0.0), vec4(0.0, 0.0, length(MODEL_MATRIX[2].xyz), 0.0), vec4(0.0, 0.0, 0.0, 1.0));
}

void fragment() {
	vec2 p = UV - 0.5;
	float t = TIME * (0.8 + seed * 0.7) + seed * 40.0;
	float flash = pow(max(0.0, sin(t)), 10.0);
	float r = length(p) * 2.0;
	float dot_ = max(0.0, 1.0 - r * 3.0);
	float h = max(0.0, 1.0 - abs(p.y) * 14.0) * max(0.0, 1.0 - abs(p.x) * 2.4);
	float v = max(0.0, 1.0 - abs(p.x) * 14.0) * max(0.0, 1.0 - abs(p.y) * 2.4);
	ALBEDO = colour * (dot_ + h + v) * flash * strength;
}
