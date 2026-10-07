// A shaft of light or energy (world/combat/fx/fx_kit.gd): an open cylinder (or cone) whose sides glow brightest where
// they turn away from the camera, with streaks running along it. A pillar of radiance coming down on a smite, a
// healing glow rising round a friend, a cone of frost or flame flaring from a caster's hands.
shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_disabled, shadows_disabled, fog_disabled;

uniform float fade = 1.0;
uniform float energy = 2.0;
uniform float scroll = 1.2;
uniform float streaks = 6.0;
// Where along the mesh (0 bottom to 1 top) the light is: fades out toward `top_fade` and in from `bottom_fade`.
uniform float top_fade = 1.0;
uniform float bottom_fade = 0.0;
uniform vec3 core : source_color = vec3(1.0);
uniform vec3 glow : source_color = vec3(1.0, 0.8, 0.4);
uniform sampler2D noise_tex : repeat_enable, filter_linear;

void fragment() {
	float rim = 1.0 - abs(dot(NORMAL, VIEW));
	float n = texture(noise_tex, vec2(UV.x * streaks, UV.y * 0.6 - TIME * scroll * 0.3)).r;
	float n2 = texture(noise_tex, vec2(UV.x * streaks * 2.0 + 0.3, UV.y * 1.4 - TIME * scroll * 0.7)).r;
	float h = 1.0 - UV.y;
	float vertical = smoothstep(top_fade, top_fade - 0.35, h) * smoothstep(bottom_fade, bottom_fade + 0.08, h);
	float body = (0.25 + pow(rim, 1.6) * 0.9) * (0.5 + n * 0.8);
	float hot = pow(rim, 4.0) * n2;
	ALBEDO = (glow * body + core * hot) * energy;
	ALPHA = clamp((body + hot) * vertical * fade, 0.0, 1.0);
}
