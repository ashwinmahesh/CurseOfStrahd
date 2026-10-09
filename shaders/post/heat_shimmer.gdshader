// The air wavering over an open fire (Visual Polish Plan 8; HeatShimmer): a patch of the finished picture above each
// fire in view, read back from the screen and nudged by waves rising through it, strongest just above the flame and
// fading out upward and to the sides, so its edges match the picture round it. Drawn on a canvas layer over the world
// and under the HUD and menus.
shader_type canvas_item;
render_mode unshaded;

uniform sampler2D screen : hint_screen_texture, filter_linear, repeat_disable;
// How far the waves nudge the picture (a share of the screen's height), and each fire's own offset.
uniform float strength = 0.0035;
uniform float seed = 0.0;
uniform float aspect = 1.778;

void fragment() {
	vec2 p = UV;                 // 0..1 across the patch, y down
	float up = 1.0 - p.y;        // 0 at the flame, 1 at the top
	float mask = smoothstep(0.0, 0.18, up) * (1.0 - smoothstep(0.45, 1.0, up))
		* (1.0 - smoothstep(0.22, 0.5, abs(p.x - 0.5)));
	float t = TIME;
	// Waves rising through the patch, bending as they go.
	float a = p.y * 11.0 + t * 3.2 + seed;
	float b = p.x * 7.0 - t * 1.3 + seed * 1.7;
	vec2 off = vec2(sin(a + sin(b) * 1.5), cos(a * 0.8 + b * 1.4) * 0.6);
	vec2 uv = SCREEN_UV + off * strength * mask * vec2(1.0 / aspect, 1.0);
	COLOR = vec4(texture(screen, uv).rgb, 1.0);
}
