// The edge of an area on the floor while a spell is aimed (world/combat/grid_overlay.gd, show_outline): a bright line
// with a soft glow either side of it, on a ribbon that follows the edge. UV.y runs across the ribbon, 0 to 1.
shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_never, cull_disabled, shadows_disabled, fog_disabled;

uniform vec4 line_col : source_color = vec4(0.98, 0.88, 0.54, 1.0);

void fragment() {
	float a = abs(UV.y * 2.0 - 1.0);
	float core = 1.0 - smoothstep(0.2, 0.42, a);
	float glow = (1.0 - smoothstep(0.42, 1.0, a)) * 0.4;
	float breathe = 0.9 + 0.1 * sin(TIME * 2.4);
	ALBEDO = line_col.rgb;
	ALPHA = line_col.a * max(core, glow) * breathe;
}
