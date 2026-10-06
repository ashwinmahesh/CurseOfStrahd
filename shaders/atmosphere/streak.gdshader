// A falling streak (Atmosphere weather "rain", "sleet"): a thin quad facing the camera and stretched along the fall
// direction as the camera sees it, so rain slants the same way from every heading. Opaque and hard-edged, so the
// screen pass snaps it to the palette like everything else.
shader_type spatial;
render_mode unshaded, cull_disabled;

uniform vec3 colour : source_color = vec3(0.56, 0.7, 0.81);
uniform vec3 fall = vec3(0.15, -1.0, 0.05);
uniform float length_units = 0.45;
uniform float width_units = 0.018;

void vertex() {
	vec3 view_dir = normalize(INV_VIEW_MATRIX[2].xyz);
	vec3 d = normalize(fall);
	vec3 up = d - dot(d, view_dir) * view_dir;
	up = length(up) < 1e-3 ? INV_VIEW_MATRIX[1].xyz : normalize(up);
	vec3 right = normalize(cross(up, view_dir));
	vec3 centre = MODEL_MATRIX[3].xyz;
	vec3 world = centre + right * VERTEX.x * width_units + up * VERTEX.y * length_units;
	POSITION = PROJECTION_MATRIX * VIEW_MATRIX * vec4(world, 1.0);
}

void fragment() {
	ALBEDO = colour;
}
