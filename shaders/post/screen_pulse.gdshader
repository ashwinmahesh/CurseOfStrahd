// A pulse over the whole picture at a fight's big moments (Visual Polish Plan 3; ScreenPulse): the world streaks
// toward a point (the party as a fight breaks out, the creature struck by a critical hit or a killing blow, where a big
// spell lands) with a colour fringe along the streaks, the colour drains out for a beat and a quick flash rises, all
// following `amount` (0 to 1 and back). Octopath's encounter swirl, done in place. Drawn on a canvas layer over the
// world and under every menu and the HUD, only while a pulse plays.
shader_type canvas_item;
render_mode unshaded;

uniform sampler2D screen : hint_screen_texture, filter_linear, repeat_disable;
// The envelope (ScreenPulse tweens it), the point the streaks run to (screen 0..1), and the kind's mix.
uniform float amount = 0.0;
uniform vec2 centre = vec2(0.5);
uniform float blur = 1.0;
uniform float fringe = 1.0;
uniform float drain = 0.5;
uniform float flash = 0.3;
uniform vec4 tint : source_color = vec4(1.0);
// Width over height of the screen, so the clear middle is round.
uniform float aspect = 1.778;

const int TAPS = 10;

void fragment() {
	vec2 uv = SCREEN_UV;
	vec2 d = uv - centre;
	float r = length(d * vec2(aspect, 1.0));
	// Streaks: samples back toward the centre, longer further out; red pulled out and blue pulled in along them.
	float reach = 0.08 * blur * amount;
	float split = 0.012 * fringe * amount;
	vec3 acc = vec3(0.0);
	for (int i = 0; i < TAPS; i++) {
		float t = float(i) / float(TAPS - 1);
		vec2 p = centre + d * (1.0 - reach * t);
		acc.r += texture(screen, p + d * split).r;
		acc.g += texture(screen, p).g;
		acc.b += texture(screen, p - d * split).b;
	}
	acc /= float(TAPS);
	// The point itself stays sharp: the streaks grow with the distance from it.
	vec3 col = mix(texture(screen, uv).rgb, acc, smoothstep(0.04, 0.3, r));
	float lum = dot(col, vec3(0.299, 0.587, 0.114));
	col = mix(col, vec3(lum), drain * amount);
	// The flash: brightest where the moment is, rising faster than the rest.
	float glow = flash * amount * amount * (1.0 - 0.6 * smoothstep(0.0, 0.9, r));
	col = mix(col, tint.rgb, clamp(glow, 0.0, 1.0));
	COLOR = vec4(col, 1.0);
}
