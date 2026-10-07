// A spell effect's smoke, mist or shadow puff (world/combat/fx/fx_kit.gd): a ragged blob from the quad's UVs, mixed
// over the scene (not added), coloured by the particle's colour over its life. Fireball's soot, a cloud's billows,
// shadow magic's dark wisps.
shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_never, cull_disabled, shadows_disabled, fog_disabled;

uniform float density = 0.75;
uniform sampler2D noise_tex : repeat_enable, filter_linear;
uniform sampler2D depth_tex : hint_depth_texture, filter_nearest;
// How far (world units) in front of the floor or a wall a particle fades out, so big puffs never show a hard edge
// where they cut into the ground.
uniform float soft = 0.35;

varying float seed;
varying float phase;

void vertex() {
	seed = fract(sin(float(INSTANCE_ID) * 57.3 + 1.7) * 43758.5453);
	phase = INSTANCE_CUSTOM.y;
	mat4 world = mat4(normalize(INV_VIEW_MATRIX[0]), normalize(INV_VIEW_MATRIX[1]), normalize(INV_VIEW_MATRIX[2]), MODEL_MATRIX[3]);
	float a = INSTANCE_CUSTOM.x;
	mat4 spin = mat4(vec4(cos(a), -sin(a), 0.0, 0.0), vec4(sin(a), cos(a), 0.0, 0.0), vec4(0.0, 0.0, 1.0, 0.0), vec4(0.0, 0.0, 0.0, 1.0));
	float s = length(MODEL_MATRIX[0].xyz);
	MODELVIEW_MATRIX = VIEW_MATRIX * world * spin * mat4(vec4(s, 0.0, 0.0, 0.0), vec4(0.0, s, 0.0, 0.0), vec4(0.0, 0.0, 1.0, 0.0), vec4(0.0, 0.0, 0.0, 1.0));
}

void fragment() {
	float scene_depth = texture(depth_tex, SCREEN_UV).r;
	vec4 scene_view = INV_PROJECTION_MATRIX * vec4(SCREEN_UV * 2.0 - 1.0, scene_depth, 1.0);
	float behind = (-scene_view.z / scene_view.w) - (-VERTEX.z);
	float soften = clamp(behind / soft, 0.0, 1.0);
	vec2 p = UV * 2.0 - 1.0;
	float r = length(p);
	float n = texture(noise_tex, UV * 0.5 + vec2(seed * 5.0, seed * 9.0 + phase * 0.2)).r;
	float n2 = texture(noise_tex, UV * 1.3 + vec2(seed * 2.0 - phase * 0.3, seed)).r;
	float body = clamp(1.0 - r, 0.0, 1.0);
	float a = smoothstep(0.1, 0.6, body * (0.5 + n * 0.9) + (n2 - 0.5) * 0.25 - phase * 0.3);
	ALBEDO = COLOR.rgb * (0.85 + n2 * 0.3);
	ALPHA = clamp(a * COLOR.a * density * soften, 0.0, 1.0);
}
