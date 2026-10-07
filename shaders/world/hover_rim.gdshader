shader_type spatial;
// The glow on whatever the mouse is over while exploring (world/look/hover_glow.gd, docs/plans/ui_polish.md): a gilt
// rim brightest at the silhouette, laid over the thing's own material, gently pulsing.
render_mode unshaded, blend_add, depth_draw_never, cull_back, shadows_disabled;

uniform vec3 tint : source_color = vec3(0.89, 0.77, 0.49);
uniform float strength = 0.6;

void fragment() {
	float rim = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), 3.0);
	float pulse = 0.75 + 0.25 * sin(TIME * 4.0);
	ALBEDO = tint * (0.06 + rim * strength) * pulse;
}
