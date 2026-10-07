// A spell effect's particle (world/combat/fx/fx_kit.gd): additive light drawn from the quad's UVs, coloured by the
// particle's own colour (the effect's palette ramp over its life) with a hotter centre in the flavour's core colour.
// Shapes: 0 a soft glow, 1 a ragged flame or energy puff (noise eats its edge), 2 a streak (a spark stretched along its
// flight: the emitter aligns the quad to the velocity), 3 a four-pointed glint, 4 a thin ring.
// Drawn after the palette pass (render priority) like the character sprites, so it stays bright and blooms in the
// modern finish.
shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_disabled, shadows_disabled, fog_disabled;

uniform int shape = 0;
uniform bool billboard = true;
uniform float energy = 2.0;
uniform vec3 core : source_color = vec3(1.0);
// Multiplies the particle colour; a lone quad (not a particle) has white vertex colour, so this is its colour.
uniform vec3 tint : source_color = vec3(1.0);
uniform float alpha = 1.0;
uniform float core_amount = 0.6;
uniform float softness = 1.6;
uniform sampler2D noise_tex : repeat_enable, filter_linear;
uniform sampler2D depth_tex : hint_depth_texture, filter_nearest;
// How far (world units) in front of the floor or a wall a particle fades out, so big puffs never show a hard edge
// where they cut into the ground.
uniform float soft = 0.35;

varying float seed;
varying float phase;

// Particle colours come from palette gradients, which hold sRGB values: turn them linear like every other colour.
vec3 to_linear(vec3 c) {
	return mix(c / 12.92, pow((c + 0.055) / 1.055, vec3(2.4)), step(0.04045, c));
}


void vertex() {
	seed = fract(sin(float(INSTANCE_ID) * 91.7 + 3.1) * 43758.5453);
	phase = INSTANCE_CUSTOM.y;
	if (billboard) {
		mat4 world = mat4(normalize(INV_VIEW_MATRIX[0]), normalize(INV_VIEW_MATRIX[1]), normalize(INV_VIEW_MATRIX[2]), MODEL_MATRIX[3]);
		float a = INSTANCE_CUSTOM.x;
		mat4 spin = mat4(vec4(cos(a), -sin(a), 0.0, 0.0), vec4(sin(a), cos(a), 0.0, 0.0), vec4(0.0, 0.0, 1.0, 0.0), vec4(0.0, 0.0, 0.0, 1.0));
		float sx = length(MODEL_MATRIX[0].xyz);
		float sy = length(MODEL_MATRIX[1].xyz);
		MODELVIEW_MATRIX = VIEW_MATRIX * world * spin * mat4(vec4(sx, 0.0, 0.0, 0.0), vec4(0.0, sy, 0.0, 0.0), vec4(0.0, 0.0, 1.0, 0.0), vec4(0.0, 0.0, 0.0, 1.0));
	}
}

void fragment() {
	float scene_depth = texture(depth_tex, SCREEN_UV).r;
	vec4 scene_view = INV_PROJECTION_MATRIX * vec4(SCREEN_UV * 2.0 - 1.0, scene_depth, 1.0);
	float behind = (-scene_view.z / scene_view.w) - (-VERTEX.z);
	float soften = clamp(behind / soft, 0.0, 1.0);
	vec2 p = UV * 2.0 - 1.0;
	float r = length(p);
	float a = 0.0;
	if (shape == 0) {
		a = pow(clamp(1.0 - r, 0.0, 1.0), softness);
	} else if (shape == 1) {
		float n = texture(noise_tex, UV * 0.55 + vec2(seed * 7.0, seed * 3.0 - phase * 0.35)).r;
		float body = clamp(1.0 - r, 0.0, 1.0);
		a = smoothstep(0.05, 0.55, body * (0.45 + n * 1.1) - phase * 0.25) * pow(body, 0.6);
	} else if (shape == 2) {
		a = pow(clamp(1.0 - abs(p.x), 0.0, 1.0), 3.0) * pow(clamp(1.0 - abs(p.y), 0.0, 1.0), 1.2);
	} else if (shape == 3) {
		float arms = max(pow(clamp(1.0 - abs(p.x), 0.0, 1.0), 10.0) * pow(clamp(1.0 - abs(p.y), 0.0, 1.0), 1.6),
			pow(clamp(1.0 - abs(p.y), 0.0, 1.0), 10.0) * pow(clamp(1.0 - abs(p.x), 0.0, 1.0), 1.6));
		a = clamp(arms + pow(clamp(1.0 - r, 0.0, 1.0), 4.0), 0.0, 1.0);
	} else {
		a = smoothstep(0.12, 0.0, abs(r - 0.8)) * 0.9 + pow(clamp(1.0 - r, 0.0, 1.0), 6.0) * 0.3;
	}
	vec3 col = mix(to_linear(COLOR.rgb) * tint, core, clamp(pow(a, 2.5) * core_amount, 0.0, 1.0));
	ALBEDO = col * energy;
	ALPHA = clamp(a * COLOR.a * alpha * soften, 0.0, 1.0);
}
