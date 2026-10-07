// A slick on the floor (world/combat/fx/fx_zones.gd): Grease's oily pool, ice left by Ice Storm or Sleet Storm. A
// ragged-edged patch over each square, mixed over the floor, with a slow sheen sliding across it and (with `glitter`)
// points of light like frost.
shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_never, cull_disabled, shadows_disabled, fog_disabled;

uniform vec3 colour : source_color = vec3(0.2, 0.15, 0.1);
uniform vec3 sheen : source_color = vec3(0.8, 0.7, 0.5);
uniform float opacity = 0.75;
uniform float glitter = 0.0;
uniform float fade = 1.0;
uniform sampler2D noise_tex : repeat_enable, filter_linear;

varying vec3 world;

void vertex() {
	world = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	vec2 w = world.xz;
	float n = texture(noise_tex, w * 0.17).r;
	float n2 = texture(noise_tex, w * 0.53 + vec2(0.3, 0.7)).r;
	// Ragged edges: the patch fades out toward its square's rim, broken by noise.
	vec2 e = abs(fract(w) - 0.5) * 2.0;
	float edge = 1.0 - smoothstep(0.75, 1.0, max(e.x, e.y) * (0.85 + n * 0.3));
	float body = smoothstep(0.25, 0.55, n * 0.7 + n2 * 0.5) * 0.4 + 0.6;
	float shine = pow(clamp(texture(noise_tex, w * 0.3 + vec2(TIME * 0.05, -TIME * 0.03)).r * 1.8 - 0.65, 0.0, 1.0), 2.0);
	float glints = glitter * step(0.92, fract(sin(dot(floor(w * 9.0), vec2(12.9898, 78.233))) * 43758.5453))
		* (0.5 + 0.5 * sin(TIME * 3.0 + n * 20.0));
	ALBEDO = mix(colour, sheen, clamp(shine * 1.2 + glints, 0.0, 1.0));
	ALPHA = clamp(opacity * edge * body * fade + glints * 0.5, 0.0, 1.0);
}
