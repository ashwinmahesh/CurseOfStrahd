shader_type spatial;
// The last pass over a 3D piece that a Search or a check just found (world/look/found_outline.gd): where something
// stands well in front of it (a cut-away wall, a pillar), a faint orange fill of its shape, so a find behind a wall
// still shows where it is. Drawn over everything and kept to those pixels by the depth it reads; never where the
// piece itself shows (found_rim.gdshader marks those in the stencil), and each pixel once.
render_mode unshaded, depth_draw_never, depth_test_disabled, cull_back, shadows_disabled, fog_disabled, blend_mix;
stencil_mode read, write, compare_not_equal, 37;

uniform sampler2D depth_tex : hint_depth_texture, filter_nearest;
uniform vec4 color : source_color = vec4(0.85, 0.45, 0.12, 1.0);
// Only where what's in front is at least this far in front (world units): not the floor it stands on, a wall beside it.
uniform float xray_gap = 0.8;
uniform float xray_alpha = 0.22;
uniform float glow = 1.0;
uniform float bright = 1.0;
uniform float saturate = 1.0;

void fragment() {
	float scene = texture(depth_tex, SCREEN_UV).r;
	vec4 at = INV_PROJECTION_MATRIX * vec4(SCREEN_UV * 2.0 - 1.0, scene, 1.0);
	if (glow <= 0.0 || -at.z / at.w > -VERTEX.z - xray_gap) {
		discard;
	}
	float grey = dot(color.rgb, vec3(0.2126, 0.7152, 0.0722));
	ALBEDO = max(mix(vec3(grey), color.rgb, saturate), vec3(0.0)) * bright;
	ALPHA = xray_alpha * clamp(glow, 0.0, 1.0);
}
