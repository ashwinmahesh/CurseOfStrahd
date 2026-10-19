// The battle grid (world/combat/battle_grid.gd): thin lines laid along the ground round every square a creature can
// stand in, shown in fights round the creature whose turn it is and over the whole map in the tactical view. Each
// square is a patch lying on the ground with UV 0..1 across it; the line is drawn along its border, so two squares
// each draw half of the line between them. A pale core with a dark soft edge reads on snow and on moss alike.
shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_never, cull_disabled, shadows_disabled, fog_disabled;

uniform vec4 line_col : source_color = vec4(0.88, 0.84, 0.72, 1.0);
uniform vec4 edge_col : source_color = vec4(0.07, 0.06, 0.09, 1.0);
// How wide the whole line is (squares), and its pale core's share of it.
uniform float width = 0.065;
uniform float core = 0.45;
// Strength of the core and of the dark edge.
uniform float core_alpha = 0.45;
uniform float edge_alpha = 0.3;
// Where the lines gather (world x, z) and how far from it they stay whole and then fade out (squares).
uniform vec2 focus = vec2(0.0);
uniform float reach_in = 6.0;
uniform float reach_out = 8.0;
// 0 hidden, 1 shown: the lines fade in and out.
uniform float shown : hint_range(0.0, 1.0) = 1.0;

varying vec2 world_xz;

void vertex() {
	world_xz = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xz;
}

void fragment() {
	float near = min(min(UV.x, 1.0 - UV.x), min(UV.y, 1.0 - UV.y));
	// Never thinner than a pixel, so a far line stays whole instead of breaking up.
	float px = max(fwidth(near), 0.0001);
	float half_w = max(width * 0.5, px * 1.1);
	float core_w = max(half_w * core, px * 0.55);
	float c = 1.0 - smoothstep(core_w - px, core_w + px, near);
	float e = 1.0 - smoothstep(half_w - px, half_w + px, near);
	float fade = (1.0 - smoothstep(reach_in, reach_out, distance(world_xz, focus))) * shown;
	float a = max(c * core_alpha, e * edge_alpha) * fade;
	if (a < 0.004) {
		discard;
	}
	ALBEDO = mix(edge_col.rgb, line_col.rgb, c);
	ALPHA = a;
}
