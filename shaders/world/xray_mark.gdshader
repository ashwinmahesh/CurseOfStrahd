shader_type spatial;
// A noticed trap seen through the wall in front of it (docs/ui/travel_map.md "Traps"): drawn only where something
// nearer the camera hides it, as red hatching, so a pit in a one-square passage still shows from the diagonal camera.
render_mode unshaded, depth_test_inverted, depth_draw_never, cull_disabled, blend_mix, shadows_disabled;

uniform vec4 tint : source_color = vec4(0.84, 0.16, 0.23, 1.0);
uniform float strength = 0.55;
uniform float stripes = 90.0;

void fragment() {
	float hatch = step(0.45, fract((SCREEN_UV.x * VIEWPORT_SIZE.x / VIEWPORT_SIZE.y + SCREEN_UV.y) * stripes));
	ALBEDO = tint.rgb;
	ALPHA = strength * mix(0.35, 1.0, hatch);
}
